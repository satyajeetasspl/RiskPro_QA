public class NoteHistoryRetryQueueable implements Queueable {

    private Set<Id> docIds;
    private Integer retryCount;

    public NoteHistoryRetryQueueable(Set<Id> docIds, Integer retryCount) {
        this.docIds = docIds;
        this.retryCount = retryCount != null ? retryCount : 0;
    }

    public void execute(QueueableContext context) {

        // Re-query latest versions
        List<ContentVersion> versions = [
            SELECT Id, ContentDocumentId, Title, VersionData
            FROM ContentVersion
            WHERE ContentDocumentId IN :docIds
            AND IsLatest = true
        ];

        // If you don't need the helper anymore, you can just do your logic here
        // or leave it blank if the Queueable is being retired.
        if (retryCount > 0 && !Test.isRunningTest()) {
            // TODO: Add whatever new logic you want to happen here
            System.debug('Retrying for versions: ' + versions);
        } else {
            System.debug('Skipping retry for DocIds: ' + docIds);
        }
    }
}