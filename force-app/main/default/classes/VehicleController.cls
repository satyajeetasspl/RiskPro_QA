public with sharing class VehicleController {

    public class OptionWrapper {
        @AuraEnabled public String label;
        @AuraEnabled public String value;

        public OptionWrapper(String label, String value) {
            this.label = label;
            this.value = value;
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<Vehicle__c> getVehicles(Id recordId) {
        List<Vehicle__c> vehicles = [
            SELECT Name, Vehicle_Type__c, VIN__c, Year__c,Purchase_Year__c, Make__c, Model__c,
                Lienholder__c, Annual_Miles__c,
                Registered_To__c, Registered_To__r.Name
            FROM Vehicle__c
            WHERE Lead__c = :recordId
            ORDER BY CreatedDate DESC
        ];
        return vehicles;
    }

    @AuraEnabled
    public static void deleteVehicle(Id vehicleId) {
        try {
            delete [SELECT Id FROM Vehicle__c WHERE Id = :vehicleId];
        } catch (Exception e) {
            throw new AuraHandledException('Error deleting vehicle: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static Id createVehicle(Vehicle__c v) {
        try {
            insert v;
            return v.Id;
        } catch (Exception e) {
            throw new AuraHandledException('Error creating vehicle: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static void updateVehicle(Vehicle__c v) {
        try {
            update v;
        } catch (Exception e) {
            throw new AuraHandledException('Error updating vehicle: ' + e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<OptionWrapper> getAvailableDrivers(Id leadId) {
        List<OptionWrapper> options = new List<OptionWrapper>();
        if (leadId != null) {
            for (Driver__c d : [
                SELECT Id, First_Name__c, Last_Name__c
                FROM Driver__c
                WHERE Lead__c = :leadId
                ORDER BY Name
            ]) {
                options.add(new OptionWrapper(d.First_Name__c + ' ' + d.Last_Name__c, d.Id));
            }
        }
        return options;
    }

    // ⚡ NEW: Dynamic Vehicle Type options from metadata
    @AuraEnabled(cacheable=true)
    public static List<OptionWrapper> getVehicleTypeOptions() {
        List<OptionWrapper> options = new List<OptionWrapper>();
        Schema.DescribeFieldResult fieldResult = Vehicle__c.Vehicle_Type__c.getDescribe();
        for (Schema.PicklistEntry entry : fieldResult.getPicklistValues()) {
            options.add(new OptionWrapper(entry.getLabel(), entry.getValue()));
        }
        return options;
    }
}