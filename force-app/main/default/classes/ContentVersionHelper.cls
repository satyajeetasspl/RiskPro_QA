public without sharing class ContentVersionHelper {

    public static Boolean isLwcContext = false;

    private static Boolean isRunning = false;
    private static final Integer MAX_FIELD_LEN = 130000;

    public static void processNoteHistory(List<ContentVersion> newVersions) {

        // Log warning if not LWC context, but continue
        if (!isLwcContext) {
            System.debug('⚠️ WARNING: Update not initiated from LWC context. Continuing anyway so history is captured.');
        }

        if (newVersions == null || newVersions.isEmpty()) {
            return;
        }

        try {
            Set<Id> docIds = new Set<Id>();
            for (ContentVersion cv : newVersions) {
                if (cv.ContentDocumentId != null) {
                    docIds.add(cv.ContentDocumentId);
                }
            }

            if (docIds.isEmpty()) {
                isRunning = false;
                return;
            }

            Map<Id, Id> docToParentMap = new Map<Id, Id>();
           for (ContentDocumentLink cdl : [
    SELECT ContentDocumentId, LinkedEntityId
    FROM ContentDocumentLink
    WHERE ContentDocumentId IN :docIds
]) {
    
    if (cdl.LinkedEntityId.getSObjectType() == Account.SObjectType) {
        if (!docToParentMap.containsKey(cdl.ContentDocumentId)) {
            docToParentMap.put(cdl.ContentDocumentId, cdl.LinkedEntityId);
        }
    }
}


            if (docToParentMap.isEmpty()) {
                isRunning = false;
                return;
            }

            Map<Id, List<ContentVersion>> historyMap = new Map<Id, List<ContentVersion>>();
            for (ContentVersion cv : [
                SELECT Id, ContentDocumentId, VersionNumber, Title, VersionData, FileExtension, CreatedDate
                FROM ContentVersion
                WHERE ContentDocumentId IN :docIds
                ORDER BY CreatedDate DESC, Id DESC
            ]) {
                if (!historyMap.containsKey(cv.ContentDocumentId)) {
                    historyMap.put(cv.ContentDocumentId, new List<ContentVersion>());
                }
                historyMap.get(cv.ContentDocumentId).add(cv);
            }

            List<Note_History_Logs__c> logs = new List<Note_History_Logs__c>();

            for (ContentVersion curr : newVersions) {

                if (!docToParentMap.containsKey(curr.ContentDocumentId)) {
                    continue;
                }

                if (curr.FileExtension != 'snote') {
                    continue;
                }

                Id parentId = docToParentMap.get(curr.ContentDocumentId);

 if (!String.valueOf(parentId).startsWith('001')) {
        System.debug(' SKIPPED — Parent is not Account: ' + parentId);
        continue;
    }

                ContentVersion prev = findPreviousVersion(
                    curr,
                    historyMap.get(curr.ContentDocumentId)
                );

                List<Note_History_Logs__c> created = createLogs(curr, prev, parentId);
                logs.addAll(created);
            }

            if (!logs.isEmpty()) {
                Database.SaveResult[] results = Database.insert(logs, false);
            }

        } catch (Exception e) {
            System.debug('❌ EXCEPTION: ' + e.getMessage());
        } finally {
            isRunning = false;
        }
    }

    private static ContentVersion findPreviousVersion(
        ContentVersion curr,
        List<ContentVersion> history
    ) {
        if (history == null) return null;

        for (ContentVersion v : history) {
            if (v.Id != curr.Id) {
                return v;
            }
        }
        return null;
    }


    private static List<Note_History_Logs__c> createLogs(
        ContentVersion curr,
        ContentVersion prev,
        Id parentId
    ) {
        List<Note_History_Logs__c> logs = new List<Note_History_Logs__c>();

        String currBody = extractBody(curr.VersionData);

        if (prev == null) {
            logs.add(buildLog(curr.ContentDocumentId, parentId, 'Created', 'Title', '', curr.Title));

            if (String.isNotBlank(currBody)) {
                logs.add(buildLog(curr.ContentDocumentId, parentId, 'Created', 'Body', '', currBody));
            }
            return logs;
        }

        String prevBody = extractBody(prev.VersionData);

        if (curr.Title != prev.Title) {
            logs.add(buildLog(
                curr.ContentDocumentId,
                parentId,
                'Updated',
                'Title',
                prev.Title,
                curr.Title
            ));
        }

        if (currBody != prevBody) {
            logs.add(buildLog(
                curr.ContentDocumentId,
                parentId,
                'Updated',
                'Body',
                prevBody,
                currBody
            ));
        }

        return logs;
    }

    private static Note_History_Logs__c buildLog(
        Id noteId,
        Id accountId,
        String action,
        String field,
        String oldVal,
        String newVal
    ) {
        Note_History_Logs__c log = new Note_History_Logs__c();

        log.Parent_Record_Id__c = accountId;
        log.Note_Id__c = noteId;
        log.Action__c = action;
        log.Field_Name__c = field;
        log.Old_Value__c = (oldVal != null && oldVal.length() > MAX_FIELD_LEN) ? oldVal.left(MAX_FIELD_LEN) : oldVal;
        log.New_Value__c = (newVal != null && newVal.length() > MAX_FIELD_LEN) ? newVal.left(MAX_FIELD_LEN) : newVal;
        return log;
    }

    private static String extractBody(Blob data) {
        if (data == null) return '';
        try {
            String html = data.toString();
            html = html.replace('<br>', '\n')
                        .replace('<br/>', '\n')
                        .replace('</p>', '\n')
                        .replace('</div>', '\n');
            return html.stripHtmlTags().trim();
        } catch (Exception e) {
            return '';
        }
    }
}