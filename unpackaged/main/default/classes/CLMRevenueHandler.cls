public with sharing class CLMRevenueHandler {
    public static Boolean isRunning = false;

    // Configure the labels you described (case-insensitive; we compare after lowercasing)
    private static final Set<String> INSTALL_NAMES = new Set<String>{ 'Install - Transactional Business', 'Dismantle' };
    private static final Set<String> TRANSPORT_NAMES = new Set<String>{ 'Transportation and Relocation', 'Return Transportation' };
    private static final Set<String> VAPS_NAMES = new Set<String>{ 'Miscellaneous Items' };   

    /**
     * Recalculates CLM_* revenue fields on the parent "Complex" Quote Line(s),
     * based on child/options linked via SBQQ__RequiredBy__c.
     *
     * Runs ONLY when the parent line's Quote has:
     *  - Branch__c = 'BOXX CL Martin'
     *  - Transaction_Type__c = 'Rental'
     *
     * Buckets:
     *  - Install Revenue:     sum(Unit_Price__c) for products exactly named Install or Dismantle
     *  - Transportation Rev:  sum(Unit_Price__c) for products exactly named Transportation or Return Transportation
     *  - VAPS Revenue:        sum(Unit_Price__c * Subscription_Term_Quote__c) for remaining non-Unit lines
     *  - Unit Revenue:        SBQQ__NetTotal__c - (Install + Transportation + VAPS)
     */
    public static void recalculate(Set<Id> parentComplexLineIds) {
        if (parentComplexLineIds == null || parentComplexLineIds.isEmpty()) return;

        isRunning = true;
        try {
            // 1) Query parents + quote context needed for eligibility + term + net total
            Map<Id, SBQQ__QuoteLine__c> parentsById = new Map<Id, SBQQ__QuoteLine__c>([
                SELECT Id,
                       SBQQ__Quote__c,
                       SBQQ__NetTotal__c,
                       CLM_Install_Revenue__c,
                       CLM_Transportation_Revenue__c,
                       CLM_VAPS_Revenue__c,
                       CLM_Unit_Revenue__c,
                       SBQQ__Quote__r.Branch__c,
                       SBQQ__Quote__r.Transaction_Type__c,
                       SBQQ__Quote__r.SBQQ__SubscriptionTerm__c
                FROM SBQQ__QuoteLine__c
                WHERE Id IN :parentComplexLineIds
            ]);

            if (parentsById.isEmpty()) return;

            // 2) Determine eligible parents and capture term per parent
            Set<Id> eligibleParentIds = new Set<Id>();
            Map<Id, Integer> termByParentId = new Map<Id, Integer>();

            for (SBQQ__QuoteLine__c p : parentsById.values()) {
                if (p.SBQQ__Quote__r.Branch__c == 'BOXX CL Martin'
                    && p.SBQQ__Quote__r.Transaction_Type__c == 'Rental'
                ) {
                    eligibleParentIds.add(p.Id);

                    Integer term = (Integer)p.SBQQ__Quote__r.SBQQ__SubscriptionTerm__c;
                    if (term == null || term < 0) term = 0;
                    termByParentId.put(p.Id, term);
                }
            }

            if (eligibleParentIds.isEmpty()) return;

            // 3) Pull all children linked to those parents
            List<SBQQ__QuoteLine__c> children = [
                SELECT Id,
                       SBQQ__RequiredBy__c,
                       Unit_Price__c,
                       SBQQ__Product__r.Name
                FROM SBQQ__QuoteLine__c
                WHERE SBQQ__RequiredBy__c IN :eligibleParentIds
            ];

            // 4) Compute totals per parent
            Map<Id, Decimal> installTotalByParent   = new Map<Id, Decimal>();
            Map<Id, Decimal> transportTotalByParent = new Map<Id, Decimal>();
            Map<Id, Decimal> vapsTotalByParent      = new Map<Id, Decimal>();

            for (SBQQ__QuoteLine__c c : children) {
                if (c.SBQQ__RequiredBy__c == null) continue;

                Decimal price = (c.Unit_Price__c == null) ? 0 : c.Unit_Price__c;

                String productName = (c.SBQQ__Product__r != null && c.SBQQ__Product__r.Name != null)
                    ? c.SBQQ__Product__r.Name.trim()
                    : '';

                String lower = normalize(productName);

                // Exclude "Unit" lines from these buckets (your unit revenue is derived from net total)
                if (lower.contains('unit')) {
                    continue;
                }

                // Install / Dismantle (one-time)
                if (matchesAnyExact(lower, INSTALL_NAMES)) {
                    installTotalByParent.put(
                        c.SBQQ__RequiredBy__c,
                        (installTotalByParent.containsKey(c.SBQQ__RequiredBy__c) ? installTotalByParent.get(c.SBQQ__RequiredBy__c) : 0) + price
                    );
                    continue;
                }

                // Transportation / Return Transportation (one-time)
                if (matchesAnyExact(lower, TRANSPORT_NAMES)) {
                    transportTotalByParent.put(
                        c.SBQQ__RequiredBy__c,
                        (transportTotalByParent.containsKey(c.SBQQ__RequiredBy__c) ? transportTotalByParent.get(c.SBQQ__RequiredBy__c) : 0) + price
                    );
                    continue;
                }

                // Bucket: VAPS (monthly rental) – treat everything else (non-unit, non-install, non-transport) as VAPS
                // If you have a better discriminator (Product Code, Family, checkbox), swap this logic.
                 if (matchesAnyExact(lower, VAPS_NAMES)) {
                	Integer term = termByParentId.get(c.SBQQ__RequiredBy__c);
                	Decimal extended = price * term;

                	vapsTotalByParent.put(
                    	c.SBQQ__RequiredBy__c,
                    	(vapsTotalByParent.containsKey(c.SBQQ__RequiredBy__c) ? vapsTotalByParent.get(c.SBQQ__RequiredBy__c) : 0) + extended
                	);
            	}
            }

            // 5) Update eligible parents
            List<SBQQ__QuoteLine__c> updates = new List<SBQQ__QuoteLine__c>();

            for (Id parentId : eligibleParentIds) {
                Decimal install = installTotalByParent.containsKey(parentId) ? installTotalByParent.get(parentId) : 0;
                Decimal trans   = transportTotalByParent.containsKey(parentId) ? transportTotalByParent.get(parentId) : 0;
                Decimal vaps    = vapsTotalByParent.containsKey(parentId) ? vapsTotalByParent.get(parentId) : 0;

                Decimal parentNetTotal = parentsById.get(parentId).SBQQ__NetTotal__c == null
                    ? 0
                    : parentsById.get(parentId).SBQQ__NetTotal__c;

                Decimal unitRevenue = parentNetTotal - (install + trans + vaps);

                updates.add(new SBQQ__QuoteLine__c(
                    Id = parentId,
                    CLM_Install_Revenue__c = install,
                    CLM_Transportation_Revenue__c = trans,
                    CLM_VAPS_Revenue__c = vaps,
                    CLM_Unit_Revenue__c = unitRevenue
                ));
            }

            if (!updates.isEmpty()) {
                update updates;
            }
        } finally {
            isRunning = false;
        }
    }

    // Normalizes a product name for matching: lowercase, collapse whitespace, trim
    private static String normalize(String s) {
        if (s == null) return '';
        return s.toLowerCase().replaceAll('\\s+', ' ').trim();
    }

    // Exact match against a set of expected names (after normalize())
    private static Boolean matchesAnyExact(String normalizedLowerName, Set<String> expectedLower) {
        if (String.isBlank(normalizedLowerName)) return false;
        for (String e : expectedLower) {
            if (normalizedLowerName == e) return true;
        }
        return false;
    }
}