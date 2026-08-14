@isTest
public class QuoteSheetControllerTest {

    @testSetup
    static void setup() {
        // Create Lead
        Lead l = new Lead(
            FirstName = 'Test',
            LastName  = 'Lead',
            Company   = 'Test Co',
            Status    = 'Open - Not Contacted',
            Email     = 'testlead@example.com'
        );
        insert l;

        // Create Account
        Account acc = new Account(
            Name             = 'Test Account',
            First_Name_FI__c = 'Test',
            Last_Name_FI__c  = 'Acc'
        );
        insert acc;

        // Create Opportunity
        Opportunity opp = new Opportunity(
            Name      = 'Test Opp',
            AccountId = acc.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30)
        );
        insert opp;

        // Properties__c address records for Lead
        Properties__c propLead = new Properties__c(Lead__c = l.Id);
        insert propLead;

        // Lead Property_Information__c – primary (no Properties__c link)
        Property_Information__c piLeadPrimary = new Property_Information__c(
            Lead__c      = l.Id,
            Year_Built__c = '2020'
        );
        insert piLeadPrimary;

        // Lead Property_Information__c – linked to Properties__c
        Property_Information__c piLeadLinked = new Property_Information__c(
            Lead__c       = l.Id,
            Year_Built__c = '2019',
            Properties__c = propLead.Id
        );
        insert piLeadLinked;

        // Properties__c address record for Account
        Properties__c propAcc = new Properties__c(Account__c = acc.Id);
        insert propAcc;

        // Account Property_Information__c – primary
        Property_Information__c piAccPrimary = new Property_Information__c(
            Account__c    = acc.Id,
            Year_Built__c = '2021'
        );
        insert piAccPrimary;

        // Account Property_Information__c – linked to Properties__c
        Property_Information__c piAccLinked = new Property_Information__c(
            Account__c    = acc.Id,
            Year_Built__c = '2018',
            Properties__c = propAcc.Id
        );
        insert piAccLinked;

        // Lead child records – all types
        insert new Driver__c(Lead__c = l.Id, First_Name__c = 'Driver');
        insert new Vehicle__c(Lead__c = l.Id, Year__c = '2020', Make__c = 'Toyota', Model__c = 'Camry');
        insert new Auto_Incidents_Violations__c(Lead__c = l.Id, Incident_Description__c = 'At-Fault Accident');
        insert new Home_Losses_Claims__c(Lead__c = l.Id, Cause_of_Loss__c = 'Fire');
        insert new Prior_Insurance_Information__c(Lead__c = l.Id, Carrier_Name__c = 'State Farm', Line__c = 'Home');

        // Account child records – all types
        insert new Driver__c(Account__c = acc.Id, First_Name__c = 'AccDriver');
        insert new Vehicle__c(Account__c = acc.Id, Year__c = '2021', Make__c = 'Honda', Model__c = 'Civic');
        insert new Auto_Incidents_Violations__c(Account__c = acc.Id, Incident_Description__c = 'At-Fault Accident');
        insert new Home_Losses_Claims__c(Account__c = acc.Id, Cause_of_Loss__c = 'Hail');
        insert new Prior_Insurance_Information__c(Account__c = acc.Id, Carrier_Name__c = 'Allstate', Line__c = 'Auto');
    }

    // ── GET tests ─────────────────────────────────────────────────────────────

    @isTest
    static void testGetLeadData() {
        Lead l = [SELECT Id FROM Lead LIMIT 1];
        Test.startTest();
        QuoteSheetController.getQuoteData(l.Id, 'Lead');
        Test.stopTest();
    }

    @isTest
    static void testGetOppData() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Test.startTest();
        QuoteSheetController.getQuoteData(opp.Id, 'Opportunity');
        Test.stopTest();
    }

    // ── SAVE Lead – minimal ───────────────────────────────────────────────────

    @isTest
    static void testSaveLeadData_Minimal() {
        Lead l = [SELECT Id, LastName FROM Lead LIMIT 1];

        QuoteSheetController.QuotePayload payload = new QuoteSheetController.QuotePayload();
        payload.leadId            = l.Id;
        payload.firstName         = 'Updated';
        payload.lastName          = l.LastName;
        payload.showSecondInsured = false;

        QuoteSheetController.PropertyWrapper pw = new QuoteSheetController.PropertyWrapper();
        pw.details = new Property_Information__c(Year_Built__c = '2022', Roof_ACV__c = false);
        pw.street  = '456 Prop St';
        pw.city    = 'Prop City';
        pw.state   = 'FL';
        pw.zip     = '33101';

        payload.properties = new List<QuoteSheetController.PropertyWrapper>{ pw };

        Test.startTest();
        QuoteSheetController.saveQuoteData(payload);
        Test.stopTest();
    }

    // ── SAVE Lead – full payload with all child records ───────────────────────

    @isTest
    static void testSaveLeadData_FullPayload() {
        Lead l = [SELECT Id, LastName FROM Lead LIMIT 1];

        QuoteSheetController.QuotePayload payload = new QuoteSheetController.QuotePayload();
        payload.leadId             = l.Id;
        payload.firstName          = 'Full';
        payload.lastName           = 'Test';
        payload.email              = 'full@test.com';
        payload.phone              = '5551234567';
        payload.secondaryPhone     = '5559876543';
        payload.insuredStreet      = '100 Main St';
        payload.insuredCity        = 'Miami';
        payload.insuredState       = 'FL';
        payload.insuredZip         = '33101';
        payload.insuredCountry     = 'US';
        payload.dob                = Date.newInstance(1990, 1, 1);
        payload.maritalStatus      = 'Single';
        payload.occupation         = 'Engineer';
        payload.dlNumber           = 'DL123456';
        payload.dlState            = 'Florida';
        payload.siDLState          = 'Florida';
        payload.showSecondInsured  = true;
        payload.siFirstName        = 'Second';
        payload.siLastName         = 'Insured';
        payload.siPhone            = '5550001111';
        payload.siEmail            = 'si@test.com';
        payload.siDOB              = Date.newInstance(1992, 6, 15);
        payload.siOccupation       = 'Nurse';
        payload.siMaritalStatus    = 'Married';

        // Property 1 (primary)
        QuoteSheetController.PropertyWrapper pw1 = new QuoteSheetController.PropertyWrapper();
        pw1.details = new Property_Information__c(
            Year_Built__c                = '2010',
            Square_Footage__c            = 2000,
            Swimming_Pool_on_Premises__c = 'In-Ground',
            Hot_Tub_on_Premises__c       = 'Fence',
            Is_Trampoline__c             = false,
            Is_Animal__c                 = false,
            Roof_ACV__c                  = false
        );
        pw1.street      = '100 Main St';
        pw1.city        = 'Miami';
        pw1.state       = 'FL';
        pw1.zip         = '33101';
        pw1.coverageForm = 'HO3';
        pw1.animals     = new List<Animals_on_Premises__c>();
        pw1.deletedAnimalIds = new List<String>();

        // Property 2 (secondary – will create a new Properties__c)
        QuoteSheetController.PropertyWrapper pw2 = new QuoteSheetController.PropertyWrapper();
        pw2.details = new Property_Information__c(
            Year_Built__c = '2015',
            Roof_ACV__c   = false
        );
        pw2.street = '200 Oak Ave';
        pw2.city   = 'Orlando';
        pw2.state  = 'FL';
        pw2.zip    = '32801';

        payload.properties = new List<QuoteSheetController.PropertyWrapper>{ pw1, pw2 };

        // Prior insurance
        payload.priorInsurances = new List<Prior_Insurance_Information__c>{
            new Prior_Insurance_Information__c(Carrier_Name__c = 'Liberty Mutual', Line__c = 'Home')
        };

        // Drivers
        payload.drivers = new List<Driver__c>{
            new Driver__c(First_Name__c = 'Jane', Last_Name__c = 'Doe')
        };

        // Vehicles
        payload.vehicles = new List<Vehicle__c>{
            new Vehicle__c(Year__c = '2022', Make__c = 'Ford', Model__c = 'F-150')
        };

        // Incidents
        payload.incidents = new List<Auto_Incidents_Violations__c>{
            new Auto_Incidents_Violations__c(Incident_Description__c = 'At-Fault Accident')
        };

        // Losses
        payload.losses = new List<Home_Losses_Claims__c>{
            new Home_Losses_Claims__c(Cause_of_Loss__c = 'Hail')
        };

        payload.deletedPropertyIds       = new List<String>();
        payload.deletedPriorInsuranceIds = new List<String>();
        payload.deletedDriverIds         = new List<String>();
        payload.deletedVehicleIds        = new List<String>();
        payload.deletedIncidentIds       = new List<String>();
        payload.deletedLossIds           = new List<String>();

        Test.startTest();
        QuoteSheetController.saveQuoteData(payload);
        Test.stopTest();
    }

    // ── SAVE Lead – with existing Properties__c id on secondary property ──────

    @isTest
    static void testSaveLeadData_WithExistingPropertyId() {
        Lead l              = [SELECT Id, LastName FROM Lead LIMIT 1];
        Properties__c prop  = [SELECT Id FROM Properties__c WHERE Lead__c = :l.Id LIMIT 1];

        QuoteSheetController.QuotePayload payload = new QuoteSheetController.QuotePayload();
        payload.leadId            = l.Id;
        payload.lastName          = l.LastName;
        payload.showSecondInsured = false;

        // Property 1
        QuoteSheetController.PropertyWrapper pw1 = new QuoteSheetController.PropertyWrapper();
        pw1.details = new Property_Information__c(Roof_ACV__c = false);
        pw1.street  = '10 First St';
        pw1.city    = 'Tampa';
        pw1.state   = 'FL';
        pw1.zip     = '33601';

        // Property 2 – linked to existing Properties__c
        QuoteSheetController.PropertyWrapper pw2 = new QuoteSheetController.PropertyWrapper();
        pw2.details             = new Property_Information__c(Properties__c = prop.Id, Roof_ACV__c = false);
        pw2.street              = '20 Second St';
        pw2.city                = 'Tampa';
        pw2.state               = 'FL';
        pw2.zip                 = '33602';

        payload.properties = new List<QuoteSheetController.PropertyWrapper>{ pw1, pw2 };

        Test.startTest();
        QuoteSheetController.saveQuoteData(payload);
        Test.stopTest();
    }

    // ── SAVE Lead – with animals on a property ────────────────────────────────

    @isTest
    static void testSaveLeadData_WithAnimals() {
        Lead l = [SELECT Id, LastName FROM Lead LIMIT 1];

        QuoteSheetController.QuotePayload payload = new QuoteSheetController.QuotePayload();
        payload.leadId            = l.Id;
        payload.lastName          = l.LastName;
        payload.showSecondInsured = false;

        // Create a PI with an Id so animals can be linked
        Property_Information__c pi = new Property_Information__c(
            Lead__c       = l.Id,
            Year_Built__c = '2000',
            Roof_ACV__c   = false
        );
        insert pi;

        Animals_on_Premises__c animal = new Animals_on_Premises__c(
            Property_Information__c = pi.Id,
            Number__c               = 1
        );
        insert animal;

        QuoteSheetController.PropertyWrapper pw1 = new QuoteSheetController.PropertyWrapper();
        pw1.details = pi;
        pw1.street  = '30 Animal St';
        pw1.city    = 'Jacksonville';
        pw1.state   = 'FL';
        pw1.zip     = '32099';
        pw1.animals = new List<Animals_on_Premises__c>{ animal };

        payload.properties = new List<QuoteSheetController.PropertyWrapper>{ pw1 };

        Test.startTest();
        QuoteSheetController.saveQuoteData(payload);
        Test.stopTest();
    }

    // ── SAVE Lead – delete all record types ───────────────────────────────────

    @isTest
    static void testSaveLeadData_DeleteAllTypes() {
        Lead l = [SELECT Id, LastName FROM Lead LIMIT 1];

        Property_Information__c pi = [SELECT Id FROM Property_Information__c WHERE Lead__c = :l.Id LIMIT 1];
        Driver__c               dr = [SELECT Id FROM Driver__c                WHERE Lead__c = :l.Id LIMIT 1];
        Vehicle__c              vh = [SELECT Id FROM Vehicle__c               WHERE Lead__c = :l.Id LIMIT 1];
        Auto_Incidents_Violations__c inc = [SELECT Id FROM Auto_Incidents_Violations__c WHERE Lead__c = :l.Id LIMIT 1];
        Home_Losses_Claims__c   los = [SELECT Id FROM Home_Losses_Claims__c   WHERE Lead__c = :l.Id LIMIT 1];
        Prior_Insurance_Information__c pri = [SELECT Id FROM Prior_Insurance_Information__c WHERE Lead__c = :l.Id LIMIT 1];

        QuoteSheetController.QuotePayload payload = new QuoteSheetController.QuotePayload();
        payload.leadId                   = l.Id;
        payload.lastName                 = l.LastName;
        payload.showSecondInsured        = false;
        payload.deletedPropertyIds       = new List<String>{ String.valueOf(pi.Id) };
        payload.deletedDriverIds         = new List<String>{ String.valueOf(dr.Id) };
        payload.deletedVehicleIds        = new List<String>{ String.valueOf(vh.Id) };
        payload.deletedIncidentIds       = new List<String>{ String.valueOf(inc.Id) };
        payload.deletedLossIds           = new List<String>{ String.valueOf(los.Id) };
        payload.deletedPriorInsuranceIds = new List<String>{ String.valueOf(pri.Id) };

        Test.startTest();
        QuoteSheetController.saveQuoteData(payload);
        Test.stopTest();
    }

    // ── SAVE Opp – minimal ────────────────────────────────────────────────────

    @isTest
    static void testSaveOppData_Minimal() {
        Opportunity opp = [SELECT Id, AccountId, Account.Last_Name_FI__c FROM Opportunity LIMIT 1];

        QuoteSheetController.QuotePayload payload = new QuoteSheetController.QuotePayload();
        payload.oppId             = opp.Id;
        payload.accountId         = opp.AccountId;
        payload.firstName         = 'Updated';
        payload.lastName          = opp.Account.Last_Name_FI__c;
        payload.insuredStreet     = '123 Acc St';
        payload.insuredCity       = 'Acc City';
        payload.showSecondInsured = false;

        Test.startTest();
        QuoteSheetController.saveQuoteData(payload);
        Test.stopTest();
    }

    // ── SAVE Opp – full payload with properties and child records ─────────────

    @isTest
    static void testSaveOppData_FullPayload() {
        Opportunity opp = [SELECT Id, AccountId, Account.Last_Name_FI__c FROM Opportunity LIMIT 1];

        QuoteSheetController.QuotePayload payload = new QuoteSheetController.QuotePayload();
        payload.oppId             = opp.Id;
        payload.accountId         = opp.AccountId;
        payload.firstName         = 'OppFirst';
        payload.lastName          = 'OppLast';
        payload.email             = 'opp@test.com';
        payload.phone             = '5551112222';
        payload.showSecondInsured = true;
        payload.siFirstName       = 'SIOppFirst';
        payload.siLastName        = 'SIOppLast';
        payload.description       = 'Test description';
        payload.dlState            = 'Florida';
        payload.siDLState          = 'Florida';

        QuoteSheetController.PropertyWrapper pw1 = new QuoteSheetController.PropertyWrapper();
        pw1.details = new Property_Information__c(
            Year_Built__c = '2005',
            Roof_ACV__c   = false
        );
        pw1.street = '500 Opp Rd';
        pw1.city   = 'Atlanta';
        pw1.state  = 'GA';
        pw1.zip    = '30301';
        pw1.animals         = new List<Animals_on_Premises__c>();
        pw1.deletedAnimalIds= new List<String>();

        QuoteSheetController.PropertyWrapper pw2 = new QuoteSheetController.PropertyWrapper();
        pw2.details = new Property_Information__c(Roof_ACV__c = false);
        pw2.street  = '600 Opp Blvd';
        pw2.city    = 'Atlanta';
        pw2.state   = 'GA';
        pw2.zip     = '30302';

        payload.properties = new List<QuoteSheetController.PropertyWrapper>{ pw1, pw2 };

        payload.priorInsurances = new List<Prior_Insurance_Information__c>{
            new Prior_Insurance_Information__c(Carrier_Name__c = 'Travelers', Line__c = 'Home')
        };
        payload.drivers = new List<Driver__c>{
            new Driver__c(First_Name__c = 'OppDriver', Last_Name__c = 'Test')
        };
        payload.vehicles = new List<Vehicle__c>{
            new Vehicle__c(Year__c = '2019', Make__c = 'Chevy', Model__c = 'Malibu')
        };
        payload.incidents = new List<Auto_Incidents_Violations__c>{
            new Auto_Incidents_Violations__c(Incident_Description__c = 'At-Fault Accident')
        };
        payload.losses = new List<Home_Losses_Claims__c>{
            new Home_Losses_Claims__c(Cause_of_Loss__c = 'Hail')
        };

        payload.deletedPropertyIds       = new List<String>();
        payload.deletedPriorInsuranceIds = new List<String>();
        payload.deletedDriverIds         = new List<String>();
        payload.deletedVehicleIds        = new List<String>();
        payload.deletedIncidentIds       = new List<String>();
        payload.deletedLossIds           = new List<String>();

        Test.startTest();
        QuoteSheetController.saveQuoteData(payload);
        Test.stopTest();
    }

    // ── SAVE Opp – with existing Properties__c id on secondary property ───────

    @isTest
    static void testSaveOppData_WithExistingPropertyId() {
        Opportunity    opp  = [SELECT Id, AccountId, Account.Last_Name_FI__c FROM Opportunity LIMIT 1];
        Properties__c  prop = [SELECT Id FROM Properties__c WHERE Account__c = :opp.AccountId LIMIT 1];

        QuoteSheetController.QuotePayload payload = new QuoteSheetController.QuotePayload();
        payload.oppId             = opp.Id;
        payload.accountId         = opp.AccountId;
        payload.lastName          = opp.Account.Last_Name_FI__c;
        payload.showSecondInsured = false;

        QuoteSheetController.PropertyWrapper pw1 = new QuoteSheetController.PropertyWrapper();
        pw1.details = new Property_Information__c(Roof_ACV__c = false);
        pw1.street  = '10 First Ave';
        pw1.city    = 'Charlotte';
        pw1.state   = 'NC';
        pw1.zip     = '28201';

        QuoteSheetController.PropertyWrapper pw2 = new QuoteSheetController.PropertyWrapper();
        pw2.details = new Property_Information__c(Properties__c = prop.Id, Roof_ACV__c = false);
        pw2.street  = '20 Second Ave';
        pw2.city    = 'Charlotte';
        pw2.state   = 'NC';
        pw2.zip     = '28202';

        payload.properties = new List<QuoteSheetController.PropertyWrapper>{ pw1, pw2 };

        Test.startTest();
        QuoteSheetController.saveQuoteData(payload);
        Test.stopTest();
    }

    // ── SAVE Opp – delete all record types ───────────────────────────────────

    @isTest
    static void testSaveOppData_DeleteAllTypes() {
        Opportunity opp = [SELECT Id, AccountId, Account.Last_Name_FI__c FROM Opportunity LIMIT 1];

        Property_Information__c pi  = [SELECT Id FROM Property_Information__c WHERE Account__c = :opp.AccountId LIMIT 1];
        Driver__c               dr  = [SELECT Id FROM Driver__c                WHERE Account__c = :opp.AccountId LIMIT 1];
        Vehicle__c              vh  = [SELECT Id FROM Vehicle__c               WHERE Account__c = :opp.AccountId LIMIT 1];
        Auto_Incidents_Violations__c inc = [SELECT Id FROM Auto_Incidents_Violations__c WHERE Account__c = :opp.AccountId LIMIT 1];
        Home_Losses_Claims__c   los = [SELECT Id FROM Home_Losses_Claims__c   WHERE Account__c = :opp.AccountId LIMIT 1];
        Prior_Insurance_Information__c pri = [SELECT Id FROM Prior_Insurance_Information__c WHERE Account__c = :opp.AccountId LIMIT 1];

        QuoteSheetController.QuotePayload payload = new QuoteSheetController.QuotePayload();
        payload.oppId                    = opp.Id;
        payload.accountId                = opp.AccountId;
        payload.lastName                 = opp.Account.Last_Name_FI__c;
        payload.showSecondInsured        = false;
        payload.deletedPropertyIds       = new List<String>{ String.valueOf(pi.Id) };
        payload.deletedDriverIds         = new List<String>{ String.valueOf(dr.Id) };
        payload.deletedVehicleIds        = new List<String>{ String.valueOf(vh.Id) };
        payload.deletedIncidentIds       = new List<String>{ String.valueOf(inc.Id) };
        payload.deletedLossIds           = new List<String>{ String.valueOf(los.Id) };
        payload.deletedPriorInsuranceIds = new List<String>{ String.valueOf(pri.Id) };

        Test.startTest();
        QuoteSheetController.saveQuoteData(payload);
        Test.stopTest();
    }

    // ── Error path – null payload ─────────────────────────────────────────────

    @isTest
    static void testSaveQuoteData_NullPayload() {
        Test.startTest();
        try {
            QuoteSheetController.saveQuoteData(null);
        } catch (Exception e) {
            // Expected path – just exercising the null guard
        }
        Test.stopTest();
    }

    // ── GET – Lead with linked Properties__c (covers merge branch) ────────────

    @isTest
    static void testGetLeadData_WithLinkedProperties() {
        Lead l = [SELECT Id FROM Lead LIMIT 1];
        Test.startTest();
        QuoteSheetController.getQuoteData(l.Id, 'Lead');
        Test.stopTest();
    }

    // ── GET – Opp with linked Properties__c (covers merge branch) ────────────

    @isTest
    static void testGetOppData_WithLinkedProperties() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Test.startTest();
        QuoteSheetController.getQuoteData(opp.Id, 'Opportunity');
        Test.stopTest();
    }
}