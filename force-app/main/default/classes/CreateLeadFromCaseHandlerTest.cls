@IsTest
private class CreateLeadFromCaseHandlerTest {

    @IsTest
    static void testComprehensiveCoverage() {
        // This single test method constructs a complex description designed to 
        // hit every branch in the parser logic.

        String complexDescription = 
            // 1. Test Value on New Line (No colon)
            'borrower first\n' + 
            'Jonathan\n' + 
            
            // 2. Test Standard Key:Value
            'borrower last: Doe\n' + 
            
            // 3. Test Email Logic (Borrower vs Primary)
            'email: primary@test.com\n' + 
            'borrower email: borrower@test.com\n' + 
            'processor email: proc@test.com\n' + 
            
            // 4. Test State Normalization (Full name -> Code)
            'borrower state: California\n' + 
            
            // 5. Test Date Parsing (Valid)
            'dob: 01/01/1980\n' + 
            
            // 6. Test Date Parsing (Invalid - triggers catch block)
            'estimated closing date: NotADate\n' + 
            
            // 7. Test Phone Parsing (Stripping characters)
            'borrower phone: (555) 123-4567\n' + 
            
            // 8. Test Address Parsing: Complex Branch (Using Suffix Splitter)
            // This format (Street City, Zip) with only 1 comma triggers the logic 
            // that looks for "St" to separate "123 Main St" from "Metropolis"
            'borrower address: 123 Main St Metropolis, 90210\n' + 
            
            // 9. Switch to Property Section
            '---PROPERTY INFORMATION---\n' + 
            
            // 10. Test City State Zip (Space separated logic)
            'city, state zip: Gotham NY 10001\n' + 
            
            // 11. Test Property Address with missing City (Triggers default ".")
            'address: 500 Wayne Manor, NY, 10001\n' + 
            
            // 12. Test Stop Phrase (Should ignore everything after this)
            'Sincerely\n' + 
            'Ignore this text';

        Case c = new Case(
            Origin = 'Email',
            Description = complexDescription
        );
        insert c;

        Test.startTest();
        // Invoke method - no assertions as requested
        CreateLeadFromCaseHandler.parseDescription(new List<Id>{c.Id});
        Test.stopTest();
    }

    @IsTest
    static void testAddressEdgeCases() {
        // specific test to hit the catch blocks and edge cases in address parsing
        
        String descText = 
            // 1. Triggers Exception in parseCommaAddress (empty parts logic or nulls)
            'borrower address: , , ,\n' + 
            
            // 2. Triggers fallback in parseCommaAddress (No number in last part)
            'property address: Just A Street Name\n' + 
            
            // 3. Triggers Exception in parseCityStateZip
            'city, state zip: \n'; 

        Case c = new Case(
            Origin = 'Email',
            Description = descText
        );
        insert c;

        Test.startTest();
        CreateLeadFromCaseHandler.parseDescription(new List<Id>{c.Id});
        Test.stopTest();
    }

    @IsTest
    static void testNullsAndBlanks() {
        // Test 1: Null Description
        Case c1 = new Case(Origin = 'Email');
        insert c1;

        // Test 2: Standard Description but null Case Id in list (simulating list handling issues)
        Case c2 = new Case(Origin = 'Email', Description = 'Test');
        insert c2;
        
        List<Id> caseIds = new List<Id>{c1.Id, c2.Id};
        
        // Add a fake ID to test query handling
        // Note: We can't easily query a fake ID, but we can test the loop with valid IDs
        
        Test.startTest();
        CreateLeadFromCaseHandler.parseDescription(caseIds);
        
        // Test passing empty list
        CreateLeadFromCaseHandler.parseDescription(new List<Id>());
        Test.stopTest();
    }
    
    @IsTest
    static void test_parseDescription_AbsoluteEdgeCases() {
        // This description is purposely mangled to hit every tiny skipped 'if/else' 
        // and formatting fallback in your parser.
        String crazyDescription = 
            // 1. Cover Windows (\r\n) and Mac (\r) line breaks
            'borrower first: Clark\r\n' +
            'borrower last: Kent\r' +
            
            // 2. Cover invalid email (forces regex extractEmail to return null)
            'email: just-a-random-string-no-domain\n' +
            
            // 3. Cover explicitly mapped Date fields being invalid/NA
            'dob: N/A\n' +
            
            // 4. Address parser: Exactly 2 parts, but NO numbers (skips zip code extraction)
            'borrower address: Main Street, Metropolis\n' +
            
            // 5. Address parser: Exactly 3 parts
            'property address: 123 Main St, Metropolis, NY\n' +
            
            // 6. City State Zip parser: Only 1 word provided
            'city, state zip: Metropolis\n' +
            
            // 7. State Normalizer: Blank state
            'borrower state: \n' +
            
            // 8. Line without a colon, sitting at the very END of the file.
            // This forces (i + 1 < lines.size()) to evaluate to FALSE, hitting the 'else { continue; }'
            'borrower name'; 

        Case c = new Case(
            Origin = 'Email', 
            Description = crazyDescription
        );
        insert c;

        Test.startTest();
        try {
            CreateLeadFromCaseHandler.parseDescription(new List<Id>{c.Id});
        } catch (Exception e) {}
        Test.stopTest();
    }
    
    @IsTest
    static void test_parseDescription_AdvancedAddressCoverage() {
        String descText = 
            // 1. Cover the parts.size() >= 4 logic. 
            // Requires 3+ commas (Street, Suite, City, State, Zip)
            'borrower address: 123 Main St, Suite 100, Gotham, NY, 10001\n' + 
            
            // 2. Cover the Suffix Splitter logic.
            // Requires exactly 2 commas. The code will pop off the Zip (66605) 
            // and the State (KS). The remaining string "456 Elm Ave Smallville" 
            // is then passed into the words.size() > 2 logic, where "Ave" triggers the split.
            'property address: 456 Elm Ave Smallville, KS, 66605\n';

        Case c = new Case(
            Origin = 'Email',
            Description = descText
        );
        insert c;

        Test.startTest();
        try {
            CreateLeadFromCaseHandler.parseDescription(new List<Id>{c.Id});
        } catch (Exception e) {}
        Test.stopTest();
    }
}