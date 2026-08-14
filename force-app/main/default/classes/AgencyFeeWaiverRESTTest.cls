@IsTest
private class AgencyFeeWaiverRESTTest {

    @TestSetup
    static void setupTestData() {
        // Create a dummy Lead (Required for Policy_Information__c)
        Lead testLead = new Lead(
            FirstName = 'Test',
            LastName = 'Lead',
            Company = 'Test Company'
        );
        insert testLead;

        // Create a Policy Information record with a pending waiver and a token
        Policy_Information__c testQuote = new Policy_Information__c(
            Lead__c = testLead.Id,
            Policy_Type__c = 'Quote',
            Is_Quote__c = true,
            Agency_Fee_Waiver_Request__c = true,
            Agency_Fee_Waiver_Decision__c = 'Pending',
            Waiver_Token__c = 'SECURE_TEST_TOKEN_123'
        );
        insert testQuote;
    }

    @IsTest
    static void testSuccessfulAcceptance() {
        Policy_Information__c quote = [SELECT Id, Waiver_Token__c FROM Policy_Information__c LIMIT 1];

        // Set up the REST Context
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        req.requestURI = '/services/apexrest/WaiverAction';
        req.httpMethod = 'GET';
        req.addParameter('id', quote.Id);
        req.addParameter('decision', 'Accepted');
        req.addParameter('token', quote.Waiver_Token__c);
        
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        AgencyFeeWaiverREST.handleWaiver();
        Test.stopTest();
    }

    @IsTest
    static void testSuccessfulRejection() {
        Policy_Information__c quote = [SELECT Id, Waiver_Token__c FROM Policy_Information__c LIMIT 1];

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        req.requestURI = '/services/apexrest/WaiverAction';
        req.httpMethod = 'GET';
        req.addParameter('id', quote.Id);
        req.addParameter('decision', 'Rejected');
        req.addParameter('token', quote.Waiver_Token__c);
        
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        AgencyFeeWaiverREST.handleWaiver();
        Test.stopTest();
    }

    @IsTest
    static void testMissingParameters() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        req.requestURI = '/services/apexrest/WaiverAction';
        req.httpMethod = 'GET';
        // Omitting parameters intentionally to hit the error block
        
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        AgencyFeeWaiverREST.handleWaiver();
        Test.stopTest();
    }

    @IsTest
    static void testInvalidToken() {
        Policy_Information__c quote = [SELECT Id FROM Policy_Information__c LIMIT 1];

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        req.requestURI = '/services/apexrest/WaiverAction';
        req.httpMethod = 'GET';
        req.addParameter('id', quote.Id);
        req.addParameter('decision', 'Accepted');
        req.addParameter('token', 'WRONG_TOKEN_999'); // Invalid token
        
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        AgencyFeeWaiverREST.handleWaiver();
        Test.stopTest();
    }

    @IsTest
    static void testAlreadyProcessed() {
        // Update the record first to hit the "already processed" logic block
        Policy_Information__c quote = [SELECT Id, Waiver_Token__c FROM Policy_Information__c LIMIT 1];
        quote.Agency_Fee_Waiver_Decision__c = 'Accepted';
        update quote;
        
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.requestURI = '/services/apexrest/WaiverAction';
        req.httpMethod = 'GET';
        req.addParameter('id', quote.Id);
        req.addParameter('decision', 'Accepted');
        req.addParameter('token', quote.Waiver_Token__c);

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        AgencyFeeWaiverREST.handleWaiver();
        Test.stopTest();
    }
}