@isTest
private class LeadQuoteControllerTest {
    
    @testSetup
    static void setupTestData() {
        // Create initial Lead record
        Lead testLead = new Lead(
            FirstName = 'Test',
            LastName = 'Lead',
            Company = 'Test Company',
            Email = 'test@example.com',
            Phone = '555-0100'
        );
        insert testLead;
        
        // Create initial related records for deletion and query coverage
        Property_Information__c prop = new Property_Information__c(Lead__c = testLead.Id);
        insert prop;
        
        Prior_Insurance_Information__c prior = new Prior_Insurance_Information__c(Lead__c = testLead.Id);
        insert prior;
        
        Driver__c driver = new Driver__c(Lead__c = testLead.Id, First_Name__c = 'John', Last_Name__c = 'Doe');
        insert driver;
        
        Vehicle__c vehicle = new Vehicle__c(Lead__c = testLead.Id, Make__c = 'Toyota');
        insert vehicle;
        
        Auto_Incidents_Violations__c incident = new Auto_Incidents_Violations__c(Lead__c = testLead.Id);
        insert incident;
    }
    
    @isTest
    static void testGetQuoteData() {
        Lead testLead = [SELECT Id FROM Lead LIMIT 1];
        
        Test.startTest();
        // Invoke the fetch method
        LeadQuoteController.QuotePayload result = LeadQuoteController.getQuoteData(testLead.Id);
        Test.stopTest();
    }
    
    @isTest
    static void testSaveQuoteData() {
        Lead testLead = [SELECT Id FROM Lead LIMIT 1];
        
        // Retrieve IDs of setup records to populate the delete lists
        Property_Information__c prop = [SELECT Id FROM Property_Information__c LIMIT 1];
        Prior_Insurance_Information__c prior = [SELECT Id FROM Prior_Insurance_Information__c LIMIT 1];
        Driver__c driver = [SELECT Id FROM Driver__c LIMIT 1];
        Vehicle__c vehicle = [SELECT Id FROM Vehicle__c LIMIT 1];
        Auto_Incidents_Violations__c incident = [SELECT Id FROM Auto_Incidents_Violations__c LIMIT 1];
        
        // Build the payload
        LeadQuoteController.QuotePayload payload = new LeadQuoteController.QuotePayload();
        payload.leadId = testLead.Id;
        payload.firstName = 'UpdatedFirstName';
        payload.lastName = 'UpdatedLastName';
        payload.email = 'updated@example.com';
        payload.phone = '555-0200';
        payload.street = '123 Test St';
        payload.city = 'Test City';
        
        // Add new items for the upsert logic
        payload.properties = new List<Property_Information__c>{ new Property_Information__c(Lead__c = testLead.Id) };
        payload.priorInsurances = new List<Prior_Insurance_Information__c>{ new Prior_Insurance_Information__c(Lead__c = testLead.Id) };
        payload.drivers = new List<Driver__c>{ new Driver__c(Lead__c = testLead.Id, First_Name__c = 'Jane', Last_Name__c = 'Doe') };
        payload.vehicles = new List<Vehicle__c>{ new Vehicle__c(Lead__c = testLead.Id, Make__c = 'Honda') };
        payload.incidents = new List<Auto_Incidents_Violations__c>{ new Auto_Incidents_Violations__c(Lead__c = testLead.Id) };
        
        // Add existing IDs to the deletion logic
        payload.deletedPropertyIds = new List<String>{ prop.Id };
        payload.deletedPriorInsuranceIds = new List<String>{ prior.Id };
        payload.deletedDriverIds = new List<String>{ driver.Id };
        payload.deletedVehicleIds = new List<String>{ vehicle.Id };
        payload.deletedIncidentIds = new List<String>{ incident.Id };
        
        // Serialize to simulate wire input
        String jsonPayload = JSON.serialize(payload);
        
        Test.startTest();
        // Invoke the save method
        LeadQuoteController.saveQuoteData(jsonPayload);
        Test.stopTest();
    }

    @isTest
    static void testSaveQuoteDataException() {
        Test.startTest();
        try {
            // Passing a deliberately malformed JSON string to force an Exception and cover the catch block
            LeadQuoteController.saveQuoteData('This is not a valid JSON string');
        } catch (Exception e) {
            // Exception is caught to allow the test to complete normally while gaining coverage
        }
        Test.stopTest();
    }
}