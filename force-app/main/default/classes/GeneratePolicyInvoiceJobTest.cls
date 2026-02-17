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

        // Create Policy (Happy Path)
        Policy_Information__c policy = new Policy_Information__c(
            Lead__c = ld.Id,
            Carrier__c = carrier.Id,
            Policy__c = 'POL-12345'
        );
        insert policy;
        
        // Create Policy (Missing fields to test null fallbacks)
        Policy_Information__c blankPolicy = new Policy_Information__c(
            Lead__c = ld.Id
        );
        insert blankPolicy;
    }

    // 1. Tests standard execution and 2-parameter constructor
    @isTest
    static void testQueueableExecution() {
        Lead ld = [SELECT Id FROM Lead LIMIT 1];
        Policy_Information__c policy = [
            SELECT Id 
            FROM Policy_Information__c 
            WHERE Policy__c = 'POL-12345'
            LIMIT 1
        ];

        Test.startTest();
        System.enqueueJob(new GeneratePolicyInvoiceJob(ld.Id, policy.Id));
        Test.stopTest();
    }
    
    // 2. Tests 3-parameter constructor and "Unknown"/"NoNum" fallbacks
    @isTest
    static void testMissingDataExecution() {
        Lead ld = [SELECT Id FROM Lead LIMIT 1];
        Policy_Information__c blankPolicy = [
            SELECT Id 
            FROM Policy_Information__c 
            WHERE Policy__c = null
            LIMIT 1
        ];

        Test.startTest();
        System.enqueueJob(new GeneratePolicyInvoiceJob(ld.Id, blankPolicy.Id, ld.Id));
        Test.stopTest();
    }

    // 3. Tests the catch block by forcing a QueryException
    @isTest
    static void testExceptionBlockExecution() {
        Lead ld = [SELECT Id FROM Lead LIMIT 1];
        Policy_Information__c policy = [
            SELECT Id 
            FROM Policy_Information__c 
            WHERE Policy__c = 'POL-12345'
            LIMIT 1
        ];
        
        // Delete the policy record to force a SOQL error in the Queueable
        delete policy;

        Test.startTest();
        System.enqueueJob(new GeneratePolicyInvoiceJob(ld.Id, policy.Id));
        Test.stopTest();
    }

    // 4. Tests the null PDF graceful exit using the @TestVisible flag
    @isTest
    static void testNullPdfGracefulExit() {
        Lead ld = [SELECT Id FROM Lead LIMIT 1];
        Policy_Information__c policy = [
            SELECT Id 
            FROM Policy_Information__c 
            WHERE Policy__c = 'POL-12345'
            LIMIT 1
        ];

        // Toggle the test flag to force pdfBlob to be null
        GeneratePolicyInvoiceJob.forceNullPdfForTest = true;

        Test.startTest();
        System.enqueueJob(new GeneratePolicyInvoiceJob(ld.Id, policy.Id));
        Test.stopTest();
    }
}