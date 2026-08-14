@IsTest
public class SignEasyTransactionHelperTest {

    @IsTest
    static void testProcessCompletedTransactions() {
        // Setup Test Data
        User testUser = [SELECT Id FROM User WHERE IsActive = true AND Profile.Name = 'System Administrator' LIMIT 1];
        
        System.runAs(testUser) {
            // Create a Lead
            Lead testLead = new Lead(
                LastName = 'Test Lead',
                Company = 'Test Company',
                Status = 'Open - Not Contacted',
                Agent_2__c = testUser.Id,
                OwnerId = testUser.Id
            );
            insert testLead;
            
            // Create SignEasy Transaction
            hic_signeasy__Transaction__c testTrans = new hic_signeasy__Transaction__c(
                hic_signeasy__Lead__c = testLead.Id,
                hic_signeasy__Status__c = 'Pending'
            );
            insert testTrans;
            
            Test.startTest();
            // Update status to Completed to fire the trigger
            testTrans.hic_signeasy__Status__c = 'Completed';
            update testTrans;
            
            // Ensure no limits or exceptions were thrown
            // Note: CustomNotification & Email sending in tests don't actually send, 
            // but we can assert limits to verify they were executed.
            Integer emailInvocations = Limits.getEmailInvocations();
            System.assertEquals(1, emailInvocations, 'One email invocation should have occurred');
            
            Test.stopTest();
        }
    }
    
    @IsTest
    static void testProcessCompletedTransactionsOpp() {
        // Setup Test Data
        User testUser = [SELECT Id FROM User WHERE IsActive = true AND Profile.Name = 'System Administrator' LIMIT 1];
        
        System.runAs(testUser) {
            // Create an Account
            Account acc = new Account(Name = 'Test Account');
            insert acc;
            
            // Create an Opportunity
            Opportunity opp = new Opportunity(
                Name = 'Test Opp',
                StageName = 'Prospecting',
                CloseDate = Date.today().addDays(30),
                AccountId = acc.Id,
                Agent_2__c = testUser.Id,
                OwnerId = testUser.Id
            );
            insert opp;
            
            // Create SignEasy Transaction
            hic_signeasy__Transaction__c testTrans = new hic_signeasy__Transaction__c(
                hic_signeasy__Opportunity__c = opp.Id,
                hic_signeasy__Status__c = 'Sent'
            );
            insert testTrans;
            
            Test.startTest();
            // Update status to COMPLETE
            testTrans.hic_signeasy__Status__c = 'COMPLETE';
            update testTrans;
            
            Integer emailInvocations = Limits.getEmailInvocations();
            System.assertEquals(1, emailInvocations, 'One email invocation should have occurred');
            
            Test.stopTest();
        }
    }
}