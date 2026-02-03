public class SearchInVFController{

    public list <Help_Article__c> defaultArticles {get;set;}
    public list <Help_Article__c> searchArticles {get;set;}
    
    public String searchKey {get;set;}
    
    public String currentRecordId {get;set;}    
    public String topicName {get;set;}    
    
    public SearchInVFController( ) {   
        currentRecordId  = ApexPages.CurrentPage().getparameters().get('id');   

        switch on currentRecordId.substring(0,3) {
            when '001' { topicName = 'Account'; }
            when '003' { topicName = 'Contact'; }
            when '00Q' { topicName = 'Lead'; }
            when '006' { topicName = 'Opportunity'; }
            when 'a19' { topicName = 'Quote'; }
            when else { topicName = 'General'; }
        }

   
        string searchquery='select Name, URL__c, Topic__c from help_article__c where Topic__c includes (\''+ topicName +'\') Limit 10';
        defaultArticles = Database.query(searchquery);
    }
    
    public void search(){
        string searchquery='select Name, URL__C, Topic__c from help_article__c where name like \'%'+searchKey+'%\' OR Topic__c includes (\''+searchKey+'\') Limit 5';
        searchArticles = Database.query(searchquery);
    }
    
    public void clear(){
        searchArticles .clear();
        searchKey = '';
    }
}