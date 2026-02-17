@IsTest
public class RecordAuditControllerTest {

    @IsTest
    static void testBlankRecordId() {
        Test.startTest();
        List<RecordAuditController.AuditWrapper> res =
            RecordAuditController.getFieldAuditLogs(null);
        Test.stopTest();
    }

    @IsTest
    static void testNoLogsFound() {
        Account acc = new Account(Name = 'Audit Parent 1');
        insert acc;

        Test.startTest();
        List<RecordAuditController.AuditWrapper> res =
            RecordAuditController.getFieldAuditLogs(acc.Id);
        Test.stopTest();
    }

    @IsTest
    static void testSingleLogRecord() {
        Account acc = new Account(Name = 'Audit Parent 2');
        insert acc;

        Note_History_Logs__c log = new Note_History_Logs__c(
            Parent_Record_Id__c = acc.Id,
            Field_Name__c = 'Title',
            Old_Value__c = 'Old Title',
            New_Value__c = 'New Title'
        );
        insert log;

        Test.startTest();
        List<RecordAuditController.AuditWrapper> res =
            RecordAuditController.getFieldAuditLogs(acc.Id);
        Test.stopTest();
    }

    @IsTest
    static void testMultipleLogsSameTransaction() {
        Account acc = new Account(Name = 'Audit Parent 3');
        insert acc;

        List<Note_History_Logs__c> logs = new List<Note_History_Logs__c>{
            new Note_History_Logs__c(
                Parent_Record_Id__c = acc.Id,
                Field_Name__c = 'Title',
                Old_Value__c = 'Old T',
                New_Value__c = 'New T'
            ),
            new Note_History_Logs__c(
                Parent_Record_Id__c = acc.Id,
                Field_Name__c = 'Body',
                Old_Value__c = 'Old B',
                New_Value__c = 'New B'
            )
        };
        insert logs;

        Test.startTest();
        List<RecordAuditController.AuditWrapper> res =
            RecordAuditController.getFieldAuditLogs(acc.Id);
        Test.stopTest();
    }

    @IsTest
    static void testMultipleLogsDifferentGroups() {
        Account acc = new Account(Name = 'Audit Parent 4');
        insert acc;

        // First group
        insert new Note_History_Logs__c(
            Parent_Record_Id__c = acc.Id,
            Field_Name__c = 'Title',
            Old_Value__c = 'Old 1',
            New_Value__c = 'New 1'
        );

        // Ensure different CreatedDate by inserting later
        Test.startTest();
        insert new Note_History_Logs__c(
            Parent_Record_Id__c = acc.Id,
            Field_Name__c = 'Status',
            Old_Value__c = 'Open',
            New_Value__c = 'Closed'
        );

        List<RecordAuditController.AuditWrapper> res =
            RecordAuditController.getFieldAuditLogs(acc.Id);
        Test.stopTest();
    }
}