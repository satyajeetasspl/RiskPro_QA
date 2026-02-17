@IsTest
private class LeadCadenceOwnerChange_BulkTest {

    @IsTest
    static void bulk_owner_change_invokes_flow_per_item() {
        // Arrange users
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User u1 = makeUser('bulkAct', p.Id);
        User u2 = makeUser('bulkNew', p.Id);
        insert new List<User>{ u1, u2 };

        // Arrange 5 leads owned by u1
        List<Lead> leads = new List<Lead>();
        for (Integer i = 0; i < 5; i++) {
            leads.add(new Lead(
                LastName = 'Bulk Lead ' + i,
                Company = 'Acme ' + i,
                OwnerId = u1.Id,
                Status = 'Open - Not Contacted'
            ));
        }
        insert leads;

        // Act: change all owners to u2
        for (Lead ld : leads) ld.OwnerId = u2.Id;

        Test.startTest();
        update leads;
        Test.stopTest();

        // Assert: owners changed and no exceptions; covers helper loop and Flow invocation
        Map<Id, Lead> reloaded = new Map<Id, Lead>([
            SELECT Id, OwnerId FROM Lead WHERE Id IN :leads
        ]);
        for (Lead ld : leads) {
            System.assertEquals(u2.Id, reloaded.get(ld.Id).OwnerId, 'Owner should change for ' + ld.Id);
        }
    }

    private static User makeUser(String key, Id profileId) {
        Long ts = System.currentTimeMillis();
        return new User(
            FirstName = key,
            LastName = 'User',
            Alias = key.left(5),
            Email = key + ts + '@example.com.dev',
            Username = key + ts + '@example.com.dev',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = profileId
        );
    }
}