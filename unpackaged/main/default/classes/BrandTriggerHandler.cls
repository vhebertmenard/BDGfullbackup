public class BrandTriggerHandler {
	public static void brandHandler(list<lead> Newlead){
        try{
        	 	set<string> brandCode = new set<string>();
				Map<string,Brand__c> newMapBrand = new map<string,Brand__c>();
        		for(Lead lead:Newlead)
                {	
					system.debug('Enter For'+lead.Brand_Code__c);            
            		if(lead.Brand_Code__c != null && lead.Sales_Region_Code__c != '')
                    {
                  	 	brandCode.add(lead.Brand_Code__c);
                   		system.debug('Brand Code is: '+brandCode);
             		}
          		}
            
             for(Brand__c BR:[select id, Brand_Code__c from Brand__c
                  				where  Brand_Code__c IN: brandCode]){
                                                         system.debug(BR.Brand_Code__c );
                                                         newMapBrand.put(BR.Brand_Code__c , BR);
                                                         system.debug(newMapBrand);
                                                         
        	 }
            
            for(lead ld:Newlead){
            string ldBrand;
			ldBrand = ld.Brand_Code__c;	
            if(newMapBrand.containsKey(ldBrand)){
                system.debug(ldBrand);
                ld.Brand_Name__c = newMapBrand.get(ldBrand).Id;
            }else{
                ld.Brand_Name__c = '';
                system.debug('test2');
            }
        }
    
        
        }catch(exception e){
            
            system.debug('8lead error88'+e.getStackTraceString());
            
        }
    }
}