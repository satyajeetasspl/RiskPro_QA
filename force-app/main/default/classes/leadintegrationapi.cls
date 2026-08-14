@RestResource(urlMapping='/leadintegration/*')
global with sharing class leadintegrationapi {
    
    // 1. Wrapper for Address Fields
    global class AddressInfo {
        public String street;
        public String city;
        public String state;
        public String zipCode;
        public String country;
    }

    // 2. Main Request Wrapper
    global class LeadRequest {
        public String firstName;
        public String lastName;
        public String phone;
        public String email;
        public String loanNumber;
        public AddressInfo currentAddress;
        public AddressInfo propertyAddress;
        public String fileName;    
        public String fileData;    
    }

    // 3. Response Wrapper
    global class ApiResponse {
        public Boolean isSuccess;
        public String message;
        public String leadId;
    }

    @HttpPost
    global static ApiResponse createLead() {
        ApiResponse response = new ApiResponse();
        RestRequest req = RestContext.request;
        
        try {
            LeadRequest payload = (LeadRequest) JSON.deserialize(req.requestBody.toString(), LeadRequest.class);
            
            if (String.isBlank(payload.lastName)) {
                response.isSuccess = false;
                response.message = 'Last Name is required.';
                return response;
            }

            Lead newLead = new Lead();
            newLead.FirstName = payload.firstName;
            newLead.LastName = payload.lastName;
            newLead.Company = 'Unknown'; 
            newLead.Phone = payload.phone;
            newLead.Email = payload.email;
            newLead.Loan__c = payload.loanNumber; // Mapped to the API name from your schema dump

            // --- SWAPPED: Current Address -> Custom Insured_Address__c (Uses __s) ---
            if (payload.currentAddress != null) {
                newLead.Insured_Address__Street__s      = payload.currentAddress.street;
                newLead.Insured_Address__City__s        = payload.currentAddress.city;
                newLead.Insured_Address__PostalCode__s  = payload.currentAddress.zipCode;
                // If State/Country Picklists are disabled, change these to State__s and Country__s
                newLead.Insured_Address__StateCode__s   = payload.currentAddress.state;
                newLead.Insured_Address__CountryCode__s = payload.currentAddress.country;
            }

            // --- SWAPPED: Property Address -> Standard Lead Address (Uses standard flat names) ---
            if (payload.propertyAddress != null) {
                newLead.Street     = payload.propertyAddress.street;
                newLead.City       = payload.propertyAddress.city;
                newLead.PostalCode = payload.propertyAddress.zipCode;
                newLead.State      = payload.propertyAddress.state; 
                newLead.Country    = payload.propertyAddress.country; 
            }

            insert newLead;

            // Deserialize and attach the file
            if (String.isNotBlank(payload.fileData) && String.isNotBlank(payload.fileName)) {
                
                ContentVersion cv = new ContentVersion();
                cv.Title = payload.fileName; 
                cv.PathOnClient = payload.fileName;
                cv.VersionData = EncodingUtil.base64Decode(payload.fileData); 
                insert cv;

                Id contentDocId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id LIMIT 1].ContentDocumentId;
                
                ContentDocumentLink cdl = new ContentDocumentLink();
                cdl.ContentDocumentId = contentDocId;
                cdl.LinkedEntityId = newLead.Id; 
                cdl.ShareType = 'V'; 
                insert cdl;
            }

            response.isSuccess = true;
            response.message = 'Lead and file successfully created!';
            response.leadId = newLead.Id;

        } catch (Exception e) {
            response.isSuccess = false;
            response.message = 'Error creating Lead: ' + e.getMessage();
        }

        return response;
    }
}