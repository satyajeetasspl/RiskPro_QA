@IsTest
public class OpportunityNBCControllerTest {

    @TestSetup
    static void setupData() {

        // User
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User u = new User(
            Alias = 'agt2',
            Email = 'agent2@test.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'AgentTwo',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'America/New_York',
            UserName = 'agent2' + String.valueOf(System.currentTimeMillis()) + '@test.com'
        );
        insert u;

        // Carrier
        Carrier__c carrier = new Carrier__c(
            Company_Name__c = 'Test Carrier'
        );
        insert carrier;

        // Account
        Account acc = new Account(
            Name = 'Test Account',
            Address_Property__Street__s = '789 Property St',
            Address_Property__City__s = 'Prop City',
            Address_Property__StateCode__s = 'CA',
            Address_Property__PostalCode__s = '90210',
            Address_Property__CountryCode__s = 'US',
            BillingStreet = '456 Billing St',
            BillingCity = 'Bill City',
            BillingState = 'New York',
            BillingPostalCode = '10001',
            BillingCountry = 'USA'
        );
        insert acc;

        // Opportunity
        Opportunity opp = new Opportunity(
            Name = 'Test Opp',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(10),
            AccountId = acc.Id
        );
        insert opp;

        // Policy
        Policy_Information__c policy = new Policy_Information__c(
            Opportunity__c = opp.Id,
            Carrier__c = carrier.Id,
            Policy__c = '1001',
            Premium__c = '100',
            Policy_Type__c = 'NBC',
            Generate_Invoice__c = true
        );
        insert policy;
    }

    @IsTest
    static void testControllerConstructor() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        ApexPages.currentPage().getParameters().put('id', opp.Id);

        Test.startTest();
        new OpportunityNBCController();
        Test.stopTest();
    }

    @IsTest
    static void testSaveOpportunityNBC_PROPERTY() {
        Opportunity opp = [SELECT Id, AccountId FROM Opportunity LIMIT 1];

        Account acc = [
    SELECT Id, Name, Phone, Email__c,
           ShippingStreet, ShippingCity, ShippingState, ShippingPostalCode, ShippingCountry,
           BillingStreet, BillingCity, BillingState, BillingPostalCode, BillingCountry,
           NBC_Address__Street__s, NBC_Address__City__s, NBC_Address__StateCode__s, NBC_Address__PostalCode__s, NBC_Address__CountryCode__s,
           Address_Property__Street__s, Address_Property__City__s, Address_Property__StateCode__s, 
           Address_Property__PostalCode__s, Address_Property__CountryCode__s
    FROM Account WHERE Id = :opp.AccountId
];


        List<Policy_Information__c> policies =
            [SELECT Id FROM Policy_Information__c WHERE Opportunity__c = :opp.Id];

        Test.startTest();
        OpportunityNBCController.saveOpportunityNBC(
            opp, acc, policies, 'PROPERTY'
        );
        Test.stopTest();
    }

    @IsTest
    static void testSaveOpportunityNBC_INSURED() {
        Opportunity opp = [SELECT Id, AccountId FROM Opportunity LIMIT 1];

        Account acc = [
            SELECT Id,
                   ShippingStreet, ShippingCity, ShippingState, ShippingPostalCode, ShippingCountry,
                   BillingStreet, BillingCity, BillingState, BillingPostalCode, BillingCountry
            FROM Account
            WHERE Id = :opp.AccountId
        ];

        List<Policy_Information__c> policies =
            [SELECT Id FROM Policy_Information__c WHERE Opportunity__c = :opp.Id];

        Test.startTest();
        OpportunityNBCController.saveOpportunityNBC(
            opp, acc, policies, 'INSURED'
        );
        Test.stopTest();
    }

    @IsTest
    static void testGenerateNBCPdf() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];

        Test.startTest();
        OpportunityNBCController.generateNBCPdf(opp.Id);
        Test.stopTest();
    }

    @IsTest
    static void testPdfExists() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];

        Test.startTest();
        OpportunityNBCController.pdfExists(opp.Id);
        Test.stopTest();
    }

    @IsTest
    static void testPicklists() {
        Test.startTest();
        OpportunityNBCController.getCarrierOptions();
        OpportunityNBCController.getAgent2Options();
        Test.stopTest();
    }
}