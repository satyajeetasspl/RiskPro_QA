@isTest
private class LeadExportControllerTest {

    @testSetup
    static void setupData() {
        // Create test Leads with different Partner Names
        List<Lead> leads = new List<Lead>();
        
        for (Integer i = 0; i < 5; i++) {
            leads.add(new Lead(
                LastName = 'Test Lead ' + i,
                Company = 'Test Company ' + i,
                Status = 'Open - Not Contacted',
                Partner_Name__c = 'Partner A',
                Email = 'test' + i + '@example.com'
            ));
        }

        for (Integer i = 0; i < 5; i++) {
            leads.add(new Lead(
                LastName = 'Test Lead B ' + i,
                Company = 'Test Company B ' + i,
                Status = 'Open - Not Contacted',
                Partner_Name__c = 'Partner B',
                Email = 'testb' + i + '@example.com'
            ));
        }
        
        insert leads;
    }

    @isTest
    static void testFetchPartnerNameOptions() {
        // Execute the method to fetch picklist options
        Test.startTest();
        LeadExportController.fetchPartnerNameOptions();
        Test.stopTest();
    }

    @isTest
    static void testFetchLeadsForTable_AllFilters() {
        // Test with all filters applied (Partner + Dates)
        Date today = Date.today();
        
        Test.startTest();
        LeadExportController.fetchLeadsForTable('Partner A', today, today);
        Test.stopTest();
    }

    @isTest
    static void testFetchLeadsForTable_PartnerOnly() {
        // Test with only Partner Name filter
        Test.startTest();
        LeadExportController.fetchLeadsForTable('Partner B', null, null);
        Test.stopTest();
    }

    @isTest
    static void testFetchLeadsForTable_DateOnly() {
        // Test with only Date filters
        Date today = Date.today();

        Test.startTest();
        LeadExportController.fetchLeadsForTable(null, today, today);
        Test.stopTest();
    }

    @isTest
    static void testFetchLeadsForTable_NoFilters() {
        // Test with no filters (nulls)
        Test.startTest();
        LeadExportController.fetchLeadsForTable(null, null, null);
        Test.stopTest();
    }

    @isTest
    static void testFetchAllFieldsForSelectedLeads() {
        // Get IDs from setup data
        Map<Id, Lead> leadsMap = new Map<Id, Lead>([SELECT Id FROM Lead LIMIT 10]);
        List<Id> leadIds = new List<Id>(leadsMap.keySet());

        Test.startTest();
        LeadExportController.fetchAllFieldsForSelectedLeads(leadIds);
        Test.stopTest();
    }

    @isTest
    static void testFetchAllFields_EmptyList() {
        // Test with null or empty list to hit the guard clause
        Test.startTest();
        LeadExportController.fetchAllFieldsForSelectedLeads(new List<Id>());
        LeadExportController.fetchAllFieldsForSelectedLeads(null);
        Test.stopTest();
    }
}