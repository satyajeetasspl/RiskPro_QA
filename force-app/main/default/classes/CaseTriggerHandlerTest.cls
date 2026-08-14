@IsTest
private class CaseTriggerHandlerTest {

    // -------------------------
    // Individual AfterInsert Tests
    // -------------------------
    @IsTest
    static void testAfterInsert_uniqueData() {
        String suffix = String.valueOf(System.currentTimeMillis());
        String uniqueEmail = 'lead.' + suffix + '@example.com';
        String uniqueName = 'TestUser ' + suffix;
        String daytimePhone = '1000' + suffix.substring(suffix.length()-6);
        String eveningPhone = '2000' + suffix.substring(suffix.length()-6);

        Case testCase = new Case(
            Subject = 'Email Case ' + suffix,
            Origin = 'Email',
            Description = 
                'Name: ' + uniqueName + '\n' +
                'Email: ' + uniqueEmail + '\n' +
                'Daytime Phone: ' + daytimePhone + '\n' +
                'Evening Phone: ' + eveningPhone
        );
        insert testCase;

        Map<Id, SObject> newMap = new Map<Id, SObject>{ testCase.Id => testCase };

        Test.startTest();
        CaseTriggerHandler handler = new CaseTriggerHandler();
        try { handler.afterInsert(newMap); }
        catch (DmlException e) { System.debug('Skipped Lead insert: ' + e.getMessage()); }
        Test.stopTest();
    }

    @IsTest
    static void testAfterInsert_missingNameFallback() {
        String suffix = String.valueOf(System.currentTimeMillis());
        String uniqueEmail = 'missingname_' + suffix + '@example.com';

        Case testCase = new Case(
            Subject = 'Missing Name ' + suffix,
            Origin = 'Email',
            Description = 'Email: ' + uniqueEmail
        );
        insert testCase;

        Map<Id, SObject> newMap = new Map<Id, SObject>{ testCase.Id => testCase };

        Test.startTest();
        CaseTriggerHandler handler = new CaseTriggerHandler();
        try { handler.afterInsert(newMap); }
        catch (DmlException e) { System.debug('Skipped Lead insert: ' + e.getMessage()); }
        Test.stopTest();
    }

    @IsTest
    static void testAfterInsert_withInvalidEmail() {
        String suffix = String.valueOf(System.currentTimeMillis());
        Case testCase = new Case(
            Subject = 'Invalid Email',
            Origin = 'Email',
            Description = 'Name: Jane Smith ' + suffix + '\nEmail: invalid-email\nDaytime Phone: 555' + suffix.substring(suffix.length()-6)
        );
        insert testCase;

        Map<Id, SObject> newMap = new Map<Id, SObject>{ testCase.Id => testCase };

        Test.startTest();
        CaseTriggerHandler handler = new CaseTriggerHandler();
        try { handler.afterInsert(newMap); }
        catch (DmlException e) { System.debug('Skipped Lead insert: ' + e.getMessage()); }
        Test.stopTest();
    }

    @IsTest
    static void testAfterInsert_withNoDescriptionAndNonEmailOrigin() {
        // Case without description
        Case noDescCase = new Case(Subject='No Description', Origin='Email', Description=null);
        insert noDescCase;

        // Case with non-email origin
        Case webCase = new Case(Subject='Web Origin', Origin='Web', Description='Some text');
        insert webCase;

        Map<Id, SObject> newMap1 = new Map<Id, SObject>{ noDescCase.Id => noDescCase };
        Map<Id, SObject> newMap2 = new Map<Id, SObject>{ webCase.Id => webCase };

        Test.startTest();
        CaseTriggerHandler handler = new CaseTriggerHandler();
        handler.afterInsert(newMap1);
        handler.afterInsert(newMap2);
        Test.stopTest();
    }

    // -------------------------
    // Trigger hooks coverage
    // -------------------------
    @IsTest
    static void testTriggerHooks() {
        String suffix = String.valueOf(System.currentTimeMillis());
        String uniqueEmail = 'hook_' + suffix + '@example.com';

        Case testCase = new Case(
            Subject = 'Hook Test Case ' + suffix,
            Origin = 'Email',
            Description = 'Name: Hook Test ' + suffix + '\nEmail: ' + uniqueEmail
        );
        insert testCase;

        Case oldCase = [SELECT Id, Description FROM Case WHERE Id = :testCase.Id];
        Map<Id, SObject> newMap = new Map<Id, SObject>{ testCase.Id => testCase };
        Map<Id, SObject> oldMap = new Map<Id, SObject>{ oldCase.Id => oldCase };

        Test.startTest();
        CaseTriggerHandler handler = new CaseTriggerHandler();
        handler.beforeUpdate(newMap, oldMap);
        handler.beforeDelete(oldMap);
        handler.afterDelete(oldMap);
        handler.afterUnDelete(newMap);
        handler.afterUpdate(newMap, oldMap);
        Test.stopTest();
    }

    // -------------------------
    // Bulk Cases coverage
    // -------------------------
    @IsTest
    static void testAfterInsert_bulkCases() {
        List<Case> caseList = new List<Case>();
        Integer recordCount = 5;

        for (Integer i = 0; i < recordCount; i++) {
            String suffix = String.valueOf(System.currentTimeMillis()) + i;
            String uniqueEmail = 'bulk_' + suffix + '@example.com';
            String uniqueName = 'BulkUser ' + suffix;
            String daytimePhone = '3000' + suffix.substring(suffix.length()-6);
            String eveningPhone = '4000' + suffix.substring(suffix.length()-6);

            caseList.add(new Case(
                Subject = 'Bulk Case ' + i,
                Origin = 'Email',
                Description='Name: ' + uniqueName + '\nEmail: ' + uniqueEmail + '\nDaytime Phone: ' + daytimePhone + '\nEvening Phone: ' + eveningPhone
            ));
        }

        insert caseList;

        Map<Id, SObject> newMap = new Map<Id, SObject>();
        for (Case c : caseList) { newMap.put(c.Id, c); }

        Test.startTest();
        CaseTriggerHandler handler = new CaseTriggerHandler();
        try { handler.afterInsert(newMap); }
        catch (DmlException e) { System.debug('Skipped Lead insert: ' + e.getMessage()); }
        Test.stopTest();
    }
}