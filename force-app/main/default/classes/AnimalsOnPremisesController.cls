public with sharing class AnimalsOnPremisesController {

    @AuraEnabled(cacheable=true)
    public static List<Animals_on_Premises__c> getAnimals(Id propertyInfoId) {
        return [
            SELECT Id, Name, Type_Breed__c, Number__c, Bite_History__c
            FROM Animals_on_Premises__c
            WHERE Property_Information__c = :propertyInfoId
            ORDER BY CreatedDate ASC
        ];
    }

    @AuraEnabled
    public static void saveAnimals(List<Animals_on_Premises__c> animals, Id propertyInfoId) {
        for (Animals_on_Premises__c a : animals) {
            a.Property_Information__c = propertyInfoId;
        }
        upsert animals;
    }

    @AuraEnabled
    public static void deleteAnimal(Id recordId) {
        delete [SELECT Id FROM Animals_on_Premises__c WHERE Id = :recordId];
    }
}