public with sharing class RiskProUserController {
    
    // Gets the users for the LWC table
    @AuraEnabled(cacheable=true)
    public static List<User> getRiskProUsers() {
        return [
            SELECT Id, Name, Email 
            FROM User 
            WHERE IsActive = true 
            AND Profile.Name = 'RISK  PRO Standard Profile'
        ];
    }

    // Connects the LWC button to your Helper class
    @AuraEnabled
    public static void generateGoalsForUser(Id userId) {
        GoalService.generateGoals(new List<Id>{userId});
    }
}