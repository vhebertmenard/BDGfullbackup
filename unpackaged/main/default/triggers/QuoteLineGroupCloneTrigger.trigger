trigger QuoteLineGroupCloneTrigger on SBQQ__QuoteLineGroup__c (after insert) {
    // Map to hold original group IDs
    Set<Id> originalGroupIds = new Set<Id>();

    // Identify cloned groups and collect their original IDs
    for (SBQQ__QuoteLineGroup__c QLG : Trigger.new) {
        if (QLG.OriginalQuoteLineGroup__c != null) {
            originalGroupIds.add(QLG.OriginalQuoteLineGroup__c);
        }
    }

    // Update the original groups to set Cloned__c = true
    if (!originalGroupIds.isEmpty()) {
        List<SBQQ__QuoteLineGroup__c> originalGroupsToUpdate = [
            SELECT Id, External__c FROM SBQQ__QuoteLineGroup__c
            WHERE Id IN :originalGroupIds
        ];

        for (SBQQ__QuoteLineGroup__c originalGroup : originalGroupsToUpdate) {
            originalGroup.External__c = true;
        }

        update originalGroupsToUpdate;
    }
}