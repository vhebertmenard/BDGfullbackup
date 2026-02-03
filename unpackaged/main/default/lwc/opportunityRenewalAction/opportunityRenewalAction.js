import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import renewOpportunity from '@salesforce/apex/OpportunityRenewalController.renewOpportunityLwc';

export default class OpportunityRenewalAction extends NavigationMixin(LightningElement) {
    @api recordId;

    @track loading = false;
    @track closeDate;        // 'YYYY-MM-DD'
    @track subscriptionTerm; // integer
    @track copyFiles = false;

    handleNativeDateChange = (evt) => {
        this.closeDate = evt.target.value || null;
    };

    handleInputChange = (event) => {
        const { name, value, checked } = event.target;
        if (name === 'copyFiles') {
            this.copyFiles = checked;
        } else if (name === 'subscriptionTerm') {
            const n = parseInt(value, 10);
            this.subscriptionTerm = Number.isFinite(n) && n > 0 ? n : null;
        }
    };

    bump = (e) => { e.target.style.boxShadow = '0 0 0 3px rgba(21,137,238,0.25)'; e.target.style.transform = 'translateY(-1px)'; };
    unbump = (e) => { e.target.style.boxShadow = 'none'; e.target.style.transform = 'none'; };

    handleReset = () => {
        this.closeDate = null;
        this.subscriptionTerm = null;
        this.copyFiles = false;
        const el = this.template.querySelector('#closeDateInput');
        if (el) el.value = '';
    };

    handleCreate = async () => {
        this.loading = true;
        try {
            const res = await renewOpportunity({
                opportunityId: this.recordId,
                newCloseDate: this.closeDate || null,
                copyFiles: !!this.copyFiles,
                newSubscriptionTerm: this.subscriptionTerm ?? null
            });

            this.dispatchEvent(new ShowToastEvent({
                title: 'Renewal Created',
                message: (res && res.message) || 'Success',
                variant: 'success'
            }));

            if (res && res.newOpportunityId) {
                this[NavigationMixin.Navigate]({
                    type: 'standard__recordPage',
                    attributes: {
                        recordId: res.newOpportunityId,
                        objectApiName: 'Opportunity',
                        actionName: 'view'
                    }
                });
            }
            // No explicit close actions per your request

        } catch (e) {
            const msg = (e && e.body && e.body.message) || e?.message || 'Unexpected error';
            this.dispatchEvent(new ShowToastEvent({
                title: 'Renewal Failed',
                message: msg,
                variant: 'error'
            }));
        } finally {
            this.loading = false;
        }
    };
}