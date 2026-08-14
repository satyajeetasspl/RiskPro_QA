public without sharing class RecordAuditController {

    public class AuditWrapper {
        @AuraEnabled public String id;
        @AuraEnabled public String fieldName;
        @AuraEnabled public String oldValue;
        @AuraEnabled public String newValue;
        @AuraEnabled public String modifiedByName;
        @AuraEnabled public Datetime modifiedDate;
    }

    @AuraEnabled
    public static List<AuditWrapper> getFieldAuditLogs(String recordId) {
        List<AuditWrapper> results = new List<AuditWrapper>();

        if (String.isBlank(recordId)) {
            return results;
        }

        List<Note_History_Logs__c> logs = [
            SELECT Id, Field_Name__c, Old_Value__c, New_Value__c,
                   CreatedDate, CreatedBy.Name
            FROM Note_History_Logs__c
            WHERE Parent_Record_Id__c = :recordId
            ORDER BY CreatedDate DESC, Id DESC
        ];

        for (Note_History_Logs__c log : logs) {
            AuditWrapper wrapper = new AuditWrapper();
            wrapper.id = log.Id;
            wrapper.fieldName = log.Field_Name__c;
            wrapper.modifiedByName = log.CreatedBy.Name;
            wrapper.modifiedDate = log.CreatedDate;
            
            // Failsafe for Old Value
            String oldVal = (log.Old_Value__c != null) ? log.Old_Value__c : '';
            if (oldVal.contains('&lt;')) {
                oldVal = oldVal.unescapeHtml4();
            }
            wrapper.oldValue = oldVal;

            // Failsafe for New Value
            String newVal = (log.New_Value__c != null) ? log.New_Value__c : '';
            if (newVal.contains('&lt;')) {
                newVal = newVal.unescapeHtml4();
            }
            wrapper.newValue = newVal;
            
            results.add(wrapper);
        }

        return results;
    }
}