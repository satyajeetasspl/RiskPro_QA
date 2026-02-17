// CaseHelper.cls
public class CaseHelper {
    private static final Map<String, String> FIELD_MAP = new Map<String, String>{
        'name' => 'Name', 
        'daytime phone' => 'Borrowers_Phone_Number__c',
        'evening phone' => 'Phone_2__c',
        'email' => 'Email',
        'birthdate' => 'Borrower_DOB__c',
        'property address' => 'Street',
        'property city' => 'City',
        'property state' => 'State',
        'property zip' => 'PostalCode'
    };

    public static List<Lead> parseDescription(List<Id> caseIds) {
        if (caseIds == null || caseIds.isEmpty()) {
            return new List<Lead>();
        }

        // CORRECTED: Removed "AND Origin = 'Email'" to process cases from any source
        List<Case> cases = [SELECT Id, Description FROM Case WHERE Id IN :caseIds];

        if (cases.isEmpty()) {
            return new List<Lead>();
        }

        List<Lead> leadsToInsert = new List<Lead>();
        for (Case c : cases) {
            if (String.isBlank(c.Description)) {
                continue;
            }

            Map<String, List<String>> parsedMap = parseKeyValues(c.Description);
            Lead newLead = new Lead(Company = 'N/A');

            // --- Field Parsing Logic (remains the same) ---

            // Parse and clean name
            if (parsedMap.containsKey('name') && !parsedMap.get('name').isEmpty()) {
                String fullName = parsedMap.get('name')[0];
                for (String label : new List<String>{'DAYTIME PHONE', 'EVENING PHONE', 'CELL PHONE', 'EMAIL','ADDRESS','CITY, STATE ZIP','BIRTHDATE'}) {
                    Integer idx = fullName.indexOf(label);
                    if (idx > 0) fullName = fullName.substring(0, idx).trim();
                }
                List<String> nameParts = fullName.split(' ');
                if (nameParts.size() > 1) {
                    newLead.FirstName = nameParts[0];
                    newLead.LastName = fullName.substring(newLead.FirstName.length()).trim();
                } else {
                    newLead.LastName = fullName;
                }
                if (newLead.LastName != null && newLead.LastName.length() > 80) {
                    newLead.LastName = newLead.LastName.substring(0, 80);
                }
            }

            // Parse birthdate
            if (parsedMap.containsKey('birthdate') && !parsedMap.get('birthdate').isEmpty()) {
                newLead.Borrower_DOB__c = parseDateSafe(parsedMap.get('birthdate')[0]);
            }

            // Map insured address (first occurrence)
            if (parsedMap.containsKey('address') && parsedMap.get('address').size() >= 1) {
                newLead.Insured_Address__Street__s = parsedMap.get('address')[0];
            }
            if (parsedMap.containsKey('city, state zip') && parsedMap.get('city, state zip').size() >= 1) {
                Map<String, String> parsedAddress = parseCityStateZip(parsedMap.get('city, state zip')[0]);
                if (parsedAddress != null) {
                    newLead.Insured_Address__City__s = parsedAddress.get('city');
                    newLead.Insured_Address__StateCode__s = parsedAddress.get('state');
                    newLead.Insured_Address__PostalCode__s = parsedAddress.get('zip');
                    newLead.Insured_Address__CountryCode__s = 'US';
                }
            }

            // Map property address (second occurrence)
            if (parsedMap.containsKey('address') && parsedMap.get('address').size() >= 2) {
                newLead.Street = parsedMap.get('address')[1];
            }
            if (parsedMap.containsKey('city, state zip') && parsedMap.get('city, state zip').size() >= 2) {
                Map<String, String> parsedAddress = parseCityStateZip(parsedMap.get('city, state zip')[1]);
                 if (parsedAddress != null) {
                    newLead.City = parsedAddress.get('city');
                    newLead.State = parsedAddress.get('state');
                    newLead.PostalCode = parsedAddress.get('zip');
                }
            }

            mapSimpleFields(newLead, parsedMap);
            appendUnmappedFields(newLead, parsedMap);

            if (String.isBlank(newLead.LastName)) newLead.LastName = 'Unknown';

            newLead.LeadSource = 'Online Leads';
            newLead.Referral_Source_Name__c = 'Hometown Quotes';

            leadsToInsert.add(newLead);
        }

        return leadsToInsert;
    }
    
    // Helper to parse 'City State ZIP' robustly
    private static Map<String, String> parseCityStateZip(String addressLine) {
        if (String.isBlank(addressLine)) return null;
        try {
            Integer lastSpace = addressLine.lastIndexOf(' ');
            if (lastSpace == -1) return null;
            String zip = addressLine.substring(lastSpace + 1);
            String cityState = addressLine.substring(0, lastSpace).trim();
            Integer secondLastSpace = cityState.lastIndexOf(' ');
            if (secondLastSpace == -1) return null;
            String state = cityState.substring(secondLastSpace + 1);
            String city = cityState.substring(0, secondLastSpace).trim();
            return new Map<String, String>{'city' => city, 'state' => state, 'zip' => zip};
        } catch (Exception e) {
            return null;
        }
    }

    private static void mapSimpleFields(Lead newLead, Map<String, List<String>> parsedMap) {
        if (parsedMap.containsKey('daytime phone') && !parsedMap.get('daytime phone').isEmpty()) {
            newLead.Borrowers_Phone_Number__c = parsedMap.get('daytime phone')[0];
        }
        if (parsedMap.containsKey('evening phone') && !parsedMap.get('evening phone').isEmpty()) {
            newLead.Phone_2__c = parsedMap.get('evening phone')[0];
        }
        if (parsedMap.containsKey('email') && !parsedMap.get('email').isEmpty()) {
            // This properly handles the mailto link format in your example data
            newLead.Email = cleanValidateEmail(parsedMap.get('email')[0]);
        }
    }

    private static void appendUnmappedFields(Lead newLead, Map<String, List<String>> parsedMap) {
        List<String> unmappedFields = new List<String>();
        Set<String> mappedKeys = new Set<String>{'name', 'daytime phone', 'evening phone', 'email', 'birthdate', 'address', 'city, state zip'};
        for (String key : parsedMap.keySet()) {
            if (!mappedKeys.contains(key.toLowerCase())) {
                for (String value : parsedMap.get(key)) {
                    if (String.isNotBlank(value)) {
                        unmappedFields.add(key.toUpperCase() + ': ' + value);
                    }
                }
            }
        }
        if (!unmappedFields.isEmpty()) {
            newLead.Description = String.join(unmappedFields, '\n');
        }
    }
    
    // --- Unchanged Helper Methods ---
    private static Map<String, List<String>> parseKeyValues(String text) {
        Map<String, List<String>> result = new Map<String, List<String>>();
        for (String line : text.split('\n')) {
            if (String.isBlank(line) || !line.contains(':')) continue;
            List<String> parts = line.split(':', 2);
            String key = parts[0].trim().toLowerCase();
            String value = parts[1].trim();
            if (!result.containsKey(key)) {
                result.put(key, new List<String>());
            }
            result.get(key).add(value);
        }
        return result;
    }

    private static String cleanValidateEmail(String emailVal) {
        if (emailVal == null) return null;
        // This regex handles cleaning up email values like '[s.m@example.com](mailto:s.m@example.com)'
        emailVal = emailVal.replaceAll('\\[mailto:([^\\]]+)\\]', '$1').replaceAll('[\\[\\]]', '').trim();
        Pattern p = Pattern.compile('^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$');
        return p.matcher(emailVal).matches() ? emailVal : null;
    }

    private static Date parseDateSafe(String val) {
        if (String.isBlank(val)) return null;
        try {
            List<String> parts = val.split('/');
            if (parts.size() == 3) {
                return Date.newInstance(Integer.valueOf(parts[2]), Integer.valueOf(parts[0]), Integer.valueOf(parts[1]));
            }
        } catch (Exception e) {}
        return null;
    }
}