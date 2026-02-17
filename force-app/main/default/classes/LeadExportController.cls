public with sharing class LeadExportController {

    @AuraEnabled(cacheable=true)
    public static List<String> fetchPartnerNameOptions() {
        List<String> partnerNames = new List<String>();

        try {
            AggregateResult[] results = [
                SELECT Partner_Name__c 
                FROM Lead 
                WHERE Partner_Name__c != NULL 
                GROUP BY Partner_Name__c 
                ORDER BY Partner_Name__c
            ];

            for (AggregateResult ar : results) {
                String name = (String) ar.get('Partner_Name__c');
                if (!String.isBlank(name)) {
                    partnerNames.add(name);
                }
            }

            return partnerNames;
        } catch (Exception ex) {
            throw new AuraHandledException('Error fetching Partner Names: ' + ex.getMessage());
        }
    }

    /**
     * Fetch Lead records for datatable
     * UPDATED: Now supports Date Filtering
     */
    @AuraEnabled(cacheable=true)
    public static List<Lead> fetchLeadsForTable(String partnerName, Date startDate, Date endDate) {
        try {
            // Start with a generic query
            String baseQuery = 'SELECT Id, Name, Company, Email, Phone, Status, Owner.Name, Partner_Name__c, CreatedDate FROM Lead WHERE Id != NULL';

            // 1. Filter by Partner Name
            if (String.isNotBlank(partnerName)) {
                baseQuery += ' AND Partner_Name__c = :partnerName';
            }

            // 2. Filter by Start Date (Inclusive)
            if (startDate != null) {
                baseQuery += ' AND DAY_ONLY(CreatedDate) >= :startDate';
            }

            // 3. Filter by End Date (Inclusive)
            if (endDate != null) {
                baseQuery += ' AND DAY_ONLY(CreatedDate) <= :endDate';
            }

            baseQuery += ' ORDER BY CreatedDate DESC LIMIT 50000';
            
            System.debug('Dynamic Table Query: ' + baseQuery);

            return Database.query(baseQuery);
        } catch (Exception ex) {
            throw new AuraHandledException('Error fetching leads: ' + ex.getMessage());
        }
    }

    /**
     * Fetch all fields dynamically for the selected (or filtered) Leads
     * (Unchanged - works with the IDs passed from the UI)
     */
    @AuraEnabled
    public static List<Map<String, Object>> fetchAllFieldsForSelectedLeads(List<Id> leadIds) {
        if (leadIds == null || leadIds.isEmpty()) {
            return new List<Map<String, Object>>();
        }

        try {
            Map<String, Schema.SObjectField> fieldMap = Schema.SObjectType.Lead.fields.getMap();
            List<String> fieldNames = new List<String>();

            for (String fieldName : fieldMap.keySet()) {
                fieldNames.add(fieldName);
            }

            if (!fieldNames.contains('Owner.Name')) {
                fieldNames.add('Owner.Name');
            }

            String soql = 'SELECT ' + String.join(fieldNames, ', ') + ' FROM Lead WHERE Id IN :leadIds';
            List<SObject> records = Database.query(soql);

            List<Map<String, Object>> result = new List<Map<String, Object>>();
            for (SObject record : records) {
                Map<String, Object> fieldData = new Map<String, Object>();
                for (String fieldName : fieldNames) {
                    if (fieldName.contains('.')) {
                        List<String> parts = fieldName.split('\\.');
                        SObject related = record.getSObject(parts[0]);
                        fieldData.put(fieldName, related != null ? related.get(parts[1]) : null);
                    } else {
                        fieldData.put(fieldName, record.get(fieldName));
                    }
                }
                result.add(fieldData);
            }

            return result;
        } catch (Exception ex) {
            throw new AuraHandledException('Error fetching all Lead fields: ' + ex.getMessage());
        }
    }
}