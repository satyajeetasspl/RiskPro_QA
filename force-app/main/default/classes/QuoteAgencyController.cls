public with sharing class QuoteAgencyController {
    
    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getCarrierOptions() {
        List<Map<String, String>> options = new List<Map<String, String>>();
        try {
            for(Carrier__c carrier : [SELECT Id, Company_Name__c, Admitted_Status__c FROM Carrier__c WITH USER_MODE ORDER BY Company_Name__c]) {
                options.add(new Map<String, String>{
                    'label' => carrier.Company_Name__c,
                    'value' => carrier.Company_Name__c,
                    'admittedStatus' => carrier.Admitted_Status__c
                });
            }
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
        return options;
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, Map<String, Decimal>> getAgencyFeeMap() {
        Map<String, Map<String, Decimal>> feeMap = new Map<String, Map<String, Decimal>>();
        try {
            for (Agency_Fee__c fee : [SELECT State__c, Line_of_Business__c, Agency_Fee_Amount__c, Non_Admitted_Agency_Fee__c FROM Agency_Fee__c WHERE (Agency_Fee_Amount__c != null OR Non_Admitted_Agency_Fee__c != null) WITH USER_MODE]) {
                String key = (fee.State__c + '|' + fee.Line_of_Business__c).toUpperCase();
                feeMap.put(key, new Map<String, Decimal>{
                    'Admitted' => fee.Agency_Fee_Amount__c != null ? fee.Agency_Fee_Amount__c : 0,
                    'Non-Admitted' => fee.Non_Admitted_Agency_Fee__c != null ? fee.Non_Admitted_Agency_Fee__c : 0
                });
            }
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
        return feeMap;
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, String> getRecordDetails(Id recordId) {
        Map<String, String> result = new Map<String, String>();
        if (recordId == null) return result;
        
        SObjectType sType = recordId.getSObjectType();
        if (sType == Lead.SObjectType) {
            Lead l = [SELECT Name, State, Policy_Check_Status__c, Email FROM Lead WHERE Id = :recordId WITH USER_MODE LIMIT 1];
            result.put('Name', l.Name);
            result.put('State', l.State);
            result.put('PolicyCheckStatus', l.Policy_Check_Status__c);
            result.put('Email', l.Email);
        } else if (sType == Opportunity.SObjectType) {
            Opportunity o = [SELECT Name, Account.Address_Property__StateCode__s, Policy_Check_Status__c, Account.Email__c FROM Opportunity WHERE Id = :recordId WITH USER_MODE LIMIT 1];
            result.put('Name', o.Name);
            result.put('State', o.Account.Address_Property__StateCode__s);
            result.put('PolicyCheckStatus', o.Policy_Check_Status__c);
            result.put('Email', o.Account.Email__c);
        }
        return result;
    }

    @AuraEnabled(cacheable=true)
    public static List<Policy_Information__c> getExistingQuotes(Id recordId) {
        SObjectType sType = recordId.getSObjectType();
        String query = 'SELECT Id, Carrier__c, Lines__c, Quote__c, Quote_Identifier__c, Premium__c, Effective_Date__c, Agency_State__c, Agency_Fee__c, Include_in_Proposal__c, ' +
                       'Agency_Fee_Waiver_Request__c, Agency_Fee_Waiver_Decision__c, Waiver_Comment__c, Waiver_Reason__c, Waiver_Token__c, Term__c, Expiration_Date__c, ' +
                       'Policy_Bound__c, Policy_Status__c, Is_Replacement__c, Replacement_Initiated__c, Quote_Summary__c, Original_Policy__c, ' +
                       '(SELECT Status__c FROM Agency_Fee_Invoices__r ORDER BY CreatedDate DESC LIMIT 1) ' +
                       'FROM Policy_Information__c WHERE Is_Quote__c = true ';
        if (sType == Lead.SObjectType) query += 'AND Lead__c = :recordId ';
        else if (sType == Opportunity.SObjectType) query += 'AND Opportunity__c = :recordId ';
        query += 'WITH USER_MODE';
        return Database.query(query);
    }
    
    @AuraEnabled(cacheable=true)
    public static Boolean checkIsSystemAdmin() {
        Profile p = [SELECT Name FROM Profile WHERE Id = :UserInfo.getProfileId() LIMIT 1];
        return (p.Name == 'System Administrator' && p.Name != 'RiskPro');
    }

    @AuraEnabled
    public static List<Policy_Information__c> saveQuotes(Id recordId, List<Policy_Information__c> quotesToUpsert, List<Id> quoteIdsToDelete) {
        if (recordId == null || ((quotesToUpsert == null || quotesToUpsert.isEmpty()) && (quoteIdsToDelete == null || quoteIdsToDelete.isEmpty()))) {
            throw new AuraHandledException('No quotes provided.');
        }

        try {
            if (quoteIdsToDelete != null && !quoteIdsToDelete.isEmpty()) {
                delete [SELECT Id FROM Policy_Information__c WHERE Id IN :quoteIdsToDelete WITH USER_MODE];
            }

            if (quotesToUpsert != null && !quotesToUpsert.isEmpty()) {
                SObjectType sType = recordId.getSObjectType();
                Opportunity opp;
                if (sType == Opportunity.SObjectType) {
                    opp = [SELECT Id, AccountId FROM Opportunity WHERE Id = :recordId WITH USER_MODE LIMIT 1];
                }

                for (Policy_Information__c quote : quotesToUpsert) {
                    if (sType == Lead.SObjectType) {
                        quote.Lead__c = recordId;
                    } else if (sType == Opportunity.SObjectType) {
                        quote.Opportunity__c = recordId;
                        quote.Account__c = opp.AccountId;
                    }
                    
                    if (quote.Id == null) {
                        quote.Policy_Type__c = 'Quote';
                        quote.Is_Quote__c = true; 
                    }
                    
                    Decimal premiumAmt = 0.00;
                    if (quote.Premium__c != null) {
                        premiumAmt = Decimal.valueOf(String.valueOf(quote.Premium__c));
                    }
                    
                    if (quote.Agency_State__c == 'AR' || quote.Agency_State__c == 'Arkansas') {
                        quote.Agency_Fee__c = Math.min(25.00, (premiumAmt * 0.20));
                    }
                }
                upsert as user quotesToUpsert;
                
                // Call the helper to process waivers in system mode
                QuoteAgencyHelper.processWaiverRequests(recordId, quotesToUpsert);
            }
            
            return quotesToUpsert;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static void deleteQuote(Id quoteId) {
        if (quoteId == null) return;
        try {
            delete [SELECT Id FROM Policy_Information__c WHERE Id = :quoteId WITH USER_MODE];
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static void savePDFToRecord(Id recordId, String quotesJson, String recordName) {
    try {
        List<QuotePDFController.QuoteWrapper> quotes = (List<QuotePDFController.QuoteWrapper>) JSON.deserialize(quotesJson, List<QuotePDFController.QuoteWrapper>.class);
        
        Map<String, List<QuotePDFController.QuoteWrapper>> groupedQuotes = new Map<String, List<QuotePDFController.QuoteWrapper>>();
        
        Set<String> carrierNames = new Set<String>();
        Set<String> states = new Set<String>();
        for(QuotePDFController.QuoteWrapper q : quotes) {
            if(String.isNotBlank(q.getSafeState())) {
                states.add(q.getSafeState());
            }
            if(String.isNotBlank(q.Carrier)) {
                carrierNames.add(q.Carrier);
            }
        }
        
        // Fetch statuses for these carriers
        Map<String, String> carrierStatusMapByName = new Map<String, String>();
        for (Carrier__c c : [SELECT Company_Name__c, Admitted_Status__c FROM Carrier__c WHERE Company_Name__c IN :carrierNames WITH USER_MODE]) {
            carrierStatusMapByName.put(c.Company_Name__c, c.Admitted_Status__c);
        }

        Map<String, Agency_Fee__c> feeMap = new Map<String, Agency_Fee__c>();
        for (Agency_Fee__c fee : [SELECT State__c, Line_of_Business__c, Color__c, Agency_Fee_Amount__c FROM Agency_Fee__c WHERE State__c IN :states AND Color__c != null WITH USER_MODE]) {
            String key = (fee.State__c + '|' + (fee.Line_of_Business__c != null ? fee.Line_of_Business__c : '')).toUpperCase();
            feeMap.put(key, fee);
            String fallbackKey = fee.State__c.toUpperCase();
            if (!feeMap.containsKey(fallbackKey)) {
                feeMap.put(fallbackKey, fee);
            }
        }
        
        // Step 1: Identify "Mixed" carriers using current statuses
        Map<String, Set<String>> activeCarrierStatusMap = new Map<String, Set<String>>();
        for (QuotePDFController.QuoteWrapper q : quotes) {
            String status = carrierStatusMapByName.get(q.Carrier);
            if (status == null) status = 'Admitted';
            
            if (String.isNotBlank(q.Carrier)) {
                if (!activeCarrierStatusMap.containsKey(q.Carrier)) {
                    activeCarrierStatusMap.put(q.Carrier, new Set<String>());
                }
                activeCarrierStatusMap.get(q.Carrier).add(status);
            }
        }
        
        Set<String> mixedCarriers = new Set<String>();
        for (String carrierName : activeCarrierStatusMap.keySet()) {
            if (activeCarrierStatusMap.get(carrierName).contains('Admitted') && activeCarrierStatusMap.get(carrierName).contains('Non-Admitted')) {
                mixedCarriers.add(carrierName);
            }
        }

        for (QuotePDFController.QuoteWrapper q : quotes) {
            String rawState = q.getSafeState();
            String normState = normalizeStateName(rawState);
            String line = q.Lines != null ? q.Lines : '';
            String normLine = normalizeLineOfBusiness(line);
            
            String key = (rawState + '|' + line).toUpperCase();
            String fallbackKey = rawState != null ? rawState.toUpperCase() : '';
            String status = carrierStatusMapByName.get(q.Carrier);
            if (status == null) status = 'Admitted';
            
            String groupKey = '';
            
            // 1. Determine the logical Group/Template Key
            if (mixedCarriers.contains(q.Carrier)) {
                groupKey = 'RED'; // Mixed carriers always use No-Fee template logic
                if (status == 'Admitted') {
                    q.AgencyFee = 0; 
                }
            } else {
                // Determine base color/type from database
                String dbColor = 'WHITE';
                if ((q.AgencyFee == 0 || q.AgencyFee == null) || q.WaiverRequested == true) {
                    dbColor = 'RED';
                } else if (feeMap.containsKey(key) && feeMap.get(key).Color__c != null) {
                    dbColor = feeMap.get(key).Color__c;
                } else if (!String.isBlank(fallbackKey) && feeMap.containsKey(fallbackKey) && feeMap.get(fallbackKey).Color__c != null) {
                    dbColor = feeMap.get(fallbackKey).Color__c;
                }

                // Explicit State Template Overrides (Matches User Requirements)
                if (dbColor == 'RED') {
                    groupKey = 'RED';
                } else if (normState == 'TEXAS') {
                    groupKey = 'BLUE';
                } else if (normState == 'CONNECTICUT') {
                    groupKey = 'YELLOW';
                } else if (normState == 'ARKANSAS') {
                    groupKey = 'ORANGE';
                } else if (normState == 'LOUISIANA') {
                    groupKey = 'GREEN';
                } else if (normState == 'ALABAMA') {
                    groupKey = 'PURPLE';
                } else {
                    groupKey = dbColor.toUpperCase();
                }
            }

            if (!groupedQuotes.containsKey(groupKey)) {
                groupedQuotes.put(groupKey, new List<QuotePDFController.QuoteWrapper>());
            }
            groupedQuotes.get(groupKey).add(q);
        }
        
        SObjectType sType = recordId.getSObjectType();
        String createdDateStr = Date.today().format();
        if (sType == Lead.SObjectType) {
            Lead l = [SELECT CreatedDate FROM Lead WHERE Id = :recordId WITH USER_MODE];
            createdDateStr = l.CreatedDate != null ? l.CreatedDate.date().format() : createdDateStr;
        } else if (sType == Opportunity.SObjectType) {
            Opportunity o = [SELECT CreatedDate FROM Opportunity WHERE Id = :recordId WITH USER_MODE];
            createdDateStr = o.CreatedDate != null ? o.CreatedDate.date().format() : createdDateStr;
        }

        List<ContentVersion> cvsToInsert = new List<ContentVersion>();
        
        for (String groupKey : groupedQuotes.keySet()) {
            List<QuotePDFController.QuoteWrapper> groupList = groupedQuotes.get(groupKey);
            
            String color = groupKey;
            
            Set<String> distinctStates = new Set<String>();
            for (QuotePDFController.QuoteWrapper q : groupList) {
                if (String.isNotBlank(q.getSafeState())) {
                    distinctStates.add(q.getSafeState().toUpperCase());
                }
            }
            
            Boolean isMultiState = distinctStates.size() > 1;
            
            PageReference pdfPage;
            String pdfName = '';
            String trimmedLeadName = (recordName != null) ? recordName.trim() : 'Record';

            if (color.equalsIgnoreCase('WHITE')) {
                pdfPage = Page.QuotePDF;
                pdfName = 'Proposal Summary (Premium & Agency Service Fee) - ' + trimmedLeadName;
            } else if (color.equalsIgnoreCase('RED')) {
                pdfPage = Page.Proposal_NoFee;
                pdfName = 'Proposal Summary - ' + trimmedLeadName;
            } else if (color.equalsIgnoreCase('YELLOW')) {
                pdfPage = Page.Proposal_Connecticut;
                pdfName = 'Proposal Summary - Connecticut - ' + trimmedLeadName;
            } else if (color.equalsIgnoreCase('ORANGE')) {
                pdfPage = Page.Proposal_Arkansas;
                pdfName = 'Proposal Summary - Arkansas - ' + trimmedLeadName;
            } else if (color.equalsIgnoreCase('GREEN')) {
                pdfPage = Page.Proposal_Louisiana;
                pdfName = 'Proposal Summary - Louisiana - ' + trimmedLeadName;
            } else if (color.equalsIgnoreCase('BLUE')) {
                pdfPage = Page.Proposal_Texas;
                pdfName = 'Proposal Summary - Texas - ' + trimmedLeadName;
            } else if (color.equalsIgnoreCase('PURPLE')) {
                pdfPage = Page.Proposal_Alabama;
                pdfName = 'Proposal Summary - Alabama - ' + trimmedLeadName;
            } else {
                pdfPage = Page.QuotePDF;
                pdfName = 'Proposal Summary - ' + trimmedLeadName;
            }
            
            String groupJson = JSON.serialize(groupList);
            pdfPage.getParameters().put('quotes', groupJson);
            pdfPage.getParameters().put('leadName', recordName);
            pdfPage.getParameters().put('createdDate', createdDateStr);
            
            if (isMultiState) {
                pdfPage.getParameters().put('showStateColumn', 'true');
            }
            
            Blob pdfBlob;
            if (Test.isRunningTest()) {
                pdfBlob = Blob.valueOf('Test File');
            } else {
                pdfBlob = pdfPage.getContentAsPDF();
            }
            
            ContentVersion cv = new ContentVersion();
            cv.Title = pdfName;
            cv.PathOnClient = pdfName.replaceAll('[^a-zA-Z0-9 &() -]', '_') + '.pdf';
            cv.VersionData = pdfBlob;
            cv.IsMajorVersion = true;
            cvsToInsert.add(cv);
        }
        
        insert cvsToInsert;
        
        Set<Id> cvIds = new Set<Id>();
        for(ContentVersion cv : cvsToInsert){
            cvIds.add(cv.Id);
        }
        
        List<ContentDocumentLink> cdlsToInsert = new List<ContentDocumentLink>();
        for (ContentVersion cv : [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id IN :cvIds WITH USER_MODE]) {
            ContentDocumentLink cdl = new ContentDocumentLink();
            cdl.ContentDocumentId = cv.ContentDocumentId;
            cdl.LinkedEntityId = recordId;
            cdl.ShareType = 'V';
            cdl.Visibility = 'AllUsers';
            cdlsToInsert.add(cdl);
        }
        if(!cdlsToInsert.isEmpty()){
            insert cdlsToInsert;
        }
        
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage() + ' at line: ' + e.getLineNumber());
        }
    }

    private static String normalizeStateName(String state) {
        if (String.isNotBlank(state)) {
            String s = state.trim().toUpperCase();
            if (s == 'TX' || s == 'TEXAS') return 'TEXAS';
            if (s == 'CT' || s == 'CONNECTICUT') return 'CONNECTICUT';
            if (s == 'AR' || s == 'ARKANSAS') return 'ARKANSAS';
            if (s == 'LA' || s == 'LOUISIANA') return 'LOUISIANA';
            if (s == 'AL' || s == 'ALABAMA') return 'ALABAMA';
        }
        return state;
    }

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
}