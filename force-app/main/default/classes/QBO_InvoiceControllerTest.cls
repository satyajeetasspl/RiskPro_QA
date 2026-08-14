@IsTest
public class QBO_InvoiceControllerTest {

    @TestSetup
    static void setup() {
        Lead testLead = new Lead(
            FirstName = 'Test',
            LastName = 'Lead',
            Company = 'Test Co',
            Email = 'test@example.com',
            Phone = '1234567890'
        );
        insert testLead;

        Policy_Information__c pol = new Policy_Information__c(
            Lead__c = testLead.Id,
            Agency_Fee__c = 100.00,
            Lines__c = 'Homeowners'
        );
        insert pol;
    }

    @IsTest
    static void testCreateInvoiceSuccess() {
        Lead ld = [SELECT Id FROM Lead LIMIT 1];
        
        Test.setMock(HttpCalloutMock.class, new QBO_Mock(200, '{"QueryResponse": {"Customer": [{"Id": "123"}]}, "Invoice": {"InvoiceLink": "http://qbo.link/123"}}'));
        
        Test.startTest();
        String result = QBO_InvoiceController.createQBOInvoice(ld.Id);
        Test.stopTest();
        
        System.assert(result.startsWith('http'), 'Should return a link: ' + result);
    }

    @IsTest
    static void testCreateInvoiceNoPolicies() {
        Lead ld = [SELECT Id FROM Lead LIMIT 1];
        delete [SELECT Id FROM Policy_Information__c];
        
        Test.startTest();
        String result = QBO_InvoiceController.createQBOInvoice(ld.Id);
        Test.stopTest();
        
        System.assert(result.contains('ERROR: No policies'), 'Should return no policies error');
    }

    @IsTest
    static void testCustomerNotFoundThenCreate() {
        Lead ld = [SELECT Id FROM Lead LIMIT 1];
        
        // Mock 1: Empty Query, Mock 2: Create Customer, Mock 3: Create Invoice
        Test.setMock(HttpCalloutMock.class, new QBO_MultiMock());
        
        Test.startTest();
        String result = QBO_InvoiceController.createQBOInvoice(ld.Id);
        Test.stopTest();
        
        System.assert(result.startsWith('http'), 'Should return a link after creating customer');
    }

    // Simple Mock for single responses
    public class QBO_Mock implements HttpCalloutMock {
        Integer code;
        String body;
        public QBO_Mock(Integer c, String b) { code = c; body = b; }
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(code);
            res.setBody(body);
            return res;
        }
    }

    // Multi Mock for flow: Query (empty) -> Create Customer -> Create Invoice
    public class QBO_MultiMock implements HttpCalloutMock {
        Integer count = 0;
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            if (count == 0) {
                res.setBody('{"QueryResponse": {}}'); // Not found
            } else if (count == 1) {
                res.setBody('{"Customer": {"Id": "456"}}'); // Created
            } else {
                res.setBody('{"Invoice": {"InvoiceLink": "http://qbo.link/456"}}'); // Invoiced
            }
            count++;
            return res;
        }
    }
}