trigger QuoteLineTrigger on SBQQ__QuoteLine__c (after insert) {
     //clone lines only when they are first created
     // QuoteLineGroupCloneHandler.cloneLines(Trigger.new);
}