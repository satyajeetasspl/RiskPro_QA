@isTest
public class TaskManagerController_Test {

    // Utility to build a user record with a given profile id (not inserted)
    static User buildUserWithProfile(Id profileId, String nameSuffix) {
        String uniqueSuffix = String.valueOf(Math.abs(Crypto.getRandomInteger()));
        // ensure alias is <= 8 chars
        String alias = 'tst' + (uniqueSuffix.length() > 4 ? uniqueSuffix.substring(0,4) : uniqueSuffix);
        User u = new User(
            FirstName = 'Test',
            LastName = 'User' + nameSuffix,
            Email = 'test' + uniqueSuffix + nameSuffix + '@example.com',
            Username = 'test' + uniqueSuffix + nameSuffix + '@example.com',
            Alias = alias,
            TimeZoneSidKey = 'America/New_York',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = profileId
        );
        return u;
    }

    @testSetup
    static void setupData() {
        // ---------- Resolve admin user ----------
        User adminUser;
        try {
            List<User> admins = [SELECT Id FROM User WHERE Profile.Name = 'System Administrator' AND IsActive = true LIMIT 1];
            if (!admins.isEmpty()) {
                adminUser = admins[0];
            } else {
                Profile pAdmin;
                List<Profile> profs = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];
                if (!profs.isEmpty()) pAdmin = profs[0];
                else pAdmin = [SELECT Id FROM Profile LIMIT 1];

                User u = buildUserWithProfile(pAdmin.Id, 'Admin');
                Database.SaveResult[] res = Database.insert(new List<User>{u}, false);
                if (res != null && res.size() > 0 && res[0].isSuccess()) {
                    Id newUserId = (Id) res[0].getId();
                    adminUser = [SELECT Id FROM User WHERE Id = :newUserId LIMIT 1];
                } else {
                    List<User> anyUser = [SELECT Id FROM User WHERE IsActive = true LIMIT 1];
                    if (!anyUser.isEmpty()) adminUser = anyUser[0];
                }
            }
        } catch (Exception e) {
            try {
                List<User> anyUser = [SELECT Id FROM User WHERE IsActive = true LIMIT 1];
                if (!anyUser.isEmpty()) adminUser = anyUser[0];
                else adminUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
            } catch (Exception ex) {
                adminUser = new User(Id = UserInfo.getUserId());
            }
        }

        // ---------- Resolve standard user ----------
        User stdUser;
        try {
            List<User> stds = [SELECT Id FROM User WHERE Profile.Name = 'Standard User' AND IsActive = true LIMIT 1];
            if (!stds.isEmpty()) {
                stdUser = stds[0];
            } else {
                Profile pStd;
                List<Profile> profs2 = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
                if (!profs2.isEmpty()) pStd = profs2[0];
                else pStd = [SELECT Id FROM Profile LIMIT 1];

                User u2 = buildUserWithProfile(pStd.Id, 'Std');
                Database.SaveResult[] res2 = Database.insert(new List<User>{u2}, false);
                if (res2 != null && res2.size() > 0 && res2[0].isSuccess()) {
                    Id newStdId = (Id) res2[0].getId();
                    stdUser = [SELECT Id FROM User WHERE Id = :newStdId LIMIT 1];
                } else {
                    List<User> anyUser = [SELECT Id FROM User WHERE IsActive = true LIMIT 1];
                    if (!anyUser.isEmpty()) stdUser = anyUser[0];
                }
            }
        } catch (Exception e) {
            List<User> anyUser = [SELECT Id FROM User WHERE IsActive = true LIMIT 1];
            if (!anyUser.isEmpty()) stdUser = anyUser[0];
            else stdUser = new User(Id = UserInfo.getUserId());
        }

        if (adminUser == null) adminUser = new User(Id = UserInfo.getUserId());
        if (stdUser == null) stdUser = new User(Id = UserInfo.getUserId());

        // ---------- Create Account ----------
        Account acc = new Account(Name = 'Test Account');
        try {
            insert acc;
        } catch (Exception e) {
            Database.SaveResult[] accRes = Database.insert(new List<Account>{acc}, false);
            if (accRes != null && accRes.size() > 0 && accRes[0].isSuccess()) {
                acc.Id = (Id) accRes[0].getId();
            }
        }

        // ---------- Insert Cases using valid OwnerIds (partial insert to avoid throwing) ----------
        Id adminId = (adminUser != null && adminUser.Id != null) ? adminUser.Id : UserInfo.getUserId();
        Id stdId = (stdUser != null && stdUser.Id != null) ? stdUser.Id : UserInfo.getUserId();

        List<Case> casesToInsert = new List<Case>{
            new Case(Subject='Open Case 1', Status='Open', Category__c='Inbound', OwnerId=adminId, AccountId=acc.Id, Archive__c=false),
            new Case(Subject='Completed Case', Status='Completed', Category__c='Completed', OwnerId=stdId, AccountId=acc.Id, Archive__c=false),
            new Case(Subject='Category Case', Status='Open', Category__c='Non Payment', OwnerId=stdId, AccountId=acc.Id, Archive__c=false),
            new Case(Subject='To Be Closed', Status='Open', Category__c='Completed', OwnerId=adminId, AccountId=acc.Id, Archive__c=false),
            new Case(Subject='Junk Case 1', Status='Open', Category__c='Junk', OwnerId=adminId, AccountId=acc.Id, Archive__c=false)
        };

        Database.SaveResult[] caseResults = Database.insert(casesToInsert, false);
        // intentionally ignore per-row errors
    }

    // ---------- Tests (no assertions as requested) ----------

    @isTest
    static void testIsCurrentUserSysAdmin() {
        List<User> admins = [SELECT Id FROM User WHERE Profile.Name = 'System Administrator' LIMIT 1];
        if (!admins.isEmpty()) {
            System.runAs(admins[0]) {
                TaskManagerController.isCurrentUserSysAdmin();
            }
        } else {
            TaskManagerController.isCurrentUserSysAdmin();
        }

        List<User> stds = [SELECT Id FROM User WHERE Profile.Name = 'Standard User' LIMIT 1];
        if (!stds.isEmpty()) {
            System.runAs(stds[0]) {
                TaskManagerController.isCurrentUserSysAdmin();
            }
        } else {
            TaskManagerController.isCurrentUserSysAdmin();
        }
    }

    @isTest
    static void testGetUserList() {
        TaskManagerController.getUserList();
    }

    @isTest
    static void testGetInProgressCases() {
        User anyUser = [SELECT Id FROM User WHERE IsActive = true LIMIT 1];
        System.runAs(anyUser) {
            TaskManagerController.getInProgressCases(false);
            TaskManagerController.getInProgressCases(true);
        }
    }

    @isTest
    static void testGetCompletedCases() {
        User anyUser = [SELECT Id FROM User WHERE IsActive = true LIMIT 1];
        System.runAs(anyUser) {
            TaskManagerController.getCompletedCases(false);
            TaskManagerController.getCompletedCases(true);
        }
    }

    @isTest
    static void testGetCasesByCategory() {
        User anyUser = [SELECT Id FROM User WHERE IsActive = true LIMIT 1];
        System.runAs(anyUser) {
            TaskManagerController.getCasesByCategory('Non Payment', false);
            TaskManagerController.getCasesByCategory('Completed', false);
            TaskManagerController.getCasesByCategory('', false);
            TaskManagerController.getCasesByCategory('Non Payment', true);
        }
    }

    @isTest
    static void testMarkJunkCasesAsCompleted() {
        TaskManagerController.markJunkCasesAsCompleted();
    }

    @isTest
    static void testGetAccount() {
        TaskManagerController.getAccount('Test');
        TaskManagerController.getAccount('NoSuchAccountNameXYZ');
    }
}