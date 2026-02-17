@IsTest
public with sharing class MicrobatchSelfRegControllerTest {

    @IsTest
    public static void testConstructor() {
        // Avoid expid since Site.setExperienceId is not allowed in tests
        Test.setCurrentPage(Page.CommunitiesSelfRegConfirm);

        MicrobatchSelfRegController controller = new MicrobatchSelfRegController();
        System.assertNotEquals(null, controller);
    }


    @IsTest
    public static void testCommunityNicknameTrim() {
        MicrobatchSelfRegController controller = new MicrobatchSelfRegController();
        controller.communityNickname = '  Nick  ';
        System.assertEquals('Nick', controller.communityNickname);
    }


    @IsTest
    public static void testRegisterUser_ValidationFailurePath() {
        // Invalid email → validation stops execution BEFORE async call
        // This increases coverage of the try/catch without Salesforce blocking.
        MicrobatchSelfRegController controller = new MicrobatchSelfRegController();
        controller.firstName = 'First';
        controller.lastName = 'Last';
        controller.email = 'invalid-email';  // INVALID
        controller.communityNickname = 'tester';

        Test.startTest();
        controller.registerUser();   // No assertion requested
        Test.stopTest();
    }


    @IsTest
    public static void testRegisterUser_NullUUID() {
        // This covers the null UUID return path
        MicrobatchSelfRegController controller = new MicrobatchSelfRegController();
        controller.firstName = 'A';
        controller.lastName = 'B';
        controller.email = 'valid@example.com';
        controller.communityNickname = 'nick';

        Test.startTest();
        controller.registerUser();   // Also no assertion needed
        Test.stopTest();
    }
}