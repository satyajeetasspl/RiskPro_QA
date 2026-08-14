public with sharing class LeadQuoteController {
    
    public class QuotePayload {
        @AuraEnabled public Id leadId { get; set; }
        @AuraEnabled public String firstName { get; set; }
        @AuraEnabled public String lastName { get; set; }
        @AuraEnabled public String email { get; set; }
        @AuraEnabled public String phone { get; set; }
        @AuraEnabled public String phone2 { get; set; }
        @AuraEnabled public String street { get; set; }
        @AuraEnabled public String city { get; set; }
        @AuraEnabled public String state { get; set; }
        @AuraEnabled public String zip { get; set; }
        @AuraEnabled public String country { get; set; }
        @AuraEnabled public String partnerName { get; set; }
        @AuraEnabled public String loanOfficerName { get; set; }
        @AuraEnabled public String referralSourceName { get; set; }
        @AuraEnabled public String processorName { get; set; }
        @AuraEnabled public String loanAssociateName { get; set; }
        @AuraEnabled public String coverageForm { get; set; }
        @AuraEnabled public String propertyType { get; set; }
        @AuraEnabled public String personalLines { get; set; }
        @AuraEnabled public String commercialLines { get; set; }
        @AuraEnabled public String description { get; set; }
        
        @AuraEnabled public List<Property_Information__c> properties { get; set; }
        @AuraEnabled public List<String> deletedPropertyIds { get; set; }
        
        @AuraEnabled public List<Prior_Insurance_Information__c> priorInsurances { get; set; }
        @AuraEnabled public List<String> deletedPriorInsuranceIds { get; set; }
        
        @AuraEnabled public List<Driver__c> drivers { get; set; }
        @AuraEnabled public List<String> deletedDriverIds { get; set; }
        
        @AuraEnabled public List<Vehicle__c> vehicles { get; set; }
        @AuraEnabled public List<String> deletedVehicleIds { get; set; }
        
        @AuraEnabled public List<Auto_Incidents_Violations__c> incidents { get; set; }
        @AuraEnabled public List<String> deletedIncidentIds { get; set; }
    }

    @AuraEnabled(cacheable=true)
    public static QuotePayload getQuoteData(Id leadId) {
        QuotePayload payload = new QuotePayload();
        payload.leadId = leadId;
        
        Lead l = [SELECT FirstName, LastName, Email, Borrowers_Phone_Number__c, Phone_2__c, Partner_Name__c, Loan_Officer_Name__c, Referral_Source_Name__c, Processor_Name__c, Loan_Associate_Name__c, Coverage_Form__c, Property_Type__c, Personal_Lines__c, Commercial_Lines__c, Description, Insured_Address__Street__s, Insured_Address__City__s, Insured_Address__StateCode__s, Insured_Address__PostalCode__s, Insured_Address__CountryCode__s FROM Lead WHERE Id = :leadId WITH USER_MODE LIMIT 1];
        
        payload.firstName = l.FirstName;
        payload.lastName = l.LastName;
        payload.email = l.Email;
        payload.phone = l.Borrowers_Phone_Number__c;
        payload.phone2 = l.Phone_2__c;
        payload.partnerName = l.Partner_Name__c;
        payload.loanOfficerName = l.Loan_Officer_Name__c;
        payload.referralSourceName = l.Referral_Source_Name__c;
        payload.processorName = l.Processor_Name__c;
        payload.loanAssociateName = l.Loan_Associate_Name__c;
        payload.coverageForm = l.Coverage_Form__c;
        payload.propertyType = l.Property_Type__c;
        payload.personalLines = l.Personal_Lines__c;
        payload.commercialLines = l.Commercial_Lines__c;
        payload.description = l.Description;
        payload.street = l.Insured_Address__Street__s;
        payload.city = l.Insured_Address__City__s;
        payload.state = l.Insured_Address__StateCode__s;
        payload.zip = l.Insured_Address__PostalCode__s;
        payload.country = l.Insured_Address__CountryCode__s;
        
        payload.properties = [SELECT Id, Heating_Year__c, Plumbing_Year__c, Wiring_Year__c, Complete__c, Partial__c FROM Property_Information__c WHERE Lead__c = :leadId WITH USER_MODE];
        payload.priorInsurances = [SELECT Id, Carrier_Name__c, Line__c, Policy_Number__c, Bodily_Injury_Limits__c, Length_with_Current_Carrier__c FROM Prior_Insurance_Information__c WHERE Lead__c = :leadId WITH USER_MODE];
        payload.drivers = [SELECT Id, First_Name__c, Last_Name__c, Date_of_Birth__c, Relationship_to_Insured__c, Marital_Status__c, DL__c FROM Driver__c WHERE Lead__c = :leadId WITH USER_MODE];
        payload.vehicles = [SELECT Id, Year__c, Make__c, Model__c, VIN__c FROM Vehicle__c WHERE Lead__c = :leadId WITH USER_MODE];
        payload.incidents = [SELECT Id, Incident_Description__c, Additional_Information__c FROM Auto_Incidents_Violations__c WHERE Lead__c = :leadId WITH USER_MODE];
        
        return payload;
    }

    @AuraEnabled
    public static void saveQuoteData(String jsonPayload) {
        try {
            QuotePayload payload = (QuotePayload) JSON.deserialize(jsonPayload, QuotePayload.class);
            
            Lead leadToUpdate = new Lead(
                Id = payload.leadId,
                FirstName = payload.firstName,
                LastName = payload.lastName,
                Email = payload.email,
                Phone = payload.phone,
                Phone_2__c = payload.phone2,
                Partner_Name__c = payload.partnerName,
                Loan_Officer_Name__c = payload.loanOfficerName,
                Referral_Source_Name__c = payload.referralSourceName,
                Processor_Name__c = payload.processorName,
                Loan_Associate_Name__c = payload.loanAssociateName,
                Coverage_Form__c = payload.coverageForm,
                Property_Type__c = payload.propertyType,
                Personal_Lines__c = payload.personalLines,
                Commercial_Lines__c = payload.commercialLines,
                Description = payload.description,
                Insured_Address__Street__s = payload.street,
                Insured_Address__City__s = payload.city,
                Insured_Address__StateCode__s = payload.state,
                Insured_Address__PostalCode__s = payload.zip,
                Insured_Address__CountryCode__s = payload.country
            );
            
            update as user leadToUpdate;

            if (payload.properties != null && !payload.properties.isEmpty()) {
                for (Property_Information__c prop : payload.properties) { prop.Lead__c = payload.leadId; }
                upsert as user payload.properties;
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

            List<SObject> recordsToDelete = new List<SObject>();
            if (payload.deletedPropertyIds != null) { for (String delId : payload.deletedPropertyIds) { recordsToDelete.add(new Property_Information__c(Id = delId)); } }
            if (payload.deletedPriorInsuranceIds != null) { for (String delId : payload.deletedPriorInsuranceIds) { recordsToDelete.add(new Prior_Insurance_Information__c(Id = delId)); } }
            if (payload.deletedDriverIds != null) { for (String delId : payload.deletedDriverIds) { recordsToDelete.add(new Driver__c(Id = delId)); } }
            if (payload.deletedVehicleIds != null) { for (String delId : payload.deletedVehicleIds) { recordsToDelete.add(new Vehicle__c(Id = delId)); } }
            if (payload.deletedIncidentIds != null) { for (String delId : payload.deletedIncidentIds) { recordsToDelete.add(new Auto_Incidents_Violations__c(Id = delId)); } }
            
            if (!recordsToDelete.isEmpty()) {
                delete as user recordsToDelete;
            }

        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
}