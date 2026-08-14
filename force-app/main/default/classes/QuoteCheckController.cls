public without sharing class QuoteCheckController {
    
    // 1. Picklist Options
    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getPolicyStatusOptions() {
        List<Map<String, String>> options = new List<Map<String, String>>();
        try {
            Schema.DescribeFieldResult fieldResult = Policy_Information__c.Policy_Status__c.getDescribe();
            for (Schema.PicklistEntry f : fieldResult.getPicklistValues()) {
                options.add(new Map<String, String>{ 'label' => f.getLabel(), 'value' => f.getValue() });
            }
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
        return options;
    }

    @AuraEnabled
    public static void deleteRequirement(Id docId) {
        if (docId == null) return;
        try {
            SObjectType sType = docId.getSObjectType();
            if (sType == ContentDocument.SObjectType) {
                delete [SELECT Id FROM ContentDocument WHERE Id = :docId];
            } else if (sType == Field_UW_Requirement__c.SObjectType) {
                delete [SELECT Id FROM Field_UW_Requirement__c WHERE Id = :docId];
            }
        } catch (Exception e) {
            throw new AuraHandledException('Failed to delete requirement: ' + e.getMessage());
        }
    }

    // 2. Data Wrappers
    public class QuoteCheckWrapper {
        @AuraEnabled public SObject recordDetail { get; set; } 
        @AuraEnabled public List<String> leadLinesList { get; set; }
        @AuraEnabled public List<Policy_Information__c> policies { get; set; }
        @AuraEnabled public List<Field_UW_Requirement__c> uwRequirements { get; set; }
        @AuraEnabled public Boolean isSystemAdmin { get; set; }
        @AuraEnabled public Map<Id, List<ContentDocumentLink>> policyFilesMap { get; set; } 
        @AuraEnabled public Map<Id, List<FeedItem>> policyChatterMap { get; set; } 
        @AuraEnabled public List<FeedItem> generalFeedItems { get; set; }
        @AuraEnabled public DateTime submittedDateTime { get; set; }
        @AuraEnabled public List<Map<String, String>> docTypeOptions { get; set; }
        @AuraEnabled public List<Map<String, String>> reqTypeOptions { get; set; }
    }
    
    public class QuoteSaveRequest {
        @AuraEnabled public Policy_Information__c policyRecord { get; set; }
        @AuraEnabled public String requirementId { get; set; }
        @AuraEnabled public String chatterText { get; set; }
        @AuraEnabled public String mentionUserId { get; set; }
        @AuraEnabled public List<String> fileIdsToAttach { get; set; }
        @AuraEnabled public List<Base64File> base64Files { get; set; }
        @AuraEnabled public String fileType { get; set; }
        @AuraEnabled public String fileReqType { get; set; }
        @AuraEnabled public String fileReqItem { get; set; }
        @AuraEnabled public String fileDescription { get; set; }
        @AuraEnabled public String producerComments { get; set; }
        @AuraEnabled public String uwStatus { get; set; }
        @AuraEnabled public String uwTiming { get; set; }
    }

    public class Base64File {
        @AuraEnabled public String fileName { get; set; }
        @AuraEnabled public String base64 { get; set; }
        @AuraEnabled public String contentType { get; set; }
    }
    
    public class RequirementRow {

    @AuraEnabled public String appliesTo { get; set; }
    @AuraEnabled public String timing { get; set; }
    @AuraEnabled public String requirementType { get; set; }
    @AuraEnabled public String requirementItem { get; set; }

    public RequirementRow(
        String appliesTo,
        String timing,
        String requirementType,
        String requirementItem
    ) {
        this.appliesTo = appliesTo;
        this.timing = timing;
        this.requirementType = requirementType;
        this.requirementItem = requirementItem;
    }
}

    // VF Properties
    public QuoteCheckWrapper wrapperObj { get; set; }
    public String mgtComments { get; set; }

    // Constructor for VF
    public QuoteCheckController() {}

    // 3. Main Load Method
    @AuraEnabled
    public static QuoteCheckWrapper getQuoteCheckData(Id recordId) {
        if (recordId == null) throw new AuraHandledException('Record ID is required.');
        
        QuoteCheckWrapper w = new QuoteCheckWrapper();
        Profile p = [SELECT Name FROM Profile WHERE Id = :UserInfo.getProfileId() LIMIT 1];
        w.isSystemAdmin = (p.Name == 'System Administrator');
        
        SObjectType sType = recordId.getSObjectType();
        
        if (sType == Lead.SObjectType) {
            List<Lead> leads = [SELECT Id, Name, OwnerId, Owner.Name, Owner.Email, Status, Street, City, State, PostalCode, 
                        Insured_Address__Street__s, Insured_Address__City__s, Insured_Address__StateCode__s, Insured_Address__PostalCode__s,
                        Policy_Check_Status__c, Agent_2__c, Agent_2__r.Name, Agent_2__r.Email, Policy_Check_Comments__c, Personal_Lines__c, Commercial_Lines__c FROM Lead WHERE Id = :recordId LIMIT 1];
            if (leads.isEmpty()) {
                throw new AuraHandledException('Lead record not found or inaccessible for ID: ' + recordId);
            }
            Lead l = leads[0];
            w.recordDetail = l;
            List<String> finalLines = new List<String>();
            if (l.Personal_Lines__c != null) finalLines.addAll(l.Personal_Lines__c.split(';'));
            if (l.Commercial_Lines__c != null) finalLines.addAll(l.Commercial_Lines__c.split(';'));
            w.leadLinesList = finalLines;
        } 
        else if (sType == Account.SObjectType) {
            Account acc = [SELECT Id, Name, OwnerId, Owner.Name, Owner.Email, 
                            BillingStreet, BillingCity, BillingState, BillingPostalCode,
                            Address_Property__Street__s, Address_Property__City__s, Address_Property__StateCode__s, Address_Property__PostalCode__s, 
                            Policy_Check_Status__c, Agent_2__c, Agent_2__r.Name, Agent_2__r.Email, Policy_Check_Comments__c FROM Account WHERE Id = :recordId LIMIT 1];
            w.recordDetail = acc;
            w.leadLinesList = new List<String>();
        } 
        else if (sType == Opportunity.SObjectType) {
            Opportunity opp = [SELECT Id, Name, AccountId, Account.Name, OwnerId, Owner.Name, Owner.Email, 
                                Account.BillingStreet, Account.BillingCity, Account.BillingState, Account.BillingPostalCode,
                                Account.Address_Property__Street__s, Account.Address_Property__City__s, Account.Address_Property__StateCode__s, Account.Address_Property__PostalCode__s, 
                                Policy_Check_Status__c, Agent_2__c, Agent_2__r.Name, Agent_2__r.Email, Policy_Check_Comments__c FROM Opportunity WHERE Id = :recordId LIMIT 1];
            w.recordDetail = opp;
            w.leadLinesList = new List<String>();
        }
        
        // Fetch Policies (Quotes)
        String query = 'SELECT Id, Carrier__c, Lines__c, Quote__c, Agency_State__c, Term__c, Effective_Date__c, Expiration_Date__c, Agency_Fee_Waiver_Request__c, Agency_Fee_Waiver_Decision__c, Waiver_Reason__c, Waiver_Comment__c, Premium__c, Agency_Fee__c, Policy_Status__c, Policy_Bound__c, Replacement_Initiated__c, Is_Replacement__c, Original_Policy__c, Additional_Comments__c, UW_Timing__c, UW_Status__c FROM Policy_Information__c WHERE ';
        
        if (sType == Lead.SObjectType) query += 'Lead__c = :recordId';
        else if (sType == Account.SObjectType) query += 'Account__c = :recordId';
        else if (sType == Opportunity.SObjectType) query += 'Opportunity__c = :recordId';
        
        query += ' ORDER BY CreatedDate ASC';
        w.policies = Database.query(query);
        
        Set<Id> policyIds = new Set<Id>();
        for (Policy_Information__c pi : w.policies) policyIds.add(pi.Id);
        
        // Fetch Requirements
        String reqQuery = 'SELECT Id, Lead__c, Opportunity__c, Account__c, Policy_Information__c, ' +
                          'Requirement_Type__c, Requirement_Item__c, Requirement_Details__c, ' +
                          'UW_Timing__c, UW_Status__c, Producer_Comments__c, CreatedDate ' +
                          'FROM Field_UW_Requirement__c WHERE ';
        if (sType == Lead.SObjectType) reqQuery += 'Lead__c = :recordId';
        else if (sType == Account.SObjectType) reqQuery += 'Account__c = :recordId';
        else if (sType == Opportunity.SObjectType) reqQuery += 'Opportunity__c = :recordId';
        reqQuery += ' ORDER BY CreatedDate ASC';
        w.uwRequirements = Database.query(reqQuery);

        w.policyChatterMap = new Map<Id, List<FeedItem>>();
        w.policyFilesMap   = new Map<Id, List<ContentDocumentLink>>();
        w.submittedDateTime = System.now();
        
        Set<Id> allLinkedIds = new Set<Id>(policyIds);
        for (Field_UW_Requirement__c req : w.uwRequirements) allLinkedIds.add(req.Id);
        allLinkedIds.add(recordId);
        
        if (!allLinkedIds.isEmpty()) {
            for (FeedItem f : [SELECT Id, ParentId, Body, Title, CreatedDate, CreatedBy.Name, Type FROM FeedItem WHERE ParentId IN :allLinkedIds ORDER BY CreatedDate DESC]) {
                if (!w.policyChatterMap.containsKey(f.ParentId)) w.policyChatterMap.put(f.ParentId, new List<FeedItem>());
                w.policyChatterMap.get(f.ParentId).add(f);
            }
            for (ContentDocumentLink cdl : [SELECT LinkedEntityId, ContentDocumentId, 
                                                ContentDocument.Title, ContentDocument.FileExtension, ContentDocument.CreatedDate, 
                                                ContentDocument.LatestPublishedVersion.Description, 
                                                ContentDocument.LatestPublishedVersion.Type__c, 
                                                ContentDocument.LatestPublishedVersion.Requirement_Type__c, 
                                                ContentDocument.LatestPublishedVersion.Requirement_Item__c, 
                                                ContentDocument.LatestPublishedVersion.Requirement_Details__c,
                                                ContentDocument.LatestPublishedVersion.UW_Status__c,
                                                ContentDocument.LatestPublishedVersion.UW_Timing__c,
                                                ContentDocument.LatestPublishedVersion.Producer_Comments__c
                                            FROM ContentDocumentLink 
                                            WHERE LinkedEntityId IN :allLinkedIds 
                                            ORDER BY ContentDocument.CreatedDate DESC]) {
                if (!w.policyFilesMap.containsKey(cdl.LinkedEntityId)) w.policyFilesMap.put(cdl.LinkedEntityId, new List<ContentDocumentLink>());
                w.policyFilesMap.get(cdl.LinkedEntityId).add(cdl);
            }
        }
        
        // Fetch General Feed for Lead/Opp
        w.generalFeedItems = [SELECT Id, ParentId, Body, Title, CreatedDate, CreatedBy.Name, Type FROM FeedItem WHERE ParentId = :recordId ORDER BY CreatedDate DESC LIMIT 20];

        // Fetch Picklist Options for File Metadata
        w.docTypeOptions = new List<Map<String, String>>();
        for (Schema.PicklistEntry f : ContentVersion.Type__c.getDescribe().getPicklistValues()) {
            w.docTypeOptions.add(new Map<String, String>{ 'label' => f.getLabel(), 'value' => f.getValue() });
        }
        
        w.reqTypeOptions = new List<Map<String, String>>();
        for (Schema.PicklistEntry f : ContentVersion.Requirement_Type__c.getDescribe().getPicklistValues()) {
            w.reqTypeOptions.add(new Map<String, String>{ 'label' => f.getLabel(), 'value' => f.getValue() });
        }
        
        return w;
    }

    // 4. Main Save Method
    @AuraEnabled
    public static void saveQuoteCheckWithPolicies(Id recordId, String comments, String agent2Id, List<QuoteSaveRequest> quoteRequests, List<Id> deletedIds, Boolean isFinalSubmission, String chatterText, String mentionUserId, String saveContext) {
        if (recordId == null) throw new AuraHandledException('Record ID is missing.');
        
        Id a2Id = null;
        if (String.isNotBlank(agent2Id)) {
            try { a2Id = (Id)agent2Id; } catch(Exception e) { /* ignore invalid id */ }
        }

        SObjectType sType = recordId.getSObjectType();
        SObject recordToUpdate;
        String currentStatus = '';
        
        // Fetch current status for logic
        if (sType == Lead.SObjectType) currentStatus = [SELECT Policy_Check_Status__c FROM Lead WHERE Id = :recordId].Policy_Check_Status__c;
        else if (sType == Account.SObjectType) currentStatus = [SELECT Policy_Check_Status__c FROM Account WHERE Id = :recordId].Policy_Check_Status__c;
        else if (sType == Opportunity.SObjectType) currentStatus = [SELECT Policy_Check_Status__c FROM Opportunity WHERE Id = :recordId].Policy_Check_Status__c;

        // Prepare record update
        if (sType == Lead.SObjectType) {
            recordToUpdate = new Lead(Id = recordId, Policy_Check_Comments__c = comments, Agent_2__c = a2Id, Is_Policy_Checked__c = true);
            if (isFinalSubmission && String.isBlank(currentStatus)) {
                recordToUpdate.put('Policy_Check_Status__c', 'Submitted');
                recordToUpdate.put('Quote_Check_Submitted_Date__c', System.now());
            }
        } else if (sType == Account.SObjectType) {
            recordToUpdate = new Account(Id = recordId, Policy_Check_Comments__c = comments, Agent_2__c = a2Id);
            if (isFinalSubmission && String.isBlank(currentStatus)) {
                recordToUpdate.put('Policy_Check_Status__c', 'Submitted');
                recordToUpdate.put('Quote_Check_Submitted_Date__c', System.now());
            }
        } else if (sType == Opportunity.SObjectType) {
            recordToUpdate = new Opportunity(Id = recordId, Policy_Check_Comments__c = comments, Agent_2__c = a2Id);
            if (isFinalSubmission && String.isBlank(currentStatus)) {
                recordToUpdate.put('Policy_Check_Status__c', 'Submitted');
                recordToUpdate.put('Quote_Check_Submitted_Date__c', System.now());
            }
        }

        // ✅ CHANGED: fetch requirements and pass to redesigned generateHtmlSummary
        List<RequirementRow> existingRequirements = fetchRequirements(recordId, sType);
        String htmlTable = generateHtmlSummary(quoteRequests, existingRequirements);
        recordToUpdate.put('Policy_Check_Summary__c', htmlTable);
        update recordToUpdate;

        // Handle Deletions
        if (deletedIds != null && !deletedIds.isEmpty()) {
            delete [SELECT Id FROM Policy_Information__c WHERE Id IN :deletedIds];
        }

        // Upsert Policies (Deduplicated)
        Map<Id, Policy_Information__c> policiesToUpsertMap = new Map<Id, Policy_Information__c>();
        List<Policy_Information__c> newPoliciesToInsert = new List<Policy_Information__c>();
        
        List<Field_UW_Requirement__c> reqsToUpsert = new List<Field_UW_Requirement__c>();
        Map<QuoteSaveRequest, Field_UW_Requirement__c> reqToUwReqMap = new Map<QuoteSaveRequest, Field_UW_Requirement__c>();
        
        Id accountId;
        if (sType == Opportunity.SObjectType) accountId = [SELECT AccountId FROM Opportunity WHERE Id = :recordId].AccountId;

        for (QuoteSaveRequest req : quoteRequests) {
            Policy_Information__c p = req.policyRecord;
            
            // Skip if this is purely a Requirement row (no LOB/Carrier) OR if the ID is not a Policy ID (e.g. Lead ID)
            Boolean isRealPolicy = String.isNotBlank(p.Lines__c) || String.isNotBlank(p.Carrier__c);
            Boolean isPolicyId = (p.Id != null && p.Id.getSObjectType() == Policy_Information__c.SObjectType);
            
            if (!isRealPolicy) {
                // This is a Requirement
                Field_UW_Requirement__c uwReq = new Field_UW_Requirement__c();
                if (String.isNotBlank(req.requirementId)) {
                    uwReq.Id = req.requirementId;
                }
                
                if (sType == Lead.SObjectType) uwReq.Lead__c = recordId;
                else if (sType == Opportunity.SObjectType) uwReq.Opportunity__c = recordId;
                else if (sType == Account.SObjectType) uwReq.Account__c = recordId;
                
                if (isPolicyId) uwReq.Policy_Information__c = p.Id;
                
                uwReq.Requirement_Type__c = req.fileReqType;
                uwReq.Requirement_Item__c = req.fileReqItem;
                uwReq.Requirement_Details__c = req.fileDescription;
                uwReq.UW_Timing__c = req.uwTiming;
                uwReq.UW_Status__c = req.uwStatus;
                uwReq.Producer_Comments__c = req.producerComments;
                
                reqsToUpsert.add(uwReq);
                reqToUwReqMap.put(req, uwReq);
                continue;
            }

            // Apply Field UW Requirements Blocker Logic
            Boolean hasActivePreBind = false;
            Boolean hasActivePostBind = false;
            Boolean hasAnyReqs = false;
            for (QuoteSaveRequest innerReq : quoteRequests) {
                // Strictly use the ID to map requirements to this specific policy
                if (innerReq.policyRecord != null && p.Id != null && innerReq.policyRecord.Id == p.Id && String.isNotBlank(innerReq.uwStatus)) {
                    hasAnyReqs = true;
                    String reqStatus = innerReq.uwStatus;
                    String reqTiming = innerReq.uwTiming;
                    if (reqStatus == 'Open' || reqStatus == 'In Progress' || reqStatus == 'Rejected / Needs Revision') {
                        if (reqTiming == 'Pre-Bind') hasActivePreBind = true;
                        if (reqTiming == 'Post-Bind') hasActivePostBind = true;
                    }
                }
            }
            
            if (p.Policy_Status__c != 'Rejected' && p.Policy_Status__c != 'Rejected / Do Not Proceed') {
                if (p.Mismatch_Flag__c == true) {
                    // Manager manually overrode the status. Keep p.Policy_Status__c as is (which is Manager_Selected_Decision__c)
                    p.Override_User__c = UserInfo.getUserId();
                    p.Override_Time__c = System.now();
                } else {
                    // System-calculated logic
                    if (hasActivePreBind) {
                        p.Policy_Status__c = 'Pending - Pre-Bind Requirements Needed';
                    } else if (hasActivePostBind) {
                        p.Policy_Status__c = 'Approved - With Post-Bind Conditions';
                    } else {
                        // All requirements are completed/waived, or no requirements exist
                        // If no manager decision has been made, default to Submitted.
                        // Otherwise, keep the manager's decision.
                        if (String.isBlank(p.Policy_Status__c) || p.Policy_Status__c == 'Pending - Pre-Bind Requirements Needed' || p.Policy_Status__c == 'Pending - One or More Quotes Need Requirements') {
                            p.Policy_Status__c = 'Submitted';
                        }
                    }
                    
                    // Clear tracking fields if no mismatch
                    p.Override_User__c = null;
                    p.Override_Time__c = null;
                    p.Override_Reason__c = null;
                }
            }

            if (sType == Lead.SObjectType) p.Lead__c = recordId;
            else if (sType == Account.SObjectType) p.Account__c = recordId;
            else if (sType == Opportunity.SObjectType) {
                p.Opportunity__c = recordId;
                p.Account__c = accountId;
            }
            p.Policy_Type__c = 'Quote';
            p.Is_Quote__c = true;
            
            try { p.Agency_Fee__c = AgencyFeeHelper.applyWaiverDecision(p.Agency_Fee__c, p.Agency_Fee_Waiver_Decision__c); } catch(Exception e){}

            if (isPolicyId) {
                policiesToUpsertMap.put(p.Id, p);
            } else if (p.Id == null) {
                newPoliciesToInsert.add(p);
            }
        }
        
        if (!policiesToUpsertMap.isEmpty()) update policiesToUpsertMap.values();
        if (!newPoliciesToInsert.isEmpty()) insert newPoliciesToInsert;
        if (!reqsToUpsert.isEmpty()) upsert reqsToUpsert;
        
        List<Policy_Information__c> allPolicies = new List<Policy_Information__c>();
        allPolicies.addAll(policiesToUpsertMap.values());
        allPolicies.addAll(newPoliciesToInsert);

        // Calculate and update overall status using 7-step priority hierarchy
        // Only consider policies that are active (not explicitly 'Not Bound' and not replaced)
        List<Policy_Information__c> dbPolicies = [SELECT Id, Policy_Status__c, Policy_Bound__c, Replacement_Initiated__c, Is_Quote__c FROM Policy_Information__c WHERE (Lead__c = :recordId OR Account__c = :recordId OR Opportunity__c = :recordId) AND Is_Quote__c = true];
        List<Policy_Information__c> activePolicies = new List<Policy_Information__c>();
        for (Policy_Information__c dbP : dbPolicies) {
            if (dbP.Policy_Bound__c == 'No' || dbP.Replacement_Initiated__c == true) {
                continue; // Skip unbound or replaced quotes
            }
            if (policiesToUpsertMap.containsKey(dbP.Id)) {
                activePolicies.add(policiesToUpsertMap.get(dbP.Id));
            } else {
                activePolicies.add(dbP);
            }
        }
        for (Policy_Information__c newP : newPoliciesToInsert) {
            activePolicies.add(newP);
        }
        
        String overallStatus = calculateOverallStatus(activePolicies);
        Boolean wasBlank = String.isBlank(currentStatus);
        SObject statusUpdate;
        if (sType == Lead.SObjectType) statusUpdate = new Lead(Id = recordId, Policy_Check_Status__c = overallStatus);
        else if (sType == Account.SObjectType) statusUpdate = new Account(Id = recordId, Policy_Check_Status__c = overallStatus);
        else if (sType == Opportunity.SObjectType) statusUpdate = new Opportunity(Id = recordId, Policy_Check_Status__c = overallStatus);
        if (statusUpdate != null) update statusUpdate;

        // Auto-create Task for any Post-Bind approval
        createPostBindTasks(recordId, allPolicies);

        // Email and Notification triggers
        Boolean isStatusDecision = (overallStatus == 'Approved' || 
                                    overallStatus == 'Approved - With Post-Bind Conditions' || 
                                    overallStatus == 'Rejected' || 
                                    overallStatus == 'Partially Approved' || 
                                    overallStatus == 'Partially Approved - With Post-Bind Conditions' || 
                                    overallStatus == 'Rejected / Do Not Proceed' || 
                                    overallStatus == 'Pending - One or More Quotes Need Requirements' ||
                                    overallStatus == 'Need More Info');

        if (saveContext == 'ProducerSubmit5') {
            // Producer responded to Field UW Requirements. Notify Management.
            sendFieldUwResponseNotification(recordId);
            postConsolidatedChatter(recordId, quoteRequests, allPolicies);
        } else if (saveContext == 'AdminSubmit6' || isFinalSubmission) {
            // Management submitted Quote Check result. Notify Producer.
            if (sType == Lead.SObjectType) {
                if (overallStatus != currentStatus && isStatusDecision) {
                    sendQuoteCheckEmail(recordId, false); // Completion Email
                } else if (String.isBlank(currentStatus) || currentStatus == 'Submitted' || currentStatus == 'Open') {
                    sendQuoteCheckEmail(recordId, true);  // Submission Request Email
                }
            } else {
                Set<String> finalStatuses = new Set<String>{'Approved','Approved - With Post-Bind Conditions','Rejected','Partially Approved','Partially Approved - With Post-Bind Conditions','Rejected / Do Not Proceed'};
                if (finalStatuses.contains(overallStatus)) {
                    sendQuoteCheckEmail(recordId, false); // Completion Email
                } else if (wasBlank) {
                    sendQuoteCheckEmail(recordId, true);  // Submission Request Email
                }
            }
            
            // Chatter & Files for Quote Check Submission
            if (String.isNotBlank(chatterText) || String.isNotBlank(mentionUserId)) {
                postGeneralChatter(recordId, chatterText, mentionUserId);
            }
            postConsolidatedChatter(recordId, quoteRequests, allPolicies);
        } else if (saveContext == 'AdminSave5') {
            // Quiet save by Management. Do not send notifications or chatter.
            // (Files are still linked below)
        }

        // Chatter & Files
        if (!quoteRequests.isEmpty() || String.isNotBlank(chatterText)) {
            // Handle Base64 file uploads first
            for (QuoteSaveRequest req : quoteRequests) {
                if (req.base64Files != null && !req.base64Files.isEmpty()) {
                    if (req.fileIdsToAttach == null) req.fileIdsToAttach = new List<String>();
                    for (Base64File bf : req.base64Files) {
                        ContentVersion cv = new ContentVersion();
                        cv.Title = bf.fileName;
                        cv.PathOnClient = bf.fileName;
                        cv.VersionData = EncodingUtil.base64Decode(bf.base64);
                        cv.IsMajorVersion = true;
                        
                        // Apply metadata
                        if (String.isNotBlank(req.fileType)) cv.Type__c = req.fileType;
                        if (String.isNotBlank(req.fileReqType)) cv.Requirement_Type__c = req.fileReqType;
                        if (String.isNotBlank(req.fileReqItem)) cv.Requirement_Item__c = req.fileReqItem;
                        if (String.isNotBlank(req.fileDescription)) {
                            cv.Description = req.fileDescription;
                            cv.Requirement_Details__c = req.fileDescription;
                        }
                        if (String.isNotBlank(req.producerComments)) cv.Producer_Comments__c = req.producerComments;
                        insert cv;
                        
                        // Get the ContentDocumentId and add to the attach list
                        cv = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id];
                        req.fileIdsToAttach.add(cv.ContentDocumentId);
                    }
                }
            }

            Set<Id> docIds = new Set<Id>();
            for (QuoteSaveRequest req : quoteRequests) {
                if (req.fileIdsToAttach != null) {
                    for (String dId : req.fileIdsToAttach) docIds.add((Id)dId);
                }
            }
            
            if (!docIds.isEmpty()) {
                Map<Id, ContentVersion> latestVersions = new Map<Id, ContentVersion>();
                for (ContentVersion cv : [SELECT Id, ContentDocumentId, Description, Type__c, Requirement_Type__c, Requirement_Item__c, Requirement_Details__c, UW_Status__c, UW_Timing__c, Producer_Comments__c FROM ContentVersion WHERE ContentDocumentId IN :docIds AND IsLatest = true]) {
                    latestVersions.put(cv.ContentDocumentId, cv);
                }
                
                Map<Id, ContentVersion> dedupedUpdates = new Map<Id, ContentVersion>();
                for (QuoteSaveRequest req : quoteRequests) {
                    if (req.fileIdsToAttach != null) {
                        for (String dId : req.fileIdsToAttach) {
                            ContentVersion cv = latestVersions.get((Id)dId);
                            if (cv != null) {
                                if (String.isNotBlank(req.fileType)) cv.Type__c = req.fileType;
                                if (String.isNotBlank(req.fileReqType)) cv.Requirement_Type__c = req.fileReqType;
                                if (String.isNotBlank(req.fileReqItem)) cv.Requirement_Item__c = req.fileReqItem;
                                if (String.isNotBlank(req.fileDescription)) {
                                    cv.Description = req.fileDescription;
                                    cv.Requirement_Details__c = req.fileDescription;
                                }
                                if (String.isNotBlank(req.uwStatus)) cv.UW_Status__c = req.uwStatus;
                                if (String.isNotBlank(req.uwTiming)) cv.UW_Timing__c = req.uwTiming;
                                if (String.isNotBlank(req.producerComments)) cv.Producer_Comments__c = req.producerComments;
                                dedupedUpdates.put(cv.Id, cv);
                            }
                        }
                    }
                }
                if (!dedupedUpdates.isEmpty()) update dedupedUpdates.values();
            }

            // Link files to the specific Quote records or Requirements to enable Section 5 visibility
            List<ContentDocumentLink> cdlsToInsert = new List<ContentDocumentLink>();
            for (QuoteSaveRequest req : quoteRequests) {
                if (req.fileIdsToAttach != null) {
                    Id linkedEntityId = null;
                    if (reqToUwReqMap.containsKey(req) && reqToUwReqMap.get(req).Id != null) {
                        linkedEntityId = reqToUwReqMap.get(req).Id;
                    } else if (req.policyRecord != null && req.policyRecord.Id != null) {
                        linkedEntityId = req.policyRecord.Id;
                    }
                    
                    if (linkedEntityId != null) {
                        for (String docId : req.fileIdsToAttach) {
                            cdlsToInsert.add(new ContentDocumentLink(
                                LinkedEntityId = linkedEntityId,
                                ContentDocumentId = (Id)docId,
                                ShareType = 'V',
                                Visibility = 'AllUsers'
                            ));
                        }
                    }
                }
            }
            if (!cdlsToInsert.isEmpty()) {
                Database.insert(cdlsToInsert, false); // use false to skip if link already exists
            }

            if (String.isNotBlank(chatterText)) {
                postGeneralChatter(recordId, chatterText, mentionUserId);
            }
            if (!quoteRequests.isEmpty()) {
                // Post consolidated chatter synchronously for immediate visibility
                postConsolidatedChatter(recordId, quoteRequests, allPolicies);
            }
        }
    }

    // -----------------------------------------------------------------------
    // ✅ NEW: Fetch requirements (Policy_Information__c where Is_Quote__c = false)
    // -----------------------------------------------------------------------
   private static List<RequirementRow> fetchRequirements(
    Id recordId,
    SObjectType sType
) {
    List<RequirementRow> rows = new List<RequirementRow>();

    try {
        String whereClause = '';
        if (sType == Lead.SObjectType) {
            whereClause = 'Lead__c = :recordId';
        } else if (sType == Account.SObjectType) {
            whereClause = 'Account__c = :recordId';
        } else if (sType == Opportunity.SObjectType) {
            whereClause = 'Opportunity__c = :recordId';
        } else {
            return rows;
        }

        List<Field_UW_Requirement__c> reqs = Database.query(
            'SELECT Id, Requirement_Type__c, Requirement_Item__c, UW_Timing__c, ' +
            'Policy_Information__r.Lines__c, Policy_Information__r.Carrier__c, Policy_Information__r.Quote__c ' +
            'FROM Field_UW_Requirement__c ' +
            'WHERE ' + whereClause
        );

        for (Field_UW_Requirement__c r : reqs) {
            String appliesTo = '';
            if (r.Policy_Information__c != null) {
                if (String.isNotBlank(r.Policy_Information__r.Lines__c)) appliesTo += r.Policy_Information__r.Lines__c;
                if (String.isNotBlank(r.Policy_Information__r.Carrier__c)) {
                    appliesTo += (String.isNotBlank(appliesTo) ? ' - ' : '') + r.Policy_Information__r.Carrier__c;
                }
                if (String.isNotBlank(r.Policy_Information__r.Quote__c)) {
                    appliesTo += ' (' + r.Policy_Information__r.Quote__c + ')';
                }
            }
            if (String.isBlank(appliesTo)) appliesTo = '—';

            rows.add(
                new RequirementRow(
                    appliesTo,
                    r.UW_Timing__c,
                    r.Requirement_Type__c,
                    r.Requirement_Item__c
                )
            );
        }
    } catch (Exception e) {
        System.debug('fetchRequirements error: ' + e.getMessage());
    }

    return rows;
}
    // -----------------------------------------------------------------------
    // 7-Step Priority Hierarchy: calculates Overall Quote Check Status
    // -----------------------------------------------------------------------
    private static String calculateOverallStatus(List<Policy_Information__c> policies) {
        Set<String> statuses = new Set<String>();
        for (Policy_Information__c p : policies) {
            if (String.isNotBlank(p.Policy_Status__c)) statuses.add(p.Policy_Status__c);
        }
        // Priority 1: Any Pre-Bind pending blocks everything
        if (statuses.contains('Pending - Pre-Bind Requirements Needed'))
            return 'Pending - One or More Quotes Need Requirements';
        // Priority 2: All Rejected
        Boolean allRejected = true;
        for (Policy_Information__c p : policies)
            if (p.Policy_Status__c != 'Rejected') { allRejected = false; break; }
        if (allRejected) return 'Rejected / Do Not Proceed';
        // Priority 3: Any still Submitted
        if (statuses.contains('Submitted')) return 'Submitted';
        // Priority 4: Mix Rejected + Approved-With-Post-Bind
        if (statuses.contains('Rejected') && statuses.contains('Approved - With Post-Bind Conditions'))
            return 'Partially Approved - With Post-Bind Conditions';
        // Priority 5: Mix Rejected + Approved
        if (statuses.contains('Rejected') && statuses.contains('Approved'))
            return 'Partially Approved';
        // Priority 6: Any Post-Bind, no Rejected
        if (statuses.contains('Approved - With Post-Bind Conditions'))
            return 'Approved - With Post-Bind Conditions';
        // Priority 7: All Approved
        Boolean allApproved = true;
        for (Policy_Information__c p : policies)
            if (p.Policy_Status__c != 'Approved') { allApproved = false; break; }
        if (allApproved) return 'Approved';
        return 'Submitted';
    }

    // -----------------------------------------------------------------------
    // Producer -> Management Field UW Response Notification
    // -----------------------------------------------------------------------
    private static void sendFieldUwResponseNotification(Id recordId) {
        try {
            // Create a chatter post on the record to notify Management/Admin
            ConnectApi.FeedItemInput feedItemInput = new ConnectApi.FeedItemInput();
            ConnectApi.MessageBodyInput messageBodyInput = new ConnectApi.MessageBodyInput();
            messageBodyInput.messageSegments = new List<ConnectApi.MessageSegmentInput>();
            
            ConnectApi.TextSegmentInput textSegment = new ConnectApi.TextSegmentInput();
            textSegment.text = 'The Producer has responded to Field UW Requirements. Please review the updated comments and files in the Quote Check workspace.';
            messageBodyInput.messageSegments.add(textSegment);
            
            feedItemInput.body = messageBodyInput;
            feedItemInput.subjectId = recordId;
            
            if (!Test.isRunningTest()) {
                ConnectApi.ChatterFeeds.postFeedElement(Network.getNetworkId(), feedItemInput);
            }
        } catch (Exception e) {
            System.debug('Field UW Response Notification Error: ' + e.getMessage());
        }
    }

    // -----------------------------------------------------------------------
    // Auto-create a Task when a quote is Approved - With Post-Bind Conditions
    // -----------------------------------------------------------------------
    private static void createPostBindTasks(Id parentRecordId, List<Policy_Information__c> policies) {
        try {
            List<Task> tasksToInsert = new List<Task>();
            for (Policy_Information__c p : policies) {
                if (p.Policy_Status__c == 'Approved - With Post-Bind Conditions') {
                    Task t = new Task();
                    t.Subject = 'Post-Bind Follow-Up: ' + (p.Lines__c != null ? p.Lines__c : 'Policy') + ' - ' + (p.Carrier__c != null ? p.Carrier__c : 'Carrier');
                    t.Status = 'Not Started';
                    t.Priority = 'Normal';
                    t.WhatId = parentRecordId;
                    t.ActivityDate = Date.today().addDays(30);
                    t.Description = 'Post-bind requirement created for ' + (p.Lines__c != null ? p.Lines__c : '') + ' - ' + (p.Carrier__c != null ? p.Carrier__c : '') + '. Please review and complete the required follow-up item.';
                    tasksToInsert.add(t);
                }
            }
            if (!tasksToInsert.isEmpty()) insert tasksToInsert;
        } catch (Exception e) {
            System.debug('Post-Bind Task creation error: ' + e.getMessage());
        }
    }

    private static void postConsolidatedChatter(Id parentId, List<QuoteSaveRequest> requests, List<Policy_Information__c> upsertedPolicies) {
        try {
            ConnectApi.FeedItemInput feedItemInput = new ConnectApi.FeedItemInput();
            ConnectApi.MessageBodyInput messageBodyInput = new ConnectApi.MessageBodyInput();
            messageBodyInput.messageSegments = new List<ConnectApi.MessageSegmentInput>();

            // 1. Build the Message Body
            ConnectApi.TextSegmentInput textSegment = new ConnectApi.TextSegmentInput();
            textSegment.text = 'Policy Update Summary:\n\n';
            messageBodyInput.messageSegments.add(textSegment);

            for (QuoteSaveRequest req : requests) {
                String line = req.policyRecord.Lines__c;
                String carrier = req.policyRecord.Carrier__c;
                String status = req.policyRecord.Policy_Status__c;
                
                // Only post a summary row if it looks like an actual Quote/Policy record (not just a requirement/file update)
                if (String.isNotBlank(line) || String.isNotBlank(carrier)) {
                    ConnectApi.TextSegmentInput rowSegment = new ConnectApi.TextSegmentInput();
                    rowSegment.text = '• ' + (String.isNotBlank(line) ? line : 'N/A') + 
                                     ' (' + (String.isNotBlank(carrier) ? carrier : 'N/A') + '): ' + 
                                     (String.isNotBlank(status) ? status : 'Pending') + '\n';
                    messageBodyInput.messageSegments.add(rowSegment);
                }
                
                if (String.isNotBlank(req.chatterText)) {
                    ConnectApi.TextSegmentInput noteSegment = new ConnectApi.TextSegmentInput();
                    noteSegment.text = '  Note: ' + req.chatterText + '\n';
                    messageBodyInput.messageSegments.add(noteSegment);
                }
            }

            feedItemInput.body = messageBodyInput;
            feedItemInput.subjectId = parentId;

            // 2. Attach Files if any
            List<String> allFileIds = new List<String>();
            for (QuoteSaveRequest req : requests) {
                if (req.fileIdsToAttach != null) allFileIds.addAll(req.fileIdsToAttach);
            }

            if (!allFileIds.isEmpty()) {
                ConnectApi.BatchInput fileBatch = new ConnectApi.BatchInput(new List<ConnectApi.FeedElementInput>());
                ConnectApi.ContentCapabilityInput contentCapability = new ConnectApi.ContentCapabilityInput();
                // Note: ConnectApi usually only supports one main attachment via capabilities per post easily
                // For multiple files, we often rely on standard ContentDocumentLink which we already handle in handleSaveFileDetails
            }

            if (!Test.isRunningTest()) {
                ConnectApi.ChatterFeeds.postFeedElement(Network.getNetworkId(), feedItemInput);
            }
        } catch (Exception e) {
            System.debug('Chatter Sync Error: ' + e.getMessage());
        }
    }

    private static void postGeneralChatter(Id recordId, String text, String mentionId) {
        ConnectApi.FeedItemInput feedItemInput = new ConnectApi.FeedItemInput();
        ConnectApi.MessageBodyInput messageBodyInput = new ConnectApi.MessageBodyInput();
        messageBodyInput.messageSegments = new List<ConnectApi.MessageSegmentInput>();

        if (String.isNotBlank(mentionId)) {
            ConnectApi.MentionSegmentInput userMention = new ConnectApi.MentionSegmentInput();
            userMention.id = mentionId;
            messageBodyInput.messageSegments.add(userMention);
            
            ConnectApi.TextSegmentInput space = new ConnectApi.TextSegmentInput();
            space.text = ' ';
            messageBodyInput.messageSegments.add(space);
        }

        ConnectApi.TextSegmentInput textSegment = new ConnectApi.TextSegmentInput();
        textSegment.text = text;
        messageBodyInput.messageSegments.add(textSegment);

        feedItemInput.body = messageBodyInput;
        feedItemInput.subjectId = recordId;

        if (!Test.isRunningTest()) {
            ConnectApi.ChatterFeeds.postFeedElement(Network.getNetworkId(), feedItemInput);
        }
    }

    private static Decimal safeParseDecimal(String str) {
        if (String.isBlank(str)) return 0;
        try {
            String cleanStr = str.replaceAll('[^0-9\\.]', '');
            return Decimal.valueOf(cleanStr);
        } catch (Exception e) {
            return 0;
        }
    }

    private static String formatCurrency(Decimal val) {
        if (val == null) return '$0.00';
        Decimal scaled = val.setScale(2);
        String s = scaled.format();
        Integer dotIndex = s.indexOf('.');
        if (dotIndex == -1) {
            s += '.00';
        } else {
            String decimals = s.substring(dotIndex + 1);
            if (decimals.length() == 1) {
                s += '0';
            }
        }
        return '$' + s;
    }

    // ── Public: force-refresh Policy_Check_Summary__c with new card HTML ──
    @AuraEnabled
    public static void refreshPolicyCheckSummary(Id recordId) {
        if (recordId == null) return;
        SObjectType sType = recordId.getSObjectType();
        String whereClause = '';
        if      (sType == Lead.SObjectType)        whereClause = 'Lead__c = :recordId';
        else if (sType == Account.SObjectType)     whereClause = 'Account__c = :recordId';
        else if (sType == Opportunity.SObjectType) whereClause = 'Opportunity__c = :recordId';
        else return;

        List<Policy_Information__c> policies = Database.query(
            'SELECT Id, Carrier__c, Lines__c, Quote__c, Agency_State__c, Term__c, ' +
            'Effective_Date__c, Expiration_Date__c, Agency_Fee_Waiver_Request__c, ' +
            'Premium__c, Agency_Fee__c, Policy_Status__c, Additional_Comments__c ' +
            'FROM Policy_Information__c WHERE ' + whereClause + ' ORDER BY CreatedDate ASC'
        );

        List<QuoteSaveRequest> reqs = new List<QuoteSaveRequest>();
        for (Policy_Information__c p : policies) {
            QuoteSaveRequest r = new QuoteSaveRequest();
            r.policyRecord = p;
            reqs.add(r);
        }

        // ✅ CHANGED: also fetch requirements for the refresh
        List<RequirementRow> requirements = fetchRequirements(recordId, sType);
        String newHtml = generateHtmlSummary(reqs, requirements);
        SObject rec;
        if      (sType == Lead.SObjectType)        rec = new Lead(Id = recordId);
        else if (sType == Account.SObjectType)     rec = new Account(Id = recordId);
        else                                       rec = new Opportunity(Id = recordId);
        rec.put('Policy_Check_Summary__c', newHtml);
        update rec;
    }

    // -----------------------------------------------------------------------
    // ✅ REDESIGNED: generateHtmlSummary — now matches Image 2 layout
    //    Section 1: Field UW Requirements table
    //    Section 2: Management Review — Quote Check Status + decisions table
    //    Section 3: Totals bar (unchanged from before)
    // -----------------------------------------------------------------------
    private static String generateHtmlSummary(
    List<QuoteSaveRequest> quoteRequests,
    List<RequirementRow> requirements
) {

        Boolean waiverRequested = false;
        Decimal totalPremium      = 0;
        Decimal totalAgencyFees   = 0;
        Decimal annualizedPremium = 0;
        Integer realQuotesCount   = 0;

        // ── Collect quote rows ──
        List<Map<String, Object>> quoteRows = new List<Map<String, Object>>();

        for (QuoteSaveRequest req : quoteRequests) {
            Policy_Information__c p = req.policyRecord;
            if (p == null) continue;
            Boolean isRealPolicy = String.isNotBlank(p.Lines__c) || String.isNotBlank(p.Carrier__c);
            if (!isRealPolicy) continue;

            realQuotesCount++;
            if (p.Agency_Fee_Waiver_Request__c == true) waiverRequested = true;

            Decimal prem = 0;
            if (p.Premium__c != null) {
                prem = safeParseDecimal(p.Premium__c);
                totalPremium += prem;
                Decimal multiplier = (p.Term__c != null && p.Term__c.containsIgnoreCase('6')) ? 2 : 1;
                annualizedPremium += prem * multiplier;
            }
            Decimal fee = 0;
            if (p.Agency_Fee__c != null) {
                fee = p.Agency_Fee__c;
                totalAgencyFees += fee;
            }

            // LOB icon
            String rawLine = p.Lines__c != null ? p.Lines__c : '';
            String lineStr = rawLine.replaceAll('[^a-zA-Z0-9\\s/\\-&]', '').trim();
            String lineUpper = lineStr.toUpperCase();
            String icons8Name = 'document';
            if (lineUpper.contains('AUTO') || lineUpper.contains('VEHICLE') || lineUpper == 'AUTO') {
                icons8Name = 'car';
            } else if (lineUpper.contains('HOME') || lineUpper.contains('PROPERTY') || lineUpper.contains('RENTER') || lineUpper.contains('CONDO') || lineUpper == 'HOME') {
                icons8Name = 'home';
            } else if (lineUpper.contains('RV')) {
                icons8Name = 'camper-vehicle';
            } else if (lineUpper.contains('BOAT') || lineUpper.contains('WATERCRAFT')) {
                icons8Name = 'boat';
            } else if (lineUpper.contains('MOTORCYCLE')) {
                icons8Name = 'motorcycle';
            } else if (lineUpper.contains('COMMERCIAL') || lineUpper.contains('BUSINESS')) {
                icons8Name = 'company';
            } else if (lineUpper.contains('UMBRELLA')) {
                icons8Name = 'umbrella';
            } else if (lineUpper.contains('FLOOD')) {
                icons8Name = 'water';
            } else if (lineUpper.contains('HEALTH') || lineUpper.contains('LIFE') || lineUpper.contains('MEDICAL')) {
                icons8Name = 'heart-with-pulse';
            } else if (lineUpper.contains('D&O') || lineUpper.contains('E&O') || lineUpper.contains('LIABILITY')) {
                icons8Name = 'scales--v1';
            }

            String lineIcon = '<img src="https://img.icons8.com/ios/50/0176d3/' + icons8Name + '.png" width="24" height="24" alt="' + lineUpper + '" style="display:block;" />';
            // Status badge colors
            String stat  = p.Policy_Status__c != null ? p.Policy_Status__c : 'Submitted';
            String statL = stat.toLowerCase();
            String statusColor  = '#374151';
            String statusBg     = '#f3f4f6';
            String statusBorder = '#d1d5db';
            if (statL.contains('approved') && !statL.contains('partial')) {
                statusColor = '#059669'; statusBg = '#ecfdf5'; statusBorder = '#059669';
            } else if (statL.contains('partial')) {
                statusColor = '#d97706'; statusBg = '#fffbeb'; statusBorder = '#d97706';
            } else if (statL.contains('pending') || statL.contains('info') || statL.contains('submitted')) {
                statusColor = '#d97706'; statusBg = '#fffbeb'; statusBorder = '#d97706';
            } else if (statL.contains('rejected') || statL.contains('not proceed')) {
                statusColor = '#dc2626'; statusBg = '#fef2f2'; statusBorder = '#dc2626';
            }

            quoteRows.add(new Map<String, Object>{
                'line'        => lineStr,
                'lineIcon'    => lineIcon,
                'carrier'     => p.Carrier__c   != null ? p.Carrier__c   : '—',
                'quoteNum'    => p.Quote__c      != null ? p.Quote__c      : '—',
                'term'        => p.Term__c       != null ? p.Term__c       : '—',
                'stat'        => stat,
                'statusColor' => statusColor,
                'statusBg'    => statusBg,
                'statusBorder'=> statusBorder,
                'prem'        => prem,
                'fee'         => fee,
                'total'       => prem + fee,
                'comments'    => p.Additional_Comments__c != null ? p.Additional_Comments__c : '',
                'waiver'      => (p.Agency_Fee_Waiver_Request__c == true) ? 'Yes' : 'No',
                'effDate'     => p.Effective_Date__c != null
                    ? (String.valueOf(p.Effective_Date__c.month()).leftPad(2,'0') + '-' +
                       String.valueOf(p.Effective_Date__c.day()).leftPad(2,'0') + '-' +
                       p.Effective_Date__c.year()) : '—',
                'expDate'     => p.Expiration_Date__c != null
                    ? (String.valueOf(p.Expiration_Date__c.month()).leftPad(2,'0') + '-' +
                       String.valueOf(p.Expiration_Date__c.day()).leftPad(2,'0') + '-' +
                       p.Expiration_Date__c.year()) : '—'
            });
        }

        // ── Compute overall status from quote rows ──
        String overallStatus = 'Submitted';
        if (!quoteRows.isEmpty()) {
            List<Policy_Information__c> pList = new List<Policy_Information__c>();
            for (QuoteSaveRequest req : quoteRequests) {
                if (req.policyRecord != null &&
                    (String.isNotBlank(req.policyRecord.Lines__c) || String.isNotBlank(req.policyRecord.Carrier__c))) {
                    pList.add(req.policyRecord);
                }
            }
            if (!pList.isEmpty()) overallStatus = calculateOverallStatus(pList);
        }

        // Overall status badge colors
        String ovStatL  = overallStatus.toLowerCase();
        String ovColor  = '#d97706'; String ovBg = '#fffbeb'; String ovBorder = '#fcd34d';
        if (ovStatL.contains('approved') && !ovStatL.contains('partial')) {
            ovColor = '#059669'; ovBg = '#ecfdf5'; ovBorder = '#6ee7b7';
        } else if (ovStatL.contains('partial')) {
            ovColor = '#d97706'; ovBg = '#fffbeb'; ovBorder = '#fcd34d';
        } else if (ovStatL.contains('rejected') || ovStatL.contains('not proceed')) {
            ovColor = '#dc2626'; ovBg = '#fef2f2'; ovBorder = '#fca5a5';
        }

        // ════════════════════════════════════════════════════════
        // BUILD HTML
        // ════════════════════════════════════════════════════════
        String html = '<div style="font-family: Arial, Helvetica, sans-serif; width: 100%; margin: 0 auto;">';

        // ── Waiver banner ──
        if (waiverRequested) {
            html += '<div style="color:#92400e; font-weight:700; margin-bottom:16px; border:1px solid #fcd34d; background-color:#fef3c7; padding:10px 14px; border-radius:6px; text-align:center; font-size:13px;">AGENCY FEE WAIVER REQUESTED</div>';
        }

        // ════════════════════════════════════════════════
        // SECTION 1: Field UW Requirements table
        // ════════════════════════════════════════════════
        html += '<div style="background:#ffffff; border:1px solid #e2e8f0; border-radius:12px; padding:20px 24px; margin-bottom:16px;">';
        html += '<h2 style="font-size:15px; font-weight:700; color:#1e293b; margin:0 0 14px 0; padding-bottom:10px; border-bottom:2px solid #e2e8f0;">Field UW Requirements</h2>';

        if (requirements == null || requirements.isEmpty()) {
            html += '<div style="text-align:center; padding:20px; color:#94a3b8; font-size:12px;">No Field UW Requirements submitted.</div>';
        } else {
            html += '<table style="width:100%; border-collapse:collapse; font-size:12px;">';
            // Header
            html += '<thead><tr style="background:#f8fafc;">';
            for (String h : new String[]{ 'Applies To', 'Timing', 'Requirement Type', 'Requirement Item' }) {
                html += '<th style="padding:10px 12px; text-align:left; font-size:10px; font-weight:700; color:#64748b; text-transform:uppercase; letter-spacing:0.05em; border-bottom:1px solid #e2e8f0;">' + h + '</th>';
            }
            html += '</tr></thead><tbody>';

            Boolean altRow = false;
            for (RequirementRow req : requirements) {
                String rowBg = altRow ? '#f8fafc' : '#ffffff';
                altRow = !altRow;

                // Timing badge
                String timing      = req.timing != null ?  req.timing : '—';
                String timingColor = '#374151'; String timingBg = '#f3f4f6'; String timingBorder = '#d1d5db';
                String timL = timing.toLowerCase();
                if      (timL.contains('pre'))  { timingColor = '#92400e'; timingBg = '#fef3c7'; timingBorder = '#fcd34d'; }
                else if (timL.contains('post')) { timingColor = '#1d4ed8'; timingBg = '#eff6ff'; timingBorder = '#93c5fd'; }

              String appliesTo = req.appliesTo;
                
               
                html += '<tr style="background:' + rowBg + '; border-bottom:1px solid #f1f5f9;">';
                html += '<td style="padding:10px 12px; color:#1e293b; font-weight:600;">' + appliesTo + '</td>';
                html += '<td style="padding:10px 12px;">';
                html += '<span style="display:inline-block; background:' + timingBg + '; color:' + timingColor + '; border:1px solid ' + timingBorder + '; border-radius:4px; font-size:10px; font-weight:700; padding:3px 8px; white-space:nowrap;">' + timing + '</span>';
                html += '</td>';
                html += '<td style="padding:10px 12px; color:#374151;">' + (req.requirementType!= null ? req.requirementType: '—') + '</td>';
                html += '<td style="padding:10px 12px; color:#374151;">' + (req.requirementItem  != null ? req.requirementItem  : '—') + '</td>';
                html += '</tr>';
            }
            html += '</tbody></table>';
        }
        html += '</div>'; // end Section 1

        // ════════════════════════════════════════════════
        // SECTION 2: Management Review
        // ════════════════════════════════════════════════
        html += '<div style="background:#ffffff; border:1px solid #e2e8f0; border-radius:12px; padding:20px 24px; margin-bottom:16px;">';
        html += '<h2 style="font-size:15px; font-weight:700; color:#1e293b; margin:0 0 14px 0; padding-bottom:10px; border-bottom:2px solid #e2e8f0;">Management Review</h2>';

        // Overall status pill
        html += '<div style="background:' + ovBg + '; border:1px solid ' + ovBorder + '; border-radius:8px; padding:12px 16px; margin-bottom:18px; display:flex; align-items:center; gap:12px;">';
        html += '<span style="font-size:12px; font-weight:700; color:#374151;">Quote Check Status</span>';
        html += '<span style="font-size:12px; font-weight:700; color:' + ovColor + ';">' + overallStatus + '</span>';
        html += '</div>';

        // Individual Quote Decisions label
        html += '<div style="font-size:11px; font-weight:700; color:#64748b; margin-bottom:10px; text-transform:uppercase; letter-spacing:0.05em;">Individual Quote Decisions</div>';

        // Decisions table
        html += '<table style="width:100%; border-collapse:collapse; font-size:12px; border:1px solid #e2e8f0; border-radius:8px; overflow:hidden;">';
        html += '<thead><tr style="background:#f8fafc;">';
        html += '<th style="padding:12px 16px; text-align:left; font-size:10px; font-weight:700; color:#64748b; text-transform:uppercase; letter-spacing:0.05em; border-bottom:1px solid #e2e8f0; width:35%;">Policy / Quote</th>';
        html += '<th style="padding:12px 16px; text-align:left; font-size:10px; font-weight:700; color:#64748b; text-transform:uppercase; letter-spacing:0.05em; border-bottom:1px solid #e2e8f0; width:30%;">Decision</th>';
        html += '<th style="padding:12px 16px; text-align:left; font-size:10px; font-weight:700; color:#64748b; text-transform:uppercase; letter-spacing:0.05em; border-bottom:1px solid #e2e8f0; width:35%;">Management Comments</th>';
        html += '</tr></thead><tbody>';

        if (quoteRows.isEmpty()) {
            html += '<tr><td colspan="3" style="padding:20px; text-align:center; color:#94a3b8; font-size:12px;">No quotes submitted.</td></tr>';
        } else {
            Boolean altRow2 = false;
            for (Map<String, Object> row : quoteRows) {
                String rowBg2    = altRow2 ? '#f8fafc' : '#ffffff';
                altRow2 = !altRow2;
                String li2       = String.valueOf(row.get('lineIcon'));
                String ln2       = String.valueOf(row.get('line'));
                String ca2       = String.valueOf(row.get('carrier'));
                String qn2       = String.valueOf(row.get('quoteNum'));
                String st2       = String.valueOf(row.get('stat'));
                String sc2       = String.valueOf(row.get('statusColor'));
                String sb2       = String.valueOf(row.get('statusBg'));
                String sbr2      = String.valueOf(row.get('statusBorder'));
                String cm2       = String.valueOf(row.get('comments'));

                html += '<tr style="background:' + rowBg2 + '; border-bottom:1px solid #f1f5f9;">';

                // Policy / Quote cell
                html += '<td style="padding:14px 16px; vertical-align:top;">';
                html += '  <div style="display:flex; align-items:center; gap:8px; margin-bottom:4px;">';
                html += '    <span style="color:#0176d3; font-size:15px;">' + li2 + '</span>';
                html += '    <span style="font-weight:700; color:#0176d3; font-size:13px;">' + ln2 + '</span>';
                html += '  </div>';
                html += '  <div style="font-size:11px; color:#64748b; margin-left:24px;">' + ca2 + '</div>';
                if (!qn2.equals('—')) {
                    html += '  <div style="font-size:10px; color:#94a3b8; margin-left:24px;">' + qn2 + '</div>';
                }
                html += '</td>';

                // Decision cell — colored badge
                html += '<td style="padding:14px 16px; vertical-align:top;">';
                html += '  <span style="display:inline-block; background:' + sb2 + '; color:' + sc2 + '; border:1px solid ' + sbr2 + '; border-radius:5px; font-size:11px; font-weight:700; padding:5px 12px;">' + st2 + '</span>';
                html += '</td>';

                // Management Comments cell
                html += '<td style="padding:14px 16px; vertical-align:top;">';
                if (String.isNotBlank(cm2)) {
                    html += '<div style="font-size:12px; color:#374151; line-height:1.5;">' + cm2 + '</div>';
                } else {
                    html += '<div style="font-size:11px; color:#cbd5e1; font-style:italic;">No comments</div>';
                }
                html += '</td>';
                html += '</tr>';
            }
        }
        html += '</tbody></table>';
        html += '</div>'; // end Section 2

        // ════════════════════════════════════════════════
        // SECTION 3: Totals bar (removed per user request)
        // ════════════════════════════════════════════════

        html += '</div>'; // outer wrapper
        return html;
    }

    private static void sendQuoteCheckEmail(Id recordId, Boolean isRequest) {
        try {
            SObjectType sType = recordId.getSObjectType();
            String templateName = '';
            if (sType == Lead.SObjectType) {
                templateName = isRequest ? 'Producer_Submission_Request_Lead' : 'Quote_Check_Completion_Lead';
            } else if (sType == Opportunity.SObjectType) {
                templateName = isRequest ? 'Policy_Check_Request_Opportunity' : 'Policy_Check_Completed_Opportunity';
            } else {
                return;
            }

            EmailTemplate et = [SELECT Id FROM EmailTemplate WHERE DeveloperName = :templateName LIMIT 1];
            
            Id ownerId;
            String ownerEmail = '';
            if (sType == Lead.SObjectType) {
                Lead l = [SELECT OwnerId, Owner.Email FROM Lead WHERE Id = :recordId LIMIT 1];
                ownerId = l.OwnerId;
                ownerEmail = l.Owner.Email;
            } else {
                Opportunity opp = [SELECT OwnerId, Owner.Email FROM Opportunity WHERE Id = :recordId LIMIT 1];
                ownerId = opp.OwnerId;
                ownerEmail = opp.Owner.Email;
            }
            
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setTemplateId(et.Id);
            mail.setSaveAsActivity(false);
            
            if (sType == Lead.SObjectType) {
                mail.setTargetObjectId(recordId);
                mail.setWhatId(null);
                mail.setTreatTargetObjectAsRecipient(false);
                
                if (isRequest) {
                    String labelEmail = System.Label.Policy_Check_Email;
                    if (String.isNotBlank(labelEmail)) {
                        mail.setToAddresses(new String[]{ labelEmail });
                    }
                } else {
                    if (String.isNotBlank(ownerEmail)) {
                        mail.setToAddresses(new String[]{ ownerEmail });
                    }
                }
            } else {
                mail.setTargetObjectId(ownerId);
                mail.setWhatId(recordId);
                mail.setTreatTargetObjectAsRecipient(true);
                
                if (isRequest) {
                    String labelEmail = System.Label.Policy_Check_Email;
                    if (String.isNotBlank(labelEmail)) {
                        mail.setToAddresses(new String[]{ labelEmail });
                    }
                }
            }
            
            if (!Test.isRunningTest()) {
                Messaging.sendEmail(new Messaging.SingleEmailMessage[]{ mail });
            }
        } catch(Exception e) {
            System.debug('sendQuoteCheckEmail error: ' + e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<User> getAgent2Options() {
        return [SELECT Id, Name, Email FROM User 
                WHERE IsActive = true 
                AND UserType = 'Standard' 
                AND (NOT Name LIKE '%Integration%') 
                AND (NOT Name LIKE '%Security%') 
                AND (NOT Name LIKE '%SalesforceIQ%')
                ORDER BY Name];
    }

    @AuraEnabled(cacheable=true)
    public static List<Carrier__c> getCarrierOptions() {
        return [SELECT Id, Company_Name__c, Quote_Specific_Website__c FROM Carrier__c ORDER BY Company_Name__c];
    }

    @AuraEnabled(cacheable=true)
    public static List<RequirementLibraryHelper.LibraryItem> getCommonRequirements(String reqType) {
        return RequirementLibraryHelper.getCommonItems(reqType);
    }

    @AuraEnabled(cacheable=true)
    public static List<RequirementLibraryHelper.LibraryItem> searchRequirementLibrary(String keyword) {
        return RequirementLibraryHelper.searchLibrary(keyword);
    }

    // -----------------------------------------------------------------------
    // Producer Submission Email: notifies management when producer clicks Submit
    // -----------------------------------------------------------------------
    @AuraEnabled
    public static void sendProducerSubmissionEmail(Id recordId) {
        if (recordId == null) return;
        try {
            SObjectType sType = recordId.getSObjectType();
            String templateDeveloperName = '';

            if (sType == Lead.SObjectType) {
                // Return early for Lead. The request email is now sent inside the saveQuoteCheckWithPolicies process,
                // matching the Policy Check flow and avoiding duplicate emails.
                return;
            } else if (sType == Opportunity.SObjectType) {
                templateDeveloperName = 'Producer_Submission_Request_Opportunity';
            } else {
                return;
            }

            // Look up the email template
            List<EmailTemplate> templates = [
                SELECT Id FROM EmailTemplate WHERE DeveloperName = :templateDeveloperName LIMIT 1
            ];
            if (templates.isEmpty()) {
                System.debug('Producer submission email template not found: ' + templateDeveloperName);
                return;
            }

            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setTemplateId(templates[0].Id);
            mail.setSaveAsActivity(false);

            // Determine recipient list (Owner + Management Team)
            List<String> toAddresses = new List<String>();
            
            // Get Owner Email
            Id ownerId;
            String ownerEmail = '';
            if (sType == Lead.SObjectType) {
                Lead l = [SELECT OwnerId, Owner.Email FROM Lead WHERE Id = :recordId LIMIT 1];
                ownerId = l.OwnerId;
                ownerEmail = l.Owner.Email;
            } else {
                Opportunity opp = [SELECT OwnerId, Owner.Email FROM Opportunity WHERE Id = :recordId LIMIT 1];
                ownerId = opp.OwnerId;
                ownerEmail = opp.Owner.Email;
            }
            if (String.isNotBlank(ownerEmail)) {
                toAddresses.add(ownerEmail);
            }

            // Get Management Team Email
            String mgmtEmail = '';
            try {
                mgmtEmail = System.Label.Policy_Check_Email;
            } catch (Exception labelEx) {}
            if (String.isNotBlank(mgmtEmail)) {
                toAddresses.add(mgmtEmail);
            }

            mail.setToAddresses(toAddresses);

            // Handle Lead vs Opportunity targeting rules in Salesforce
            if (sType == Lead.SObjectType) {
                mail.setTargetObjectId(recordId);
                mail.setWhatId(null);
                mail.setTreatTargetObjectAsRecipient(false);
            } else {
                mail.setTargetObjectId(ownerId);
                mail.setWhatId(recordId);
                mail.setTreatTargetObjectAsRecipient(true);
            }

            if (!Test.isRunningTest()) {
                Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ mail });
            }
        } catch (Exception e) {
            System.debug('sendProducerSubmissionEmail error: ' + e.getMessage());
            throw new AuraHandledException('Failed to send email: ' + e.getMessage());
        }
    }
}