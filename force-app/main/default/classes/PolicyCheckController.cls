public with sharing class PolicyCheckController {
    
    // 1. Picklist Options
    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getPolicyStatusOptions() {
        List<Map<String, String>> options = new List<Map<String, String>>();
        try {
            Schema.DescribeFieldResult fieldResult = Lead.Policy_Check_Status__c.getDescribe();
            List<Schema.PicklistEntry> ple = fieldResult.getPicklistValues();
            for (Schema.PicklistEntry f : ple) {
                options.add(new Map<String, String>{
                    'label' => f.getLabel(),
                    'value' => f.getValue()
                });
            }
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
        return options;
    }
    
    // 2. Data Wrappers
    public class PolicyCheckWrapper {
        @AuraEnabled public SObject recordDetail { get; set; } 
        @AuraEnabled public List<String> leadLinesList { get; set; }
        @AuraEnabled public List<Policy_Information__c> policies { get; set; }
        @AuraEnabled public Boolean isSystemAdmin { get; set; }
        @AuraEnabled public Map<Id, List<ContentDocumentLink>> policyFilesMap { get; set; } 
        @AuraEnabled public Map<Id, List<FeedItem>> policyChatterMap { get; set; } 
    }
    
    public class PolicySaveRequest {
        @AuraEnabled public Policy_Information__c policyRecord { get; set; }
        @AuraEnabled public String chatterText { get; set; }
        @AuraEnabled public String mentionUserId { get; set; }
        @AuraEnabled public String fileIdToAttach { get; set; } 
    }

    // --- NEW: Special Wrapper for Visualforce PDF Iteration ---
    public class PdfPolicyWrapper {
        public Policy_Information__c policy { get; set; }
        public List<FeedItem> feeds { get; set; }
        public List<ContentDocumentLink> files { get; set; }
        public Boolean getHasFeeds() { return feeds != null && !feeds.isEmpty(); }
        public Boolean getHasFiles() { return files != null && !files.isEmpty(); }
    }
    
    public PolicyCheckWrapper wrapperObj { get; set; }
    public List<PdfPolicyWrapper> pdfPolicies { get; set; } 
    public String recordName { get; set; }
    public String recordAddress { get; set; }
    public String ownerName { get; set; }
    public String ownerEmail { get; set; }
    public String agent2Name { get; set; }
    public String agent2Email { get; set; }
    public String mgtComments { get; set; }
    
    // --- CONSTRUCTOR FOR VISUALFORCE PDF ---
    public PolicyCheckController() {
        Id recId = ApexPages.currentPage().getParameters().get('id');
        if (recId != null) {
            wrapperObj = getPolicyCheckData(recId);
            
            SObjectType sType = recId.getSObjectType();
            if (sType == Lead.SObjectType) {
                Lead l = (Lead)wrapperObj.recordDetail;
                recordName = l.Name;
                recordAddress = l.Street + ', ' + l.City + ', ' + l.State + ' ' + l.PostalCode;
                ownerName = l.Owner.Name;
                ownerEmail = l.Owner.Email;
                agent2Name = (l.Agent_2__r != null) ? l.Agent_2__r.Name : '';
                agent2Email = (l.Agent_2__r != null) ? l.Agent_2__r.Email : '';
                mgtComments = l.Policy_Check_Comments__c;
            } else if (sType == Account.SObjectType) {
                Account a = (Account)wrapperObj.recordDetail;
                recordName = a.Name;
                recordAddress = a.Address_Property__Street__s + ', ' + a.Address_Property__City__s + ', ' + a.Address_Property__StateCode__s + ' ' + a.Address_Property__PostalCode__s;
                ownerName = a.Owner.Name;
                ownerEmail = a.Owner.Email;
                agent2Name = (a.Agent_2__r != null) ? a.Agent_2__r.Name : '';
                agent2Email = (a.Agent_2__r != null) ? a.Agent_2__r.Email : '';
                mgtComments = a.Policy_Check_Comments__c;
            } else if (sType == Opportunity.SObjectType) {
                Opportunity o = (Opportunity)wrapperObj.recordDetail;
                recordName = o.Account.Name;
                recordAddress = o.Account.Address_Property__Street__s + ', ' + o.Account.Address_Property__City__s + ', ' + o.Account.Address_Property__StateCode__s + ' ' + o.Account.Address_Property__PostalCode__s;
                ownerName = o.Owner.Name;
                ownerEmail = o.Owner.Email;
                agent2Name = (o.Agent_2__r != null) ? o.Agent_2__r.Name : '';
                agent2Email = (o.Agent_2__r != null) ? o.Agent_2__r.Email : '';
                mgtComments = o.Policy_Check_Comments__c;
            }

            // POPULATE THE PDF WRAPPER LIST
            pdfPolicies = new List<PdfPolicyWrapper>();
            for (Policy_Information__c p : wrapperObj.policies) {
                PdfPolicyWrapper ppw = new PdfPolicyWrapper();
                ppw.policy = p;
                ppw.feeds = wrapperObj.policyChatterMap.containsKey(p.Id) ? wrapperObj.policyChatterMap.get(p.Id) : new List<FeedItem>();
                ppw.files = wrapperObj.policyFilesMap.containsKey(p.Id) ? wrapperObj.policyFilesMap.get(p.Id) : new List<ContentDocumentLink>();
                pdfPolicies.add(ppw);
            }
        }
    }
    
    // 3. Main Load Method
    @AuraEnabled(cacheable=true)
    public static PolicyCheckWrapper getPolicyCheckData(Id recordId) {
        if (recordId == null) {
            throw new AuraHandledException('Record Id is required.');
        }
        
        PolicyCheckWrapper w = new PolicyCheckWrapper();
        
        Profile p = [SELECT Name FROM Profile WHERE Id = :UserInfo.getProfileId() LIMIT 1];
        w.isSystemAdmin = (p.Name == 'System Administrator' && p.Name != 'RiskPro');
        
        SObjectType sType = recordId.getSObjectType();
        
        if (sType == Lead.SObjectType) {
            Lead l = [SELECT Id, Name, OwnerId, Owner.Name, Owner.Email, Status, Street, City, State, PostalCode, Policy_Check_Status__c, Agent_2__c, Agent_2__r.Name, Agent_2__r.Email, Policy_Check_Comments__c, Personal_Lines__c, Commercial_Lines__c FROM Lead WHERE Id = :recordId LIMIT 1];
            w.recordDetail = l;
            List<String> finalLines = new List<String>();
            if (l.Personal_Lines__c != null) finalLines.addAll(l.Personal_Lines__c.split(';'));
            if (l.Commercial_Lines__c != null) finalLines.addAll(l.Commercial_Lines__c.split(';'));
            w.leadLinesList = finalLines;
        } 
        else if (sType == Account.SObjectType) {
            Account acc = [SELECT Id, Name, OwnerId, Owner.Name, Owner.Email, Address_Property__Street__s, Address_Property__City__s, Address_Property__StateCode__s, Address_Property__PostalCode__s, Policy_Check_Status__c, Agent_2__c, Agent_2__r.Name, Agent_2__r.Email, Policy_Check_Comments__c FROM Account WHERE Id = :recordId LIMIT 1];
            w.recordDetail = acc;
            w.leadLinesList = new List<String>();
        } 
        else if (sType == Opportunity.SObjectType) {
            Opportunity opp = [SELECT Id, Name, AccountId, Account.Name, OwnerId, Owner.Name, Owner.Email, Account.Address_Property__Street__s, Account.Address_Property__City__s, Account.Address_Property__StateCode__s, Account.Address_Property__PostalCode__s, Policy_Check_Status__c, Agent_2__c, Agent_2__r.Name, Agent_2__r.Email, Policy_Check_Comments__c FROM Opportunity WHERE Id = :recordId LIMIT 1];
            w.recordDetail = opp;
            w.leadLinesList = new List<String>();
        }
        
        String query = 'SELECT Id, Carrier__c, Lines__c, Quote__c, Premium__c, Agency_Fee__c, Agency_Fee_Waiver_Request__c, Agency_Fee_Waiver_Decision__c, Waiver_Reason__c, Waiver_Comment__c, Effective_Date__c, Policy_Status__c, Additional_Comments__c, Term__c, Expiration_Date__c FROM Policy_Information__c WHERE Policy_Type__c != \'NBC\' AND ';
        
        if (sType == Lead.SObjectType) query += 'Lead__c = :recordId';
        else if (sType == Account.SObjectType) query += 'Account__c = :recordId';
        else if (sType == Opportunity.SObjectType) query += 'Opportunity__c = :recordId';
        
        query += ' ORDER BY CreatedDate ASC';
        
        w.policies = Database.query(query);
        
        Set<Id> policyIds = new Set<Id>();
        for (Policy_Information__c pInfo : w.policies) {
            policyIds.add(pInfo.Id);
        }
        
        w.policyChatterMap = new Map<Id, List<FeedItem>>();
        w.policyFilesMap   = new Map<Id, List<ContentDocumentLink>>();
        
        if (!policyIds.isEmpty()) {
            
            // UPDATED: Removed Type filters to ensure we catch ALL posts, and added Title to get File Names
            List<FeedItem> feeds = [
                SELECT Id, ParentId, Body, Title, CreatedDate, CreatedBy.Name, Type
                FROM FeedItem
                WHERE ParentId IN :policyIds
                ORDER BY CreatedDate DESC
            ];
            
            for (FeedItem f : feeds) {
                if (!w.policyChatterMap.containsKey(f.ParentId)) {
                    w.policyChatterMap.put(f.ParentId, new List<FeedItem>());
                }
                w.policyChatterMap.get(f.ParentId).add(f);
            }
            
            List<ContentDocumentLink> files = [
                SELECT LinkedEntityId, ContentDocumentId, ContentDocument.Title, ContentDocument.FileExtension, ContentDocument.CreatedDate
                FROM ContentDocumentLink
                WHERE LinkedEntityId IN :policyIds
                ORDER BY ContentDocument.CreatedDate DESC
            ];
            
            for (ContentDocumentLink cdl : files) {
                if (!w.policyFilesMap.containsKey(cdl.LinkedEntityId)) {
                    w.policyFilesMap.put(cdl.LinkedEntityId, new List<ContentDocumentLink>());
                }
                w.policyFilesMap.get(cdl.LinkedEntityId).add(cdl);
            }
        }
        
        return w;
    }
    
    // 4. Main Save Method
    @AuraEnabled
    public static void savePolicyCheckWithPolicies( Id recordId, String comments, String agent2Id, List<PolicySaveRequest> policyRequests, List<Id> deletedPolicyIds, Boolean isFinalSubmission ) {
        if (recordId == null) throw new AuraHandledException('Record ID is missing.');
        SObjectType sType = recordId.getSObjectType();
        SObject recordToUpdate;
        String policyCheckStatus = '';
        String ownerId = '';
        String recordName = '';
        
        if (sType == Lead.SObjectType) {
            Lead oldLead = [ SELECT Name, OwnerId, Policy_Check_Status__c, Status FROM Lead WHERE Id = :recordId LIMIT 1 ];
            policyCheckStatus = oldLead.Policy_Check_Status__c;
            ownerId = oldLead.OwnerId;
            recordName = oldLead.Name;
            recordToUpdate = new Lead( Id = recordId, Policy_Check_Comments__c = comments, Agent_2__c = agent2Id, Is_Policy_Checked__c = true );
            if (isFinalSubmission && String.isBlank(policyCheckStatus)) {
                recordToUpdate.put('Policy_Check_Status__c', 'Submitted');
                if (oldLead.Status != 'Unqualified') recordToUpdate.put('Status', 'Unqualified');
            }
        } 
        else if (sType == Account.SObjectType) {
            Account acc = [ SELECT Name, OwnerId, Policy_Check_Status__c FROM Account WHERE Id = :recordId LIMIT 1 ];
            policyCheckStatus = acc.Policy_Check_Status__c;
            ownerId = acc.OwnerId;
            recordName = acc.Name;
            recordToUpdate = new Account( Id = recordId, Policy_Check_Comments__c = comments, Agent_2__c = agent2Id );
            if (isFinalSubmission && String.isBlank(policyCheckStatus)) recordToUpdate.put('Policy_Check_Status__c', 'Submitted');
        } 
        else if (sType == Opportunity.SObjectType) {
            Opportunity oppParent = [ SELECT Name, OwnerId, Policy_Check_Status__c FROM Opportunity WHERE Id = :recordId LIMIT 1 ];
            policyCheckStatus = oppParent.Policy_Check_Status__c;
            ownerId = oppParent.OwnerId;
            recordName = oppParent.Name;
            recordToUpdate = new Opportunity( Id = recordId, Policy_Check_Comments__c = comments, Agent_2__c = agent2Id );
            if (isFinalSubmission && String.isBlank(policyCheckStatus)) {
                recordToUpdate.put('Policy_Check_Status__c', 'Submitted');
                recordToUpdate.put('StageName', 'Policy Check'); 
            }
        }
        
        Boolean waiverRequested = false;
        String htmlTable = '<table style="width:100%; border-collapse:collapse; margin-bottom: 20px; font-family: sans-serif; font-size: 13px; border: none; background-color: transparent;">';
        htmlTable += '<tr style="text-align: left; border-bottom: 1px solid #c9c9c9;"><th style="padding: 8px 12px 8px 0; font-weight: 700; color: #514f4d; width: 35%;">Policy / Quote</th><th style="padding: 8px 12px; font-weight: 700; color: #514f4d; width: 30%;">Decision *</th><th style="padding: 8px 12px; font-weight: 700; color: #514f4d; width: 35%;">Management Comments</th></tr>';
        
        for (PolicySaveRequest req : policyRequests) {
            String waiverText = '';
            if (req.policyRecord.Agency_Fee_Waiver_Request__c == true) {
                waiverRequested = true;
                waiverText = '<br/><span style="color:#ea001e; font-weight:bold; font-size: 11px;">AGENCY SERVICE FEE WAIVER REQUESTED</span>';
            }
            
            String lineIcon = '&#128196;';
            String lineStr = req.policyRecord.Lines__c != null ? req.policyRecord.Lines__c : '';
            String lineL = lineStr.toLowerCase();
            if (lineL.contains('auto') || lineL.contains('vehicle')) lineIcon = '&#128663;';
            else if (lineL.contains('home') || lineL.contains('property')) lineIcon = '&#127968;';
            else if (lineL.contains('flood')) lineIcon = '&#127754;';
            else if (lineL.contains('umbrella')) lineIcon = '&#9730;';
            else if (lineL.contains('commercial') || lineL.contains('business')) lineIcon = '&#127970;';
            
            String statusColor = '#080707';
            String statStr = req.policyRecord.Policy_Status__c != null ? req.policyRecord.Policy_Status__c : '';
            String statL = statStr.toLowerCase();
            if (statL.contains('approved')) statusColor = '#027e46';
            else if (statL.contains('pending') || statL.contains('need more info') || statL.contains('requirements needed')) statusColor = '#dd7a01';
            else if (statL.contains('rejected')) statusColor = '#ea001e';
            
            String carrierName = req.policyRecord.Carrier__c != null ? req.policyRecord.Carrier__c : '';
            String quoteNum = req.policyRecord.Quote__c != null ? req.policyRecord.Quote__c : '';
            String policyComments = req.policyRecord.Additional_Comments__c != null ? req.policyRecord.Additional_Comments__c : '';
            
            String col1 = '<table style="border: none; border-collapse: collapse; margin: 0; width: 100%;"><tr><td style="padding: 0 10px 0 0; vertical-align: top; font-size: 20px; border:none; width: 28px; color: #0176d3;">' + lineIcon + '</td><td style="padding: 0; vertical-align: top; border:none;"><div style="font-weight: 700; color: #080707; font-size: 13px; margin-bottom: 2px;">' + lineStr + '</div><div style="color: #080707; font-size: 13px;">' + carrierName + '</div><div style="color: #444; font-size: 12px; margin-top: 1px;">' + quoteNum + '</div></td></tr></table>';
            
            String col2 = '<div style="border: 1px solid #c9c9c9; border-radius: 4px; padding: 6px 10px; display: inline-block; min-width: 160px; background-color: #fff; color: ' + statusColor + '; font-weight: 500;">' + statStr + '<span style="float: right; color: #080707; font-size: 10px; margin-top: 4px; margin-left: 8px;">&#9660;</span></div>' + waiverText;
            
            String col3 = '<div style="border: 1px solid #c9c9c9; border-radius: 4px; padding: 6px 10px; min-height: 48px; background-color: #fff; color: #080707; font-family: inherit;">' + policyComments + '</div>';
            
            htmlTable += '<tr style="border-bottom: 1px solid #c9c9c9;"><td style="padding: 12px 12px 12px 0; vertical-align: top; border:none;">' + col1 + '</td><td style="padding: 12px; vertical-align: top; border:none;">' + col2 + '</td><td style="padding: 12px; vertical-align: top; border:none;">' + col3 + '</td></tr>';
        }
        htmlTable += '</table>';

        if (waiverRequested) {
            htmlTable = '<div style="color:#ea001e; font-weight:700; font-size: 16px; margin-bottom: 10px;">AGENCY SERVICE FEE WAIVER REQUESTED</div>' + htmlTable;
        }
        recordToUpdate.put('Policy_Check_Summary__c', htmlTable);
        update recordToUpdate;
        
        if (deletedPolicyIds != null && !deletedPolicyIds.isEmpty()) delete [SELECT Id FROM Policy_Information__c WHERE Id IN :deletedPolicyIds];
        
        List<Policy_Information__c> policiesToUpsert = new List<Policy_Information__c>();
        Boolean statusChanged = false;
        String detectedStatus;
        Set<String> triggerStatuses = new Set<String>{'Approved','Rejected', 'Need More Info'};
        Opportunity opp;
        if (sType == Opportunity.SObjectType) opp = [ SELECT Id, AccountId FROM Opportunity WHERE Id = :recordId LIMIT 1 ];
        
        for (PolicySaveRequest req : policyRequests) {
            if (sType == Lead.SObjectType) req.policyRecord.Lead__c = recordId;
            else if (sType == Account.SObjectType) req.policyRecord.Account__c = recordId;
            else if (sType == Opportunity.SObjectType) {
                req.policyRecord.Opportunity__c = opp.Id;
                req.policyRecord.Account__c = opp.AccountId;
            }
            req.policyRecord.Policy_Type__c = 'Quote';
            
            // Apply Waiver Decision logic
            req.policyRecord.Agency_Fee__c = AgencyFeeHelper.applyWaiverDecision(req.policyRecord.Agency_Fee__c, req.policyRecord.Agency_Fee_Waiver_Decision__c);

            policiesToUpsert.add(req.policyRecord);
            if (triggerStatuses.contains(req.policyRecord.Policy_Status__c)) {
                statusChanged = true;
                detectedStatus = req.policyRecord.Policy_Status__c;
            }
        }
        upsert policiesToUpsert;
        
        // Process waivers for Policy Check (sends approval emails and generates tokens)
        QuoteAgencyHelper.processWaiverRequests(recordId, policiesToUpsert);
        
        if (statusChanged) {
            SObject statusUpdate;
            if (sType == Lead.SObjectType) statusUpdate = new Lead(Id = recordId, Policy_Check_Status__c = detectedStatus);
            else if (sType == Account.SObjectType) statusUpdate = new Account(Id = recordId, Policy_Check_Status__c = detectedStatus);
            else if (sType == Opportunity.SObjectType) statusUpdate = new Opportunity(Id = recordId, Policy_Check_Status__c = detectedStatus);
            if (statusUpdate != null) update statusUpdate;
        }
        
        if (statusChanged) sendPolicyCheckStatusEmail(recordId, false); 
        else if (isFinalSubmission && String.isBlank(policyCheckStatus)) sendPolicyCheckStatusEmail(recordId, true); 
        
        if (!policyRequests.isEmpty()) {
            System.enqueueJob(new PolicyChatterQueueable(recordId, policyRequests, policiesToUpsert));
        }
    }
    
    private static void sendSubmissionEmail(Id recordId) {
        SObjectType sType = recordId.getSObjectType();
        String templateApiName;
        Id ownerId;
        
        if (sType == Lead.SObjectType) {
            templateApiName = 'Policy_Check_Request_Template';
            ownerId = [SELECT OwnerId FROM Lead WHERE Id = :recordId].OwnerId;
        }
        else if (sType == Opportunity.SObjectType) {
            templateApiName = 'Policy_Check_Request_Opportunity';
            ownerId = [SELECT OwnerId FROM Opportunity WHERE Id = :recordId].OwnerId;
        }
        else return;
        
        EmailTemplate template = [SELECT Id FROM EmailTemplate WHERE DeveloperName = :templateApiName LIMIT 1];
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setTargetObjectId(ownerId);
        mail.setTemplateId(template.Id);
        mail.setWhatId(recordId);
        mail.setSaveAsActivity(false);
        Messaging.sendEmail(new Messaging.SingleEmailMessage[]{ mail });
    }
    
    private static void sendPolicyCheckStatusEmail(Id recordId, Boolean useLabelRecipient) {
        SObjectType sType = recordId.getSObjectType();
        String templateApiName;
        Id ownerId;
        
        if (sType == Lead.SObjectType) {
            templateApiName = useLabelRecipient ? 'Policy_Check_Request_Template' : 'Policy_Check_Completion_Template';
            ownerId = [SELECT OwnerId FROM Lead WHERE Id = :recordId].OwnerId;
        }
        else if (sType == Opportunity.SObjectType) {
            templateApiName = useLabelRecipient ? 'Policy_Check_Request_Opportunity' : 'Policy_Check_Completed_Opportunity';
            ownerId = [SELECT OwnerId FROM Opportunity WHERE Id = :recordId].OwnerId;
        }
        else return;
        
        EmailTemplate template = [SELECT Id FROM EmailTemplate WHERE DeveloperName = :templateApiName LIMIT 1];
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setTargetObjectId(ownerId); 
        mail.setTemplateId(template.Id);
        mail.setWhatId(recordId);
        mail.setSaveAsActivity(false);
        
        if (useLabelRecipient) {
            String labelEmail = System.Label.Policy_Check_Email;
            mail.setToAddresses(new String[] { labelEmail });
        } 
        Messaging.sendEmail(new Messaging.SingleEmailMessage[]{ mail });
    }
    
    @AuraEnabled(cacheable=true)
    public static List<User> getAgent2Options() {
        return [SELECT Id, Name, Email FROM User WHERE IsActive = true AND (Profile.Name = 'Standard User' OR Profile.Name = 'System Administrator') ORDER BY Name];
    }
    @AuraEnabled(cacheable=true)
    public static List<Carrier__c> getCarrierOptions() {
        return [SELECT Id, Company_Name__c FROM Carrier__c ORDER BY Company_Name__c];
    }
    
    @AuraEnabled
    public static void savePolicyCheckPdfLink(Id recordId) {
        try {
            SObjectType sType = recordId.getSObjectType();
            String name = 'Record';
            
            if (sType == Lead.SObjectType) name = [SELECT Name FROM Lead WHERE Id = :recordId LIMIT 1].Name;
            else if (sType == Account.SObjectType) name = [SELECT Name FROM Account WHERE Id = :recordId LIMIT 1].Name;
            else if (sType == Opportunity.SObjectType) name = [SELECT Account.Name FROM Opportunity WHERE Id = :recordId LIMIT 1].Account.Name;

            PageReference pdfPage = Page.PolicyCheck_PDF;
            pdfPage.getParameters().put('id', recordId);

            Blob pdfBlob;
            if (Test.isRunningTest()) pdfBlob = Blob.valueOf('Test PDF content');
            else pdfBlob = pdfPage.getContentAsPDF();

            ContentVersion cv = new ContentVersion();
            cv.Title = 'Policy Check - ' + name; 
            cv.PathOnClient = 'Policy_Check.pdf';
            cv.VersionData = pdfBlob;
            cv.FirstPublishLocationId = recordId; 
            //cv.Type__c = 'Policy Check'; 
            insert cv;

        } catch (Exception e) {
            throw new AuraHandledException('PDF Error line ' + e.getLineNumber() + ': ' + e.getMessage());
        }
    }
}