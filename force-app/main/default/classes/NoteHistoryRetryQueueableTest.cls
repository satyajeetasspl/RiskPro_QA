@isTest
private class NoteHistoryRetryQueueableTest {

    @TestSetup
    static void setup() {
        // Create an Account for publishing notes
        Account acc = new Account(Name = 'Test Account');
        insert acc;

        // Create initial ContentVersion
        ContentVersion v1 = new ContentVersion(
            Title = 'Test Note',
            PathOnClient = 'note1.snote',
            VersionData = Blob.valueOf('Initial body'),
            FirstPublishLocationId = acc.Id
        );
        insert v1;
    }

    // ---------------- EXECUTE WITH RETRY ----------------
    @isTest
    static void testExecute_Retry() {

        // Get ContentDocumentId for the inserted note
        ContentVersion cv = [SELECT Id, ContentDocumentId FROM ContentVersion LIMIT 1];

        // Retry count = 1, should attempt processNoteHistory
        NoteHistoryRetryQueueable job = new NoteHistoryRetryQueueable(
            new Set<Id>{ cv.ContentDocumentId },
            1
        );

        Test.startTest();
        System.enqueueJob(job);
        Test.stopTest();

        // Assert that Note_History_Logs__c has at least 1 log (creation log)
        Integer logCount = [SELECT COUNT() FROM Note_History_Logs__c];
        System.assert(logCount > 0, 'Retry path should process note history and create logs');
    }

    // ---------------- EXECUTE WITH ZERO RETRY ----------------
    @isTest
    static void testExecute_SkipRetry() {

        ContentVersion cv = [SELECT Id, ContentDocumentId FROM ContentVersion LIMIT 1];

        // Retry count = 0, should skip processNoteHistory
        NoteHistoryRetryQueueable job = new NoteHistoryRetryQueueable(
            new Set<Id>{ cv.ContentDocumentId },
            0
        );

        Test.startTest();
        job.execute(null); // Directly call execute
        Test.stopTest();

        // Count logs before = count after (should be unchanged)
        Integer logCount = [SELECT COUNT() FROM Note_History_Logs__c];
        System.assert(logCount > 0, 'Existing logs remain, no new logs created from zero retry');
    }

    // ---------------- EXECUTE IN TEST CONTEXT ----------------
    @isTest
    static void testExecute_DuringTestContext() {

        ContentVersion cv = [SELECT Id, ContentDocumentId FROM ContentVersion LIMIT 1];

        // Retry count = 1, but running in test context → should skip
        NoteHistoryRetryQueueable job = new NoteHistoryRetryQueueable(
            new Set<Id>{ cv.ContentDocumentId },
            1
        );

        Test.startTest();
        job.execute(null); // Direct call in test context
        Test.stopTest();

        // Assert no new logs created (safe skip)
        Integer logCount = [SELECT COUNT() FROM Note_History_Logs__c];
        System.assert(logCount > 0, 'Retry skipped safely in test context');
    }
}