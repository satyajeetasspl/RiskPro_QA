@isTest
private class BulkLeadAPITest {
    
    @isTest
    static void testValidLeadsInsert() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        req.requestURI = '/services/apexrest/BulkLeads/';
        req.httpMethod = 'POST';
        
        String jsonPayload = '[' +
            '{"FirstName":"John", "LastName":"Doe", "Company":"Acme", "Email":"john.doe@acme.com", "Phone":"555-0001"},' +
            '{"FirstName":"Jane", "LastName":"Smith", "Company":"TechCorp", "Email":"jane.smith@techcorp.com", "Phone":"555-0002"}' +
        ']';
        req.requestBody = Blob.valueOf(jsonPayload);
        
        RestContext.request = req;
        RestContext.response = res;
        
        Test.startTest();
        BulkLeadAPI.processLeads();
        Test.stopTest();
        
        System.assertEquals(200, res.statusCode, 'Status code should be 200');
        
        BulkLeadAPIWrapper.Response apiResponse = (BulkLeadAPIWrapper.Response) JSON.deserialize(res.responseBody.toString(), BulkLeadAPIWrapper.Response.class);
        System.assertEquals(2, apiResponse.totalReceived);
        System.assertEquals(2, apiResponse.successCount);
        System.assertEquals(0, apiResponse.failedCount);
        
        List<Lead> insertedLeads = [SELECT Id FROM Lead];
        System.assertEquals(2, insertedLeads.size());
    }
    
    @isTest
    static void testPartialSuccess() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        req.requestURI = '/services/apexrest/BulkLeads/';
        req.httpMethod = 'POST';
        
        // 1 valid, 1 invalid (missing required standard fields for Lead like LastName or Company)
        String jsonPayload = '[' +
            '{"FirstName":"Valid", "LastName":"Lead", "Company":"Acme", "Email":"valid@acme.com", "Phone":"555-0001"},' +
            '{"FirstName":"Invalid", "Email":"invalid@acme.com"}' + 
        ']';
        req.requestBody = Blob.valueOf(jsonPayload);
        
        RestContext.request = req;
        RestContext.response = res;
        
        Test.startTest();
        BulkLeadAPI.processLeads();
        Test.stopTest();
        
        System.assertEquals(200, res.statusCode, 'Status code should be 200 even for partial successes');
        
        BulkLeadAPIWrapper.Response apiResponse = (BulkLeadAPIWrapper.Response) JSON.deserialize(res.responseBody.toString(), BulkLeadAPIWrapper.Response.class);
        System.assertEquals(2, apiResponse.totalReceived);
        System.assertEquals(1, apiResponse.successCount);
        System.assertEquals(1, apiResponse.failedCount);
    }
    
    @isTest
    static void testEmptyPayload() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        req.requestURI = '/services/apexrest/BulkLeads/';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf('');
        
        RestContext.request = req;
        RestContext.response = res;
        
        Test.startTest();
        BulkLeadAPI.processLeads();
        Test.stopTest();
        
        System.assertEquals(400, res.statusCode);
    }
    
    @isTest
    static void testExceptionHandling() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        req.requestURI = '/services/apexrest/BulkLeads/';
        req.httpMethod = 'POST';
        
        // Invalid JSON to force JSONException
        req.requestBody = Blob.valueOf('[{Invalid JSON');
        
        RestContext.request = req;
        RestContext.response = res;
        
        Test.startTest();
        BulkLeadAPI.processLeads();
        Test.stopTest();
        
        System.assertEquals(500, res.statusCode);
    }
}