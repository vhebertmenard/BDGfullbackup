// File: force-app/main/default/lwc/fleetCheckedOutWarning/fleetCheckedOutWarning.js
import { LightningElement, api, wire } from 'lwc';
import getCheckedOutUnitsForOpportunity from '@salesforce/apex/FleetCheckedOutService.getCheckedOutUnitsForOpportunity';

export default class FleetCheckedOutWarning extends LightningElement {
    @api recordId; // Opportunity Id supplied by the record page
    loading = true;
    error;
    hasCheckedOut = false;
    units = [];

    @wire(getCheckedOutUnitsForOpportunity, { opportunityId: '$recordId' })
    wiredData({ data, error }) {
        this.loading = false;
        if (data) {
            this.hasCheckedOut = data.hasCheckedOut;
            this.units = (data.units || []).map(u => ({
                ...u,
                recordUrl: `${window.location.origin}/lightning/r/Fleet__c/${u.unitId}/view`
            }));
            this.error = undefined;
        } else if (error) {
            this.error = error;
            this.hasCheckedOut = false;
            this.units = [];
        }
    }

    get showBanner() {
        return !this.loading && this.hasCheckedOut;
    }
}