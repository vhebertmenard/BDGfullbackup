trigger QuoteCloneExternalTrigger on SBQQ__Quote__c (after update) {
    if (Trigger.isAfter && Trigger.isUpdate) {
        QuoteLineGroupCloneHandler.processForQuotes(Trigger.newMap.keySet());
    }
}