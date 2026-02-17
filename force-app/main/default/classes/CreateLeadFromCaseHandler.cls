public class CreateLeadFromCaseHandler {

    private static final Map<String, String> FIELD_MAP = new Map<String, String>{
        'mortgage broker name' => 'Company',
        'partner name' => 'Company',
        'email' => 'Email',
        'borrower first' => 'FirstName',
        'borrower first name' => 'FirstName',
        'borrower last' => 'LastName',
        'borrower last name' => 'LastName',
        'name' => 'LastName',
        'borrower name' => 'LastName',    
        'borrower\'s email address' => 'Borrowers_Email__c',
        'borrower email' => 'Borrowers_Email__c',
        'processor email' => 'Processor_Email__c',
        'initial payment?' => 'Initial_Payment__c',
        'additional comments' => 'Additional_Comments__c',
        'for cross-sell purposes?' => 'Can_we_contact_the_borrower_directly__c',
        'can we contact the prospect directly?' => 'Can_we_contact_the_borrower_directly__c',
        'escrowed?' => 'Escrowed__c',
        'borrower\'s phone #' => 'Borrowers_Phone_Number__c',
        'borrower phone' => 'Borrowers_Phone_Number__c',
        'daytime phone' => 'Borrowers_Phone_Number__c',
        'loan #' => 'Loan__c',
        'first named insured (etc)' => 'First_Named_Insured_etc__c',
        'last name insured (etc)' => 'Last_Named_Insured_etc__c',
        'referral source name' => 'Referral_Source_Name__c',
        'referral source' => 'Referral_Source_Name__c',
        'lead source' => 'LeadSource',
        'processor name' => 'Processor_Name__c',
        'lender' => 'Mortgagee_Clause__c',
        'lender name' => 'Mortgagee_Clause__c',
        'loan officer' => 'Loan_Officer_Name__c',
        'loan officer name' => 'Loan_Officer_Name__c',
        'gender' => 'GenderIdentity',
        'borrower street' => 'Insured_Address__Street__s',
        'borrower city' => 'Insured_Address__City__s',
        'borrower state' => 'Insured_Address__StateCode__s',
        'borrower zip' => 'Insured_Address__PostalCode__s',
        'subject property street' => 'Street',
        'subject property city' => 'City',
        'subject property state' => 'State',
        'subject property zip' => 'PostalCode'
    };

    private static final Set<String> DATE_FIELDS = new Set<String>{
        'dob', 'co-borrower dob', 'estimated closing date', 'borrower dob', 'birthdate'
    };

    private static final Map<String, String> STATE_CODE_MAP = new Map<String, String>{
        'alabama' => 'AL', 'alaska' => 'AK', 'arizona' => 'AZ', 'arkansas' => 'AR', 'california' => 'CA',
        'colorado' => 'CO', 'connecticut' => 'CT', 'delaware' => 'DE', 'district of columbia' => 'DC',
        'florida' => 'FL', 'georgia' => 'GA', 'hawaii' => 'HI', 'idaho' => 'ID', 'illinois' => 'IL',
        'indiana' => 'IN', 'iowa' => 'IA', 'kansas' => 'KS', 'kentucky' => 'KY', 'louisiana' => 'LA',
        'maine' => 'ME', 'maryland' => 'MD', 'massachusetts' => 'MA', 'michigan' => 'MI', 'minnesota' => 'MN',
        'mississippi' => 'MS', 'missouri' => 'MO', 'montana' => 'MT', 'nebraska' => 'NE', 'nevada' => 'NV',
        'new hampshire' => 'NH', 'new jersey' => 'NJ', 'new mexico' => 'NM', 'new york' => 'NY',
        'north carolina' => 'NC', 'north dakota' => 'ND', 'ohio' => 'OH', 'oklahoma' => 'OK', 'oregon' => 'OR',
        'pennsylvania' => 'PA', 'rhode island' => 'RI', 'south carolina' => 'SC', 'south dakota' => 'SD',
        'tennessee' => 'TN', 'texas' => 'TX', 'utah' => 'UT', 'vermont' => 'VT', 'virginia' => 'VA',
        'washington' => 'WA', 'west virginia' => 'WV', 'wisconsin' => 'WI', 'wyoming' => 'WY'
    };

    private static final Set<String> STREET_SUFFIXES = new Set<String>{
        'rd', 'road', 'st', 'street', 'ave', 'avenue', 'dr', 'drive', 'ln', 'lane', 
        'ct', 'court', 'blvd', 'boulevard', 'cir', 'circle', 'way', 'pl', 'place'
    };

    private static final List<String> STOP_PHRASES = new List<String>{
        'sincerely', 'best regards', 'warm regards', 'kind regards', 'respectfully', 
        'thanks,', 'thank you,', '--', 'sent from my', 'confidentiality notice', 'disclaimer',
        'mobile:', 'office:', 'fax:', 'confidential', 'the content of this email'
    };

    private static final Pattern EMAIL_PATTERN = Pattern.compile('[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,4}');

    @InvocableMethod(label='Parse Case Description for Lead' description='Parses key-value pairs from Case Description into Lead fields')
    public static List<Lead> parseDescription(List<Id> caseIds) {
        System.debug('--- START: CreateLeadFromCaseHandler.parseDescription ---');
        List<Lead> leadsToReturn = new List<Lead>();
        
        Map<Id, Case> caseMap = new Map<Id, Case>(
            [SELECT Description, Origin FROM Case WHERE Id IN :caseIds]
        );

        for (Id cId : caseIds) {
            Case c = caseMap.get(cId);
            if (c == null || String.isBlank(c.Description)) {
                System.debug('Case description is null or blank for Case ID: ' + cId);
                leadsToReturn.add(null);
                continue;
            }

            Lead lead = new Lead();
            String rawDesc = c.Description.replace('\r\n', '\n').replace('\r', '\n');
            String[] lines = rawDesc.split('\n');
            
            Boolean isPropertySection = false; 

            for (Integer i = 0; i < lines.size(); i++) {
                String line = lines[i].trim();
                if (String.isBlank(line)) continue;

                Boolean isSignature = false;
                String lowerLine = line.toLowerCase();
                for (String stopWord : STOP_PHRASES) {
                    if (lowerLine.contains(stopWord) || line == '--') {
                        isSignature = true;
                        System.debug('Signature/Stop phrase detected: ' + stopWord + ' at line: ' + line);
                        break;
                    }
                }
                if (isSignature) break;

                if (line.contains('---PROPERTY INFORMATION---')) {
                    System.debug('Switched to Property Information section');
                    isPropertySection = true; 
                    continue;
                }

                try {
                    String key = '';
                    String value = '';

                    if (line.contains(':')) {
                        String[] parts = line.split(':', 2);
                        key = parts[0].trim().toLowerCase();
                        if (parts.size() > 1) value = parts[1].trim();
                    }
                    else {
                        key = line.toLowerCase();
                        Boolean isKnownKey = FIELD_MAP.containsKey(key) || key.contains('address') || key.contains('email') || DATE_FIELDS.contains(key);
                        
                        if (isKnownKey && (i + 1 < lines.size())) {
                            value = lines[i+1].trim();
                            i++; 
                        } else {
                            continue;
                        }
                    }

                    System.debug('Processing Key: ' + key + ' | Value: ' + value);

                    if (key.contains('email')) {
                        String validEmail = extractEmail(value);
                        if (validEmail != null) {
                            if (key == 'email') lead.Email = validEmail;
                            else if (key == 'processor email') lead.Processor_Email__c = validEmail;
                            else { 
                                lead.Borrowers_Email__c = validEmail;
                                if (lead.Email == null) lead.Email = validEmail; 
                            }
                        }
                    }
                    else if (key == 'borrower address') {
                        parseCommaAddress(value, lead, true); 
                    }
                    else if (key == 'property address') {
                        parseCommaAddress(value, lead, false);
                    }
                    else if (key == 'address') {
                        if (isPropertySection) lead.Street = value; 
                        else lead.Insured_Address__Street__s = value; 
                    }
                    else if (key == 'city, state zip') {
                        parseCityStateZip(value, lead, isPropertySection);
                    }
                    else if (FIELD_MAP.containsKey(key)) {
                        String targetField = FIELD_MAP.get(key);
                        if (key.contains('phone')) lead.put(targetField, value.replaceAll('[^0-9]', ''));
                        else lead.put(targetField, value);
                    } 
                    else if (DATE_FIELDS.contains(key)) {
                        Date parsedDate = parseDateSafe(value);
                        if (parsedDate != null) {
                            if (key.contains('dob') || key.contains('birthdate')) lead.Borrower_DOB__c = parsedDate;
                            else if (key.contains('closing')) lead.Estimated_Closing_Date__c = parsedDate;
                        }
                    }
                } catch (Exception lineEx) {
                    System.debug('ERROR parsing line: ' + line + '. Exception: ' + lineEx.getMessage());
                }
            }

            if (lead.Email == null && String.isNotBlank(lead.Borrowers_Email__c)) lead.Email = lead.Borrowers_Email__c;
            if (String.isBlank(lead.Company)) lead.Company = 'Individual';
            if (String.isBlank(lead.LastName)) lead.LastName = 'Unknown';

            if (lead.LastName != null || lead.FirstName != null || lead.Company != null) {
                System.debug('Successfully parsed Lead: ' + lead);
                leadsToReturn.add(lead);
            } else {
                System.debug('Failed to parse valid Lead data from Case: ' + cId);
                leadsToReturn.add(null);
            }
        }
        System.debug('--- END: CreateLeadFromCaseHandler.parseDescription ---');
        return leadsToReturn;
    }

    private static void parseCommaAddress(String val, Lead lead, Boolean isInsured) {
        try {
            System.debug('Parsing Address: ' + val + ' (IsInsured: ' + isInsured + ')');
            val = normalizeStateName(val);
            
            String street='', city='', state='', zip='';
            List<String> parts = val.split(',');

            for(Integer i=0; i<parts.size(); i++) parts[i] = parts[i].trim();

            if (parts.size() >= 4) {
                zip = parts.remove(parts.size()-1);
                state = parts.remove(parts.size()-1);
                city = parts.remove(parts.size()-1);
                street = String.join(parts, ', ');
            } 
            else if (parts.size() >= 2) {
                String lastPart = parts[parts.size()-1];
                
                if (Pattern.matches('.*[0-9].*', lastPart)) {
                    zip = parts.remove(parts.size()-1);
                    
                    if (!parts.isEmpty()) {
                        state = parts.remove(parts.size()-1);
                    }
                    
                    String streetAndCity = String.join(parts, ', ');
                    List<String> words = streetAndCity.split(' ');
                    
                    Boolean cityFound = false;
                    if (words.size() > 2) {
                        Integer splitIndex = -1;
                        
                        for (Integer k = words.size() - 2; k >= 0; k--) {
                            String wordClean = words[k].toLowerCase().replaceAll('[^a-z]', '');
                            if (STREET_SUFFIXES.contains(wordClean)) {
                                splitIndex = k;
                                break;
                            }
                        }
                        
                        if (splitIndex != -1 && splitIndex < words.size() - 1) {
                            List<String> streetWords = new List<String>();
                            for(Integer s = 0; s <= splitIndex; s++) streetWords.add(words[s]);
                            street = String.join(streetWords, ' ');
                            
                            List<String> cityWords = new List<String>();
                            for(Integer c = splitIndex + 1; c < words.size(); c++) cityWords.add(words[c]);
                            city = String.join(cityWords, ' ');
                            cityFound = true;
                        }
                    } 
                    
                    if (!cityFound) {
                        street = streetAndCity;
                    }
                } else {
                    street = val;
                }
            } else {
                street = val;
            }

            if (String.isNotBlank(state) && String.isBlank(city)) {
                System.debug('City missing for State: ' + state + '. Defaulting City to "." to prevent crash.');
                city = '.'; 
            }

            if (isInsured) {
                lead.Insured_Address__Street__s = street; 
                lead.Insured_Address__City__s = city; 
                lead.Insured_Address__StateCode__s = state; 
                lead.Insured_Address__PostalCode__s = zip; 
                lead.Insured_Address__CountryCode__s = 'US';
            } else {
                lead.Street = street; 
                lead.City = city; 
                lead.State = state; 
                lead.PostalCode = zip; 
                lead.Country = 'US';
            }
            System.debug('Parsed Address -> Street: ' + street + ', City: ' + city + ', State: ' + state + ', Zip: ' + zip);

        } catch (Exception e) {
            System.debug('Address parsing failed: ' + e.getMessage());
            if(isInsured) lead.Insured_Address__Street__s = val;
            else lead.Street = val;
        }
    }

    private static void parseCityStateZip(String val, Lead lead, Boolean isPropertySection) {
        try {
            System.debug('Parsing CityStateZip: ' + val);
            val = normalizeStateName(val);
            List<String> parts = val.split(' ');
            if (parts.size() >= 2) {
                String zip = parts.remove(parts.size()-1);
                String state = parts.remove(parts.size()-1);
                String city = String.join(parts, ' ');
                
                if (String.isBlank(city)) city = '.';

                if (isPropertySection) {
                    lead.City = city; lead.State = state; lead.PostalCode = zip; lead.Country = 'US';
                } else {
                    lead.Insured_Address__City__s = city; lead.Insured_Address__StateCode__s = state; lead.Insured_Address__PostalCode__s = zip; lead.Insured_Address__CountryCode__s = 'US';
                }
            }
        } catch (Exception e) {
            System.debug('CityStateZip parsing failed: ' + e.getMessage());
        }
    }

    private static String normalizeStateName(String input) {
        if (String.isBlank(input)) return input;
        
        String lowerInput = input.toLowerCase();
        
        for (String stateName : STATE_CODE_MAP.keySet()) {
            if (lowerInput.contains(stateName)) {
                input = input.replaceAll('(?i)\\b' + stateName + '\\b', STATE_CODE_MAP.get(stateName));
            }
        }
        return input;
    }

    private static String extractEmail(String input) {
        if (String.isBlank(input)) return null;
        Matcher m = EMAIL_PATTERN.matcher(input);
        return m.find() ? m.group() : null;
    }

    private static Date parseDateSafe(String dateStr) {
        if (String.isBlank(dateStr) || dateStr == 'N/A') return null;
        try {
            String[] parts = dateStr.split('/');
            if (parts.size() == 3) return Date.newInstance(Integer.valueOf(parts[2]), Integer.valueOf(parts[0]), Integer.valueOf(parts[1]));
            return null;
        } catch (Exception e) { 
            System.debug('Date parsing error for: ' + dateStr);
            return null; 
        }
    }
}