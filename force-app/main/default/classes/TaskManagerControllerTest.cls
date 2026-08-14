@isTest
private class TaskManagerControllerTest {
    
    static User createTestUser(String alias, String profileName, Boolean isSysAdmin) {
        Profile p = [SELECT Id FROM Profile WHERE Name = :profileName LIMIT 1];
        User u = new User(
            FirstName = 'Test',
            LastName = alias,
            Email = alias + '@example.com',
            Username = alias + '@example.com.' + DateTime.now().getTime(),
            Alias = alias.substring(0,3),
            TimeZoneSidKey = 'Asia/Dhaka',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = p.Id
        );
        insert u;
        return u;
    }

    static Case createCase(String category, String status, Id ownerId) {
        return new Case(
            Subject = 'Test Subject',
            Status = status,
            Category__c = category,
            OwnerId = ownerId,
            Archive__c = false
        );
    }

    @testSetup
    static void setupData() {
        // Create standard user
        User stdUser = createTestUser('stdUser', 'Standard User', false);

        // Create system admin user
        User adminUser = createTestUser('adminUser', 'System Administrator', true);

        // Insert test cases
        List<Case> cases = new List<Case>{
            createCase('Inbound', 'New', stdUser.Id),
            createCase('Non Payment', 'In Progress', stdUser.Id),
            createCase('Completed', 'Completed', stdUser.Id)
        };
        insert cases;
    }

    @isTest
    static void testGetCases_Completed_withMyTasks() {
        User u = [SELECT Id FROM User WHERE Alias = 'std' LIMIT 1];
        System.runAs(u) {
            List<Case> cases = TaskManagerController.getCompletedCases(true);
            System.assertNotEquals(0, cases.size(), 'Should return user-assigned completed cases');
        }
    }

    @isTest
    static void testGetCases_Completed_allTasks() {
        List<Case> cases = TaskManagerController.getCompletedCases(false);
        System.assertNotEquals(0, cases.size(), 'Should return all completed cases');
    }

    @isTest
    static void testGetCases_Inbound_withMyTasks() {
        User u = [SELECT Id FROM User WHERE Alias = 'std' LIMIT 1];
        System.runAs(u) {
            List<Case> cases = TaskManagerController.getCasesByCategory('Inbound', true);
            System.assertEquals(1, cases.size(), 'Should return user-assigned Inbound case');
        }
    }

    @isTest
    static void testGetCases_NonPayment_allTasks() {
        List<Case> cases = TaskManagerController.getCasesByCategory('Non Payment', false);
        System.assertEquals(1, cases.size(), 'Should return all Non Payment cases');
    }

    @isTest
    static void testGetUserList() {
        List<User> users = TaskManagerController.getUserList();
        System.assertNotEquals(0, users.size(), 'Should return active Salesforce users');
    }

    @isTest
    static void testSearchUsers() {
        List<User> result = TaskManagerController.searchUsers('Test');
        System.assertNotEquals(0, result.size(), 'Should return matching user(s)');
    }

    @isTest
    static void testIsCurrentUserSysAdmin_true() {
        User admin = [SELECT Id FROM User WHERE Alias = 'adm' LIMIT 1];
        System.runAs(admin) {
            Boolean isAdmin = TaskManagerController.isCurrentUserSysAdmin();
            System.assertEquals(true, isAdmin, 'Should return true for System Administrator');
        }
    }

    @isTest
    static void testIsCurrentUserSysAdmin_false() {
        User std = [SELECT Id FROM User WHERE Alias = 'std' LIMIT 1];
        System.runAs(std) {
            Boolean isAdmin = TaskManagerController.isCurrentUserSysAdmin();
            System.assertEquals(false, isAdmin, 'Should return false for non-admin user');
        }
    }
}