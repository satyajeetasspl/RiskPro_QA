public with sharing class PropertyDetailController {

    @AuraEnabled(cacheable=false)
    public static Property_Information__c getPropertyInfo(Id leadId) {
        if (leadId == null) {
            throw new AuraHandledException('Lead Id cannot be null.');
        }

        // Query safely for existing record
        List<Property_Information__c> props = [
            SELECT Id, Lead__c,
                   Any_smokers_in_the_Household__c, Construction__c,
                   Distance_to_Coastline__c, Diving_Board__c, Fence__c,
                   Hail_Resistive_Roof__c, Members_in_Household__c, Net__c,
                   Number_of_Families__c, Number_of_Mortgages__c, Number_of_Stories__c,
                   Roof_ACV__c, Roof_Shape__c, Roof_Type__c,
                   Slide__c, Square_Footage__c, Swimming_Pool_on_Premises__c,
                   Trampoline_on_Premises__c, Year_Built__c
            FROM Property_Information__c
            WHERE Lead__c = :leadId
            LIMIT 1
        ];

        // Return existing record or a blank one for form display
        if (!props.isEmpty()) {
            return props[0];
        } else {
            return new Property_Information__c(Lead__c = leadId);
        }
    }

    @AuraEnabled
    public static Property_Information__c saveProperty(Property_Information__c prop) {
        if (prop == null) {
            throw new AuraHandledException('No data to save.');
        }

        // Enforce one record per Lead
        List<Property_Information__c> existing = [
            SELECT Id FROM Property_Information__c WHERE Lead__c = :prop.Lead__c LIMIT 1
        ];

        if (prop.Id == null && !existing.isEmpty()) {
            // Prevent duplicate creation
            prop.Id = existing[0].Id;
            update prop;
        } else if (prop.Id == null) {
            insert prop;
        } else {
            update prop;
        }

        return prop;
    }
}