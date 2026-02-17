public interface TriggerInterface {
    void beforeInsert(List<SObject> newRecords);
    void beforeUpdate(Map<Id, SObject> mapNewRecords, Map<Id, SObject> mapOldRecords);
    void beforeDelete(Map<Id, SObject> mapOldRecords);
    void afterInsert(Map<Id, SObject> mapNewRecords);
    void afterUpdate(Map<Id, SObject> mapNewRecords, Map<Id, SObject> mapOldRecords);
    void afterDelete(Map<Id, SObject> mapOldRecords);
    void afterUnDelete(Map<Id, SObject> mapNewRecords);
}