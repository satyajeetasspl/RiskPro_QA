@RestResource(urlMapping='/partner/register/*')
global with sharing class PartnerRegistrationService {
    
    // 1. What we send BACK to Postman/Riskpro
    global class CreateResponse {
        public Boolean isSuccess;
        public String message;
        public String partnerId; 
    }

    // 2. We ONLY expect an email 
    public class CreateRequest {
        public String email;
    }

    @HttpPost
    global static CreateResponse createPartner() {
        CreateResponse response = new CreateResponse();
        
        try {
            // 3. Grab the raw JSON message
            RestRequest req = RestContext.request;
            String jsonBody = req.requestBody.toString();
            
            // 4. Translate the JSON 
            CreateRequest requestData = (CreateRequest) JSON.deserialize(jsonBody, CreateRequest.class);
            
            // 5. Check if Email is missing
            if (String.isBlank(requestData.email)) {
                response.isSuccess = false;
                response.message = 'Email is required to create a Partner.';
                return response;
            }

            // 6. Build the new Salesforce Record in memory
            Partner__c newPartner = new Partner__c();
            newPartner.Email__c = requestData.email;
            
            // Note: We are NO LONGER setting the Name field here. 
            // Salesforce will automatically generate the "P-XXXX" number!

            // 7. Save it to the database! 
            insert newPartner;

            // 8. Tell Postman it was a success
            response.isSuccess = true;
            response.message = 'Partner record successfully created. Verification email sent!';
            response.partnerId = newPartner.Id;

        } catch (Exception e) {
            response.isSuccess = false;
            response.message = 'Error creating partner: ' + e.getMessage();
        }

        return response;
    }



@HttpPatch
    global static CreateResponse verifyPartner() {
        CreateResponse response = new CreateResponse();
        
        try {
            // Grab the raw JSON message
            RestRequest req = RestContext.request;
            String jsonBody = req.requestBody.toString();
            
            // Deserialize as a generic map so we don't have to change your inner classes
            Map<String, Object> requestData = (Map<String, Object>) JSON.deserializeUntyped(jsonBody);
            String email = (String) requestData.get('email');
            String verificationCode = (String) requestData.get('verificationCode');
            
            // Check if Email or Code is missing
            if (String.isBlank(email) || String.isBlank(verificationCode)) {
                response.isSuccess = false;
                response.message = 'Email and Verification Code are required for verification.';
                return response;
            }

            // Query the database to find a PERFECT match
            List<Partner__c> partners = [
                SELECT Id, Is_Verified__c, Verification_Code__c 
                FROM Partner__c 
                WHERE Email__c = :email 
                AND Verification_Code__c = :verificationCode 
                LIMIT 1
            ];

            // Check the result and update the record
            if (!partners.isEmpty()) {
                Partner__c p = partners[0];
                p.Is_Verified__c = true;
                p.Verification_Code__c = null; // Delete the code so it can't be used twice
                update p;

                response.isSuccess = true;
                response.message = 'Account successfully verified! Checkbox is now checked.';
                response.partnerId = p.Id;
            } else {
                response.isSuccess = false;
                response.message = 'Invalid email or verification code.';
            }

        } catch (Exception e) {
            response.isSuccess = false;
            response.message = 'Error verifying partner: ' + e.getMessage();
        }

        return response;
    }
}