public class ExternalQuoteLineGroupCloneJob implements Queueable {

    private Set<Id> groupIds;

    public ExternalQuoteLineGroupCloneJob(Set<Id> groupIds) {
        this.groupIds = groupIds;
    }

    public void execute(QueueableContext context) {
        if (groupIds == null || groupIds.isEmpty()) {
            return;
        }

        // 1) Query external groups
        List<SBQQ__QuoteLineGroup__c> externalGroups = [
            SELECT Id,
                   Name,
                   External__c,
                   External_Quote_Line_Group__c,
                   X3rd_Party_Partnership_Quote_Line_Group__c,
                   SBQQ__Quote__c,
                   SBQQ__Quote__r.Transaction_Type__c
            FROM SBQQ__QuoteLineGroup__c
            WHERE Id IN :groupIds
              AND External__c = true
        ];

        if (externalGroups.isEmpty()) {
            return;
        }

        // 2) Clone external groups that don't yet have an internal counterpart
        List<SBQQ__QuoteLineGroup__c> groupsToClone = new List<SBQQ__QuoteLineGroup__c>();
        for (SBQQ__QuoteLineGroup__c g : externalGroups) {
            if (g.External_Quote_Line_Group__c == null &&
                g.X3rd_Party_Partnership_Quote_Line_Group__c == null) {
                groupsToClone.add(g);
            }
        }

        List<SBQQ__QuoteLineGroup__c> newGroupsToInsert = new List<SBQQ__QuoteLineGroup__c>();
        Map<Id, Integer> originalIdToIndex = new Map<Id, Integer>();

        if (!groupsToClone.isEmpty()) {
            for (SBQQ__QuoteLineGroup__c orig : groupsToClone) {
                SBQQ__QuoteLineGroup__c cloned = orig.clone(false, true, false, false);

                if (cloned.Name != null) {
                    cloned.Name = cloned.Name + ' - Internal';
                }

                cloned.External__c = false;
                cloned.SBQQ__Optional__c = true;
                cloned.Joint_Venture_Line_Items__c = true;

                cloned.External_Quote_Line_Group__c = null;
                cloned.X3rd_Party_Partnership_Quote_Line_Group__c = null;

                newGroupsToInsert.add(cloned);
                originalIdToIndex.put(orig.Id, newGroupsToInsert.size() - 1);
            }

            insert newGroupsToInsert;
        }

        // 3) Build external -> internal group map
        Map<Id, Id> externalToInternalGroup = new Map<Id, Id>();

        // a) Newly cloned ones
        for (Id extGroupId : originalIdToIndex.keySet()) {
            Integer idx = originalIdToIndex.get(extGroupId);
            externalToInternalGroup.put(extGroupId, newGroupsToInsert[idx].Id);
        }

        // b) Ones that already had internal linked
        for (SBQQ__QuoteLineGroup__c g : externalGroups) {
            if (g.External_Quote_Line_Group__c != null &&
                !externalToInternalGroup.containsKey(g.Id)) {
                externalToInternalGroup.put(g.Id, g.External_Quote_Line_Group__c);
            }
        }

        // 4) Update original external groups with references to internal group
        List<SBQQ__QuoteLineGroup__c> groupsToUpdate = new List<SBQQ__QuoteLineGroup__c>();
        for (SBQQ__QuoteLineGroup__c g : externalGroups) {
            if (g.External_Quote_Line_Group__c == null &&
                externalToInternalGroup.containsKey(g.Id)) {

                Id internalId = externalToInternalGroup.get(g.Id);
                groupsToUpdate.add(new SBQQ__QuoteLineGroup__c(
                    Id = g.Id,
                    External_Quote_Line_Group__c = internalId,
                    X3rd_Party_Partnership_Quote_Line_Group__c = internalId
                ));
            }
        }
        if (!groupsToUpdate.isEmpty()) {
            update groupsToUpdate;
        }

        if (externalToInternalGroup.isEmpty()) {
            return;
        }

        // 5) Clone lines: parents first, then children with RequiredBy remap

        Set<Id> externalGroupIds = new Set<Id>(externalToInternalGroup.keySet());
        Set<Id> internalGroupIds = new Set<Id>(externalToInternalGroup.values());

        // Existing lines in internal groups (avoid duplicates)
        Set<String> existingKeys = new Set<String>();
        if (!internalGroupIds.isEmpty()) {
            for (SBQQ__QuoteLine__c existing : [
                SELECT Id, SBQQ__Group__c, SBQQ__Product__c, SBQQ__Number__c
                FROM SBQQ__QuoteLine__c
                WHERE SBQQ__Group__c IN :internalGroupIds
            ]) {
                existingKeys.add(buildLineKey(
                    existing.SBQQ__Group__c,
                    existing.SBQQ__Product__c,
                    existing.SBQQ__Number__c
                ));
            }
        }

        // Query ALL fields for external lines so clone() carries everything
        Map<String, Schema.SObjectField> fieldMap =
            Schema.SObjectType.SBQQ__QuoteLine__c.fields.getMap();
        List<String> fieldNames = new List<String>(fieldMap.keySet());

        Set<Id> extGroupIds = new Set<Id>(externalGroupIds);

        String soql =
            'SELECT ' + String.join(fieldNames, ',') +
            ' FROM SBQQ__QuoteLine__c' +
            ' WHERE SBQQ__Group__c IN :extGroupIds';

        List<SBQQ__QuoteLine__c> externalLines = Database.query(soql);

        if (externalLines.isEmpty()) {
            return;
        }

        // Map group Id -> group (for Transaction_Type__c)
        Map<Id, SBQQ__QuoteLineGroup__c> groupById =
            new Map<Id, SBQQ__QuoteLineGroup__c>(externalGroups);

        List<SBQQ__QuoteLine__c> parentClonesToInsert = new List<SBQQ__QuoteLine__c>();
        List<SBQQ__QuoteLine__c> childClonesToInsert  = new List<SBQQ__QuoteLine__c>();
        Set<String> newKeys = new Set<String>();

        Map<Id, SBQQ__QuoteLine__c> parentOrigToCloneSObj = new Map<Id, SBQQ__QuoteLine__c>();

        // PASS 1: parents (no RequiredBy)
        for (SBQQ__QuoteLine__c orig : externalLines) {
            Id extGroupId = orig.SBQQ__Group__c;
            if (!externalToInternalGroup.containsKey(extGroupId)) {
                continue;
            }
            if (orig.SBQQ__RequiredBy__c != null) {
                continue;
            }

            Id internalGroupId = externalToInternalGroup.get(extGroupId);

            String key = buildLineKey(
                internalGroupId,
                orig.SBQQ__Product__c,
                orig.SBQQ__Number__c
            );

            if (existingKeys.contains(key) || newKeys.contains(key)) {
                continue;
            }

            SBQQ__QuoteLine__c cloneLine = orig.clone(false, true, false, false);
            cloneLine.SBQQ__Group__c = internalGroupId;

            // Pricing logic (parents)
            SBQQ__QuoteLineGroup__c grp = groupById.get(extGroupId);
            String txType = (grp != null) ? grp.SBQQ__Quote__r.Transaction_Type__c : null;
            Decimal origPrice = orig.Unit_Price__c;

            if (txType != null &&
                origPrice != null &&
                origPrice > 0 &&
                (orig.Trans_Category__c == 'Rental' ||
                 orig.Trans_Category__c == 'Sale')) {

                if (txType == 'Rental') {
                    cloneLine.Unit_Price__c = origPrice * 0.90;
                } else if (txType == 'Sale') {
                    cloneLine.Unit_Price__c = origPrice * 0.97;
                }
            }

            parentClonesToInsert.add(cloneLine);
            newKeys.add(key);
            parentOrigToCloneSObj.put(orig.Id, cloneLine);
        }

        if (!parentClonesToInsert.isEmpty()) {
            insert parentClonesToInsert;
        }

        // Map original parent Id -> cloned parent Id
        Map<Id, Id> parentOrigToCloneId = new Map<Id, Id>();
        for (Id origId : parentOrigToCloneSObj.keySet()) {
            parentOrigToCloneId.put(origId, parentOrigToCloneSObj.get(origId).Id);
        }

        // PASS 2: children (with RequiredBy remapped)
        for (SBQQ__QuoteLine__c orig : externalLines) {
            Id extGroupId = orig.SBQQ__Group__c;
            if (!externalToInternalGroup.containsKey(extGroupId)) {
                continue;
            }
            if (orig.SBQQ__RequiredBy__c == null) {
                continue;
            }

            Id internalGroupId = externalToInternalGroup.get(extGroupId);

            String key = buildLineKey(
                internalGroupId,
                orig.SBQQ__Product__c,
                orig.SBQQ__Number__c
            );

            if (existingKeys.contains(key) || newKeys.contains(key)) {
                continue;
            }

            SBQQ__QuoteLine__c cloneLine = orig.clone(false, true, false, false);
            cloneLine.SBQQ__Group__c = internalGroupId;

            // Remap RequiredBy
            Id origParentId = orig.SBQQ__RequiredBy__c;
            if (origParentId != null && parentOrigToCloneId.containsKey(origParentId)) {
                cloneLine.SBQQ__RequiredBy__c = parentOrigToCloneId.get(origParentId);
            }

            // Pricing logic (children)
            SBQQ__QuoteLineGroup__c grp = groupById.get(extGroupId);
            String txType = (grp != null) ? grp.SBQQ__Quote__r.Transaction_Type__c : null;
            Decimal origPrice = orig.Unit_Price__c;

            if (txType != null &&
                origPrice != null &&
                origPrice > 0 &&
                (orig.Trans_Category__c == 'Rental' ||
                 orig.Trans_Category__c == 'Sale')) {

                if (txType == 'Rental') {
                    cloneLine.Unit_Price__c = origPrice * 0.90;
                } else if (txType == 'Sale') {
                    cloneLine.Unit_Price__c = origPrice * 0.97;
                }
            }

            childClonesToInsert.add(cloneLine);
            newKeys.add(key);
        }

        if (!childClonesToInsert.isEmpty()) {
            insert childClonesToInsert;
        }
    }

    // Uniqueness key helper
    private static String buildLineKey(Id groupId, Id productId, Decimal numberVal) {
        String g = (groupId == null) ? 'NONE' : String.valueOf(groupId);
        String p = (productId == null) ? 'NONE' : String.valueOf(productId);
        String n = (numberVal == null) ? 'NONE' : String.valueOf(numberVal);
        return g + '|' + p + '|' + n;
    }
}