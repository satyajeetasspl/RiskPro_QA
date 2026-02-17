@IsTest
public class AccountDashboardControllerTest {

    private static String getAccountLookupFieldOnPolicy() {
        Map<String, Schema.SObjectField> fields =
            Schema.SObjectType.Policy_Information__c.fields.getMap();

        for (String fieldName : fields.keySet()) {
            Schema.DescribeFieldResult fr = fields.get(fieldName).getDescribe();
            if (fr.getType() == Schema.DisplayType.REFERENCE) {
                for (Schema.SObjectType refType : fr.getReferenceTo()) {
                    if (refType.getDescribe().getName() == 'Account') {
                        return fieldName;
                    }
                }
            }
        }
        return null;
    }

    private static String getValidContentVersionTypeValue() {
        Map<String, Schema.SObjectField> cvFields = Schema.SObjectType.ContentVersion.fields.getMap();
        if (!cvFields.containsKey('Type__c')) return null;

        Schema.DescribeFieldResult d = cvFields.get('Type__c').getDescribe();
        if (!d.isUpdateable()) return null;

        if (d.getType() == Schema.DisplayType.Picklist) {
            for (Schema.PicklistEntry pe : d.getPicklistValues()) {
                if (pe.isActive()) return pe.getValue();
            }
            return null;
        }
        return 'TestType';
    }

    @TestSetup
    static void setupData() {
        Account acc = new Account(Name='Test Account');
        insert acc;

        insert new Contact(
            FirstName='Primary',
            LastName='Insured',
            AccountId=acc.Id,
            Insured_Role__c='First Insured',
            Phone='111',
            MobilePhone='222',
            Email='primary@test.com',
            MailingStreet='123 Street',
            MailingCity='City',
            MailingState='TX',
            MailingPostalCode='75001',
            MailingCountry='USA'
        );

        insert new Contact(
            FirstName='Secondary',
            LastName='Insured',
            AccountId=acc.Id,
            Insured_Role__c='Second Named Insured'
        );

        String lookupField = getAccountLookupFieldOnPolicy();
        if (String.isNotBlank(lookupField)) {
            Policy_Information__c policy = new Policy_Information__c(
                Policy__c='POL-001',
                Effective_Date__c=Date.today()
            );
            policy.put(lookupField, acc.Id);
            insert policy;
        }

        insert new Case(Subject='Test Case', Status='New', AccountId=acc.Id);

        insert new Task(
            Subject='Follow Up',
            Status='Not Started',
            WhatId=acc.Id,
            vert__Activity_Action_Name__c='Call'
        );

        insert new Event(
            Subject='Meeting',
            StartDateTime=System.now(),
            DurationInMinutes=30,
            WhatId=acc.Id,
            vert__Activity_Action_Name__c='Meeting'
        );

        ContentNote note = new ContentNote(
            Title='Setup Note',
            Content=Blob.valueOf('<p>Body</p>')
        );
        insert note;

        insert new ContentDocumentLink(
            ContentDocumentId=note.Id,
            LinkedEntityId=acc.Id,
            ShareType='V',
            Visibility='AllUsers'
        );

        ContentVersion cv = new ContentVersion(
            Title='Test File',
            PathOnClient='Test.pdf',
            VersionData=Blob.valueOf('File Data')
        );
        insert cv;

        cv = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id];

        insert new ContentDocumentLink(
            ContentDocumentId=cv.ContentDocumentId,
            LinkedEntityId=acc.Id,
            ShareType='V',
            Visibility='AllUsers'
        );
    }

    @IsTest
    static void testDashboardBranches() {
        Account acc = [SELECT Id FROM Account LIMIT 1];

        Test.startTest();
        try {
            AccountDashboardController.getDashboardDetails(acc.Id);
            AccountDashboardController.getDashboardDetails(null);
        } finally {
            Test.stopTest();
        }
    }

    @IsTest
    static void testDashboard_AMSBranch() {
        Account acc = new Account(
            Name='AMS Account',
            vert__AMS360_Customer_Number__c='123',
            vert__AMS360_First_Name__c='AMS',
            vert__AMS360_Last_Name__c='User',
            vert__Mobile_Phone__c='999',
            vert__Other_Phone__c='888',
            vert__AMS360_Company_Email_Address2__c='ams@test.com'
        );
        insert acc;

        insert new Contact(
            FirstName='AMS',
            LastName='User',
            AccountId=acc.Id,
            Insured_Role__c='First Insured'
        );

        Test.startTest();
        try {
            AccountDashboardController.getDashboardDetails(acc.Id);
        } finally {
            Test.stopTest();
        }
    }

    @IsTest
    static void testDashboard_FIBranch() {
        Account acc = new Account(
            Name='FI Account',
            First_Name_FI__c='John',
            Last_Name_FI__c='Smith'
        );
        insert acc;

        insert new Contact(
            FirstName='John',
            LastName='Smith',
            AccountId=acc.Id,
            Insured_Role__c='First Insured'
        );

        Test.startTest();
        try {
            AccountDashboardController.getDashboardDetails(acc.Id);
        } finally {
            Test.stopTest();
        }
    }

    @IsTest
    static void testSavePrimaryInsured_WithId() {
        Account acc = [SELECT Id FROM Account LIMIT 1];

        Contact existing = [
            SELECT Id
            FROM Contact
            WHERE Insured_Role__c='First Insured'
            LIMIT 1
        ];

        Contact c = new Contact(
            Id = existing.Id,
            FirstName='Updated',
            LastName='User',
            Phone='333',
            MobilePhone='444',
            Email='updated@test.com',
            MailingStreet='New Street',
            MailingCity='New City',
            MailingState='CA',
            MailingPostalCode='90001',
            MailingCountry='USA'
        );

        Test.startTest();
        try {
            AccountDashboardController.savePrimaryInsuredDetails(c, acc.Id);
        } finally {
            Test.stopTest();
        }
    }

    @IsTest
    static void testSavePrimaryInsured_NoId() {
        Account acc = [SELECT Id FROM Account LIMIT 1];

        Contact newContact = new Contact(
            FirstName='NoId',
            LastName='User',
            Phone='111',
            MobilePhone='222',
            Email='test@test.com',
            MailingStreet='123 Street',
            MailingCity='City',
            MailingState='TX',
            MailingPostalCode='75001',
            MailingCountry='USA'
        );

        Test.startTest();
        try {
            AccountDashboardController.savePrimaryInsuredDetails(newContact, acc.Id);
        } finally {
            Test.stopTest();
        }
    }

    @IsTest
    static void testSavePrimary_Error() {
        Test.startTest();
        try {
            try {
                AccountDashboardController.savePrimaryInsuredDetails(null, null);
                System.assert(false, 'Expected AuraHandledException');
            } catch (AuraHandledException e) {
                // expected
            }
        } finally {
            Test.stopTest();
        }
    }

    @IsTest
    static void testUpdateFileDetails_AllBranches() {
        Account acc = [SELECT Id FROM Account LIMIT 1];

        ContentVersion cv = new ContentVersion(
            Title='CoverageFile',
            PathOnClient='CoverageFile.pdf',
            VersionData=Blob.valueOf('Test Data')
        );
        insert cv;

        cv = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id=:cv.Id];

        insert new ContentDocumentLink(
            ContentDocumentId=cv.ContentDocumentId,
            LinkedEntityId=acc.Id,
            ShareType='V',
            Visibility='AllUsers'
        );

        String validType = getValidContentVersionTypeValue();

        Test.startTest();
        try {
            AccountDashboardController.updateFileDetails(
                new List<Id>{cv.ContentDocumentId},
                'Updated Description',
                null
            );

            if (validType != null) {
                AccountDashboardController.updateFileDetails(
                    new List<Id>{cv.ContentDocumentId},
                    null,
                    validType
                );
            }

            AccountDashboardController.updateFileDetails(new List<Id>(), 'Desc', 'Type');
            AccountDashboardController.updateFileDetails(null, 'Desc', 'Type');
        } finally {
            Test.stopTest();
        }
    }

    @IsTest
    static void testNoteLoggingAndDebounce() {
        Account acc = [SELECT Id FROM Account LIMIT 1];

        Test.startTest();
        try {
            AccountDashboardController.createContentNote(acc.Id, '', 'Body 1');

            Id noteId = [
                SELECT ContentDocumentId
                FROM ContentDocumentLink
                WHERE LinkedEntityId = :acc.Id
                AND ContentDocument.FileType = 'SNOTE'
                LIMIT 1
            ].ContentDocumentId;

            AccountDashboardController.updateContentNote(noteId, 'Title 2', 'Body 2', acc.Id);
            AccountDashboardController.updateContentNote(noteId, 'Title 3', 'Body 3', acc.Id);
        } finally {
            Test.stopTest();
        }
    }

    @IsTest
    static void testQueryMethods() {
        Account acc = [SELECT Id FROM Account LIMIT 1];

        Test.startTest();
        try {
            AccountDashboardController.getPolicies(acc.Id);
            AccountDashboardController.getAmsPolicyMap(acc.Id);
            AccountDashboardController.getCases(acc.Id);
            AccountDashboardController.getNotes(acc.Id);
            AccountDashboardController.getFiles(acc.Id);
            AccountDashboardController.getTasks(acc.Id);
            AccountDashboardController.getEvents(acc.Id);
            AccountDashboardController.getEmails(acc.Id);

            AccountDashboardController.getAmsPoliciesByAccount(acc.Id);

            AccountDashboardController.getPolicies(null);
            AccountDashboardController.getCases(null);
            AccountDashboardController.getNotes(null);
            AccountDashboardController.getFiles(null);
            AccountDashboardController.getTasks(null);
            AccountDashboardController.getEvents(null);
            AccountDashboardController.getEmails(null);
        } finally {
            Test.stopTest();
        }
    }

    @IsTest
    static void testCreatePolicy() {
        Account acc = [SELECT Id FROM Account LIMIT 1];

        Policy_Information__c p = new Policy_Information__c(Policy__c='NEW-POL');
        String lookupField = getAccountLookupFieldOnPolicy();
        if (String.isNotBlank(lookupField)) {
            p.put(lookupField, acc.Id);
        }

        Test.startTest();
        try {
            AccountDashboardController.createPolicy(p);
        } finally {
            Test.stopTest();
        }
    }

    @IsTest
    static void testCreatePolicy_NullError() {
        Test.startTest();
        try {
            try {
                AccountDashboardController.createPolicy(null);
                System.assert(false, 'Expected AuraHandledException');
            } catch (AuraHandledException e) {
                // expected
            }
        } finally {
            Test.stopTest();
        }
    }

    @IsTest
    static void testSaveAccountAndContacts() {
        Account acc = [SELECT Id FROM Account LIMIT 1];

        Test.startTest();
        try {
            AccountDashboardController.saveAccountDetails(
                new Account(Id=acc.Id, Name='Updated Name From Test')
            );

            AccountDashboardController.saveContactDetails(
                new Contact(FirstName='P', LastName='L', AccountId=acc.Id),
                new Contact(FirstName='S', LastName='L', AccountId=acc.Id)
            );

            AccountDashboardController.saveContactDetails(null, null);
        } finally {
            Test.stopTest();
        }
    }
}