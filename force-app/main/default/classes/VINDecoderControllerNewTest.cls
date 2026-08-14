@IsTest
public class VINDecoderControllerNewTest {

    // Mock for successful VIN API call
    private class MockHttpResponse implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);
            res.setBody('{"Results": [ { "Make": "Toyota", "Model": "Camry", "ModelYear": "2021" } ]}');
            return res;
        }
    }

    // Mock for HTTP 500 error
    private class MockHttpErrorResponse implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody('{"Results": []}');
            return res;
        }
    }

    // Mock for empty VIN data
    private class MockHttpEmptyResponse implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"Results": []}');
            return res;
        }
    }

    @IsTest
    static void testFetchLatestVINData_Success() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponse());
        Test.startTest();
        VINDecoderControllerNew.VehicleData data = VINDecoderControllerNew.fetchLatestVINData('1HGCM82633A004352');
        Test.stopTest();
    }

    @IsTest
    static void testFetchLatestVINData_BlankVIN() {
        try {
            VINDecoderControllerNew.fetchLatestVINData('');
        } catch (AuraHandledException e) { }
    }

    @IsTest
    static void testFetchLatestVINData_HttpError() {
        Test.setMock(HttpCalloutMock.class, new MockHttpErrorResponse());
        try {
            VINDecoderControllerNew.fetchLatestVINData('TESTVIN');
        } catch (AuraHandledException e) { }
    }

    @IsTest
    static void testFetchLatestVINData_EmptyResults() {
        Test.setMock(HttpCalloutMock.class, new MockHttpEmptyResponse());
        try {
            VINDecoderControllerNew.fetchLatestVINData('TESTVIN2');
        } catch (AuraHandledException e) { }
    }

    @IsTest
    static void testSaveVehicleRecord_Success() {
        Map<String, Object> vehicleData = new Map<String, Object>{
            'VIN__c' => '1HGCM82633A004352',
            'Make__c' => 'Toyota',
            'Model__c' => 'Camry',
            'Year__c' => '2021',
            'Annual_Miles__c' => '12000',
            'Lienholder__c' => 'HDFC Bank',
            'Lead__c' => null,
            'Registered_To__c' => null,
            'Vehicle_Type__c' => 'Auto' // ✅ Updated picklist value
        };

        Test.startTest();
        VINDecoderControllerNew.saveVehicleRecord(vehicleData);
        Test.stopTest();
    }
}