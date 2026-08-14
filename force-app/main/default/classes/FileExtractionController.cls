public with sharing class FileExtractionController {

    @TestVisible
    private static String TEST_JSON_RESPONSE;

    @AuraEnabled
    public static Id uploadCustomFile(String base64Data, String fileName, Id recordId) {
        try {
            ContentVersion cv = new ContentVersion();
            cv.Title = fileName;
            cv.PathOnClient = fileName;
            cv.VersionData = EncodingUtil.base64Decode(base64Data);
            cv.IsMajorVersion = true;
            insert cv;
            
            // Re-query to get ContentDocumentId
            cv = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id LIMIT 1];
            
            if (recordId != null) {
                ContentDocumentLink cdl = new ContentDocumentLink();
                cdl.ContentDocumentId = cv.ContentDocumentId;
                cdl.LinkedEntityId = recordId;
                cdl.ShareType = 'V';
                cdl.Visibility = 'AllUsers';
                insert cdl;
            }
            
            return cv.ContentDocumentId;
        } catch(Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static Id processDocument(Id documentId, Id contextLeadId) {
        try {
            // ==========================================
            // 1. GET PDF FILE
            // ==========================================
            ContentVersion cv = [
                SELECT VersionData
                FROM ContentVersion
                WHERE ContentDocumentId = :documentId
                AND IsLatest = true
                LIMIT 1
            ];

            // ==========================================
            // 2. OCR EXTRACTION
            // ==========================================
            String extractedText = extractTextFromPDF(cv.VersionData);

            // ==========================================
            // 3. PREPARE AGENTFORCE INPUT
            // ==========================================
            ConnectApi.WrappedValue textValue = new ConnectApi.WrappedValue();
            textValue.value = extractedText;

            Map<String, ConnectApi.WrappedValue> inputParams = new Map<String, ConnectApi.WrappedValue>();
            inputParams.put('Input:PDF_Text', textValue);

            ConnectApi.EinsteinPromptTemplateGenerationsInput executeTemplateInput = new ConnectApi.EinsteinPromptTemplateGenerationsInput();
            executeTemplateInput.inputParams = inputParams;
            executeTemplateInput.isPreview = false;
            executeTemplateInput.additionalConfig = new ConnectApi.EinsteinLlmAdditionalConfigInput();
            executeTemplateInput.additionalConfig.applicationName = 'PromptTemplateGenerationsInvocable';

            // ==========================================
            // 4. GENERATE AI RESPONSE
            // ==========================================
            String jsonResponse;

            if (Test.isRunningTest() && TEST_JSON_RESPONSE != null) {
                jsonResponse = TEST_JSON_RESPONSE;
            } else {
                ConnectApi.EinsteinPromptTemplateGenerationsRepresentation generationsOutput =
                    ConnectApi.EinsteinLLM.generateMessagesForPromptTemplate('Parse_Insurance_Quote_PDF', executeTemplateInput);
                jsonResponse = generationsOutput.generations[0].text;
            }

            // ==========================================
            // 5 & 6. CLEAN & PARSE JSON SAFE-EXTRACT
            // ==========================================
            String cleanedJson = extractJsonPayload(jsonResponse);
            Object parsedObj = JSON.deserializeUntyped(cleanedJson);
            List<Map<String, Object>> parsedQuotes = new List<Map<String, Object>>();
            
            if (parsedObj instanceof List<Object>) {
                for (Object obj : (List<Object>)parsedObj) {
                    parsedQuotes.add((Map<String, Object>)obj);
                }
            } else if (parsedObj instanceof Map<String, Object>) {
                Map<String, Object> mapObj = (Map<String, Object>)parsedObj;
                if (mapObj.containsKey('quotes') && mapObj.get('quotes') instanceof List<Object>) {
                    for (Object obj : (List<Object>)mapObj.get('quotes')) {
                        parsedQuotes.add((Map<String, Object>)obj);
                    }
                } else if (mapObj.containsKey('Quotes') && mapObj.get('Quotes') instanceof List<Object>) {
                    for (Object obj : (List<Object>)mapObj.get('Quotes')) {
                        parsedQuotes.add((Map<String, Object>)obj);
                    }
                } else {
                    parsedQuotes.add(mapObj);
                }
            }

            if (parsedQuotes.isEmpty()) {
                throw new CalloutException('Failed to extract any valid quotes from the document.');
            }

            // ==========================================
            // DEBUG: LOG ALL AI-RETURNED FIELDS
            // ==========================================
            System.debug('==== PARSED AI FIELDS (' + parsedQuotes.size() + ' QUOTES) ====');
            for (Integer i = 0; i < parsedQuotes.size(); i++) {
                System.debug('--- QUOTE ' + (i+1) + ' ---');
                for (String key : parsedQuotes[i].keySet()) {
                    System.debug('KEY: [' + key + '] => VALUE: [' + parsedQuotes[i].get(key) + ']');
                }
            }

            // ==========================================
            // RENAME FILE & SET TYPE TO PROPOSAL
            // ==========================================
            String newTitle = 'Proposal';
            String carrier = getNormalizedString(parsedQuotes[0], 'Carrier');
            if (String.isNotBlank(carrier)) {
                newTitle += ' - ' + carrier;
            }

            if (parsedQuotes.size() > 1) {
                newTitle += ' - Multiple Lines';
            } else {
                String lineOfBusiness = getNormalizedString(parsedQuotes[0], 'LineOfBusiness');
                if (String.isBlank(lineOfBusiness)) {
                    lineOfBusiness = getNormalizedString(parsedQuotes[0], 'Lines');
                }
                if (String.isNotBlank(lineOfBusiness)) {
                    newTitle += ' - ' + lineOfBusiness;
                }
            }

            List<ContentVersion> cvsToUpdate = [
                SELECT Id, Title, Type__c
                FROM ContentVersion
                WHERE ContentDocumentId = :documentId
                AND IsLatest = true
                LIMIT 1
            ];
            if (!cvsToUpdate.isEmpty()) {
                ContentVersion cvToUpdate = cvsToUpdate[0];
                cvToUpdate.Title = newTitle;
                cvToUpdate.Type__c = 'Proposal';
                update cvToUpdate;
            }

            // ==========================================
            // 7. ROUTING CONTEXT LOGIC
            // ==========================================
            Id targetLeadId;
            Boolean isBrandNewLead = false;

            if (contextLeadId != null) {
                System.debug('DEBUG: Use Case A - Context Lead Provided: ' + contextLeadId);
                targetLeadId = contextLeadId;
            } else {
                System.debug('DEBUG: Use Case B - No context lead. Searching database...');
                
                Lead existingLead = null;
                for (Map<String, Object> quoteData : parsedQuotes) {
                    existingLead = findExistingLead(quoteData);
                    if (existingLead != null) break;
                }

                if (existingLead != null) {
                    System.debug('DEBUG: Existing Lead Found: ' + existingLead.Id);
                    targetLeadId = existingLead.Id;
                } else {
                    System.debug('DEBUG: No lead found. Generating new Lead...');
                    Map<String, Object> primaryContactData = parsedQuotes[0];
                    for (Map<String, Object> quoteData : parsedQuotes) {
                        if (String.isNotBlank(getNormalizedString(quoteData, 'InsuredFirstName')) || 
                            String.isNotBlank(getNormalizedString(quoteData, 'InsuredEmail')) ||
                            String.isNotBlank(getNormalizedString(quoteData, 'InsuredPhone'))) {
                            primaryContactData = quoteData;
                            break;
                        }
                    }
                    
                    Lead newLead = createLead(primaryContactData);
                    targetLeadId = newLead.Id;
                    isBrandNewLead = true;
                }
            }

            System.debug('DEBUG: Final Target Lead ID: ' + targetLeadId);

            // ==========================================
            // PRE-LOAD MAPS FOR AGENCY FEE CALCULATION
            // ==========================================
            Map<String, String> carrierAdmittedStatusMap = new Map<String, String>();
            for (Carrier__c c : [SELECT Company_Name__c, Admitted_Status__c FROM Carrier__c WITH USER_MODE]) {
                carrierAdmittedStatusMap.put(c.Company_Name__c.toUpperCase(), c.Admitted_Status__c);
            }
            Map<String, Map<String, Decimal>> feeMap = QuoteAgencyController.getAgencyFeeMap();

            // ==========================================
            // CREATE POLICY & PROPERTY
            // ==========================================
            for (Map<String, Object> quoteData : parsedQuotes) {
                createPolicyInformation(targetLeadId, quoteData, carrierAdmittedStatusMap, feeMap);
            }

            if (isBrandNewLead) {
                // Just use the first quote to populate property info (typically Home policy)
                Map<String, Object> primaryPropertyData = parsedQuotes[0];
                for (Map<String, Object> quoteData : parsedQuotes) {
                    if (String.isNotBlank(getNormalizedString(quoteData, 'YearBuilt')) ||
                        String.isNotBlank(getNormalizedString(quoteData, 'Construction'))) {
                        primaryPropertyData = quoteData;
                        break;
                    }
                }
                createPropertyInformation(targetLeadId, primaryPropertyData);
            }

            return targetLeadId;

        } catch (Exception e) {
            String realError = e.getMessage();
            System.debug('CRITICAL INTAKE ENGINE ERROR: ' + realError);

            AuraHandledException auraEx = new AuraHandledException(realError);
            auraEx.setMessage(realError);
            throw auraEx;
        }
    }

    // ==========================================
    // ROBUST JSON EXTRACTOR
    // ==========================================
    private static String extractJsonPayload(String rawLlmResponse) {
        if (String.isBlank(rawLlmResponse)) return '{}';

        Integer firstCurly = rawLlmResponse.indexOf('{');
        Integer lastCurly  = rawLlmResponse.lastIndexOf('}');
        
        Integer firstSquare = rawLlmResponse.indexOf('[');
        Integer lastSquare  = rawLlmResponse.lastIndexOf(']');

        // Prioritize array structure if it encapsulates the json objects
        if (firstSquare != -1 && lastSquare != -1 && lastSquare > firstSquare && (firstCurly == -1 || firstSquare < firstCurly)) {
            return rawLlmResponse.substring(firstSquare, lastSquare + 1);
        } else if (firstCurly != -1 && lastCurly != -1 && lastCurly > firstCurly) {
            return rawLlmResponse.substring(firstCurly, lastCurly + 1);
        }
        return rawLlmResponse.trim();
    }

    // ==========================================
    // FIND EXISTING LEAD
    // ==========================================
    private static Lead findExistingLead(Map<String, Object> parsedData) {
        String email = getNormalizedString(parsedData, 'InsuredEmail');
        String phone = getNormalizedString(parsedData, 'InsuredPhone');

        System.debug('DEBUG: Searching for Lead with Email: [' + email + '] or Phone: [' + phone + ']');

        if (String.isBlank(email) && String.isBlank(phone)) {
            System.debug('DEBUG: Both Email and Phone are blank. Returning null.');
            return null;
        }

        List<Lead> leads = [
            SELECT Id FROM Lead
            WHERE (Email = :email AND Email != null)
            OR (Phone = :phone AND Phone != null)
            LIMIT 1
        ];

        System.debug('DEBUG: Number of matching leads found in DB: ' + leads.size());

        return !leads.isEmpty() ? leads[0] : null;
    }

    // ==========================================
    // CREATE LEAD
    // ==========================================
    private static Lead createLead(Map<String, Object> parsedData) {
        System.debug('WARNING: THE APEX createLead() METHOD WAS EXECUTED!');

        Lead newLead = new Lead();

        newLead.FirstName = getNormalizedString(parsedData, 'InsuredFirstName');
        newLead.LastName  = getNormalizedString(parsedData, 'InsuredLastName');

        if (String.isBlank(newLead.LastName)) {
            newLead.LastName = String.isNotBlank(newLead.FirstName) ? newLead.FirstName : 'Unknown Insured';
        }

        String companyVal = getNormalizedString(parsedData, 'Company');
        newLead.Company = String.isNotBlank(companyVal) ? companyVal : 'NA';

        newLead.Status      = 'Open - Not Contacted';
        newLead.Phone       = getNormalizedString(parsedData, 'InsuredPhone');
        newLead.Email       = getNormalizedString(parsedData, 'InsuredEmail');
        newLead.Street      = getNormalizedString(parsedData, 'Street');
        newLead.City        = getNormalizedString(parsedData, 'City');
        newLead.State       = getNormalizedString(parsedData, 'State');
        newLead.PostalCode  = getNormalizedString(parsedData, 'ZipCode');
        newLead.Country     = 'United States';

        insert newLead;
        System.debug('NEW LEAD INSERTED BY APEX! ID: ' + newLead.Id);
        return newLead;
    }

    // ==========================================
    // CREATE POLICY INFORMATION
    // ==========================================
    private static void createPolicyInformation(Id leadId, Map<String, Object> parsedData, Map<String, String> carrierMap, Map<String, Map<String, Decimal>> feeMap) {
        Policy_Information__c newPolicy = new Policy_Information__c();
        newPolicy.Lead__c = leadId;

        // ==========================================
        // 1. CARRIER MAPPING (lookup by Id)
        // ==========================================
        String rawCarrier = getNormalizedString(parsedData, 'Carrier');
        System.debug('==== CARRIER DEBUG ====');
        System.debug('Raw Carrier from AI: [' + rawCarrier + ']');

        if (String.isNotBlank(rawCarrier)) {
            // Apply custom mapping exceptions before DB check
            String upperCarrier = rawCarrier.toUpperCase();
            if (upperCarrier.contains('NATGEN') || upperCarrier.contains('NATIONAL GENERAL')) {
                System.debug('Applying alias override: NatGen -> National General');
                rawCarrier = 'National General';
            } else if (upperCarrier.contains('HOMEOWNERS OF AMERICA') || upperCarrier.contains('HOAIC')) {
                System.debug('Applying alias override: Homeowners of America -> HOAIC');
                rawCarrier = 'Homeowners of America Ins Co (HOAIC)';
            } else if (upperCarrier.contains('UNIVERSAL')) {
                System.debug('Applying alias override: Universal Property -> Universal');
                rawCarrier = 'Universal';
            } else if (upperCarrier.contains('ORION') && upperCarrier.contains('180')) {
                System.debug('Applying alias override: Orion 180 -> Orion 180 - OIC');
                rawCarrier = 'Orion 180 - OIC';
            }

            String cleanCarrier = rawCarrier.replaceAll('(?i)\\b(Insurance|Co\\.?|Company|Inc\\.?|LLC|Corp\\.?)\\b', '').trim();
            for (Carrier__c c : [SELECT Id, Company_Name__c FROM Carrier__c WITH USER_MODE LIMIT 1000]) {
                System.debug('Comparing DB carrier: [' + c.Company_Name__c + '] vs AI: [' + rawCarrier + ']');
                String cleanDb = c.Company_Name__c.replaceAll('(?i)\\b(Insurance|Co\\.?|Company|Inc\\.?|LLC|Corp\\.?)\\b', '').trim();
                
                if (c.Company_Name__c.equalsIgnoreCase(rawCarrier) ||
                    c.Company_Name__c.containsIgnoreCase(rawCarrier) ||
                    rawCarrier.containsIgnoreCase(c.Company_Name__c) ||
                    (String.isNotBlank(cleanCarrier) && String.isNotBlank(cleanDb) && 
                     (cleanDb.equalsIgnoreCase(cleanCarrier) || cleanDb.containsIgnoreCase(cleanCarrier) || cleanCarrier.containsIgnoreCase(cleanDb)))) {
                    
                    newPolicy.Carrier__c = c.Company_Name__c;
                    System.debug('CARRIER MATCH FOUND: ' + c.Company_Name__c + ' (Id: ' + c.Id + ')');
                    break;
                }
            }
            if (newPolicy.Carrier__c == null) {
              System.debug('NO CARRIER MATCH - leaving blank to enforce Carrier List selection. Raw was: [' + rawCarrier + ']');
              // We intentionally do NOT save the raw text so the agent is forced 
              // to pick an official carrier from the dropdown.
              // newPolicy.Carrier__c = rawCarrier;
            }
        }
        System.debug('Final Carrier__c value set: [' + newPolicy.Carrier__c + ']');

        // ==========================================
        // 2. QUOTE NUMBER
        // ==========================================
        newPolicy.Quote__c = getNormalizedString(parsedData, 'QuoteNumber');
        if (String.isBlank(newPolicy.Quote__c)) {
            Integer randomInt = (Integer)Math.floor(Math.random() * 900000000) + 100000000;
            newPolicy.Quote__c = 'RP-INT-' + randomInt;
        }

        // ==========================================
        // 3. LINE OF BUSINESS MAPPING
        // ==========================================
        String rawLine = getNormalizedString(parsedData, 'LineOfBusiness');
        if (String.isBlank(rawLine)) {
            rawLine = getNormalizedString(parsedData, 'Lines');
        }
        if (String.isNotBlank(rawLine)) {
            String upperLine = rawLine.toUpperCase();
            if (upperLine.contains('HOMEOWNER') || upperLine.contains('HOME') || upperLine.contains('PROPERTY')) {
                newPolicy.Lines__c = 'Home';
            } else if (upperLine.contains('AUTO')) {
                newPolicy.Lines__c = 'Auto';
            } else if (upperLine.contains('FLOOD')) {
                newPolicy.Lines__c = 'Flood';
            } else if (upperLine.contains('RENTER')) {
                newPolicy.Lines__c = 'Renters';
            } else if (upperLine.contains('UMBRELLA')) {
                newPolicy.Lines__c = 'Umbrella';
            } else if (upperLine.contains('CONDO')) {
                newPolicy.Lines__c = 'Condo';
            } else {
                newPolicy.Lines__c = rawLine;
            }
        }

        // ==========================================
        // 4. TERM MAPPING
        // ==========================================
        String rawTerm = getNormalizedString(parsedData, 'Term');
        System.debug('Raw Term from AI: [' + rawTerm + ']');
        if (String.isNotBlank(rawTerm)) {
            String upperTerm = rawTerm.toUpperCase();
            if (upperTerm.contains('6') || upperTerm.contains('SIX') || upperTerm.contains('SEMI')) {
                newPolicy.Term__c = '6-Month';
            } else if (upperTerm.contains('NON') || upperTerm.contains('SHORT')) {
                newPolicy.Term__c = 'Non-Renewable';
            } else {
                // Covers "Annual", "12-Month", "12 Month", or any other value
                newPolicy.Term__c = 'Annual';
            }
        }
        System.debug('Final Term__c value set: [' + newPolicy.Term__c + ']');

        // ==========================================
        // 5. PREMIUM / FEE / TOTAL
        // ==========================================
        Decimal premiumNum = getNormalizedDecimal(parsedData, 'Premium');
        newPolicy.Premium__c   = premiumNum != null ? String.valueOf(premiumNum) : null;
        
        // ==========================================
        // 6. DATES (flexible parser — handles MM/DD/YYYY and YYYY-MM-DD)
        // ==========================================
        newPolicy.Effective_Date__c  = parseFlexibleDate(getNormalizedString(parsedData, 'EffectiveDate'));
        newPolicy.Expiration_Date__c = parseFlexibleDate(getNormalizedString(parsedData, 'ExpirationDate'));

        if (newPolicy.Expiration_Date__c == null && newPolicy.Effective_Date__c != null && String.isNotBlank(newPolicy.Term__c)) {
            if (newPolicy.Term__c == '6-Month') {
                newPolicy.Expiration_Date__c = newPolicy.Effective_Date__c.addMonths(6);
            } else if (newPolicy.Term__c == 'Annual') {
                newPolicy.Expiration_Date__c = newPolicy.Effective_Date__c.addYears(1);
            }
        }

        // ==========================================
        // 7. ADDRESS
        // ==========================================
        newPolicy.Address__Street__s     = getNormalizedString(parsedData, 'Street');
        newPolicy.Address__City__s       = getNormalizedString(parsedData, 'City');
        newPolicy.Address__PostalCode__s = getNormalizedString(parsedData, 'ZipCode');

        String rawState = getNormalizedString(parsedData, 'State');
        if (String.isNotBlank(rawState)) {
            String code     = convertStateToCode(rawState);
            String fullName = convertCodeToStateName(code);
            newPolicy.Address__StateCode__s = code;
            newPolicy.Agency_State__c       = fullName;
        }

        // ==========================================
        // 8. CALCULATE AGENCY FEE
        // ==========================================
        Decimal calcAgencyFee = 0;
        Decimal calcNonAdmittedFee = 0;
        
        String calcState = newPolicy.Agency_State__c;
        String calcLob = normalizeLineOfBusiness(newPolicy.Lines__c);
        
        String admittedStatus = 'Admitted';
        if (String.isNotBlank(newPolicy.Carrier__c) && carrierMap.containsKey(newPolicy.Carrier__c.toUpperCase())) {
            admittedStatus = carrierMap.get(newPolicy.Carrier__c.toUpperCase());
            if (String.isBlank(admittedStatus)) admittedStatus = 'Admitted';
        }
        
        if (String.isNotBlank(calcState) && String.isNotBlank(calcLob)) {
            String feeKey = (calcState + '|' + calcLob).toUpperCase();
            if (feeMap.containsKey(feeKey)) {
                Map<String, Decimal> fData = feeMap.get(feeKey);
                if (admittedStatus == 'Admitted') {
                    if (calcState.equalsIgnoreCase('Arkansas') || calcState.equalsIgnoreCase('AR')) {
                        calcAgencyFee = Math.min(25.00, (premiumNum != null ? premiumNum : 0) * 0.20);
                    } else {
                        calcAgencyFee = fData.get('Admitted') != null ? fData.get('Admitted') : 0;
                    }
                } else {
                    calcNonAdmittedFee = fData.get('Non-Admitted') != null ? fData.get('Non-Admitted') : 0;
                }
            }
        }
        newPolicy.Agency_Fee__c = calcAgencyFee + calcNonAdmittedFee;
        newPolicy.Total__c      = (premiumNum != null ? premiumNum : 0) + newPolicy.Agency_Fee__c;

        // ==========================================
        // 9. FLAGS AND SUMMARY
        // ==========================================
        newPolicy.Is_Quote__c = true;
        newPolicy.Quote_Summary__c = getNormalizedString(parsedData, 'QuoteSummary');

        insert newPolicy;
        System.debug('Policy_Information__c inserted: ' + newPolicy.Id);
    }

    // ==========================================
    // FLEXIBLE DATE PARSER
    // Handles: YYYY-MM-DD, MM/DD/YYYY, MM-DD-YYYY
    // ==========================================
    private static Date parseFlexibleDate(String dateStr) {
        if (String.isBlank(dateStr)) return null;
        dateStr = dateStr.trim();

        // Format 1: YYYY-MM-DD (standard ISO — try first)
        try { return Date.valueOf(dateStr); } catch (Exception e) {}

        // Format 2: MM/DD/YYYY  (Hartford, most US carriers)
        try {
            List<String> p = dateStr.split('/');
            if (p.size() == 3 && p[2].length() == 4) {
                return Date.newInstance(
                    Integer.valueOf(p[2]),
                    Integer.valueOf(p[0]),
                    Integer.valueOf(p[1])
                );
            }
        } catch (Exception e) {}

        // Format 3: MM-DD-YYYY
        try {
            List<String> p = dateStr.split('-');
            if (p.size() == 3 && p[0].length() <= 2) {
                return Date.newInstance(
                    Integer.valueOf(p[2]),
                    Integer.valueOf(p[0]),
                    Integer.valueOf(p[1])
                );
            }
        } catch (Exception e) {}

        System.debug('WARNING: Could not parse date string: [' + dateStr + ']');
        return null;
    }

    // ==========================================
    // STATE CODE CONVERTERS
    // ==========================================
    private static String convertStateToCode(String state) {
        if (String.isBlank(state)) return state;
        String s = state.trim().toUpperCase();
        if (s == 'ALABAMA') return 'AL'; if (s == 'ALASKA') return 'AK'; if (s == 'ARIZONA') return 'AZ';
        if (s == 'ARKANSAS') return 'AR'; if (s == 'CALIFORNIA') return 'CA'; if (s == 'COLORADO') return 'CO';
        if (s == 'CONNECTICUT') return 'CT'; if (s == 'DELAWARE') return 'DE'; if (s == 'FLORIDA') return 'FL';
        if (s == 'GEORGIA') return 'GA'; if (s == 'HAWAII') return 'HI'; if (s == 'IDAHO') return 'ID';
        if (s == 'ILLINOIS') return 'IL'; if (s == 'INDIANA') return 'IN'; if (s == 'IOWA') return 'IA';
        if (s == 'KANSAS') return 'KS'; if (s == 'KENTUCKY') return 'KY'; if (s == 'LOUISIANA') return 'LA';
        if (s == 'MAINE') return 'ME'; if (s == 'MARYLAND') return 'MD'; if (s == 'MASSACHUSETTS') return 'MA';
        if (s == 'MICHIGAN') return 'MI'; if (s == 'MINNESOTA') return 'MN'; if (s == 'MISSISSIPPI') return 'MS';
        if (s == 'MISSOURI') return 'MO'; if (s == 'MONTANA') return 'MT'; if (s == 'NEBRASKA') return 'NE';
        if (s == 'NEVADA') return 'NV'; if (s == 'NEW HAMPSHIRE') return 'NH'; if (s == 'NEW JERSEY') return 'NJ';
        if (s == 'NEW MEXICO') return 'NM'; if (s == 'NEW YORK') return 'NY'; if (s == 'NORTH CAROLINA') return 'NC';
        if (s == 'NORTH DAKOTA') return 'ND'; if (s == 'OHIO') return 'OH'; if (s == 'OKLAHOMA') return 'OK';
        if (s == 'OREGON') return 'OR'; if (s == 'PENNSYLVANIA') return 'PA'; if (s == 'RHODE ISLAND') return 'RI';
        if (s == 'SOUTH CAROLINA') return 'SC'; if (s == 'SOUTH DAKOTA') return 'SD'; if (s == 'TENNESSEE') return 'TN';
        if (s == 'TEXAS') return 'TX'; if (s == 'UTAH') return 'UT'; if (s == 'VERMONT') return 'VT';
        if (s == 'VIRGINIA') return 'VA'; if (s == 'WASHINGTON') return 'WA'; if (s == 'WEST VIRGINIA') return 'WV';
        if (s == 'WISCONSIN') return 'WI'; if (s == 'WYOMING') return 'WY';
        return s; // already a code or unknown
    }

    private static String convertCodeToStateName(String code) {
        if (String.isBlank(code)) return code;
        String c = code.trim().toUpperCase();
        if (c == 'AL') return 'Alabama'; if (c == 'AK') return 'Alaska'; if (c == 'AZ') return 'Arizona';
        if (c == 'AR') return 'Arkansas'; if (c == 'CA') return 'California'; if (c == 'CO') return 'Colorado';
        if (c == 'CT') return 'Connecticut'; if (c == 'DE') return 'Delaware'; if (c == 'FL') return 'Florida';
        if (c == 'GA') return 'Georgia'; if (c == 'HI') return 'Hawaii'; if (c == 'ID') return 'Idaho';
        if (c == 'IL') return 'Illinois'; if (c == 'IN') return 'Indiana'; if (c == 'IA') return 'Iowa';
        if (c == 'KS') return 'Kansas'; if (c == 'KY') return 'Kentucky'; if (c == 'LA') return 'Louisiana';
        if (c == 'ME') return 'Maine'; if (c == 'MD') return 'Maryland'; if (c == 'MA') return 'Massachusetts';
        if (c == 'MI') return 'Michigan'; if (c == 'MN') return 'Minnesota'; if (c == 'MS') return 'Mississippi';
        if (c == 'MO') return 'Missouri'; if (c == 'MT') return 'Montana'; if (c == 'NE') return 'Nebraska';
        if (c == 'NV') return 'Nevada'; if (c == 'NH') return 'New Hampshire'; if (c == 'NJ') return 'New Jersey';
        if (c == 'NM') return 'New Mexico'; if (c == 'NY') return 'New York'; if (c == 'NC') return 'North Carolina';
        if (c == 'ND') return 'North Dakota'; if (c == 'OH') return 'Ohio'; if (c == 'OK') return 'Oklahoma';
        if (c == 'OR') return 'Oregon'; if (c == 'PA') return 'Pennsylvania'; if (c == 'RI') return 'Rhode Island';
        if (c == 'SC') return 'South Carolina'; if (c == 'SD') return 'South Dakota'; if (c == 'TN') return 'Tennessee';
        if (c == 'TX') return 'Texas'; if (c == 'UT') return 'Utah'; if (c == 'VT') return 'Vermont';
        if (c == 'VA') return 'Virginia'; if (c == 'WA') return 'Washington'; if (c == 'WV') return 'West Virginia';
        if (c == 'WI') return 'Wisconsin'; if (c == 'WY') return 'Wyoming';
        return c;
    }

    // ==========================================
    // CREATE PROPERTY INFORMATION
    // ==========================================
    private static void createPropertyInformation(Id leadId, Map<String, Object> parsedData) {
        Property_Information__c propInfo = new Property_Information__c();
        propInfo.Lead__c                  = leadId;
        propInfo.Year_Built__c            = getNormalizedString(parsedData, 'YearBuilt');
        propInfo.Number_of_Stories__c     = getNormalizedString(parsedData, 'NumberOfStories');
        propInfo.Construction__c          = getNormalizedString(parsedData, 'Construction');
        propInfo.Foundation_Type__c       = getNormalizedString(parsedData, 'FoundationType');
        propInfo.Roof_Shape__c            = getNormalizedString(parsedData, 'RoofShape');
        propInfo.Roof_Type__c             = getNormalizedString(parsedData, 'RoofType');
        propInfo.Roof_Yr__c               = getNormalizedString(parsedData, 'RoofYear');
        propInfo.Plumbing__c              = getNormalizedString(parsedData, 'PlumbingType');
        propInfo.Plumbing_Year__c         = getNormalizedString(parsedData, 'PlumbingYear');
        propInfo.Wiring_Year__c           = getNormalizedString(parsedData, 'WiringYear');
        propInfo.Square_Footage__c        = getNormalizedDecimal(parsedData, 'SquareFootage');
        propInfo.Number_of_Mortgages__c   = getNormalizedDecimal(parsedData, 'NumberOfMortgages');
        propInfo.Members_in_Household__c  = getNormalizedDecimal(parsedData, 'MembersInHousehold');
        propInfo.Is_Pool__c               = getNormalizedBoolean(parsedData, 'IsPool');
        propInfo.Is_Alarm_System__c       = getNormalizedBoolean(parsedData, 'IsAlarmSystem');
        propInfo.Is_Animal__c             = getNormalizedBoolean(parsedData, 'IsAnimal');

        insert propInfo;
        System.debug('Property_Information__c inserted: ' + propInfo.Id);
    }

    // ==========================================
    // NORMALIZATION UTILITIES
    // ==========================================
    private static String normalizeLineOfBusiness(String lob) {
        if (String.isNotBlank(lob)) {
            String s = lob.trim().toUpperCase();
            List<String> propertyLines = new List<String>{'HOME', 'LANDLORD', 'CONDO', 'SECONDARY PROPERTY', 'MANUFACTURED HOME', 'MOBILE HOME', 'MOBILE / MANUFACTURED HOME'};
            for (String p : propertyLines) {
                if (s == p) return 'HOME';
            }
        }
        return lob;
    }


    private static Object getNormalizedValue(Map<String, Object> sourceMap, String targetKey) {
        String cleanTarget = targetKey.toLowerCase().replaceAll('[^a-z0-9]', '');
        for (String key : sourceMap.keySet()) {
            if (key.toLowerCase().replaceAll('[^a-z0-9]', '').equals(cleanTarget)) {
                return sourceMap.get(key);
            }
        }
        return null;
    }

    private static String getNormalizedString(Map<String, Object> sourceMap, String targetKey) {
        Object val = getNormalizedValue(sourceMap, targetKey);
        if (val == null) return null;
        String s = String.valueOf(val).trim();
        // Treat literal "null" strings returned by AI as actual null
        return (s.equalsIgnoreCase('null') || s == '') ? null : s;
    }

    private static Decimal getNormalizedDecimal(Map<String, Object> sourceMap, String targetKey) {
        Object val = getNormalizedValue(sourceMap, targetKey);
        if (val == null) return null;
        try {
            String cleanStr = String.valueOf(val).replaceAll('[^0-9\\.]', '');
            return String.isNotBlank(cleanStr) ? Decimal.valueOf(cleanStr) : null;
        } catch (Exception e) { return null; }
    }

    private static Boolean getNormalizedBoolean(Map<String, Object> sourceMap, String targetKey) {
        Object val = getNormalizedValue(sourceMap, targetKey);
        if (val == null) return false;
        String strVal = String.valueOf(val).toLowerCase().trim();
        return strVal == 'true' || strVal == 'yes' || strVal == 'y' || strVal == '1' || strVal == 'incl' || strVal == 'included';
    }

    // ==========================================
    // OCR EXTRACTION
    // ==========================================
    private static String extractTextFromPDF(Blob fileData) {
        String base64Pdf       = EncodingUtil.base64Encode(fileData);
        String urlEncodedBase64 = EncodingUtil.urlEncode('data:application/pdf;base64,' + base64Pdf, 'UTF-8');

        HttpRequest req = new HttpRequest();
        req.setEndpoint('https://api.ocr.space/parse/image');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
        req.setTimeout(120000);

        String apiKey = 'helloworld';
        String body   = 'apikey=' + apiKey + '&base64Image=' + urlEncodedBase64 + '&OCREngine=2';
        req.setBody(body);

        Http http = new Http();
        HttpResponse res = http.send(req);

        if (res.getStatusCode() == 200) {
            Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            List<Object> parsedResults      = (List<Object>) responseMap.get('ParsedResults');

            if (parsedResults != null && !parsedResults.isEmpty()) {
                String combinedText = '';
                for (Object result : parsedResults) {
                    Map<String, Object> pageResult = (Map<String, Object>) result;
                    if (pageResult.get('ParsedText') != null) {
                        combinedText += (String) pageResult.get('ParsedText') + '\n';
                    }
                }
                if (String.isNotBlank(combinedText)) return combinedText;
            }
            if ((Boolean) responseMap.get('IsErroredOnProcessing') == true) {
                throw new CalloutException('OCR API Error: ' + responseMap.get('ErrorMessage'));
            }
        }
        throw new CalloutException('Failed to contact OCR server. Status: ' + res.getStatusCode());
    }
}