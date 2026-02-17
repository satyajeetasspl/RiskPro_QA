@IsTest
private class CaseHelperTest {

    @IsTest
    static void testParseDescription_AllFields_TwoAddresses_Unmapped() {
        Case c = new Case(
            Subject = 'Parse All Fields',
            Origin  = 'Web',
            Description =
                // Name includes extra label text to verify trimming logic
                'Name: John Michael Doe DAYTIME PHONE 111-111-1111\n' +
                'Daytime Phone: 123-456-7890\n' +
                'Evening Phone: 098-765-4321\n' +
                // mailto-like / bracket-ish formats (your helper tries to clean)
                'Email: [john.doe@example.com]\n' +
                'Birthdate: 02/15/1988\n' +
                // 1st address set = insured address
                'Address: 123 Main St\n' +
                'City, State ZIP: Raleigh NC 27609\n' +
                // 2nd address set = property address (based on helper’s "second occurrence" logic)
                'Address: 456 Elm St\n' +
                'City, State ZIP: Durham NC 27701\n' +
                // Unmapped fields should be appended into Lead.Description
                'Loan Amount: 250000\n' +
                'Foo Bar: Baz\n'
        );
        insert c;

        Test.startTest();
        List<Lead> leads = CaseHelper.parseDescription(new List<Id>{ c.Id });
        Test.stopTest();

        System.assertEquals(1, leads.size(), 'Should return one Lead for one Case');
        Lead l = leads[0];

        // Name parsing: should set FirstName and LastName
        System.assertEquals('John', l.FirstName, 'FirstName should be parsed from name');
        System.assert(String.isNotBlank(l.LastName), 'LastName should not be blank');

        // Simple fields
        System.assertEquals('123-456-7890', l.Borrowers_Phone_Number__c);
        System.assertEquals('098-765-4321', l.Phone_2__c);
        System.assertEquals('john.doe@example.com', l.Email, 'Email should be cleaned/validated');
        System.assertEquals(Date.newInstance(1988, 2, 15), l.Borrower_DOB__c);

        // Insured address (first occurrence)
        System.assertEquals('123 Main St', l.Insured_Address__Street__s);
        System.assertEquals('Raleigh', l.Insured_Address__City__s);
        System.assertEquals('NC', l.Insured_Address__StateCode__s);
        System.assertEquals('27609', l.Insured_Address__PostalCode__s);
        System.assertEquals('US', l.Insured_Address__CountryCode__s);

        // Property address (second occurrence)
        System.assertEquals('456 Elm St', l.Street);
        System.assertEquals('Durham', l.City);
        System.assertEquals('NC', l.State);
        System.assertEquals('27701', l.PostalCode);

        // Defaults set by helper
        System.assertEquals('Online Leads', l.LeadSource);
        System.assertEquals('Hometown Quotes', l.Referral_Source_Name__c);

        // Unmapped keys appended to Lead.Description
        System.assert(String.isNotBlank(l.Description), 'Unmapped fields should be appended to Lead.Description');
        System.assert(l.Description.contains('LOAN AMOUNT: 250000'), 'Expected unmapped field to be added');
        System.assert(l.Description.contains('FOO BAR: Baz'), 'Expected unmapped field to be added');
    }

    @IsTest
    static void testParseDescription_NullAndEmptyIds_ReturnEmpty() {
        Test.startTest();
        List<Lead> a = CaseHelper.parseDescription(null);
        List<Lead> b = CaseHelper.parseDescription(new List<Id>());
        Test.stopTest();

        System.assertEquals(0, a.size());
        System.assertEquals(0, b.size());
    }

    @IsTest
    static void testParseDescription_BlankDescription_SkipsCase() {
        Case c = new Case(Subject='Blank Desc', Origin='Email', Description='');
        insert c;

        List<Lead> leads = CaseHelper.parseDescription(new List<Id>{ c.Id });
        System.assertEquals(0, leads.size(), 'Blank description should produce no leads');
    }

    @IsTest
    static void testParseDescription_InvalidEmail_InvalidDate_BadCityStateZip() {
        Case c = new Case(
            Subject='Invalid Values',
            Origin='Email',
            Description =
                'Name: SingleName\n' +
                'Email: not-an-email\n' +
                'Birthdate: 13/40/9999\n' +
                // Bad format (no zip / missing spaces) => parseCityStateZip should return null
                'Address: 1 Test St\n' +
                'City, State ZIP: BADFORMAT\n' +
                // Unmapped to ensure Description gets something even if parsing fails
                'Extra: Value\n'
        );
        insert c;

        List<Lead> leads = CaseHelper.parseDescription(new List<Id>{ c.Id });
        System.assertEquals(1, leads.size());

        Lead l = leads[0];

        // Name: Single token -> LastName only
       

        // Address line set, but city/state/zip should remain null due to bad parsing
        System.assertEquals('1 Test St', l.Insured_Address__Street__s);
        System.assertEquals(null, l.Insured_Address__City__s);
        System.assertEquals(null, l.Insured_Address__StateCode__s);
        System.assertEquals(null, l.Insured_Address__PostalCode__s);

        // Unmapped should still be appended
        System.assert(String.isNotBlank(l.Description));
        System.assert(l.Description.contains('EXTRA: Value'));
    }

    @IsTest
    static void testParseDescription_EnsuresLastNameFallbackUnknown() {
        // If name isn't present, helper sets LastName = 'Unknown'
        Case c = new Case(
            Subject='No Name',
            Origin='Web',
            Description='Email: test@example.com\n'
        );
        insert c;

        List<Lead> leads = CaseHelper.parseDescription(new List<Id>{ c.Id });
        System.assertEquals(1, leads.size());
        System.assertEquals('Unknown', leads[0].LastName, 'Should default LastName to Unknown when blank');
    }
}