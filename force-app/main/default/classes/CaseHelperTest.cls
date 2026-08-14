@IsTest
public class CaseHelperTest {
    
    // =======================
    // Existing Lead owner tests
    // =======================
    
    @IsTest
    static void bulk_owner_change_invokes_flow_per_item() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User u1 = makeUser('bulkAct', p.Id);
        User u2 = makeUser('bulkNew', p.Id);
        insert new List<User>{ u1, u2 };

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

        for (Lead ld : leads) ld.OwnerId = u2.Id;

        Test.startTest();
        update leads;
        Test.stopTest();
    }

    @IsTest
    static void no_change_skips_flow() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User u1 = makeUser('sameOwn', p.Id);
        insert u1;

        Lead ld = new Lead(LastName = 'No Change', Company = 'Acme', OwnerId = u1.Id, Status = 'Open - Not Contacted');
        insert ld;

        ld.Company = 'Acme Updated';

        Test.startTest();
        update ld;
        Test.stopTest();
    }

    @IsTest
    static void mixed_batch_some_change_some_not() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User u1 = makeUser('mixAct', p.Id);
        User u2 = makeUser('mixNew', p.Id);
        insert new List<User>{ u1, u2 };

        Lead mustChange = new Lead(LastName = 'Must Change', Company = 'A', OwnerId = u1.Id, Status = 'Open - Not Contacted');
        Lead noChange = new Lead(LastName = 'No Change', Company = 'B', OwnerId = u1.Id, Status = 'Open - Not Contacted');
        insert new List<Lead>{ mustChange, noChange };

        mustChange.OwnerId = u2.Id;
        noChange.Company = 'B Updated';

        Test.startTest();
        update new List<Lead>{ mustChange, noChange };
        Test.stopTest();
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

    // =======================
    // New CaseHelper coverage tests
    // =======================
    
    @IsTest
    static void testParseDescription_allFields() {
        Case c = new Case(
            Subject = 'Test Case',
            Origin = 'Email',
            Description =
                'Name: John Doe\n' +
                'Daytime Phone: 123-456-7890\n' +
                'Evening Phone: 098-765-4321\n' +
                'Email: john.doe@example.com\n' +
                'Birthdate: 02/15/1988\n' +
                'Address: 123 Main St\n' +
                'City, State ZIP: Raleigh NC 27609\n' +
                'Property Address: 456 Elm St\n' +
                'Property City: Raleigh\n' +
                'Property State: NC\n' +
                'Property ZIP: 27609\n' +
                'Extra Field: Extra Value'
        );
        insert c;

        Test.startTest();
        CaseHelper.parseDescription(new List<Id>{c.Id});
        Test.stopTest();
    }

    @IsTest
    static void testParseDescription_emptyAndNull() {
        Test.startTest();
        CaseHelper.parseDescription(null);
        CaseHelper.parseDescription(new List<Id>());
        Test.stopTest();
    }

    @IsTest
    static void testParseDescription_invalidEmailAndDate() {
        Case c = new Case(
            Subject = 'Invalid Data Case',
            Origin = 'Email',
            Description =
                'Name: Jane Smith\n' +
                'Email: invalid-email\n' +
                'Birthdate: invalid-date'
        );
        insert c;

        Test.startTest();
        CaseHelper.parseDescription(new List<Id>{c.Id});
        Test.stopTest();
    }

    @IsTest
    static void testParseDescription_emptyDescription() {
        Case c = new Case(
            Subject = 'Empty Description',
            Origin = 'Email',
            Description = ''
        );
        insert c;

        Test.startTest();
        CaseHelper.parseDescription(new List<Id>{c.Id});
        Test.stopTest();
    }

}