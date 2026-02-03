@isTest(seealldata=false)
public class BrandTriggerHandlerTest{
   @isTest static void BrandTriggerHandlerMethod(){
        Brand__c b = new Brand__c();
        b.Name = 'BOXX Modular';
        b.Brand_Code__c = 'BOXX';
        insert b;
        
        Lead l = new Lead();
        l.Brand_Code__c = 'BOXX';
        l.FirstName = 'test';
        l.LastName = 'test';
        insert l;
    }
    

}