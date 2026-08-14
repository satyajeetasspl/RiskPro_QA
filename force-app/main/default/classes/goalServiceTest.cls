@isTest
public class goalServiceTest {
    
    @isTest
    static void testGenerateGoals() {
        // Fetch the current user's ID to use as valid input
        List<Id> testUserIds = new List<Id>{ UserInfo.getUserId() };
        
        Test.startTest();
        // Execute the method to cover the map, the nested loops, and the database insert
        goalService.generateGoals(testUserIds);
        Test.stopTest();
        
        // Assertions omitted as requested
    }
}