@isTest
public class PropertyDetailControllerTest {

    // Utility to create test Lead
    private static Lead createLead() {
        Lead ld = new Lead(
            LastName = 'Test Lead',
            Company = 'Test Co'
        );
        insert ld;
        return ld;
    }

    @isTest
    static void testGetPropertyInfo_NullLeadId() {
        try {
            PropertyDetailController.getPropertyInfo(null);
        } catch (Exception e) {
            // assertion removed as per request
        }
    }

    @isTest
    static void testGetPropertyInfo_ReturnExisting() {
        Lead ld = createLead();

        Property_Information__c prop = new Property_Information__c(
            Lead__c = ld.Id,
            Square_Footage__c = 123
        );
        insert prop;

        Property_Information__c result =
            PropertyDetailController.getPropertyInfo(ld.Id);
    }

    @isTest
    static void testGetPropertyInfo_ReturnNew() {
        Lead ld = createLead();

        Property_Information__c result =
            PropertyDetailController.getPropertyInfo(ld.Id);
    }

    @isTest
    static void testSaveProperty_NullInput() {
        try {
            PropertyDetailController.saveProperty(null);
        } catch (Exception e) {
            // assertion removed as per request
        }
    }

    @isTest
    static void testSaveProperty_InsertNew() {
        Lead ld = createLead();

        Property_Information__c prop = new Property_Information__c(
            Lead__c = ld.Id,
            Square_Footage__c = 100
        );

        Test.startTest();
        Property_Information__c saved = PropertyDetailController.saveProperty(prop);
        Test.stopTest();
    }

    @isTest
    static void testSaveProperty_UpdateExisting() {
        Lead ld = createLead();

        Property_Information__c prop = new Property_Information__c(
            Lead__c = ld.Id,
            Square_Footage__c = 200
        );
        insert prop;

        prop.Square_Footage__c = 300;

        Test.startTest();
        Property_Information__c updated = PropertyDetailController.saveProperty(prop);
        Test.stopTest();
    }

    @isTest
    static void testSaveProperty_PreventDuplicateCreation() {
        Lead ld = createLead();

        // Existing record
        Property_Information__c existing = new Property_Information__c(
            Lead__c = ld.Id,
            Square_Footage__c = 400
        );
        insert existing;

        // new attempt (Id = null)
        Property_Information__c newAttempt = new Property_Information__c(
            Lead__c = ld.Id,
            Square_Footage__c = 500
        );

        Test.startTest();
        Property_Information__c result = PropertyDetailController.saveProperty(newAttempt);
        Test.stopTest();
    }
}