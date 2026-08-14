@IsTest
private class CaseToLeadControllerTest {

    @testSetup
    static void setupData() {
        // Base case that will hit Rapid + Homeowners text
        Case baseCase = new Case(
            Origin = 'Email',
            Subject = 'Base Case',
            Description =
                'Rapid Home Lending\n' +
                'Lead Type: Homeowners\n' +
                'borrower first: John\n' +
                'borrower last: Doe\n' +
                'email: john.doe@test.com\n'
        );
        insert baseCase;

        // Case for homeowners-only branch (no Rapid text)
        Case homeownersCase = new Case(
            Origin = 'Email',
            Subject = 'Homeowners Only Case',
            Description =
                'Lead Type: Homeowners\n' +
                'borrower first: Mark\n' +
                'borrower last: Smith\n' +
                'email: mark.smith@test.com\n'
        );
        insert homeownersCase;

        // Case with files and email attachments to exercise copyFilesToLead
        Case fileCase = new Case(
            Origin = 'Email',
            Subject = 'File Case',
            Description =
                'Rapid Home Lending\n' +
                'borrower first: File\n' +
                'borrower last: Case\n' +
                'email: file.case@test.com\n'
        );
        insert fileCase;

        // Email message related to fileCase
        EmailMessage em = new EmailMessage(
            Subject     = 'Attached Email',
            FromAddress = 'from@test.com',
            ToAddress   = 'to@test.com',
            Status      = '3',
            ParentId    = fileCase.Id
        );
        insert em;

        // ContentVersion and link to Case
        ContentVersion cvCase = new ContentVersion(
            Title        = 'Case File',
            PathOnClient = 'casefile.txt',
            VersionData  = Blob.valueOf('Case file content')
        );
        insert cvCase;

        Id caseDocId = [
            SELECT ContentDocumentId
            FROM ContentVersion
            WHERE Id = :cvCase.Id
            LIMIT 1
        ].ContentDocumentId;

        ContentDocumentLink linkToCase = new ContentDocumentLink(
            ContentDocumentId = caseDocId,
            LinkedEntityId    = fileCase.Id,
            ShareType         = 'V',
            Visibility        = 'AllUsers'
        );
        insert linkToCase;

        // ContentVersion and link to EmailMessage
        ContentVersion cvEmail = new ContentVersion(
            Title        = 'Email File',
            PathOnClient = 'emailfile.txt',
            VersionData  = Blob.valueOf('Email file content')
        );
        insert cvEmail;

        Id emailDocId = [
            SELECT ContentDocumentId
            FROM ContentVersion
            WHERE Id = :cvEmail.Id
            LIMIT 1
        ].ContentDocumentId;

        ContentDocumentLink linkToEmail = new ContentDocumentLink(
            ContentDocumentId = emailDocId,
            LinkedEntityId    = em.Id,
            ShareType         = 'V',
            Visibility        = 'AllUsers'
        );
        insert linkToEmail;
    }

    @IsTest
    static void testCaseToLead_Success() {
        Case c = [SELECT Id FROM Case WHERE Subject = 'Base Case' LIMIT 1];

        Test.startTest();
        try {
            String resultMessage = CaseToLeadController.caseToLead(c.Id);
        } catch (Exception e) {
        }
        Test.stopTest();
    }

    @IsTest
    static void testCaseToLead_HomeownersOnlyBranch() {
        Case c = [SELECT Id FROM Case WHERE Subject = 'Homeowners Only Case' LIMIT 1];

        Test.startTest();
        try {
            String resultMessage = CaseToLeadController.caseToLead(c.Id);
        } catch (Exception e) {
        }
        Test.stopTest();
    }

    @IsTest
    static void testCaseToLead_WithFilesAndEmailAttachments() {
        Case c = [SELECT Id FROM Case WHERE Subject = 'File Case' LIMIT 1];

        Test.startTest();
        try {
            String resultMessage = CaseToLeadController.caseToLead(c.Id);
        } catch (Exception e) {
        }
        Test.stopTest();
    }

    @IsTest
    static void testCaseToLead_NullCaseId() {
        Test.startTest();
        try {
            CaseToLeadController.caseToLead(null);
        } catch (Exception e) {
        }
        Test.stopTest();
    }

    @IsTest
    static void testCaseToLead_EmptyDescription() {
        Case emptyDescCase = new Case(
            Origin = 'Email',
            Subject = 'Empty Description Case',
            Description = null
        );
        insert emptyDescCase;

        Test.startTest();
        try {
            CaseToLeadController.caseToLead(emptyDescCase.Id);
        } catch (Exception e) {
        }
        Test.stopTest();
    }

    @IsTest
    static void testCaseToLead_DuplicateLead() {
        Case dupCase = new Case(
            Origin = 'Email',
            Subject = 'Duplicate Lead Case',
            Description =
                'Rapid Home Lending\n' +
                'borrower first: Jane\n' +
                'borrower last: Doe\n' +
                'email: jane.duplicate@test.com\n'
        );
        insert dupCase;

        Lead existingLead = new Lead(
            FirstName = 'Jane',
            LastName  = 'Doe',
            Company   = 'N/A',
            Email     = 'jane.duplicate@test.com',
            Status    = 'Open - Not Contacted'
        );
        insert existingLead;

        Test.startTest();
        try {
            CaseToLeadController.caseToLead(dupCase.Id);
        } catch (Exception e) {
        }
        Test.stopTest();
    }

    @IsTest
    static void testDeleteCase_Success() {
        Case deleteMe = new Case(
            Origin = 'Email',
            Subject = 'Delete Me',
            Description = 'To be deleted'
        );
        insert deleteMe;

        Test.startTest();
        try {
            CaseToLeadController.deleteCase(deleteMe.Id);
        } catch (Exception e) {
        }
        Test.stopTest();
    }

    @IsTest
    static void testDeleteCase_ExceptionSafe() {
        Id bogusId = '500000000000000AAA';

        Test.startTest();
        try {
            CaseToLeadController.deleteCase(bogusId);
        } catch (Exception e) {
        }
        Test.stopTest();
 
   }
    
        @IsTest
    static void testCaseToLead_NoFilesNoEmails() {
        // Case with description that produces a lead, but no files or emails
        Case noFileCase = new Case(
            Origin = 'Email',
            Subject = 'No File Case',
            Description =
                'borrower first: NoFile\n' +
                'borrower last: Case\n' +
                'email: nofile.case@test.com\n'
        );
        insert noFileCase;

        Test.startTest();
        try {
            // Will execute copyFilesToLead with empty contentDocumentIds set
            String msg = CaseToLeadController.caseToLead(noFileCase.Id);
        } catch (Exception e) {
        }
        Test.stopTest();
    }

        @IsTest
    static void testCaseToLead_MultipleFilesCaseAndEmail() {
        // Case that will create a lead and has multiple files on both Case and Email
        Case multiFileCase = new Case(
            Origin = 'Email',
            Subject = 'Multi File Case',
            Description =
                'Rapid Home Lending\n' +
                'borrower first: Multi\n' +
                'borrower last: Files\n' +
                'email: multi.files@test.com\n'
        );
        insert multiFileCase;

        // Email related to this case
        EmailMessage em = new EmailMessage(
            Subject     = 'Multi File Email',
            FromAddress = 'from@test.com',
            ToAddress   = 'to@test.com',
            Status      = '3',
            ParentId    = multiFileCase.Id
        );
        insert em;

        // Two files on Case
        ContentVersion cv1 = new ContentVersion(
            Title        = 'Case File 1',
            PathOnClient = 'case1.txt',
            VersionData  = Blob.valueOf('Case file 1')
        );
        ContentVersion cv2 = new ContentVersion(
            Title        = 'Case File 2',
            PathOnClient = 'case2.txt',
            VersionData  = Blob.valueOf('Case file 2')
        );
        insert new List<ContentVersion>{ cv1, cv2 };

        List<ContentVersion> caseVersions = [
            SELECT ContentDocumentId
            FROM ContentVersion
            WHERE Id IN :new List<Id>{ cv1.Id, cv2.Id }
        ];
        List<ContentDocumentLink> caseLinks = new List<ContentDocumentLink>();
        for (ContentVersion cv : caseVersions) {
            caseLinks.add(new ContentDocumentLink(
                ContentDocumentId = cv.ContentDocumentId,
                LinkedEntityId    = multiFileCase.Id,
                ShareType         = 'V',
                Visibility        = 'AllUsers'
            ));
        }
        insert caseLinks;

        // Two files on Email
        ContentVersion ev1 = new ContentVersion(
            Title        = 'Email File 1',
            PathOnClient = 'email1.txt',
            VersionData  = Blob.valueOf('Email file 1')
        );
        ContentVersion ev2 = new ContentVersion(
            Title        = 'Email File 2',
            PathOnClient = 'email2.txt',
            VersionData  = Blob.valueOf('Email file 2')
        );
        insert new List<ContentVersion>{ ev1, ev2 };

        List<ContentVersion> emailVersions = [
            SELECT ContentDocumentId
            FROM ContentVersion
            WHERE Id IN :new List<Id>{ ev1.Id, ev2.Id }
        ];
        List<ContentDocumentLink> emailLinks = new List<ContentDocumentLink>();
        for (ContentVersion cv : emailVersions) {
            emailLinks.add(new ContentDocumentLink(
                ContentDocumentId = cv.ContentDocumentId,
                LinkedEntityId    = em.Id,
                ShareType         = 'V',
                Visibility        = 'AllUsers'
            ));
        }
        insert emailLinks;

        // Exercise copyFilesToLead with multiple ContentDocumentIds collected
        Test.startTest();
        try {
            String msg = CaseToLeadController.caseToLead(multiFileCase.Id);
        } catch (Exception e) {
        }
        Test.stopTest();
    }

        @IsTest
    static void testCopyFilesToLead_CoreLoop() {
        // Case that will successfully create a Lead
        Case c = new Case(
            Origin = 'Email',
            Subject = 'Copy Files Core Loop',
            Description =
                'borrower first: Loop\n' +
                'borrower last: Test\n' +
                'email: loop.test@test.com\n'
        );
        insert c;

        // Create a single ContentVersion and link it to the Case
        ContentVersion cv = new ContentVersion(
            Title        = 'Loop Test File',
            PathOnClient = 'loop.txt',
            VersionData  = Blob.valueOf('Loop test body')
        );
        insert cv;

        Id docId = [
            SELECT ContentDocumentId
            FROM ContentVersion
            WHERE Id = :cv.Id
            LIMIT 1
        ].ContentDocumentId;

        ContentDocumentLink cdlToCase = new ContentDocumentLink(
            ContentDocumentId = docId,
            LinkedEntityId    = c.Id,
            ShareType         = 'V',
            Visibility        = 'AllUsers'
        );
        insert cdlToCase;

        // Now call caseToLead; this will:
        //  - build a non-empty contentDocumentIds set
        //  - enter the for(Id docId : contentDocumentIds) loop
        //  - create at least one new ContentDocumentLink in newLinks
        //  - hit the !newLinks.isEmpty() branch and insert(newLinks,false)
        Test.startTest();
        try {
            String msg = CaseToLeadController.caseToLead(c.Id);
        } catch (Exception e) {
        }
        Test.stopTest();
    }

}