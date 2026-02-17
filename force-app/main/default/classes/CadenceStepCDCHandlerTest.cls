@isTest
public class CadenceStepCDCHandlerTest {

    /* -----------------------------------------------------------
       Helper method to create a CDC event from JSON
    ----------------------------------------------------------- */
    private static ActionCadenceStepTrackerChangeEvent buildEvent(
        String changeType,
        String state,
        String outcome,
        String stepType,
        Id targetId
    ) {
        String eventJson = '{' +
            '"ChangeEventHeader": {' +
                '"changeType": "' + changeType + '",' +
                '"entityName": "ActionCadenceStepTracker"' +
            '},' +
            '"State__c": "' + state + '",' +
            '"Outcome__c": "' + outcome + '",' +
            '"StepType__c": "' + stepType + '",' +
            '"TargetId__c": "' + targetId + '"' +
        '}';

        return (ActionCadenceStepTrackerChangeEvent)
            JSON.deserialize(eventJson, ActionCadenceStepTrackerChangeEvent.class);
    }

    /* -----------------------------------------------------------
       Test Meaningful Connect (CREATE)
    ----------------------------------------------------------- */
    @isTest
    static void testMeaningfulConnectCreate() {

        Lead l = new Lead(
            FirstName = 'MC',
            LastName  = 'Create',
            Company   = 'Test Co',
            Status    = 'New'
        );
        insert l;

        ActionCadenceStepTrackerChangeEvent evt =
            buildEvent('CREATE', 'Completed', 'Meaningful Connect', 'Call', l.Id);

        Test.startTest();
        CadenceStepCDCHandler.process(
            new List<ActionCadenceStepTrackerChangeEvent>{ evt }
        );
        Test.stopTest();
    }

    /* -----------------------------------------------------------
       Test Reply (UPDATE - Email)
    ----------------------------------------------------------- */
    @isTest
    static void testReplyEmailUpdate() {

        Lead l = new Lead(
            FirstName = 'Reply',
            LastName  = 'Email',
            Company   = 'Reply Inc',
            Status    = 'New'
        );
        insert l;

        ActionCadenceStepTrackerChangeEvent evt =
            buildEvent('UPDATE', 'Completed', 'Email Replied', 'Email', l.Id);

        Test.startTest();
        CadenceStepCDCHandler.process(
            new List<ActionCadenceStepTrackerChangeEvent>{ evt }
        );
        Test.stopTest();
    }

    /* -----------------------------------------------------------
       Test Reply (SMS)
    ----------------------------------------------------------- */
    @isTest
    static void testReplySMS() {

        Lead l = new Lead(
            FirstName = 'Reply',
            LastName  = 'SMS',
            Company   = 'SMS Corp',
            Status    = 'New'
        );
        insert l;

        ActionCadenceStepTrackerChangeEvent evt =
            buildEvent('UPDATE', 'Completed', 'SMS Replied', 'SMS', l.Id);

        Test.startTest();
        CadenceStepCDCHandler.process(
            new List<ActionCadenceStepTrackerChangeEvent>{ evt }
        );
        Test.stopTest();
    }

    /* -----------------------------------------------------------
       Test Non-Completed State (Should Skip)
    ----------------------------------------------------------- */
    @isTest
    static void testNonCompletedState() {

        Lead l = new Lead(
            FirstName = 'Skip',
            LastName  = 'State',
            Company   = 'Skip Co',
            Status    = 'New'
        );
        insert l;

        ActionCadenceStepTrackerChangeEvent evt =
            buildEvent('UPDATE', 'In Progress', 'Meaningful Connect', 'Call', l.Id);

        Test.startTest();
        CadenceStepCDCHandler.process(
            new List<ActionCadenceStepTrackerChangeEvent>{ evt }
        );
        Test.stopTest();
    }

    /* -----------------------------------------------------------
       Test Wrong Change Type (Should Skip)
    ----------------------------------------------------------- */
    @isTest
    static void testWrongChangeType() {

        Lead l = new Lead(
            FirstName = 'Wrong',
            LastName  = 'Type',
            Company   = 'Wrong Co',
            Status    = 'New'
        );
        insert l;

        ActionCadenceStepTrackerChangeEvent evt =
            buildEvent('DELETE', 'Completed', 'Meaningful Connect', 'Call', l.Id);

        Test.startTest();
        CadenceStepCDCHandler.process(
            new List<ActionCadenceStepTrackerChangeEvent>{ evt }
        );
        Test.stopTest();
    }

    /* -----------------------------------------------------------
       Test Lead Not in 'New' Status (Should Not Update)
    ----------------------------------------------------------- */
    @isTest
    static void testLeadNotNewStatus() {

        Lead l = new Lead(
            FirstName = 'Old',
            LastName  = 'Lead',
            Company   = 'Old Co',
            Status    = 'Working'
        );
        insert l;

        ActionCadenceStepTrackerChangeEvent evt =
            buildEvent('CREATE', 'Completed', 'Meaningful Connect', 'Call', l.Id);

        Test.startTest();
        CadenceStepCDCHandler.process(
            new List<ActionCadenceStepTrackerChangeEvent>{ evt }
        );
        Test.stopTest();
    }

    /* -----------------------------------------------------------
       Test Non-Lead TargetId (Should Skip)
    ----------------------------------------------------------- */
    @isTest
    static void testNonLeadTargetId() {

        Account acc = new Account(Name = 'Test Account');
        insert acc;

        ActionCadenceStepTrackerChangeEvent evt =
            buildEvent('CREATE', 'Completed', 'Meaningful Connect', 'Call', acc.Id);

        Test.startTest();
        CadenceStepCDCHandler.process(
            new List<ActionCadenceStepTrackerChangeEvent>{ evt }
        );
        Test.stopTest();
    }

    /* -----------------------------------------------------------
       Test Empty Event List
    ----------------------------------------------------------- */
    @isTest
    static void testEmptyEvents() {

        Test.startTest();
        CadenceStepCDCHandler.process(
            new List<ActionCadenceStepTrackerChangeEvent>()
        );
        Test.stopTest();
    }

    /* -----------------------------------------------------------
       Test Null Input
    ----------------------------------------------------------- */
    @isTest
    static void testNullEvents() {

        Test.startTest();
        CadenceStepCDCHandler.process(null);
        Test.stopTest();
    }
}