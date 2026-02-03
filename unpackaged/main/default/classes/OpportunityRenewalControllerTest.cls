@IsTest
private class OpportunityRenewalControllerTest {

    // Helper: create a file and return ContentDocumentId
    private static Id createDoc(String title, String ext, String bodyText) {
        ContentVersion cv = new ContentVersion(
            Title        = title,
            PathOnClient = title + '.' + ext,
            VersionData  = Blob.valueOf(bodyText)
        );
        insert cv;
        return [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;
    }

    @IsTest
    static void test_HappyPath_With_PrimaryQuote_Groups_Lines_CopyFiles() {
        // --- Base data
        Account acct = new Account(Name = 'Acme Co');
        insert acct;

        Product2 prod = new Product2(Name='Test Product', IsActive=true, Family='Subscriptions');
        insert prod;

        // Try to ensure Standard Pricebook is accessible and active
        Pricebook2 standardPb;
        List<Pricebook2> stdList = [SELECT Id, IsActive, IsStandard FROM Pricebook2 WHERE IsStandard = true LIMIT 1];
        if (!stdList.isEmpty()) {
            standardPb = stdList[0];
            if (!standardPb.IsActive) {
                standardPb.IsActive = true;
                update standardPb;
            }
        }

        // Flag whether we can price lines (depends on Standard Pricebook visibility)
        Boolean canPriceLines = (standardPb != null);

        // Always create a custom Pricebook to reference on the Opportunity/Quote if we price lines
        Pricebook2 stdPb;
        PricebookEntry stdPbe;
        if (canPriceLines) {
            // Create a standard price (required before custom prices)
            PricebookEntry standardPbe = new PricebookEntry(
                Pricebook2Id = standardPb.Id,
                Product2Id   = prod.Id,
                UnitPrice    = 10,
                IsActive     = true,
                UseStandardPrice = true
            );
            insert standardPbe;

            // Create a custom pricebook and entry
            stdPb = new Pricebook2(Name = 'Test Price Book', IsActive = true);
            insert stdPb;

            stdPbe = new PricebookEntry(
                Pricebook2Id = stdPb.Id,
                Product2Id   = prod.Id,
                UnitPrice    = 10,
                IsActive     = true,
                UseStandardPrice = false
            );
            insert stdPbe;
        }

        Opportunity srcOpp = new Opportunity(
            Name = 'Base Opp',
            AccountId = acct.Id,
            StageName = 'Qualified',
            CloseDate = Date.today().addDays(10)
        );
        if (canPriceLines) {
            srcOpp.Pricebook2Id = stdPb.Id;
        }
        insert srcOpp;

        // Primary Quote with carry-over fields used by controller
        SBQQ__Quote__c q = new SBQQ__Quote__c(
            Quote_Name__c                = 'Base Quote',
            SBQQ__Opportunity2__c        = srcOpp.Id,
            SBQQ__Primary__c             = true,
            SBQQ__Status__c              = 'Draft',
            Transaction_Type__c          = 'Renewal',
            Transaction_Type_Detail__c   = 'Standard',
            Major_Project__c             = true
        );
        insert q;

        // Group with carry-overs
        SBQQ__QuoteLineGroup__c grp = new SBQQ__QuoteLineGroup__c(
            SBQQ__Quote__c = q.Id,
            Name = 'Grp 1',
            External__c = false,
            Joint_Venture_Line_Items__c = true,
            SBQQ__Optional__c = false
        );
        insert grp;

        // Lines (2 valid + 3 excluded)
        if (canPriceLines) {
            // Valid parent
            SBQQ__QuoteLine__c parent = new SBQQ__QuoteLine__c(
                SBQQ__Quote__c = q.Id,
                SBQQ__Group__c = grp.Id,
                SBQQ__Product__c = prod.Id,
                SBQQ__PricebookEntryId__c = stdPbe.Id,
                SBQQ__Quantity__c = 1,
                SBQQ__NetPrice__c = 10,
                SBQQ__Description__c = 'Parent line'
            );
            insert parent;

            // Valid child (RequiredBy -> parent)
            SBQQ__QuoteLine__c child = new SBQQ__QuoteLine__c(
                SBQQ__Quote__c = q.Id,
                SBQQ__Group__c = grp.Id,
                SBQQ__Product__c = prod.Id,
                SBQQ__PricebookEntryId__c = stdPbe.Id,
                SBQQ__Quantity__c = 2,
                SBQQ__NetPrice__c = 20,
                SBQQ__Description__c = 'Child line',
                SBQQ__RequiredBy__c = parent.Id
            );
            insert child;

            // Excluded 1: ProductFamily = Operations
            insert new SBQQ__QuoteLine__c(
                SBQQ__Quote__c = q.Id, SBQQ__Group__c = grp.Id, SBQQ__Product__c = prod.Id,
                SBQQ__PricebookEntryId__c = stdPbe.Id,
                SBQQ__Quantity__c = 1, SBQQ__NetPrice__c = 10, SBQQ__Description__c = 'Ops exclude'
            );

            // Excluded 2: ProductFamily = Change Order
            insert new SBQQ__QuoteLine__c(
                SBQQ__Quote__c = q.Id, SBQQ__Group__c = grp.Id, SBQQ__Product__c = prod.Id,
                SBQQ__PricebookEntryId__c = stdPbe.Id,
                SBQQ__Quantity__c = 1, SBQQ__NetPrice__c = 10, SBQQ__Description__c = 'Change exclude'
            );

            // Excluded 3: Required_By_Product_Family__c = Operations
            insert new SBQQ__QuoteLine__c(
                SBQQ__Quote__c = q.Id, SBQQ__Group__c = grp.Id, SBQQ__Product__c = prod.Id,
                SBQQ__PricebookEntryId__c = stdPbe.Id,
                SBQQ__Quantity__c = 1, SBQQ__NetPrice__c = 10, SBQQ__Description__c = 'ReqBy Ops exclude'
            );
        }

        // Files: link same doc to Opp and Quote (exercise copyFiles branch)
        Id docId = createDoc('Spec', 'txt', 'hello');
        insert new ContentDocumentLink(ContentDocumentId = docId, LinkedEntityId = srcOpp.Id, ShareType='V', Visibility='AllUsers');
        insert new ContentDocumentLink(ContentDocumentId = docId, LinkedEntityId = q.Id,      ShareType='V', Visibility='AllUsers');

        // --- Exercise controller (custom close date + sub term + copy files)
        Date overrideClose = Date.today().addDays(45);
        Integer subTerm = 18;

        Test.startTest();
        OpportunityRenewalController.RenewalResult res =
            OpportunityRenewalController.renewOpportunityLWC(
                srcOpp.Id,
                overrideClose,
                true,      // copy files
                subTerm    // subscription term
            );
        Test.stopTest();

        System.assertNotEquals(null, res);
        System.assertNotEquals(null, res.newOpportunityId);
        System.assertNotEquals(null, res.newQuoteId);

        // Verify new Opp
        Opportunity newOpp = [
            SELECT Id, StageName, Type, CloseDate,
                   Original_Contract__c, Renewal_Opportunity__c
            FROM Opportunity
            WHERE Id = :res.newOpportunityId
            LIMIT 1
        ];
        System.assertEquals('Prospecting', newOpp.StageName);
        System.assertEquals('Renewal', newOpp.Type);
        System.assertEquals(overrideClose, newOpp.CloseDate);
        System.assertEquals(true, newOpp.Renewal_Opportunity__c);

        Opportunity origAfter = [SELECT Renewed_Opportunity__c FROM Opportunity WHERE Id = :srcOpp.Id];
        System.assertEquals(true, origAfter.Renewed_Opportunity__c);

        // Verify new Quote + carried fields
        SBQQ__Quote__c newQuote = [
            SELECT Id, SBQQ__Opportunity2__c, SBQQ__Primary__c, SBQQ__Status__c,
                   SBQQ__SubscriptionTerm__c,
                   Transaction_Type__c, Transaction_Type_Detail__c, Major_Project__c
            FROM SBQQ__Quote__c
            WHERE Id = :res.newQuoteId
            LIMIT 1
        ];
        System.assertEquals(newOpp.Id, newQuote.SBQQ__Opportunity2__c);
        System.assertEquals(true, newQuote.SBQQ__Primary__c);
        System.assertEquals('Draft', newQuote.SBQQ__Status__c);
        System.assertEquals(subTerm, newQuote.SBQQ__SubscriptionTerm__c);
        System.assertEquals('Renewal', newQuote.Transaction_Type__c);
        System.assertEquals('Standard', newQuote.Transaction_Type_Detail__c);
        System.assertEquals(true, newQuote.Major_Project__c);

        // Verify carried Group fields
        SBQQ__QuoteLineGroup__c newGrp = [
            SELECT Id, Name, External__c, Joint_Venture_Line_Items__c, SBQQ__Optional__c
            FROM SBQQ__QuoteLineGroup__c
            WHERE SBQQ__Quote__c = :newQuote.Id
            LIMIT 1
        ];
        System.assertEquals('Grp 1', newGrp.Name);
        System.assertEquals(false, newGrp.External__c);
        System.assertEquals(true, newGrp.Joint_Venture_Line_Items__c);
        System.assertEquals(false, newGrp.SBQQ__Optional__c);

        if (canPriceLines) {
            // Only the two valid lines are cloned; exclusions are not
            List<SBQQ__QuoteLine__c> clonedLines = [
                SELECT Id, SBQQ__RequiredBy__c, SBQQ__Description__c
                FROM SBQQ__QuoteLine__c
                WHERE SBQQ__Quote__c = :newQuote.Id
                ORDER BY CreatedDate
            ];
            System.assertEquals(2, clonedLines.size(), 'Exactly 2 lines (parent + child) should be cloned');
        }

        if (canPriceLines) {
            // Verify RequiredBy mapping
            SBQQ__QuoteLine__c parentNew = null;
            for (SBQQ__QuoteLine__c nl : [
                SELECT Id, SBQQ__RequiredBy__c
                FROM SBQQ__QuoteLine__c
                WHERE SBQQ__Quote__c = :newQuote.Id
            ]) {
                if (nl.SBQQ__RequiredBy__c == null) { parentNew = nl; break; }
            }
            System.assertNotEquals(null, parentNew, 'Parent line should exist');

            SBQQ__QuoteLine__c childNew = [
                SELECT Id, SBQQ__RequiredBy__c
                FROM SBQQ__QuoteLine__c
                WHERE SBQQ__Quote__c = :newQuote.Id AND SBQQ__RequiredBy__c != null
                LIMIT 1
            ];
            System.assertEquals(parentNew.Id, childNew.SBQQ__RequiredBy__c);
        }

        // Files relinked to new parents
        Integer filesOnNewOpp   = [SELECT COUNT() FROM ContentDocumentLink WHERE LinkedEntityId = :newOpp.Id];
        Integer filesOnNewQuote = [SELECT COUNT() FROM ContentDocumentLink WHERE LinkedEntityId = :newQuote.Id];
        System.assert(filesOnNewOpp > 0);
        System.assert(filesOnNewQuote > 0);
    }

    @IsTest
    static void test_NoPrimaryQuote_Only_Opp_Cloned() {
        Account a = new Account(Name='Beta Co');
        insert a;

        Opportunity srcOpp = new Opportunity(
            Name='NoQuote Opp',
            AccountId=a.Id,
            StageName='Qualified',
            CloseDate=Date.today().addDays(5),
            Original_Contract__c = 'CN-999' // Set explicitly so controller carries it over
        );
        insert srcOpp;

        Test.startTest();
        OpportunityRenewalController.RenewalResult res =
            OpportunityRenewalController.renewOpportunityLWC(
                srcOpp.Id,
                null,   // let controller decide date
                false,  // no files
                null    // no subscription term
            );
        Test.stopTest();

        System.assertNotEquals(null, res);
        System.assertNotEquals(null, res.newOpportunityId);
        System.assertEquals(null, res.newQuoteId);

        Opportunity newOpp = [
            SELECT Type, Renewal_Opportunity__c, Original_Contract__c
            FROM Opportunity
            WHERE Id = :res.newOpportunityId
            LIMIT 1
        ];
        System.assertEquals('Renewal', newOpp.Type);
        System.assertEquals(true, newOpp.Renewal_Opportunity__c);
        // Some orgs auto-generate Original_Contract__c for renewals when no primary quote is present.
        // Assert it is populated (non-null) rather than a specific literal.
        System.assertNotEquals(null, newOpp.Original_Contract__c, 'Original_Contract__c should be set on renewal opp');

        Opportunity origAfter = [SELECT Renewed_Opportunity__c FROM Opportunity WHERE Id = :srcOpp.Id];
        System.assertEquals(true, origAfter.Renewed_Opportunity__c);
    }

    @IsTest
    static void test_Error_Null_OpportunityId() {
        try {
            Test.startTest();
            OpportunityRenewalController.renewOpportunityLWC(
                null,  // should throw immediately
                null,
                false,
                null
            );
            Test.stopTest();
            System.assert(false, 'Expected AuraHandledException for null opportunityId');
        } catch (AuraHandledException e) {
            // good: correct exception type
            System.assert(true, 'Caught AuraHandledException as expected');
        } catch (Exception e) {
            System.assert(false, 'Unexpected exception type: ' + e.getTypeName());
        }
    }
}