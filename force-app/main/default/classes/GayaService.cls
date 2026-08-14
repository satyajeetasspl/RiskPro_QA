public with sharing class GayaService {

    @AuraEnabled
    public static String sendDataToGaya() {

        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:Gaya_Sandbox/clipboard_records');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setTimeout(60000);

        String body = JSON.serialize(new Map<String, Object>{
            'industry' => 'personal_line_insurance',
            'entities' => new List<Object>{

                // CUSTOMER
                new Map<String, Object>{
                    'entity' => 'customer',
                    'index' => 1,
                    'fields' => new List<Object>{
                        new Map<String, Object>{ 'name' => 'email', 'value' => 'johndoe@example.com' },
                        new Map<String, Object>{ 'name' => 'phone_number', 'value' => '5551234567' },
                        new Map<String, Object>{ 'name' => 'first_name', 'value' => 'John' },
                        new Map<String, Object>{ 'name' => 'last_name', 'value' => 'Doe' },
                        new Map<String, Object>{ 'name' => 'date_of_birth', 'value' => '1985-03-15' }
                    }
                },

                // CAR
                new Map<String, Object>{
                    'entity' => 'car',
                    'index' => 1,
                    'fields' => new List<Object>{
                        new Map<String, Object>{ 'name' => 'make', 'value' => 'Toyota' },
                        new Map<String, Object>{ 'name' => 'model', 'value' => 'Camry' },
                        new Map<String, Object>{ 'name' => 'year', 'value' => '2020' },
                        new Map<String, Object>{ 'name' => 'vin', 'value' => '1HGBH41JXMN109186' }
                    }
                },

                // HOUSEHOLD
                new Map<String, Object>{
                    'entity' => 'household',
                    'index' => 2,
                    'fields' => new List<Object>{
                        new Map<String, Object>{ 'name' => 'first_name', 'value' => 'Jane' },
                        new Map<String, Object>{ 'name' => 'last_name', 'value' => 'Doe' },
                        new Map<String, Object>{ 'name' => 'relationship', 'value' => 'spouse' }
                    }
                },

                // PROPERTY
                new Map<String, Object>{
                    'entity' => 'property',
                    'index' => 1,
                    'fields' => new List<Object>{
                        new Map<String, Object>{ 'name' => 'address_1', 'value' => '123 Main Street' },
                        new Map<String, Object>{ 'name' => 'city', 'value' => 'Anytown' },
                        new Map<String, Object>{ 'name' => 'state', 'value' => 'CA' },
                        new Map<String, Object>{ 'name' => 'zip_code', 'value' => '90210' }
                    }
                }
            }
        });

        req.setBody(body);

        Http http = new Http();
        HttpResponse res = http.send(req);

        System.debug('STATUS: ' + res.getStatusCode());
        System.debug('RESPONSE: ' + res.getBody());

        if (res.getStatusCode() >= 200 && res.getStatusCode() < 300) {
            return res.getBody();
        } else {
            throw new CalloutException('Error: ' + res.getStatusCode() + ' - ' + res.getBody());
        }
    }
}