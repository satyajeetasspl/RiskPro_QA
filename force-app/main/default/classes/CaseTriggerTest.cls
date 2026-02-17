@isTest
public class CaseTriggerTest {

    @isTest
    static void testCaseTriggerAllEvents() {
        // 1. Set up your test data (Make sure to add ANY fields your org requires!)
        Case c = new Case(
            Subject = 'Test Case',
            Status = 'New',
            Origin = 'Phone'
            // Add other required fields here if you have active Validation Rules!
            // e.g., AccountId = testAccount.Id
        );

        Test.startTest();
        
        // BEFORE INSERT & AFTER INSERT
        insert c;
        
        // BEFORE UPDATE & AFTER UPDATE
        c.Subject = 'Updated Test Case';
        update c;
        
        // BEFORE DELETE & AFTER DELETE
        delete c;
        
        // AFTER UNDELETE
        undelete c;
        
        Test.stopTest();

        // 2. Verify that the undelete actually worked to ensure the test completed
        List<Case> verifyCases = [SELECT Id FROM Case WHERE Id = :c.Id];
        System.assertEquals(1, verifyCases.size(), 'The case should exist after being undeleted.');
    }
}