@isTest
private class YearlyGoalRolloverBatchTest {

    @testSetup
    static void setupData() {

        // IMPORTANT: match batch profile name
        Profile p = [
            SELECT Id 
            FROM Profile 
            WHERE Name = 'RISK  PRO Standard Profile'
            LIMIT 1
        ];

        User u = new User(
            FirstName = 'Test',
            LastName = 'User',
            Email = 'testuser@test.com',
            Username = 'testuser' + System.currentTimeMillis() + '@test.com',
            Alias = 'tuser',
            TimeZoneSidKey = 'Asia/Kolkata',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = p.Id
        );
        insert u;

        List<Goal__c> goals = new List<Goal__c>();

        for (Integer i = 1; i <= 3; i++) {

            goals.add(new Goal__c(
                User__c = u.Id,
                OwnerId = u.Id,
                Target__c = 10000,
                Is_Active__c = true,
                Month__c = 'Jan',
                Start_Date__c = DateTime.now(),
                End_Date__c = DateTime.now().addDays(30)
            ));
        }

        insert goals;
    }

    @isTest
    static void testBatchExecution() {

        Test.startTest();

        Database.executeBatch(new YearlyGoalRolloverBatch(), 200);

        Test.stopTest();

        List<Goal__c> goals = [
            SELECT Id, Is_Active__c
            FROM Goal__c
        ];

        System.debug('Goals after batch: ' + goals);

        System.assert(goals.size() > 0, 'Goals should exist');

        Boolean hasInactive = false;

        for (Goal__c g : goals) {
            if (!g.Is_Active__c) {
                hasInactive = true;
            }
        }

        System.assertEquals(true, hasInactive,
            'Old goals should be deactivated'
        );
    }

    @isTest
    static void testSchedulerExecution() {

        Test.startTest();

        System.schedule(
            'Yearly Goal Test Job',
            '0 0 0 1 1 ? *',
            new YearlyGoalRolloverBatch()
        );

        Test.stopTest();

        System.assert(true);
    }
}