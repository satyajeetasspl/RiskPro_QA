@IsTest
public class AutoIncidentControllerTest {

    @IsTest
    static void testAutoIncidentControllerMethods() {
        // ---------- Create Test Lead ----------
        Lead testLead = new Lead(
            FirstName = 'Test',
            LastName = 'Lead',
            Company = 'Test Company',
            Status = 'Open - Not Contacted'
        );
        insert testLead;

        // ---------- Create Test Account ----------
        Account testAccount = new Account(
            Name = 'Test Account'
        );
        insert testAccount;

        // ---------- Create Related Drivers ----------
        Driver__c leadDriver = new Driver__c(
            First_Name__c = 'John',
            Last_Name__c = 'Doe',
            Lead__c = testLead.Id
        );
        insert leadDriver;

        Driver__c accountDriver = new Driver__c(
            First_Name__c = 'Jane',
            Last_Name__c = 'Smith',
            Account__c = testAccount.Id
        );
        insert accountDriver;

        // ---------- Get valid picklist value ----------
        String validIncidentDesc = null;
        Schema.DescribeFieldResult descResult = Auto_Incidents_Violations__c.Incident_Description__c.getDescribe();
        List<Schema.PicklistEntry> pickVals = descResult.getPicklistValues();
        if (!pickVals.isEmpty()) {
            validIncidentDesc = pickVals[0].getValue();
        }

        // ---------- Create Lead-based Incident ----------
        Auto_Incidents_Violations__c leadIncident = new Auto_Incidents_Violations__c(
            Lead__c = testLead.Id,
            Operator__c = leadDriver.Id,
            Date__c = Date.today(),
            Additional_Information__c = 'Lead Test Info',
            Incident_Description__c = validIncidentDesc
        );
        insert leadIncident;

        // ---------- Create Account-based Incident ----------
        Auto_Incidents_Violations__c accountIncident = new Auto_Incidents_Violations__c(
            Account__c = testAccount.Id,
            Operator__c = accountDriver.Id,
            Date__c = Date.today(),
            Additional_Information__c = 'Account Test Info',
            Incident_Description__c = validIncidentDesc
        );
        insert accountIncident;

        // ✅ ---------- Main Functional Calls ----------
        Test.startTest();

        // Lead-based retrieval
        AutoIncidentController.getRecordsByParent(testLead.Id);
        AutoIncidentController.getAllDrivers(testLead.Id);
        AutoIncidentController.getRecordById(leadIncident.Id);

        // Account-based retrieval
        AutoIncidentController.getRecordsByParent(testAccount.Id);
        AutoIncidentController.getAllDrivers(testAccount.Id);
        AutoIncidentController.getRecordById(accountIncident.Id);

        // Create record (valid)
        Auto_Incidents_Violations__c newIncident = new Auto_Incidents_Violations__c(
            Lead__c = testLead.Id,
            Operator__c = leadDriver.Id,
            Date__c = Date.today(),
            Additional_Information__c = 'New Info',
            Incident_Description__c = validIncidentDesc
        );
        AutoIncidentController.createRecord(newIncident);

        // Update record (valid)
        newIncident.Additional_Information__c = 'Updated Info';
        AutoIncidentController.updateRecord(newIncident);

        // Delete record (valid)
        AutoIncidentController.deleteRecord(newIncident.Id);

        // ✅ ---------- Covering Exception Blocks ----------
        // Invalid create (simulate exception by passing null)
        AutoIncidentController.createRecord(null);

        // Invalid update (simulate exception by passing null)
        AutoIncidentController.updateRecord(null);

        // Invalid delete (simulate exception by passing invalid Id)
        AutoIncidentController.deleteRecord('001000000000000AAA');

        // Cover null Id scenarios
        try { AutoIncidentController.getRecordById(null); } catch (Exception e) {}
        try { AutoIncidentController.getRecordsByParent(null); } catch (Exception e) {}
        try { AutoIncidentController.getAllDrivers(null); } catch (Exception e) {}

        Test.stopTest();
    }
}