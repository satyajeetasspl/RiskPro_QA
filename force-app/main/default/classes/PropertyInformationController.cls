public with sharing class PropertyInformationController {

    @AuraEnabled(cacheable=true)
    public static Id getCurrentUserId() {
        System.debug(' [getCurrentUserId] Called by user: ' + UserInfo.getUserId());
        return UserInfo.getUserId();
    }
    
    @AuraEnabled
public static Id getPropertyInfoByLead(Id leadId) {
    List<Property_Information__c> piList = [
        SELECT Id
        FROM Property_Information__c
        WHERE Lead__c = :leadId
        LIMIT 1
    ];
    return piList.isEmpty() ? null : piList[0].Id;
}


    @AuraEnabled
    public static Property_Information__c getPropertyInfo(Id recordId) {
        System.debug(' [getPropertyInfo] Called with recordId: ' + recordId);
        if (recordId == null) return null;

        Property_Information__c info = [
            SELECT Name, OwnerId, Lead__c, Properties__c, Year_Built__c, Age_of_Dwelling__c, Foundation_Type__c,
                   Construction__c, Full_Bath__c, Half_Bath__c, X3_4_Bath__c, Number_of_Families__c,
                   Members_in_Household__c, Purchased_Rental_Date__c, Number_of_Mortgages__c,
                   Square_Footage__c, Number_of_Stories__c, Distance_to_Coastline__c, Community__c,
                   Roof_Type__c, Roof_Shape__c, Roof_ACV__c, Hail_Resistive_Roof__c, Number_of_Roof_Layers__c,
                   Trampoline_on_Premises__c, Swimming_Pool_on_Premises__c, Hot_Tub_on_Premise__c,
                   Fence__c, Locked_Secure_Cover__c, Any_smokers_in_the_Household__c,
                   Plumbing__c, Plumbing_Year__c, Primary_Heat_Type__c, Auxiliary_Heat_Type__c,
                   Heating_Year__c, Heating_Type__c, Winning__c, Wiring_Year__c, Diving_Board__c, Locked__c,
                   Slide__c, Net__c, Exterior_Paint__c, Complete__c, Partial__c, Fence_3__c, Ladder__c, Removable_Retracting_Locking__c, Fence_2__c

            FROM Property_Information__c
            WHERE Id = :recordId
            LIMIT 1
        ];

        System.debug(' [getPropertyInfo] Result: ' + info);
        return info;
    }
    
    @AuraEnabled(cacheable=true)
    public static Id getPropertyInfoByProperty(Id propertyId) {
        List<Property_Information__c> piList = [
            SELECT Id
            FROM Property_Information__c
            WHERE Properties__c = :propertyId 
            LIMIT 1
        ];
        return piList.isEmpty() ? null : piList[0].Id;
    }

    @AuraEnabled
    public static Property_Information__c savePropertyInfo(Property_Information__c pi) {
        System.debug(' [savePropertyInfo] Called with: ' + pi);

        try {
            if (pi == null) {
                throw new AuraHandledException('No record provided.');
            }

            if (String.isBlank(pi.OwnerId)) {
                pi.OwnerId = UserInfo.getUserId();
                System.debug('️ [savePropertyInfo] OwnerId set to current user: ' + pi.OwnerId);
            }

            upsert pi;
            System.debug(' [savePropertyInfo] Upsert success, record Id: ' + pi.Id);

            Property_Information__c result = [
                SELECT Name, OwnerId, Lead__c, Properties__c, Year_Built__c, Age_of_Dwelling__c, Foundation_Type__c,
                       Construction__c, Full_Bath__c, Half_Bath__c, X3_4_Bath__c, Number_of_Families__c,
                       Members_in_Household__c, Purchased_Rental_Date__c, Number_of_Mortgages__c,
                       Square_Footage__c, Number_of_Stories__c, Distance_to_Coastline__c, Community__c,
                       Roof_Type__c, Roof_Shape__c, Roof_ACV__c, Hail_Resistive_Roof__c, Locked__c,
                       Number_of_Roof_Layers__c, Trampoline_on_Premises__c, Swimming_Pool_on_Premises__c,
                       Hot_Tub_on_Premise__c, Fence__c, Locked_Secure_Cover__c, Any_smokers_in_the_Household__c,
                       Plumbing__c, Plumbing_Year__c, Primary_Heat_Type__c, Auxiliary_Heat_Type__c,
                       Heating_Year__c, Heating_Type__c, Winning__c, Wiring_Year__c, Diving_Board__c,
                       Slide__c, Net__c, Exterior_Paint__c, Complete__c, Partial__c, Fence_3__c, Ladder__c, Removable_Retracting_Locking__c, Fence_2__c
                FROM Property_Information__c
                WHERE Id = :pi.Id
                LIMIT 1
            ];

            System.debug(' [savePropertyInfo] Returning record: ' + result);
            return result;

        } catch (Exception e) {
            System.debug(' [savePropertyInfo] Exception: ' + e.getMessage() + ' | Stack: ' + e.getStackTraceString());
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    @AuraEnabled
    public static List<Animals_on_Premises__c> getAnimals(Id propertyId) {

        return [
            SELECT Id, Type_Breed__c, Number__c, Bite_History__c 
            FROM Animals_on_Premises__c 
            WHERE Property_Information__c = :propertyId
        ];
    }

    @AuraEnabled
    public static Animals_on_Premises__c saveAnimal(String animalJson) {
        System.debug(' [saveAnimal] Called with JSON: ' + animalJson);

        try {
            if (String.isBlank(animalJson)) {
                throw new AuraHandledException('No animal data provided.');
            }

            // Deserialize JSON into the SObject
            Animals_on_Premises__c animal = 
                (Animals_on_Premises__c) JSON.deserialize(animalJson, Animals_on_Premises__c.class);
            System.debug(' [saveAnimal] Deserialized animal: ' + animal);

            insert animal;
            System.debug(' [saveAnimal] Inserted successfully with Id: ' + animal.Id);

            Animals_on_Premises__c result = [
                SELECT Id, Name, Bite_History__c, Type_Breed__c, Property_Information__c, Number__c
                FROM Animals_on_Premises__c
                WHERE Id = :animal.Id
                LIMIT 1
            ];

            System.debug('✅ [saveAnimal] Returning result: ' + result);
            return result;

        } catch (Exception e) {
            System.debug(' [saveAnimal] Exception: ' + e.getMessage() + ' | Stack: ' + e.getStackTraceString());
            throw new AuraHandledException('Error saving Animal record: ' + e.getMessage());
        }
    }
}