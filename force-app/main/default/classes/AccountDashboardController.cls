public with sharing class AccountDashboardController {
    public class DashboardWrapper {
        @AuraEnabled public Account account { get; set; }
        @AuraEnabled public Contact primaryInsured { get; set; }
        @AuraEnabled public Contact secondaryInsured { get; set; }
        @AuraEnabled public Boolean isPrimaryFromAccount { get; set; }
    }
    
    @AuraEnabled(cacheable=true)
    public static DashboardWrapper getDashboardDetails(Id accountId) {
        if (accountId == null) return null;
        DashboardWrapper result = new DashboardWrapper();
        result.isPrimaryFromAccount = false;
        
        // Query Account (Same as before)
        result.account = [
            SELECT Id, Name, vert__AMS360_Customer_Number__c, Lead_Source__c,
            Partner_Name__c, Relationship_to_Insured__c, Referral_Source_Name__c,
            BillingStreet, BillingCity, BillingState, BillingPostalCode, BillingCountry,
            Phone, Phone_2_FI__c, Email__c,
            First_Name_FI__c, Last_Name_FI__c, Insured_DOB__c,
            First_Insured_Occupation__c, First_Insured_Education__c,
            First_Insured_Marital_Status__c, First_Insured_Driver_S_License__c,
            First_Insured_Driver_S_License_State__c, 
            vert__AMS360_First_Name__c, 
            vert__AMS360_Last_Name__c, 
            vert__Other_Phone__c, 
            vert__AMS360_Firm_Name__c, 
            vert__Mobile_Phone__c, 
            vert__AMS360_Company_Email_Address2__c
            FROM Account
            WHERE Id = :accountId
            LIMIT 1
        ];
        
        List<Contact> insuredContacts = [
            SELECT Id, FirstName, LastName, Phone, Email, Drivers_License__c, Marital_Status__c,
            Occupation__c, Birthdate, MobilePhone, MailingStreet, MailingCity,
            MailingState, MailingPostalCode, MailingCountry, Insured_Role__c,
            OtherStreet, OtherCity, OtherState, OtherPostalCode, OtherCountry
            FROM Contact
            WHERE AccountId = :accountId
            AND Insured_Role__c IN ('First Insured', 'Second Named Insured')
        ];
        
        // Secondary Insured - unchanged
        for (Contact c : insuredContacts) {
            if (c.Insured_Role__c == 'Second Named Insured') {
                result.secondaryInsured = c;
            }
        }
        
        if (String.isNotBlank(result.account.vert__AMS360_Customer_Number__c) || String.isNotBlank(result.account.vert__AMS360_Last_Name__c)) {
            
            result.isPrimaryFromAccount = true;
            Contact accountAsContact = new Contact();
            
            // AMS Field Mapping
            accountAsContact.FirstName = result.account.vert__AMS360_First_Name__c;
            accountAsContact.LastName = result.account.vert__AMS360_Last_Name__c;
            
            // Fallback for Last Name
            if (String.isBlank(accountAsContact.LastName)) {
                accountAsContact.LastName = result.account.Name;
            }
            
            // Address
            accountAsContact.MailingStreet = result.account.BillingStreet;
            accountAsContact.MailingCity = result.account.BillingCity;
            accountAsContact.MailingState = result.account.BillingState;
            accountAsContact.MailingPostalCode = result.account.BillingPostalCode;
            accountAsContact.MailingCountry = result.account.BillingCountry;
            
            // AMS Phone/Email
            accountAsContact.Phone = result.account.vert__Mobile_Phone__c; 
            accountAsContact.MobilePhone = result.account.vert__Other_Phone__c; 
            accountAsContact.Email = result.account.vert__AMS360_Company_Email_Address2__c; 
            
            // Custom Fields (DOB, License, etc.)
            accountAsContact.Birthdate = result.account.Insured_DOB__c;
            accountAsContact.Occupation__c = result.account.First_Insured_Occupation__c;
            accountAsContact.Marital_Status__c = result.account.First_Insured_Marital_Status__c;
            accountAsContact.Drivers_License__c = result.account.First_Insured_Driver_S_License__c;
            
            // Link real Contact ID
            for (Contact c : insuredContacts) {
                if (c.Insured_Role__c == 'First Insured') {
                    accountAsContact.Id = c.Id;
                    break;
                }
            }
            
            result.primaryInsured = accountAsContact;
            
        } else if (String.isNotBlank(result.account.Last_Name_FI__c)) {
            // ... (Legacy Logic remains the same as backup) ...
            result.isPrimaryFromAccount = true;
            Contact fiContact = new Contact();
            fiContact.FirstName = result.account.First_Name_FI__c;
            fiContact.LastName = result.account.Last_Name_FI__c;
            fiContact.Phone = result.account.Phone;
            fiContact.MobilePhone = result.account.Phone_2_FI__c;
            fiContact.Email = result.account.Email__c;
            fiContact.Birthdate = result.account.Insured_DOB__c;
            fiContact.Occupation__c = result.account.First_Insured_Occupation__c;
            fiContact.Education__c = result.account.First_Insured_Education__c;
            fiContact.Marital_Status__c = result.account.First_Insured_Marital_Status__c;
            fiContact.Drivers_License__c = result.account.First_Insured_Driver_S_License__c;
            fiContact.Drivers_License_State__c = result.account.First_Insured_Driver_S_License_State__c;
            fiContact.MailingStreet = result.account.BillingStreet;
            fiContact.MailingCity = result.account.BillingCity;
            fiContact.MailingState = result.account.BillingState;
            fiContact.MailingPostalCode = result.account.BillingPostalCode;
            fiContact.MailingCountry = result.account.BillingCountry;
            
            for (Contact c : insuredContacts) {
                if (c.Insured_Role__c == 'First Insured') {
                    fiContact.Id = c.Id;
                    break;
                }
            }
            result.primaryInsured = fiContact;
            
        } else {
            // Fallback to Contact
            for (Contact c : insuredContacts) {
                if (c.Insured_Role__c == 'First Insured') {
                    result.primaryInsured = c;
                    break;
                }
            }
        }
        
        return result;
    }
    
    @AuraEnabled
    public static void savePrimaryInsuredDetails(Contact primaryContact, Id accountId) {
        if (primaryContact == null || accountId == null) {
            throw new AuraHandledException('Primary contact and account ID are required.');
        }
        
        List<SObject> toUpdate = new List<SObject>();
        
        // 1. Update the Contact if it exists
        if (primaryContact.Id != null) {
            toUpdate.add(primaryContact);
        }
        
        // 2. Update Account - Syncing Custom AND AMS Fields
        Account acc = new Account(Id = accountId);
        
        String fName = (primaryContact.FirstName != null) ? primaryContact.FirstName : '';
        String lName = (primaryContact.LastName != null) ? primaryContact.LastName : '';
        
        // Standard Account Name
        acc.Name = (fName + ' ' + lName).trim();
        
        // A. Custom 'FI' Fields (Legacy/Backup)
        acc.First_Name_FI__c = primaryContact.FirstName;
        acc.Last_Name_FI__c = primaryContact.LastName;
        acc.Phone = primaryContact.Phone;
        acc.Phone_2_FI__c = primaryContact.MobilePhone;
        acc.Email__c = primaryContact.Email;
        acc.Insured_DOB__c = primaryContact.Birthdate;
        acc.First_Insured_Occupation__c = primaryContact.Occupation__c;
        acc.First_Insured_Education__c = primaryContact.Education__c;
        acc.First_Insured_Marital_Status__c = primaryContact.Marital_Status__c;
        acc.First_Insured_Driver_S_License__c = primaryContact.Drivers_License__c;
        acc.First_Insured_Driver_S_License_State__c = primaryContact.Drivers_License_State__c;
        
        // B. ADDED: AMS 'vert__' Fields (To keep Dashboard sync)
        acc.vert__AMS360_First_Name__c = primaryContact.FirstName;
        acc.vert__AMS360_Last_Name__c = primaryContact.LastName;
        acc.vert__AMS360_Firm_Name__c = primaryContact.LastName; 
        
        acc.vert__Mobile_Phone__c = primaryContact.Phone;      
        acc.vert__Other_Phone__c = primaryContact.MobilePhone; 
        acc.vert__AMS360_Company_Email_Address2__c = primaryContact.Email;
        
        // C. Address Sync (Standard Fields)
        acc.BillingStreet = primaryContact.MailingStreet;
        acc.BillingCity = primaryContact.MailingCity;
        acc.BillingState = primaryContact.MailingState;
        acc.BillingPostalCode = primaryContact.MailingPostalCode;
        acc.BillingCountry = primaryContact.MailingCountry;
        
        toUpdate.add(acc);
        
        try {
            update toUpdate;
        } catch (Exception e) {
            throw new AuraHandledException('Error saving First Insured: ' + e.getMessage());
        }
    }
    
    // Existing saveContactDetails - kept as-is (you may still need it for secondary)
    @AuraEnabled
    public static void saveContactDetails(Contact primaryContact, Contact secondaryContact) {
        List<Contact> contactsToUpsert = new List<Contact>();
        if (primaryContact != null) contactsToUpsert.add(primaryContact);
        if (secondaryContact != null) contactsToUpsert.add(secondaryContact);
        if (!contactsToUpsert.isEmpty()) {
            try {
                upsert contactsToUpsert;
            } catch (DmlException e) {
                if (e.getDmlType(0) == StatusCode.REQUIRED_FIELD_MISSING) {
                    throw new AuraHandledException('Unable to save: Please provide the Insured’s last name to continue.');
                }
                throw new AuraHandledException(e.getDmlMessage(0));
            } catch (Exception e) {
                throw new AuraHandledException('An unexpected error occurred: ' + e.getMessage());
            }
        }
    }
    
    // ALL OTHER METHODS BELOW ARE YOUR ORIGINAL ONES - COPY THEM EXACTLY
    @AuraEnabled(cacheable=true)
    public static List<Policy_Information__c> getPolicies(Id accountId) {
        return [
            SELECT Id, Policy__c, Effective_Date__c, Carrier__c, Owner.Name, Status__c, Type__c, Company__c,
            AMS_Policy__c, Address__Street__s, Address__City__s, Address__StateCode__s,
            Address__PostalCode__s, Address__CountryCode__s
            FROM Policy_Information__c
            WHERE Account__c = :accountId
            ORDER BY Effective_Date__c DESC
            LIMIT 500
        ];
    }
    
    @AuraEnabled(cacheable=true)
    public static Map<Id, vert__AMS360_Policy__c> getAmsPolicyMap(Id accountId) {
        Set<Id> amsPolicyIds = new Set<Id>();
        for(Policy_Information__c pi : [SELECT AMS_Policy__c FROM Policy_Information__c WHERE Account__c = :accountId AND AMS_Policy__c != null]) {
            amsPolicyIds.add(pi.AMS_Policy__c);
        }
        if(amsPolicyIds.isEmpty()) return new Map<Id, vert__AMS360_Policy__c>();
        return new Map<Id, vert__AMS360_Policy__c>([SELECT Id, Name, vert__AMS360_Effective_Date__c FROM vert__AMS360_Policy__c WHERE Id IN :amsPolicyIds]);
    }
    
    @AuraEnabled(cacheable=true)
    public static List<Case> getCases(Id accountId) {
        if (accountId == null) return new List<Case>();
        return [SELECT Id, CaseNumber, Status, Subject, CreatedDate, CreatedBy.Name, (SELECT Id FROM CaseComments)  FROM Case WHERE AccountId = :accountId ORDER BY CreatedDate DESC LIMIT 105];
    }
    
    @AuraEnabled(cacheable=true)
    public static List<ContentNote> getNotes(Id accountId) {
        if (accountId == null) {
            return new List<ContentNote>();
        }
        
        Set<Id> noteDocumentIds = new Set<Id>();
        
        for (ContentDocumentLink cdl : [
            SELECT ContentDocumentId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :accountId
            AND ContentDocument.FileType = 'SNOTE'
        ]) {
            noteDocumentIds.add(cdl.ContentDocumentId);
        }
        
        if (noteDocumentIds.isEmpty()) {
            return new List<ContentNote>();
        }
        
        return [
            SELECT Id, Title, TextPreview, CreatedDate, CreatedBy.Name
            FROM ContentNote
            WHERE Id IN :noteDocumentIds
            ORDER BY CreatedDate DESC
            LIMIT 50
        ];
    }
    
    
    @AuraEnabled(cacheable=true)
    public static List<ContentDocumentLink> getFiles(Id accountId) {
        if (accountId == null) return new List<ContentDocumentLink>();
        Set<Id> linkedDocIds = new Set<Id>();
        for (ContentDocumentLink cdl : [SELECT ContentDocumentId FROM ContentDocumentLink WHERE LinkedEntityId = :accountId]) {
            if (cdl.ContentDocumentId != null) linkedDocIds.add(cdl.ContentDocumentId);
        }
        if (linkedDocIds.isEmpty()) return new List<ContentDocumentLink>();
        List<ContentDocument> fileDocs = [SELECT Id FROM ContentDocument WHERE Id IN :linkedDocIds AND (FileType != 'SNOTE' OR FileType = NULL)];
        if (fileDocs.isEmpty()) return new List<ContentDocumentLink>();
        Set<Id> fileDocIds = new Set<Id>();
        for (ContentDocument cd : fileDocs) fileDocIds.add(cd.Id);
        return [
            SELECT Id, ContentDocumentId, ContentDocument.Title, ContentDocument.Description,
            ContentDocument.CreatedBy.Name, ContentDocument.FileExtension,
            ContentDocument.CreatedDate, ContentDocument.LatestPublishedVersionId,
            ContentDocument.LatestPublishedVersion.Type__c
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :accountId AND ContentDocumentId IN :fileDocIds AND ContentDocument.FileType != 'SNOTE'
            ORDER BY ContentDocument.CreatedDate DESC
        ];
    }
    
    @AuraEnabled(cacheable=true)
    public static List<Task> getTasks(Id accountId) {
        if (accountId == null) return new List<Task>();
        return [SELECT Id, Subject, Status, ActivityDate, Owner.Name, Description FROM Task WHERE WhatId = :accountId AND vert__Activity_Action_Name__c != NULL ORDER BY ActivityDate DESC LIMIT 10];
    }
    
    @AuraEnabled(cacheable=true)
    public static List<Event> getEvents(Id accountId) {
        if (accountId == null) return new List<Event>();
        return [SELECT Id, Subject, StartDateTime, EndDateTime, Owner.Name, Description FROM Event WHERE WhatId = :accountId AND vert__Activity_Action_Name__c != NULL ORDER BY StartDateTime DESC LIMIT 5];
    }
    
    @AuraEnabled(cacheable=true)
    public static List<EmailMessage> getEmails(Id accountId) {
        if (accountId == null) return new List<EmailMessage>();
        return [SELECT Id, Subject, Status, MessageDate, FromName, TextBody FROM EmailMessage WHERE RelatedToId = :accountId ORDER BY MessageDate DESC LIMIT 5];
    }
    
 @AuraEnabled
    public static void createContentNote(Id parentId, String title, String text) {
        if (parentId == null) throw new AuraHandledException('Parent Id is required.');
        
        // 1. SAFETY: Debounce Check
        if (checkDuplicateAction(parentId, 'Created')) return;

        String noteTitle = (String.isBlank(title)) ? 'Untitled Note' : title.trim();
        String noteText = (text == null) ? '' : text;
        
        // 2. Create Note
        ContentNote newNote = new ContentNote();
        newNote.Title = noteTitle;
        newNote.Content = Blob.valueOf(noteText);
        insert newNote;
        
        // 3. Link to Account
        ContentDocumentLink cdl = new ContentDocumentLink();
        cdl.ContentDocumentId = newNote.Id;
        cdl.LinkedEntityId = parentId;
        cdl.ShareType = 'I';
        cdl.Visibility = 'AllUsers';
        insert cdl;

        // 4. LOGGING (Manual)
        List<Note_History_Logs__c> logs = new List<Note_History_Logs__c>();
        logs.add(generateLog(parentId, newNote.Id, 'Created', 'Title', null, noteTitle));
        
        if (String.isNotBlank(noteText)) {
            logs.add(generateLog(parentId, newNote.Id, 'Created', 'Body', null, noteText));
        }
        
        if(!logs.isEmpty()) insert logs;
    }
    
    @AuraEnabled
    public static Policy_Information__c createPolicy(Policy_Information__c policy) {
        if (policy == null) throw new AuraHandledException('Policy information cannot be null.');
        try {
            insert policy;
            return policy;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    @AuraEnabled(cacheable=true)
    public static List<PolicyDetailType> getAmsPoliciesByAccount(Id accountId) {
        // 1️⃣ Fetch policies once
        List<vert__AMS360_Policy__c> policies = [
            SELECT Name, vert__AMS360_Policy_Status__c, vert__AMS360_Account_Name__c,
            vert__AMS360_Account_Name__r.Name, vert__AMS360_Parent_Company__r.Name,
            vert__AMS360_Full_Term_Premium__c, vert__AMS360_Expiration_Date__c,
            vert__AMS360_Effective_Date__c, vert__AMS360_LOB__c,
            vert__AMS360_Employee_Policy_Exec__r.Name, vert__AMS360_Description__c,
            vert__AMS360_Policy_Dec_Url__c
            FROM vert__AMS360_Policy__c
            WHERE vert__AMS360_Account_Name__c = :accountId
        ];
        
        if (policies.isEmpty()) {
            return null;
        }
        
        // 2️⃣ Collect Policy Ids
        Set<Id> policyIdSet = new Set<Id>();
        for (vert__AMS360_Policy__c p : policies) {
            policyIdSet.add(p.Id);
        }
        
        // 3️⃣ Map<PolicyId, Set<Business Names>>
        Map<Id, Set<String>> policyToBusinessSet = new Map<Id, Set<String>>();
        
        for (vert__AMS360_Transaction__c txn : [
            SELECT vert__AMS360_Policy__c,
            vert__AMS360_Line_of_Business__r.Name
            FROM vert__AMS360_Transaction__c
            WHERE vert__AMS360_Policy__c IN :policyIdSet
        ]) {
            
            if (txn.vert__AMS360_Line_of_Business__r == null) {
                continue;
            }
            
            Id policyId = txn.vert__AMS360_Policy__c;
            String businessName = txn.vert__AMS360_Line_of_Business__r.Name;
            
            if (!policyToBusinessSet.containsKey(policyId)) {
                policyToBusinessSet.put(policyId, new Set<String>());
            }
            
            policyToBusinessSet.get(policyId).add(businessName);
        }
        
        // 4️⃣ Build response
        List<PolicyDetailType> result = new List<PolicyDetailType>();
        
        for (vert__AMS360_Policy__c policy : policies) {
            PolicyDetailType wrapper = new PolicyDetailType();
            wrapper.amsPolicy = policy;
            
            if (policyToBusinessSet.containsKey(policy.Id)) {
                List<String> businessList =
                    new List<String>(policyToBusinessSet.get(policy.Id));
                businessList.sort(); // optional but recommended
                wrapper.businessLineItem = String.join(businessList, ', ');
            }
            
            result.add(wrapper);
        }
        
        return result;
    }
    
    
    @AuraEnabled
    public static void saveAccountDetails(Account accountToUpdate) {
        if (accountToUpdate != null && accountToUpdate.Id != null) {
            SObjectAccessDecision decision = Security.stripInaccessible(AccessType.UPDATABLE, new List<Account>{ accountToUpdate });
            update decision.getRecords();
        }
    }
    public class PolicyDetailType {
        @AuraEnabled public vert__AMS360_Policy__c amsPolicy { get; set; }
        @AuraEnabled public String businessLineItem { get; set; }
    }
    
   @AuraEnabled
    public static void updateContentNote(String noteId, String title, String body, Id parentRecordId) {
        // 1. SAFETY: Debounce Check using parentRecordId (Account ID)
        if (parentRecordId != null && checkDuplicateAction(parentRecordId, 'Updated')) return;

        // 2. Fetch OLD Data
        ContentNote note = [SELECT Id, Title, Content FROM ContentNote WHERE Id = :noteId LIMIT 1];
        
        String oldTitle = note.Title;
        String oldBody = extractBody(note.Content);
        String newBody = (body == null) ? '' : body;

        // 3. Update Note
        note.Title = title;
        if (String.isNotBlank(newBody)) {
            note.Content = Blob.valueOf(newBody.escapeXml());
        } else {
             note.Content = Blob.valueOf('');
        }
        update note;

        // 4. LOGGING (Compare Old vs New)
        if (parentRecordId != null) {
            List<Note_History_Logs__c> logs = new List<Note_History_Logs__c>();

            if (oldTitle != title) {
                logs.add(generateLog(parentRecordId, noteId, 'Updated', 'Title', oldTitle, title));
            }

            if (oldBody != newBody) {
                logs.add(generateLog(parentRecordId, noteId, 'Updated', 'Body', oldBody, newBody));
            }

            if(!logs.isEmpty()) insert logs;
        }
    }
 
   @AuraEnabled
public static void updateFileDetails(List<Id> documentIds, String description, String fileType) {
    if (documentIds == null || documentIds.isEmpty()) return;

    // 1) Update ContentDocument.Description
    if (String.isNotBlank(description)) {
        List<ContentDocument> docsToUpdate = new List<ContentDocument>();
        for (Id docId : documentIds) {
            docsToUpdate.add(new ContentDocument(Id = docId, Description = description));
        }
        try {
            update docsToUpdate;
        } catch (Exception e) {
            throw new AuraHandledException('Error updating description: ' + e.getMessage());
        }
    }

    // 2) Update ContentVersion.Type__c only if field exists + is updateable
    if (String.isNotBlank(fileType)) {
        Map<String, Schema.SObjectField> cvFields = Schema.SObjectType.ContentVersion.fields.getMap();

        if (!cvFields.containsKey('Type__c') || !cvFields.get('Type__c').getDescribe().isUpdateable()) {
            // Skip safely (prevents failures in orgs where field doesn't exist or isn't writable)
            return;
        }

        List<ContentVersion> versionsToUpdate = [
            SELECT Id
            FROM ContentVersion
            WHERE ContentDocumentId IN :documentIds
            AND IsLatest = true
        ];

        for (ContentVersion cv : versionsToUpdate) {
            cv.put('Type__c', fileType);
        }

        if (!versionsToUpdate.isEmpty()) {
            try {
                update versionsToUpdate;
            } catch (Exception e) {
                throw new AuraHandledException('Error updating file type: ' + e.getMessage());
            }
        }
    }
}
    

        private static Note_History_Logs__c generateLog(Id parentId, Id noteId, String action, String field, String oldVal, String newVal) {
            Note_History_Logs__c log = new Note_History_Logs__c();
            log.Parent_Record_Id__c = parentId; 
            log.Note_Id__c = noteId;          
            log.Action__c = action;
            log.Field_Name__c = field;
            
            Integer maxLen = 130000; 
            log.Old_Value__c = (oldVal != null && oldVal.length() > maxLen) ? oldVal.left(maxLen) : oldVal;
            log.New_Value__c = (newVal != null && newVal.length() > maxLen) ? newVal.left(maxLen) : newVal;
            
            return log;
        }

    private static String extractBody(Blob data) {
        if (data == null) return '';
        try {
            // Convert HTML ContentNote to Plain Text for readable logging
            String html = data.toString();
            html = html.replace('<br>', '\n')
                       .replace('<br/>', '\n')
                       .replace('</p>', '\n')
                       .replace('</div>', '\n');
            return html.stripHtmlTags().trim();
        } catch (Exception e) {
            return '';
        }
    }
    
    private static Boolean checkDuplicateAction(Id parentId, String action) {
        Datetime threshold = System.now().addSeconds(-2);
        Integer count = [
            SELECT COUNT()
            FROM Note_History_Logs__c
            WHERE Parent_Record_Id__c = :parentId
            AND CreatedById = :UserInfo.getUserId()
            AND Action__c = :action
            AND CreatedDate >= :threshold
        ];
        return count > 0;
    }
}