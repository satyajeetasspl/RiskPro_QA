@RestResource(urlMapping='/123formhook')
global with sharing class FormHookAPI {
    private static final Map<String, String> FIELD_MAP = new Map<String, String>{
        'FirstName' => 'controlvalue118439786-1',
        'LastName' => 'controlvalue118439786-2', 
        'Email' => 'controlvalue118439782', // Officer Email
        'ReferralSourceName' => 'controlvalue118439781', 
        'BorrowersEmail' => 'controlvalue119149848', // Borrower's Email -> Lead.Email
        'Loan' => 'controlvalue118439799', 
        'Comments' => 'controlvalue118439801', 
        'BorrowerDOB' => 'controlvalue118477125', 
        'Second_Insureds_DOB__c' => 'controlvalue118469001', 
        'ClosingDate' => 'controlvalue118439800', 
        'Street' => 'controlvalue118439791-1', 
        'City' => 'controlvalue118439791-3', 
        'State' => 'controlvalue119219628', 
        'PostalCode' => 'controlvalue118439791-5',
        'SecondStreet' => 'controlvalue118439798-1', 
        'SecondCity' => 'controlvalue118439798-3', 
        'SecondState' => 'controlvalue119213700',
        'SecondPostalCode' => 'controlvalue118439798-5', 
        'Second_Insured_First_Name__c' => 'controlvalue118469000-1', 
        'Second_Insured_Last_Name__c' => 'controlvalue118469000-2', 
        'ContactPref' => 'controlvalue118439795', 
        'Escrowed' => 'controlvalue118475375', 
        'SecondInsuredPhone' => 'controlvalue118439792', 
        'BorrowersPhone' => 'controlvalue119149832', 
        'IsRiskProsPartner' => 'controlvalue119104190', 
        'SecondInsuredEmail' => 'controlvalue118439793', 
        'FileUpload' => 'controlvalue118439802',
        'Same_Address_listed_in_Insured_s_Contact__c' => 'controlvalue119211509',
        'Loan_Officer_Name__c' => 'controlvalue119212782',
        'Processor_Email__c' => 'controlvalue119212732',
        'Processor_Name__c' => 'controlvalue119359280'
    };

    private static final Set<String> VALID_CONTACT_PREF_VALUES = new Set<String>{
        'Yes - You can call the client',
        'No, send me the quote direcity'
    };

    private static final Set<String> VALID_ESCROWED_VALUES = new Set<String>{'Yes', 'No'};

    private static final Set<String> VALID_STATE_VALUES = new Set<String>{
        'AL','AK','AZ','AR','CA','CO','CT','DE','FL','GA','HI','ID','IL','IN','IA',
        'KS','KY','LA','ME','MD','MA','MI','MN','MS','MO','MT','NE','NV','NH',
        'NJ','NM','NY','NC','ND','OH','OK','OR','PA','RI','SC','SD','TN','TX',
        'UT','VT','VA','WA','WV','WI','WY'
    };

    private static final Map<String, String> STATE_FULL_TO_ABBREV = new Map<String, String>{
        'alabama' => 'AL', 'alaska' => 'AK', 'arizona' => 'AZ', 'arkansas' => 'AR', 'california' => 'CA',
        'colorado' => 'CO', 'connecticut' => 'CT', 'delaware' => 'DE', 'florida' => 'FL', 'georgia' => 'GA',
        'hawaii' => 'HI', 'idaho' => 'ID', 'illinois' => 'IL', 'indiana' => 'IN', 'iowa' => 'IA',
        'kansas' => 'KS', 'kentucky' => 'KY', 'louisiana' => 'LA', 'maine' => 'ME', 'maryland' => 'MD',
        'massachusetts' => 'MA', 'michigan' => 'MI', 'minnesota' => 'MN', 'mississippi' => 'MS',
        'missouri' => 'MO', 'montana' => 'MT', 'nebraska' => 'NE', 'nevada' => 'NV', 'new hampshire' => 'NH',
        'new jersey' => 'NJ', 'new mexico' => 'NM', 'new york' => 'NY', 'north carolina' => 'NC',
        'north dakota' => 'ND', 'ohio' => 'OH', 'oklahoma' => 'OK', 'oregon' => 'OR', 'pennsylvania' => 'PA',
        'rhode island' => 'RI', 'south carolina' => 'SC', 'south dakota' => 'SD', 'tennessee' => 'TN',
        'texas' => 'TX', 'utah' => 'UT', 'vermont' => 'VT', 'virginia' => 'VA', 'washington' => 'WA',
        'west virginia' => 'WV', 'wisconsin' => 'WI', 'wyoming' => 'WY'
    };

    @HttpPost
    global static String receiveData() {
        RestRequest req = RestContext.request;
        Map<String, String> formData = req.params;

        System.debug('=== START FormHookAPI.receiveData ===');
        System.debug('Full incoming form data: ' + JSON.serialize(formData));

        try {
            Lead newLead = new Lead();

            // Basic field mapping
            System.debug('Mapping basic fields...');
            newLead.FirstName = getValue(formData, FIELD_MAP.get('FirstName')); 
            newLead.LastName = String.isNotBlank(getValue(formData, FIELD_MAP.get('LastName'))) 
                ? getValue(formData, FIELD_MAP.get('LastName')) 
                : 'Unknown'; 
            newLead.Company = 'NA';
            newLead.Referral_Source_Name__c = getValue(formData, FIELD_MAP.get('ReferralSourceName')); 
            newLead.Loan_Officer_Name__c = getValue(formData, FIELD_MAP.get('Loan_Officer_Name__c'));
            newLead.Processor_Email__c = getValue(formData, FIELD_MAP.get('Processor_Email__c'));
            newLead.Processor_Name__c = getValue(formData, FIELD_MAP.get('Processor_Name__c'));
 
            newLead.Email = getValue(formData, FIELD_MAP.get('BorrowersEmail'));
            newLead.Loan_Officer_Email__c = getValue(formData, FIELD_MAP.get('Email'));
            newLead.Second_Insured_Email__c = getValue(formData, FIELD_MAP.get('SecondInsuredEmail')); 
            newLead.Loan__c = getValue(formData, FIELD_MAP.get('Loan')); 
            newLead.Additional_Comments__c = getValue(formData, FIELD_MAP.get('Comments')); 

            System.debug('Lead basic info: ' + JSON.serialize(newLead));

            String isPartner = getValue(formData, FIELD_MAP.get('IsRiskProsPartner')); 
            newLead.LeadSource = (isPartner == 'Yes') ? 'Partner' : null;
            System.debug('Is Partner: ' + isPartner + ' | LeadSource set to: ' + newLead.LeadSource);

            // Property Address
            String propertyState = getValue(formData, FIELD_MAP.get('SecondState')); 
            newLead.Street = getValue(formData, FIELD_MAP.get('SecondStreet')); 
            newLead.City = getValue(formData, FIELD_MAP.get('SecondCity'));
            newLead.State = getStateAbbrev(propertyState);
            newLead.PostalCode = getValue(formData, FIELD_MAP.get('SecondPostalCode')); 
            newLead.Country = 'US'; 
            System.debug('Property Address: ' + newLead.Street + ', ' + newLead.City + ', ' + newLead.State + ', ' + newLead.PostalCode);

            // Insured Address
            String insuredState = getValue(formData, FIELD_MAP.get('State')); 
            newLead.Insured_Address__Street__s = getValue(formData, FIELD_MAP.get('Street')); 
            newLead.Insured_Address__City__s = getValue(formData, FIELD_MAP.get('City')); 
            newLead.Insured_Address__PostalCode__s = getValue(formData, FIELD_MAP.get('PostalCode')); 
            newLead.Insured_Address__CountryCode__s = 'US';
            newLead.Insured_Address__StateCode__s = getStateAbbrev(insuredState);
            System.debug('Insured Address State Mapped: ' + insuredState + ' => ' + newLead.Insured_Address__StateCode__s);

            // Date fields
            newLead.Borrower_DOB__c = parseDateSafe(getValue(formData, FIELD_MAP.get('BorrowerDOB')));
            newLead.Second_Insureds_DOB__c = parseDateSafe(getValue(formData, FIELD_MAP.get('Second_Insureds_DOB__c'))); 
            newLead.Estimated_Closing_Date__c = parseDateSafe(getValue(formData, FIELD_MAP.get('ClosingDate'))); 
            System.debug('Dates parsed: Borrower DOB=' + newLead.Borrower_DOB__c + ', Second DOB=' + newLead.Second_Insureds_DOB__c + ', Closing=' + newLead.Estimated_Closing_Date__c);

            // Second insured
            String secondFirstName = getValue(formData, FIELD_MAP.get('Second_Insured_First_Name__c')); 
            String secondLastName = getValue(formData, FIELD_MAP.get('Second_Insured_Last_Name__c')); 
            String secondDOB = getValue(formData, FIELD_MAP.get('Second_Insureds_DOB__c')); 
            newLead.Second_Insured_First_Name__c = secondFirstName;
            newLead.Second_Insured_Last_Name__c = secondLastName;
            newLead.Second_Insureds_DOB__c = parseDateSafe(secondDOB);
            newLead.Add_Second_Named_Insured__c = String.isNotBlank(secondFirstName) || String.isNotBlank(secondLastName) || String.isNotBlank(secondDOB);
            System.debug('Second insured info: ' + secondFirstName + ' ' + secondLastName + ' | DOB=' + secondDOB);

            // Phone cleanup
            String phoneStr = getValue(formData, FIELD_MAP.get('BorrowersPhone')); 
            System.debug('Borrower phone raw: ' + phoneStr);
            if (String.isNotBlank(phoneStr)) {
                try {
                    newLead.Borrowers_Phone_Number__c = phoneStr.replace('-', '').replace(',', '');
                } catch (Exception e) {
                    System.debug('Phone parse error: ' + e.getMessage());
                }
            }

            String secondPhoneStr = getValue(formData, FIELD_MAP.get('SecondInsuredPhone')); 
            System.debug('Second insured phone raw: ' + secondPhoneStr);
            if (String.isNotBlank(secondPhoneStr)) {
                try {
                    newLead.Second_Insured_Phone_1__c = secondPhoneStr.replace('-', '').replace(',', '');
                } catch (Exception e) {
                    System.debug('Second phone parse error: ' + e.getMessage());
                }
            }

            // Escrowed logic
            String escrowedValue = getValue(formData, FIELD_MAP.get('Escrowed')); 
            newLead.Escrowed__c = String.isNotBlank(escrowedValue) && VALID_ESCROWED_VALUES.contains(escrowedValue) 
                ? escrowedValue : null;
            if (newLead.Escrowed__c == 'Yes') {
                newLead.Initial_Payment__c = 'Paid Prior to Closing'; 
            } else if (newLead.Escrowed__c == 'No') {
                newLead.Initial_Payment__c = 'Insured Paid - Prior to Closing';
            }
            System.debug('Escrowed=' + newLead.Escrowed__c + ', Initial Payment=' + newLead.Initial_Payment__c);

            // Contact preference
            String contactPref = getValue(formData, FIELD_MAP.get('ContactPref')); 
            System.debug('Contact preference raw: ' + contactPref);
            if (String.isNotBlank(contactPref)) {
                String lowerContactPref = contactPref.toLowerCase();
                if (VALID_CONTACT_PREF_VALUES.contains(contactPref) || lowerContactPref.contains('yes')) {
                    newLead.Can_we_contact_the_borrower_directly__c = 'Yes - You can call the client';
                } else if (VALID_CONTACT_PREF_VALUES.contains(contactPref) || lowerContactPref.contains('no')) {
                    newLead.Can_we_contact_the_borrower_directly__c = 'No, send me the quote direcity';
                }
            }

            // Same Address
            String sameAddressValue = getValue(formData, FIELD_MAP.get('Same_Address_listed_in_Insured_s_Contact__c'));
            System.debug('Same Address Value: ' + sameAddressValue);
            newLead.Same_Address_listed_in_Insured_s_Contact__c = (sameAddressValue != null && 
                (sameAddressValue.equalsIgnoreCase('Yes') || sameAddressValue.equalsIgnoreCase('true'))) ? true : false;
            
            System.debug('Final lead data before insert: ' + JSON.serialize(newLead));

            insert newLead;
            System.debug('Lead successfully inserted: ' + newLead.Id);

            // File upload handling
            String fileUrl = getValue(formData, FIELD_MAP.get('FileUpload'));
            System.debug('File upload URL: ' + fileUrl);
            if (String.isNotBlank(fileUrl)) {
                String fileName = null;
                for (String key : formData.keySet()) {
                    if (formData.get(key)?.contains('.pdf') == true || formData.get(key)?.contains('.zip') == true) {
                        fileName = formData.get(key);
                        break;
                    }
                }
                fileName = fileName ?? 'uploaded_file.pdf';
                System.debug('Queueing FileUploadQueueable with file: ' + fileName);
                System.enqueueJob(new FileUploadQueueable(newLead.Id, fileName, fileUrl));
            }

            System.debug('=== END SUCCESS FormHookAPI ===');
            return 'New Lead Created with ID: ' + newLead.Id;
        } catch (Exception e) {
            System.debug('=== ERROR in FormHookAPI === ' + e.getMessage() + ' | Stack: ' + e.getStackTraceString());
            return 'Error: ' + e.getMessage();
        }
    }

    private static String getValue(Map<String, String> data, String key) {
        String val = (data != null && key != null && data.containsKey(key) && String.isNotBlank(data.get(key))) 
            ? data.get(key).trim().replace('â\u0080\u0099', '\'') 
            : null;
        System.debug('getValue() -> key: ' + key + ' | value: ' + val);
        return val;
    }

    private static Date parseDateSafe(String dateStr) {
        if (String.isBlank(dateStr)) return null;
        System.debug('Parsing date: ' + dateStr);
        try {
            List<String> parts = dateStr.split('/');
            if (parts.size() == 3) {
                Integer month = Integer.valueOf(parts[0]);
                Integer day = Integer.valueOf(parts[1]);
                Integer year = Integer.valueOf(parts[2]);
                return Date.newInstance(year, month, day);
            }
            return Date.valueOf(dateStr);
        } catch (Exception e) {
            System.debug('parseDateSafe() failed for ' + dateStr + ': ' + e.getMessage());
            return null;
        }
    }

    private static String getStateAbbrev(String stateValue) {
        if (String.isBlank(stateValue)) return null;
        String upperState = stateValue.trim().toUpperCase();
        if (VALID_STATE_VALUES.contains(upperState)) return upperState;
        for (String fullName : STATE_FULL_TO_ABBREV.keySet()) {
            if (fullName.toUpperCase() == upperState) {
                return STATE_FULL_TO_ABBREV.get(fullName);
            }
        }
        System.debug('Invalid state value received: ' + stateValue);
        return null;
    }

    public class FileUploadQueueable implements Queueable, Database.AllowsCallouts {
        private Id leadId;
        private String fileName;
        private String fileUrl;

        public FileUploadQueueable(Id leadId, String fileName, String fileUrl) {
            this.leadId = leadId;
            this.fileName = fileName;
            this.fileUrl = fileUrl;
        }

        public void execute(QueueableContext context) {
            System.debug('=== FileUploadQueueable START for Lead ' + leadId + ' ===');
            System.debug('FileName: ' + fileName + ' | FileURL: ' + fileUrl);
            try {
                Http http = new Http();
                HttpRequest fileReq = new HttpRequest();
                fileReq.setEndpoint(fileUrl);
                fileReq.setMethod('GET');
                fileReq.setTimeout(120000); 
                HttpResponse res = http.send(fileReq);

                System.debug('Initial file response code: ' + res.getStatusCode());

                if (res.getStatusCode() == 301 || res.getStatusCode() == 302) {
                    String redirectUrl = res.getHeader('Location');
                    System.debug('Redirect detected. Redirecting to: ' + redirectUrl);
                    if (String.isNotBlank(redirectUrl)) {
                        fileReq.setEndpoint(redirectUrl);
                        res = http.send(fileReq);
                    }
                }

                if (res.getStatusCode() == 200) {
                    Blob fileBlob = res.getBodyAsBlob();
                    System.debug('File blob size: ' + fileBlob.size());
                    if (fileBlob.size() > 12000000) {
                        System.debug('File too large, skipping upload.');
                        return;
                    }

                    ContentVersion cv = new ContentVersion();
                    cv.Title = fileName;
                    cv.PathOnClient = fileName;
                    cv.VersionData = fileBlob;
                    cv.FirstPublishLocationId = leadId;
                    insert cv;
                    System.debug('File successfully uploaded for Lead: ' + leadId);
                } else {
                    System.debug('File upload failed, HTTP ' + res.getStatusCode() + ' | Body: ' + res.getBody());
                }
            } catch (Exception e) {
                System.debug('FileUploadQueueable ERROR: ' + e.getMessage());
            }
            System.debug('=== FileUploadQueueable END ===');
        }
    }
}