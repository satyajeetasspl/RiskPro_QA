@IsTest
private class ContactRestServiceTest {
    @TestSetup
    static void makeData() {
        Contact testContact = new Contact(FirstName = 'Test', LastName = 'User', Email = 'test@example.com', Phone = '555-1212');
        insert testContact;
    }

    static testmethod void testGetContactData_Success() {
        Contact c = [SELECT Id FROM Contact LIMIT 1];
        String contactId = c.Id;

        RestRequest req = new RestRequest();
        req.requestURI = '/contact/get';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf('{"contactId": "' + contactId + '"}');

        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        ContactRestService.ContactResponse response = ContactRestService.getContactData();
        Test.stopTest();
    }

    static testmethod void testGetContactData_MissingId() {
        RestRequest req = new RestRequest();
        req.requestURI = '/contact/get';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf('{}');

        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        ContactRestService.ContactResponse response = ContactRestService.getContactData();
        Test.stopTest();
    }

    static testmethod void testGetContactData_ContactNotFound() {
        String fakeId = '003' + String.valueOf(Limits.getLimitDmlRows()).repeat(15);
        fakeId = fakeId.substring(0, 18);

        RestRequest req = new RestRequest();
        req.requestURI = '/contact/get';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf('{"contactId": "' + fakeId + '"}');

        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        ContactRestService.ContactResponse response = ContactRestService.getContactData();
        Test.stopTest();
    }

    static testmethod void testGetContactData_GenericException() {
        RestRequest req = new RestRequest();
        req.requestURI = '/contact/get';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf('This is not valid JSON');

        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        ContactRestService.ContactResponse response = ContactRestService.getContactData();
        Test.stopTest();
    }
}