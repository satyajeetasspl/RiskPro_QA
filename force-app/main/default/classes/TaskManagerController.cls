public with sharing class TaskManagerController {

    public static string webEmail='williambakow@myriskpros.com';
    public static String webLeadEmail='leads@myriskpros.com';
    /* -------------------------------------------------
       SYSTEM ADMIN CHECK
       ------------------------------------------------- */
    @AuraEnabled(cacheable=true)
    public static Boolean isCurrentUserSysAdmin() {
        User u = [
            SELECT Profile.Name 
            FROM User 
            WHERE Id = :UserInfo.getUserId() 
            LIMIT 1
        ];
        return u.Profile.Name == 'System Administrator';
    }

    /* -------------------------------------------------
       USER LIST (CSR Lookup)
       ------------------------------------------------- */
    @AuraEnabled(cacheable=true)
    public static List<User> getUserList() {
        return [
            SELECT Id, Name
            FROM User
            WHERE IsActive = true
            ORDER BY Name
        ];
    }

    /* -------------------------------------------------
       IN-PROGRESS TASKS (All except Completed/Junk)
       ------------------------------------------------- */
    @AuraEnabled(cacheable=true)
    public static List<Case> getInProgressCases(Boolean onlyMyTasks) {
        Id userId = UserInfo.getUserId();

        String query =
            'SELECT Id, Subject, Status, Category__c,' +
            ' OwnerId, Owner.Name,' +
            ' CreatedDate, CreatedBy.Name,' +
            ' AccountId, Account.Name, Account.Type' +
            ' FROM Case' +
            ' WHERE Status NOT IN (\'Completed\', \'Junk\')' +
            ' AND SuppliedEmail NOT IN (\'' + webEmail + '\', \'' + webLeadEmail + '\')' +
            ' AND Archive__c = false';

        if (onlyMyTasks) {
            query += ' AND OwnerId = \'' + userId + '\'';
        }

        query += ' ORDER BY CreatedDate DESC';

        return Database.query(query);
    }

    /* -------------------------------------------------
       COMPLETED TASKS (Completed + Junk)
       ------------------------------------------------- */
    @AuraEnabled(cacheable=true)
    public static List<Case> getCompletedCases(Boolean onlyMyTasks) {
        Id userId = UserInfo.getUserId();

        String query =
            'SELECT Id, Subject, Status, Category__c,' +
            ' OwnerId, Owner.Name,' +
            ' CreatedDate, CreatedBy.Name,' +
            ' AccountId, Account.Name, Account.Type' +
            ' FROM Case' +
            ' WHERE Archive__c = false' +
            ' AND SuppliedEmail NOT IN (\'' + webEmail + '\', \'' + webLeadEmail + '\')' +
            ' AND (Status IN (\'Completed\', \'Junk\') OR Category__c = \'Completed\')';

        if (onlyMyTasks) {
            query += ' AND OwnerId = \'' + userId + '\'';
        }

        query += ' ORDER BY CreatedDate DESC';

        return Database.query(query);
    }

    /* -------------------------------------------------
       CATEGORY SPECIFIC (Inbound / Non Payment)
       Exclude Completed + Junk + Closed
       ------------------------------------------------- */
    @AuraEnabled(cacheable=true)
    public static List<Case> getCasesByCategory(String category, Boolean onlyMyTasks) {
        if (String.isBlank(category)) {
            return new List<Case>();
        }

        Id userId = UserInfo.getUserId();
        String safeCat = String.escapeSingleQuotes(category);
        

        String query =
            'SELECT Id, Subject, Status, Category__c,' +
            ' OwnerId, Owner.Name,' +
            ' CreatedDate, CreatedBy.Name,' +
            ' AccountId, Account.Name, Account.Type' +
            ' FROM Case' +
            ' WHERE Archive__c = false' +
            ' AND SuppliedEmail NOT IN (\'' + webEmail + '\', \'' + webLeadEmail + '\')' +
            ' AND Category__c = \'' + safeCat + '\'' +
            ' AND Status NOT IN (\'Completed\', \'Closed\', \'Junk\')';

        if (onlyMyTasks) {
            query += ' AND OwnerId = \'' + userId + '\'';
        }

        query += ' ORDER BY CreatedDate DESC';

        return Database.query(query);
    }

    /* -------------------------------------------------
       BULK MARK JUNK → COMPLETED (manual button)
       ------------------------------------------------- */
    @AuraEnabled
    public static void markJunkCasesAsCompleted() {
        List<Case> junkCases = [
            SELECT Id
            FROM Case
            WHERE Category__c = 'Junk'
            AND Status != 'Completed'
        ];

        for (Case c : junkCases) {
            c.Status = 'Completed';
            c.Category__c = 'Completed';
        }

        if (!junkCases.isEmpty()) {
            update junkCases;
        }
    }

    /* -------------------------------------------------
       ACCOUNT SEARCH
       ------------------------------------------------- */
    @AuraEnabled(cacheable=true)
    public static List<Account> getAccount(String name) {
        String searchKey = (name == null) ? '' : name.trim();
        String query =
            'SELECT Id, Name FROM Account ' +
            'WHERE Name LIKE \'%' + String.escapeSingleQuotes(searchKey) + '%\' ' +
            'ORDER BY Name LIMIT 50';
        return Database.query(query);
    }

}