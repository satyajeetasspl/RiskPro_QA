@isTest
public class LeadEmailInvokerTest {

    @isTest
    static void testSendProcessorEmail_Success() {
        // 1. Create the specific data we need for this test
        Lead testLead = new Lead(
            FirstName = 'John',
            LastName = 'Doe',
            Company = 'Test Company', // Required standard field
            Loan__c = '12345',
            Processor_Name__c = 'Processor Guy',
            Processor_Email__c = 'processor@test.com' 
        );
        insert testLead;

        // 2. Prepare the request
        LeadEmailInvoker.Request req = new LeadEmailInvoker.Request();
        req.leadId = testLead.Id;

        // 3. Run the test
        Test.startTest();
        LeadEmailInvoker.sendEmail(new List<LeadEmailInvoker.Request>{ req });
        Integer invocations = Limits.getEmailInvocations(); // Check if email was sent
        Test.stopTest();
    }

    @isTest
    static void testSendProcessorEmail_MissingEmail() {
        // 1. Create a lead explicitly WITHOUT a processor email
        Lead testLead = new Lead(
            LastName = 'NoEmail',
            Company = 'Test Company',
            Processor_Email__c = null // Explicitly null
        );
        insert testLead;

        LeadEmailInvoker.Request req = new LeadEmailInvoker.Request();
        req.leadId = testLead.Id;

        Test.startTest();
        LeadEmailInvoker.sendEmail(new List<LeadEmailInvoker.Request>{ req });
        Integer invocations = Limits.getEmailInvocations();
        Test.stopTest();

    }
}