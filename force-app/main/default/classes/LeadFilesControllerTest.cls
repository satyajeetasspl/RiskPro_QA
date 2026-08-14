@IsTest
public class LeadFilesControllerTest {

    @IsTest
    static void testGetFilesForLead_withFile() {
        // Create Lead
        Lead l = new Lead(
            LastName = 'Test Lead',
            Company = 'Test Company'
        );
        insert l;

        // Create ContentVersion (file upload)
        ContentVersion cv = new ContentVersion(
            Title = 'Test File',
            PathOnClient = 'TestFile.pdf',
            VersionData = Blob.valueOf('Test content')
        );
        insert cv;

        // Get ContentDocumentId
        ContentDocument cd = [
            SELECT Id
            FROM ContentDocument
            WHERE Id IN (
                SELECT ContentDocumentId
                FROM ContentVersion
                WHERE Id = :cv.Id
            )
            LIMIT 1
        ];

        // Link file to Lead
        ContentDocumentLink cdl = new ContentDocumentLink(
            LinkedEntityId = l.Id,
            ContentDocumentId = cd.Id,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );
        insert cdl;

        Test.startTest();
        List<ContentDocumentLink> results =
            LeadFilesController.getFilesForLead(l.Id);
        Test.stopTest();
    }

    @IsTest
    static void testGetFilesForLead_noFiles() {
        Lead l = new Lead(
            LastName = 'No File Lead',
            Company = 'Test Company'
        );
        insert l;

        Test.startTest();
        List<ContentDocumentLink> results =
            LeadFilesController.getFilesForLead(l.Id);
        Test.stopTest();
    }

    @IsTest
    static void testGetFilesForLead_nullId() {
        Test.startTest();
        List<ContentDocumentLink> results =
            LeadFilesController.getFilesForLead(null);
        Test.stopTest();
    }
}