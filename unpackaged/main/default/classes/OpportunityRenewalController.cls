public with sharing class OpportunityRenewalController {

    public class RenewalResult {
        @AuraEnabled public Id newOpportunityId;
        @AuraEnabled public Id newQuoteId;
        @AuraEnabled public String message;
    }   

    // NEW: LWC-facing method with a fresh name
    @AuraEnabled
    public static RenewalResult renewOpportunityLwc(
        Id opportunityId,
        Date newCloseDate,
        Boolean copyFiles,
        Integer newSubscriptionTerm
    ) {
        
        return renewInternal(opportunityId, newCloseDate, copyFiles, newSubscriptionTerm);

    }

    // INTERNAL: all your existing logic lives here now
    private static RenewalResult renewInternal(

        Id opportunityId,
        Date newCloseDate,
        Boolean copyFiles,
        Integer newSubscriptionTerm
    ) {
        system.debug('Test2');
        if (opportunityId == null) {
            throw new AuraHandledException('Opportunity Id is required.');
        }

        Savepoint sp = Database.setSavepoint();
		system.debug('Test3');
        try {
            // --- Source Opportunity (including fields to carry over)
            Opportunity srcOpp = [
                SELECT Id, Name, AccountId, OwnerId, CloseDate, StageName, Type, RecordTypeId,
                       CurrencyIsoCode, Pricebook2Id,
                       /* CARRY-OVER FIELDS */
                       Primary_Contact__c,
                       JV_Partnership_Account__c,
                       Indigenous_Partnership__c,
                       LeadSource,
                       Parent_Industry__c,
                       Industry_Segment__c,
                       Industry_Segment_Details__c,
                       Branch_Name__c,
                       Equipment_Type__c,
                       Cooperative_Opportunity__c,
                       Project_Location_Country__c,
                       Project_Location_Address__c,
                       Project_Location_City__c,
                       Project_Location_Province__c,
                       Project_Location_Postal_Code_Zip_Code__c,
                       Tax_Exempt__c,
                       Credit_App_Obtained__c,
                       Credit_Notes__c,
                       Insurance_Type__c,
                       Customer_PO__c,
                       Proof_of_Insurance_Obtained__c,
                       Proof_of_General_Liability_Obtained__c,
                       Insurance_Notes__c,
                       T_C__c,
                       T_C_Type__c,
                       T_C_Clauses__c,
                       Description__c,
                       Description,
                       Contract_Number__c,
                       Site_Contact__c,
                	   Accounting_Contact__c,
                       // New Fullcopy Sandbox field
                       ContractId,
                       NS_Project_ID__c,
                       NS_Rental_Contract_ID__c,
                       Project_Manager__c,
                       Reserve_Land__c,
                       Paid_when_Paid__c,
                       Renewal_Opportunity_ID__c,       // ID of Renewal Opp
                       Original_Opportunity_ID__c,      // ID of Original Opp
                       Renewal_Opportunity2__c,         // Lookup field on Original Opp to store Renewal Opp record
                       NS_Billing_Contact_ID__c,
                       NS_Site_Contact_ID__c,
                       Bid_Submit_Date__c,
                       Bid_Set_Meeting_Date__c,
                       Reason_s_Won_Lost_Cancelled__c,
                       Site_Contact_First_Name__c,
                       Site_Contact_Last_Name__c,
                       Site_Contact_Email2__c,
                       Site_Contact_Phone2__c,
                       Site_Contact_Mobile2__c,
                       Billing_Contact_First_Name__c,
                       Billing_Contact_Last_Name__c,
                       Billing_Contact_Email__c,
                       Billing_Contact_Phone__c,
                       Billing_Contact_Mobile__c,
                       Opportunity_Billing_Address__c,
                       Opportunity_Billing_Address__Street__s,
                       Opportunity_Billing_Address__City__s,
                       Opportunity_Billing_Address__StateCode__s,
                       Opportunity_Billing_Address__PostalCode__s,
                       Opportunity_Billing_Address__CountryCode__s,
                       Opportunity_Billing_Address__Longitude__s,
                       Opportunity_Billing_Address__Latitude__s,
                       Opportunity_Billing_Address__GeocodeAccuracy__s,
                	   Site_Contact__r.FirstName,
            		   Site_Contact__r.LastName,
            		   Site_Contact__r.Email,
            		   Site_Contact__r.MobilePhone,
            		   Site_Contact__r.Phone,
           			   Accounting_Contact__r.FirstName,
            		   Accounting_Contact__r.LastName,
            		   Accounting_Contact__r.Email,
            		   Accounting_Contact__r.MobilePhone,
           			   Accounting_Contact__r.Phone      
                FROM Opportunity
                WHERE Id = :opportunityId
                LIMIT 1
            ];
            
            // -- Contract (optional: there may be none)
            Contract cntrct;
            List<Contract> cntrctList = [
                SELECT Id, SBQQ__Opportunity__c, SBQQ__RenewalOpportunity__c, SBQQ__RenewalTerm__c 
                FROM Contract
                WHERE SBQQ__Opportunity__c = :opportunityId
                   OR SBQQ__RenewalOpportunity__c = :opportunityId
                LIMIT 1
            ];
            if (!cntrctList.isEmpty()) {
                cntrct = cntrctList[0];
            }

            // --- Primary Quote (including fields to carry over)
            SBQQ__Quote__c srcPrimaryQuote;
            List<SBQQ__Quote__c> qts = [
                SELECT Id, Name, SBQQ__Primary__c, SBQQ__Opportunity2__c, CurrencyIsoCode,
                       SBQQ__PricebookId__c, SBQQ__StartDate__c, SBQQ__EndDate__c, SBQQ__SubscriptionTerm__c,
                       SBQQ__Status__c,
                       /* CARRY-OVER FIELDS ON QUOTE */
                       Transaction_Type__c,
                       Transaction_Type_Detail__c,
                       Milestone_Format__c,
                       Major_Project__c,
                       SBQQ__LineItemsGrouped__c
                FROM SBQQ__Quote__c
                WHERE SBQQ__Opportunity2__c = :opportunityId AND SBQQ__Primary__c = true
                LIMIT 1
            ];
            if (!qts.isEmpty()) srcPrimaryQuote = qts[0];

            // --- 1) Clone Opportunity (set mappings + flags)
            Opportunity newOpp = srcOpp.clone(false, true, false, false);
            newOpp.Name      = srcOpp.Name + ' — Renewal';
            newOpp.StageName = 'Qualified';
            newOpp.CloseDate = (newCloseDate != null)
                ? newCloseDate
                : (srcOpp.CloseDate != null ? srcOpp.CloseDate.addYears(1) : Date.today().addYears(1));
            newOpp.Type      = 'Existing Customer'; 
			system.debug('Test4');
            // Carry over fields from original Opp
            newOpp.Primary_Contact__c                         = srcOpp.Primary_Contact__c;
            newOpp.JV_Partnership_Account__c                  = srcOpp.JV_Partnership_Account__c;
            newOpp.LeadSource                                 = srcOpp.LeadSource;
            newOpp.Parent_Industry__c                         = srcOpp.Parent_Industry__c;
            newOpp.Indigenous_Partnership__c                  = srcOpp.Indigenous_Partnership__c;
            newOpp.Industry_Segment__c                        = srcOpp.Industry_Segment__c;
            newOpp.Industry_Segment_Details__c                = srcOpp.Industry_Segment_Details__c;
            newOpp.Branch_Name__c                             = srcOpp.Branch_Name__c;
            newOpp.Equipment_Type__c                          = srcOpp.Equipment_Type__c;
            newOpp.Cooperative_Opportunity__c                 = srcOpp.Cooperative_Opportunity__c;
            newOpp.Site_Contact__c                            = srcOpp.Site_Contact__c;
            newOpp.Project_Location_Country__c                = srcOpp.Project_Location_Country__c;
            newOpp.Project_Location_Address__c                = srcOpp.Project_Location_Address__c;
            newOpp.Project_Location_City__c                   = srcOpp.Project_Location_City__c;
            newOpp.Project_Location_Province__c               = srcOpp.Project_Location_Province__c;
            newOpp.Project_Location_Postal_Code_Zip_Code__c   = srcOpp.Project_Location_Postal_Code_Zip_Code__c;
            newOpp.Accounting_Contact__c                      = srcOpp.Accounting_Contact__c;
            newOpp.Tax_Exempt__c                              = srcOpp.Tax_Exempt__c;
            newOpp.Credit_App_Obtained__c                     = srcOpp.Credit_App_Obtained__c;
            newOpp.Credit_Notes__c                            = srcOpp.Credit_Notes__c;
            newOpp.Insurance_Type__c                          = srcOpp.Insurance_Type__c;
            newOpp.Customer_PO__c                             = srcOpp.Customer_PO__c;
            newOpp.Proof_of_Insurance_Obtained__c             = srcOpp.Proof_of_Insurance_Obtained__c;
            newOpp.Proof_of_General_Liability_Obtained__c     = srcOpp.Proof_of_General_Liability_Obtained__c;
            newOpp.Insurance_Notes__c                         = srcOpp.Insurance_Notes__c;
            newOpp.T_C__c                                     = srcOpp.T_C__c;
            newOpp.T_C_Type__c                                = srcOpp.T_C_Type__c;
            newOpp.T_C_Clauses__c                             = srcOpp.T_C_Clauses__c;
            newOpp.Description__c                             = srcOpp.Description__c;
            newOpp.Description                                = srcOpp.Description;
            newOpp.NS_Billing_Contact_ID__c                   = srcOpp.NS_Billing_Contact_ID__c;
            newOpp.NS_Site_Contact_ID__c                      = srcOpp.NS_Site_Contact_ID__c;
            newOpp.Bid_Submit_Date__c                         = srcOpp.Bid_Submit_Date__c;
            newOpp.Bid_Set_Meeting_Date__c                    = srcOpp.Bid_Set_Meeting_Date__c;
            newOpp.Reason_s_Won_Lost_Cancelled__c             = srcOpp.Reason_s_Won_Lost_Cancelled__c;
 
            newOpp.Opportunity_Billing_Address__Street__s     = srcOpp.Opportunity_Billing_Address__Street__s;
            newOpp.Opportunity_Billing_Address__City__s       = srcOpp.Opportunity_Billing_Address__City__s;
            newOpp.Opportunity_Billing_Address__StateCode__s  = srcOpp.Opportunity_Billing_Address__StateCode__s;
            newOpp.Opportunity_Billing_Address__CountryCode__s = srcOpp.Opportunity_Billing_Address__CountryCode__s;
            newOpp.Opportunity_Billing_Address__PostalCode__s = srcOpp.Opportunity_Billing_Address__PostalCode__s;
            newOpp.Opportunity_Billing_Address__Latitude__s   = srcOpp.Opportunity_Billing_Address__Latitude__s;
            newOpp.Opportunity_Billing_Address__Longitude__s  = srcOpp.Opportunity_Billing_Address__Longitude__s;
            newOpp.Opportunity_Billing_Address__GeocodeAccuracy__s = srcOpp.Opportunity_Billing_Address__GeocodeAccuracy__s;
            newOpp.Credit_App_Obtained__c = 'No';
            newOpp.New_Contract_or_Renewal__c = 'Renewal';
            system.debug('Test5');
            IF(srcOpp.Site_Contact__c != null && srcOpp.Site_Contact_First_Name__c == null){
               	newOpp.Site_Contact_First_Name__c = srcOpp.Site_Contact__r.FirstName;
               	newOpp.Site_Contact_Last_Name__c = srcOpp.Site_Contact__r.LastName;
                newOpp.Site_Contact_Email2__c = srcOpp.Site_Contact__r.Email;
                newOpp.Site_Contact_Mobile2__c = srcOpp.Site_Contact__r.MobilePhone;
                newOpp.Site_Contact_Phone2__c = srcOpp.Site_Contact__r.Phone;
            }
            

            IF(srcOpp.Site_Contact_First_Name__c != null){
				newOpp.Site_Contact_First_Name__c = srcOpp.Site_Contact_First_Name__c;
				newOpp.Site_Contact_Last_Name__c = srcOpp.Site_Contact_Last_Name__c;
				newOpp.Site_Contact_Email2__c = srcOpp.Site_Contact_Email2__c;
				newOpp.Site_Contact_Phone2__c = srcOpp.Site_Contact_Phone2__c;
				newOpp.Site_Contact_Mobile2__c = srcOpp.Site_Contact_Mobile2__c;
            }
            
            
              IF(srcOpp.Accounting_Contact__c != null && srcOpp.Billing_Contact_First_Name__c == null){
               	newOpp.Billing_Contact_First_Name__c = srcOpp.Accounting_Contact__r.FirstName;
               	newOpp.Billing_Contact_Last_Name__c = srcOpp.Accounting_Contact__r.LastName;
                newOpp.Billing_Contact_Email__c = srcOpp.Accounting_Contact__r.Email;
                newOpp.Billing_Contact_Mobile__c = srcOpp.Accounting_Contact__r.MobilePhone;
                newOpp.Billing_Contact_Phone__c = srcOpp.Accounting_Contact__r.Phone;
            }
            

            
            IF(srcOpp.Billing_Contact_First_Name__c != null){
            	newOpp.Billing_Contact_First_Name__c = srcOpp.Billing_Contact_First_Name__c;
            	newOpp.Billing_Contact_Last_Name__c = srcOpp.Billing_Contact_Last_Name__c;
            	newOpp.Billing_Contact_Email__c = srcOpp.Billing_Contact_Email__c;
            	newOpp.Billing_Contact_Phone__c = srcOpp.Billing_Contact_Phone__c;
            	newOpp.Billing_Contact_Mobile__c = srcOpp.Billing_Contact_Mobile__c;
            }
			system.debug('Test5.1');
            // Map Contract_Number__c (original) -> Original_Contract__c (renewal)
            newOpp.Original_Contract__c = srcOpp.Contract_Number__c ;

            // Set Renewal flag on the new Opp
            newOpp.Renewal_Opportunity__c = true;
			system.debug('Test5.2');
            insert newOpp;
			system.debug('Test5.3');
            // After new Opp insert, mark the ORIGINAL as renewed
            update new Opportunity(
                Id                      = srcOpp.Id,
                Renewed_Opportunity__c  = true,
                Renewal_Opportunity2__c = newOpp.Id
            );

            Id newQuoteId;
			system.debug('Test6');
            if (srcPrimaryQuote != null) {
                // --- 2) Clone Primary Quote (+ carry specific fields)
                SBQQ__Quote__c newQuote = srcPrimaryQuote.clone(false, true, false, false);
                newQuote.SBQQ__Opportunity2__c = newOpp.Id;
                newQuote.Quote_Name__c         = srcPrimaryQuote.Name + ' — Renewal';
                newQuote.SBQQ__Primary__c      = true;
                newQuote.SBQQ__Status__c       = 'Draft';
                newQuote.Renewal_Quote__c      = srcPrimaryQuote.Id;

                // Carry-over fields
                newQuote.Transaction_Type__c         = srcPrimaryQuote.Transaction_Type__c;
                newQuote.Transaction_Type_Detail__c  = srcPrimaryQuote.Transaction_Type_Detail__c;
                newQuote.Major_Project__c            = srcPrimaryQuote.Major_Project__c;
                newQuote.SBQQ__LineItemsGrouped__c   = srcPrimaryQuote.SBQQ__LineItemsGrouped__c;
                
                System.debug('Milestone Format carry over');
                if (!String.isBlank(srcPrimaryQuote.Milestone_Format__c)) {
                    newQuote.Milestone_Format__c = srcPrimaryQuote.Milestone_Format__c;
                }
                if (String.isBlank(srcPrimaryQuote.Milestone_Format__c)) {
                    newQuote.Milestone_Format__c = '--None--';
                }

                if (newSubscriptionTerm != null) {
                    newQuote.SBQQ__SubscriptionTerm__c = newSubscriptionTerm;
                }

                insert newQuote;
                newQuoteId = newQuote.Id;
                
                // Update Renewal Opp on Contract (only if a Contract exists)
                if (cntrct != null) {
                    update new Contract(
                        Id                          = cntrct.Id,
                        SBQQ__RenewalOpportunity__c = newOpp.Id,
                        SBQQ__RenewalTerm__c        = newQuote.SBQQ__SubscriptionTerm__c
                    );
                }
				system.debug('Test7');
                // --- 3) Clone Quote Line Groups (ensure fields are carried)
                List<SBQQ__QuoteLineGroup__c> srcGroups = [
                    SELECT Id, Name, SBQQ__Description__c, SBQQ__Number__c,
                           External__c, Joint_Venture_Line_Items__c, SBQQ__Optional__c
                    FROM SBQQ__QuoteLineGroup__c
                    WHERE SBQQ__Quote__c = :srcPrimaryQuote.Id
                    ORDER BY SBQQ__Number__c ASC NULLS LAST
                ];
                Map<Id, Id> groupIdMap = new Map<Id, Id>();
                List<SBQQ__QuoteLineGroup__c> newGroups = new List<SBQQ__QuoteLineGroup__c>();
                for (SBQQ__QuoteLineGroup__c g : srcGroups) {
                    SBQQ__QuoteLineGroup__c ng = g.clone(false, true, false, false);
                    ng.SBQQ__Quote__c = newQuote.Id;
                    newGroups.add(ng);
                }
                if (!newGroups.isEmpty()) insert newGroups;
                for (Integer i = 0; i < srcGroups.size(); i++) {
                    groupIdMap.put(srcGroups[i].Id, newGroups[i].Id);
                }
				system.debug('Test8');
                // --- 4) Clone Quote Lines (two-pass), but excluding product families
                List<SBQQ__QuoteLine__c> srcLines = [
                    SELECT Id, Name, SBQQ__Number__c, CurrencyIsoCode,
                           SBQQ__Product__c, SBQQ__Quantity__c, Unit_Price__c,
                           SBQQ__RegularPrice__c, SBQQ__ListPrice__c, SBQQ__Discount__c,
                           SBQQ__AdditionalDiscountAmount__c, SBQQ__AdditionalDiscount__c,
                           SBQQ__DiscountSchedule__c, SBQQ__SubscriptionTerm__c, SBQQ__ProrateMultiplier__c,
                           SBQQ__StartDate__c, SBQQ__EndDate__c, SBQQ__RequiredBy__c, SBQQ__Bundle__c,
                           SBQQ__Group__c, SBQQ__PriceEditable__c,
                           Shell__c, SBQQ__Hidden__c, SBQQ__PricingMethodEditable__c, SBQQ__CostEditable__c,
                           Cost_Type__c, SBQQ__PricingMethod__c,
                           SBQQ__ProductOption__c, SBQQ__OptionLevel__c, SBQQ__OptionType__c,
                           SBQQ__DynamicOptionId__c, SBQQ__Bundled__c,
                           /* EXCLUSION + CARRY fields */
                           SBQQ__ProductFamily__c,
                           Required_By_Product_Family__c,
                           Unit__c,
                           SBQQ__Description__c,
                           SBQQ__DefaultSubscriptionTerm__c
                    FROM SBQQ__QuoteLine__c
                    WHERE SBQQ__Quote__c = :srcPrimaryQuote.Id
                      AND (
                          SBQQ__ProductFamily__c = null
                          OR (
                              SBQQ__ProductFamily__c != 'Operations'
                              AND SBQQ__ProductName__c != 'Change Order: Return Transportation'
                              AND SBQQ__ProductName__c != 'Change Order: Installation'
                              AND SBQQ__ProductName__c != 'Change Order: Transportation'
                              AND Trans_Category__c != 'Carry On'
                              AND Trans_Category__c != 'Installation'
                              AND Trans_Category__c != 'Return'
                              AND Trans_Category__c != 'Dismantle'
                              AND Trans_Category__c != 'Delivery'
                              AND Trans_Category__c != 'Miscellaneous'
                          )
                      )
                      AND (Required_By_Product_Family__c = null OR Required_By_Product_Family__c != 'Operations')
                    ORDER BY SBQQ__Number__c ASC
                ];

                List<SBQQ__QuoteLine__c> newLines = new List<SBQQ__QuoteLine__c>();
                Map<Id, Id> lineIdMap = new Map<Id, Id>();

                // pass 1 – insert copies with RequiredBy cleared; remap groups; clear pricing fields
                for (SBQQ__QuoteLine__c l : srcLines) {
                    SBQQ__QuoteLine__c nl = l.clone(false, true, false, false);
                    nl.SBQQ__Quote__c      = newQuote.Id;
                    nl.SBQQ__RequiredBy__c = null; // will set in pass 2
                    if (l.SBQQ__Group__c != null) {
                        nl.SBQQ__Group__c = groupIdMap.get(l.SBQQ__Group__c);
                    }
					system.debug('Test9');
                    // Carry Over Info
                    nl.Unit__c                        = l.Unit__c;
                    nl.SBQQ__Description__c           = l.SBQQ__Description__c;
                    nl.SBQQ__ProductOption__c         = l.SBQQ__ProductOption__c;
                    nl.SBQQ__OptionLevel__c           = l.SBQQ__OptionLevel__c;
                    nl.SBQQ__OptionType__c            = l.SBQQ__OptionType__c;
                    nl.SBQQ__DynamicOptionId__c       = l.SBQQ__DynamicOptionId__c;
                    nl.SBQQ__Bundle__c                = l.SBQQ__Bundle__c;
                    nl.SBQQ__Bundled__c               = l.SBQQ__Bundled__c;
                    nl.Shell__c                       = l.Shell__c;
                    nl.SBQQ__Hidden__c                = l.SBQQ__Hidden__c;
                    nl.SBQQ__PricingMethod__c         = l.SBQQ__PricingMethod__c;
                    nl.SBQQ__PricingMethodEditable__c = l.SBQQ__PricingMethodEditable__c;
                    nl.SBQQ__CostEditable__c          = l.SBQQ__CostEditable__c;
                    nl.Cost_Type__c                   = l.Cost_Type__c;
                    nl.Unit_Price__c                  = l.Unit_Price__c;
                    nl.SBQQ__DefaultSubscriptionTerm__c = l.SBQQ__DefaultSubscriptionTerm__c;

                    // Let Price Rules & calculator recompute values
                    nl.SBQQ__RegularPrice__c            = null;
                    // nl.SBQQ__ListPrice__c           = null;
                    nl.SBQQ__Discount__c                = null;
                    nl.SBQQ__AdditionalDiscountAmount__c = null;

                    // If allowed, make price editable so rules can set values
                    nl.SBQQ__PriceEditable__c = true;

                    newLines.add(nl);
                }
                if (!newLines.isEmpty()) insert newLines;
                for (Integer i = 0; i < srcLines.size(); i++) {
                    lineIdMap.put(srcLines[i].Id, newLines[i].Id);
                }

                // pass 2 – restore RequiredBy
                List<SBQQ__QuoteLine__c> toUpdate = new List<SBQQ__QuoteLine__c>();
                for (Integer i = 0; i < srcLines.size(); i++) {
                    Id oldParent = srcLines[i].SBQQ__RequiredBy__c;
                    if (oldParent != null && lineIdMap.containsKey(oldParent)) {
                        toUpdate.add(new SBQQ__QuoteLine__c(
                            Id = newLines[i].Id,
                            SBQQ__RequiredBy__c = lineIdMap.get(oldParent)
                        ));
                    }
                }
                if (!toUpdate.isEmpty()) update toUpdate;

                // --- 5) Benign update to nudge managed logic (calculator/price rules often run on update)
                update new SBQQ__Quote__c(
                    Id = newQuote.Id,
                    SBQQ__Status__c = 'Draft'
                );

                // --- 6) Optionally copy Files from original Opp and Quote
                if (copyFiles == true) {

                    List<ContentDocumentLink> srcLinks = new List<ContentDocumentLink>();

                     // ContentDocumentLink SOQL restriction: filter by a SINGLE Id (no IN, no OR)
                     srcLinks.addAll([
                        SELECT ContentDocumentId, ShareType, Visibility
                        FROM ContentDocumentLink
                        WHERE LinkedEntityId = :srcOpp.Id
                    ]);

                if (srcPrimaryQuote != null) {
                     srcLinks.addAll([
                    SELECT ContentDocumentId, ShareType, Visibility
                     FROM ContentDocumentLink
                    WHERE LinkedEntityId = :srcPrimaryQuote.Id
                ]);
            }

        List<ContentDocumentLink> newLinks = new List<ContentDocumentLink>();

            for (ContentDocumentLink l : srcLinks) {
                // Decide which new parent to attach to based on which source record the link came from.
                // Since LinkedEntityId isn't selected, infer by re-query approach:
                // Easiest: re-run with two lists OR include LinkedEntityId in the SELECT (recommended).
            }
        }

            }

            // --- Success
            RenewalResult res = new RenewalResult();
            res.newOpportunityId = newOpp.Id;
            res.newQuoteId       = newQuoteId;
            res.message          = 'Renewal created successfully';
            return res;

        } catch (Exception e) {
            Database.rollback(sp);
            throw new AuraHandledException('Could not create renewal: ' + e.getMessage());
        }
    }
}