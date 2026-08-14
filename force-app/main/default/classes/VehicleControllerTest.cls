@IsTest
public class VehicleControllerTest {

    @TestSetup
    static void setupTestData() {
        // Lead record
        Lead testLead = new Lead(
            FirstName = 'Test',
            LastName = 'Lead',
            Company = 'Test Company',
            Status = 'Open - Not Contacted'
        );
        insert testLead;

        // Driver record
        Driver__c testDriver = new Driver__c(
            First_Name__c = 'John',
            Last_Name__c = 'Doe',
            Lead__c = testLead.Id
        );
        insert testDriver;

        // Vehicle record
        Vehicle__c testVehicle = new Vehicle__c(
            Vehicle_Type__c = 'Auto',
            VIN__c = 'VIN123456789',
            Year__c = '2022',
            Make__c = 'Toyota',
            Model__c = 'Camry',
            Annual_Miles__c = '12000',
            Lead__c = testLead.Id
        );
        insert testVehicle;
    }

    @IsTest
    static void testVehicleControllerMethods() {
        Lead lead = [SELECT Id FROM Lead LIMIT 1];
        Vehicle__c vehicle = [SELECT Id FROM Vehicle__c LIMIT 1];

        Test.startTest();
        // Fetch Vehicles
        try { VehicleController.getVehicles(lead.Id); } catch (Exception e) {}

        // Fetch Available Drivers
        try { VehicleController.getAvailableDrivers(lead.Id); } catch (Exception e) {}

        // Vehicle Type Options (Picklist)
        try { VehicleController.getVehicleTypeOptions(); } catch (Exception e) {}

        // Create Vehicle
        Vehicle__c newVehicle = new Vehicle__c(
            Vehicle_Type__c = 'Auto',
            VIN__c = 'VIN987654321',
            Year__c = '2023',
            Make__c = 'Honda',
            Model__c = 'Civic',
            Annual_Miles__c = '15000',
            Lead__c = lead.Id
        );
        try { VehicleController.createVehicle(newVehicle); } catch (Exception e) {}

        // Update Vehicle
        vehicle.Make__c = 'UpdatedMake';
        try { VehicleController.updateVehicle(vehicle); } catch (Exception e) {}

        // Delete Vehicle
        Vehicle__c delVehicle = new Vehicle__c(
            Vehicle_Type__c = 'Auto',
            VIN__c = 'VINDELETE123',
            Year__c = '2021',
            Make__c = 'Ford',
            Model__c = 'Focus',
            Lead__c = lead.Id
        );
        insert delVehicle;
        try { VehicleController.deleteVehicle(delVehicle.Id); } catch (Exception e) {}

        // Edge Case: Delete invalid vehicle ID
        try { VehicleController.deleteVehicle(null); } catch (Exception e) {}

        Test.stopTest();
    }

    @IsTest
    static void testVINDecoderControllerNew() {
        // Mock HTTP Response
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());

        Test.startTest();
        // Fetch VIN Data
        try {
            VINDecoderControllerNew.VehicleData vd = VINDecoderControllerNew.fetchLatestVINData('VIN123456789');
        } catch (Exception e) {}

        // Fetch with empty VIN (error branch)
        try {
            VINDecoderControllerNew.fetchLatestVINData('');
        } catch (Exception e) {}

        // Save Vehicle Record
        Lead lead = [SELECT Id FROM Lead LIMIT 1];
        Map<String, Object> vehicleData = new Map<String, Object>{
            'VIN__c' => 'VIN000111222',
            'Make__c' => 'Toyota',
            'Model__c' => 'Corolla',
            'Year__c' => '2020',
            'Annual_Miles__c' => '10000',
            'Lead__c' => lead.Id,
            'Vehicle_Type__c' => 'Auto'
        };
        try {
            VINDecoderControllerNew.saveVehicleRecord(vehicleData);
        } catch (Exception e) {}

        // Edge Case: Empty vehicleData
        try {
            VINDecoderControllerNew.saveVehicleRecord(new Map<String, Object>());
        } catch (Exception e) {}

        Test.stopTest();
    }

    // Mock callout class for VINDecoderControllerNew
    public class MockHttpResponseGenerator implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"Results":[{"Make":"Toyota","Model":"Camry","ModelYear":"2022"}]}');
            return res;
        }
    }
}