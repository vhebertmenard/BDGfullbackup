// File: triggers/QuoteLine_LinkedRentalItem.trigger
trigger QuoteLine_LinkedRentalItem on SBQQ__QuoteLine__c (before insert, before update) {
    if (Trigger.isBefore) {
        QuoteLineLinkedRentalItemHandler.run(Trigger.new);
    }
}