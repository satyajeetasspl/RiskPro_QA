/**
 * Class containing tests for SiteRegisterController
 */
@IsTest public with sharing class SiteRegisterControllerTest {
    @IsTest(SeeAllData=true) static void testRegistration() {
        SiteRegisterController controller = new SiteRegisterController();
        controller.username = 'test@force.com';
        controller.email = 'test@force.com';
        controller.communityNickname = 'test';
        
        // ---------------------------------------------------------
        // 1. COVER THE PASSWORDS DON't MATCH BLOCK
        // ---------------------------------------------------------
        controller.password = 'abcd1234';
        controller.confirmPassword = 'mismatched_password!';
        
        // This executes the ApexPages.Message and return null block
        controller.registerUser(); 
        

        // ---------------------------------------------------------
        // 2. COVER THE SUCCESSFUL SITE.LOGIN BLOCK
        // ---------------------------------------------------------
        controller.password = 'abcd1234';
        controller.confirmPassword = 'abcd1234';
        
        // This executes Site.login(username, password, null)
        controller.registerUser(); 
        

        // ---------------------------------------------------------
        // 3. COVER THE NULL PASSWORD REDIRECT BLOCK
        // ---------------------------------------------------------
        controller.password = null;
        controller.confirmPassword = null;
        
        // This executes the System.Page.SiteRegisterConfirm redirect logic
        controller.registerUser(); 
    }
}