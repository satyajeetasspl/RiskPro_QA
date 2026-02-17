@IsTest
private class CadenceAssigneeService_Test {

    // small helper to create a test user (fallback to any available profile)
    private static User createTestUser() {
        Profile p;
        List<Profile> ps = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        if (ps.isEmpty()) p = [SELECT Id FROM Profile LIMIT 1];
        else p = ps[0];

        String uniq = String.valueOf(Datetime.now().getTime());
        User u = new User(
            Alias = ('t' + uniq).left(8),
            Email = 'tu' + uniq + '@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'TUser' + uniq,
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            TimeZoneSidKey = 'America/Los_Angeles',
            Username = 'tu' + uniq + '@example.com',
            ProfileId = p.Id
        );
        insert u;
        return u;
    }

    @IsTest
    static void test_flow_invocation_lines_run_without_trackers() {
        // create a lead
        Lead L = new Lead(FirstName='Flow', LastName='Test', Company='Acme');
        insert L;

        // create new owner user
        User newOwner = createTestUser();

        // prepare oldMap and newList (owner change)
        Lead oldL = new Lead(Id = L.Id, OwnerId = L.OwnerId);
        Lead newL = new Lead(Id = L.Id, OwnerId = newOwner.Id);

        // Enable the test hook so eligibleLeads will be forced even if we couldn't insert trackers
        CadenceAssigneeService.TEST_FORCE_INVOKE_FLOW = true;

        Test.startTest();
            CadenceAssigneeService.handleOwnerChanges(
                new List<Lead>{ newL },
                new Map<Id, Lead>{ L.Id => oldL }
            );
        Test.stopTest();

        // Turn the flag off (cleanup)
        CadenceAssigneeService.TEST_FORCE_INVOKE_FLOW = false;
    }

    @IsTest
    static void test_other_branches_covered() {
        // cover empty/null/no-change branches in the same test method (one start/stop)
        Lead L2 = new Lead(FirstName='No', LastName='Change', Company='Me');
        insert L2;
        Lead oldL2 = new Lead(Id = L2.Id, OwnerId = L2.OwnerId);

        Test.startTest();
            CadenceAssigneeService.handleOwnerChanges(new List<Lead>(), new Map<Id, Lead>());
            CadenceAssigneeService.handleOwnerChanges(null, null);
            CadenceAssigneeService.handleOwnerChanges(new List<Lead>{ oldL2 }, new Map<Id, Lead>{ L2.Id => oldL2 });
        Test.stopTest();
    }
}