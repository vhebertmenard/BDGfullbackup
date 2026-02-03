@isTest
public class SearchInVFControllerTest {
   @isTest static void SearchInVFControllerTest(){
        Lead l = new Lead();
        l.Business_Line__c = 'AUS - Additional Services';
        l.FirstName = 'test';
        l.LastName = 'test';
        l.Opportunity_Postal_Code__c = '00000';
        insert l;
       
        help_article__c ha = new help_article__c();
        ha.Name = 'Test';
        ha.URL__c = 'google.com';
        ha.Topic__c = 'Lead';
        insert ha;
       
       Test.StartTest();
       apexpages.currentpage().getparameters().put('Id',string.valueOf(l.Id)) ;
       SearchInVFController sv = new SearchInVFController();
       sv.search();
       sv.clear();
       Test.Stoptest();
    }
    

}