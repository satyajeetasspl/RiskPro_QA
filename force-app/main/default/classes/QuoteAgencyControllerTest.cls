@IsTest
private class QuoteAgencyControllerTest {

    @TestSetup
    static void setupTestData() {
        // Lead
        Lead testLead = new Lead(
            LastName = 'Test',
            Company = 'Test Company',
            State = 'AR'
        );
        insert testLead;

        // Account + Opportunity
        Account testAccount = new Account(
            Name = 'Test Account'
        );
        insert testAccount;

        Opportunity testOpp = new Opportunity(
            Name = 'Test Opp',
            AccountId = testAccount.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30)
        );
        insert testOpp;

        // Carriers
        Carrier__c admittedCarrier = new Carrier__c(
            Company_Name__c = 'Test Carrier',
            Admitted_Status__c = 'Admitted'
        );
        Carrier__c nonAdmittedCarrier = new Carrier__c(
            Company_Name__c = 'Non Admitted Carrier',
            Admitted_Status__c = 'Non-Admitted'
        );
        insert new List<Carrier__c>{ admittedCarrier, nonAdmittedCarrier };

        // Agency Fees - covering all color paths
        Agency_Fee__c feeAR = new Agency_Fee__c(State__c = 'Arkansas',    Line_of_Business__c = 'Auto', Agency_Fee_Amount__c = 25.00, Color__c = 'Orange');
        Agency_Fee__c feeLA = new Agency_Fee__c(State__c = 'Louisiana',   Line_of_Business__c = 'Auto', Agency_Fee_Amount__c = 25.00, Color__c = 'Green');
        Agency_Fee__c feeCT = new Agency_Fee__c(State__c = 'Connecticut', Line_of_Business__c = 'Auto', Agency_Fee_Amount__c = 25.00, Color__c = 'Yellow');
        Agency_Fee__c feeTX = new Agency_Fee__c(State__c = 'Texas',       Line_of_Business__c = 'Home', Agency_Fee_Amount__c = 50.00, Color__c = 'Blue');
        Agency_Fee__c feeAL = new Agency_Fee__c(State__c = 'Alabama',     Line_of_Business__c = 'Auto', Agency_Fee_Amount__c = 25.00, Color__c = 'Purple');
        Agency_Fee__c feeFL = new Agency_Fee__c(State__c = 'Florida',     Line_of_Business__c = 'Auto', Agency_Fee_Amount__c = 25.00, Color__c = 'Red');
        Agency_Fee__c feeWA = new Agency_Fee__c(State__c = 'Washington',  Line_of_Business__c = 'Auto', Agency_Fee_Amount__c = 25.00, Color__c = 'White');
        insert new List<Agency_Fee__c>{ feeAR, feeLA, feeCT, feeTX, feeAL, feeFL, feeWA };

        // Existing Quote on Lead
        Policy_Information__c leadQuote = new Policy_Information__c(
            Lead__c = testLead.Id,
            Is_Quote__c = true,
            Premium__c = '100.00',
            Agency_State__c = 'Arkansas'
        );
        insert leadQuote;

        // Existing Quote on Opportunity
        Policy_Information__c oppQuote = new Policy_Information__c(
            Opportunity__c = testOpp.Id,
            Is_Quote__c = true,
            Premium__c = '200.00',
            Agency_State__c = 'Texas'
        );
        insert oppQuote;
    }

    // ─── getCarrierOptions ────────────────────────────────────────────────────

    @IsTest
    static void testGetCarrierOptions() {
        Test.startTest();
        QuoteAgencyController.getCarrierOptions();
        Test.stopTest();
    }

    // ─── getAgencyFeeMap ──────────────────────────────────────────────────────

    @IsTest
    static void testGetAgencyFeeMap() {
        Test.startTest();
        QuoteAgencyController.getAgencyFeeMap();
        Test.stopTest();
    }

    // ─── checkIsSystemAdmin ───────────────────────────────────────────────────

    @IsTest
    static void testCheckIsSystemAdmin() {
        Test.startTest();
        QuoteAgencyController.checkIsSystemAdmin();
        Test.stopTest();
    }

    // ─── getRecordDetails ─────────────────────────────────────────────────────

    @IsTest
    static void testGetRecordDetails_Lead() {
        Lead testLead = [SELECT Id FROM Lead LIMIT 1];
        Test.startTest();
        QuoteAgencyController.getRecordDetails(testLead.Id);
        Test.stopTest();
    }

    @IsTest
    static void testGetRecordDetails_Opportunity() {
        Opportunity testOpp = [SELECT Id FROM Opportunity LIMIT 1];
        Test.startTest();
        QuoteAgencyController.getRecordDetails(testOpp.Id);
        Test.stopTest();
    }

    @IsTest
    static void testGetRecordDetails_Null() {
        Test.startTest();
        QuoteAgencyController.getRecordDetails(null);
        Test.stopTest();
    }

    // ─── getExistingQuotes ────────────────────────────────────────────────────

    @IsTest
    static void testGetExistingQuotes_Lead() {
        Lead testLead = [SELECT Id FROM Lead LIMIT 1];
        Test.startTest();
        QuoteAgencyController.getExistingQuotes(testLead.Id);
        Test.stopTest();
    }

    @IsTest
    static void testGetExistingQuotes_Opportunity() {
        Opportunity testOpp = [SELECT Id FROM Opportunity LIMIT 1];
        Test.startTest();
        QuoteAgencyController.getExistingQuotes(testOpp.Id);
        Test.stopTest();
    }

    // ─── saveQuotes – Lead ────────────────────────────────────────────────────

    @IsTest
    static void testSaveQuotes_Lead_Basic() {
        Lead testLead = [SELECT Id FROM Lead LIMIT 1];
        Policy_Information__c existing = [SELECT Id FROM Policy_Information__c WHERE Lead__c != null LIMIT 1];

        Policy_Information__c quoteAR = new Policy_Information__c(Premium__c = '500.00', Agency_State__c = 'Arkansas');
        Policy_Information__c quoteOther = new Policy_Information__c(Premium__c = '300.00', Agency_State__c = 'Texas');
        Policy_Information__c quoteNullPremium = new Policy_Information__c(Premium__c = null, Agency_State__c = 'Ohio');

        Test.startTest();
        QuoteAgencyController.saveQuotes(
            testLead.Id,
            new List<Policy_Information__c>{ quoteAR, quoteOther, quoteNullPremium },
            new List<Id>{ existing.Id }
        );
        Test.stopTest();
    }

    @IsTest
    static void testSaveQuotes_Lead_WaiverRequested() {
        Lead testLead = [SELECT Id FROM Lead LIMIT 1];
        Policy_Information__c quoteWaiver = new Policy_Information__c(
            Premium__c = '500.00',
            Agency_State__c = 'Arkansas',
            Agency_Fee_Waiver_Request__c = true,
            Agency_Fee_Waiver_Decision__c = 'Pending'
        );
        Test.startTest();
        QuoteAgencyController.saveQuotes(testLead.Id, new List<Policy_Information__c>{ quoteWaiver }, new List<Id>());
        Test.stopTest();
    }

    // ─── saveQuotes – Opportunity ─────────────────────────────────────────────

    @IsTest
    static void testSaveQuotes_Opportunity_Basic() {
        Opportunity testOpp = [SELECT Id FROM Opportunity LIMIT 1];
        Policy_Information__c existing = [SELECT Id FROM Policy_Information__c WHERE Opportunity__c != null LIMIT 1];

        Policy_Information__c newQuote = new Policy_Information__c(Premium__c = '400.00', Agency_State__c = 'Texas');

        Test.startTest();
        QuoteAgencyController.saveQuotes(
            testOpp.Id,
            new List<Policy_Information__c>{ newQuote },
            new List<Id>{ existing.Id }
        );
        Test.stopTest();
    }

    @IsTest
    static void testSaveQuotes_Opportunity_ArkansasFee() {
        Opportunity testOpp = [SELECT Id FROM Opportunity LIMIT 1];
        Policy_Information__c quoteAR = new Policy_Information__c(Premium__c = '600.00', Agency_State__c = 'Arkansas');

        Test.startTest();
        QuoteAgencyController.saveQuotes(testOpp.Id, new List<Policy_Information__c>{ quoteAR }, new List<Id>());
        Test.stopTest();
    }

    // ─── saveQuotes – Error paths ─────────────────────────────────────────────

    @IsTest
    static void testSaveQuotes_NullInputsException() {
        Test.startTest();
        try {
            QuoteAgencyController.saveQuotes(null, null, null);
        } catch (Exception e) {}
        Test.stopTest();
    }

    @IsTest
    static void testSaveQuotes_EmptyListsException() {
        Lead testLead = [SELECT Id FROM Lead LIMIT 1];
        Test.startTest();
        try {
            QuoteAgencyController.saveQuotes(testLead.Id, new List<Policy_Information__c>(), new List<Id>());
        } catch (Exception e) {}
        Test.stopTest();
    }

    // ─── savePDFToRecord – Lead paths ─────────────────────────────────────────

    @IsTest
    static void testSavePDFToRecord_Lead_Orange() {
        Lead testLead = [SELECT Id FROM Lead LIMIT 1];
        String json = '[{"AgencyState":"Arkansas","State":"Arkansas","Premium_c":100.00,"AgencyFee":25.00,"Carrier":"Test Carrier"}]';
        Test.startTest();
        QuoteAgencyController.savePDFToRecord(testLead.Id, json, 'Test');
        Test.stopTest();
    }

    @IsTest
    static void testSavePDFToRecord_Lead_Green() {
        Lead testLead = [SELECT Id FROM Lead LIMIT 1];
        String json = '[{"AgencyState":"Louisiana","State":"Louisiana","Premium_c":100.00,"AgencyFee":25.00,"Carrier":"Test Carrier"}]';
        Test.startTest();
        QuoteAgencyController.savePDFToRecord(testLead.Id, json, 'Test');
        Test.stopTest();
    }

    @IsTest
    static void testSavePDFToRecord_Lead_Yellow() {
        Lead testLead = [SELECT Id FROM Lead LIMIT 1];
        String json = '[{"AgencyState":"Connecticut","State":"Connecticut","Premium_c":100.00,"AgencyFee":25.00,"Carrier":"Test Carrier"}]';
        Test.startTest();
        QuoteAgencyController.savePDFToRecord(testLead.Id, json, 'Test');
        Test.stopTest();
    }

    @IsTest
    static void testSavePDFToRecord_Lead_CTHome() {
        Lead testLead = [SELECT Id FROM Lead LIMIT 1];
        String json = '[{"AgencyState":"CT","State":"CT","Lines":"Home","Premium_c":100.00,"AgencyFee":25.00,"Carrier":"Test Carrier"}]';
        Test.startTest();
        QuoteAgencyController.savePDFToRecord(testLead.Id, json, 'Test');
        Test.stopTest();
    }

    @IsTest
    static void testSavePDFToRecord_Lead_Blue() {
        Lead testLead = [SELECT Id FROM Lead LIMIT 1];
        String json = '[{"AgencyState":"Texas","State":"Texas","Lines":"Home","Premium_c":100.00,"AgencyFee":50.00,"Carrier":"Test Carrier"}]';
        Test.startTest();
        QuoteAgencyController.savePDFToRecord(testLead.Id, json, 'Test');
        Test.stopTest();
    }

    @IsTest
    static void testSavePDFToRecord_Lead_Purple() {
        Lead testLead = [SELECT Id FROM Lead LIMIT 1];
        String json = '[{"AgencyState":"Alabama","State":"Alabama","Premium_c":100.00,"AgencyFee":25.00,"Carrier":"Test Carrier"}]';
        Test.startTest();
        QuoteAgencyController.savePDFToRecord(testLead.Id, json, 'Test');
        Test.stopTest();
    }

    @IsTest
    static void testSavePDFToRecord_Lead_Red() {
        Lead testLead = [SELECT Id FROM Lead LIMIT 1];
        String json = '[{"AgencyState":"Florida","State":"Florida","Premium_c":100.00,"AgencyFee":0.00,"Carrier":"Test Carrier"}]';
        Test.startTest();
        QuoteAgencyController.savePDFToRecord(testLead.Id, json, 'Test');
        Test.stopTest();
    }

    @IsTest
    static void testSavePDFToRecord_Lead_White() {
        Lead testLead = [SELECT Id FROM Lead LIMIT 1];
        String json = '[{"AgencyState":"Washington","State":"Washington","Premium_c":100.00,"AgencyFee":25.00,"Carrier":"Test Carrier"}]';
        Test.startTest();
        QuoteAgencyController.savePDFToRecord(testLead.Id, json, 'Test');
        Test.stopTest();
    }

    @IsTest
    static void testSavePDFToRecord_Lead_WaiverRed() {
        Lead testLead = [SELECT Id FROM Lead LIMIT 1];
        String json = '[{"AgencyState":"Texas","State":"Texas","Lines":"Home","Premium_c":100.00,"AgencyFee":50.00,"WaiverRequested":true,"Carrier":"Test Carrier"}]';
        Test.startTest();
        QuoteAgencyController.savePDFToRecord(testLead.Id, json, 'Test');
        Test.stopTest();
    }

    @IsTest
    static void testSavePDFToRecord_Lead_NonAdmittedCarrier() {
        Lead testLead = [SELECT Id FROM Lead LIMIT 1];
        String json = '[{"AgencyState":"Texas","State":"Texas","Lines":"Home","Premium_c":100.00,"AgencyFee":50.00,"Carrier":"Non Admitted Carrier"}]';
        Test.startTest();
        QuoteAgencyController.savePDFToRecord(testLead.Id, json, 'Test');
        Test.stopTest();
    }

    @IsTest
    static void testSavePDFToRecord_Lead_MixedCarrier() {
        Lead testLead = [SELECT Id FROM Lead LIMIT 1];
        // Same carrier appearing as both Admitted and Non-Admitted triggers "Mixed" path
        String json = '[{"AgencyState":"Texas","State":"Texas","Lines":"Home","Premium_c":100.00,"AgencyFee":50.00,"Carrier":"Test Carrier"},' +
                       '{"AgencyState":"Texas","State":"Texas","Lines":"Auto","Premium_c":200.00,"AgencyFee":0.00,"Carrier":"Test Carrier"}]';
        Test.startTest();
        QuoteAgencyController.savePDFToRecord(testLead.Id, json, 'Test');
        Test.stopTest();
    }

    @IsTest
    static void testSavePDFToRecord_Lead_MultiState() {
        Lead testLead = [SELECT Id FROM Lead LIMIT 1];
        String json = '[{"AgencyState":"Arkansas","State":"Arkansas","Premium_c":100.00,"AgencyFee":25.00,"Carrier":"Test Carrier"},' +
                       '{"AgencyState":"Texas","State":"Texas","Lines":"Home","Premium_c":200.00,"AgencyFee":50.00,"Carrier":"Test Carrier"}]';
        Test.startTest();
        QuoteAgencyController.savePDFToRecord(testLead.Id, json, 'Test');
        Test.stopTest();
    }

    @IsTest
    static void testSavePDFToRecord_Lead_BlankState() {
        Lead testLead = [SELECT Id FROM Lead LIMIT 1];
        String json = '[{"AgencyState":"","State":"","Premium_c":100.00,"AgencyFee":25.00,"Carrier":"Test Carrier"}]';
        Test.startTest();
        QuoteAgencyController.savePDFToRecord(testLead.Id, json, 'Test');
        Test.stopTest();
    }

    @IsTest
    static void testSavePDFToRecord_Lead_NoFeeRecord() {
        Lead testLead = [SELECT Id FROM Lead LIMIT 1];
        String json = '[{"AgencyState":"Alaska","State":"Alaska","Premium_c":100.00,"AgencyFee":25.00,"Carrier":"Test Carrier"}]';
        Test.startTest();
        QuoteAgencyController.savePDFToRecord(testLead.Id, json, 'Test');
        Test.stopTest();
    }

    @IsTest
    static void testSavePDFToRecord_Lead_NullRecordName() {
        Lead testLead = [SELECT Id FROM Lead LIMIT 1];
        String json = '[{"AgencyState":"Arkansas","State":"Arkansas","Premium_c":100.00,"AgencyFee":25.00,"Carrier":"Test Carrier"}]';
        Test.startTest();
        QuoteAgencyController.savePDFToRecord(testLead.Id, json, null);
        Test.stopTest();
    }

    // ─── savePDFToRecord – Opportunity path ───────────────────────────────────

    @IsTest
    static void testSavePDFToRecord_Opportunity_Blue() {
        Opportunity testOpp = [SELECT Id FROM Opportunity LIMIT 1];
        String json = '[{"AgencyState":"Texas","State":"Texas","Lines":"Home","Premium_c":100.00,"AgencyFee":50.00,"Carrier":"Test Carrier"}]';
        Test.startTest();
        QuoteAgencyController.savePDFToRecord(testOpp.Id, json, 'Test Opp');
        Test.stopTest();
    }

    @IsTest
    static void testSavePDFToRecord_Opportunity_Red() {
        Opportunity testOpp = [SELECT Id FROM Opportunity LIMIT 1];
        String json = '[{"AgencyState":"Florida","State":"Florida","Premium_c":100.00,"AgencyFee":0.00,"Carrier":"Test Carrier"}]';
        Test.startTest();
        QuoteAgencyController.savePDFToRecord(testOpp.Id, json, 'Test Opp');
        Test.stopTest();
    }

    // ─── savePDFToRecord – Exception path ─────────────────────────────────────

    @IsTest
    static void testSavePDFToRecord_Exception() {
        Lead testLead = [SELECT Id FROM Lead LIMIT 1];
        Test.startTest();
        try {
            QuoteAgencyController.savePDFToRecord(testLead.Id, 'not valid json {{', 'Test');
        } catch (Exception e) {}
        Test.stopTest();
    }
}