trigger FleetCount on SBQQ__QuoteLine__c (after insert, after update, after delete,before delete, after undelete) {
   
    
        
        if(Trigger.isInsert && Trigger.isAfter){
            List<String> FleetList = New List<String>();
            For(SBQQ__QuoteLine__c QL : Trigger.New){
                if(!QL.Contract_Expired__c && QL.Unit__c != null && QL.Primary_Quote__c == TRUE && QL.Renewal_Quote_Line__c){
                    FleetList.add(QL.Unit__c);
                }
            }
            if(!FleetList.isEmpty()){
                FleetCountTriggerHandler.fleetCountAfterInsert(FleetList);
            }
        }
        if(Trigger.isupdate && Trigger.isAfter){
            List<String> FleetList = New List<String>();
            List<String> OldFleetList = New List<String>();
            For(SBQQ__QuoteLine__c QL : Trigger.New){
                system.debug('**QL**'+QL);
                system.debug('**New**'+QL.Unit__c +'**Old**'+ trigger.oldMap.get(QL.Id).Unit__c);
                if((QL.Contract_Expired__c != trigger.oldMap.get(QL.Id).Contract_Expired__c  || QL.Unit__c != trigger.oldMap.get(QL.Id).Unit__c)&& QL.Primary_Quote__c == TRUE && !QL.Contract_Expired__c && QL.Renewal_Quote_Line__c){
                    system.debug('**QL**'+QL);
                    FleetList.add(QL.Unit__c);
                    OldFleetList.add(trigger.oldMap.get(QL.Id).Unit__c);
                }
            }
            if(!FleetList.isEmpty()){
                FleetCountTriggerHandler.fleetCountAfterInsert(FleetList);
            }
            if(!OldFleetList.isEmpty()){
                FleetCountTriggerHandler.fleetCountAfterUpdateOld(OldFleetList);
            }
        }
        if(Trigger.isDelete && Trigger.isBefore){
            List<String> FleetList = New List<String>();
            For(SBQQ__QuoteLine__c QL : Trigger.old){
                if(!QL.Contract_Expired__c && QL.Unit__c != null && QL.Primary_Quote__c == TRUE && QL.Renewal_Quote_Line__c){
                    FleetList.add(QL.Unit__c);
                }
            }
            if(!FleetList.isEmpty()){
                FleetCountTriggerHandler.fleetCountBeforeDelete(FleetList);
            }
        }
    if(Trigger.isundelete && Trigger.isAfter){
        List<String> FleetList = New List<String>();
            For(SBQQ__QuoteLine__c QL : Trigger.New){
                if(!QL.Contract_Expired__c && QL.Unit__c != null && QL.Primary_Quote__c == TRUE && QL.Renewal_Quote_Line__c){
                    FleetList.add(QL.Unit__c);
                }
            }
            if(!FleetList.isEmpty()){
                FleetCountTriggerHandler.fleetCountAfterInsert(FleetList);
            }
    }
       /* 
        // List<Unit__c> FleetList = new List<Fleet__C>();   
        Set<Id> QuoteLineids = new Set<Id>();
        
        if(Trigger.isDelete) {
            for(SBQQ__QuoteLine__c  test:Trigger.Old) {      
                QuoteLineids.add(test.Unit__c);   
            }      
        }
        
        else if(Trigger.isUpdate) {
            for(SBQQ__QuoteLine__c  test:Trigger.New) {    
                if(test.Unit__c != null){
                    QuoteLineids.add(test.Unit__c);     
                }   
            }
            
            for(SBQQ__QuoteLine__c  test:Trigger.Old) {      
                QuoteLineids.add(test.Unit__c);       
            }      
        }
        else{
            for(SBQQ__QuoteLine__c  test:Trigger.New) {      
                QuoteLineids.add(test.Unit__c);    
            }
        }
        
        AggregateResult[] groupedResults = [SELECT COUNT(Id), Unit__c FROM SBQQ__QuoteLine__c  
                                            where Unit__c IN :QuoteLineids GROUP BY Unit__c ];
        
        for(AggregateResult a:groupedResults) {     
            Id BId = (ID)a.get('Unit__c');     
            Integer count = (INTEGER)a.get('expr0');     
            Fleet__c objB = new Fleet__c();  
            objB.id=BId;
            objB.CountUsed__c  = count;     
            FleetList.add(objB.id);      
        }   
        
        //update FleetList.values();*/
   
    
}