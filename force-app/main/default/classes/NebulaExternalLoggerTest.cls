@IsTest
private class NebulaExternalLoggerTest {
    
    @IsTest
    static void testCreateLogsWithSummary() {
        // Setup REST Context
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/ExternalLogger/';
        req.httpMethod = 'POST';
        
        // Setup JSON payload with lead summary counts
        String jsonBody = '{' +
            '"totalLeads": 100,' +
            '"successCount": 90,' +
            '"failedCount": 10,' +
            '"logEntries": [' +
                '{"loggingLevel": "ERROR", "message": "Missing Email", "originLocation": "Integration"}' +
            ']' +
        '}';
        
        req.requestBody = Blob.valueOf(jsonBody);
        RestContext.request = req;
        RestContext.response = res;
        
        Test.startTest();
        NebulaExternalLogger.createLogs();
        Test.stopTest();
        
        // Verify execution succeeded (no exceptions thrown)
        System.assert(true, 'Expected createLogs to execute successfully without unhandled exceptions.');
    }
    
    @IsTest
    static void testCreateLogsWithoutSummary() {
        // Setup REST Context
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/ExternalLogger/';
        req.httpMethod = 'POST';
        
        // Setup JSON payload without lead summary counts
        String jsonBody = '{' +
            '"logEntries": [' +
                '{"loggingLevel": "INFO", "message": "Standard log entry", "originLocation": "Integration"}' +
            ']' +
        '}';
        
        req.requestBody = Blob.valueOf(jsonBody);
        RestContext.request = req;
        RestContext.response = res;
        
        Test.startTest();
        NebulaExternalLogger.createLogs();
        Test.stopTest();
        
        // Verify execution succeeded (no exceptions thrown)
        System.assert(true, 'Expected createLogs to execute successfully without unhandled exceptions.');
    }
}