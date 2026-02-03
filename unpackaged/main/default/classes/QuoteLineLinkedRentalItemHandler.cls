public class QuoteLineLinkedRentalItemHandler {

    public static void run(List<SBQQ__QuoteLine__c> newList) {
        if (newList == null || newList.isEmpty()) return;

        // Map Trigger.new by Id so we can set fields on the live instances
        Map<Id, SBQQ__QuoteLine__c> liveById = new Map<Id, SBQQ__QuoteLine__c>();
        Set<Id> newIds = new Set<Id>();
        for (SBQQ__QuoteLine__c ql : newList) {
            if (ql.Id != null) {
                newIds.add(ql.Id);
                liveById.put(ql.Id, ql);
            }
        }
        if (newIds.isEmpty()) return;

        // Pull only the lines in context that are Insurance / Personal Property Fee
        Map<Id, SBQQ__QuoteLine__c> feeLinesEnrichedById = new Map<Id, SBQQ__QuoteLine__c>(
            [
                SELECT Id,
                       SBQQ__RequiredBy__c,
                       SBQQ__Product__r.Name
                FROM SBQQ__QuoteLine__c
                WHERE Id IN :newIds
                  AND SBQQ__Product__r.Name IN ('Insurance', 'Personal Property Fee')
            ]
        );
        if (feeLinesEnrichedById.isEmpty()) return;

        // Collect their RequiredBy parents
        Set<Id> parentReqByIds = new Set<Id>();
        for (SBQQ__QuoteLine__c feeRow : feeLinesEnrichedById.values()) {
            if (feeRow.SBQQ__RequiredBy__c != null) {
                parentReqByIds.add(feeRow.SBQQ__RequiredBy__c);
            }
        }
        if (parentReqByIds.isEmpty()) return;

        // Pull all siblings that share those RequiredBy parents
        // "First" is determined by CreatedDate ASC
        List<SBQQ__QuoteLine__c> siblings = [
            SELECT Id,
                   SBQQ__RequiredBy__c,
                   Unit__c,
                   NS_Rental_Item_ID__c,
                   CreatedDate
            FROM SBQQ__QuoteLine__c
            WHERE SBQQ__RequiredBy__c IN :parentReqByIds
            ORDER BY CreatedDate ASC
        ];

        // For each parent, store the first sibling that has Unit__c and NS_Rental_Item_ID__c
        Map<Id, String> firstRentalIdByParent = new Map<Id, String>();
        for (SBQQ__QuoteLine__c s : siblings) {
            // Only set once per parent (the first one in CreatedDate order)
            if (!firstRentalIdByParent.containsKey(s.SBQQ__RequiredBy__c)) {
                Boolean hasUnit = (s.Unit__c != null && String.isNotBlank(String.valueOf(s.Unit__c)));
               Boolean hasRental = (s.Id != null && String.isNotBlank(s.Id));
                if (hasUnit && hasRental) {
                    firstRentalIdByParent.put(s.SBQQ__RequiredBy__c, s.Id);
                }
            }
        }

        // Set NS_Linked_Rental_Item_ID__c on the live fee lines
        for (Id feeId : feeLinesEnrichedById.keySet()) {
            SBQQ__QuoteLine__c feeEnriched = feeLinesEnrichedById.get(feeId);
            SBQQ__QuoteLine__c feeLive = liveById.get(feeId);
            if (feeEnriched == null || feeLive == null) continue;

            Id parentId = feeEnriched.SBQQ__RequiredBy__c;
            if (parentId == null) continue;

            String rentalId = firstRentalIdByParent.get(parentId);
            if (rentalId != null) {
                feeLive.NS_Linked_Rental_Item_ID__c = rentalId;
            }
            // else: leave as-is (no clearing)
        }
    }
}