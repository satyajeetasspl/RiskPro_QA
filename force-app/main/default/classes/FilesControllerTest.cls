@IsTest
public class FilesControllerTest {

    @IsTest
    static void testGetFilesForRecord() {

        // Create a test record to link files to
        Account acc = new Account(Name = 'Test Account');
        insert acc;

        // Create a ContentVersion (this auto-creates ContentDocument)
        ContentVersion cv = new ContentVersion(
            Title = 'Test File',
            PathOnClient = 'TestFile.pdf',
            VersionData = Blob.valueOf('Test file content'),
            IsMajorVersion = true
        );
        insert cv;

        // Get ContentDocumentId
        cv = [
            SELECT ContentDocumentId
            FROM ContentVersion
            WHERE Id = :cv.Id
        ];

        // Link the document to the Account
        ContentDocumentLink cdl = new ContentDocumentLink(
            ContentDocumentId = cv.ContentDocumentId,
            LinkedEntityId = acc.Id,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );
        insert cdl;

        Test.startTest();
        FilesController.getFilesForRecord(acc.Id);
        FilesController.getFilesForRecord(null);
        Test.stopTest();
    }
}