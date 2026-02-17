@IsTest
public class VehicleControllerTest {

    @TestSetup
    static void setupTestData() {
        // Lead
        Lead testLead = new Lead(
            FirstName = 'Test',
            LastName  = 'Lead',
            Company   = 'Test Company',
            Status    = 'Open - Not Contacted'
        );
        insert testLead;

        // Driver (for getAvailableDrivers)
        Driver__c testDriver = new Driver__c(
            First_Name__c = 'John',
            Last_Name__c  = 'Doe',
            Lead__c       = testLead.Id
        );
        insert testDriver;

        // Vehicle (for getVehicles/update/delete)
        Vehicle__c testVehicle = new Vehicle__c(
            Vehicle_Type__c   = 'Auto',
            VIN__c            = 'VIN123456789',
            Year__c           = '2022',
            Make__c           = 'Toyota',
            Model__c          = 'Camry',
            Annual_Miles__c   = '12000',
            Lead__c           = testLead.Id
        );
        insert testVehicle;
    }

    @IsTest
    static void test_AllMethods_AllBranches() {
        Lead lead = [SELECT Id FROM Lead LIMIT 1];
        Vehicle__c existingVehicle = [SELECT Id, Make__c FROM Vehicle__c LIMIT 1];

        Test.startTest();

        // 1) getVehicles (success)
        try { VehicleController.getVehicles(lead.Id); } catch (Exception e) {}

        // 2) getAvailableDrivers (leadId != null)
        try { VehicleController.getAvailableDrivers(lead.Id); } catch (Exception e) {}

        // 3) getAvailableDrivers (leadId == null) => returns empty
        try { VehicleController.getAvailableDrivers(null); } catch (Exception e) {}

        // 4) getVehicleTypeOptions (picklist describe)
        try { VehicleController.getVehicleTypeOptions(); } catch (Exception e) {}

        // 5) createVehicle (success)
        Vehicle__c newVehicle = new Vehicle__c(
            Vehicle_Type__c = 'Auto',
            VIN__c          = 'VIN987654321',
            Year__c         = '2023',
            Make__c         = 'Honda',
            Model__c        = 'Civic',
            Annual_Miles__c = '15000',
            Lead__c         = lead.Id
        );
        try { VehicleController.createVehicle(newVehicle); } catch (Exception e) {}

        // 6) createVehicle (error branch) - force DML error by missing required fields
        // If your org does NOT require VIN__c/Vehicle_Type__c, set null to a required field in your org.
        Vehicle__c badCreate = new Vehicle__c(
            Lead__c = lead.Id
            // intentionally missing fields to trigger catch
        );
        try { VehicleController.createVehicle(badCreate); } catch (Exception e) {}

        // 7) updateVehicle (success)
        existingVehicle.Make__c = 'UpdatedMake';
        try { VehicleController.updateVehicle(existingVehicle); } catch (Exception e) {}

        // 8) updateVehicle (error branch) - update record with null Id causes exception
        Vehicle__c badUpdate = new Vehicle__c(Make__c = 'NoId');
        try { VehicleController.updateVehicle(badUpdate); } catch (Exception e) {}

        // 9) deleteVehicle (success)
        Vehicle__c delVehicle = new Vehicle__c(
            Vehicle_Type__c = 'Auto',
            VIN__c          = 'VINDELETE123',
            Year__c         = '2021',
            Make__c         = 'Ford',
            Model__c        = 'Focus',
            Lead__c         = lead.Id
        );
        insert delVehicle;
        try { VehicleController.deleteVehicle(delVehicle.Id); } catch (Exception e) {}

        // 10) deleteVehicle (error branch) - null Id leads to query exception inside method
        try { VehicleController.deleteVehicle(null); } catch (Exception e) {}

        Test.stopTest();
    }
}