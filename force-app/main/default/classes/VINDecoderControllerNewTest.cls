@IsTest
public class VINDecoderControllerNewTest {

    // -----------------------------
    // CALLOUT MOCKS
    // -----------------------------
    private class MockHttpSuccess implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);
            res.setBody('{"Results":[{"Make":"Toyota","Model":"Camry","ModelYear":"2021"}]}');
            return res;
        }
    }

    private class MockHttp500 implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody('{"Results":[]}');
            return res;
        }
    }

    private class MockHttpEmptyResults implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"Results":[]}');
            return res;
        }
    }

    private class MockHttpThrows implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            throw new CalloutException('Simulated callout failure');
        }
    }

    // -----------------------------
    // fetchLatestVINData tests
    // -----------------------------
    @IsTest
    static void testFetchLatestVINData_Success() {
        Test.setMock(HttpCalloutMock.class, new MockHttpSuccess());

        Test.startTest();
        VINDecoderControllerNew.fetchLatestVINData('1HGCM82633A004352');
        Test.stopTest();
    }

    @IsTest
    static void testFetchLatestVINData_BlankVIN() {
        try {
            Test.startTest();
            VINDecoderControllerNew.fetchLatestVINData('');
            Test.stopTest();
        } catch (AuraHandledException e) {
            Test.stopTest();
        }
    }

    @IsTest
    static void testFetchLatestVINData_HttpError() {
        Test.setMock(HttpCalloutMock.class, new MockHttp500());
        try {
            Test.startTest();
            VINDecoderControllerNew.fetchLatestVINData('TESTVIN');
            Test.stopTest();
        } catch (AuraHandledException e) {
            Test.stopTest();
        }
    }

    @IsTest
    static void testFetchLatestVINData_EmptyResults() {
        Test.setMock(HttpCalloutMock.class, new MockHttpEmptyResults());
        try {
            Test.startTest();
            VINDecoderControllerNew.fetchLatestVINData('TESTVIN2');
            Test.stopTest();
        } catch (AuraHandledException e) {
            Test.stopTest();
        }
    }

    @IsTest
    static void testFetchLatestVINData_CalloutThrows() {
        Test.setMock(HttpCalloutMock.class, new MockHttpThrows());
        try {
            Test.startTest();
            VINDecoderControllerNew.fetchLatestVINData('TESTVIN3');
            Test.stopTest();
        } catch (AuraHandledException e) {
            Test.stopTest();
        }
    }

    // -----------------------------
    // saveVehicleRecord tests
    // -----------------------------
    @IsTest
    static void testSaveVehicleRecord_NullOrEmpty() {
        try {
            VINDecoderControllerNew.saveVehicleRecord(null);
        } catch (AuraHandledException e) {}

        try {
            VINDecoderControllerNew.saveVehicleRecord(new Map<String, Object>());
        } catch (AuraHandledException e) {}
    }

    @IsTest
    static void testSaveVehicleRecord_InsertThenUpdate_Success() {

        Map<String, Object> insertData = new Map<String, Object>{
            'VIN__c' => '1HGCM82633A004352',
            'Make__c' => 'Toyota',
            'Model__c' => 'Camry',
            'Year__c' => '2021',
            'Annual_Miles__c' => '12000',
            'Lienholder__c' => 'HDFC Bank',
            'Lead__c' => null,
            'Registered_To__c' => null,
            'Vehicle_Type__c' => 'Auto'
        };

        Test.startTest();

        // INSERT
        Id newId = VINDecoderControllerNew.saveVehicleRecord(insertData);

        // UPDATE
        Map<String, Object> updateData = new Map<String, Object>{
            'Id' => newId,
            'VIN__c' => '1HGCM82633A004352',
            'Make__c' => 'Toyota',
            'Model__c' => 'Camry SE',
            'Year__c' => '2021',
            'Annual_Miles__c' => '15000',
            'Lienholder__c' => 'HDFC Bank',
            'Lead__c' => null,
            'Registered_To__c' => null,
            'Vehicle_Type__c' => 'Auto'
        };
        VINDecoderControllerNew.saveVehicleRecord(updateData);

        Test.stopTest();
    }

    @IsTest
    static void testSaveVehicleRecord_DmlFailure() {
        // Create a baseline record first (outside startTest)
        Vehicle__c v = new Vehicle__c();
        v.VIN__c = 'DMLFAILVIN';
        v.Vehicle_Type__c = 'Auto';
        insert v;

        Map<String, Object> badUpdate = new Map<String, Object>{
            'Id' => v.Id,
            'VIN__c' => null,
            'Make__c' => 'X',
            'Model__c' => 'Y',
            'Year__c' => '2020',
            'Annual_Miles__c' => '1',
            'Lienholder__c' => 'Z',
            'Lead__c' => null,
            'Registered_To__c' => null,
            'Vehicle_Type__c' => 'Auto'
        };

        try {
            Test.startTest();
            VINDecoderControllerNew.saveVehicleRecord(badUpdate);
            Test.stopTest();
        } catch (AuraHandledException e) {
            Test.stopTest();
        }
    }
}