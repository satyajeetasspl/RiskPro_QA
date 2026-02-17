public with sharing class LeadToAccountHelper {

    public static void convertLeadsToAccounts(List<Lead> leadsToConvert, Map<String, String> leadAccountMap) {
        // Create a map to hold all related objects and their corresponding lead-to-account mappings
        Map<String, List<SObject>> objectUpdates = new Map<String, List<SObject>>();

        // Collect all lead IDs from the leads that need conversion
        Set<Id> leadIds = new Set<Id>();
        for (Lead leadDetail : leadsToConvert) {
            leadIds.add(leadDetail.Id);
        }

        // List of related objects that need to be updated
        List<String> relatedObjects = new List<String>{
            'Cross_Sell__c', 'Driver__c', 'Vehicle__c', 'Properties__c',
            'Policy_Information__c', 'Prior_Insurance_Information__c',
            'Auto_Incidents_Violations__c', 'Home_Losses_Claims__c'
        };

        // Process each related object in bulk
        for (String sObj : relatedObjects) {
            // Perform the query for all related records in one go, binding the lead IDs
            String query = 'SELECT Id, Lead__c, Account__c FROM ' + sObj + ' WHERE Lead__c IN :leadIds';
            List<SObject> records = Database.query(query);

            // Prepare a list of records to update
            List<SObject> updates = new List<SObject>();
            for (SObject rec : records) {
                Id leadId = (Id) rec.get('Lead__c');
                if (leadAccountMap.containsKey(leadId)) {
                    // Update the Account__c field and nullify the Lead__c field
                    rec.put('Account__c', leadAccountMap.get(leadId));
                    rec.put('Lead__c', null); // Remove the reference to Lead
                    updates.add(rec);
                }
            }

            // Store the updates in the map for bulk DML later
            if (!updates.isEmpty()) {
                objectUpdates.put(sObj, updates);
            }
        }  

        // Perform all DML updates at once for all related objects
        for (String sObj : objectUpdates.keySet()) {
            List<SObject> updates = objectUpdates.get(sObj);
            if (!updates.isEmpty()) {
                Database.update(updates, false); // Use partial success for bulk updates
                System.debug('Updated ' + updates.size() + ' records for ' + sObj);
            }
        }
    }
}