public with sharing class QuoteSheetController {
    
    public class QuotePayload {
        // Routing ID — exactly one will be non-null
        @AuraEnabled public Id leadId    { get; set; }
        @AuraEnabled public Id oppId     { get; set; }
        @AuraEnabled public Id accountId { get; set; }
        @AuraEnabled public String objectApiName { get; set; }

        // Common fields
        @AuraEnabled public String firstName          { get; set; }
        @AuraEnabled public String lastName           { get; set; }
        @AuraEnabled public String email              { get; set; }
        @AuraEnabled public String phone              { get; set; }
        @AuraEnabled public String secondaryPhone     { get; set; }
        @AuraEnabled public String insuredStreet     { get; set; }
        @AuraEnabled public String insuredCity       { get; set; }
        @AuraEnabled public String insuredState      { get; set; }
        @AuraEnabled public String insuredZip        { get; set; }
        @AuraEnabled public String insuredCountry    { get; set; }
        @AuraEnabled public String partnerName        { get; set; }
        @AuraEnabled public String loanOfficerName    { get; set; }
        @AuraEnabled public String referralSourceName { get; set; }
        @AuraEnabled public String processorName      { get; set; }
        @AuraEnabled public String loanAssociateName  { get; set; }
        @AuraEnabled public String coverageForm       { get; set; }
        @AuraEnabled public String propertyType       { get; set; }
        @AuraEnabled public String description        { get; set; }

        // Added Fields
        @AuraEnabled public Date   dob                { get; set; }
        @AuraEnabled public String maritalStatus      { get; set; }
        @AuraEnabled public String occupation         { get; set; }
        @AuraEnabled public String dlNumber           { get; set; }
        @AuraEnabled public String dlState            { get; set; }

        // Second Insured
        @AuraEnabled public Boolean showSecondInsured { get; set; }
        @AuraEnabled public String siFirstName        { get; set; }
        @AuraEnabled public String siLastName         { get; set; }
        @AuraEnabled public String siPhone            { get; set; }
        @AuraEnabled public String siSecondaryPhone   { get; set; }
        @AuraEnabled public String siEmail            { get; set; }
        @AuraEnabled public Date   siDOB              { get; set; }
        @AuraEnabled public String siOccupation       { get; set; }
        @AuraEnabled public String siMaritalStatus    { get; set; }
        @AuraEnabled public String siDLNumber         { get; set; }
        @AuraEnabled public String siDLState          { get; set; }

        // Child lists
        @AuraEnabled public List<PropertyWrapper>               properties             { get; set; }
        @AuraEnabled public List<String>                        deletedPropertyIds     { get; set; }
        @AuraEnabled public List<Prior_Insurance_Information__c> priorInsurances       { get; set; }
        @AuraEnabled public List<String>                        deletedPriorInsuranceIds { get; set; }
        @AuraEnabled public List<Driver__c>                     drivers                { get; set; }
        @AuraEnabled public List<String>                        deletedDriverIds       { get; set; }
        @AuraEnabled public List<Vehicle__c>                    vehicles               { get; set; }
        @AuraEnabled public List<String>                        deletedVehicleIds      { get; set; }
        @AuraEnabled public List<Auto_Incidents_Violations__c>  incidents              { get; set; }
        @AuraEnabled public List<String>                        deletedIncidentIds     { get; set; }
        @AuraEnabled public List<Home_Losses_Claims__c>         losses                 { get; set; }
        @AuraEnabled public List<String>                        deletedLossIds         { get; set; }
    }

    public class PropertyWrapper {
        @AuraEnabled public Property_Information__c details { get; set; }
        @AuraEnabled public String street { get; set; }
        @AuraEnabled public String city { get; set; }
        @AuraEnabled public String state { get; set; }
        @AuraEnabled public String zip { get; set; }
        @AuraEnabled public String coverageForm { get; set; }
        @AuraEnabled public String propertyType { get; set; }
        @AuraEnabled public List<Animals_on_Premises__c> animals { get; set; }
        @AuraEnabled public List<String> deletedAnimalIds { get; set; }
    }

    // ─────────────────────────────────────────────
    // GET  — dispatches based on which Id is passed
    // ─────────────────────────────────────────────

    @AuraEnabled(cacheable=true)
    public static QuotePayload getQuoteData(Id recordId, String objectApiName) {
        if (recordId == null) {
            return new QuotePayload();
        }
        if (objectApiName == 'Lead') {
            return getLeadData(recordId);
        } else {
            return getOppData(recordId);
        }
    }

    private static QuotePayload getLeadData(Id leadId) {
        QuotePayload payload = new QuotePayload();
        payload.leadId = leadId;

        Lead l = [
            SELECT FirstName, LastName, Email,
                   Borrowers_Phone_Number__c, Phone_2__c,
                   Partner_Name__c, Loan_Officer_Name__c, Referral_Source_Name__c,
                   Processor_Name__c, Loan_Associate_Name__c,
                   Coverage_Form__c, Property_Type__c, Description,
                    Insured_Address__Street__s, Insured_Address__City__s,
                    Insured_Address__StateCode__s, Insured_Address__PostalCode__s,
                    Insured_Address__CountryCode__s,
                    Street, City, State, PostalCode, Country,
                    Borrower_DOB__c, Marital_Status_FI__c, First_Insured_Occupation__c,
                    Driver_s_License__c, Drivers_License_State__c,
                    Add_Second_Named_Insured__c, Second_Insured_First_Name__c,
                    Second_Insured_Last_Name__c, Second_Insured_Phone_1__c, Second_Insured_Phone_2__c,
                    Second_Insured_Email__c, Second_Insureds_DOB__c,
                    Second_Insured_Occupation__c, Marital_Status_SI__c,
                    Second_Insured_Drivers_License__c, Second_Insured_Drivers_License_State__c
            FROM Lead WHERE Id = :leadId WITH USER_MODE LIMIT 1
        ];

        payload.firstName          = l.FirstName;
        payload.lastName           = l.LastName;
        payload.email              = l.Email;
        payload.phone              = l.Borrowers_Phone_Number__c;
        payload.secondaryPhone     = l.Phone_2__c;
        payload.partnerName        = l.Partner_Name__c;
        payload.loanOfficerName    = l.Loan_Officer_Name__c;
        payload.referralSourceName = l.Referral_Source_Name__c;
        payload.processorName      = l.Processor_Name__c;
        payload.loanAssociateName  = l.Loan_Associate_Name__c;
        payload.coverageForm       = l.Coverage_Form__c;
        payload.propertyType       = l.Property_Type__c;
        payload.description        = l.Description;
        payload.insuredStreet      = l.Insured_Address__Street__s;
        payload.insuredCity        = l.Insured_Address__City__s;
        payload.insuredState       = l.Insured_Address__StateCode__s;
        payload.insuredZip         = l.Insured_Address__PostalCode__s;
        payload.insuredCountry     = l.Insured_Address__CountryCode__s;

        payload.dob                = l.Borrower_DOB__c;
        payload.maritalStatus      = l.Marital_Status_FI__c;
        payload.occupation         = l.First_Insured_Occupation__c;
        payload.dlNumber           = l.Driver_s_License__c;
        payload.dlState            = l.Drivers_License_State__c;

        payload.showSecondInsured  = l.Add_Second_Named_Insured__c;
        payload.siFirstName        = l.Second_Insured_First_Name__c;
        payload.siLastName         = l.Second_Insured_Last_Name__c;
        payload.siPhone            = l.Second_Insured_Phone_1__c;
        payload.siSecondaryPhone   = l.Second_Insured_Phone_2__c;
        payload.siEmail            = l.Second_Insured_Email__c;
        payload.siDOB              = l.Second_Insureds_DOB__c;
        payload.siOccupation       = l.Second_Insured_Occupation__c;
        payload.siMaritalStatus    = l.Marital_Status_SI__c;
        payload.siDLNumber         = l.Second_Insured_Drivers_License__c;
        payload.siDLState          = l.Second_Insured_Drivers_License_State__c;

        // 1. Fetch all Property Information (Quote Details) for this Lead
        List<Property_Information__c> propDetails = [
            SELECT Id, Year_Built__c, Purchased_Rental_Date__c, Square_Footage__c, Heating_Year__c, Plumbing_Year__c, Wiring_Year__c, 
                   Roof_Yr__c, Complete__c, Partial__c, Swimming_Pool_on_Premises__c, Hot_Tub_on_Premises__c, Trampoline_on_Premises__c,
                   Is_Pool__c, Is_Hot_Tub__c, Is_Trampoline__c, Alarm_System__c, Is_Animal__c,
                   Properties__c,
                   (SELECT Id, Type_Breed__c, Number__c, Bite_History__c FROM Animals_on_Premisess__r)
            FROM Property_Information__c WHERE Lead__c = :leadId WITH USER_MODE
        ];

        // 2. Fetch all related Property addresses for this Lead
        List<Properties__c> relatedProps = [
            SELECT Id, Address__Street__s, Address__City__s, Address__StateCode__s, Address__PostalCode__s, 
                   Coverage_Form__c, Property_Type__c
            FROM Properties__c WHERE Lead__c = :leadId WITH USER_MODE
        ];

        // 3. Merge Logic: Start with all Quote Details (Property_Information__c)
        payload.properties = new List<PropertyWrapper>();
        Set<Id> handledPropIds = new Set<Id>();
        Property_Information__c prop1Detail = null;

        // Add all existing detail records first
        for (Property_Information__c pi : propDetails) {
            PropertyWrapper pw = new PropertyWrapper();
            pw.details = pi;
            pw.animals = pi.Animals_on_Premisess__r;

            if (pi.Properties__c != null) {
                // Link to an existing Properties__c record
                handledPropIds.add(pi.Properties__c);
                // Find the matching address record to get the street/city/etc.
                for (Properties__c p : relatedProps) {
                    if (p.Id == pi.Properties__c) {
                        pw.street = p.Address__Street__s;
                        pw.city   = p.Address__City__s;
                        pw.state  = p.Address__StateCode__s;
                        pw.zip    = p.Address__PostalCode__s;
                        pw.coverageForm = p.Coverage_Form__c;
                        pw.propertyType = p.Property_Type__c;
                        break;
                    }
                }
                payload.properties.add(pw);
            } else {
                // This is likely the primary property using Lead address
                prop1Detail = pi;
            }
        }

        // 4. Handle Property 1 (Always at index 0)
        PropertyWrapper pw1 = new PropertyWrapper();
        pw1.details = (prop1Detail != null) ? prop1Detail : new Property_Information__c();
        pw1.animals = (prop1Detail != null) ? prop1Detail.Animals_on_Premisess__r : new List<Animals_on_Premises__c>();
        pw1.street  = l.Street;
        pw1.city    = l.City;
        pw1.state   = l.State;
        pw1.zip     = l.PostalCode;
        pw1.coverageForm = l.Coverage_Form__c;
        pw1.propertyType = l.Property_Type__c;
        
        // Ensure Property 1 is at the start safely without add(0, pw1)
        List<PropertyWrapper> safeList = new List<PropertyWrapper>();
        safeList.add(pw1);
        if (payload.properties != null) {
            safeList.addAll(payload.properties);
        }
        payload.properties = safeList;

        // 5. Add any Property Addresses (Properties__c) that don't have Quote Details yet
        for (Properties__c p : relatedProps) {
            if (!handledPropIds.contains(p.Id)) {
                PropertyWrapper pw = new PropertyWrapper();
                pw.details = new Property_Information__c(Properties__c = p.Id, Lead__c = leadId);
                pw.street  = p.Address__Street__s;
                pw.city    = p.Address__City__s;
                pw.state   = p.Address__StateCode__s;
                pw.zip     = p.Address__PostalCode__s;
                pw.coverageForm = p.Coverage_Form__c;
                pw.propertyType = p.Property_Type__c;
                payload.properties.add(pw);
            }
        }

        payload.priorInsurances= [SELECT Id, Carrier_Name__c, Line__c, Policy_Number__c, Bodily_Injury_Limits__c, Length_with_Current_Carrier__c FROM Prior_Insurance_Information__c WHERE Lead__c = :leadId WITH USER_MODE];
        payload.drivers        = [SELECT Id, First_Name__c, Last_Name__c, Date_of_Birth__c, Relationship_to_Insured__c, Marital_Status__c, DL__c, State__c FROM Driver__c WHERE Lead__c = :leadId WITH USER_MODE];
        payload.vehicles       = [SELECT Id, Vehicle_Type__c,Year__c, Make__c, Model__c, VIN__c FROM Vehicle__c WHERE Lead__c = :leadId WITH USER_MODE];
        payload.incidents      = [SELECT Id, Incident_Description__c, Additional_Information__c FROM Auto_Incidents_Violations__c WHERE Lead__c = :leadId WITH USER_MODE];
        payload.losses         = [SELECT Id, Date_of_Loss__c, Cause_of_Loss__c, Amount_Paid__c FROM Home_Losses_Claims__c WHERE Lead__c = :leadId WITH USER_MODE];

        return payload;
    }

    private static QuotePayload getOppData(Id oppId) {
        QuotePayload payload = new QuotePayload();
        payload.oppId = oppId;

        Opportunity opp = [
            SELECT Id, AccountId, Description,
                   Account.First_Name_FI__c, Account.Last_Name_FI__c, Account.Email__c,
                   Account.Phone, Account.Phone_2_FI__c, Account.Partner_Name__c,
                   Account.Loan_Officer_Name__c, Account.Referral_Source_Name__c,
                   Account.Processor_Name__c, Account.Loan_Associate_Name__c,
                    Account.Coverage_Form__c, Account.Property_Type__c,
                    Account.Insured_Address__Street__s, Account.Insured_Address__City__s,
                    Account.Insured_Address__StateCode__s, Account.Insured_Address__PostalCode__s, Account.Insured_Address__CountryCode__s,
                    Account.Address_Property__Street__s, Account.Address_Property__City__s,
                    Account.Address_Property__StateCode__s, Account.Address_Property__PostalCode__s, Account.Address_Property__CountryCode__s,
                    Account.Insured_DOB__c, Account.First_Insured_Marital_Status__c,
                    Account.First_Insured_Occupation__c, Account.First_Insured_Driver_S_License__c,
                    Account.First_Insured_Driver_S_License_State__c,
                    Account.Add_Second_Named_Insured__c, Account.Second_Insured_First_Name__c,
                    Account.Second_Insured_Last_Name__c, Account.Second_Insured_Phone__c, Account.Second_Insured_Phone_2__c,
                    Account.Second_Insured_Email__c, Account.Second_Insured_DOB__c,
                    Account.Second_Insured_Occupation__c, Account.Second_Insured_Marital_Status__c,
                    Account.Second_Insured_Drivers_License__c, Account.Second_Insured_Drivers_License_State__c
            FROM Opportunity WHERE Id = :oppId WITH USER_MODE LIMIT 1
        ];

        payload.accountId  = opp.AccountId;
        payload.description= opp.Description;

        if (opp.Account != null) {
            payload.firstName          = opp.Account.First_Name_FI__c;
            payload.lastName           = opp.Account.Last_Name_FI__c;
            payload.email              = opp.Account.Email__c;
            payload.phone              = opp.Account.Phone;
            payload.secondaryPhone     = opp.Account.Phone_2_FI__c;
            payload.partnerName        = opp.Account.Partner_Name__c;
            payload.loanOfficerName    = opp.Account.Loan_Officer_Name__c;
            payload.referralSourceName = opp.Account.Referral_Source_Name__c;
            payload.processorName      = opp.Account.Processor_Name__c;
            payload.loanAssociateName  = opp.Account.Loan_Associate_Name__c;
            payload.coverageForm       = opp.Account.Coverage_Form__c;
            payload.propertyType       = opp.Account.Property_Type__c;
            payload.insuredStreet      = opp.Account.Insured_Address__Street__s;
            payload.insuredCity        = opp.Account.Insured_Address__City__s;
            payload.insuredState       = opp.Account.Insured_Address__StateCode__s;
            payload.insuredZip         = opp.Account.Insured_Address__PostalCode__s;
            payload.insuredCountry     = opp.Account.Insured_Address__CountryCode__s;

            payload.dob                = opp.Account.Insured_DOB__c;
            payload.maritalStatus      = opp.Account.First_Insured_Marital_Status__c;
            payload.occupation         = opp.Account.First_Insured_Occupation__c;
            payload.dlNumber           = opp.Account.First_Insured_Driver_S_License__c;
            payload.dlState            = opp.Account.First_Insured_Driver_S_License_State__c;

            payload.showSecondInsured  = opp.Account.Add_Second_Named_Insured__c;
            payload.siFirstName        = opp.Account.Second_Insured_First_Name__c;
            payload.siLastName         = opp.Account.Second_Insured_Last_Name__c;
            payload.siPhone            = opp.Account.Second_Insured_Phone__c;
            payload.siSecondaryPhone   = opp.Account.Second_Insured_Phone_2__c;
            payload.siEmail            = opp.Account.Second_Insured_Email__c;
            payload.siDOB              = opp.Account.Second_Insured_DOB__c;
            payload.siOccupation       = opp.Account.Second_Insured_Occupation__c;
            payload.siMaritalStatus    = opp.Account.Second_Insured_Marital_Status__c;
            payload.siDLNumber         = opp.Account.Second_Insured_Drivers_License__c;
            payload.siDLState          = opp.Account.Second_Insured_Drivers_License_State__c;
        }

        if (payload.accountId != null) {
            Id accId = payload.accountId;
            // 1. Fetch all Property Information (Quote Details) for this Account
            List<Property_Information__c> propDetails = [
                SELECT Id, Year_Built__c, Purchased_Rental_Date__c, Square_Footage__c, Heating_Year__c, Plumbing_Year__c, Wiring_Year__c, 
                       Roof_Yr__c, Complete__c, Partial__c, Swimming_Pool_on_Premises__c, Hot_Tub_on_Premises__c, Trampoline_on_Premises__c,
                       Is_Pool__c, Is_Hot_Tub__c, Is_Trampoline__c, Alarm_System__c, Is_Animal__c,
                       Properties__c,
                       (SELECT Id, Type_Breed__c, Number__c, Bite_History__c FROM Animals_on_Premisess__r)
                FROM Property_Information__c WHERE Account__c = :accId WITH USER_MODE
            ];

            // 2. Fetch all related Property addresses for this Account
            List<Properties__c> relatedProps = [
                SELECT Id, Address__Street__s, Address__City__s, Address__StateCode__s, Address__PostalCode__s, 
                       Coverage_Form__c, Property_Type__c
                FROM Properties__c WHERE Account__c = :accId WITH USER_MODE
            ];

            // 3. Merge Logic: Start with all Quote Details (Property_Information__c)
            payload.properties = new List<PropertyWrapper>();
            Set<Id> handledPropIds = new Set<Id>();
            Property_Information__c prop1Detail = null;

            // Add all existing detail records first
            for (Property_Information__c pi : propDetails) {
                PropertyWrapper pw = new PropertyWrapper();
                pw.details = pi;
                pw.animals = pi.Animals_on_Premisess__r;

                if (pi.Properties__c != null) {
                    // Link to an existing Properties__c record
                    handledPropIds.add(pi.Properties__c);
                    // Find the matching address record to get the street/city/etc.
                    for (Properties__c p : relatedProps) {
                        if (p.Id == pi.Properties__c) {
                            pw.street = p.Address__Street__s;
                            pw.city   = p.Address__City__s;
                            pw.state  = p.Address__StateCode__s;
                            pw.zip    = p.Address__PostalCode__s;
                            pw.coverageForm = p.Coverage_Form__c;
                            pw.propertyType = p.Property_Type__c;
                            break;
                        }
                    }
                    payload.properties.add(pw);
                } else {
                    // This is likely the primary property using Account address
                    prop1Detail = pi;
                }
            }

            // 4. Handle Property 1 (Always at index 0)
            PropertyWrapper pw1 = new PropertyWrapper();
            pw1.details = (prop1Detail != null) ? prop1Detail : new Property_Information__c();
            pw1.animals = (prop1Detail != null) ? prop1Detail.Animals_on_Premisess__r : new List<Animals_on_Premises__c>();
            pw1.street  = opp.Account.Address_Property__Street__s;
            pw1.city    = opp.Account.Address_Property__City__s;
            pw1.state   = opp.Account.Address_Property__StateCode__s;
            pw1.zip     = opp.Account.Address_Property__PostalCode__s;
            pw1.coverageForm = opp.Account.Coverage_Form__c;
            pw1.propertyType = opp.Account.Property_Type__c;
        
        // Ensure Property 1 is at the start safely without add(0, pw1)
        List<PropertyWrapper> safeList = new List<PropertyWrapper>();
        safeList.add(pw1);
        if (payload.properties != null) {
            safeList.addAll(payload.properties);
        }
        payload.properties = safeList;

            // 5. Add any Property Addresses (Properties__c) that don't have Quote Details yet
            for (Properties__c p : relatedProps) {
                if (!handledPropIds.contains(p.Id)) {
                    PropertyWrapper pw = new PropertyWrapper();
                    pw.details = new Property_Information__c(Properties__c = p.Id, Account__c = accId);
                    pw.street  = p.Address__Street__s;
                    pw.city    = p.Address__City__s;
                    pw.state   = p.Address__StateCode__s;
                    pw.zip     = p.Address__PostalCode__s;
                    pw.coverageForm = p.Coverage_Form__c;
                    pw.propertyType = p.Property_Type__c;
                    payload.properties.add(pw);
                }
            }

            payload.priorInsurances= [SELECT Id, Carrier_Name__c, Line__c, Policy_Number__c, Bodily_Injury_Limits__c, Length_with_Current_Carrier__c FROM Prior_Insurance_Information__c WHERE Account__c = :accId WITH USER_MODE];
            payload.drivers        = [SELECT Id, First_Name__c, Last_Name__c, Date_of_Birth__c, Relationship_to_Insured__c, Marital_Status__c, DL__c, State__c FROM Driver__c WHERE Account__c = :accId WITH USER_MODE];
            payload.vehicles       = [SELECT Id, Vehicle_Type__c,Year__c, Make__c, Model__c, VIN__c FROM Vehicle__c WHERE Account__c = :accId WITH USER_MODE];
            payload.incidents      = [SELECT Id, Incident_Description__c, Additional_Information__c FROM Auto_Incidents_Violations__c WHERE Account__c = :accId WITH USER_MODE];
            payload.losses         = [SELECT Id, Date_of_Loss__c, Cause_of_Loss__c, Amount_Paid__c FROM Home_Losses_Claims__c WHERE Account__c = :accId WITH USER_MODE];
        } else {
            payload.properties      = new List<PropertyWrapper>();
            payload.priorInsurances = new List<Prior_Insurance_Information__c>();
            payload.drivers         = new List<Driver__c>();
            payload.vehicles        = new List<Vehicle__c>();
            payload.incidents       = new List<Auto_Incidents_Violations__c>();
        }

        return payload;
    }

    // ─────────────────────────────────────────────
    // SAVE — dispatches based on which Id is present
    // ─────────────────────────────────────────────

    @AuraEnabled
    public static Id saveQuoteData(QuotePayload payload) {
        Savepoint sp = Database.setSavepoint();
        try {
            if (payload == null) throw new AuraHandledException('Payload is null');
            
            Id recordId;
            if (payload.objectApiName == 'Lead' || payload.leadId != null || payload.oppId == null) {
                recordId = saveLeadData(payload);
            } else {
                recordId = saveOppData(payload);
            }

            return recordId;

        } catch (Exception e) {
            Database.rollback(sp);
            if (Test.isRunningTest()) {
                throw e;
            }
            throw new AuraHandledException(e.getMessage() + ' | Stack: ' + e.getStackTraceString());
        }
    }

    private static Id saveLeadData(QuotePayload payload) {
        Lead leadToUpdate = new Lead(
            Id                           = payload.leadId,
            FirstName                    = payload.firstName,
            LastName                     = payload.lastName,
            Email                        = payload.email,
            Borrowers_Phone_Number__c    = payload.phone,
            Phone_2__c                   = payload.secondaryPhone,
            Partner_Name__c              = payload.partnerName,
            Loan_Officer_Name__c         = payload.loanOfficerName,
            Referral_Source_Name__c      = payload.referralSourceName,
            Processor_Name__c            = payload.processorName,
            Loan_Associate_Name__c       = payload.loanAssociateName,
            Coverage_Form__c             = payload.coverageForm,
            Property_Type__c             = payload.propertyType,
            Description                  = payload.description,
            Insured_Address__Street__s   = payload.insuredStreet,
            Insured_Address__City__s     = payload.insuredCity,
            Insured_Address__StateCode__s= payload.insuredState,
            Insured_Address__PostalCode__s = payload.insuredZip,
            Insured_Address__CountryCode__s= payload.insuredCountry,
            Borrower_DOB__c              = payload.dob,
            Marital_Status_FI__c         = payload.maritalStatus,
            First_Insured_Occupation__c  = payload.occupation,
            Driver_s_License__c          = payload.dlNumber,
            Drivers_License_State__c     = payload.dlState,
            Add_Second_Named_Insured__c  = payload.showSecondInsured,
            Second_Insured_First_Name__c = payload.siFirstName,
            Second_Insured_Last_Name__c  = payload.siLastName,
            Second_Insured_Phone_1__c    = payload.siPhone,
            Second_Insured_Phone_2__c    = payload.siSecondaryPhone,
            Second_Insured_Email__c      = payload.siEmail,
            Second_Insureds_DOB__c       = payload.siDOB,
            Second_Insured_Occupation__c = payload.siOccupation,
            Marital_Status_SI__c         = payload.siMaritalStatus,
            Second_Insured_Drivers_License__c = payload.siDLNumber,
            Second_Insured_Drivers_License_State__c = payload.siDLState
        );

        // Map Property 1 Address to Lead standard fields BEFORE update
        if (payload.properties != null && !payload.properties.isEmpty()) {
            PropertyWrapper pw1 = payload.properties[0];
            leadToUpdate.Street     = pw1.street;
            leadToUpdate.City       = pw1.city;
            leadToUpdate.State      = pw1.state;
            leadToUpdate.PostalCode = pw1.zip;
        }

        if (payload.leadId == null) {
            leadToUpdate.Company = String.isNotBlank(payload.lastName) ? payload.lastName + ' Household' : '[Not Provided]';
        }

        upsert as user leadToUpdate;

        if (payload.leadId == null) {
            payload.leadId = leadToUpdate.Id;
        }

        // Save Properties
        if (payload.properties != null && !payload.properties.isEmpty()) {
            List<Property_Information__c> piToUpsert = new List<Property_Information__c>();
            for (Integer i = 0; i < payload.properties.size(); i++) {
                PropertyWrapper pw = payload.properties[i];
                Property_Information__c pi = pw.details;
                pi.Lead__c = payload.leadId;

                if (i > 0) {
                    // Property 1 is handled on Lead directly above; others use Properties__c
                    Properties__c p = new Properties__c();
                    if (pi.Properties__c != null) p.Id = pi.Properties__c;
                    p.Lead__c = payload.leadId;
                    p.Address__Street__s = pw.street;
                    p.Address__City__s = pw.city;
                    p.Address__StateCode__s = pw.state;
                    p.Address__PostalCode__s = pw.zip;
                    p.Coverage_Form__c = pw.coverageForm;
                    p.Property_Type__c = pw.propertyType;
                    upsert as user p;
                    pi.Properties__c = p.Id;
                }
                piToUpsert.add(pi);
            }
            upsert as user piToUpsert;

            // Save Animals per property
            List<Animals_on_Premises__c> animalsToUpsert = new List<Animals_on_Premises__c>();
            List<Animals_on_Premises__c> animalsToDelete = new List<Animals_on_Premises__c>();
            for (PropertyWrapper pw : payload.properties) {
                if (pw.animals != null) {
                    for (Animals_on_Premises__c anim : pw.animals) {
                        anim.Property_Information__c = pw.details.Id;
                        animalsToUpsert.add(anim);
                    }
                }
                if (pw.deletedAnimalIds != null) {
                    for (String aid : pw.deletedAnimalIds) {
                        animalsToDelete.add(new Animals_on_Premises__c(Id = aid));
                    }
                }
            }
            if (!animalsToDelete.isEmpty()) delete as user animalsToDelete;
            if (!animalsToUpsert.isEmpty()) upsert as user animalsToUpsert;
        }

        if (payload.priorInsurances != null && !payload.priorInsurances.isEmpty()) {
            for (Prior_Insurance_Information__c prior : payload.priorInsurances) { prior.Lead__c = payload.leadId; }
            upsert as user payload.priorInsurances;
        }
        if (payload.drivers != null && !payload.drivers.isEmpty()) {
            for (Driver__c driver : payload.drivers) { driver.Lead__c = payload.leadId; }
            upsert as user payload.drivers;
        }
        if (payload.vehicles != null && !payload.vehicles.isEmpty()) {
            for (Vehicle__c vehicle : payload.vehicles) { vehicle.Lead__c = payload.leadId; }
            upsert as user payload.vehicles;
        }
        if (payload.incidents != null && !payload.incidents.isEmpty()) {
            for (Auto_Incidents_Violations__c incident : payload.incidents) { incident.Lead__c = payload.leadId; }
            upsert as user payload.incidents;
        }
        if (payload.losses != null && !payload.losses.isEmpty()) {
            for (Home_Losses_Claims__c loss : payload.losses) { loss.Lead__c = payload.leadId; }
            upsert as user payload.losses;
        }

        deleteRecords(payload);
        return leadToUpdate.Id;
    }

    private static Id saveOppData(QuotePayload payload) {
        update as user new Opportunity(Id = payload.oppId, Description = payload.description);

        if (payload.accountId != null) {
            Account accToUpdate = new Account(
                Id                      = payload.accountId,
                First_Name_FI__c        = payload.firstName,
                Last_Name_FI__c         = payload.lastName,
                Email__c                = payload.email,
                Phone                   = payload.phone,
                Phone_2_FI__c           = payload.secondaryPhone,
                Partner_Name__c         = payload.partnerName,
                Loan_Officer_Name__c    = payload.loanOfficerName,
                Referral_Source_Name__c = payload.referralSourceName,
                Processor_Name__c       = payload.processorName,
                Loan_Associate_Name__c  = payload.loanAssociateName,
                Coverage_Form__c        = payload.coverageForm,
                Property_Type__c        = payload.propertyType,
                Insured_Address__Street__s   = payload.insuredStreet,
                Insured_Address__City__s     = payload.insuredCity,
                Insured_Address__StateCode__s= payload.insuredState,
                Insured_Address__PostalCode__s = payload.insuredZip,
                Insured_Address__CountryCode__s= payload.insuredCountry,
                Insured_DOB__c          = payload.dob,
                First_Insured_Marital_Status__c = payload.maritalStatus,
                First_Insured_Occupation__c     = payload.occupation,
                First_Insured_Driver_S_License__c = payload.dlNumber,
                First_Insured_Driver_S_License_State__c = payload.dlState,
                Add_Second_Named_Insured__c     = payload.showSecondInsured,
                Second_Insured_First_Name__c    = payload.siFirstName,
                Second_Insured_Last_Name__c     = payload.siLastName,
                Second_Insured_Phone__c         = payload.siPhone,
                Second_Insured_Phone_2__c       = payload.siSecondaryPhone,
                Second_Insured_Email__c         = payload.siEmail,
                Second_Insured_DOB__c           = payload.siDOB,
                Second_Insured_Occupation__c    = payload.siOccupation,
                Second_Insured_Marital_Status__c = payload.siMaritalStatus,
                Second_Insured_Drivers_License__c = payload.siDLNumber,
                Second_Insured_Drivers_License_State__c = payload.siDLState
            );

            // Map Property 1 Address to Account property fields BEFORE update
            if (payload.properties != null && !payload.properties.isEmpty()) {
                PropertyWrapper pw1 = payload.properties[0];
                accToUpdate.Address_Property__Street__s    = pw1.street;
                accToUpdate.Address_Property__City__s      = pw1.city;
                accToUpdate.Address_Property__StateCode__s = pw1.state;
                accToUpdate.Address_Property__PostalCode__s = pw1.zip;
            }

            update as user accToUpdate;

            // Save Properties
            if (payload.properties != null && !payload.properties.isEmpty()) {
                List<Property_Information__c> piToUpsert = new List<Property_Information__c>();
                for (Integer i = 0; i < payload.properties.size(); i++) {
                    PropertyWrapper pw = payload.properties[i];
                    Property_Information__c pi = pw.details;
                    pi.Account__c = payload.accountId;

                    if (i > 0) {
                        Properties__c p = new Properties__c();
                        if (pi.Properties__c != null) p.Id = pi.Properties__c;
                        p.Account__c = payload.accountId;
                        p.Address__Street__s = pw.street;
                        p.Address__City__s = pw.city;
                        p.Address__StateCode__s = pw.state;
                        p.Address__PostalCode__s = pw.zip;
                        p.Coverage_Form__c = pw.coverageForm;
                        p.Property_Type__c = pw.propertyType;
                        upsert as user p;
                        pi.Properties__c = p.Id;
                    }
                    piToUpsert.add(pi);
                }
                upsert as user piToUpsert;

                // Save Animals per property
                List<Animals_on_Premises__c> animalsToUpsert = new List<Animals_on_Premises__c>();
                List<Animals_on_Premises__c> animalsToDelete = new List<Animals_on_Premises__c>();
                for (PropertyWrapper pw : payload.properties) {
                    if (pw.animals != null) {
                        for (Animals_on_Premises__c anim : pw.animals) {
                            anim.Property_Information__c = pw.details.Id;
                            animalsToUpsert.add(anim);
                        }
                    }
                    if (pw.deletedAnimalIds != null) {
                        for (String aid : pw.deletedAnimalIds) {
                            animalsToDelete.add(new Animals_on_Premises__c(Id = aid));
                        }
                    }
                }
                if (!animalsToDelete.isEmpty()) delete as user animalsToDelete;
                if (!animalsToUpsert.isEmpty()) upsert as user animalsToUpsert;
            }

            if (payload.priorInsurances != null && !payload.priorInsurances.isEmpty()) {
                for (Prior_Insurance_Information__c prior : payload.priorInsurances) { prior.Account__c = payload.accountId; }
                upsert as user payload.priorInsurances;
            }
            if (payload.drivers != null && !payload.drivers.isEmpty()) {
                for (Driver__c driver : payload.drivers) { driver.Account__c = payload.accountId; }
                upsert as user payload.drivers;
            }
            if (payload.vehicles != null && !payload.vehicles.isEmpty()) {
                for (Vehicle__c vehicle : payload.vehicles) { vehicle.Account__c = payload.accountId; }
                upsert as user payload.vehicles;
            }
            if (payload.incidents != null && !payload.incidents.isEmpty()) {
                for (Auto_Incidents_Violations__c incident : payload.incidents) { incident.Account__c = payload.accountId; }
                upsert as user payload.incidents;
            }
            if (payload.losses != null && !payload.losses.isEmpty()) {
                for (Home_Losses_Claims__c loss : payload.losses) { loss.Account__c = payload.accountId; }
                upsert as user payload.losses;
            }
        }

        deleteRecords(payload);
        return payload.oppId;
    }

    private static void deleteRecords(QuotePayload payload) {
        List<SObject> recordsToDelete = new List<SObject>();
        if (payload.deletedPropertyIds != null)       { for (String id : payload.deletedPropertyIds)       { recordsToDelete.add(new Property_Information__c(Id = id)); } }
        if (payload.deletedPriorInsuranceIds != null) { for (String id : payload.deletedPriorInsuranceIds) { recordsToDelete.add(new Prior_Insurance_Information__c(Id = id)); } }
        if (payload.deletedDriverIds != null)         { for (String id : payload.deletedDriverIds)         { recordsToDelete.add(new Driver__c(Id = id)); } }
        if (payload.deletedVehicleIds != null)        { for (String id : payload.deletedVehicleIds)        { recordsToDelete.add(new Vehicle__c(Id = id)); } }
        if (payload.deletedIncidentIds != null)       { for (String id : payload.deletedIncidentIds)       { recordsToDelete.add(new Auto_Incidents_Violations__c(Id = id)); } }
        if (payload.deletedLossIds != null)           { for (String id : payload.deletedLossIds)           { recordsToDelete.add(new Home_Losses_Claims__c(Id = id)); } }
        if (!recordsToDelete.isEmpty()) { delete as user recordsToDelete; }
    }
}