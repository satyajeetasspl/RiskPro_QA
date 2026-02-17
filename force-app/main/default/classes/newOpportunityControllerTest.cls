@isTest
private class newOpportunityControllerTest {
    
    @testSetup
    static void setupData() {
        // Create a test Account to query
        Account acc = new Account(
            Name = 'Test Intelligence Account',
            Referral_Type__c = 'Company',
            Lead_Source__c = 'Web'
            // Add other fields here if they are mandatory in your org
        );
        insert acc;
    }

    @isTest
    static void testGetAccountDetails() {
        // Retrieve the account created in setup
        Account acc = [SELECT Id FROM Account LIMIT 1];
        
        // Start Test context
        Test.startTest();
        
        // Execute the controller method
        newOpportunityController.getAccountDetails(acc.Id);
        
        Test.stopTest();
    }
}