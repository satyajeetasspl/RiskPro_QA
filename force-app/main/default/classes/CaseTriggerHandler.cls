public class CaseTriggerHandler implements TriggerInterface {
    // Unused interface hooks for this requirement
    public void beforeInsert(List<SObject> newRecords) {}
    public void beforeUpdate(Map<Id, SObject> mapNewRecords, Map<Id, SObject> mapOldRecords) {}
    public void beforeDelete(Map<Id, SObject> mapOldRecords) {}
    public void afterInsert(Map<Id, SObject> mapNewRecords) {
        List<Case> cases = (List<Case>) mapNewRecords.values();
        List<Id> caseIds = new List<Id>();

        for (Case c : cases) {
            System.debug('Processing Case Id: ' + c.Id);
            if (String.isNotBlank(c.Description) && c.Origin == 'Email') {
                caseIds.add(c.Id);
                System.debug('Case added for processing: ' + c.Id);
            } else {
                System.debug('Case skipped (No description or not Email origin): ' + c.Id);
            }
        }

        if (!caseIds.isEmpty()) {
            List<Lead> leads = CaseHelper.parseDescription(caseIds);
            System.debug('Leads parsed from cases: ' + leads.size());
            if (!leads.isEmpty()) {
                insert leads;
                System.debug('Inserted ' + leads.size() + ' leads successfully.');
            } else {
                System.debug('No leads to insert.');
            }
        } else {
            System.debug('No cases to process.');
        }
    }
    
    public void afterDelete(Map<Id, SObject> mapOldRecords) {}
    public void afterUnDelete(Map<Id, SObject> mapNewRecords) {}
    
    public void afterUpdate(Map<Id, SObject> mapNewRecords, Map<Id, SObject> mapOldRecords) {
       
    }
    
}