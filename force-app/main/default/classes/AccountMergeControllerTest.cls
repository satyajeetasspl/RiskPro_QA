@IsTest
private class AccountMergeControllerTest {

    @TestSetup
    static void setupData() {
        Account mainAcc = new Account(
            Name = 'Main Test Account',
            vert__AMS360_Customer_Number__c = 'CUST-001'
        );
        insert mainAcc;

        Account dupAcc = new Account(
            Name = 'Main Test Duplicate',
            vert__AMS360_Customer_Number__c = 'CUST-002'
        );
        insert dupAcc;

        Contact c = new Contact(
            LastName = 'Test Contact',
            AccountId = dupAcc.Id
        );
        insert c;

        Opportunity o = new Opportunity(
            Name = 'Test Opp',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30),
            AccountId = dupAcc.Id
        );
        insert o;

        Case cs = new Case(
            Subject = 'Test Case',
            Status = 'New',
            Origin = 'Phone',
            AccountId = dupAcc.Id
        );
        insert cs;

        Note n = new Note(
            Title = 'Test Note',
            Body = 'Body',
            ParentId = dupAcc.Id
        );
        insert n;

        Task t = new Task(
            Subject = 'Test Task',
            WhatId = dupAcc.Id,
            Status = 'Not Started',
            Priority = 'Normal'
        );
        insert t;

        Event e = new Event(
            Subject = 'Test Event',
            WhatId = dupAcc.Id,
            StartDateTime = System.now().addDays(1),
            EndDateTime = System.now().addDays(1).addHours(1)
        );
        insert e;

        ContentVersion cv = new ContentVersion(
            Title = 'Test File',
            PathOnClient = 'test.pdf',
            VersionData = Blob.valueOf('Test')
        );
        insert cv;

        Id docId = [
            SELECT ContentDocumentId
            FROM ContentVersion
            WHERE Id = :cv.Id
            LIMIT 1
        ].ContentDocumentId;

        ContentDocumentLink cdl = new ContentDocumentLink(
            ContentDocumentId = docId,
            LinkedEntityId = dupAcc.Id,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );
        insert cdl;

        Driver__c d = new Driver__c(
            Account__c = dupAcc.Id
        );
        insert d;

        Vehicle__c v = new Vehicle__c(
            Account__c = dupAcc.Id
        );
        insert v;

        Properties__c prop = new Properties__c(
            Account__c = dupAcc.Id
        );
        insert prop;

        Auto_Incidents_Violations__c aiv = new Auto_Incidents_Violations__c(
            Account__c = dupAcc.Id
        );
        insert aiv;

        Home_Losses_Claims__c hl = new Home_Losses_Claims__c(
            Account__c = dupAcc.Id
        );
        insert hl;

        Policy_Information__c pi = new Policy_Information__c(
            Account__c = dupAcc.Id
        );
        insert pi;

        Prior_Insurance_Information__c pii = new Prior_Insurance_Information__c(
            Account__c = dupAcc.Id
        );
        insert pii;
    }

    @IsTest
    static void testGetDuplicates() {
        Account mainAcc = [
            SELECT Id
            FROM Account
            WHERE Name = 'Main Test Account'
            LIMIT 1
        ];

        Test.startTest();
        List<Account> dups = AccountMergeController.getDuplicates(mainAcc.Id);
        Test.stopTest();
    }

    @IsTest
    static void testMergeAccounts() {
        Account mainAcc = [
            SELECT Id
            FROM Account
            WHERE Name = 'Main Test Account'
            LIMIT 1
        ];

        Account dupAcc = [
            SELECT Id
            FROM Account
            WHERE Name = 'Main Test Duplicate'
            LIMIT 1
        ];

        Test.startTest();
        AccountMergeController.mergeAccounts(dupAcc.Id, mainAcc.Id);
        Test.stopTest();
    }
}