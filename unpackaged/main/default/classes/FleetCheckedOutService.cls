// File: force-app/main/default/classes/FleetCheckedOutService.cls
public with sharing class FleetCheckedOutService {
    public class CheckedOutUnit {
        @AuraEnabled public Id unitId;
        @AuraEnabled public String unitName;
        @AuraEnabled public String rentalStatus;
    }
    public class Result {
        @AuraEnabled public Boolean hasCheckedOut;
        @AuraEnabled public List<CheckedOutUnit> units;
    }

    @AuraEnabled(cacheable=true)
    public static Result getCheckedOutUnitsForOpportunity(Id opportunityId) {
        Result r = new Result();
        r.units = new List<CheckedOutUnit>();
        if (opportunityId == null) { r.hasCheckedOut = false; return r; }

        // Query quote lines by walking up to the primary quote on this opportunity.
        // This avoids a separate "find primary quote" query and is more robust in tests & prod.
        List<SBQQ__QuoteLine__c> lines = [
            SELECT Id,
                   Unit__c,
                   Unit__r.Name,
                   Unit__r.Rental_Status__c
            FROM SBQQ__QuoteLine__c
            WHERE SBQQ__Quote__r.SBQQ__Opportunity2__c = :opportunityId
              AND SBQQ__Quote__r.SBQQ__Primary__c = true
              AND Unit__c != null
              AND Unit__r.Rental_Status__c = 'Checked Out'
              AND SBQQ__Group__r.External__c != true
            ORDER BY Unit__r.Name
        ];

        for (SBQQ__QuoteLine__c ql : lines) {
            CheckedOutUnit cu = new CheckedOutUnit();
            cu.unitId = ql.Unit__c;
            cu.unitName = ql.Unit__r.Name;
            cu.rentalStatus = ql.Unit__r.Rental_Status__c;
            r.units.add(cu);
        }
        r.hasCheckedOut = !r.units.isEmpty();
        return r;
    }
}