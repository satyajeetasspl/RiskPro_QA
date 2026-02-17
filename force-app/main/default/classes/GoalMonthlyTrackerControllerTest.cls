@isTest
private class GoalMonthlyTrackerControllerTest {

    @testSetup
    static void setupTestData() {
        // Create a test Goal without setting the Name field (Auto-Number)
        Goal__c testGoal = new Goal__c(
            Target__c = 10000
        );
        insert testGoal;

        // Create an Opportunity that falls in the current month and is Closed Won
        Opportunity opp = new Opportunity(
            Name = 'Current Month Won Opp',
            StageName = 'Closed Won',
            CloseDate = Date.today(), // Ensures it falls in the current month
            Amount = 2500,
            OwnerId = UserInfo.getUserId()
        );
        insert opp;
    }

    @isTest
    static void testGetMonthlyProgress_WithValidData() {
        // Retrieve the goal created in setup using Target__c instead of Name
        Goal__c g = [SELECT Id FROM Goal__c WHERE Target__c = 10000 LIMIT 1];

        Test.startTest();
        // Execute the method
        Map<String, Object> result = GoalMonthlyTrackerController.getMonthlyProgress(g.Id);
        Test.stopTest();
    }

    @isTest
    static void testGetMonthlyProgress_NullOrZeroAchieved() {
        // Create a separate goal with a different target to identify it
        Goal__c emptyGoal = new Goal__c(
            Target__c = 5000
        );
        insert emptyGoal;

        Test.startTest();
        // Execute the method 
        Map<String, Object> result = GoalMonthlyTrackerController.getMonthlyProgress(emptyGoal.Id);
        Test.stopTest();
    }

    @isTest
    static void testGetMonthlyProgress_ZeroTarget() {
        // Create a goal with a null or zero target 
        Goal__c zeroTargetGoal = new Goal__c(
            Target__c = 0 
        );
        insert zeroTargetGoal;

        Test.startTest();
        // Execute the method 
        Map<String, Object> result = GoalMonthlyTrackerController.getMonthlyProgress(zeroTargetGoal.Id);
        Test.stopTest();
    }
}