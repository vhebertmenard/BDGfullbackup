public class QuoteLineGroupCloneHandler {

    //public static Boolean isRunning = false;

    public static void processForQuotes(Set<Id> quoteIds) {
        system.debug('***isRunning**'+QuoteLineGroupRecurssionCheck.isRunning);
        system.debug('***quoteIds**'+quoteIds);
        if (QuoteLineGroupRecurssionCheck.isRunning) {
            return;
        }
        QuoteLineGroupRecurssionCheck.isRunning = true;

        try {
            if (quoteIds == null || quoteIds.isEmpty()) {
                return;
            }

            // 1) Get all external groups under these quotes
            List<SBQQ__QuoteLineGroup__c> externalGroups = [
                SELECT Id,
                       Name,
                       External__c,
                       External_Quote_Line_Group__c,
                       X3rd_Party_Partnership_Quote_Line_Group__c,
                       SBQQ__Quote__c,
                       SBQQ__Quote__r.Transaction_Type__c
                FROM SBQQ__QuoteLineGroup__c
                WHERE SBQQ__Quote__c IN :quoteIds
                  AND External__c = true
            ];

            if (externalGroups.isEmpty()) {
                return;
            }

            // 2) Clone only those that don't yet have an internal counterpart
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

            // 3) Build external -> internal group map (includes existing links + new ones)
            Map<Id, Id> externalToInternalGroup = new Map<Id, Id>();

            // a) For groups we just cloned
            for (Id extGroupId : originalIdToIndex.keySet()) {
                Integer idx = originalIdToIndex.get(extGroupId);
                externalToInternalGroup.put(extGroupId, newGroupsToInsert[idx].Id);
            }

            // b) For external groups that already had an internal group
            for (SBQQ__QuoteLineGroup__c g : externalGroups) {
                if (g.External_Quote_Line_Group__c != null &&
                    !externalToInternalGroup.containsKey(g.Id)) {
                    externalToInternalGroup.put(g.Id, g.External_Quote_Line_Group__c);
                }
            }

            // 4) Update original external groups with references to internal groups
            List<SBQQ__QuoteLineGroup__c> groupsToUpdate = new List<SBQQ__QuoteLineGroup__c>();
            for (SBQQ__QuoteLineGroup__c g : externalGroups) {
                if (g.External_Quote_Line_Group__c == null &&
                    externalToInternalGroup.containsKey(g.Id)) {
                    Id newInternalId = externalToInternalGroup.get(g.Id);
                    SBQQ__QuoteLineGroup__c upd = new SBQQ__QuoteLineGroup__c(
                        Id = g.Id,
                        External_Quote_Line_Group__c = newInternalId,
                        X3rd_Party_Partnership_Quote_Line_Group__c = newInternalId
                    );
                    groupsToUpdate.add(upd);
                }
            }
            if (!groupsToUpdate.isEmpty()) {
                update groupsToUpdate;
            }

            if (externalToInternalGroup.isEmpty()) {
                return;
            }

            // 5) Prepare for line cloning
            Set<Id> externalGroupIds = new Set<Id>(externalToInternalGroup.keySet());
            Set<Id> internalGroupIds = new Set<Id>(externalToInternalGroup.values());

            // 6) Query all external lines with all fields (dynamic SOQL)
            Map<String, Schema.SObjectField> fieldMap =
                Schema.SObjectType.SBQQ__QuoteLine__c.fields.getMap();
            List<String> fieldNames = new List<String>();
            fieldNames.addAll(fieldMap.keySet());

            Set<Id> extGroupIds = new Set<Id>(externalGroupIds);

            String soql = 'SELECT ' + String.join(fieldNames, ',') +
                          ' FROM SBQQ__QuoteLine__c' +
                          ' WHERE SBQQ__Group__c IN :extGroupIds';

            List<SBQQ__QuoteLine__c> externalLines = Database.query(soql);

            if (externalLines.isEmpty()) {
                return;
            }

            // Map external group Id -> group (for Transaction_Type__c)
            Map<Id, SBQQ__QuoteLineGroup__c> groupById =
                new Map<Id, SBQQ__QuoteLineGroup__c>(externalGroups);

            // 7) Two-pass cloning so SBQQ__RequiredBy__c points to cloned parents

            List<SBQQ__QuoteLine__c> parentClonesToInsert = new List<SBQQ__QuoteLine__c>();
            List<SBQQ__QuoteLine__c> childClonesToInsert  = new List<SBQQ__QuoteLine__c>();

            // Track new clones
            Map<Id, SBQQ__QuoteLine__c> parentOrigToCloneSObj =
                new Map<Id, SBQQ__QuoteLine__c>();
            Map<Id, SBQQ__QuoteLine__c> childOrigToCloneSObj =
                new Map<Id, SBQQ__QuoteLine__c>();

            // Map original parent → cloned parent Id (existing + new)
            Map<Id, Id> parentIdMap = new Map<Id, Id>();

            // 7a) Seed parentIdMap from existing clones via Associated_Partnership_Quote_Line__c
            for (SBQQ__QuoteLine__c origLine : externalLines) {
                if (origLine.SBQQ__RequiredBy__c == null &&  // parent
                    origLine.Associated_Partnership_Quote_Line__c != null) {

                    parentIdMap.put(
                        origLine.Id,
                        origLine.Associated_Partnership_Quote_Line__c
                    );
                }
            }

            // PASS 1: parents (RequiredBy__c == null, not already associated)
            for (SBQQ__QuoteLine__c origLine : externalLines) {
                Id extGroupId = origLine.SBQQ__Group__c;
                if (!externalToInternalGroup.containsKey(extGroupId)) {
                    continue;
                }

                // Skip parents that already have a partnership line
                if (origLine.Associated_Partnership_Quote_Line__c != null) {
                    continue;
                }

                if (origLine.SBQQ__RequiredBy__c != null) {
                    continue; // parents only
                }

                Id internalGroupId = externalToInternalGroup.get(extGroupId);
                if (internalGroupId == null) {
                    continue;
                }

                SBQQ__QuoteLine__c newLine =
                    origLine.clone(false, true, false, false);
                newLine.SBQQ__Group__c = internalGroupId;

                // Pricing logic for parents
                SBQQ__QuoteLineGroup__c extGroup = groupById.get(extGroupId);
                String txType = (extGroup != null)
                    ? extGroup.SBQQ__Quote__r.Transaction_Type__c
                    : null;
                Decimal origPrice = origLine.Unit_Price__c;

                if (txType != null &&
                    origPrice != null &&
                    origPrice > 0 &&
                    (origLine.Trans_Category__c == 'Rental' ||
                     origLine.Trans_Category__c == 'Sale' ||
                     origLine.Trans_Category__c == 'VAPS')) {

                    if (txType == 'Rental') {
                        newLine.Unit_Price__c = origPrice * 0.90; // 90%
                    } else if (txType == 'Sale') {
                        newLine.Unit_Price__c = origPrice * 0.97; // 3% less
                    }
                }

                System.debug(
                    'PARENT CLONE DEBUG → ORIG: ' + origLine.Id +
                    ', Orig Unit_Price__c=' + origPrice +
                    ', TxType=' + txType +
                    ', Clone Unit_Price__c=' + newLine.Unit_Price__c
                );

                parentClonesToInsert.add(newLine);
                parentOrigToCloneSObj.put(origLine.Id, newLine);
            }

            if (!parentClonesToInsert.isEmpty()) {
                insert parentClonesToInsert;
            }

            // Add newly cloned parents to parentIdMap
            for (Id origId : parentOrigToCloneSObj.keySet()) {
                parentIdMap.put(origId, parentOrigToCloneSObj.get(origId).Id);
            }

            // PASS 2: children (RequiredBy__c != null, not already associated)
            for (SBQQ__QuoteLine__c origLine : externalLines) {
                Id extGroupId = origLine.SBQQ__Group__c;
                if (!externalToInternalGroup.containsKey(extGroupId)) {
                    continue;
                }

                // Skip children that already have a partnership line
                if (origLine.Associated_Partnership_Quote_Line__c != null) {
                    continue;
                }

                if (origLine.SBQQ__RequiredBy__c == null) {
                    continue; // children only
                }

                Id internalGroupId = externalToInternalGroup.get(extGroupId);
                if (internalGroupId == null) {
                    continue;
                }

                SBQQ__QuoteLine__c newLine =
                    origLine.clone(false, true, false, false);
                newLine.SBQQ__Group__c = internalGroupId;

                // Remap RequiredBy__c to cloned parent if possible
                Id origParentId = origLine.SBQQ__RequiredBy__c;
                if (origParentId != null && parentIdMap.containsKey(origParentId)) {
                    newLine.SBQQ__RequiredBy__c = parentIdMap.get(origParentId);
                }

                // Pricing logic for children
                SBQQ__QuoteLineGroup__c extGroup = groupById.get(extGroupId);
                String txType = (extGroup != null)
                    ? extGroup.SBQQ__Quote__r.Transaction_Type__c
                    : null;
                Decimal origPrice = origLine.Unit_Price__c;

                if (txType != null &&
                    origPrice != null &&
                    origPrice > 0 &&
                    (origLine.Trans_Category__c == 'Rental' ||
                     origLine.Trans_Category__c == 'Sale' ||
                     origLine.Trans_Category__c == 'VAPS')) {

                    if (txType == 'Rental') {
                        newLine.Unit_Price__c = origPrice * 0.90; // 90%
                    } else if (txType == 'Sale') {
                        newLine.Unit_Price__c = origPrice * 0.97; // 3% less
                    }
                }

                System.debug(
                    'CHILD CLONE DEBUG → ORIG: ' + origLine.Id +
                    ', Orig Unit_Price__c=' + origPrice +
                    ', TxType=' + txType +
                    ', Clone Unit_Price__c=' + newLine.Unit_Price__c +
                    ', New RequiredBy__c=' + newLine.SBQQ__RequiredBy__c
                );

                childClonesToInsert.add(newLine);
                childOrigToCloneSObj.put(origLine.Id, newLine);
            }

            if (!childClonesToInsert.isEmpty()) {
                insert childClonesToInsert;
            }

            // 8) Populate Associated_* link fields on originals and clones

            Map<Id, Id> origToCloneId = new Map<Id, Id>();

            // parents
            for (Id origId : parentOrigToCloneSObj.keySet()) {
                origToCloneId.put(origId, parentOrigToCloneSObj.get(origId).Id);
            }
            // children
            for (Id origId : childOrigToCloneSObj.keySet()) {
                origToCloneId.put(origId, childOrigToCloneSObj.get(origId).Id);
            }

            if (!origToCloneId.isEmpty()) {
                List<SBQQ__QuoteLine__c> originalsToUpdate = new List<SBQQ__QuoteLine__c>();
                List<SBQQ__QuoteLine__c> clonesToUpdate    = new List<SBQQ__QuoteLine__c>();

                for (Id origId : origToCloneId.keySet()) {
                    Id cloneId = origToCloneId.get(origId);

                    // On original external line
                    originalsToUpdate.add(new SBQQ__QuoteLine__c(
                        Id = origId,
                        Associated_Partnership_Quote_Line__c = cloneId
                    ));

                    // On cloned internal line
                    clonesToUpdate.add(new SBQQ__QuoteLine__c(
                        Id = cloneId,
                        Associated_External_Quote_Line__c = origId
                    ));
                }

                if (!originalsToUpdate.isEmpty()) {
                    update originalsToUpdate;
                }
                if (!clonesToUpdate.isEmpty()) {
                    update clonesToUpdate;
                }
            }

        } finally {
           // isRunning = false;
        }
    }

    // Helper to build a uniqueness key for lines (currently unused but kept for future)
    private static String buildLineKey(Id groupId, Id productId, Decimal numberVal) {
        String g = (groupId == null) ? 'NONE' : String.valueOf(groupId);
        String p = (productId == null) ? 'NONE' : String.valueOf(productId);
        String n = (numberVal == null) ? 'NONE' : String.valueOf(numberVal);
        return g + '|' + p + '|' + n;
    }
}