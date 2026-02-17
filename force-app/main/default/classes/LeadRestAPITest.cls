@IsTest
private class LeadRestAPITest {

    // Helper: build base RestContext
    private static void setupRest(String body) {
        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/LeadRestAPI/';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(body);
        RestContext.request = req;
        RestContext.response = new RestResponse();
    }

    @IsTest
    static void testCreateLead_Success_SingleRecord() {
        String body = JSON.serialize(new Map<String, Object>{
            'FirstName' => 'Alice',
            'LastName' => 'Brown',
            'Company' => 'Acme Inc',
            'Email' => 'alice@example.com',
            'NumberOfEmployees' => 12,
            'AnnualRevenue' => 50000.50,
            'IsConverted' => false,
            'Status' => 'Open - Not Contacted'
        });
        setupRest(body);
        LeadRestAPI.createLead();
    }

    @IsTest
    static void testCreateLead_Success_MultipleRecords() {
        List<Object> leads = new List<Object>{
            new Map<String,Object>{
                'FirstName' => 'Bob',
                'LastName' => 'Builder',
                'Company' => 'Construction Co',
                'Email' => 'bob@build.com'
            },
            new Map<String,Object>{
                'FirstName' => 'Jane',
                'LastName' => 'Smith',
                'Company' => 'TechWorks',
                'Email' => 'jane@techworks.com'
            }
        };
        setupRest(JSON.serialize(leads));
        LeadRestAPI.createLead();
    }

    @IsTest
    static void testCreateLead_EmptyBody() {
        setupRest('');
        LeadRestAPI.createLead();
    }

    @IsTest
    static void testCreateLead_InvalidJSON() {
        setupRest('invalid-json-string');
        LeadRestAPI.createLead();
    }

    @IsTest
    static void testCreateLead_InvalidFieldName() {
        String body = JSON.serialize(new Map<String, Object>{
            'FirstName' => 'Rick',
            'LastName' => 'Morty',
            'Company' => 'SciTech',
            'FakeField__c' => 'SomeValue' // invalid field, should skip
        });
        setupRest(body);
        LeadRestAPI.createLead();
    }

    @IsTest
    static void testCreateLead_MissingRequiredFields() {
        String body = JSON.serialize(new Map<String, Object>{
            'FirstName' => 'Tom'
        });
        setupRest(body);
        LeadRestAPI.createLead();
    }

    @IsTest
    static void testCreateLead_BadDataTypeConversion() {
        // Will trigger type conversion exception for AnnualRevenue (expect double)
        String body = JSON.serialize(new Map<String, Object>{
            'FirstName' => 'Error',
            'LastName' => 'Case',
            'Company' => 'ErrorCo',
            'AnnualRevenue' => 'NotANumber'
        });
        setupRest(body);
        LeadRestAPI.createLead();
    }

    @IsTest
    static void testCreateLead_DateTimeAndDateParsing() {
        String body = JSON.serialize(new Map<String, Object>{
            'FirstName' => 'Timey',
            'LastName' => 'Wimey',
            'Company' => 'Temporal Ltd',
            'Status' => 'Open - Not Contacted',
            'CreatedDate' => Datetime.now().format('yyyy-MM-dd HH:mm:ss'),
            'LastModifiedDate' => Datetime.now().format('yyyy-MM-dd HH:mm:ss')
        });
        setupRest(body);
        LeadRestAPI.createLead();
    }

    @IsTest
    static void testCreateLead_InternalException() {
        // Force an exception by setting RestContext to null
        RestContext.request = null;
        RestContext.response = null;
        try {
            LeadRestAPI.createLead();
        } catch (Exception e) {
            // swallow to continue test run
        }
    }
}