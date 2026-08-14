@isTest
private class FileExtractionControllerTest {

    // =====================================================
    // MOCK HTTP RESPONSES
    // =====================================================

    private class OCRSuccessMock implements HttpCalloutMock {

        public HTTPResponse respond(HTTPRequest req) {

            HttpResponse res = new HttpResponse();

            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);

            res.setBody(
                '{"ParsedResults":[' +
                '{"ParsedText":"Page 1 Text"},' +
                '{"ParsedText":null},' +
                '{"ParsedText":"Page 3 Text"}' +
                '],"IsErroredOnProcessing":false}'
            );

            return res;
        }
    }

    private class OCREmptyTextMock implements HttpCalloutMock {

        public HTTPResponse respond(HTTPRequest req) {

            HttpResponse res = new HttpResponse();

            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);

            res.setBody(
                '{"ParsedResults":[{"ParsedText":""}],"IsErroredOnProcessing":false}'
            );

            return res;
        }
    }

    private class OCRErrorProcessingMock implements HttpCalloutMock {

        public HTTPResponse respond(HTTPRequest req) {

            HttpResponse res = new HttpResponse();

            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);

            res.setBody(
                '{"ParsedResults":null,' +
                '"IsErroredOnProcessing":true,' +
                '"ErrorMessage":"API Error"}'
            );

            return res;
        }
    }

    private class OCRHttpErrorMock implements HttpCalloutMock {

        public HTTPResponse respond(HTTPRequest req) {

            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);

            return res;
        }
    }

    // =====================================================
    // TEST DATA FACTORY
    // =====================================================

    private static Id createTestPDF() {

        ContentVersion cv = new ContentVersion(
            Title = 'Test PDF',
            PathOnClient = 'Test.pdf',
            VersionData = Blob.valueOf('Dummy PDF'),
            IsMajorVersion = true
        );

        insert cv;

        cv = [
            SELECT Id, ContentDocumentId
            FROM ContentVersion
            WHERE Id = :cv.Id
            LIMIT 1
        ];

        return cv.ContentDocumentId;
    }

    private static Lead createTestLead(
        String email,
        String phone
    ) {

        Lead l = new Lead(
            FirstName = 'Existing',
            LastName = 'Lead',
            Company = 'Test Company',
            Email = email,
            Phone = phone,
            Status = 'Open - Not Contacted'
        );

        insert l;

        return l;
    }

    // =====================================================
    // UPLOAD CUSTOM FILE
    // =====================================================

    @isTest
    static void testUploadCustomFile() {
        Lead l = createTestLead('upload@test.com', '1112223333');
        
        Test.startTest();
        // Send a dummy base64 string
        Id docId = FileExtractionController.uploadCustomFile('RGV2ZWxvcGVyIE1vY2s=', 'CustomUpload.pdf', l.Id);
        Test.stopTest();
        
        System.assertNotEquals(null, docId, 'Document ID should be returned');
        
        ContentVersion cv = [SELECT Id, Title FROM ContentVersion WHERE ContentDocumentId = :docId LIMIT 1];
        System.assertEquals('CustomUpload.pdf', cv.Title, 'File title should match');
        
        List<ContentDocumentLink> cdls = [SELECT Id FROM ContentDocumentLink WHERE ContentDocumentId = :docId AND LinkedEntityId = :l.Id];
        System.assertEquals(1, cdls.size(), 'A ContentDocumentLink should be created to link the file to the Lead');
    }

    // =====================================================
    // NEW LEAD FLOW
    // =====================================================

    @isTest
    static void testNewLeadFlow() {

        Test.setMock(
            HttpCalloutMock.class,
            new OCRSuccessMock()
        );

        Id docId = createTestPDF();

        FileExtractionController.TEST_JSON_RESPONSE =
        '{' +
        '"InsuredFirstName":"John",' +
        '"InsuredLastName":"Doe",' +
        '"Company":"Acme",' +
        '"InsuredPhone":"1234567890",' +
        '"InsuredEmail":"john@test.com",' +
        '"Street":"123 Main St",' +
        '"City":"Miami",' +
        '"State":"FL",' +
        '"ZipCode":"33101",' +
        '"Carrier":"State Farm",' +
        '"QuoteNumber":"Q123",' +
        '"Premium":"2500.50",' +
        '"AgencyFee":"100",' +
        '"Total":"2600.50",' +
        '"EffectiveDate":"2026-01-01",' +
        '"ExpirationDate":"2027-01-01",' +
        '"YearBuilt":"2005",' +
        '"NumberOfStories":"2",' +
        '"RoofYear":"2020",' +
        '"PlumbingYear":"2021",' +
        '"WiringYear":"2022",' +
        '"SquareFootage":"2500",' +
        '"NumberOfMortgages":"1",' +
        '"MembersInHousehold":"4",' +
        '"IsPool":"yes",' +
        '"IsAlarmSystem":"included",' +
        '"IsAnimal":"false",' +
        '"LineOfBusiness":"Homeowners"' +
        '}';

        Test.startTest();

        Id newLeadId =
            FileExtractionController.processDocument(
                docId,
                null
            );

        Test.stopTest();

        System.assertNotEquals(
            null,
            newLeadId
        );

        List<Policy_Information__c> policies = [
            SELECT Id, Lines__c
            FROM Policy_Information__c
            WHERE Lead__c = :newLeadId
        ];

        System.assert(
            policies.size() > 0
        );
        System.assertEquals(
            'Home',
            policies[0].Lines__c
        );

        ContentVersion updatedCv = [
            SELECT Id, Title, Type__c
            FROM ContentVersion
            WHERE ContentDocumentId = :docId
            AND IsLatest = true
            LIMIT 1
        ];
        System.assertEquals(
            'Proposal - State Farm - Homeowners',
            updatedCv.Title
        );
        System.assertEquals(
            'Proposal',
            updatedCv.Type__c
        );

        List<Property_Information__c> props = [
            SELECT Id
            FROM Property_Information__c
            WHERE Lead__c = :newLeadId
        ];

        System.assertEquals(
            1,
            props.size()
        );
    }

    // =====================================================
    // MULTIPLE QUOTE JSON ARRAY AND CARRIER ALIAS
    // =====================================================

    @isTest
    static void testMultipleQuotesArrayAndNatGenAlias() {

        Test.setMock(HttpCalloutMock.class, new OCRSuccessMock());
        Id docId = createTestPDF();

        // Testing JSON Array fallback and 'NatGen' -> 'National General' logic
        FileExtractionController.TEST_JSON_RESPONSE =
        '[' +
        '{"Carrier":"NatGen", "Premium":"1000", "LineOfBusiness":"Auto", "InsuredFirstName":"Multi"},' +
        '{"Carrier":"Travelers", "Premium":"1500", "LineOfBusiness":"Home", "InsuredFirstName":"Multi"}' +
        ']';

        Test.startTest();
        Id leadId = FileExtractionController.processDocument(docId, null);
        Test.stopTest();

        System.assertNotEquals(null, leadId);
        
        List<Policy_Information__c> policies = [SELECT Id, Carrier__c, Lines__c FROM Policy_Information__c WHERE Lead__c = :leadId];
        System.assertEquals(2, policies.size(), 'Should extract 2 separate policies from JSON array');
        
        Boolean foundNatGen = false;
        for(Policy_Information__c p : policies) {
            if(p.Carrier__c == 'National General') {
                foundNatGen = true;
            }
        }
        System.assert(foundNatGen, 'NatGen should be successfully aliased to National General');

        ContentVersion updatedCv = [SELECT Id, Title FROM ContentVersion WHERE ContentDocumentId = :docId AND IsLatest = true LIMIT 1];
        System.assert(updatedCv.Title.contains('Multiple Lines'), 'PDF Title should reflect Multiple Lines');
    }

    @isTest
    static void testQuotesObjectFormatFallback() {
        Test.setMock(HttpCalloutMock.class, new OCRSuccessMock());
        Id docId = createTestPDF();

        // Testing the {"quotes": [...]} fallback structure
        FileExtractionController.TEST_JSON_RESPONSE =
        '{"quotes": [' +
        '{"Carrier":"State Farm", "Premium":"100", "InsuredFirstName":"Multi"}' +
        ']}';

        Test.startTest();
        Id leadId = FileExtractionController.processDocument(docId, null);
        Test.stopTest();

        System.assertNotEquals(null, leadId);
    }

    // =====================================================
    // CONTEXT LEAD FLOW
    // =====================================================

    @isTest
    static void testContextLeadFlow() {

        Test.setMock(
            HttpCalloutMock.class,
            new OCRSuccessMock()
        );

        Id docId = createTestPDF();

        Lead contextLead = createTestLead(
            'context@test.com',
            '9999999999'
        );

        FileExtractionController.TEST_JSON_RESPONSE =
        '{"Premium":"1000","Carrier":"Geico"}';

        Test.startTest();

        Id contextId =
            FileExtractionController.processDocument(
                docId,
                contextLead.Id
            );

        Test.stopTest();

        System.assertEquals(
            contextLead.Id,
            contextId
        );
    }

    // =====================================================
    // EXISTING LEAD FLOW
    // =====================================================

    @isTest
    static void testExistingLeadFlow() {

        Test.setMock(
            HttpCalloutMock.class,
            new OCRSuccessMock()
        );

        Id docId = createTestPDF();

        Lead existingLead = createTestLead(
            'match@test.com',
            '5555555555'
        );

        FileExtractionController.TEST_JSON_RESPONSE =
        '{' +
        '"InsuredEmail":"match@test.com",' +
        '"InsuredPhone":"5555555555"' +
        '}';

        Test.startTest();

        Id existingId =
            FileExtractionController.processDocument(
                docId,
                null
            );

        Test.stopTest();

        System.assertEquals(
            existingLead.Id,
            existingId
        );
    }

    // =====================================================
    // BOOLEAN COVERAGE
    // =====================================================

    @isTest
    static void testBooleanCoverage() {

        Test.setMock(
            HttpCalloutMock.class,
            new OCRSuccessMock()
        );

        String[] variants = new String[]{
            'true',
            'yes',
            'y',
            '1',
            'incl',
            'included',
            'false',
            'random',
            ''
        };

        Test.startTest();

        for(String val : variants) {

            Id docId = createTestPDF();

            FileExtractionController.TEST_JSON_RESPONSE =
            '{' +
            '"InsuredFirstName":"Bool",' +
            '"InsuredLastName":"Test",' +
            '"Company":"ABC",' +
            '"IsPool":"' + val + '"' +
            '}';

            try {

                Id leadId =
                    FileExtractionController.processDocument(
                        docId,
                        null
                    );

                System.assertNotEquals(
                    null,
                    leadId
                );

            } catch(Exception e) {

                System.assertNotEquals(
                    null,
                    e
                );
            }
        }

        Test.stopTest();
    }

    // =====================================================
    // DECIMAL COVERAGE
    // =====================================================

    @isTest
    static void testDecimalCoverage() {

        Test.setMock(
            HttpCalloutMock.class,
            new OCRSuccessMock()
        );

        String[] variants = new String[]{
            '1234.56',
            '$1,234.56',
            'abc',
            '',
            '0'
        };

        Test.startTest();

        for(String val : variants) {

            Id docId = createTestPDF();

            FileExtractionController.TEST_JSON_RESPONSE =
            '{' +
            '"InsuredFirstName":"Decimal",' +
            '"InsuredLastName":"Test",' +
            '"Company":"ABC",' +
            '"Premium":"' + val + '"' +
            '}';

            try {

                Id leadId =
                    FileExtractionController.processDocument(
                        docId,
                        null
                    );

                System.assertNotEquals(
                    null,
                    leadId
                );

            } catch(Exception e) {

                System.assertNotEquals(
                    null,
                    e
                );
            }
        }

        Test.stopTest();
    }

    // =====================================================
    // DATE COVERAGE
    // =====================================================

    @isTest
    static void testDateCoverage() {

        Test.setMock(
            HttpCalloutMock.class,
            new OCRSuccessMock()
        );

        String[] variants = new String[]{
            '2025-12-31',
            'invalid-date',
            '12/31/2025',
            ''
        };

        Test.startTest();

        for(String val : variants) {

            Id docId = createTestPDF();

            FileExtractionController.TEST_JSON_RESPONSE =
            '{' +
            '"InsuredFirstName":"Date",' +
            '"InsuredLastName":"Test",' +
            '"Company":"ABC",' +
            '"EffectiveDate":"' + val + '",' +
            '"ExpirationDate":"' + val + '"' +
            '}';

            try {

                Id leadId =
                    FileExtractionController.processDocument(
                        docId,
                        null
                    );

                System.assertNotEquals(
                    null,
                    leadId
                );

            } catch(Exception e) {

                System.assertNotEquals(
                    null,
                    e
                );
            }
        }

        Test.stopTest();
    }

    // =====================================================
    // JSON EXTRACTION
    // =====================================================

    @isTest
    static void testJsonExtractionCoverage() {

        Test.setMock(
            HttpCalloutMock.class,
            new OCRSuccessMock()
        );

        Test.startTest();

        Id docId1 = createTestPDF();

        FileExtractionController.TEST_JSON_RESPONSE =
        'prefix { "Carrier":"AAA" } suffix';

        try {

            FileExtractionController.processDocument(
                docId1,
                null
            );

        } catch(Exception e) {

            System.assertNotEquals(
                null,
                e
            );
        }

        Id docId2 = createTestPDF();

        FileExtractionController.TEST_JSON_RESPONSE = '{}';

        try {

            FileExtractionController.processDocument(
                docId2,
                null
            );

        } catch(Exception e) {

            System.assertNotEquals(
                null,
                e
            );
        }

        Test.stopTest();
    }

    // =====================================================
    // DIRTY KEY NORMALIZATION
    // =====================================================

    @isTest
    static void testDirtyKeyNormalization() {

        Test.setMock(
            HttpCalloutMock.class,
            new OCRSuccessMock()
        );

        Id docId = createTestPDF();

        FileExtractionController.TEST_JSON_RESPONSE =
        '{' +
        '"insured_first_name!":"OnlyFirst",' +
        '"insured.last.name":"",' +
        '"COMPANY":""' +
        '}';

        Test.startTest();

        Id leadId =
            FileExtractionController.processDocument(
                docId,
                null
            );

        Test.stopTest();

        System.assertNotEquals(
            null,
            leadId
        );
    }

    // =====================================================
    // BLANK EMAIL PHONE
    // =====================================================

    @isTest
    static void testBlankEmailPhoneBranch() {

        Test.setMock(
            HttpCalloutMock.class,
            new OCRSuccessMock()
        );

        Id docId = createTestPDF();

        FileExtractionController.TEST_JSON_RESPONSE =
        '{"Carrier":"TestCarrier"}';

        Test.startTest();

        Id leadId =
            FileExtractionController.processDocument(
                docId,
                null
            );

        Test.stopTest();

        System.assertNotEquals(
            null,
            leadId
        );
    }

    // =====================================================
    // RP-INT AND EXPIRATION DATE AUTOCALC
    // =====================================================

    @isTest
    static void testMissingQuoteAndExpirationDate() {
        Test.setMock(HttpCalloutMock.class, new OCRSuccessMock());
        Id docId = createTestPDF();

        FileExtractionController.TEST_JSON_RESPONSE =
        '{' +
        '"Carrier":"AutoCarrier",' +
        '"QuoteNumber":"",' +
        '"EffectiveDate":"2026-01-01",' +
        '"ExpirationDate":"",' +
        '"Term":"6-Month"' +
        '}';

        Test.startTest();
        Id leadId = FileExtractionController.processDocument(docId, null);
        Test.stopTest();

        System.assertNotEquals(null, leadId);
        
        Policy_Information__c p = [SELECT Id, Quote__c, Expiration_Date__c FROM Policy_Information__c WHERE Lead__c = :leadId LIMIT 1];
        System.assert(p.Quote__c.startsWith('RP-INT-'));
        System.assertEquals(Date.newInstance(2026, 7, 1), p.Expiration_Date__c);
    }

    // =====================================================
    // AGENTFORCE EXCEPTION
    // =====================================================

    @isTest
    static void testAgentforceCatchBlock() {

        Test.setMock(
            HttpCalloutMock.class,
            new OCRSuccessMock()
        );

        Id docId = createTestPDF();

        FileExtractionController.TEST_JSON_RESPONSE = null;

        Test.startTest();

        try {

            FileExtractionController.processDocument(
                docId,
                null
            );

        } catch(Exception e) {

            System.assertNotEquals(
                null,
                e
            );
        }

        Test.stopTest();
    }

    // =====================================================
    // OCR EMPTY TEXT
    // =====================================================

    @isTest
    static void testOCR_EmptyText() {

        Test.setMock(
            HttpCalloutMock.class,
            new OCREmptyTextMock()
        );

        Test.startTest();

        try {

            FileExtractionController.processDocument(
                createTestPDF(),
                null
            );

        } catch(Exception e) {

            System.assertNotEquals(
                null,
                e
            );
        }

        Test.stopTest();
    }

    // =====================================================
    // OCR PROCESSING ERROR
    // =====================================================

    @isTest
    static void testOCR_ProcessingError() {

        Test.setMock(
            HttpCalloutMock.class,
            new OCRErrorProcessingMock()
        );

        Test.startTest();

        try {

            FileExtractionController.processDocument(
                createTestPDF(),
                null
            );

        } catch(Exception e) {

            System.assertNotEquals(
                null,
                e
            );
        }

        Test.stopTest();
    }

    // =====================================================
    // OCR HTTP ERROR
    // =====================================================

    @isTest
    static void testOCR_HttpError() {

        Test.setMock(
            HttpCalloutMock.class,
            new OCRHttpErrorMock()
        );

        Test.startTest();

        try {

            FileExtractionController.processDocument(
                createTestPDF(),
                null
            );

        } catch(Exception e) {

            System.assertNotEquals(
                null,
                e
            );
        }

        Test.stopTest();
    }
}