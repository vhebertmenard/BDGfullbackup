@IsTest
private class FleetCheckedOutServiceTest {
    @IsTest
    static void testCheckedOutUnits() {
        // Account & Opp
        Account a = new Account(Name = 'Acme');
        insert a;
        
        //Fetching Standard Pricebook
        Id stdPbId = Test.getStandardPricebookId();

        // Custom active pricebook (don’t depend on Standard PB)
        Pricebook2 pb = new Pricebook2(Name = 'Test PB', IsActive = true);
        insert pb;

        // Product & PBE
        Product2 prod = new Product2(Name = 'Test Rental Product', ProductCode = 'RENT-001', IsActive = true);
        insert prod;
        
        PricebookEntry pbestd = new PricebookEntry(
            Product2Id = prod.Id,
            Pricebook2Id = stdPbId,
            UnitPrice = 100,
            IsActive = true
        );
        insert pbestd;
        

        PricebookEntry pbe = new PricebookEntry(Product2Id = prod.Id, Pricebook2Id = pb.Id, UnitPrice = 100, IsActive = true);
        insert pbe;

        Opportunity o = new Opportunity(
            Name = 'Test Opp',
            StageName = 'Qualified',
            CloseDate = System.today().addDays(30),
            Pricebook2Id = pb.Id,
            AccountId = a.Id
        );
        insert o;

        // Primary Quote — point it to the same PB
        SBQQ__Quote__c q = new SBQQ__Quote__c(
            Quote_Name__c = 'Primary',
            SBQQ__Primary__c = true,
            SBQQ__Opportunity2__c = o.Id,
            Transaction_Type__c = 'Rental',
            Transaction_Type_Detail__c= 'Fleet Rental',
            SBQQ__SubscriptionTerm__c = 24
        );
        insert q;

        // Fleet units
        Fleet__c u1 = new Fleet__c(Name='Unit A', Rental_Status__c='Checked Out');
        Fleet__c u2 = new Fleet__c(Name='Unit B', Rental_Status__c='Available');
        insert new List<Fleet__c>{u1, u2};

        // Quote lines — use CPQ field API names
        SBQQ__QuoteLine__c ql1 = new SBQQ__QuoteLine__c(
            SBQQ__Quote__c = q.Id,
            SBQQ__Product__c = prod.Id,
            SBQQ__Quantity__c = 1,
            Unit_Price__c = 100,
            SBQQ__PricebookEntryId__c = pbe.Id,
            Unit__c = u1.Id // Checked Out
        );
        SBQQ__QuoteLine__c ql2 = new SBQQ__QuoteLine__c(
            SBQQ__Quote__c = q.Id,
            SBQQ__Product__c = prod.Id,
            SBQQ__Quantity__c = 1,
            Unit_Price__c = 100,
            SBQQ__PricebookEntryId__c = pbe.Id,
            Unit__c = u2.Id // Available
        );
        insert new List<SBQQ__QuoteLine__c>{ ql1, ql2 };

        Test.startTest();
        FleetCheckedOutService.Result res =
            FleetCheckedOutService.getCheckedOutUnitsForOpportunity(o.Id);
        Test.stopTest();

        System.assertEquals(true, res.hasCheckedOut, 'Should detect checked-out units');
        System.assertEquals(1, res.units.size(), 'Only one unit is checked-out');
        System.assertEquals(u1.Id, res.units[0].unitId);
        System.assertEquals('Checked Out', res.units[0].rentalStatus);
    }
}