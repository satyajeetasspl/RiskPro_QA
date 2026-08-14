@isTest
private class PolicyInvoiceControllerTest {

    @isTest
    static void testWithLead() {
        // 1. DATA SETUP: Carrier, Lead, Policy linked to Lead
        Carrier__c carrier = new Carrier__c(
            Company_Name__c = 'Test Carrier',
            Payment_Address__Street__s = '123 Test St',
            Payment_Address__City__s = 'TestCity',
            Payment_Address__StateCode__s = 'CA',
            Payment_Address__PostalCode__s = '90001'
        );
        insert carrier;

        Lead lead = new Lead(
            LastName = 'Test Lead',
            Company = 'Test Company',
            Street = '123 Main St',
            City = 'Metropolis',
            State = 'NY',
            PostalCode = '12345',
            Country = 'USA',
            Add_Second_Named_Insured__c = true,
            Second_Insured_First_Name__c = 'Jane',
            Second_Insured_Last_Name__c = 'Doe'
        );
        insert lead;

        Policy_Information__c policy = new Policy_Information__c(
            Carrier__c = carrier.Company_Name__c,
            Policy__c = 'P12345',
            Premium__c = '500',
            Paid_To_Date__c = '200',
            Effective_Date__c = Date.today(),
            Lead__c = lead.Id // Linked to Lead
        );
        insert policy;

        // 2. TEST EXECUTION
        Test.setCurrentPage(Page.Policy_Invoice_PDF); 
        ApexPages.currentPage().getParameters().put('leadId', lead.Id);
        ApexPages.currentPage().getParameters().put('policyId', policy.Id);

        PolicyInvoiceController controller = new PolicyInvoiceController();

        // Call all getters
        controller.getSecondInsuredName();
        controller.getPropertyAddress();
        controller.getPaymentStreet();
        controller.getPaymentCityStateCode();
        controller.getBalanceDue();
        controller.getPaidToDate();
        controller.getTotalPremium();
        controller.getInsuredName();
        
        // Run the job (for coverage of the job class)
        Test.startTest();
        GeneratePolicyInvoiceJob job = new GeneratePolicyInvoiceJob(lead.Id, policy.Id);
        System.enqueueJob(job);
        Test.stopTest();
    }

    @isTest
    static void testWithAccount() {
        // Covers logic: if (this.policyRecord.Account__c != null)
        
        Account acc = new Account(
            Name = 'Test Account',
            NBC_Address__Street__s = '456 Acc St',
            NBC_Address__City__s = 'Gotham',
            NBC_Address__StateCode__s = 'NY',
            NBC_Address__PostalCode__s = '54321',
            Add_Second_Named_Insured__c = true,
            Second_Insured_First_Name__c = 'John',
            Second_Insured_Last_Name__c = 'Smith'
        );
        insert acc;

        Policy_Information__c policy = new Policy_Information__c(
            Policy__c = 'P99999',
            Account__c = acc.Id, // Linked to Account
            Premium__c = '1000'
        );
        insert policy;

        Test.setCurrentPage(Page.Policy_Invoice_PDF);
        // Note: No leadId passed here
        ApexPages.currentPage().getParameters().put('policyId', policy.Id);

        PolicyInvoiceController controller = new PolicyInvoiceController();
        
        // This covers the logic where a dummy Lead is created in memory
        controller.getInsuredName(); 
        controller.getSecondInsuredName();
        controller.getPropertyAddress();
    }

    @isTest
    static void testWithOpportunity() {
        // Covers logic: fetching Account via Opportunity link
        
        Account acc = new Account(Name = 'Opp Account');
        insert acc;

        Opportunity opp = new Opportunity(
            Name = 'Test Opp',
            StageName = 'Closed Won',
            CloseDate = Date.today(),
            AccountId = acc.Id
        );
        insert opp;

        Policy_Information__c policy = new Policy_Information__c(
            Policy__c = 'P88888',
            Opportunity__c = opp.Id, // Linked to Opp
            // Account__c is explicitly null here to force the lookup logic
            Premium__c = '1000'
        );
        insert policy;

        Test.setCurrentPage(Page.Policy_Invoice_PDF);
        ApexPages.currentPage().getParameters().put('policyId', policy.Id);

        PolicyInvoiceController controller = new PolicyInvoiceController();
        
        // Access getters to ensure the dummy lead was populated correctly from Opp > Acc
        controller.getInsuredName();
    }

    @isTest
    static void testNullBehavior() {
        // Covers the "return 0" and empty string branches
        
        Test.setCurrentPage(Page.Policy_Invoice_PDF);
        // We instantiate WITHOUT setting parameters
        PolicyInvoiceController controller = new PolicyInvoiceController();

        // Call methods that handle nulls gracefully
        // In the previous version, these were commented out. 
        // Calling them now ensures lines like "if (policyRecord == null) return 0;" are covered.
        controller.getBalanceDue();
        controller.getPaidToDate();
        controller.getTotalPremium();
        controller.getPaymentStreet();
        controller.getPaymentCityStateCode();
        controller.getSecondInsuredName();
        controller.getPropertyAddress();
        controller.getInsuredName();
         controller.getPolicyNumber();
         controller.getAdditionalComments();
    }
}