import { LightningElement, api } from 'lwc';
import searchFleet from '@salesforce/apex/FleetSelectorController.searchFleet';
import getFleetFilterFacets from '@salesforce/apex/FleetSelectorController.getFleetFilterFacets';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

const COLUMNS = [
    { label: 'Name', fieldName: 'Name' },
    { label: 'Rental Status', fieldName: 'Rental_Status__c' },
    { label: 'WIP Asset', fieldName: 'WIP_Asset__c', type: 'boolean' },
    { label: 'Warehouse', fieldName: 'Warehouse__c' },
    { label: 'SND Location', fieldName: 'SND_Location__c' },
    { label: 'Asset Width', fieldName: 'Asset_Width__c' },
    { label: 'Asset Length', fieldName: 'Asset_Length__c' },
    { label: 'Asset Category', fieldName: 'Asset_Category__c' },
    { label: 'Complex Serial Number', fieldName: 'Complex_Serial_number__c' },
    { label: 'Type', fieldName: 'Type__c' }
];

export default class FleetSelector extends LightningElement {
    // Legacy inputs – kept ONLY because some Lightning pages / flows are configured with these properties.
    @api quoteId;
    @api quoteLineId;

    // UI
    columns = COLUMNS;
    isLoading = true;         // initial load spinner
    isTableLoading = false;   // datatable infinite loading state

    // Data
    rows = [];
    totalCount = 0;
    loadedCount = 0;

    // Paging
    pageSize = 200;
    pageNumber = 1; // 1-based
    hasMore = true;

    // Filters - options
    warehouseOptions = [{ label: 'All', value: '' }];
    sndLocationOptions = [{ label: 'All', value: '' }];
    widthOptions = [{ label: 'All', value: '' }];
    lengthOptions = [{ label: 'All', value: '' }];
    categoryOptions = [{ label: 'All', value: '' }];
    typeOptions =  [{ label: 'All', value: '' }];

    // WIP filter options
    wipFilterOptions = [
        { label: 'All', value: '' },
        { label: 'Yes', value: 'Yes' },
        { label: 'No', value: 'No' }
    ];

    // Filters - selected
    selectedWarehouse = '';
    selectedSndLocation = '';
    selectedWidth = '';     // stored as string for combobox
    selectedLength = '';    // stored as string for combobox
    selectedCategory = '';
    selectedWipFilter = '';
    selectedTypeFilter = '';

    // Debounce
    _refreshTimer;

    connectedCallback() {
        this.refresh(true);
    }

    // -------------------------
    // Filter change handlers
    // -------------------------
    handleWarehouseChange(event) {
        this.selectedWarehouse = event.detail.value;
        this.queueRefresh();
    }
    handleSndLocationChange(event) {
        this.selectedSndLocation = event.detail.value;
        this.queueRefresh();
    }
    handleWidthChange(event) {
        this.selectedWidth = event.detail.value;
        this.queueRefresh();
    }
    handleLengthChange(event) {
        this.selectedLength = event.detail.value;
        this.queueRefresh();
    }
    handleCategoryChange(event) {
        this.selectedCategory = event.detail.value;
        this.queueRefresh();
    }
    handleTypeChange(event) {
        this.selectedType = event.detail.value;
        this.queueRefresh();
    }
    handleWipFilterChange(event) {
        this.selectedWipFilter = event.detail.value;
        this.queueRefresh();
    }

    queueRefresh() {
        window.clearTimeout(this._refreshTimer);
        this._refreshTimer = window.setTimeout(() => {
            this.refresh(true);
        }, 150);
    }

    // -------------------------
    // Main refresh flow
    // -------------------------
    async refresh(reset) {
        try {
            if (reset) {
                this.isLoading = true;
                this.isTableLoading = false;

                this.rows = [];
                this.totalCount = 0;
                this.loadedCount = 0;

                this.pageNumber = 1;
                this.hasMore = true;
            }

            // 1) Get dynamic filter facets from server (adjust dropdown values)
            await this.loadFacets();

            // 2) Load first page of results
            await this.loadPage();
        } catch (err) {
            this.showToast('Error', this.normalizeError(err), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    // -------------------------
    // Facets (dynamic filter options)
    // -------------------------
    async loadFacets() {
        const resp = await getFleetFilterFacets({
            warehouse: this.selectedWarehouse || null,
            sndLocation: this.selectedSndLocation || null,
            assetWidth: this.selectedWidth ? Number(this.selectedWidth) : null,
            assetLength: this.selectedLength ? Number(this.selectedLength) : null,
            category: this.selectedCategory || null,
            type: this.selectedType || null,
            wipFilter: this.selectedWipFilter || ''
        });

        this.warehouseOptions = this.toOptions(resp?.warehouses);
        this.sndLocationOptions = this.toOptions(resp?.sndLocations);
        this.widthOptions = this.toOptions(resp?.widths);
        this.lengthOptions = this.toOptions(resp?.lengths);
        this.categoryOptions = this.toOptions(resp?.categories);
        this.typeOptions = this.toOptions(resp?.types);

        // If current selection is no longer valid, clear it (prevents "stuck" invalid filters)
        this.selectedWarehouse = this.isValueInOptions(this.selectedWarehouse, this.warehouseOptions) ? this.selectedWarehouse : '';
        this.selectedSndLocation = this.isValueInOptions(this.selectedSndLocation, this.sndLocationOptions) ? this.selectedSndLocation : '';
        this.selectedWidth = this.isValueInOptions(this.selectedWidth, this.widthOptions) ? this.selectedWidth : '';
        this.selectedLength = this.isValueInOptions(this.selectedLength, this.lengthOptions) ? this.selectedLength : '';
        this.selectedCategory = this.isValueInOptions(this.selectedCategory, this.categoryOptions) ? this.selectedCategory : '';
        this.selectedType = this.isValueInOptions(this.selectedType, this.typeOptions) ? this.selectedType : '';
    }

    toOptions(list) {
        const arr = (list || []).slice();
        const opts = arr.map(v => ({ label: String(v), value: String(v) }));
        opts.unshift({ label: 'All', value: '' });
        return opts;
    }

    isValueInOptions(val, options) {
        if (!val) return true;
        return (options || []).some(o => o.value === val);
    }

    // -------------------------
    // Paged search
    // -------------------------
    async loadPage() {
        if (!this.hasMore) return;

        this.isTableLoading = true;

        const resp = await searchFleet({
            warehouse: this.selectedWarehouse || null,
            sndLocation: this.selectedSndLocation || null,
            assetWidth: this.selectedWidth ? Number(this.selectedWidth) : null,
            assetLength: this.selectedLength ? Number(this.selectedLength) : null,
            category: this.selectedCategory || null,
            type: this.selectedType || null,
            wipFilter: this.selectedWipFilter || '',
            pageSize: this.pageSize,
            pageNumber: this.pageNumber
        });

        const newRows = resp?.records || [];
        const total = resp?.total || 0;

        // Append results (do not rebuild huge arrays repeatedly)
        this.rows = this.rows.concat(newRows);

        this.totalCount = total;
        this.loadedCount = this.rows.length;

        // Stop when complete
        if (this.loadedCount >= this.totalCount || newRows.length === 0) {
            this.hasMore = false;
        } else {
            this.pageNumber += 1;
        }

        this.isTableLoading = false;
    }

    async handleLoadMore(event) {
    // Prevent concurrent loads
        if (this.isTableLoading) {
            event.target.isLoading = false;
            return;
        }

        if (!this.hasMore) {
            event.target.isLoading = false;
            return;
        }

        event.target.isLoading = true;
     this.isTableLoading = true;

     try {
         await this.loadPage();
     } catch (err) {
            this.showToast('Error', this.normalizeError(err), 'error');
        } finally {
            this.isTableLoading = false;
            event.target.isLoading = false;
        }
    }


    // -------------------------
    // Utilities
    // -------------------------
    normalizeError(error) {
        if (!error) return 'Unknown error';
        if (Array.isArray(error?.body)) return error.body.map(e => e.message).join(', ');
        return error?.body?.message || error?.message || 'Unknown error';
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}