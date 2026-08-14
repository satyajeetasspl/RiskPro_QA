public class SignEasyTransactionHelper {
    public static void processCompletedTransactions(Map<Id, hic_signeasy__Transaction__c> newMap, Map<Id, hic_signeasy__Transaction__c> oldMap) {
        List<hic_signeasy__Transaction__c> completedTransactions = new List<hic_signeasy__Transaction__c>();
        
        for (hic_signeasy__Transaction__c trans : newMap.values()) {
            String newStatus = trans.hic_signeasy__Status__c;
            String oldStatus = (oldMap != null && oldMap.containsKey(trans.Id)) ? oldMap.get(trans.Id).hic_signeasy__Status__c : null;
            
            if ((newStatus == 'Completed' || newStatus == 'COMPLETE') && newStatus != oldStatus) {
                completedTransactions.add(trans);
            }
        }
        
        if (!completedTransactions.isEmpty()) {
            sendNotifications(completedTransactions);
        }
    }

    private static void sendNotifications(List<hic_signeasy__Transaction__c> transactions) {
        Set<Id> leadIds = new Set<Id>();
        Set<Id> oppIds = new Set<Id>();
        
        for (hic_signeasy__Transaction__c trans : transactions) {
            if (trans.hic_signeasy__Lead__c != null) {
                leadIds.add(trans.hic_signeasy__Lead__c);
            } else if (trans.hic_signeasy__Opportunity__c != null) {
                oppIds.add(trans.hic_signeasy__Opportunity__c);
            }
        }
        
        Map<Id, Lead> leadsMap = new Map<Id, Lead>();
        if (!leadIds.isEmpty()) {
            leadsMap = new Map<Id, Lead>([SELECT Id, OwnerId, Agent_2__c FROM Lead WHERE Id IN :leadIds]);
        }
        
        Map<Id, Opportunity> oppsMap = new Map<Id, Opportunity>();
        if (!oppIds.isEmpty()) {
            oppsMap = new Map<Id, Opportunity>([SELECT Id, OwnerId, Agent_2__c FROM Opportunity WHERE Id IN :oppIds]);
        }
        
        CustomNotificationType notifType;
        try {
            List<CustomNotificationType> types = [SELECT Id FROM CustomNotificationType WHERE DeveloperName = 'Proposal_Signed' LIMIT 1];
            if (!types.isEmpty()) notifType = types[0];
        } catch(Exception e) {
            System.debug('Custom Notification Type not found');
        }
        
        EmailTemplate emailTemp;
        try {
            List<EmailTemplate> templates = [SELECT Id FROM EmailTemplate WHERE DeveloperName = 'Proposal_Signed_Notification' LIMIT 1];
            if (!templates.isEmpty()) emailTemp = templates[0];
        } catch(Exception e) {
            System.debug('Email Template not found');
        }
        
        List<Messaging.SingleEmailMessage> emailsToSend = new List<Messaging.SingleEmailMessage>();
        
        for (hic_signeasy__Transaction__c trans : transactions) {
            Id ownerId = null;
            Id agent2Id = null;
            Id targetId = null;
            
            if (trans.hic_signeasy__Lead__c != null && leadsMap.containsKey(trans.hic_signeasy__Lead__c)) {
                Lead l = leadsMap.get(trans.hic_signeasy__Lead__c);
                ownerId = l.OwnerId;
                agent2Id = l.Agent_2__c;
                targetId = l.Id;
            } else if (trans.hic_signeasy__Opportunity__c != null && oppsMap.containsKey(trans.hic_signeasy__Opportunity__c)) {
                Opportunity opp = oppsMap.get(trans.hic_signeasy__Opportunity__c);
                ownerId = opp.OwnerId;
                agent2Id = opp.Agent_2__c;
                targetId = opp.Id;
            }
            
            Set<String> recipients = new Set<String>();
            // Ensure owner is a user (not a queue)
            if (ownerId != null && ((String)ownerId).startsWith('005')) {
                recipients.add((String)ownerId);
            }
            if (agent2Id != null) {
                recipients.add((String)agent2Id);
            }
            
            // Send Custom Notification
            if (notifType != null && !recipients.isEmpty() && targetId != null) {
                Messaging.CustomNotification notif = new Messaging.CustomNotification();
                notif.setNotificationTypeId(notifType.Id);
                notif.setTitle('Proposal Signed via SignEasy');
                notif.setBody('The Obtain signed proposal step is completed.');
                notif.setTargetId(targetId);
                try {
                    notif.send(recipients);
                } catch (Exception e) {
                    System.debug('Error sending custom notification: ' + e.getMessage());
                }
            }
            
            // Prepare Emails
            if (emailTemp != null) {
                for (Id recId : recipients) {
                    Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
                    mail.setTemplateId(emailTemp.Id);
                    mail.setTargetObjectId(recId);
                    if (targetId != null && !((String)targetId).startsWith('00Q')) {
                        // WhatId cannot be a Lead. If it's a Lead, we don't set WhatId.
                        mail.setWhatId(targetId);
                    }
                    mail.setSaveAsActivity(false); // Target is User, so saveAsActivity must be false
                    emailsToSend.add(mail);
                }
            }
        }
        
        if (!emailsToSend.isEmpty()) {
            try {
                Messaging.sendEmail(emailsToSend, false);
            } catch (Exception e) {
                System.debug('Error sending emails: ' + e.getMessage());
            }
        }
    }
}