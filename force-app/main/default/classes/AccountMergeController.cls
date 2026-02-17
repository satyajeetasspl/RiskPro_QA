public with sharing class AccountMergeController {

    @AuraEnabled(cacheable=true)
    public static List<Account> getDuplicates(Id accountId) {
        if (accountId == null) {
            return new List<Account>();
        }

        List<Account> accList = [
            SELECT Name
            FROM Account
            WHERE Id = :accountId
            LIMIT 1
        ];

        if (accList.isEmpty()) {
            return new List<Account>();
        }

        Account acc = accList[0];
        String base = acc.Name != null ? acc.Name.trim() : '';
        Integer len = Math.min(3, base.length());
        String key = base.substring(0, len);

        return [
            SELECT Id, Name, Phone, Website, CreatedDate
            FROM Account
            WHERE Id != :accountId
            AND Name LIKE :('%' + key + '%')
        ];
    }

    @AuraEnabled
    public static void mergeAccounts(Id sourceId, Id targetId) {

        if (sourceId == null || targetId == null) {
            throw new AuraHandledException('Source or Target Id missing');
        }

        Account src = [
            SELECT Id, vert__AMS360_Customer_Number__c
            FROM Account
            WHERE Id = :sourceId
            LIMIT 1
        ];

        Account tgt = [
            SELECT Id, vert__AMS360_Customer_Number__c
            FROM Account
            WHERE Id = :targetId
            LIMIT 1
        ];

        if ( tgt.vert__AMS360_Customer_Number__c == null) {
            throw new AuraHandledException(
                'Merge not allowed because AMS360 Customer Number is missing on one or both accounts.'
            );
        }

        Id duplicateAccount = sourceId;
        Id mainAccount = targetId;

        // ---------------- STANDARD OBJECTS ----------------

        List<Contact> contacts = [SELECT Id, AccountId FROM Contact WHERE AccountId = :duplicateAccount];
        for (Contact c : contacts) c.AccountId = mainAccount;
        if (!contacts.isEmpty()) update contacts;

        List<Opportunity> opps = [SELECT Id, AccountId FROM Opportunity WHERE AccountId = :duplicateAccount];
        for (Opportunity o : opps) o.AccountId = mainAccount;
        if (!opps.isEmpty()) update opps;

        List<Case> casesList = [SELECT Id, AccountId FROM Case WHERE AccountId = :duplicateAccount];
        for (Case cs : casesList) cs.AccountId = mainAccount;
        if (!casesList.isEmpty()) update casesList;

        List<Note> oldNotes = [
            SELECT Id, Title, Body
            FROM Note
            WHERE ParentId = :duplicateAccount
        ];
        List<Note> newNotes = new List<Note>();
        for (Note n : oldNotes) {
            newNotes.add(new Note(
                Title    = n.Title,
                Body     = n.Body,
                ParentId = mainAccount
            ));
        }
        if (!newNotes.isEmpty()) insert newNotes;
        if (!oldNotes.isEmpty()) delete oldNotes;


        List<Task> tasks = [SELECT Id, WhatId FROM Task WHERE WhatId = :duplicateAccount];
        for (Task t : tasks) t.WhatId = mainAccount;
        if (!tasks.isEmpty()) update tasks;

        List<Event> events = [SELECT Id, WhatId FROM Event WHERE WhatId = :duplicateAccount];
        for (Event e : events) e.WhatId = mainAccount;
        if (!events.isEmpty()) update events;

        // ---------------- FILES ----------------

        List<ContentDocumentLink> fileLinks = [
            SELECT Id, ContentDocumentId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :duplicateAccount
        ];

        List<ContentDocumentLink> newLinks = new List<ContentDocumentLink>();
        List<ContentDocumentLink> oldLinks = new List<ContentDocumentLink>();

        for (ContentDocumentLink l : fileLinks) {
            newLinks.add(new ContentDocumentLink(
                ContentDocumentId = l.ContentDocumentId,
                LinkedEntityId = mainAccount,
                ShareType = 'V',
                Visibility = 'AllUsers'
            ));
            oldLinks.add(l);
        }

        if (!newLinks.isEmpty()) insert newLinks;
        if (!oldLinks.isEmpty()) delete oldLinks;

        // ---------------- EXISTING CUSTOM OBJECT ----------------
/*
        List<vert__AMS360_Policy__c> policies = [
            SELECT Id, vert__AMS360_Account_Name__c
            FROM vert__AMS360_Policy__c
            WHERE vert__AMS360_Account_Name__c = :duplicateAccount
        ];
        for (vert__AMS360_Policy__c p : policies) {
            p.vert__AMS360_Account_Name__c = mainAccount;
        }
        if (!policies.isEmpty()) update policies;
        
        */

        // ---------------- NEW CUSTOM OBJECTS ----------------

        updateDrivers(duplicateAccount, mainAccount);
        updateVehicles(duplicateAccount, mainAccount);
        updateProperties(duplicateAccount, mainAccount);
        updateCrossSell(duplicateAccount, mainAccount);
        updateAutoIncidents(duplicateAccount, mainAccount);
        updateHomeLosses(duplicateAccount, mainAccount);
        updatePolicyInfo(duplicateAccount, mainAccount);
        updatePriorInsurance(duplicateAccount, mainAccount);

    }

    // ================== CUSTOM OBJECT HANDLERS ==================

    private static void updateDrivers(Id src, Id tgt) {
        List<Driver__c> lst = [SELECT Id, Account__c FROM Driver__c WHERE Account__c = :src];
        for (Driver__c r : lst) r.Account__c = tgt;
        if (!lst.isEmpty()) update lst;
    }

    private static void updateVehicles(Id src, Id tgt) {
        List<Vehicle__c> lst = [SELECT Id, Account__c FROM Vehicle__c WHERE Account__c = :src];
        for (Vehicle__c r : lst) r.Account__c = tgt;
        if (!lst.isEmpty()) update lst;
    }

    private static void updateProperties(Id src, Id tgt) {
        List<Properties__c> lst = [SELECT Id, Account__c FROM Properties__c WHERE Account__c = :src];
        for (Properties__c r : lst) r.Account__c = tgt;
        if (!lst.isEmpty()) update lst;
    }

    private static void updateCrossSell(Id src, Id tgt) {
        List<Cross_Sell__c> lst = [SELECT Id, Account__c FROM Cross_Sell__c WHERE Account__c = :src];
        for (Cross_Sell__c r : lst) r.Account__c = tgt;
        if (!lst.isEmpty()) update lst;
    }

    private static void updateAutoIncidents(Id src, Id tgt) {
        List<Auto_Incidents_Violations__c> lst = [
            SELECT Id, Account__c FROM Auto_Incidents_Violations__c WHERE Account__c = :src
        ];
        for (Auto_Incidents_Violations__c r : lst) r.Account__c = tgt;
        if (!lst.isEmpty()) update lst;
    }

    private static void updateHomeLosses(Id src, Id tgt) {
        List<Home_Losses_Claims__c> lst = [
            SELECT Id, Account__c FROM Home_Losses_Claims__c WHERE Account__c = :src
        ];
        for (Home_Losses_Claims__c r : lst) r.Account__c = tgt;
        if (!lst.isEmpty()) update lst;
    }

    private static void updatePolicyInfo(Id src, Id tgt) {
        List<Policy_Information__c> lst = [
            SELECT Id, Account__c FROM Policy_Information__c WHERE Account__c = :src
        ];
        for (Policy_Information__c r : lst) r.Account__c = tgt;
        if (!lst.isEmpty()) update lst;
    }
    
    private static void updatePriorInsurance(Id src, Id tgt) {
    List<Prior_Insurance_Information__c> lst = [
        SELECT Id, Account__c
        FROM Prior_Insurance_Information__c
        WHERE Account__c = :src
    ];
    for (Prior_Insurance_Information__c r : lst) {
        r.Account__c = tgt;
    }
    if (!lst.isEmpty()) update lst;
    }

}