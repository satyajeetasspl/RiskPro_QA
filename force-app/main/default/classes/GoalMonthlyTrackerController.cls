public with sharing class GoalMonthlyTrackerController {

    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getMonthlyProgress(Id goalId) {

        // Get Goal
        Goal__c g = [
            SELECT Id, Name, Target__c, OwnerId
            FROM Goal__c
            WHERE Id = :goalId
            LIMIT 1
        ];

        // Current month start & end
        Date startOfMonth = Date.today().toStartOfMonth();
        Date endOfMonth = startOfMonth.addMonths(1).addDays(-1);

        // Sum Closed Won Opportunities for Goal Owner (monthly)
        AggregateResult ar = [
            SELECT SUM(Amount) total
            FROM Opportunity
            WHERE StageName = 'Closed Won'
            AND OwnerId = :g.OwnerId
            AND CloseDate >= :startOfMonth
            AND CloseDate <= :endOfMonth
        ];

        Decimal achieved = (Decimal) ar.get('total');
        if (achieved == null) achieved = 0;

        Decimal target = g.Target__c != null ? g.Target__c : 0;

        Decimal percent = target > 0
            ? (achieved / target) * 100
            : 0;

        return new Map<String, Object>{
            'goalName' => g.Name,
            'target' => target,
            'achieved' => achieved,
            'percent' => percent.setScale(2),
            'remaining' => target - achieved
        };
    }
}