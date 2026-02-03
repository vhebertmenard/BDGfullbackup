public class FleetCountTriggerHandler {
    public static void fleetCountAfterInsert(list<String> lstFleet){
		system.debug('***In the fleetCountAfterInsert method Performing Update/Insert***'+lstFleet);
        getFleetCount(lstFleet,'');
    }
     public static void fleetCountBeforeDelete(list<String> lstFleet){
        system.debug('***In the Before Delete method***'+lstFleet);
        getFleetCount(lstFleet,'Delete');
    }
    public static void fleetCountAfterUpdateOld(list<String> lstFleet){
        system.debug('***In the AfterUpdateOld method***'+lstFleet);
        getFleetCountOld(lstFleet,'Delete');
    }
    
    public static void getFleetCount(list<String> Fleetids,String action){
        system.debug('***'+fleetids+'***'+action);
        AggregateResult[] groupedResults = [SELECT COUNT(Id), Unit__c FROM SBQQ__QuoteLine__c  
                                            where Unit__c IN :Fleetids and Contract_Expired__c = false GROUP BY Unit__c ];
        system.debug('***'+groupedResults);
        list<Fleet__c> FleetList = new list<Fleet__c>();
        for(AggregateResult a:groupedResults) {     
            Id BId = (ID)a.get('Unit__c');  
            Integer count;
            if(action == 'Delete'){
              system.debug('***Setting Count to 0 on Delete Action***');
              count = 0;  
            }
            else{   
                system.debug('***Setting Count to 1 on Update/Insert Action***');
                count = 1;
            }
            if(BId!= null){
				Fleet__c objB = new Fleet__c(); 
            	objB.id=BId;
            	objB.CountUsed__c  = count;
            	system.debug('***objB***'+objB);			
           
            	FleetList.add(objB); 
			 }
        } 
        if(!FleetList.isEmpty()){
            update FleetList;
        }
    }
    
    public static void getFleetCountOld(list<String> Fleetids,String action){
        system.debug('***'+fleetids+'***'+action);
        AggregateResult[] groupedResults = [SELECT Id FROM Fleet__c  
                                            where Id IN :Fleetids GROUP BY Id];
        system.debug('***'+groupedResults);
        list<Fleet__c> FleetList = new list<Fleet__c>();
        for(AggregateResult a:groupedResults) {     
            Id BId = (ID)a.get('Id');  
            Integer count;
              system.debug('***Setting Count to 0 on removing old unit from the QL***');
              count = 0;  
            if(BId!= null){
				Fleet__c objB = new Fleet__c(); 
            	objB.id=BId;
            	objB.CountUsed__c  = count;
            	system.debug('***objB***'+objB);			
           
            	FleetList.add(objB); 
			 }
        } 
        if(!FleetList.isEmpty()){
            update FleetList;
        }
    }
}