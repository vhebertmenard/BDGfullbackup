public with sharing class FleetSelectorController {

    /* =========================
       DTOs
       ========================= */

    public class FleetSearchResponse {
        @AuraEnabled public List<Fleet__c> records;
        @AuraEnabled public Integer total;

        public FleetSearchResponse(List<Fleet__c> records, Integer total) {
            this.records = records;
            this.total = total;
        }
    }

    public class FleetFilterFacets {
        @AuraEnabled public List<String> warehouses = new List<String>();
        @AuraEnabled public List<String> sndLocations = new List<String>();
        @AuraEnabled public List<String> widths = new List<String>();     // returned as strings for combobox
        @AuraEnabled public List<String> lengths = new List<String>();    // returned as strings for combobox
        @AuraEnabled public List<String> categories = new List<String>();
        @AuraEnabled public List<String> type = new List<String>();        
    }

    /* =========================
       Backward-compatible method
       (keeps existing LWCs working)
       ========================= */

    @AuraEnabled(cacheable=true)
    public static List<Fleet__c> getAvailableFleet() {
        return [
            SELECT Id,
                   Name,
                   Rental_Status__c,
                   WIP_Asset__c,
                   Warehouse__c,
                   SND_Location__c,
                   Asset_Width__c,
                   Asset_Length__c,
                   Asset_Category__c,
                   Complex_Serial_number__c,
            	   Unit_Width__c,
				   Unit_Length__c,
                   Type__c
            FROM Fleet__c
            WHERE (Rental_Status__c != 'Checked Out'
               OR WIP_Asset__c = TRUE)
               AND NS_External_ID__c != ''
            ORDER BY Name
        ];
    }

    /* =========================
       Paged search (fast)
       ========================= */

    @AuraEnabled(cacheable=true)
    public static FleetSearchResponse searchFleet(
        String warehouse,
        String sndLocation,
        Decimal assetWidth,
        Decimal assetLength,
        String category,
        String type,
        String wipFilter,          // '', 'Yes', 'No'
        Integer pageSize,
        Integer pageNumber         // 1-based
    ) {
        pageSize   = (pageSize == null || pageSize <= 0) ? 200 : Math.min(pageSize, 500);
        pageNumber = (pageNumber == null || pageNumber <= 0) ? 1 : pageNumber;

        Integer offsetRows = (pageNumber - 1) * pageSize;

        String baseWhere = buildBaseWhere(wipFilter);

        // Add filter predicates
        List<String> whereParts = new List<String>();
        whereParts.add(baseWhere);

        if (String.isNotBlank(warehouse)) {
            whereParts.add('Warehouse__c = :warehouse');
        }
        if (String.isNotBlank(sndLocation)) {
            whereParts.add('SND_Location__c = :sndLocation');
        }
        if (assetWidth != null) {
            whereParts.add('Unit_Width__c = :assetWidth');
        }
        if (assetLength != null) {
            whereParts.add('Unit_Length__c = :assetLength');
        }
        if (String.isNotBlank(category)) {
            whereParts.add('Asset_Category__c = :category');
        }
        if (String.isNotBlank(category)) {
            whereParts.add('Type__c = :type');
        }

        String whereClause = String.join(whereParts, ' AND ');

        // Total count
        Integer total = (Integer)Database.countQuery(
            'SELECT COUNT() FROM Fleet__c WHERE ' + whereClause
        );

        // Page data
        String dataSoql =
            'SELECT Id, Name, Rental_Status__c, WIP_Asset__c, Warehouse__c, SND_Location__c, ' +
            '       Asset_Width__c, Asset_Length__c, Asset_Category__c, Complex_Serial_number__c, Unit_Width__c, Unit_Length__c, Type__c ' +
            'FROM Fleet__c ' +
            'WHERE ' + whereClause + ' ' +
            'ORDER BY Complex_Serial_number__c ' +
           // 'ORDER BY Name ' +
            'LIMIT :pageSize ' +
            'OFFSET :offsetRows';

        List<Fleet__c> rows = Database.query(dataSoql);
        return new FleetSearchResponse(rows, total);
    }

    /* =========================
       Dynamic filter facets
       (distinct values that adjust based on current selections)
       ========================= */

    @AuraEnabled(cacheable=true)
    public static FleetFilterFacets getFleetFilterFacets(
        String warehouse,
        String sndLocation,
        Decimal assetWidth,
        Decimal assetLength,
        String category,
        String type,
        String wipFilter
    ) {
        String baseWhere = buildBaseWhere(wipFilter);

        FleetFilterFacets facets = new FleetFilterFacets();

        // For each facet, apply all filters EXCEPT the field being faceted.
        // This ensures the dropdown values dynamically adjust based on other selections.
        facets.warehouses = queryDistinctStrings(
            'Warehouse__c',
            baseWhere,
            null, sndLocation, assetWidth, assetLength, category, type
        );

        facets.sndLocations = queryDistinctStrings(
            'SND_Location__c',
            baseWhere,
            warehouse, null, assetWidth, assetLength, category, type
        );

        facets.widths = queryDistinctDecimalsAsStrings(
            'Asset_Width__c',
            baseWhere,
            warehouse, sndLocation, null, assetLength, category, type
        );

        facets.lengths = queryDistinctDecimalsAsStrings(
            'Asset_Length__c',
            baseWhere,
            warehouse, sndLocation, assetWidth, null, category, type
        );

        facets.categories = queryDistinctStrings(
            'Asset_Category__c',
            baseWhere,
            warehouse, sndLocation, assetWidth, assetLength, null, type
        );

        facets.type = queryDistinctStrings(
            'Type__c',
            baseWhere,
            warehouse, sndLocation, assetWidth, assetLength, category, null
        );

        return facets;
    }

    /* =========================
       Assign selected Fleet unit to CPQ Quote Line
       ========================= */

    @AuraEnabled
    public static void assignUnitToLine(Id quoteLineId, Id fleetId) {
        if (quoteLineId == null || fleetId == null) {
            throw new AuraHandledException('Quote Line Id and Fleet Id are required.');
        }

        update new SBQQ__QuoteLine__c(
            Id = quoteLineId,
            Unit__c = fleetId
        );
    }

    /* =========================
       Helpers
       ========================= */

 	private static String buildBaseWhere(String wipFilter) {
    	// Always enforce External ID present
    	String ext = '(NS_External_ID__c != NULL AND NS_External_ID__c != \'\')';

    	// Base eligibility: not Checked Out OR WIP
    	String eligible = '((Rental_Status__c != \'Checked Out\') OR (WIP_Asset__c = TRUE))';

    	// Apply WIP filter dropdown meaning:
    	// - All: eligible
    	// - Yes: WIP only (and External ID)
    	// - No : not Checked Out AND not WIP (and External ID)
    	if (wipFilter == 'Yes') {
        	return '(' + ext + ' AND (WIP_Asset__c = TRUE))';
    	}
    	if (wipFilter == 'No') {
        	return '(' + ext + ' AND (Rental_Status__c != \'Checked Out\') AND (WIP_Asset__c = FALSE OR WIP_Asset__c = NULL))';
    	}
    	return '(' + ext + ' AND ' + eligible + ')';
	}
	
    

    private static List<String> queryDistinctStrings(
        String fieldName,
        String baseWhere,
        String warehouse,
        String sndLocation,
        Decimal assetWidth,
        Decimal assetLength,
        String category,
        String type
    ) {
        List<String> parts = new List<String>();
        parts.add(baseWhere);

        if (String.isNotBlank(warehouse))   parts.add('Warehouse__c = :warehouse');
        if (String.isNotBlank(sndLocation)) parts.add('SND_Location__c = :sndLocation');
        if (assetWidth != null)            parts.add('Unit_Width__c = :assetWidth');
        if (assetLength != null)           parts.add('Unit_Length__c = :assetLength');
        if (String.isNotBlank(category))   parts.add('Asset_Category__c = :category');
        if (String.isNotBlank(type))   parts.add('Type__c = :type');

        // Use AggregateResult for DISTINCT-like behavior.
        String soql =
            'SELECT ' + fieldName + ' v ' +
            'FROM Fleet__c ' +
            'WHERE ' + String.join(parts, ' AND ') + ' ' +
            'AND ' + fieldName + ' != NULL ' +
            'GROUP BY ' + fieldName + ' ' +
            'ORDER BY ' + fieldName + ' ' +
            'LIMIT 2000';

        List<AggregateResult> ars = Database.query(soql);
        List<String> out = new List<String>();
        for (AggregateResult ar : ars) {
            out.add((String)ar.get('v'));
        }
        return out;
    }

    private static List<String> queryDistinctDecimalsAsStrings(
        String fieldName,
        String baseWhere,
        String warehouse,
        String sndLocation,
        Decimal assetWidth,
        Decimal assetLength,
        String category,
        String type
    ) {
        List<String> parts = new List<String>();
        parts.add(baseWhere);

        if (String.isNotBlank(warehouse))   parts.add('Warehouse__c = :warehouse');
        if (String.isNotBlank(sndLocation)) parts.add('SND_Location__c = :sndLocation');
        if (assetWidth != null)            parts.add('Unit_Width__c = :assetWidth');
        if (assetLength != null)           parts.add('Unit_Length__c = :assetLength');
        if (String.isNotBlank(category))   parts.add('Asset_Category__c = :category');
        if (String.isNotBlank(type))   parts.add('Type__c = :type');

        String soql =
            'SELECT ' + fieldName + ' v ' +
            'FROM Fleet__c ' +
            'WHERE ' + String.join(parts, ' AND ') + ' ' +
            'AND ' + fieldName + ' != NULL ' +
            'GROUP BY ' + fieldName + ' ' +
            'ORDER BY ' + fieldName + ' ' +
            'LIMIT 2000';

        List<AggregateResult> ars = Database.query(soql);
        List<String> out = new List<String>();
        for (AggregateResult ar : ars) {
            Object v = ar.get('v');
            if (v != null) out.add(String.valueOf(v));
        }
        return out;
    }
}