@isTest
public class GeneratePolicyInvoiceJobTest {

    @testSetup
    static void setupData() {

        // Create Lead
        Lead ld = new Lead(
            LastName = 'Test Lead',
            Company = 'Test Company',
            Status = 'Open - Not Contacted'
        );
        insert ld;

        // Create Carrier
        Carrier__c carrier = new Carrier__c(
            Company_Name__c = 'Test Carrier'
        );
        insert carrier;

        // Create Policy
        Policy_Information__c policy = new Policy_Information__c(
            Lead__c = ld.Id,
            Carrier__c = carrier.Id,
            Policy__c = 'POL-12345'
        );
        insert policy;
    }

    @isTest
    static void testQueueableExecution() {

        Lead ld = [SELECT Id FROM Lead LIMIT 1];
        Policy_Information__c policy = [
            SELECT Id 
            FROM Policy_Information__c 
            LIMIT 1
        ];

        Test.startTest();
        System.enqueueJob(
            new GeneratePolicyInvoiceJob(ld.Id, policy.Id)
        );
        Test.stopTest();
    }
}