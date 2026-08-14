@IsTest
public class QuoteCheckAgingBatchTest {

    @IsTest
    static void testAgingBatch() {
        // Create test lead
        Lead testLead = new Lead(
            LastName = 'TestAging',
            Company = 'TestCompany',
            Policy_Check_Status__c = 'Submitted',
            Quote_Check_Submitted_Date__c = System.now().addDays(-3)
        );
        insert testLead;

        Test.startTest();
        QuoteCheckAgingBatch batch = new QuoteCheckAgingBatch();
        Database.executeBatch(batch);
        Test.stopTest();

        // Verify updates
        Lead updatedLead = [SELECT Quote_Check_Age_Days__c, Quote_Check_Stale__c FROM Lead WHERE Id = :testLead.Id];
        System.assertEquals(3, updatedLead.Quote_Check_Age_Days__c, 'Age days should be 3');
        System.assertEquals(false, updatedLead.Quote_Check_Stale__c, 'Should not be stale at 3 days');
        
        // Verify chatter
        Integer feedCount = [SELECT COUNT() FROM FeedItem WHERE ParentId = :testLead.Id];
        System.assertEquals(1, feedCount, 'There should be 1 chatter post for day 3');
    }
    
    @IsTest
    static void testStaleBatch() {
        Lead staleLead = new Lead(
            LastName = 'TestStale',
            Company = 'TestCompany',
            Policy_Check_Status__c = 'Submitted',
            Quote_Check_Submitted_Date__c = System.now().addDays(-7)
        );
        insert staleLead;

        Test.startTest();
        QuoteCheckAgingBatch batch = new QuoteCheckAgingBatch();
        Database.executeBatch(batch);
        Test.stopTest();

        Lead updatedLead = [SELECT Quote_Check_Age_Days__c, Quote_Check_Stale__c FROM Lead WHERE Id = :staleLead.Id];
        System.assertEquals(7, updatedLead.Quote_Check_Age_Days__c, 'Age days should be 7');
        System.assertEquals(true, updatedLead.Quote_Check_Stale__c, 'Should be stale at 7 days');
    }
}