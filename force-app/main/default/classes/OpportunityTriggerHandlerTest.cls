@isTest
public class OpportunityTriggerHandlerTest {
    @TestSetup
    static void setupTestData() {
        // Create an Account
        Account acc = new Account(Name = 'Test Account for Opp NBC');
        insert acc;

        // Create an Opportunity
        Opportunity opp = new Opportunity(
            Name = 'Test Opportunity NBC',
            AccountId = acc.Id,
            StageName = 'New',
            CloseDate = Date.today().addDays(30)
        );
        insert opp;
        
        // Create NBC Queue if possible
        Group nbcQueue = new Group(Name='NBC Queue', Type='Queue');
        insert nbcQueue;
        
        System.runAs(new User(Id=UserInfo.getUserId())) {
            QueuesObject testQueue = new QueueSObject(QueueID = nbcQueue.id, SObjectType = 'Case');
            insert testQueue;
        }
    }

    @isTest
    static void testAfterUpdate_NBCStage() {
        Opportunity opp = [SELECT Id, StageName, Is_NBC__c FROM Opportunity LIMIT 1];
        
        Test.startTest();
        // Update StageName to NBC and check Is_NBC__c
        opp.StageName = 'NBC';
        opp.Is_NBC__c = true;
        update opp;
        Test.stopTest();

        // Verify that a Case was created
        List<Case> cases = [SELECT Id, Subject, Origin, AccountId FROM Case WHERE AccountId = :opp.AccountId];
        System.assertEquals(1, cases.size(), 'A Case should be created for NBC Stage Opportunity');
        System.assertEquals('NBC - Test Opportunity NBC', cases[0].Subject, 'Subject should match');
        System.assertEquals('Opportunity Closed Won', cases[0].Origin, 'Origin should match');
    }

    @isTest
    static void testAfterUpdate_ClosedWon_NBC() {
        Opportunity opp = [SELECT Id, StageName, Is_NBC__c FROM Opportunity LIMIT 1];
        
        Test.startTest();
        // Update StageName to Closed Won and check NBC
        opp.StageName = 'Closed Won';
        opp.Is_NBC__c = true;
        update opp;
        Test.stopTest();

        // Verify that a Case was created
        List<Case> cases = [SELECT Id, Subject, Origin, AccountId FROM Case WHERE AccountId = :opp.AccountId];
        System.assertEquals(1, cases.size(), 'A Case should be created for Closed Won NBC Opportunity');
        System.assertEquals('NBC - Test Opportunity NBC', cases[0].Subject, 'Subject should match');
        System.assertEquals('Opportunity Closed Won', cases[0].Origin, 'Origin should be Opportunity Closed Won');
    }
    
    @isTest
    static void testAfterUpdate_ClosedWon_NotNBC() {
        Opportunity opp = [SELECT Id, StageName, Is_NBC__c FROM Opportunity LIMIT 1];
        
        Test.startTest();
        // Update StageName to Closed Won but NOT NBC
        opp.StageName = 'Closed Won';
        opp.Is_NBC__c = false;
        update opp;
        Test.stopTest();

        // Verify that no Case was created
        List<Case> cases = [SELECT Id FROM Case WHERE AccountId = :opp.AccountId];
        System.assertEquals(0, cases.size(), 'No Case should be created if Is_NBC__c is false');
    }
}