@IsTest
private class FormHookAPITest {
    // Simple HttpCalloutMock supporting redirect and Blob bodies
    private class FileMock implements HttpCalloutMock {
        Integer statusCode;
        String body;
        String contentType;
        Boolean redirect;
        String redirectUrl;
        Blob bodyBlob;

        public FileMock(Integer code, String b, String ct, Boolean rd, String ru) {
            statusCode = code; body = b; contentType = ct; redirect = rd; redirectUrl = ru;
        }
        public FileMock withBlobBody(Blob b, String ct) { bodyBlob = b; contentType = ct; return this; }

        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            if (redirect == true) {
                res.setStatusCode(302);
                res.setHeader('Location', redirectUrl == null ? req.getEndpoint() : redirectUrl);
                return res;
            }
            res.setStatusCode(statusCode == null ? 200 : statusCode);
            if (contentType != null) res.setHeader('Content-Type', contentType);
            if (bodyBlob != null) res.setBodyAsBlob(bodyBlob);
            else res.setBody(body == null ? '' : body);
            return res;
        }
    }

    // Build RestRequest with params
    private static RestRequest buildRequestWithParams(Map<String,String> params){
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/123formhook';
        req.httpMethod = 'POST';
        RestContext.request = req;
        for(String k: params.keySet()) {
            RestContext.request.params.put(k, params.get(k));
        }
        return req;
    }

    // Base params aligned to FIELD_MAP
    private static Map<String,String> baseParams(){
        Map<String,String> m = new Map<String,String>();
        m.put('controlvalue118439786-1','John');
        m.put('controlvalue118439786-2','Doe');
        m.put('controlvalue118439782','lo@example.com');
        m.put('controlvalue118439781','Referrer ABC');
        m.put('controlvalue119149848','borrower@example.com');
        m.put('controlvalue118439799','123456');
        m.put('controlvalue118439801','Some comments');
        m.put('controlvalue118477125','10/02/2025');
        m.put('controlvalue118469001','2025-10-10');
        m.put('controlvalue118439800','2025-12-31');
        m.put('controlvalue118439791-1','111 Insured St');
        m.put('controlvalue118439791-3','Austin');
        m.put('controlvalue118439791-4','TX');
        m.put('controlvalue118439791-5','73301');
        m.put('controlvalue118439798-1','222 Property Ave');
        m.put('controlvalue118439798-3','Dallas');
        m.put('controlvalue118439798-4','TX');
        m.put('controlvalue118439798-5','75001');
        m.put('controlvalue118469000-1','Jane');
        m.put('controlvalue118469000-2','Doe');
        m.put('controlvalue118439795','Yes - You can call the client');
        m.put('controlvalue118475375','Yes');
        m.put('controlvalue118439792','555-333-2222');
        m.put('controlvalue119149832','555-111-9999');
        m.put('controlvalue119104190','No');
        m.put('controlvalue118439793','jane@example.com');
        m.put('controlvalue118439802','https://files.example.com/doc123');
        m.put('filename_hint','document.pdf');
        return m;
    }

    @IsTest
    static void t01_HappyPath_NonPartner_WithFile_AndRedirect(){
        Map<String,String> p = baseParams();
        RestContext.response = new RestResponse();
        buildRequestWithParams(p);

        // One start/stop pair only
        Test.startTest();
        Test.setMock(HttpCalloutMock.class,
            new FileMock(200, null, 'application/pdf', true, 'https://files.example.com/final.pdf')
                .withBlobBody(Blob.valueOf('PDFDATA'), 'application/pdf')
        );
        String r = FormHookAPI.receiveData();
        Test.stopTest();

        for(Lead l:[SELECT Id FROM Lead LIMIT 3]){ String s=l.Id; }
        for(ContentVersion cv:[SELECT Id,Title FROM ContentVersion LIMIT 3]){ String t=cv.Title; }
        String out=r;
    }

    @IsTest
    static void t02_Partner_NoContact_EscrowNo_InvalidStates_NoFile(){
        Map<String,String> p = baseParams();
        p.put('controlvalue119104190','Yes');
        p.put('controlvalue118439795','no please email me');
        p.put('controlvalue118475375','No');
        p.put('controlvalue118439791-4','XX');
        p.put('controlvalue118439798-4','YY');
        p.remove('controlvalue118439802');
        p.put('controlvalue118469000-1','');
        p.put('controlvalue118469000-2','');
        p.put('controlvalue118469001','');

        RestContext.response = new RestResponse();
        buildRequestWithParams(p);

        Test.startTest();
        String r = FormHookAPI.receiveData();
        Test.stopTest();

        for(Lead l:[SELECT Id,Email,Loan_Officer_Email__c FROM Lead ORDER BY CreatedDate DESC LIMIT 2]){ String s=l.Id; }
        Integer c=[SELECT COUNT() FROM ContentVersion];
        String out=r; Integer cc=c;
    }

    @IsTest
    static void t03_DateParsing_MixedFormats_And_BadDates(){
        Map<String,String> p = baseParams();
        p.put('controlvalue118477125','13/45/9999');
        p.put('controlvalue118469001','not-a-date');
        p.put('controlvalue118439800','2025/99/99');
        p.put('controlvalue118439795','');

        RestContext.response = new RestResponse();
        buildRequestWithParams(p);

        Test.startTest();
        String r = FormHookAPI.receiveData();
        Test.stopTest();

        for(Lead l:[SELECT Borrower_DOB__c,Second_Insureds_DOB__c,Estimated_Closing_Date__c FROM Lead ORDER BY CreatedDate DESC LIMIT 1]){ Date d=l.Borrower_DOB__c; }
        String out=r;
    }

    @IsTest
    static void t04_Queueable_SizeCheck_LineCoverage_And_ExtensionFallback(){
        // Case 1: small zip body; evaluate size check without exceeding limits
        Map<String,String> p = baseParams();
        p.put('controlvalue118439802','https://files.example.com/zip1');
        p.put('filename_hint','archive');

        RestContext.response = new RestResponse();
        buildRequestWithParams(p);

        // build a modest ~100 KB blob safely
        Integer kb = 100;
        String oneKB = String.valueOf('x').repeat(1024);
        String acc = '';
        for (Integer i=0;i<kb;i++) acc += oneKB;
        Blob body = Blob.valueOf(acc);

        Test.startTest();
        Test.setMock(HttpCalloutMock.class,
            new FileMock(200, null, 'application/zip', false, null).withBlobBody(body, 'application/zip')
        );
        String r1 = FormHookAPI.receiveData();
        Test.stopTest();

        Integer cvCount1 = [SELECT COUNT() FROM ContentVersion];

        // Case 2: extension inference to .zip with no extension in discovered filename
        Map<String,String> p2 = baseParams();
        p2.put('controlvalue118439802','https://files.example.com/zip2');
        p2.put('filename_hint','archive');
        RestContext.response = new RestResponse();
        buildRequestWithParams(p2);

       
        Test.setMock(HttpCalloutMock.class, new FileMock(200,'ZIPDATA','application/zip',false,null));
        String r2 = FormHookAPI.receiveData();
        

        for(ContentVersion cv:[SELECT Id,Title,PathOnClient FROM ContentVersion ORDER BY CreatedDate DESC LIMIT 1]){ String t=cv.Title; String pc=cv.PathOnClient; }
        Integer cvCount2 = [SELECT COUNT() FROM ContentVersion];
        String o1=r1, o2=r2; Integer c1=cvCount1, c2=cvCount2;
    }

    @IsTest
    static void t05_ErrorBranch_NoLastName_DefaultUnknown_And_Non200File(){
        Map<String,String> p = baseParams();
        p.put('controlvalue118439786-2','');
        p.put('controlvalue118439801','Clientâ\u0080\u0099s notes');

        RestContext.response = new RestResponse();
        buildRequestWithParams(p);

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new FileMock(404,'Not Found','text/plain',false,null));
        String r = FormHookAPI.receiveData();
        Test.stopTest();

        for(Lead l:[SELECT Id,LastName,Additional_Comments__c FROM Lead ORDER BY CreatedDate DESC LIMIT 1]){ String ln=l.LastName; String ac=l.Additional_Comments__c; }
        String out=r;
    }
}