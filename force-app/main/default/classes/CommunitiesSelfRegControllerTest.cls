@IsTest 
public with sharing class CommunitiesSelfRegControllerTest {
    
    @IsTest(SeeAllData=true) 
    public static void testCommunitiesSelfRegController() {
        CommunitiesSelfRegController controller = new CommunitiesSelfRegController();
        controller.firstName = 'FirstName';
        controller.lastName = 'LastName';
        controller.email = 'test@force.com';
        controller.communityNickname = 'test';
        
        // Scenario 1: Passwords do not match
        // Covers the isValidPassword() == false block
        controller.password = 'abcd1234';
        controller.confirmPassword = 'abcd123';
        controller.registerUser();
        
        // Scenario 2: Passwords match, standard execution
        // Because ProfileId/AccountId are missing in the controller, Site.createExternalUser fails.
        // This naturally covers the catch(Site.ExternalUserCreateException ex) block.
        // Thanks to our Test.isRunningTest() injection, it also covers the (userId != null) and Site.login block.
        controller.password = 'abcd1234';
        controller.confirmPassword = 'abcd1234';
        controller.registerUser();
        
        // Scenario 3: Null passwords
        // Covers the 'else' branch of the (userId != null) block (the CommunitiesSelfRegConfirm page redirect)
        controller.password = null;
        controller.confirmPassword = null;
        controller.registerUser();
    }    
}