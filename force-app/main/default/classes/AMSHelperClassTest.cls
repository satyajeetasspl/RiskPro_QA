@IsTest
public class AMSHelperClassTest {

    static Id testUserId;

    @testSetup
    static void setupData() {

        /* -------- Divisions -------- */
        insert new vert__AMS360_Division__c(Name = 'Mortgage Broker Partners');
        insert new vert__AMS360_Division__c(Name = 'HOUSE ACCOUNT');

        /* -------- Branches -------- */
        insert new vert__AMS360_Branch__c(Name = 'Lend-A-Loan');
        insert new vert__AMS360_Branch__c(Name = 'Rapid Home Lending');
        insert new vert__AMS360_Branch__c(Name = 'HOUSE ACCOUNT');

        /* -------- Department -------- */
        insert new vert__AMS360_Department__c(Name = 'Department 1');

        /* -------- Group -------- */
        insert new vert__AMS360_Group__c(Name = 'Group one');

        /* -------- User WITH Employee -------- */
        Profile p = [
            SELECT Id FROM Profile
            WHERE Name = 'Standard User'
            LIMIT 1
        ];

        User u = new User(
            FirstName = 'Test',
            LastName = 'User',
            Email = 'testuser@test.com',
            Username = 'ams.test.user@test.com',
            Alias = 'tuser',
            TimeZoneSidKey = 'Asia/Kolkata',
            LocaleSidKey = 'en_IN',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = p.Id
        );
        insert u;

        testUserId = u.Id;

        insert new vert__AMS360_Employee__c(
            Name = 'Test Employee',
            vert__AMS360_Assign_To__c = u.Id,
            vert__AMS360_Employee_Code__c = 'EMP001',
            vert__AMS360_Entity_ID__c = 'ENTITY001'
        );
    }

    /* ================= Partner + Lend-A-Loan ================= */
    @IsTest
    static void testPartnerLendALoan() {

        Test.startTest();
        AMSHelperClass.getAMSBusinesUnit(
            'Partner',
            'Lend-A-Loan Mumbai',
            testUserId
        );
        Test.stopTest();
    }

    /* ================= Partner + Rapid ================= */
    @IsTest
    static void testPartnerRapidHomeLending() {

        Test.startTest();
        AMSHelperClass.getAMSBusinesUnit(
            'Partner',
            'Rapid Home Lending Delhi',
            testUserId
        );
        Test.stopTest();
    }

    /* ================= Partner + No Match ================= */
    @IsTest
    static void testPartnerNoMatch() {

        Test.startTest();
        AMSHelperClass.getAMSBusinesUnit(
            'Partner',
            'Unknown Partner',
            testUserId
        );
        Test.stopTest();
    }

    /* ================= Non Partner ================= */
    @IsTest
    static void testNonPartnerLead() {

        Test.startTest();
        AMSHelperClass.getAMSBusinesUnit(
            'New',
            'Random Company',
            testUserId
        );
        Test.stopTest();
    }

    /* ================= Null Partner Name ================= */
    @IsTest
    static void testNullPartnerName() {

        Test.startTest();
        AMSHelperClass.getAMSBusinesUnit(
            'Partner',
            null,
            testUserId
        );
        Test.stopTest();
    }

    /* ================= OwnerId NULL ================= */
    @IsTest
    static void testNullOwnerId() {

        Test.startTest();
        AMSHelperClass.getAMSBusinesUnit(
            'Partner',
            'Lend-A-Loan',
            null
        );
        Test.stopTest();
    }

    /* ================= Employee Does NOT Exist ================= */
    @IsTest
    static void testEmployeeDoesNotExist() {

        Profile p = [
            SELECT Id FROM Profile
            WHERE Name = 'Standard User'
            LIMIT 1
        ];

        User u = new User(
            FirstName = 'No',
            LastName = 'Employee',
            Email = 'noemployee@test.com',
            Username = 'no.employee@test.com',
            Alias = 'noemp',
            TimeZoneSidKey = 'Asia/Kolkata',
            LocaleSidKey = 'en_IN',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = p.Id
        );
        insert u;

        Test.startTest();
        AMSHelperClass.getAMSBusinesUnit(
            'Partner',
            'Lend-A-Loan',
            u.Id
        );
        Test.stopTest();
    }

    /* ================= BLANK nameValue path in getIdByName ================= */
    @IsTest
    static void testBlankNameValuePath() {

        // We simulate blank lookup by removing required data
        // and forcing internal calls with blank strings indirectly

        Test.startTest();
        AMSHelperClass.getAMSBusinesUnit(
            'Partner',
            '',     // Blank partner
            testUserId
        );
        Test.stopTest();
    }
}