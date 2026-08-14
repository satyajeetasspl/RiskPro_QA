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
            AccountId = acc.Id,
            OwnerId = UserInfo.getUserId(),
            Date_Bound__c = Date.today() // Added to ensure field mapping works
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

        List<Policy_Information__c> policies = [SELECT Id, Generate_Invoice__c, Agency_Fee__c FROM Policy_Information__c WHERE Opportunity__c = :opp.Id];

        Test.startTest();
        OpportunityNBCController.saveOpportunityNBC(opp, acc, policies, 'PROPERTY', new Map<String, String>());
        Test.stopTest();
    }

    @IsTest
    static void testSaveOpportunityNBC_INSURED() {
        Opportunity opp = [SELECT Id, AccountId FROM Opportunity LIMIT 1];
        Account acc = [
            SELECT Id, ShippingStreet, ShippingCity, ShippingState, ShippingPostalCode, ShippingCountry,
                   BillingStreet, BillingCity, BillingState, BillingPostalCode, BillingCountry
            FROM Account WHERE Id = :opp.AccountId
        ];
        List<Policy_Information__c> policies = [SELECT Id, Generate_Invoice__c, Agency_Fee__c FROM Policy_Information__c WHERE Opportunity__c = :opp.Id];

        Test.startTest();
        OpportunityNBCController.saveOpportunityNBC(opp, acc, policies, 'INSURED', new Map<String, String>());
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

    // -------------------------------------------------------------------------
    // NEW METHODS ADDED BELOW TO INCREASE COVERAGE
    // -------------------------------------------------------------------------

    /**
     * Covers: if (p.Id == null) logic inside saveOpportunityNBC
     */
    @IsTest
    static void testSaveNewPolicy() {
        Opportunity opp = [SELECT Id, AccountId, OwnerId, Agent_2__c, Date_Bound__c FROM Opportunity LIMIT 1];
        Account acc = [
            SELECT Id, Name, Phone, Email__c,
                   ShippingStreet, ShippingCity, ShippingState, ShippingPostalCode, ShippingCountry,
                   BillingStreet, BillingCity, BillingState, BillingPostalCode, BillingCountry,
                   NBC_Address__Street__s, NBC_Address__City__s, NBC_Address__StateCode__s, NBC_Address__PostalCode__s, NBC_Address__CountryCode__s,
                   Address_Property__Street__s, Address_Property__City__s, Address_Property__StateCode__s, 
                   Address_Property__PostalCode__s, Address_Property__CountryCode__s
            FROM Account WHERE Id = :opp.AccountId
        ];

        // Create a policy instance in memory but DO NOT insert it. 
        // This ensures Id is null and triggers the specific logic block.
        Policy_Information__c newPol = new Policy_Information__c(
            Opportunity__c = opp.Id,
            Policy__c = 'NewUnsavedPol',
            Premium__c = '500'
        );

        Test.startTest();
        // Pass a list containing the new, unsaved policy
        OpportunityNBCController.saveOpportunityNBC(opp, acc, new List<Policy_Information__c>{newPol}, 'PROPERTY', new Map<String, String>());
        Test.stopTest();
    }

    /**
     * Covers: getAMS360Policies method and loop
     */
    @IsTest
    static void testAMS360Integration() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        
        // Create a Parent Company (Account) for the carrier lookup
        Account carrierAcc = new Account(Name = 'AMS Carrier');
        insert carrierAcc;
        
        vert__AMS360_Employee__c emp = new vert__AMS360_Employee__c(
            Name = 'Whitmore',
            vert__AMS360_Employee_Code__c = 'W123',
            vert__AMS360_Entity_ID__c = 'E123'
        );
        insert emp;

        // Create AMS360 Policy to ensure the query returns rows and enters the loop
        vert__AMS360_Policy__c amsPol = new vert__AMS360_Policy__c(
            Name = 'AMS-TEST-001',
            vert__AMS360_Account_Name__c = acc.Id,
            vert__AMS360_Full_Term_Premium__c = 1250.00,
            vert__AMS360_Effective_Date__c = Date.today(),
            vert__AMS360_Employee_Policy_Exec__c = emp.Id,
            vert__AMS360_Employee_Policy_Rep__c = emp.Id,
            Paid_To_Date__c = 500
        );
        insert amsPol;

        Test.startTest();
        // Call the method
        OpportunityNBCController.getAMS360Policies(acc.Id);
        // Also call with null to cover the null check at the start of the method
        OpportunityNBCController.getAMS360Policies(null);
        Test.stopTest();
    }

    @IsTest
    static void testStateAndCountryIsoCodes() {
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
        
        // Update account with valid picklist values to avoid DML restricted picklist errors
        acc.Address_Property__StateCode__s = 'TX';
        acc.Address_Property__CountryCode__s = 'US';
        acc.BillingState = 'NY';
        acc.BillingCountry = 'US';
        update acc;
        
        List<Policy_Information__c> policies = new List<Policy_Information__c>();
        
        Test.startTest();
        OpportunityNBCController.saveOpportunityNBC(opp, acc, policies, 'PROPERTY', new Map<String, String>());
        OpportunityNBCController.saveOpportunityNBC(opp, acc, policies, 'INSURED', new Map<String, String>());
        Test.stopTest();
    }
    
    @IsTest
    static void testGetPolicyCheckValidationAllPaths() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        
        // 1. submittedCount > 0
        Policy_Information__c quote1 = new Policy_Information__c(
            Opportunity__c = opp.Id,
            Policy_Type__c = 'Quote',
            Policy_Status__c = 'Submitted'
        );
        insert quote1;
        
        Test.startTest();
        OpportunityNBCController.getPolicyCheckValidation(opp.Id);
        
        // 2. approvedCount == 0 & submittedCount == 0
        delete quote1;
        OpportunityNBCController.getPolicyCheckValidation(opp.Id);
        Test.stopTest();
    }
    
    @IsTest
    static void testGetOpportunityNBC_NoAccount() {
        Opportunity opp = new Opportunity(
            Name = 'Test Opp No Account',
            StageName = 'Prospecting',
            CloseDate = Date.today()
        );
        insert opp;
        
        Test.startTest();
        OpportunityNBCController.getOpportunityNBC(opp.Id);
        Test.stopTest();
    }
    
    @IsTest
    static void testSaveOpportunityNBC_ExistingNBC() {
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
        
        // Test providing an existing policy that is already 'NBC'
        Policy_Information__c existingNBCPol = new Policy_Information__c(
            Opportunity__c = opp.Id,
            Policy__c = 'ExistingNBC',
            Policy_Type__c = 'NBC',
            Date_Bound__c = Date.today().addDays(-2)
        );
        insert existingNBCPol;
        
        List<Policy_Information__c> policies = [SELECT Id, Generate_Invoice__c, Agency_Fee__c FROM Policy_Information__c WHERE Id = :existingNBCPol.Id];
        
        Test.startTest();
        OpportunityNBCController.saveOpportunityNBC(opp, acc, policies, 'PROPERTY', new Map<String, String>());
        Test.stopTest();
    }

    /**
     * Covers: The Catch block in generateNBCPdf
     */
    @IsTest
    static void testPdfGenerationException() {
        // Passing null ID usually triggers a QueryException or logic error in the controller
        // which forces the code into the catch (Exception e) block.
        Test.startTest();
        try {
            OpportunityNBCController.generateNBCPdf(null);
        } catch (Exception e) {
            // Expected behavior if the controller re-throws
        }
        Test.stopTest();
    }
}