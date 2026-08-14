public with sharing class GayaServiceNew {

    public class Request {
        @InvocableVariable(required=true)
        public Id leadId;
    }

    public class Response {
        @InvocableVariable
        public String result;
    }

    @InvocableMethod(label='Send Lead to Gaya')
    public static List<Response> sendLeadToGaya(List<Request> requests) {

        List<Response> responses = new List<Response>();

        if (requests == null || requests.isEmpty()) {
            return responses;
        }

        for (Request reqInput : requests) {

            Response r = new Response();

            try {

                // =====================================================
                // VALIDATION
                // =====================================================

                if (reqInput == null || reqInput.leadId == null) {

                    r.result = 'Skipped: Lead Id is null.';
                    responses.add(r);

                    continue;
                }

                // =====================================================
                // FETCH LEAD
                // =====================================================

                Lead l = [
                    SELECT
                        FirstName,
                        LastName,
                        Email,
                        Borrowers_Phone_Number__c,
                        Borrower_DOB__c,
                        Second_Insured_First_Name__c,
                        Second_Insured_Last_Name__c,
                        Relationship_to_Insured__c
                    FROM Lead
                    WHERE Id = :reqInput.leadId
                    LIMIT 1
                ];

                // =====================================================
                // FETCH VEHICLES
                // =====================================================

                List<Vehicle__c> vehicles = [
                    SELECT
                        Vehicle_Type__c,
                        Make__c,
                        Model__c,
                        Year__c,
                        VIN__c
                    FROM Vehicle__c
                    WHERE Lead__c = :reqInput.leadId
                ];

                // =====================================================
                // FETCH PROPERTIES
                // =====================================================

                List<Properties__c> propertiesList = [
                    SELECT
                        Address__Street__s,
                        Address__City__s,
                        Address__StateCode__s,
                        Address__PostalCode__s,
                        Address__CountryCode__s,
                        Address_Type__c,
                        Coverage_Form__c,
                        Loan__c,
                        Mortgage_Amount__c,
                        Property_Type__c,
                        Additional_Comments__c,
                        Escrowed__c,
                        Estimated_Closing_Date__c,
                        Initial_Payment_Method_If_Escrowed__c
                    FROM Properties__c
                    WHERE Lead__c = :reqInput.leadId
                ];

                // =====================================================
                // ENTITIES LIST
                // =====================================================

                List<Object> entitiesList = new List<Object>();

                // =====================================================
                // CUSTOMER ENTITY
                // =====================================================
                
                List<Object> customerFields = new List<Object>();
                
                if (l.FirstName != null) {
                    customerFields.add(new Map<String, Object>{
                        'name' => 'first_name',
                        'value' => l.FirstName
                    });
                }
                
                if (l.LastName != null) {
                    customerFields.add(new Map<String, Object>{
                        'name' => 'last_name',
                        'value' => l.LastName
                    });
                }
                
                if (l.Email != null) {
                    customerFields.add(new Map<String, Object>{
                        'name' => 'email',
                        'value' => l.Email
                    });
                }
                
                if (l.Borrowers_Phone_Number__c != null) {
                    customerFields.add(new Map<String, Object>{
                        'name' => 'phone_number',
                        'value' => l.Borrowers_Phone_Number__c
                    });
                }
                
                if (l.Borrower_DOB__c != null) {
                    customerFields.add(new Map<String, Object>{
                        'name' => 'date_of_birth',
                        'value' => String.valueOf(l.Borrower_DOB__c)
                    });
                }
                
                if (!customerFields.isEmpty()) {
                
                    entitiesList.add(new Map<String, Object>{
                        'entity' => 'customer',
                        'index' => 1,
                        'fields' => customerFields
                    });
                }
                
                // =====================================================
                // HOUSEHOLD ENTITY
                // =====================================================

                List<Object> householdFields = new List<Object>();

                if (l.Second_Insured_First_Name__c != null) {
                    householdFields.add(new Map<String, Object>{
                        'name' => 'first_name',
                        'value' => l.Second_Insured_First_Name__c
                    });
                }

                if (l.Second_Insured_Last_Name__c != null) {
                    householdFields.add(new Map<String, Object>{
                        'name' => 'last_name',
                        'value' => l.Second_Insured_Last_Name__c
                    });
                }

                if (l.Relationship_to_Insured__c != null) {
                    householdFields.add(new Map<String, Object>{
                        'name' => 'relationship',
                        'value' => l.Relationship_to_Insured__c
                    });
                }

                if (!householdFields.isEmpty()) {

                    entitiesList.add(new Map<String, Object>{
                        'entity' => 'household',
                        'index' => 2,
                        'fields' => householdFields
                    });
                }

                // =====================================================
                // CAR ENTITY
                // =====================================================

                Integer carIndex = 1;

                if (vehicles != null && !vehicles.isEmpty()) {

                    for (Vehicle__c v : vehicles) {

                        List<Object> carFields = new List<Object>();

                        // TYPE
                        if (v.Vehicle_Type__c != null) {
                            carFields.add(new Map<String, Object>{
                                'name' => 'type',
                                'value' => v.Vehicle_Type__c
                            });
                        }

                        // VIN
                        if (v.VIN__c != null) {
                            carFields.add(new Map<String, Object>{
                                'name' => 'vin',
                                'value' => v.VIN__c
                            });
                        }

                        // CAR YEAR
                        if (v.Year__c != null) {
                            carFields.add(new Map<String, Object>{
                                'name' => 'car_year',
                                'value' => String.valueOf(v.Year__c)
                            });
                        }

                        // MAKE
                        if (v.Make__c != null) {
                            carFields.add(new Map<String, Object>{
                                'name' => 'make',
                                'value' => v.Make__c
                            });
                        }

                        // MODEL
                        if (v.Model__c != null) {
                            carFields.add(new Map<String, Object>{
                                'name' => 'model',
                                'value' => v.Model__c
                            });
                        }

                        if (!carFields.isEmpty()) {

                            entitiesList.add(new Map<String, Object>{
                                'entity' => 'car',
                                'index' => carIndex,
                                'fields' => carFields
                            });

                            carIndex++;
                        }
                    }
                }

                // =====================================================
                // PROPERTY ENTITY
                // =====================================================

                Integer propertyIndex = 1;

                if (propertiesList != null && !propertiesList.isEmpty()) {

                    for (Properties__c p : propertiesList) {

                        List<Object> propertyFields = new List<Object>();

                        // ADDRESS 1
                        if (p.Address__Street__s != null) {
                            propertyFields.add(new Map<String, Object>{
                                'name' => 'address_1',
                                'value' => p.Address__Street__s
                            });
                        }

                        // CITY
                        if (p.Address__City__s != null) {
                            propertyFields.add(new Map<String, Object>{
                                'name' => 'city',
                                'value' => p.Address__City__s
                            });
                        }

                        // STATE
                        if (p.Address__StateCode__s != null) {
                            propertyFields.add(new Map<String, Object>{
                                'name' => 'state',
                                'value' => p.Address__StateCode__s
                            });
                        }

                        // ZIP CODE
                        if (p.Address__PostalCode__s != null) {
                            propertyFields.add(new Map<String, Object>{
                                'name' => 'zip_code',
                                'value' => p.Address__PostalCode__s
                            });
                        }

                        // COUNTRY
                        if (p.Address__CountryCode__s != null) {
                            propertyFields.add(new Map<String, Object>{
                                'name' => 'country',
                                'value' => p.Address__CountryCode__s
                            });
                        }

                        // ADDRESS TYPE
                        if (p.Address_Type__c != null) {
                            propertyFields.add(new Map<String, Object>{
                                'name' => 'address_type',
                                'value' => p.Address_Type__c
                            });
                        }

                        // COVERAGE FORM
                        if (p.Coverage_Form__c != null) {
                            propertyFields.add(new Map<String, Object>{
                                'name' => 'coverage_form',
                                'value' => p.Coverage_Form__c
                            });
                        }

                        // LOAN NUMBER
                        if (p.Loan__c != null) {
                            propertyFields.add(new Map<String, Object>{
                                'name' => 'loan_number',
                                'value' => p.Loan__c
                            });
                        }

                        // MORTGAGE AMOUNT
                        if (p.Mortgage_Amount__c != null) {
                            propertyFields.add(new Map<String, Object>{
                                'name' => 'mortgage_amount',
                                'value' => String.valueOf(p.Mortgage_Amount__c)
                            });
                        }

                        // PROPERTY TYPE
                        if (p.Property_Type__c != null) {
                            propertyFields.add(new Map<String, Object>{
                                'name' => 'property_type',
                                'value' => p.Property_Type__c
                            });
                        }

                        // COMMENTS
                        if (p.Additional_Comments__c != null) {
                            propertyFields.add(new Map<String, Object>{
                                'name' => 'additional_comments',
                                'value' => p.Additional_Comments__c
                            });
                        }

                        // ESCROWED
                        if (p.Escrowed__c != null) {
                            propertyFields.add(new Map<String, Object>{
                                'name' => 'escrowed',
                                'value' => p.Escrowed__c
                            });
                        }

                        // CLOSING DATE
                        if (p.Estimated_Closing_Date__c != null) {
                            propertyFields.add(new Map<String, Object>{
                                'name' => 'estimated_closing_date',
                                'value' => String.valueOf(p.Estimated_Closing_Date__c)
                            });
                        }

                        // INITIAL PAYMENT METHOD
                        if (p.Initial_Payment_Method_If_Escrowed__c != null) {
                            propertyFields.add(new Map<String, Object>{
                                'name' => 'initial_payment_method_if_escrowed',
                                'value' => p.Initial_Payment_Method_If_Escrowed__c
                            });
                        }

                        if (!propertyFields.isEmpty()) {

                            entitiesList.add(new Map<String, Object>{
                                'entity' => 'property',
                                'index' => propertyIndex,
                                'fields' => propertyFields
                            });

                            propertyIndex++;
                        }
                    }
                }

                // =====================================================
                // FINAL REQUEST BODY
                // =====================================================

                Map<String, Object> requestBody = new Map<String, Object>{
                    'industry' => 'personal_line_insurance',
                    'entities' => entitiesList
                };

                String jsonBody = JSON.serializePretty(requestBody);

                System.debug('🔥 GAYA REQUEST JSON: ' + jsonBody);

                // =====================================================
                // HTTP REQUEST
                // =====================================================

                HttpRequest httpReq = new HttpRequest();

                httpReq.setEndpoint('callout:Gaya_Sandbox/clipboard_records');
                httpReq.setMethod('POST');
                httpReq.setHeader('Content-Type', 'application/json');
                httpReq.setBody(jsonBody);

                Http http = new Http();

                HttpResponse res = http.send(httpReq);

                System.debug('🔥 GAYA RESPONSE STATUS: ' + res.getStatus());
                System.debug('🔥 GAYA RESPONSE BODY: ' + res.getBody());

                // =====================================================
                // RESPONSE VALIDATION
                // =====================================================

                String responseBody = res.getBody();

                if (res.getStatusCode() >= 200 &&
                    res.getStatusCode() < 300) {

                    if (responseBody != null &&
                        (
                            responseBody.contains('error') ||
                            responseBody.contains('Error') ||
                            responseBody.contains('failed') ||
                            responseBody.contains('duplicate')
                        )
                    ) {

                        r.result = 'GAYA ERROR: ' + responseBody;

                    } else {

                        r.result = 'SUCCESS: ' + responseBody;
                    }

                } else {

                    r.result =
                        'HTTP ERROR: ' +
                        res.getStatus() +
                        ' BODY: ' +
                        responseBody;
                }

            } catch (Exception e) {

                r.result =
                    'EXCEPTION: ' +
                    e.getMessage() +
                    ' LINE: ' +
                    e.getLineNumber();

                System.debug('🔥 EXCEPTION: ' + e.getMessage());
            }

            responses.add(r);
        }

        return responses;
    }
}