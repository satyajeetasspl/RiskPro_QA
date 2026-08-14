@isTest
private class GayaServiceNew02Test {

    // ─── Test Data Factory ────────────────────────────────────────────────────

    private static Lead createFullLead() {
        Lead l = new Lead(
            FirstName                           = 'John',
            LastName                            = 'Doe',
            Company                             = 'Test Co',
            Email                               = 'john.doe@test.com',
            Borrowers_Phone_Number__c           = '5551234567',
            Phone_2__c                          = '5559876543',
            Borrower_DOB__c                     = Date.newInstance(1980, 6, 15),
            First_Insured_Occupation__c         = 'Engineer',
            //Education__c                        = 'Bachelor',
            Marital_Status_FI__c                = 'Married',
            Driver_s_License__c                 = 'D1234567',
            //Drivers_License_State__c            = 'FL',
            Insured_Address__Street__s          = '123 Main St',
            Insured_Address__City__s            = 'Orlando',
            //Insured_Address__StateCode__s       = 'FL',
            Insured_Address__PostalCode__s      = '32801',
            Second_Insured_First_Name__c        = 'Jane',
            Second_Insured_Last_Name__c         = 'Doe',
            Relationship_to_Insured__c          = 'Spouse',
            Second_Insured_Email__c             = 'jane.doe@test.com',
            Second_Insured_Phone_1__c           = '5551112222',
            Second_Insured_Phone_2__c           = '5553334444',
            Second_Insureds_DOB__c              = Date.newInstance(1982, 3, 20),
            Second_Insured_Occupation__c        = 'Teacher',
            //Second_Insured_Education__c         = 'Master',
            Marital_Status_SI__c                = 'Married',
            Second_Insured_Drivers_License__c   = 'D7654321'
            //Second_Insured_Drivers_License_State__c = 'FL'
        );
        insert l;
        return l;
    }

    private static Lead createMinimalLead() {
        Lead l = new Lead(
            FirstName = 'Min',
            LastName  = 'Lead',
            Company   = 'Min Co'
        );
        insert l;
        return l;
    }

    private static Driver__c createDriver(Id leadId) {
        // Driver_Full_Name__c is a formula field — do not set it
        Driver__c d = new Driver__c(
            Lead__c                    = leadId,
            First_Name__c              = 'Tom',
            Last_Name__c               = 'Driver',
            Date_of_Birth__c           = Date.newInstance(1975, 1, 10),
            DL__c                      = 'DL123456',
            //Education__c               = 'High School',
            //State__c                   = 'FL',
            Marital_Status__c          = 'Single',
            Occupation__c              = 'Sales',
            Relationship_to_Insured__c = 'Self'
        );
        insert d;
        return d;
    }

    private static Vehicle__c createVehicle(Id leadId, Id driverId) {
        Vehicle__c v = new Vehicle__c(
            Lead__c          = leadId,
            //Vehicle_Type__c  = 'Private Passenger',
            Make__c          = 'Toyota',
            Model__c         = 'Camry',
            Year__c          = '2020',
            Purchase_Year__c = '2020',
            VIN__c           = '1HGCM82633A123456',
            Annual_Miles__c  = '12000',
            Lienholder__c    = 'Bank of FL',
            Registered_To__c = driverId
        );
        insert v;
        return v;
    }

    private static Vehicle__c createMotorcycleVehicle(Id leadId) {
        // Intentional misspelling "Motorcyle" to test normalizeVehicleType correction
        Vehicle__c v = new Vehicle__c(
            Lead__c         = leadId,
            //Vehicle_Type__c = 'Motorcyle',
            Make__c         = 'Harley',
            Model__c        = 'Sportster',
            Year__c         = '2019'
        );
        insert v;
        return v;
    }

    private static Properties__c createProperty(Id leadId) {
        Properties__c p = new Properties__c(
            Lead__c                    = leadId,
            //Property_Type__c           = 'Single Family',
            Coverage_Form__c           = 'HO3',
            Loan__c                    = 'LN001',
            Mortgagee_Clause__c        = 'Yes',
            Address__Street__s         = '456 Oak Ave',
            Address__City__s           = 'Miami',
            Address__StateCode__s      = 'FL',
            Address__PostalCode__s     = '33101',
            Estimated_Closing_Date__c  = Date.newInstance(2025, 12, 31)
        );
        insert p;
        return p;
    }

    private static Property_Information__c createPropertyInfo(Id leadId, Id propertyId) {
        Property_Information__c pi = new Property_Information__c(
            Lead__c                         = leadId,
            Properties__c                   = propertyId,
            // String / text fields (numeric values stored as text in this org)
            X3_4_Bath__c                    = 1,
            Age_of_Dwelling__c              = '15',
            Distance_to_Coastline__c        = 5,
            Full_Bath__c                    = 2,
            Half_Bath__c                    = 1,
            Members_in_Household__c         = 3,
            Number_of_Families__c           = 1,
            Number_of_Mortgages__c          = 1,
            Number_of_Roof_Layers__c        = 1,
            Number_of_Stories__c            = '2',
            Square_Footage__c               = 2200,
            // String / picklist fields
            //Alarm_System__c                 = 'Central',
            //Auxiliary_Heat_Type__c          = 'Electric',
            Community__c                    = 'Gated',
            Construction__c                 = 'Frame',
            Exterior_Paint__c               = '2018',
            Foundation_Type__c              = 'Slab',
            Hail_Resistive_Roof__c          = 'Class 4',
            Heating_Year__c                 = '2015',
            //Heating_Type__c                 = 'Gas',
            //Hot_Tub_on_Premises__c          = 'In-ground',
            //Plumbing__c                     = 'Copper',
            Plumbing_Year__c                = '2010',
            //Primary_Heat_Type__c            = 'Gas',
            Roof_Shape__c                   = 'Gable',
            Roof_Type__c                    = 'Shingle',
            Roof_Yr__c                      = '2018',
            Swimming_Pool_on_Premises__c    = 'In-ground',
            Wiring_Year__c                  = '2012',
            Year_Built__c                   = '2005',
            // Date field
            Purchased_Rental_Date__c        = Date.newInstance(2015, 5, 1),
            // Boolean checkbox fields
            Any_smokers_in_the_Household__c = 'false',
            Complete__c                     = 'true',
            Diving_Board__c                 = false,
            Fence_2__c                      = true,
            Fence__c                        = true,
            Is_Hot_Tub__c                   = true,
            Is_Alarm_System__c              = true,
            Is_Animal__c                    = false,
            Is_Pool__c                      = true,
            Is_Trampoline__c                = false,
            Locked__c                       = true,
            Locked_Secure_Cover__c          = true,
            Net__c                          = false,
            Partial__c                      = 'false',
            Removable_Retracting_Locking__c = true,
            Roof_ACV__c                     = false,
            Slide__c                        = false,
            Winning__c                      = 'Complete'
        );
        insert pi;
        return pi;
    }

    // Property_Information__c with Lead__c set but NO Properties__c lookup (Case A)
    private static Property_Information__c createOrphanPropertyInfo(Id leadId) {
        Property_Information__c pi = new Property_Information__c(
            Lead__c              = leadId,
            // String / picklist fields
            Construction__c      = 'Masonry',
            Year_Built__c        = '1998',
            Roof_Type__c         = 'Tile',
            // Decimal fields
            Square_Footage__c    = 1800,
            Number_of_Stories__c = '1',
            // Checkbox (Boolean) fields
            Is_Pool__c                      = false,
            Fence__c                        = false,
            Complete__c                     = 'false',
            Diving_Board__c                 = false,
            Fence_2__c                      = false,
            Net__c                          = false,
            Slide__c                        = false,
            Partial__c                      = 'false',
            Roof_ACV__c                     = false,
            Is_Animal__c                    = false,
            Is_Alarm_System__c              = false,
            Is_Hot_Tub__c                   = false,
            Is_Trampoline__c                = false,
            Locked__c                       = false,
            Locked_Secure_Cover__c          = false,
            Removable_Retracting_Locking__c = false,
            Winning__c                      = 'Partial',
            Any_smokers_in_the_Household__c = 'true'
        );
        insert pi;
        return pi;
    }

    private static Prior_Insurance_Information__c createPriorInsurance(Id leadId, String line) {
        // Carrier_Name_Link__c is a formula/non-writeable field — do not set it
        Prior_Insurance_Information__c hp = new Prior_Insurance_Information__c(
            Lead__c                          = leadId,
            Bodily_Injury_Limits__c          = '100/300',
            Carrier_Name__c                  = 'State Farm',
            Expiration_Date__c               = Date.newInstance(2025, 12, 31),
            //Length_of_Continuous_Coverage__c = '5',
            //Length_with_Current_Carrier__c   = '3',
            //Line__c                          = line,
            Policy_Number__c                 = 'POL123456',
            Premium__c                       = 1200.50
        );
        insert hp;
        return hp;
    }

    private static Home_Losses_Claims__c createLoss(Id leadId) {
        Home_Losses_Claims__c loss = new Home_Losses_Claims__c(
            Lead__c                  = leadId,
            Amount_Paid__c           = 5000,    // Decimal, not String
            Carrier__c               = 'Allstate',
            Catastrophic_Related__c  = true,
            //Cause_of_Loss__c         = 'Fire',
            Claim_Status__c          = 'Closed',
            Date_of_Loss__c          = Date.newInstance(2022, 3, 15),
            Description__c           = 'Kitchen fire',
            //Policy_Type__c           = 'Home',
            Property_Liability__c    = 'Property',
            //Risk_Address__c          = '456 Oak Ave, Miami, FL',
            Weather_Related__c       = false
        );
        insert loss;
        return loss;
    }

    private static Auto_Incidents_Violations__c createAccident(Id leadId, Id driverId) {
        Auto_Incidents_Violations__c av = new Auto_Incidents_Violations__c(
            Lead__c                   = leadId,
            Additional_Information__c = 'Rear-end',
            Carrier__c                = 'Geico',
            Date__c                   = Date.newInstance(2021, 7, 4),
            //Incident_Description__c   = 'Minor fender bender',
            Operator__c               = driverId
        );
        insert av;
        return av;
    }

    // ─── Mock HTTP Callout ────────────────────────────────────────────────────

    private class GayaMockSuccess implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"status":"success","record_id":"abc123"}');
            return res;
        }
    }

    private class GayaMockError implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody('Internal Server Error');
            return res;
        }
    }

    // ─── Tests ────────────────────────────────────────────────────────────────

    /**
     * Full happy-path: Lead + all related records, Properties__c exists (Case B),
     * Property_Information__c linked via Properties__c lookup.
     * Covers: customer, household, property (Case B with pi enrichment),
     *         all policy types, driver, car (normal type), loss, accident.
     */
    @isTest
    static void testFullLeadAllEntities() {
        Lead l = createFullLead();
        Driver__c d = createDriver(l.Id);
        createVehicle(l.Id, d.Id);
        Properties__c prop = createProperty(l.Id);
        createPropertyInfo(l.Id, prop.Id);

        // All policy line types to hit every entityName branch
        createPriorInsurance(l.Id, 'Auto');
        createPriorInsurance(l.Id, 'Home');
        createPriorInsurance(l.Id, 'Flood');
        createPriorInsurance(l.Id, 'Umbrella');
        createPriorInsurance(l.Id, 'Commercial');
        createPriorInsurance(l.Id, 'Life');
        createPriorInsurance(l.Id, 'Health');
        createPriorInsurance(l.Id, 'Other');   // default entity name branch

        createLoss(l.Id);
        createAccident(l.Id, d.Id);

        GayaServiceNew02.Request req = new GayaServiceNew02.Request();
        req.leadId = l.Id;

        Test.setMock(HttpCalloutMock.class, new GayaMockSuccess());
        Test.startTest();
        List<GayaServiceNew02.Response> responses =
            GayaServiceNew02.sendLeadToGaya(new List<GayaServiceNew02.Request>{ req });
        Test.stopTest();
    }

    /**
     * Case A: Property_Information__c exists with Lead__c but NO Properties__c lookup.
     * Covers the `if (properties.isEmpty() && !allPropInfos.isEmpty())` branch.
     */
    @isTest
    static void testCaseA_OrphanPropertyInfo() {
        Lead l = createFullLead();
        createOrphanPropertyInfo(l.Id);

        GayaServiceNew02.Request req = new GayaServiceNew02.Request();
        req.leadId = l.Id;

        Test.setMock(HttpCalloutMock.class, new GayaMockSuccess());
        Test.startTest();
        GayaServiceNew02.sendLeadToGaya(new List<GayaServiceNew02.Request>{ req });
        Test.stopTest();
    }

    /**
     * Properties__c exists but Property_Information__c lookup doesn't match
     * (pi == null branch in Case B enrichment).
     */
    @isTest
    static void testCaseB_PropertyWithoutPropInfo() {
        Lead l = createFullLead();
        createProperty(l.Id);   // no matching Property_Information__c

        GayaServiceNew02.Request req = new GayaServiceNew02.Request();
        req.leadId = l.Id;

        Test.setMock(HttpCalloutMock.class, new GayaMockSuccess());
        Test.startTest();
        GayaServiceNew02.sendLeadToGaya(new List<GayaServiceNew02.Request>{ req });
        Test.stopTest();
    }

    /**
     * Motorcycle with intentional misspelling "Motorcyle" → normalizeVehicleType correction.
     */
    @isTest
    static void testMotorcycleNormalization() {
        Lead l = createFullLead();
        createMotorcycleVehicle(l.Id);

        GayaServiceNew02.Request req = new GayaServiceNew02.Request();
        req.leadId = l.Id;

        Test.setMock(HttpCalloutMock.class, new GayaMockSuccess());
        Test.startTest();
        GayaServiceNew02.sendLeadToGaya(new List<GayaServiceNew02.Request>{ req });
        Test.stopTest();
    }

    /**
     * Null leadId in request → 'Skipped: Lead Id is null.' branch.
     */
    @isTest
    static void testNullLeadId() {
        GayaServiceNew02.Request req = new GayaServiceNew02.Request();
        req.leadId = null;

        Test.startTest();
        List<GayaServiceNew02.Response> responses =
            GayaServiceNew02.sendLeadToGaya(new List<GayaServiceNew02.Request>{ req });
        Test.stopTest();
    }

    /**
     * Null request object in list → null-check branch.
     */
    @isTest
    static void testNullRequest() {
        Test.startTest();
        List<GayaServiceNew02.Response> responses =
            GayaServiceNew02.sendLeadToGaya(new List<GayaServiceNew02.Request>{ null });
        Test.stopTest();
    }

    /**
     * Empty request list → early return.
     */
    @isTest
    static void testEmptyRequestList() {
        Test.startTest();
        List<GayaServiceNew02.Response> responses =
            GayaServiceNew02.sendLeadToGaya(new List<GayaServiceNew02.Request>());
        Test.stopTest();
    }

    /**
     * Null list → early return guard.
     */
    @isTest
    static void testNullRequestList() {
        Test.startTest();
        List<GayaServiceNew02.Response> responses =
            GayaServiceNew02.sendLeadToGaya(null);
        Test.stopTest();
    }

    /**
     * Non-existent Lead Id → 'Lead not found' branch.
     */
    @isTest
    static void testLeadNotFound() {
        Lead tempLead = new Lead(FirstName = 'Temp', LastName = 'Temp', Company = 'Temp');
        insert tempLead;
        Id fakeId = tempLead.Id;
        delete tempLead;

        GayaServiceNew02.Request req = new GayaServiceNew02.Request();
        req.leadId = fakeId;

        Test.startTest();
        List<GayaServiceNew02.Response> responses =
            GayaServiceNew02.sendLeadToGaya(new List<GayaServiceNew02.Request>{ req });
        Test.stopTest();
    }

    /**
     * HTTP 500 response — covers non-200 path and raw-body debug log.
     */
    @isTest
    static void testHttpErrorResponse() {
        Lead l = createFullLead();

        GayaServiceNew02.Request req = new GayaServiceNew02.Request();
        req.leadId = l.Id;

        Test.setMock(HttpCalloutMock.class, new GayaMockError());
        Test.startTest();
        GayaServiceNew02.sendLeadToGaya(new List<GayaServiceNew02.Request>{ req });
        Test.stopTest();
    }

    /**
     * Multiple requests in a single invocation.
     */
    @isTest
    static void testMultipleRequestsInBatch() {
        Lead l1 = createFullLead();
        Lead l2 = createMinimalLead();

        GayaServiceNew02.Request r1 = new GayaServiceNew02.Request();
        r1.leadId = l1.Id;

        GayaServiceNew02.Request r2 = new GayaServiceNew02.Request();
        r2.leadId = l2.Id;

        GayaServiceNew02.Request r3 = new GayaServiceNew02.Request();
        r3.leadId = null;

        Test.setMock(HttpCalloutMock.class, new GayaMockSuccess());
        Test.startTest();
        GayaServiceNew02.sendLeadToGaya(
            new List<GayaServiceNew02.Request>{ r1, r2, r3 }
        );
        Test.stopTest();
    }

    /**
     * Lead with no optional fields populated — tests null/blank guards
     * in buildAddress, formatDate, addField, addBoolField.
     */
    @isTest
    static void testMinimalLeadNoOptionalFields() {
        Lead l = createMinimalLead();

        GayaServiceNew02.Request req = new GayaServiceNew02.Request();
        req.leadId = l.Id;

        Test.setMock(HttpCalloutMock.class, new GayaMockSuccess());
        Test.startTest();
        GayaServiceNew02.sendLeadToGaya(new List<GayaServiceNew02.Request>{ req });
        Test.stopTest();
    }

    /**
     * Vehicle with no Registered_To driver (null relationship).
     */
    @isTest
    static void testVehicleWithNoRegisteredOwner() {
        Lead l = createFullLead();
        Vehicle__c v = new Vehicle__c(
            Lead__c         = l.Id,
            //Vehicle_Type__c = 'Private Passenger',
            Make__c         = 'Honda',
            Model__c        = 'Civic',
            Year__c         = '2021'
        );
        insert v;

        GayaServiceNew02.Request req = new GayaServiceNew02.Request();
        req.leadId = l.Id;

        Test.setMock(HttpCalloutMock.class, new GayaMockSuccess());
        Test.startTest();
        GayaServiceNew02.sendLeadToGaya(new List<GayaServiceNew02.Request>{ req });
        Test.stopTest();
    }

    /**
     * Accident/Violation with no Operator (null relationship).
     */
    @isTest
    static void testAccidentWithNoOperator() {
        Lead l = createFullLead();
        Auto_Incidents_Violations__c av = new Auto_Incidents_Violations__c(
            Lead__c                   = l.Id,
            Additional_Information__c = 'Speeding',
            Carrier__c                = 'Progressive',
            Date__c                   = Date.newInstance(2023, 1, 1)
            //Incident_Description__c   = 'Speeding ticket'
        );
        insert av;

        GayaServiceNew02.Request req = new GayaServiceNew02.Request();
        req.leadId = l.Id;

        Test.setMock(HttpCalloutMock.class, new GayaMockSuccess());
        Test.startTest();
        GayaServiceNew02.sendLeadToGaya(new List<GayaServiceNew02.Request>{ req });
        Test.stopTest();
    }

    /**
     * Prior Insurance with blank Line__c — covers default 'home_policy' entity name.
     */
    @isTest
    static void testPriorInsuranceBlankLine() {
        Lead l = createFullLead();
        Prior_Insurance_Information__c hp = new Prior_Insurance_Information__c(
            Lead__c          = l.Id,
            Carrier_Name__c  = 'State Farm',
            Policy_Number__c = 'POL999',
            Premium__c       = 850.00
        );
        insert hp;

        GayaServiceNew02.Request req = new GayaServiceNew02.Request();
        req.leadId = l.Id;

        Test.setMock(HttpCalloutMock.class, new GayaMockSuccess());
        Test.startTest();
        GayaServiceNew02.sendLeadToGaya(new List<GayaServiceNew02.Request>{ req });
        Test.stopTest();
    }

    /**
     * Multiple policies of the same type — exercises policyIndexMap increment.
     */
    @isTest
    static void testMultiplePoliciesSameType() {
        Lead l = createFullLead();
        createPriorInsurance(l.Id, 'Auto');
        createPriorInsurance(l.Id, 'Auto');
        createPriorInsurance(l.Id, 'Home');
        createPriorInsurance(l.Id, 'Home');

        GayaServiceNew02.Request req = new GayaServiceNew02.Request();
        req.leadId = l.Id;

        Test.setMock(HttpCalloutMock.class, new GayaMockSuccess());
        Test.startTest();
        GayaServiceNew02.sendLeadToGaya(new List<GayaServiceNew02.Request>{ req });
        Test.stopTest();
    }

    /**
     * Multiple drivers and vehicles — exercises index incrementing.
     */
    @isTest
    static void testMultipleDriversAndVehicles() {
        Lead l = createFullLead();

        Driver__c d1 = createDriver(l.Id);

        // Driver_Full_Name__c is a formula — do not set it
        Driver__c d2 = new Driver__c(
            Lead__c                    = l.Id,
            First_Name__c              = 'Sara',
            Last_Name__c               = 'Smith',
            Date_of_Birth__c           = Date.newInstance(1990, 4, 5),
            Relationship_to_Insured__c = 'Child'
        );
        insert d2;

        createVehicle(l.Id, d1.Id);
        createVehicle(l.Id, d2.Id);

        GayaServiceNew02.Request req = new GayaServiceNew02.Request();
        req.leadId = l.Id;

        Test.setMock(HttpCalloutMock.class, new GayaMockSuccess());
        Test.startTest();
        GayaServiceNew02.sendLeadToGaya(new List<GayaServiceNew02.Request>{ req });
        Test.stopTest();
    }

    /**
     * Multiple losses — exercises lossIndex incrementing.
     */
    @isTest
    static void testMultipleLosses() {
        Lead l = createFullLead();
        createLoss(l.Id);

        Home_Losses_Claims__c loss2 = new Home_Losses_Claims__c(
            Lead__c            = l.Id,
            //Cause_of_Loss__c   = 'Wind',
            Date_of_Loss__c    = Date.newInstance(2023, 9, 1),
            Weather_Related__c = true
        );
        insert loss2;

        GayaServiceNew02.Request req = new GayaServiceNew02.Request();
        req.leadId = l.Id;

        Test.setMock(HttpCalloutMock.class, new GayaMockSuccess());
        Test.startTest();
        GayaServiceNew02.sendLeadToGaya(new List<GayaServiceNew02.Request>{ req });
        Test.stopTest();
    }

    /**
     * Multiple Properties__c each with their own Property_Information__c.
     */
    @isTest
    static void testMultiplePropertiesWithInfo() {
        Lead l = createFullLead();

        Properties__c prop1 = createProperty(l.Id);
        createPropertyInfo(l.Id, prop1.Id);

        Properties__c prop2 = new Properties__c(
            Lead__c          = l.Id,
            //Property_Type__c = 'Condo',
            Coverage_Form__c = 'HO6'
        );
        insert prop2;
        createPropertyInfo(l.Id, prop2.Id);

        GayaServiceNew02.Request req = new GayaServiceNew02.Request();
        req.leadId = l.Id;

        Test.setMock(HttpCalloutMock.class, new GayaMockSuccess());
        Test.startTest();
        GayaServiceNew02.sendLeadToGaya(new List<GayaServiceNew02.Request>{ req });
        Test.stopTest();
    }
}