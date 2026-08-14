public with sharing class RecordNotesController {

    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getNotes(Id recordId) {
        if (recordId == null) return new List<Map<String, Object>>();
        Set<Id> noteIds = new Set<Id>();
        
        for (ContentDocumentLink cdl : [SELECT ContentDocumentId FROM ContentDocumentLink WHERE LinkedEntityId = :recordId AND ContentDocument.FileType = 'SNOTE']) {
            noteIds.add(cdl.ContentDocumentId);
        }
        if (noteIds.isEmpty()) return new List<Map<String, Object>>();
        
        List<Map<String, Object>> result = new List<Map<String, Object>>();
        
        for (ContentNote cn : [SELECT Id, Title, TextPreview, CreatedDate, CreatedBy.Name, LastModifiedDate, LastModifiedBy.Name, Content FROM ContentNote WHERE Id IN :noteIds ORDER BY LastModifiedDate DESC]) {
            Map<String, Object> noteMap = new Map<String, Object>();
            noteMap.put('Id', cn.Id);
            noteMap.put('Title', cn.Title);
            noteMap.put('TextPreview', cn.TextPreview);
            noteMap.put('CreatedDate', cn.CreatedDate);
            noteMap.put('CreatedBy', new Map<String, Object>{'Name' => cn.CreatedBy.Name});
            noteMap.put('LastModifiedDate', cn.LastModifiedDate);
            noteMap.put('LastModifiedBy', new Map<String, Object>{'Name' => cn.LastModifiedBy.Name});
            
            String htmlContent = '';
            if (cn.Content != null) {
                try {
                    htmlContent = cn.Content.toString();
                    if (htmlContent.contains('<')) {
                        htmlContent = htmlContent.unescapeHtml4();
                    }
                } catch(Exception e) {
                    htmlContent = 'Error loading note.';
                }
            }
            noteMap.put('Content', htmlContent);
            result.add(noteMap);
        }
        return result;
    }

    @AuraEnabled
    public static Id createNote(Id recordId, String title, String body) {
        if (recordId == null) throw new AuraHandledException('Record Id is required.');
        if (checkDuplicateAction(recordId, 'Created')) return null;

        String noteTitle = String.isBlank(title) ? 'Untitled Note' : title.trim();
        String noteBody = (body == null) ? '' : body;

        ContentNote note = new ContentNote();
        note.Title = noteTitle;
        note.Content = Blob.valueOf(noteBody);
        insert note;

        ContentDocumentLink link = new ContentDocumentLink();
        link.LinkedEntityId = recordId;
        link.ContentDocumentId = note.Id;
        link.ShareType = 'I';
        link.Visibility = 'AllUsers';
        insert link;

        List<Note_History_Logs__c> logs = new List<Note_History_Logs__c>();
        logs.add(generateLog(recordId, note.Id, 'Created', 'Title', null, noteTitle));

        if (String.isNotBlank(noteBody)) {
            logs.add(generateLog(recordId, note.Id, 'Created', 'Body', null, noteBody));
        }
        if (!logs.isEmpty()) insert logs;

        return note.Id;
    }

    @AuraEnabled
    public static void updateNote(Id noteId, String title, String body, Id parentRecordId) {
        if (noteId == null) throw new AuraHandledException('Note Id is required.');
        if (checkDuplicateAction(parentRecordId, 'Updated')) return;

        ContentNote note = [SELECT Id, Title, Content FROM ContentNote WHERE Id = :noteId LIMIT 1];

        String oldTitle = note.Title;
        String oldBody = extractBody(note.Content);
        String newBody = (body == null) ? '' : body;
        String newTitle = String.isBlank(title) ? 'Untitled Note' : title.trim();

        note.Title = newTitle;
        note.Content = Blob.valueOf(newBody);
        update note;

        List<Note_History_Logs__c> logs = new List<Note_History_Logs__c>();
        if (oldTitle != newTitle) {
            logs.add(generateLog(parentRecordId, noteId, 'Updated', 'Title', oldTitle, newTitle));
        }
        if (oldBody != newBody) {
            logs.add(generateLog(parentRecordId, noteId, 'Updated', 'Body', oldBody, newBody));
        }

        if (!logs.isEmpty()) insert logs;
    }

    private static Boolean checkDuplicateAction(Id parentId, String action) {
        Datetime threshold = System.now().addSeconds(-2);
        Integer count = [
            SELECT COUNT() FROM Note_History_Logs__c
            WHERE Parent_Record_Id__c = :parentId AND CreatedById = :UserInfo.getUserId() AND Action__c = :action AND CreatedDate >= :threshold
        ];
        return count > 0;
    }

    private static Note_History_Logs__c generateLog(Id parentId, Id noteId, String action, String field, String oldVal, String newVal) {
        Note_History_Logs__c log = new Note_History_Logs__c();
        log.Parent_Record_Id__c = parentId;
        log.Note_Id__c = noteId;
        log.Action__c = action;
        log.Field_Name__c = field;
        log.Old_Value__c = (oldVal != null && oldVal.length() > 130000) ? oldVal.left(130000) : oldVal;
        log.New_Value__c = (newVal != null && newVal.length() > 130000) ? newVal.left(130000) : newVal;
        return log;
    }

    private static String extractBody(Blob data) {
        if (data == null) return '';
        try {
            String html = data.toString();
            html = html.replace('<br>', '\n').replace('<br/>', '\n').replace('</p>', '\n').replace('</div>', '\n');
            return html.stripHtmlTags().trim();
        } catch (Exception e) {
            return '';
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static Boolean isCurrentUserAdmin() {
        Profile p = [SELECT Name FROM Profile WHERE Id = :UserInfo.getProfileId() LIMIT 1];
        return p.Name == 'System Administrator';
    }
}