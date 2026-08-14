public without sharing class GenerateUserGoalsHelper {
    
    @InvocableMethod(label='Generate Yearly Goals for User' description='Creates 12 monthly goals for a specific user')
    public static void generateGoals(List<Id> userIds) {
        if (userIds.isEmpty()) return;
        
        Id selectedUserId = userIds[0];
        Decimal TARGET_AMOUNT = 50000;
        Integer year = Date.today().year();
        
        // Exact picklist values matching your system
        Map<Integer, String> MONTH_MAP = new Map<Integer, String>{
            1 => 'January', 2 => 'February', 3 => 'March', 4 => 'April',
            5 => 'May', 6 => 'June', 7 => 'July', 8 => 'August',
            9 => 'September', 10 => 'October', 11 => 'November', 12 => 'December'
        };
        
        // 1. Deactivate existing active goals for this specific user
        List<Goal__c> goalsToDeactivate = [SELECT Id FROM Goal__c WHERE User__c = :selectedUserId AND Is_Active__c = true];
        for (Goal__c g : goalsToDeactivate) {
            g.Is_Active__c = false;
        }
        if (!goalsToDeactivate.isEmpty()) {
            update goalsToDeactivate;
        }
        
        // 2. Create the 12 new monthly goals
        List<Goal__c> newGoals = new List<Goal__c>();
        for (Integer m = 1; m <= 12; m++) {
            newGoals.add(new Goal__c(
                User__c       = selectedUserId,
                OwnerId       = selectedUserId,
                Target__c     = TARGET_AMOUNT,
                Is_Active__c  = true,
                Month__c      = MONTH_MAP.get(m),
                Start_Date__c = DateTime.newInstance(year, m, 1, 0, 0, 0),
                End_Date__c   = DateTime.newInstance(year, m, Date.daysInMonth(year, m), 23, 59, 59)
            ));
        }
        
        if (!newGoals.isEmpty()) {
            insert newGoals;
        }
    }
}