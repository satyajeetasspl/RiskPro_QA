public class ContentDocumentHandler implements TriggerInterface {

    public void beforeDelete(Map<Id, SObject> mapOldRecords) {
        
        // 1. Get Current User Profile
        // (Best practice: In a real framework, you might cache this in a utility class)
        Profile currentUserProfile = [SELECT Name FROM Profile WHERE Id = :UserInfo.getProfileId() LIMIT 1];

        // 2. Check if Restricted Profile
        if (currentUserProfile.Name == 'Standard User' || currentUserProfile.Name == 'RiskPro Standard Profile') {
            
            Set<Id> docIds = new Set<Id>();
            List<ContentDocument> docsToCheck = new List<ContentDocument>();

            // Cast SObjects to ContentDocument to access specific fields
            for (SObject sobj : mapOldRecords.values()) {
                ContentDocument cd = (ContentDocument) sobj;
                if (cd.FileType == 'SNOTE') {
                    docIds.add(cd.Id);
                    docsToCheck.add(cd);
                }
            }

            if (!docIds.isEmpty()) {
                // 3. Query Links to see if they are attached to restricted objects
                List<ContentDocumentLink> links = [
                    SELECT ContentDocumentId, LinkedEntity.Type 
                    FROM ContentDocumentLink 
                    WHERE ContentDocumentId IN :docIds
                ];

                Set<Id> restrictedDocIds = new Set<Id>();
                for (ContentDocumentLink link : links) {
                    String parentType = link.LinkedEntity.Type;
                    if (parentType == 'Account' || parentType == 'Contact' || parentType == 'Lead') {
                        restrictedDocIds.add(link.ContentDocumentId);
                    }
                }

                // 4. Add Error using Custom Label
                for (ContentDocument cd : docsToCheck) {
                    if (restrictedDocIds.contains(cd.Id)) {
                        cd.addError(Label.Note_Deletion_Error);
                    }
                }
            }
        }
    }

    // --- Empty Implementations for unused events ---
    public void beforeInsert(List<SObject> newRecords) {}
    public void beforeUpdate(Map<Id, SObject> mapNewRecords, Map<Id, SObject> mapOldRecords) {}
    public void afterInsert(Map<Id, SObject> mapNewRecords) {}
    public void afterUpdate(Map<Id, SObject> mapNewRecords, Map<Id, SObject> mapOldRecords) {}
    public void afterDelete(Map<Id, SObject> mapOldRecords) {}
    public void afterUnDelete(Map<Id, SObject> mapNewRecords) {}
}