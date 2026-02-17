@isTest
private class ContentVersionTriggerTest {

    @isTest
    static void testInsertAndUpdateContentVersion() {
        // Create a test ContentVersion (insert fires after insert trigger)
        ContentVersion cv = new ContentVersion(
            Title = 'Test File',
            PathOnClient = 'TestFile.txt',
            VersionData = Blob.valueOf('Test content')
        );
        insert cv;

        // Query the inserted record to get ContentDocumentId
        ContentVersion insertedCv = [
            SELECT Id, Title
            FROM ContentVersion
            WHERE Id = :cv.Id
            LIMIT 1
        ];

        // Update the record (fires after update trigger)
        insertedCv.Title = 'Updated Test File';
        update insertedCv;
    }
}