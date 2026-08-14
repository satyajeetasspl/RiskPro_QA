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
        insert new vert__AMS360_Branch__c(Name = 'Rapid Home Loans');
        insert new vert__AMS360_Branch__c(Name = 'HOUSE ACCOUNT');

        /* -------- Department -------- */
        insert new vert__AMS360_Department__c(Name = 'Department one');

        /* -------- Group -------- */
        insert new vert__AMS360_Group__c(Name = 'Group one');

        /* -------- User -------- */
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

        /* -------- Employee (MATCHES ownerId) -------- */
        insert new vert__AMS360_Employee__c(
            Name = 'Test Employee',
            vert__AMS360_Assign_To__c = u.Id,
            vert__AMS360_Employee_Code__c = 'EMP001',
            vert__AMS360_Entity_ID__c = 'ENTITY001'
        );
    }

    /* ================= Partner + Matching ================= */
    @IsTest
    static void testPartnerMatchingBranch() {

        User u = [
            SELECT Id FROM User
            WHERE Username = 'ams.test.user@test.com'
            LIMIT 1
        ];

        Test.startTest();
        AMSHelperClass.getAMSBusinesUnit(
            'Partner',
            'Lend-A-Loan Mumbai',
            u.Id
        );
        Test.stopTest();
    }

    /* ================= Partner + No Match ================= */
    @IsTest
    static void testPartnerNoBranchMatch() {

        User u = [
            SELECT Id FROM User
            WHERE Username = 'ams.test.user@test.com'
            LIMIT 1
        ];

        Test.startTest();
        AMSHelperClass.getAMSBusinesUnit(
            'Partner',
            'Unknown Partner',
            u.Id
        );
        Test.stopTest();
    }

    /* ================= Non Partner (FIXED) ================= */
    @IsTest
    static void testNonPartnerLead() {

        User u = [
            SELECT Id FROM User
            WHERE Username = 'ams.test.user@test.com'
            LIMIT 1
        ];

        Test.startTest();
        AMSHelperClass.getAMSBusinesUnit(
            'New',
            'Random Company',
            u.Id
        );
        Test.stopTest();
    }

    /* ================= Null Partner ================= */
    @IsTest
    static void testNullPartnerName() {

        User u = [
            SELECT Id FROM User
            WHERE Username = 'ams.test.user@test.com'
            LIMIT 1
        ];

        Test.startTest();
        AMSHelperClass.getAMSBusinesUnit(
            'Partner',
            null,
            u.Id
        );
        Test.stopTest();
    }
}