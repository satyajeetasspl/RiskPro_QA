public class SignEasyTransactionTriggerHandler implements TriggerInterface {
    
    public void beforeInsert(List<SObject> newRecords) {
        // No implementation needed
    }

    public void beforeUpdate(Map<Id, SObject> mapNewRecords, Map<Id, SObject> mapOldRecords) {
        // No implementation needed
    }

    public void beforeDelete(Map<Id, SObject> mapOldRecords) {
        // No implementation needed
    }

    public void afterInsert(Map<Id, SObject> mapNewRecords) {
        SignEasyTransactionHelper.processCompletedTransactions(
            (Map<Id, hic_signeasy__Transaction__c>)mapNewRecords, 
            null
        );
    }

    public void afterUpdate(Map<Id, SObject> mapNewRecords, Map<Id, SObject> mapOldRecords) {
        SignEasyTransactionHelper.processCompletedTransactions(
            (Map<Id, hic_signeasy__Transaction__c>)mapNewRecords, 
            (Map<Id, hic_signeasy__Transaction__c>)mapOldRecords
        );
    }

    public void afterDelete(Map<Id, SObject> mapOldRecords) {
        // No implementation needed
    }

    public void afterUnDelete(Map<Id, SObject> mapNewRecords) {
        // No implementation needed
    }
}