public without sharing class ContentVersionHandler implements TriggerInterface {

    public void afterInsert(Map<Id, SObject> mapNewRecords) {
        // 1. Feature Switch Check
        if (System.Label.Enable_Note_History_Tracking != 'TRUE') {
            return;
        }

        // 2. Delegate to Helper
        List<ContentVersion> newVersions = (List<ContentVersion>) mapNewRecords.values();
        
        // This will work now because the Helper exists!
        ContentVersionHelper.processNoteHistory(newVersions);
    }

    // --- Empty Interface Methods ---
    public void beforeInsert(List<SObject> newRecords) {}
    public void beforeUpdate(Map<Id, SObject> mapNewRecords, Map<Id, SObject> mapOldRecords) {}
    public void beforeDelete(Map<Id, SObject> mapOldRecords) {}
    public void afterUpdate(Map<Id, SObject> mapNewRecords, Map<Id, SObject> mapOldRecords) {}
    public void afterDelete(Map<Id, SObject> mapOldRecords) {}
    public void afterUnDelete(Map<Id, SObject> mapNewRecords) {}
}