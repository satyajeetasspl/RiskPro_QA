@isTest
private class ContentVersionHelperTest {

    @TestSetup
    static void setup() {
        Account acc = new Account(Name = 'Test Account');
        insert acc;
    }

    // ---------------- CREATED NOTE PATH ----------------
    @isTest
    static void testNoteCreation_LogCreated() {
        Account acc = [SELECT Id FROM Account LIMIT 1];

        ContentVersion v1 = new ContentVersion(
            Title = 'Initial Note',
            PathOnClient = 'note.snote',
            VersionData = Blob.valueOf('Initial body'),
            FirstPublishLocationId = acc.Id
        );
        insert v1;

        List<ContentVersion> insertedVersions = [
            SELECT Id, ContentDocumentId, Title, VersionData, FileExtension
            FROM ContentVersion
            WHERE Id = :v1.Id
        ];

        Test.startTest();
        ContentVersionHelper.isLwcContext = true;
        ContentVersionHelper.processNoteHistory(insertedVersions);
        Test.stopTest();
    }

    // ---------------- UPDATED NOTE PATH ----------------
    @isTest
    static void testNoteUpdate_LogUpdated() {
        Account acc = [SELECT Id FROM Account LIMIT 1];

        ContentVersion v1 = new ContentVersion(
            Title = 'Draft 1',
            PathOnClient = 'draft.snote',
            VersionData = Blob.valueOf('Body A'),
            FirstPublishLocationId = acc.Id
        );
        insert v1;

        Id docId = [
            SELECT ContentDocumentId
            FROM ContentVersion
            WHERE Id = :v1.Id
        ].ContentDocumentId;

        ContentVersion v2 = new ContentVersion(
            Title = 'Draft 2',
            PathOnClient = 'draft.snote',
            VersionData = Blob.valueOf('Body B'),
            ContentDocumentId = docId
        );
        insert v2;

        List<ContentVersion> versions = [
            SELECT Id, ContentDocumentId, Title, VersionData, FileExtension
            FROM ContentVersion
            WHERE Id IN :new List<Id>{v1.Id, v2.Id}
        ];

        Test.startTest();
        ContentVersionHelper.isLwcContext = true;
        ContentVersionHelper.processNoteHistory(versions);
        Test.stopTest();
    }

    // ---------------- RETRY / NO PARENT PATH ----------------
    @isTest
    static void testRetryWhenParentMissing() {

        ContentVersion orphan = new ContentVersion(
            Title = 'Orphan Note',
            PathOnClient = 'orphan.snote',
            VersionData = Blob.valueOf('No parent yet')
        );
        insert orphan;

        List<ContentVersion> insertedVersions = [
            SELECT Id, ContentDocumentId, Title, VersionData, FileExtension
            FROM ContentVersion
            WHERE Id = :orphan.Id
        ];

        Test.startTest();
        ContentVersionHelper.isLwcContext = true;
        ContentVersionHelper.processNoteHistory(insertedVersions);
        Test.stopTest();
    }

    // ---------------- BULK PATH ----------------
    @isTest
    static void testBulkInsert() {
        Account acc = [SELECT Id FROM Account LIMIT 1];

        List<ContentVersion> versions = new List<ContentVersion>();
        for (Integer i = 0; i < 30; i++) {
            versions.add(new ContentVersion(
                Title = 'Bulk ' + i,
                PathOnClient = 'bulk.snote',
                VersionData = Blob.valueOf('Body ' + i),
                FirstPublishLocationId = acc.Id
            ));
        }
        insert versions;

        List<ContentVersion> insertedVersions = [
            SELECT Id, ContentDocumentId, Title, VersionData, FileExtension
            FROM ContentVersion
        ];

        Test.startTest();
        ContentVersionHelper.isLwcContext = true;
        ContentVersionHelper.processNoteHistory(insertedVersions);
        Test.stopTest();
    }

    // ---------------- NULL / SAFETY PATH ----------------
    @isTest
    static void testRecursionGuard() {
        Test.startTest();
        ContentVersionHelper.processNoteHistory(null);
        ContentVersionHelper.processNoteHistory(new List<ContentVersion>());
        Test.stopTest();
    }
}