@RestResource(urlMapping='/contact/get')
global with sharing class ContactRestService {
 
    // Example JSON Body: { "contactId": "003XXXXXXXXXXXXXXX" }
    @HttpPost
    global static ContactResponse getContactData() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
 
        try {
            // Parse incoming JSON
            Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(req.requestBody.toString());
            String contactId = (String) body.get('contactId');
            if (String.isBlank(contactId)) {
                res.statusCode = 400;
                return new ContactResponse('Error: contactId is required', null);
            }
 
            // Query Contact
            Contact c = [SELECT Id, Name, Email, Phone FROM Contact WHERE Id = :contactId LIMIT 1];
 
            // Return success response
            res.statusCode = 200;
            return new ContactResponse('Success', c);
 
        } catch (QueryException qe) {
            res.statusCode = 404;
            return new ContactResponse('Contact not found', null);
        } catch (Exception e) {
            res.statusCode = 500;
            return new ContactResponse('Error: ' + e.getMessage(), null);
        }
    }
 
    // Response wrapper
    global class ContactResponse {
        public String message;
        public Contact contact;
 
        public ContactResponse(String message, Contact contact) {
            this.message = message;
            this.contact = contact;
        }
    }
}