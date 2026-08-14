@isTest
private class HistoryTrackingControllerTest {

    @isTest
    static void testProcessChanges() {
        Lead oldLead = new Lead(
            Id = '00Q000000000000AAA',
            LastName = 'Smith',
            Company = 'Old Company',
            Title = null
        );

        Lead newLead = new Lead(
            Id = '00Q000000000000AAA',
            LastName = 'Smith',
            Company = null,
            Title = 'New Title'
        );

        List<Lead> newList = new List<Lead>{ newLead };
        Map<Id, Lead> oldMap = new Map<Id, Lead>{ oldLead.Id => oldLead };

        Test.startTest();
        HistoryTrackingController.processChanges(newList, oldMap, 'Lead');
        Test.stopTest();
    }

    @isTest
    static void testGetHistoryLog() {
        Lead testLead = new Lead(LastName = 'Log Test', Company = 'Test Corp');
        insert testLead;

        History_Tracking__c testLog = new History_Tracking__c(
            Parent_ID__c = testLead.Id,
            Field_Name__c = 'Company',
            Old_Value__c = 'Old Value',
            New_Value__c = 'New Value',
            Action__c = 'Update'
        );
        insert testLog;

        Test.startTest();
        HistoryTrackingController.getHistoryLog(testLead.Id);
        Test.stopTest();
    }
}