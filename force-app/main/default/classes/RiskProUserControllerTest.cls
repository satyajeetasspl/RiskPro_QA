@isTest
public class RiskProUserControllerTest {
    
    @isTest
    static void testGetRiskProUsers() {
        Test.startTest();
        // Call the method to cover the SOQL query
        List<User> returnedUsers = RiskProUserController.getRiskProUsers();
        Test.stopTest();
        
        // Assertions omitted as requested
    }
    
    @isTest
    static void testGenerateGoalsForUser() {
        // Fetch a valid user ID (the user running the test) to pass into the method
        Id testUserId = UserInfo.getUserId();
        
        Test.startTest();
        // Call the method to cover the GoalService invocation
        RiskProUserController.generateGoalsForUser(testUserId);
        Test.stopTest();
        
        // Assertions omitted as requested
    }
}