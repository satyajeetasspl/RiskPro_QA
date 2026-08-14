@isTest
private class QuoteAgencyHelperTest {

    @isTest
    static void testProcessWaiverRequests_NullInputs() {
        // Test early return for null leadId
        QuoteAgencyHelper.processWaiverRequests(null, new List<Policy_Information__c>());

        // Generate a native fake Lead ID using its key prefix (e.g., '00Q' + 12 zeros)
        String leadPrefix = Lead.SObjectType.getDescribe().getKeyPrefix();
        Id mockLeadId = (Id)(leadPrefix + '000000000000'); 

        // Test early return for null/empty quote list
        QuoteAgencyHelper.processWaiverRequests(mockLeadId, null);
        QuoteAgencyHelper.processWaiverRequests(mockLeadId, new List<Policy_Information__c>());
    }

    @isTest
    static void testProcessWaiverRequests_FullProcessing() {
        // 1. Create a Test Lead to satisfy the SOQL query
        Lead testLead = new Lead(
            FirstName = 'John',
            LastName = 'Doe',
            Company = 'Test Agency LLC'
        );
        insert testLead;

        // 2. Create Test Policy_Information__c records to satisfy different conditional branches
        List<Policy_Information__c> testQuotes = new List<Policy_Information__c>();
        
        // Quote 1: Needs a token generated and needs approval (Pending)
        testQuotes.add(new Policy_Information__c(
            Agency_Fee_Waiver_Request__c = true,
            Agency_Fee_Waiver_Decision__c = 'Pending',
            Carrier__c = 'Standard Carrier',
            Lines__c = 'Auto',
            Waiver_Reason__c = 'Loyal Customer'
        ));

        // Quote 2: Already has a token, needs approval (Null Decision)
        testQuotes.add(new Policy_Information__c(
            Agency_Fee_Waiver_Request__c = true,
            Agency_Fee_Waiver_Decision__c = null,
            Waiver_Token__c = 'PRE_EXISTING_TOKEN_ABC123',
            Carrier__c = 'Premium Carrier',
            Lines__c = 'Home'
        ));

        // Quote 3: Waiver not requested (Bypasses token and approval logic)
        testQuotes.add(new Policy_Information__c(
            Agency_Fee_Waiver_Request__c = false
        ));

        insert testQuotes;

        // 3. Execute the Helper method inside Test.startTest() to reset governor limits for emails
        Test.startTest();
        
        // This will attempt to update tokens, process approvals, and send the email.
        // If no active approval process exists in the test context, the try-catch block 
        // in the helper handles the exception smoothly, ensuring code coverage.
        QuoteAgencyHelper.processWaiverRequests(testLead.Id, testQuotes);
        
        Test.stopTest();
    }
}