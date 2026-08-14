public with sharing class QBO_CustomerSyncController {
    
    // Dynamic Active QuickBooks Setting
    private static QuickBooks_Setting__mdt cachedSetting;
    private static QuickBooks_Setting__mdt activeSetting {
        get {
            if (cachedSetting == null) {
                cachedSetting = [SELECT Realm_ID__c, Named_Credential__c FROM QuickBooks_Setting__mdt WHERE Is_Active__c = true LIMIT 1];
            }
            return cachedSetting;
        }
    }

    @AuraEnabled
    public static String syncAccountToQBO(Id accountId) {
        try {
            // 1. Retrieve the Account data
            Account acc = [SELECT Id, Name, Phone FROM Account WHERE Id = :accountId LIMIT 1];
            
            // 2. Generate the JSON Payload using the Wrapper (from previous step)
            QBO_CustomerRequestWrapper payloadWrapper = new QBO_CustomerRequestWrapper(acc);
            String jsonBody = JSON.serialize(payloadWrapper, true);
            
            // 3. Configure the HTTP Request using the Named Credential
            HttpRequest req = new HttpRequest();
            req.setEndpoint('callout:' + activeSetting.Named_Credential__c + '/v3/company/' + activeSetting.Realm_ID__c + '/customer?minorversion=69');
            req.setMethod('POST');
            req.setHeader('Accept', 'application/json');
            req.setHeader('Content-Type', 'application/json');
            req.setBody(jsonBody);
            
            // 4. Execute the Callout
            Http http = new Http();
            HttpResponse res = http.send(req);
            
            // 5. Process the Response
            if (res.getStatusCode() == 200) {
                return 'SUCCESS';
            } else {
                return 'ERROR: ' + res.getStatusCode() + ' - ' + res.getBody();
            }
            
        } catch (Exception e) {
            return 'CRITICAL ERROR: ' + e.getMessage();
        }
    }
}