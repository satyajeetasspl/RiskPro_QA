public with sharing class PolicyInformationTriggerHandler implements TriggerInterface {
    
    public void beforeInsert(List<SObject> newRecords) {}
    public void beforeUpdate(Map<Id, SObject> mapNewRecords, Map<Id, SObject> mapOldRecords) {}
    public void beforeDelete(Map<Id, SObject> mapOldRecords) {}
    public void afterInsert(Map<Id, SObject> mapNewRecords) {}
    public void afterDelete(Map<Id, SObject> mapOldRecords) {}
    public void afterUnDelete(Map<Id, SObject> mapNewRecords) {}

    public void afterUpdate(Map<Id, SObject> mapNewRecords, Map<Id, SObject> mapOldRecords) {
        
        List<Policy_Information__c> policiesToSync = new List<Policy_Information__c>();
        
        for (Id policyId : mapNewRecords.keySet()) {
            Policy_Information__c newPolicy = (Policy_Information__c)mapNewRecords.get(policyId);
            Policy_Information__c oldPolicy = (Policy_Information__c)mapOldRecords.get(policyId);
            
            boolean accountIdPopulated = (newPolicy.Account__c != null && oldPolicy.Account__c == null);
            boolean needsSync = newPolicy.AMS_Policy_Synced__c == false;
            
            if (accountIdPopulated && needsSync) {
                policiesToSync.add(newPolicy);
            }
        }
        
        if (!policiesToSync.isEmpty()) {
            syncToAmsPolicyObject(policiesToSync);
        }
    }

    private void syncToAmsPolicyObject(List<Policy_Information__c> policies) {
    
    List<vert__AMS360_Policy__c> newAmsPolicies = new List<vert__AMS360_Policy__c>();
    Id hardcodedEmployeeId = Test.isRunningTest() ? null : (Id)'a0gV9000001KiCPIA0';
    
    for (Policy_Information__c sourcePolicy : policies) {
        vert__AMS360_Policy__c amsPolicy = new vert__AMS360_Policy__c();
        
        amsPolicy.Name = sourcePolicy.Policy__c;
        amsPolicy.vert__AMS360_Employee_Policy_Rep__c = hardcodedEmployeeId;
        amsPolicy.vert__AMS360_Employee_Policy_Exec__c = hardcodedEmployeeId;
        
        amsPolicy.vert__AMS360_Effective_Date__c = sourcePolicy.Effective_Date__c;
        
        newAmsPolicies.add(amsPolicy);
    }
    
    Database.SaveResult[] results = Database.insert(newAmsPolicies, false);
    
    Set<Id> successfulPolicyIds = new Set<Id>();
    
    for (Integer i = 0; i < results.size(); i++) {
        if (results[i].isSuccess()) {
            successfulPolicyIds.add(policies[i].Id);
        }else {
        // ADD THIS: Log the error to find out why it failed
        for(Database.Error err : results[i].getErrors()) {
            System.debug('The following error has occurred.');                    
            System.debug(err.getStatusCode() + ': ' + err.getMessage());
            System.debug('Fields that affected this error: ' + err.getFields());
        }
      }
    }

    if (!successfulPolicyIds.isEmpty()) {
        List<Policy_Information__c> policiesToUpdate = [
            SELECT Id, AMS_Policy_Synced__c
            FROM Policy_Information__c
            WHERE Id IN :successfulPolicyIds
        ];
        
        for(Policy_Information__c p : policiesToUpdate){
            p.AMS_Policy_Synced__c = true;
        }

        update policiesToUpdate;
    }
}
}