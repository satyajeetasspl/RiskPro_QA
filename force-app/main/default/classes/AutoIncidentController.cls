public with sharing class AutoIncidentController {

    // ✅ Get all related incidents for either Lead or Account
    @AuraEnabled(cacheable=true)
    public static List<Auto_Incidents_Violations__c> getRecordsByParent(Id parentId) {
        if (parentId == null) {
            throw new AuraHandledException('Parent Id cannot be null.');
        }

        return [
            SELECT Id, Name, Lead__c, Account__c,
                   Operator__c, Operator__r.First_Name__c, Operator__r.Last_Name__c,
                   Date__c, Additional_Information__c, Incident_Description__c
            FROM Auto_Incidents_Violations__c
            WHERE Lead__c = :parentId OR Account__c = :parentId
            ORDER BY Date__c DESC
        ];
    }

    // ✅ Get all Drivers related to either Lead or Account
    @AuraEnabled(cacheable=true)
    public static List<Driver__c> getAllDrivers(Id parentId) {
        if (parentId == null) {
            throw new AuraHandledException('Parent Id cannot be null.');
        }

        return [
            SELECT Id, First_Name__c, Last_Name__c, Lead__c, Account__c
            FROM Driver__c
            WHERE Lead__c = :parentId OR Account__c = :parentId
            ORDER BY First_Name__c, Last_Name__c
        ];
    }

    // ✅ Create new record
    @AuraEnabled
    public static String createRecord(Auto_Incidents_Violations__c newRecord) {
        try {
            insert newRecord;
            return 'SUCCESS';
        } catch (Exception e) {
            return 'ERROR: ' + e.getMessage();
        }
    }

    // ✅ Update existing record
    @AuraEnabled
    public static String updateRecord(Auto_Incidents_Violations__c updatedRecord) {
        try {
            update updatedRecord;
            return 'SUCCESS';
        } catch (Exception e) {
            return 'ERROR: ' + e.getMessage();
        }
    }

    // ✅ Delete record
    @AuraEnabled
    public static String deleteRecord(Id recordId) {
        try {
            delete [SELECT Id FROM Auto_Incidents_Violations__c WHERE Id = :recordId];
            return 'SUCCESS';
        } catch (Exception e) {
            return 'ERROR: ' + e.getMessage();
        }
    }

    // ✅ Get single record (for editing)
    @AuraEnabled(cacheable=true)
    public static Auto_Incidents_Violations__c getRecordById(Id recordId) {
        if (recordId == null) {
            throw new AuraHandledException('Record Id cannot be null.');
        }

        return [
            SELECT Id, Lead__c, Account__c, Operator__c, Date__c,
                   Additional_Information__c, Incident_Description__c
            FROM Auto_Incidents_Violations__c
            WHERE Id = :recordId
            LIMIT 1
        ];
    }
}