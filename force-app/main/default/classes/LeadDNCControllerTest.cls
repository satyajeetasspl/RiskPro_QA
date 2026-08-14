@isTest
private class LeadDNCControllerTest {

    @isTest
    static void testApplyDNC_NewLead() {
        // Create a Lead
        Lead testLead = new Lead(
            LastName = 'Test Lead',
            Company  = 'Test Company',
            Do_Not_Call__c = false,
            Status   = 'Open - Not Contacted'
        );
        insert testLead;

        // Add a future Event
        Event futureEvent = new Event(
            Subject = 'Future Meeting',
            StartDateTime = System.now().addDays(2),
            EndDateTime   = System.now().addDays(2).addHours(1),
            WhoId = testLead.Id
        );
        insert futureEvent;

        // Add an open Task
        Task openTask = new Task(
            Subject = 'Call Lead',
            Status  = 'Not Started',
            WhoId   = testLead.Id
        );
        insert openTask;

        Test.startTest();
        LeadDNCController.applyDNC(testLead.Id);
        Test.stopTest();
    }

    @isTest
    static void testApplyDNC_AlreadyDNC() {
        Lead testLead = new Lead(
            LastName = 'Already DNC',
            Company  = 'Test Co',
            Do_Not_Call__c = true,
            Status   = 'Closed - Not Converted'
        );
        insert testLead;

        Test.startTest();
        try {
            LeadDNCController.applyDNC(testLead.Id);
        } catch (Exception e) {
            // expected
        }
        Test.stopTest();
    }

    @isTest
    static void testApplyDNC_NullId() {
        Test.startTest();
        try {
            LeadDNCController.applyDNC(null);
        } catch (Exception e) {
            // expected
        }
        Test.stopTest();
    }

    @isTest
    static void testApplyDNC_BulkLeads() {
        List<Lead> leads = new List<Lead>();
        for (Integer i = 0; i < 3; i++) {
            leads.add(new Lead(
                LastName = 'BulkLead ' + i,
                Company  = 'Bulk Test Co ' + i,
                Do_Not_Call__c = false,
                Status   = 'Open - Not Contacted'
            ));
        }
        insert leads;

        Test.startTest();
        for (Lead l : leads) {
            LeadDNCController.applyDNC(l.Id);
        }
        Test.stopTest();
    }
}