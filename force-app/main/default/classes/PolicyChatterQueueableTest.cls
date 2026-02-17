@isTest
private class PolicyChatterQueueableTest {

    @isTest
    static void testQueueableExecution() {
        // 1. Setup Data: Parent Record
        Account acc = new Account(Name = 'Test Account');
        insert acc;

        // 2. Setup Data: ContentVersion (to create a ContentDocumentId)
        ContentVersion cv = new ContentVersion(
            Title = 'Test Document',
            PathOnClient = 'test.pdf',
            VersionData = Blob.valueOf('Test Content'),
            IsMajorVersion = true
        );
        insert cv;
        
        // Retrieve the auto-generated ContentDocumentId
        Id conDocId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;

        // 3. Setup Data: Policy Information Records
        Policy_Information__c policy = new Policy_Information__c(
            Lines__c = 'Auto Policy'
        );
        insert policy;

        // 4. Create the Request objects used by the Queueable
        // Assuming PolicyCheckController.PolicySaveRequest is a public class/inner class
        PolicyCheckController.PolicySaveRequest req = new PolicyCheckController.PolicySaveRequest();
        req.chatterText = 'This is a test chatter post';
        req.fileIdToAttach = conDocId;
        req.mentionUserId = UserInfo.getUserId();

        List<PolicyCheckController.PolicySaveRequest> requests = new List<PolicyCheckController.PolicySaveRequest>{req};
        List<Policy_Information__c> savedPolicies = new List<Policy_Information__c>{policy};

        // 5. Execute the Queueable Job
        Test.startTest();
        PolicyChatterQueueable job = new PolicyChatterQueueable(acc.Id, requests, savedPolicies);
        System.enqueueJob(job);
        Test.stopTest();
    }
    
    @isTest
    static void testQueueableWithEmptyFields() {
        // Setup minimal data to test branch coverage where chatter text might be empty
        Account acc = new Account(Name = 'Test Account 2');
        insert acc;
        
        Policy_Information__c policy = new Policy_Information__c();
        insert policy;

        PolicyCheckController.PolicySaveRequest req = new PolicyCheckController.PolicySaveRequest();
        req.chatterText = ''; // Testing the "File Attached" fallback
        req.fileIdToAttach = null; 

        List<PolicyCheckController.PolicySaveRequest> requests = new List<PolicyCheckController.PolicySaveRequest>{req};
        List<Policy_Information__c> savedPolicies = new List<Policy_Information__c>{policy};

        Test.startTest();
        System.enqueueJob(new PolicyChatterQueueable(acc.Id, requests, savedPolicies));
        Test.stopTest();
    }
}