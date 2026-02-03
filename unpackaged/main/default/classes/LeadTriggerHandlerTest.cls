@isTest(seealldata=false)
public class LeadTriggerHandlerTest {
    @isTest static void LeadTriggerHandlerMethod(){
        Sales_Region_Code_Junction__c srj = new Sales_Region_Code_Junction__c();
        //srj.Sales_Region__c = 'a2F7d000000i1RoEAI';
        srj.Sales_Region__c = 'a2F4u000002xhF9EAI';
        //srj.Sales_Region_Code__c = 'a2H7d000001uBRWEA2';
        srj.Sales_Region_Code__c = 'a2E4u000002mMa0EAE';
        insert srj;
        
        Sales_Region__c sr = new Sales_Region__c();
        sr.Name = 'Name';
        //sr.Inside_Sales_Rep__c = '0054u0000071Snu';
        sr.Inside_Sales_Rep__c = '0050g00000674gdAAA';
        sr.AD_Distribution_Group__c = 'test@test.com';
        insert sr;
        
        
        Lead l = new Lead();
        l.Business_Line__c = 'MSS';
        l.FirstName = 'test';
        l.LastName = 'test';
        l.Opportunity_City__c = 'XYZ';
        l.Opportunity_Street__c = 'XYZ Street';
        l.Opportunity_Postal_Code__c = 'T0J123';
        l.PostalCode = 'T0J123';
        l.CountryCode = 'CA';
        //l.RecordTypeId = '0127d0000005jdJAAQ';
        l.RecordTypeId = '0124u000000gtAYAAY';
        l.LeadSource = '360MobileOffice';
        //l.Website_Source__c = 'Vanguard';
        //l.Sales_Region_Code__c = '01865';
        l.Opportunity_Country__c = 'CA';
        insert l;
        
        Lead l2 = new Lead();
        l2.Business_Line__c = 'MSS';
        l2.FirstName = 'test1';
        l2.LastName = 'test1';
        l2.Opportunity_City__c = 'XYZ';
        l2.Opportunity_Street__c = 'XYZ Street';
        l2.Opportunity_Postal_Code__c = '01865';
        l2.PostalCode = '01865';
        l2.CountryCode = 'US';
        //l2.RecordTypeId = '0127d0000005jdJAAQ';
        l2.RecordTypeId = '0124u000000gtAYAAY';
        l2.LeadSource = '360MobileOffice';
        //l2.Website_Source__c = 'Vanguard';
        //l.Sales_Region_Code__c = '01865';
        l2.Opportunity_Country__c = 'US';
        insert l2;

		Lead l3 = new Lead();
        l3.FirstName = 'test3';
        l3.LastName = 'test3';
        l3.Opportunity_City__c = 'XYZ';
        l3.Opportunity_Street__c = 'XYZ Street';
        l3.Opportunity_Postal_Code__c = '01865';
        l3.PostalCode = '01865';
        l3.CountryCode = 'US';
        l3.leadsource = 'Website';
        l3.Website_Source__c = 'BOXXUS Website';
        l3.Lead_Source_Detail__c = 'Live Chat';
        //l2.RecordTypeId = '0127d0000005jdJAAQ';
        //l3.RecordTypeId = '0124u000000gtAYAAY';
        //l.Sales_Region_Code__c = '01865';
        l3.Opportunity_Country__c = 'US';
        insert l3;
    }

}