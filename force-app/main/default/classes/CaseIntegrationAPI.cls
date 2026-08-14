@RestResource(urlMapping='/caseintegration/*')
global with sharing class CaseIntegrationAPI {
    
    // 1. Main Request Wrapper
    global class CaseRequest {
        public String webName;
        public String contactEmail;
        public String subject;
        public String description;
    }

    // 2. Response Wrapper
    global class ApiResponse {
        public Boolean isSuccess;
        public String message;
        public String caseId;
    }

    @HttpPost
    global static ApiResponse createCase() {
        ApiResponse response = new ApiResponse();
        RestRequest req = RestContext.request;
        
        try {
            // Parse the incoming JSON
            CaseRequest payload = (CaseRequest) JSON.deserialize(req.requestBody.toString(), CaseRequest.class);
            
            // Validate required fields
            if (String.isBlank(payload.subject)) {
                response.isSuccess = false;
                response.message = 'Subject is required to create a Case.';
                return response;
            }

            // --- CREATE THE CASE ---
            Case newCase = new Case();
            
            // Map the exact fields
            newCase.SuppliedName  = payload.webName;
            newCase.SuppliedEmail = payload.contactEmail; 
            newCase.Subject       = payload.subject;
            newCase.Description   = payload.description;

            // Default Case Origin
            newCase.Origin = 'Web'; 

            // Save to database
            insert newCase;

            // Success Return
            response.isSuccess = true;
            response.message = 'Case successfully created!';
            response.caseId = newCase.Id;

        } catch (Exception e) {
            response.isSuccess = false;
            response.message = 'Error creating Case: ' + e.getMessage();
        }

        return response;
    }
}