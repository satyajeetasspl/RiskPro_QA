@IsTest
private class PropertyInformationControllerTest {

    /* ------------------ Helper Method ------------------ */
    private static Property_Information__c createPropertyInfo() {
        Lead l = new Lead(
            LastName = 'Test Lead',
            Company = 'Test Company',
            Status = 'Open - Not Contacted'
        );
        insert l;

        Property_Information__c pi = new Property_Information__c(
            Lead__c = l.Id,
            Year_Built__c = '2000',
            Foundation_Type__c = 'Concrete',
            Construction__c = 'Brick'
        );
        insert pi;
        return pi;
    }

    /* ------------------ Tests ------------------ */

    @IsTest static void testGetCurrentUserId() {
        Test.startTest();
        PropertyInformationController.getCurrentUserId();
        Test.stopTest();
    }

    @IsTest static void testGetPropertyInfo_Success() {
        Property_Information__c pi = createPropertyInfo();
        Test.startTest();
        PropertyInformationController.getPropertyInfo(pi.Id);
        Test.stopTest();
    }

    @IsTest static void testGetPropertyInfo_NullId() {
        Test.startTest();
        PropertyInformationController.getPropertyInfo(null);
        Test.stopTest();
    }

    @IsTest static void testSavePropertyInfo_Insert() {
        Property_Information__c pi = new Property_Information__c(
            Year_Built__c = '2010',
            Foundation_Type__c = 'Stone',
            Construction__c = 'Wood'
        );

        Test.startTest();
        PropertyInformationController.savePropertyInfo(pi);
        Test.stopTest();
    }

    @IsTest static void testSavePropertyInfo_Update() {
        Property_Information__c pi = createPropertyInfo();
        pi.Construction__c = 'Updated';

        Test.startTest();
        PropertyInformationController.savePropertyInfo(pi);
        Test.stopTest();
    }

    @IsTest static void testSavePropertyInfo_NullRecord() {
        Test.startTest();
        try {
            PropertyInformationController.savePropertyInfo(null);
        } catch (Exception e) {
            // expected
        }
        Test.stopTest();
    }

    @IsTest static void testSaveAnimal_NullJson() {
        Test.startTest();
        try {
            PropertyInformationController.saveAnimal(null);
        } catch (Exception e) {
            // expected
        }
        Test.stopTest();
    }

    @IsTest static void testSaveAnimal_EmptyJson() {
        Test.startTest();
        try {
            PropertyInformationController.saveAnimal('');
        } catch (Exception e) {
            // expected
        }
        Test.stopTest();
    }

    @IsTest static void testSaveAnimal_InvalidJson() {
        Test.startTest();
        try {
            PropertyInformationController.saveAnimal('{"invalid":"data"}');
        } catch (Exception e) {
            // expected
        }
        Test.stopTest();
    }

    @IsTest static void testGetPropertyInfoByLead() {
        Property_Information__c pi = createPropertyInfo();

        Test.startTest();
        PropertyInformationController.getPropertyInfoByLead(pi.Lead__c);
        Test.stopTest();
    }

    @IsTest static void testGetPropertyInfoByProperty() {
        Property_Information__c pi = createPropertyInfo();

        Test.startTest();
        PropertyInformationController.getPropertyInfoByProperty(pi.Properties__c);
        Test.stopTest();
    }

    @IsTest static void testGetAnimals() {
        Property_Information__c pi = createPropertyInfo();

        Animals_on_Premises__c animal = new Animals_on_Premises__c(
            Property_Information__c = pi.Id,
            Type_Breed__c = 'Boxer',
            Number__c = 1,
            Bite_History__c = false
        );
        insert animal;

        Test.startTest();
        PropertyInformationController.getAnimals(pi.Id);
        Test.stopTest();
    }

    @IsTest static void testSaveAnimal_Success() {
        Property_Information__c pi = createPropertyInfo();

        Animals_on_Premises__c animal = new Animals_on_Premises__c(
            Property_Information__c = pi.Id,
            Type_Breed__c = 'Boxer',
            Number__c = 2,
            Bite_History__c = false
        );

        String animalJson = JSON.serialize(animal);

        Test.startTest();
        PropertyInformationController.saveAnimal(animalJson);
        Test.stopTest();
    }
}