public without sharing class HistoryTrackingController {
    
    // Logic to capture changes and insert into the NEW History_Tracking__c object
    public static void processChanges(List<SObject> newList, Map<Id, SObject> oldMap, String objectApiName) {
        List<History_Tracker_Setting__mdt> settings = [
            SELECT MasterLabel, Field_API_Name__c 
            FROM History_Tracker_Setting__mdt 
            WHERE Object_API_Name__c = :objectApiName AND Is_Active__c = true
        ];

        if (settings.isEmpty()) return;

        List<History_Tracking__c> logs = new List<History_Tracking__c>();

        for (SObject newRec : newList) {
            SObject oldRec = oldMap.get(newRec.Id);
            if (oldRec == null) continue;

            for (History_Tracker_Setting__mdt s : settings) {
                String field = s.Field_API_Name__c;
                // use get() for dynamic field access
                Object nVal = newRec.get(field);
                Object oVal = oldRec.get(field);

                if (String.valueOf(nVal) != String.valueOf(oVal)) {
                    logs.add(new History_Tracking__c(
                        Parent_ID__c = (String)newRec.get('Id'),
                        Field_Name__c = s.MasterLabel,
                        Old_Value__c = oVal == null ? null : String.valueOf(oVal),
                        New_Value__c = nVal == null ? null : String.valueOf(nVal),
                        Action__c = 'Update'
                    ));
                }
            }
        }
        if (!logs.isEmpty()) insert logs;
    }

    // This method is called by your HistoryTrackingLWC
    @AuraEnabled(cacheable=true)
    public static List<HistoryWrapper> getHistoryLog(String recordId) {
        List<HistoryWrapper> results = new List<HistoryWrapper>();
        for (History_Tracking__c log : [
            SELECT Id, Field_Name__c, Old_Value__c, New_Value__c, CreatedDate, CreatedBy.Name
            FROM History_Tracking__c
            WHERE Parent_ID__c = :recordId
            ORDER BY CreatedDate DESC
        ]) {
            HistoryWrapper wrap = new HistoryWrapper();
            wrap.id = log.Id;
            wrap.fieldName = log.Field_Name__c;
            wrap.oldValue = log.Old_Value__c;
            wrap.newValue = log.New_Value__c;
            wrap.modifiedByName = log.CreatedBy.Name;
            wrap.modifiedDate = log.CreatedDate;
            results.add(wrap);
        }
        return results;
    }

    public class HistoryWrapper {
        @AuraEnabled public String id;
        @AuraEnabled public String fieldName;
        @AuraEnabled public String oldValue;
        @AuraEnabled public String newValue;
        @AuraEnabled public String modifiedByName;
        @AuraEnabled public Datetime modifiedDate;
    }
}