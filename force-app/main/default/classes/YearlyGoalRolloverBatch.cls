global without sharing class YearlyGoalRolloverBatch 
implements Database.Batchable<SObject>, Schedulable {

    private static final Decimal TARGET_AMOUNT = 50000;

    private static final Map<Integer, String> MONTH_MAP = new Map<Integer, String>{
        1 => 'January', 2 => 'February', 3 => 'March', 4 => 'April',
        5 => 'May', 6 => 'June', 7 => 'July', 8 => 'August',
        9 => 'September', 10 => 'October', 11 => 'November', 12 => 'December'
    };

    global Database.QueryLocator start(Database.BatchableContext bc) {

        Id profileId = [
            SELECT Id 
            FROM Profile 
            WHERE Name = 'RISK  PRO Standard Profile'
            LIMIT 1
        ].Id;

        return Database.getQueryLocator([
            SELECT Id
            FROM User
            WHERE IsActive = true
            AND ProfileId = :profileId
        ]);
    }

    global void execute(Database.BatchableContext bc, List<User> scope) {

        if (scope.isEmpty()) return;

        Set<Id> userIds = new Set<Id>();

        for (User u : scope) {
            userIds.add(u.Id);
        }

        List<Goal__c> goalsToDeactivate = new List<Goal__c>();

        for (Goal__c g : [
            SELECT Id
            FROM Goal__c
            WHERE User__c IN :userIds
            AND Is_Active__c = true
        ]) {
            g.Is_Active__c = false;
            goalsToDeactivate.add(g);
        }

        Integer year = Date.today().year();
        List<Goal__c> newGoals = new List<Goal__c>();

        for (User u : scope) {

            for (Integer m = 1; m <= 12; m++) {

                newGoals.add(new Goal__c(
                    User__c      = u.Id,
                    OwnerId      = u.Id,
                    Target__c    = TARGET_AMOUNT,
                    Is_Active__c = true,
                    Month__c     = MONTH_MAP.get(m),

                    Start_Date__c = DateTime.newInstance(year, m, 1, 0, 0, 0),
                    End_Date__c   = DateTime.newInstance(
                        year, m,
                        Date.daysInMonth(year, m),
                        23, 59, 59
                    )
                ));
            }
        }

        if (!goalsToDeactivate.isEmpty()) {
            Database.update(goalsToDeactivate, false);
        }

        if (!newGoals.isEmpty()) {
            Database.insert(newGoals, false);
        }
    }

    global void finish(Database.BatchableContext bc) {
        // No logging as requested
    }

    global void execute(SchedulableContext sc) {
        Database.executeBatch(new YearlyGoalRolloverBatch(), 200);
    }
}