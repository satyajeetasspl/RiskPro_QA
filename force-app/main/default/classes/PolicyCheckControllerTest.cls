@IsTest
private class PolicyCheckControllerTest {

    // =========================
    // Helper Methods
    // =========================
    private static Lead createTestLead() {
        Lead l = new Lead(
            LastName = 'Test Lead',
            Company  = 'Test Co',
            Status   = 'New'
        );
        insert l;
        return l;
    }

    private static Account createTestAccount() {
        Account a = new Account(
            Name = 'Test Account'
        );
        insert a;
        return a;
    }

    private static Opportunity createTestOpportunity(Id accountId) {
        Opportunity o = new Opportunity(
            Name = 'Test Opportunity',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30),
            AccountId = accountId
        );
        insert o;
        return o;
    }

    private static Policy_Information__c createTestPolicy(Id recordId, String sType) {
        Policy_Information__c p = new Policy_Information__c(
            Lines__c = 'Auto',
            Policy_Status__c = 'Submitted'
        );
        if(sType == 'Lead') p.Lead__c = recordId;
        else if(sType == 'Account') p.Account__c = recordId;
        else if(sType == 'Opportunity') {
            p.Opportunity__c = recordId;
        }
        insert p;
        return p;
    }

    private static Id createTestFile() {
        ContentVersion cv = new ContentVersion(
            Title = 'TestFile',
            PathOnClient = 'TestFile.txt',
            VersionData = Blob.valueOf('Test content'),
            IsMajorVersion = true
        );
        insert cv;

        ContentVersion insertedCv = [
            SELECT Id, ContentDocumentId
            FROM ContentVersion
            WHERE Id = :cv.Id
            LIMIT 1
        ];
        return insertedCv.ContentDocumentId;
    }

    // =========================
    // Picklist / Options Methods
    // =========================
    @IsTest
    static void testGetPolicyStatusOptions() {
        Test.startTest();
        List<Map<String, String>> opts = PolicyCheckController.getPolicyStatusOptions();
        System.assert(!opts.isEmpty(), 'Picklist options should return values.');
        Test.stopTest();
    }

    @IsTest
    static void testGetAgent2Options() {
        Test.startTest();
        List<User> users = PolicyCheckController.getAgent2Options();
        System.assert(!users.isEmpty(), 'Should return active users.');
        Test.stopTest();
    }

    @IsTest
    static void testGetCarrierOptions() {
        Carrier__c c = new Carrier__c(Company_Name__c = 'Test Carrier');
        insert c;

        Test.startTest();
        List<Carrier__c> carriers = PolicyCheckController.getCarrierOptions();
        System.assert(carriers.size() > 0, 'Should return carrier records.');
        Test.stopTest();
    }

    // =========================
    // Get Policy Check Data
    // =========================
    @IsTest
    static void testGetPolicyCheckData_Lead() {
        Lead l = createTestLead();
        Policy_Information__c p = createTestPolicy(l.Id, 'Lead');

        FeedItem fi = new FeedItem(ParentId = p.Id, Body = 'Test feed');
        insert fi;

        Id docId = createTestFile();
        ContentDocumentLink cdl = new ContentDocumentLink(
            LinkedEntityId = p.Id,
            ContentDocumentId = docId,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );
        insert cdl;

        Test.startTest();
        PolicyCheckController.PolicyCheckWrapper wrap = PolicyCheckController.getPolicyCheckData(l.Id);
        System.assertEquals(l.Id, wrap.recordDetail.Id, 'Wrapper should contain Lead.');
        System.assert(!wrap.policies.isEmpty(), 'Policies should be fetched.');
        System.assert(!wrap.policyChatterMap.isEmpty(), 'Chatter posts should be fetched.');
        System.assert(!wrap.policyFilesMap.isEmpty(), 'Files should be fetched.');
        Test.stopTest();
    }

    @IsTest
    static void testGetPolicyCheckData_AccountOpportunity() {
        Account a = createTestAccount();
        Opportunity o = createTestOpportunity(a.Id);
        createTestPolicy(a.Id, 'Account');
        createTestPolicy(o.Id, 'Opportunity');

        Test.startTest();
        PolicyCheckController.PolicyCheckWrapper wrapAcc = PolicyCheckController.getPolicyCheckData(a.Id);
        PolicyCheckController.PolicyCheckWrapper wrapOpp = PolicyCheckController.getPolicyCheckData(o.Id);
        System.assertEquals(a.Id, wrapAcc.recordDetail.Id, 'Wrapper should contain Account.');
        System.assertEquals(o.Id, wrapOpp.recordDetail.Id, 'Wrapper should contain Opportunity.');
        Test.stopTest();
    }

    // =========================
    // Save Policy Check With Policies
    // =========================
    @IsTest
    static void testSavePolicyCheckWithPolicies_FinalSubmission_Lead() {
        Lead l = createTestLead();

        Policy_Information__c pol = new Policy_Information__c(
            Lines__c = 'Auto',
            Policy_Status__c = 'Approved',
            Additional_Comments__c = 'Mgmt notes'
        );

        PolicyCheckController.PolicySaveRequest req = new PolicyCheckController.PolicySaveRequest();
        req.policyRecord = pol;
        req.chatterText  = 'Test chatter';
        req.mentionUserId = UserInfo.getUserId();
        req.fileIdToAttach = createTestFile();

        List<PolicyCheckController.PolicySaveRequest> reqs = new List<PolicyCheckController.PolicySaveRequest>{ req };

        Test.startTest();
        PolicyCheckController.savePolicyCheckWithPolicies(
            l.Id,
            'Final comments',
            UserInfo.getUserId(),
            reqs,
            true
        );
        Test.stopTest();

        Lead updatedLead = [SELECT Policy_Check_Status__c, Policy_Check_Summary__c FROM Lead WHERE Id = :l.Id];
       
    }

    @IsTest
    static void testSavePolicyCheckWithPolicies_NotFinal_AccountOpportunity() {
        Account a = createTestAccount();
        Opportunity o = createTestOpportunity(a.Id);

        Policy_Information__c polAcc = new Policy_Information__c(Lines__c='Home', Policy_Status__c='Approved');
        Policy_Information__c polOpp = new Policy_Information__c(Lines__c='Auto', Policy_Status__c='Rejected');

        PolicyCheckController.PolicySaveRequest reqAcc = new PolicyCheckController.PolicySaveRequest();
        reqAcc.policyRecord = polAcc;
        PolicyCheckController.PolicySaveRequest reqOpp = new PolicyCheckController.PolicySaveRequest();
        reqOpp.policyRecord = polOpp;

        Test.startTest();
        PolicyCheckController.savePolicyCheckWithPolicies(a.Id, 'Account update', null, new List<PolicyCheckController.PolicySaveRequest>{reqAcc}, false);
        PolicyCheckController.savePolicyCheckWithPolicies(o.Id, 'Opportunity update', null, new List<PolicyCheckController.PolicySaveRequest>{reqOpp}, false);
        Test.stopTest();
    }

    // =========================
    // Send Emails Covered by Test.isRunningTest()
    // =========================
    @IsTest
    static void testSendEmailsCoveredByTestMode() {
        Lead l = createTestLead();
        Policy_Information__c pol = createTestPolicy(l.Id, 'Lead');

        PolicyCheckController.PolicySaveRequest req = new PolicyCheckController.PolicySaveRequest();
        req.policyRecord = pol;
        req.chatterText  = 'Email test';
        req.fileIdToAttach = createTestFile();

        Test.startTest();
        PolicyCheckController.savePolicyCheckWithPolicies(
            l.Id,
            'Comments for email test',
            UserInfo.getUserId(),
            new List<PolicyCheckController.PolicySaveRequest>{req},
            true
        );
        Test.stopTest();
    }
}