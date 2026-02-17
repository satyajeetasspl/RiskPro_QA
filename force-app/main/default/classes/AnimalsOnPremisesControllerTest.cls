@IsTest
public with sharing class AnimalsOnPremisesControllerTest {

    @TestSetup
    static void makeData() {
        Property_Information__c propInfo = new Property_Information__c();
        insert propInfo;

        List<Animals_on_Premises__c> animals = new List<Animals_on_Premises__c>();
        animals.add(new Animals_on_Premises__c(
            Property_Information__c = propInfo.Id,
            Name = 'Dog 1',
            Type_Breed__c = 'Boxer',
            Number__c = 1,
            Bite_History__c = false
        ));
        animals.add(new Animals_on_Premises__c(
            Property_Information__c = propInfo.Id,
            Name = 'Cat 1',
            Type_Breed__c = 'Boxer',
            Number__c = 2,
            Bite_History__c = true
        ));
        insert animals;
    }

    @IsTest
    static void testGetAnimals() {
        Property_Information__c propInfo = [SELECT Id FROM Property_Information__c LIMIT 1];
        List<Animals_on_Premises__c> animals = AnimalsOnPremisesController.getAnimals(propInfo.Id);
    }

    @IsTest
    static void testSaveAnimals_Insert() {
        Property_Information__c propInfo = [SELECT Id FROM Property_Information__c LIMIT 1];
        List<Animals_on_Premises__c> newAnimals = new List<Animals_on_Premises__c>();
        newAnimals.add(new Animals_on_Premises__c(
            Name = 'Bird 1',
            Type_Breed__c = 'Boxer', // Ensure any new records use a valid picklist value
            Number__c = 1,
            Bite_History__c = false
        ));
        Test.startTest();
        AnimalsOnPremisesController.saveAnimals(newAnimals, propInfo.Id);
        Test.stopTest();
    }

    @IsTest
    static void testSaveAnimals_Update() {
        Property_Information__c propInfo = [SELECT Id FROM Property_Information__c LIMIT 1];
        Animals_on_Premises__c existingAnimal = [SELECT Id, Name, Number__c FROM Animals_on_Premises__c LIMIT 1];

        existingAnimal.Number__c = 5;

        List<Animals_on_Premises__c> animalsToUpdate = new List<Animals_on_Premises__c>{existingAnimal};

        Test.startTest();
        AnimalsOnPremisesController.saveAnimals(animalsToUpdate, propInfo.Id);
        Test.stopTest();
    }

    @IsTest
    static void testDeleteAnimal() {
        Animals_on_Premises__c animalToDelete = [SELECT Id FROM Animals_on_Premises__c LIMIT 1];
        Test.startTest();
        AnimalsOnPremisesController.deleteAnimal(animalToDelete.Id);
        Test.stopTest();
    }
}