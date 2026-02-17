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
        @AuraEnabled public SObject recordDetail { get; set; } // Generic SObject (Lead or Account)
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
    
    // 3. Main Load Method
    @AuraEnabled(cacheable=true)
    public static PolicyCheckWrapper getPolicyCheckData(Id recordId) {
        if (recordId == null) {
            throw new AuraHandledException('Record Id is required.');
        }
        
        PolicyCheckWrapper w = new PolicyCheckWrapper();
        
        // --- Profile check ---
        Profile p = [
            SELECT Name 
            FROM Profile 
            WHERE Id = :UserInfo.getProfileId()
            LIMIT 1
        ];
        w.isSystemAdmin = (p.Name == 'System Administrator');
        
        SObjectType sType = recordId.getSObjectType();
        
        /* =========================================================
A. QUERY PARENT RECORD (Lead / Account / Opportunity)
========================================================= */
        
        if (sType == Lead.SObjectType) {
            
            Lead l = [
                SELECT Id, OwnerId, Owner.Name, Owner.Email, Status,
                Policy_Check_Status__c, Agent_2__c, Policy_Check_Comments__c,
                Personal_Lines__c, Commercial_Lines__c
                FROM Lead
                WHERE Id = :recordId
                LIMIT 1
            ];
            
            w.recordDetail = l;
            
            // Parse Lines (Lead only)
            List<String> finalLines = new List<String>();
            if (l.Personal_Lines__c != null) {
                finalLines.addAll(l.Personal_Lines__c.split(';'));
            }
            if (l.Commercial_Lines__c != null) {
                finalLines.addAll(l.Commercial_Lines__c.split(';'));
            }
            w.leadLinesList = finalLines;
            
        } 
        else if (sType == Account.SObjectType) {
            
            Account acc = [
                SELECT Id, Name, OwnerId, Owner.Name, Owner.Email,
                Policy_Check_Status__c, Agent_2__c, Policy_Check_Comments__c
                FROM Account
                WHERE Id = :recordId
                LIMIT 1
            ];
            
            w.recordDetail = acc;
            w.leadLinesList = new List<String>();
            
        } 
        else if (sType == Opportunity.SObjectType) {
            
            Opportunity opp = [
                SELECT Id, Name, AccountId, OwnerId, Owner.Name, Owner.Email,
                Policy_Check_Status__c, Agent_2__c, Policy_Check_Comments__c
                FROM Opportunity
                WHERE Id = :recordId
                LIMIT 1
            ];
            
            w.recordDetail = opp;
            w.leadLinesList = new List<String>();
        }
        
        /* =========================================================
B. QUERY POLICY INFORMATION
========================================================= */
        
        String query =
            'SELECT Id, Carrier__c, Lines__c, Quote__c, Premium__c, ' +
            'Effective_Date__c, Policy_Status__c, Additional_Comments__c ' +
            'FROM Policy_Information__c WHERE Policy_Type__c != \'NBC\' AND ';
        
        if (sType == Lead.SObjectType) {
            query += 'Lead__c = :recordId';
        }
        else if (sType == Account.SObjectType) {
            query += 'Account__c = :recordId';
        }
        else if (sType == Opportunity.SObjectType) {
            query += 'Opportunity__c = :recordId';
        }
        
        query += ' ORDER BY CreatedDate ASC';
        
        w.policies = Database.query(query);
        
        /* =========================================================
C. CHATTER & FILES (UNCHANGED)
========================================================= */
        
        Set<Id> policyIds = new Set<Id>();
        for (Policy_Information__c pInfo : w.policies) {
            policyIds.add(pInfo.Id);
        }
        
        w.policyChatterMap = new Map<Id, List<FeedItem>>();
        w.policyFilesMap   = new Map<Id, List<ContentDocumentLink>>();
        
        if (!policyIds.isEmpty()) {
            
            List<FeedItem> feeds = [
                SELECT Id, ParentId, Body, CreatedDate, CreatedBy.Name, Type
                FROM FeedItem
                WHERE ParentId IN :policyIds
                AND (Type = 'TextPost' OR Type = 'ContentPost' OR Type = 'LinkPost')
                ORDER BY CreatedDate DESC
            ];
            
            for (FeedItem f : feeds) {
                if (!w.policyChatterMap.containsKey(f.ParentId)) {
                    w.policyChatterMap.put(f.ParentId, new List<FeedItem>());
                }
                w.policyChatterMap.get(f.ParentId).add(f);
            }
            
            List<ContentDocumentLink> files = [
                SELECT LinkedEntityId,
                ContentDocumentId,
                ContentDocument.Title,
                ContentDocument.FileExtension,
                ContentDocument.CreatedDate
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
    public static void savePolicyCheckWithPolicies( Id recordId, String comments, String agent2Id, List<PolicySaveRequest> policyRequests, Boolean isFinalSubmission ) {
        if (recordId == null) throw new AuraHandledException('Record ID is missing.');
        SObjectType sType = recordId.getSObjectType();
        SObject recordToUpdate;
        String policyCheckStatus = '';
        String ownerId = '';
        String recordName = '';
        
        /* ========================= A. Parent Update ========================= */
        if (sType == Lead.SObjectType) {
            Lead oldLead = [ SELECT Name, OwnerId, Policy_Check_Status__c, Status FROM Lead WHERE Id = :recordId LIMIT 1 ];
            policyCheckStatus = oldLead.Policy_Check_Status__c;
            ownerId = oldLead.OwnerId;
            recordName = oldLead.Name;
            recordToUpdate = new Lead( Id = recordId, Policy_Check_Comments__c = comments, Agent_2__c = agent2Id, Is_Policy_Checked__c = true );
            if (isFinalSubmission && String.isBlank(policyCheckStatus)) {
                recordToUpdate.put('Policy_Check_Status__c', 'Submitted');
                if (oldLead.Status != 'Unqualified') {
                    recordToUpdate.put('Status', 'Unqualified');
                }
            }
        } 
        else if (sType == Account.SObjectType) {
            Account acc = [ SELECT Name, OwnerId, Policy_Check_Status__c FROM Account WHERE Id = :recordId LIMIT 1 ];
            policyCheckStatus = acc.Policy_Check_Status__c;
            ownerId = acc.OwnerId;
            recordName = acc.Name;
            recordToUpdate = new Account( Id = recordId, Policy_Check_Comments__c = comments, Agent_2__c = agent2Id );
            if (isFinalSubmission && String.isBlank(policyCheckStatus)) {
                recordToUpdate.put('Policy_Check_Status__c', 'Submitted');
            }
        } else if (sType == Opportunity.SObjectType) {
    
    Opportunity oppParent = [ SELECT Name, OwnerId, Policy_Check_Status__c FROM Opportunity WHERE Id = :recordId LIMIT 1 ];
    policyCheckStatus = oppParent.Policy_Check_Status__c;
    ownerId = oppParent.OwnerId;
    recordName = oppParent.Name;
    
    // 1. Initialize the record to update
    recordToUpdate = new Opportunity( Id = recordId, Policy_Check_Comments__c = comments, Agent_2__c = agent2Id );
    
    // 2. Handle Final Submission
    if (isFinalSubmission && String.isBlank(policyCheckStatus)) {
        // Set the internal status to Submitted
        recordToUpdate.put('Policy_Check_Status__c', 'Submitted');
        
        // UPDATE THE OPPORTUNITY STAGE HERE
        recordToUpdate.put('StageName', 'Policy Check'); 
    }
}
        
        /* ========================= B. Summary ========================= */
        String htmlTable = '<table style="width:100%;border-collapse:collapse;">';
        htmlTable += '<tr><th>Line</th><th>Status</th><th>Comments</th></tr>';
        for (PolicySaveRequest req : policyRequests) {
            htmlTable += '<tr><td>' + req.policyRecord.Lines__c + '</td><td>' + req.policyRecord.Policy_Status__c + '</td><td>' + req.policyRecord.Additional_Comments__c + '</td></tr>';
        }
        htmlTable += '</table>';
        recordToUpdate.put('Policy_Check_Summary__c', htmlTable);
        update recordToUpdate;
        
        /* ========================= C. Policies ========================= */
        List<Policy_Information__c> policiesToUpsert = new List<Policy_Information__c>();
        Boolean statusChanged = false;
        String detectedStatus;
        Set<String> triggerStatuses = new Set<String>{'Approved','Rejected', 'Need More Info'};
        Opportunity opp;
        if (sType == Opportunity.SObjectType) {
            opp = [ SELECT Id, AccountId FROM Opportunity WHERE Id = :recordId LIMIT 1 ];
        }
        
        for (PolicySaveRequest req : policyRequests) {
            if (sType == Lead.SObjectType) {
                req.policyRecord.Lead__c = recordId;
            } else if (sType == Account.SObjectType) {
                req.policyRecord.Account__c = recordId;
            } else if (sType == Opportunity.SObjectType) {
                req.policyRecord.Opportunity__c = opp.Id;
                req.policyRecord.Account__c = opp.AccountId;
            }
            req.policyRecord.Policy_Type__c = 'Quote';
            policiesToUpsert.add(req.policyRecord);
            if (triggerStatuses.contains(req.policyRecord.Policy_Status__c)) {
                statusChanged = true;
                detectedStatus = req.policyRecord.Policy_Status__c;
            }
        }
        upsert policiesToUpsert;
        
        if (statusChanged) {
    SObject statusUpdate;
    if (sType == Lead.SObjectType) {
        statusUpdate = new Lead(Id = recordId, Policy_Check_Status__c = detectedStatus);
    } else if (sType == Account.SObjectType) {
        statusUpdate = new Account(Id = recordId, Policy_Check_Status__c = detectedStatus);
    } else if (sType == Opportunity.SObjectType) {
        statusUpdate = new Opportunity(Id = recordId, Policy_Check_Status__c = detectedStatus);
    }
    if (statusUpdate != null) {
        update statusUpdate;
    }
}
        
                /* ========================= D. Status Update & Emails ========================= */
        // 1. If status changed to Approved/Rejected/etc, send to Owner (Scenario 2)
        if (statusChanged) {
            // ... existing status update logic ...
            sendPolicyCheckStatusEmail(recordId, false); 
        } 
        // 2. If it's the very first submission, send to Custom Label (Scenario 1)
        else if (isFinalSubmission && String.isBlank(policyCheckStatus)) {
            sendPolicyCheckStatusEmail(recordId, true); 
        }
        
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
            System.debug('### OPP COMPLETION EMAIL ###');
            System.debug('RecordId: ' + recordId);
            System.debug('Template: ' + templateApiName);
            System.debug('OwnerId: ' + ownerId);
        }
        else {
            return;
        }
        
        EmailTemplate template = [
            SELECT Id FROM EmailTemplate
            WHERE DeveloperName = :templateApiName
            LIMIT 1
        ];
        
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
    
    // Determine Template and Owner based on Object Type
    if (sType == Lead.SObjectType) {
        templateApiName = useLabelRecipient ? 'Policy_Check_Request_Template' : 'Policy_Check_Completion_Template';
        ownerId = [SELECT OwnerId FROM Lead WHERE Id = :recordId].OwnerId;
    }
    else if (sType == Opportunity.SObjectType) {
        templateApiName = useLabelRecipient ? 'Policy_Check_Request_Opportunity' : 'Policy_Check_Completed_Opportunity';
        ownerId = [SELECT OwnerId FROM Opportunity WHERE Id = :recordId].OwnerId;
    }
    else { return; }
    
    EmailTemplate template = [SELECT Id FROM EmailTemplate WHERE DeveloperName = :templateApiName LIMIT 1];
    
    Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
    mail.setTargetObjectId(ownerId); // Required for Template Merge Fields
    mail.setTemplateId(template.Id);
    mail.setWhatId(recordId);
    mail.setSaveAsActivity(false);
    
    // ROUTING LOGIC
    if (useLabelRecipient) {
        // Scenario 1: First time submission -> Use Custom Label
        String labelEmail = System.Label.Policy_Check_Email;
        mail.setToAddresses(new String[] { labelEmail });
    } 
    // Scenario 2: If useLabelRecipient is false, it defaults to TargetObjectId (Owner)
    
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
}