@isTest(seealldata = true)
public class FleetCountTriggerHandlerTest {
    @isTest
    public static void testMethod1(){
      list<SBQQ__QuoteLine__c> lstquote =  [select Id,Contract_Expired__c,Unit__c,Primary_Quote__c, Renewal_Quote_Line__c from SBQQ__QuoteLine__c where Renewal_Quote_Line__c = true AND Contract_Expired__c = false AND Primary_Quote__c = true  limit 1];
        if(!lstquote.isEmpty()){
            SBQQ__QuoteLine__c SS = new SBQQ__QuoteLine__c();
            SS.Id = lstquote[0].Id;
           SS.Unit__c = 'a0CI90000005xTkMAI';
            update SS;
            
		} 
    }
	@isTest
    public static void testMethod2(){
      list<SBQQ__QuoteLine__c> lstquote =  [select Id,Name,Contract_Expired__c,Unit__c,Primary_Quote__c, Renewal_Quote_Line__c from SBQQ__QuoteLine__c where Renewal_Quote_Line__c = true AND Contract_Expired__c = false AND Primary_Quote__c = true  limit 1];
        string QName;
       if(!lstquote.isEmpty()){
           QName = lstquote[0].Name;
            delete lstquote;
		}
        list<SBQQ__QuoteLine__c> lstdel = [select Id from SBQQ__QuoteLine__c where Name =:QName ALL ROWS ];
        undelete lstdel;
    }
    
}