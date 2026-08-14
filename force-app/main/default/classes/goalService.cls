public with sharing class goalService {
private static final Decimal TARGET_AMOUNT = 50000;
    
    private static final Map<Integer, String> MONTH_MAP = new Map<Integer, String>{
        1 => 'January', 2 => 'February', 3 => 'March', 4 => 'April',
        5 => 'May', 6 => 'June', 7 => 'July', 8 => 'August',
        9 => 'September', 10 => 'October', 11 => 'November', 12 => 'December'
    };

    @AuraEnabled
    public static void generateGoals(List<Id> userIds) {
        
        List<Goal__c> goalsToInsert = new List<Goal__c>();
        Integer currentYear = Date.today().year();
        
        for (Id uId : userIds) {
            
            for (Integer i = 1; i <= 12; i++) {
                
                Goal__c singleMonthGoal = new Goal__c();
                
                singleMonthGoal.OwnerId = uId; 
                singleMonthGoal.User__c = uId; 
                singleMonthGoal.Target__c = 50000;
                singleMonthGoal.Is_Active__c = true;
                singleMonthGoal.Month__c = MONTH_MAP.get(i);
                singleMonthGoal.Start_Date__c = DateTime.newInstance(currentYear, i, 1, 0, 0, 0);
                singleMonthGoal.End_Date__c = DateTime.newInstance(
                    currentYear, i, 
                    Date.daysInMonth(currentYear, i), 
                    23, 59, 59
                );
                
                goalsToInsert.add(singleMonthGoal);
            }
        }

        if (!goalsToInsert.isEmpty()) {
            Database.insert(goalsToInsert, false); 
        }
    }
}