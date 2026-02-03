public class LeadTriggerHandler {
    public static void leadHandler(list<lead> Newlead){
        try{
            
            
            set<string> zipCode = new set<string>();
        	set<string> businessLine = new set<string>();
       	 	Map<string,Sales_Region_Code_Junction__c> newMaplead = new map<string,Sales_Region_Code_Junction__c>();
        	for(Lead lead:Newlead){	
                System.debug('DEBUG INFORMATION:');
                System.debug('Lead ID: '+lead.Id);
                System.debug('Lead Country: '+Lead.Country);
                System.debug('Lead Country Code: '+Lead.CountryCode);
                System.debug('Lead State: '+Lead.State);
                System.debug('Lead State Code: '+Lead.StateCode);
                System.debug('Zip Code'+Lead.PostalCode+'/ '+Lead.Postal_Code__c);
                System.debug('Lead Record Type ID: '+Lead.RecordTypeId);
                System.debug('Lead Brand Code: '+Lead.Brand_Code__c);
                System.debug('Lead Business Line: '+Lead.Business_Line__c);
                System.debug('Lead Sales Region Code: '+Lead.Sales_Region_Code__c);
                System.debug('Lead Site/Postal Code: '+Lead.Opportunity_Postal_Code__c);
                System.debug('Lead  Site Country: '+Lead.Opportunity_Country__c);
                System.debug('Email Opt in: '+Lead.Email_Opt_In__c);
                System.debug('Email Opt Out: '+Lead.HasOptedOutOfEmail);
                System.debug('Site Province/State: '+Lead.Opportunity_Province_State_Territory__c);

                System.debug('Lead Business Line: '+Lead.Business_Line__c);
                if((lead.PostalCode == ''||lead.PostalCode	== null) && (lead.Opportunity_Postal_Code__c != null || lead.Opportunity_Postal_Code__c != '')){
                    lead.PostalCode = lead.Opportunity_Postal_Code__c;
                }
                
  				/*if((lead.Vanguard_State__c == ''||lead.Vanguard_State__c	== null) && (lead.Opportunity_Province_State_Territory__c != null || lead.Opportunity_Province_State_Territory__c != '')){
                    lead.Vanguard_State__c = lead.Opportunity_Province_State_Territory__c;
                }*/
                
                /*if((Lead.State == ''||Lead.State == null) && (lead.Opportunity_Province_State_Territory__c != null || lead.Opportunity_Province_State_Territory__c != '')){
                    lead.State = lead.Opportunity_Province_State_Territory__c;
                }*/
                
                if((lead.City == ''||lead.City	== null) && (lead.Opportunity_City__c != null || lead.Opportunity_City__c != '')){
                    lead.City = lead.Opportunity_City__c;
                }

                
                if((lead.Street == ''||lead.Street	== null) && (lead.Opportunity_Street__c != null || lead.Opportunity_Street__c != '')){
                    lead.Street = lead.Opportunity_Street__c;
                }
                
                if((lead.Delivery_ZIP_Code__c == ''||lead.Delivery_ZIP_Code__c	== null) && (lead.Opportunity_Postal_Code__c != null || lead.Opportunity_Postal_Code__c != '') &&(lead.Website_Source__c == 'Vanguard')){
                    lead.Delivery_ZIP_Code__c = lead.Opportunity_Postal_Code__c;
                
                }//if the website source is vanguard, populating the delivery zip code field and the Vanguard state field
                
                if(lead.RecordTypeID == '0124u000000gtAYAAY'){
                    lead.Brand_Code__c = 'Vanguard';
                    lead.Business_Line__c = 'Vanguard';
                    lead.Sales_Region_Code__c = lead.PostalCode;
                    lead.Delivery_ZIP_Code__c = lead.PostalCode;
                    lead.CountryCode = 'US';
                    lead.CurrencyIsoCode = 'USD';
                    system.debug(Lead.Opportunity_Country__c);
                    system.debug( lead.CountryCode);
                                
                }
             
                
                if(lead.leadSource == '360MobileOffice'){
                     lead.Sales_Region_Code__c = lead.PostalCode;
                     lead.Opportunity_Postal_Code__c = lead.PostalCode;
                     lead.Delivery_ZIP_Code__c = lead.PostalCode;
                     lead.Opportunity_Province_State_Territory__c = lead.StateCode;
                     lead.Opportunity_City__c = lead.City;
                     lead.CountryCode = 'US';
                }
                
                 if(lead.Website_Source__c == 'BOXXUS Website' && lead.Lead_Source_Detail__c == 'Live Chat'){
                     lead.Sales_Region_Code__c = lead.Opportunity_Postal_Code__c;
                     //lead.Opportunity_Postal_Code__c = lead.PostalCode;
                     lead.Delivery_ZIP_Code__c = lead.PostalCode;
                     lead.Business_Line__c = 'MSS';
                     //lead.Opportunity_Province_State_Territory__c = lead.StateCode;
                     //lead.Opportunity_City__c = lead.City;
                     lead.Brand_Name__c = 'a2B4u000006XprQEAS';
                     lead.CountryCode = 'US';
                }
                
                if((lead.Opportunity_Country__c == '' || lead.Opportunity_Country__c == null)&&(lead.CountryCode != ''||lead.CountryCode != null)){
                    lead.Opportunity_Country__c = lead.CountryCode;
                }
                
				system.debug('Enter For'+lead.Sales_Region_Code__c+', '+lead.Business_Line__c+', '+lead.Opportunity_Country__c+' '+lead.RecordTypeId);            
            	if(lead.Sales_Region_Code__c != null && lead.Sales_Region_Code__c != ''
               		&& lead.Business_Line__c != null &&  lead.Business_Line__c != '' && (lead.Opportunity_Country__c.toUpperCase() == 'CA'||lead.Opportunity_Country__c.toUpperCase() == 'Canada')
                    &&(lead.Business_Line__c !='WFS_CA')&&(lead.Business_Line__c !='WFS_US')&&(lead.Business_Line__c !='ES CA')){
                  	 zipCode.add(lead.Sales_Region_Code__c.substring(0,3).toUpperCase());
                   	businessLine.add(lead.Business_Line__c);
                   	system.debug('Zip Code is: '+zipCode);
             	}
                else
                    if(lead.Sales_Region_Code__c != null && lead.Sales_Region_Code__c != ''
               		&& lead.Business_Line__c != null &&  lead.Business_Line__c != '' && (lead.Opportunity_Country__c.toUpperCase() == 'US'||lead.Opportunity_Country__c.toUpperCase() == 'United States'||lead.Opportunity_Country__c.toUpperCase() == 'USA')
                       ){
                  	 zipCode.add(lead.Sales_Region_Code__c.substring(0,5).toUpperCase());
                   	businessLine.add(lead.Business_Line__c);
                   	system.debug('Zip Code is: '+zipCode);
             	}
            	else
                	if(lead.Sales_Region_Code__c != null && lead.Sales_Region_Code__c != ''
             			  && lead.Business_Line__c != null &&  lead.Business_Line__c != ''){
                  		 zipCode.add(lead.Sales_Region_Code__c);
                   		 businessLine.add(lead.Business_Line__c);
                  		 system.debug('Zip Code is: '+zipCode);
           		 }
                /*else
                  if(lead.leadSource == '360MobileOffice'){
              		  lead.Sales_Region_Code__c = lead.PostalCode;
                      lead.Delivery_ZIP_Code__c = lead.PostalCode;
                      zipCode.add(lead.Delivery_ZIP_Code__c);
                      businessLine.add(lead.Business_Line__c);
                      system.debug('Zip Code is: '+zipCode);
              }*/
           
			System.debug	(lead.CountryCode);
            System.debug    (lead.Province__c); 
            system.debug	(lead.Sales_Region_ID__c);
            System.debug	(lead.Business_Line__c);
        }
        for(Sales_Region_Code_Junction__c SRJUn:[select id,Sales_Region__r.Business_Line__c,Sales_Region__r.Name,Sales_Region_Code__r.Name,Sales_Region__r.Inside_Sales_Rep__r.Email,Sales_Region__r.Inside_Sales_Rep__r.Name,Sales_Region__r.AD_Distribution_Group__c from Sales_Region_Code_Junction__c
                                                     where  Sales_Region_Code__r.Name IN: zipCode and Sales_Region__r.Business_Line__c IN:businessLine  ]){
                                                         /* if(newMaplead.containsKey(SRJUn.Zip_Postal_Code__r.Name +SRJUn.Business_Line__c)){
lead ld = newMaplead.get(SRJUn.Zip_Postal_Code__r.Name +SRJUn.Business_Line__c);
ld.Sales_Region__c = SRJUn.Sales_Region__r.Name;
}*/
                                                       system.debug(SRJUn.Sales_Region_Code__r.Name+SRJUn.Sales_Region__r.Business_Line__c );
                                                         newMaplead.put(SRJUn.Sales_Region_Code__r.Name+SRJUn.Sales_Region__r.Business_Line__c , SRJUn);
                                                         system.debug(newMaplead);
                                                         
         }
            system.debug('test0');
        for(lead ld:Newlead){
            string ldZip;
            if(ld.Opportunity_Country__c == 'CA' && ld.Business_Line__c != 'WFS_CA'&& ld.Business_Line__c != 'WFS_US' && ld.Business_Line__c != 'ES CA'){
                ldZip = ld.Sales_Region_Code__c.substring(0,3).toUpperCase();
            } 
            else
            if(ld.Sales_Region_Code__c != null && ld.Sales_Region_Code__c != ''
               	&& ld.Business_Line__c != null &&  ld.Business_Line__c != '' && (ld.Opportunity_Country__c.toUpperCase() == 'US'||ld.Opportunity_Country__c.toUpperCase() == 'United States'||ld.Opportunity_Country__c.toUpperCase() == 'USA')
               ){
                  	ldZip = ld.Sales_Region_Code__c.substring(0,5).toUpperCase();
             	}
            else
			ldZip = ld.Sales_Region_Code__c;	
            if(newMaplead.containsKey(ldZip+ld.Business_Line__c)){
                system.debug(ldZip+ld.Business_Line__c);
                ld.Sales_Region__c = newMaplead.get(ldZip+ld.Business_Line__c).Sales_Region__r.Name;
                ld.Sales_Region_ID__c = newMaplead.get(ldZip+ld.Business_Line__c).Sales_Region__r.Id;
                ld.Inside_Sales_Rep_Email__c = newMaplead.get(ldZip+ld.Business_Line__c).Sales_Region__r.Inside_Sales_Rep__r.Email;
                ld.AD_Distribution_Group__c = newMaplead.get(ldZip+ld.Business_Line__c).Sales_Region__r.AD_Distribution_Group__c;
                
            }else{
                ld.Sales_Region__c = '';
                system.debug('test2');
            }
        }
            
        }catch(exception e){
            
            system.debug('8lead error88'+e.getStackTraceString())                                                                                                               ;
            
        }
        
        
    }
}