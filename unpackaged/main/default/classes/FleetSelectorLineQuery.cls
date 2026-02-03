public with sharing class FleetSelectorLineQuery {

    public class QuoteLineOption {
        @AuraEnabled public String label { get; set; }
        @AuraEnabled public String value { get; set; }
    }

    @AuraEnabled(cacheable=true)
    public static List<QuoteLineOption> getQuoteLines(Id quoteId) {
        if (quoteId == null) {
            throw new AuraHandledException('Quote Id is required.');
        }

        List<QuoteLineOption> options = new List<QuoteLineOption>();

        // Pull whatever quote lines you want to show – adjust filters as needed
        List<SBQQ__QuoteLine__c> lines = [
            SELECT Id,
                   Name,
                   SBQQ__Number__c,
                   SBQQ__Product__r.Name
            FROM SBQQ__QuoteLine__c
            WHERE SBQQ__Quote__c = :quoteId
            ORDER BY SBQQ__Number__c
        ];

        for (SBQQ__QuoteLine__c ql : lines) {
            QuoteLineOption opt = new QuoteLineOption();

            // Build a nice label, e.g. "10 - Excavator Rental"
            String labelParts = '';
            if (ql.SBQQ__Number__c != null) {
                labelParts += String.valueOf(ql.SBQQ__Number__c) + ' - ';
            }
            if (ql.SBQQ__Product__r != null) {
                labelParts += ql.SBQQ__Product__r.Name;
            } else if (ql.Name != null) {
                labelParts += ql.Name;
            } else {
                labelParts += ql.Id;
            }

            opt.label = labelParts;
            opt.value = ql.Id;
            options.add(opt);
        }

        return options;
    }
}