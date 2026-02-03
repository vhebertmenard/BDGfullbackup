trigger CLMRevenueTrigger on SBQQ__QuoteLine__c (
    after insert, after update, after delete, after undelete
) {
    if (CLMRevenueHandler.isRunning) return;

    Set<Id> parentComplexLineIds = new Set<Id>();

    if (Trigger.isDelete) {
        for (SBQQ__QuoteLine__c ql : Trigger.old) {
            if (ql.SBQQ__RequiredBy__c != null) parentComplexLineIds.add(ql.SBQQ__RequiredBy__c);
        }
    } else {
        for (SBQQ__QuoteLine__c ql : Trigger.new) {
            if (ql.SBQQ__RequiredBy__c != null) parentComplexLineIds.add(ql.SBQQ__RequiredBy__c);
        }

        // If RequiredBy changed, also recalc the old parent
        if (Trigger.isUpdate) {
            for (Integer i = 0; i < Trigger.new.size(); i++) {
                SBQQ__QuoteLine__c n = Trigger.new[i];
                SBQQ__QuoteLine__c o = Trigger.old[i];
                if (o.SBQQ__RequiredBy__c != null && o.SBQQ__RequiredBy__c != n.SBQQ__RequiredBy__c) {
                    parentComplexLineIds.add(o.SBQQ__RequiredBy__c);
                }
            }
        }
    }

    if (!parentComplexLineIds.isEmpty()) {
        CLMRevenueHandler.recalculate(parentComplexLineIds);
    }
}