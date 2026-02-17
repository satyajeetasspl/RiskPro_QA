@IsTest
public class ACStepTrackerCDCTriggerTest {

    @IsTest
    static void testProcess_NoHeader() {

        Lead l = new Lead(
            LastName = 'Test',
            Company = 'Test Co',
            Status = 'New'
        );
        insert l;

        ActionCadenceStepTrackerChangeEvent evt =
            new ActionCadenceStepTrackerChangeEvent();

        // Do NOT set ChangeEventHeader

        evt.put('State__c', 'Completed');
        evt.put('Outcome__c', 'Meaningful Connect');
        evt.put('StepType__c', 'Call');
        evt.put('TargetId__c', l.Id);

        Test.startTest();
        CadenceStepCDCHandler.process(
            new List<ActionCadenceStepTrackerChangeEvent>{ evt }
        );
        Test.stopTest();

        // No update should happen because header is null
        Lead unchanged = [SELECT Status FROM Lead WHERE Id = :l.Id];
        System.assertEquals('New', unchanged.Status);
    }
}