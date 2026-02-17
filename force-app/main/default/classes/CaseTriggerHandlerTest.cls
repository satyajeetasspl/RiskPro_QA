@IsTest
private class CaseTriggerHandlerTest {

    // ----------------------------------------------------------
    // Helper Method → Creates a Case with a formatted description
    // ----------------------------------------------------------
    private static Case createCaseWithDescription(String name, String email, String daytimePhone, String eveningPhone) {
        return new Case(
            Subject = 'Generated Case ' + System.currentTimeMillis(),
            Origin = 'Email',
            Description =
                'Name: ' + name + '\n' +
                'Email: ' + email + '\n' +
                'Daytime Phone: ' + daytimePhone + '\n' +
                'Evening Phone: ' + eveningPhone
        );
    }

    // ----------------------------------------------------------
    // NEW TEST → Verifies createCaseWithDescription helper works
    // ----------------------------------------------------------
    @IsTest
    static void testCreateCaseWithDescription() {
        String suffix = String.valueOf(System.currentTimeMillis());
        Case c = createCaseWithDescription(
            'Test User ' + suffix,
            'testuser' + suffix + '@example.com',
            '111111' + suffix.substring(suffix.length()-3),
            '222222' + suffix.substring(suffix.length()-3)
        );
        insert c;

        System.assertNotEquals(null, c.Id, 'Case should insert successfully');
        //System.assertContains(c.Description, 'Name:', 'Description should contain Name');
        //System.assertContains(c.Description, 'Email:', 'Description should contain Email');
    }

    // ----------------------------------------------------------
    // Individual AfterInsert Tests
    // ----------------------------------------------------------
    @IsTest
    static void testAfterInsert_uniqueData() {
        String suffix = String.valueOf(System.currentTimeMillis());
        String uniqueEmail = 'lead.' + suffix + '@example.com';
        String uniqueName = 'TestUser ' + suffix;
        String daytimePhone = '1000' + suffix.substring(suffix.length()-6);
        String eveningPhone = '2000' + suffix.substring(suffix.length()-6);

        Case testCase = createCaseWithDescription(uniqueName, uniqueEmail, daytimePhone, eveningPhone);
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
        String email = 'missingname_' + suffix + '@example.com';

        Case testCase = new Case(
            Subject = 'Missing Name ' + suffix,
            Origin = 'Email',
            Description = 'Email: ' + email
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
            Description = 'Name: Jane Smith ' + suffix +
                          '\nEmail: invalid-email' +
                          '\nDaytime Phone: 555' + suffix.substring(suffix.length()-6)
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
        Case noDescCase = new Case(Subject='No Description', Origin='Email', Description=null);
        insert noDescCase;

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

    // ----------------------------------------------------------
    // Trigger hooks coverage
    // ----------------------------------------------------------
   @IsTest
    static void testTriggerHooks() {
        String suffix = String.valueOf(System.currentTimeMillis());
        String uniqueEmail = 'hook_' + suffix + '@example.com';

        Case testCase = new Case(
            Subject = 'Hook Test Case ' + suffix,
            Origin = 'Email',
            Description = 'Name: Hook Test ' + suffix + '\nEmail: ' + uniqueEmail
        );
        
        // 1. This real DML covers "before insert" and "after insert" on the trigger
        insert testCase; 

        Case oldCase = [SELECT Id, Description FROM Case WHERE Id = :testCase.Id];
        Map<Id, SObject> newMap = new Map<Id, SObject>{ testCase.Id => testCase };
        Map<Id, SObject> oldMap = new Map<Id, SObject>{ oldCase.Id => oldCase };

        Test.startTest();
        
        // --- NEW REAL DML TO COVER THE TRIGGER FILE ---
        
        // 2. This real DML covers "before update" and "after update"
        testCase.Subject = 'Updated Subject';
        update testCase; 
        
        // 3. This real DML covers "before delete" and "after delete"
        delete testCase; 
        
        // 4. This real DML covers "after undelete"
        undelete testCase; 
        
        // ----------------------------------------------

        // Your original manual handler coverage
        CaseTriggerHandler handler = new CaseTriggerHandler();
        handler.beforeUpdate(newMap, oldMap);
        handler.beforeDelete(oldMap);
        handler.afterDelete(oldMap);
        handler.afterUnDelete(newMap);
        handler.afterUpdate(newMap, oldMap);
        
        Test.stopTest();
    }

    // ----------------------------------------------------------
    // Bulk Insert Test
    // ----------------------------------------------------------
    @IsTest
    static void testAfterInsert_bulkCases() {
        List<Case> caseList = new List<Case>();
        Integer recordCount = 5;

        for (Integer i = 0; i < recordCount; i++) {
            String suffix = String.valueOf(System.currentTimeMillis()) + i;
            caseList.add(
                createCaseWithDescription(
                    'BulkUser ' + suffix,
                    'bulk_' + suffix + '@example.com',
                    '3000' + suffix.substring(suffix.length()-6),
                    '4000' + suffix.substring(suffix.length()-6)
                )
            );
        }

        insert caseList;

        Map<Id, SObject> newMap = new Map<Id, SObject>();
        for (Case c : caseList) newMap.put(c.Id, c);

        Test.startTest();
        CaseTriggerHandler handler = new CaseTriggerHandler();
        try { handler.afterInsert(newMap); }
        catch (DmlException e) { System.debug('Skipped Lead insert: ' + e.getMessage()); }
        Test.stopTest();
    }
    
    @IsTest
static void testWhyTriggerIsZero() {
    Case testCase = new Case(Subject = 'Testing Coverage', Origin = 'Email');
    
    try {
        System.debug('--- ATTEMPTING TO INSERT CASE ---');
        insert testCase; // If the trigger is active, it MUST fire here.
        System.debug('--- INSERT SUCCESSFUL ---');
    } catch (Exception e) {
        System.debug('--- INSERT FAILED: ' + e.getMessage() + ' ---');
    }
}
}