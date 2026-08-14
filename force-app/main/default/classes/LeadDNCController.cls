// File: LeadDNCController.cls
public with sharing class LeadDNCController {
    
    @AuraEnabled
    public static void applyDNC(Id leadId) {
        if (leadId == null) {
            throw new AuraHandledException('Lead Id is required.');
        }

        // Query Lead
        Lead l = [SELECT Id, Do_Not_Call__c FROM Lead WHERE Id = :leadId LIMIT 1];

        // If already DNC, skip
        if (l.Do_Not_Call__c == true) {
            throw new AuraHandledException('This Lead is already marked as Do Not Call.');
        }

        // Update Lead flag
        l.Do_Not_Call__c = true;
        update l;

        // Delete future events
        List<Event> futureEvents = [
            SELECT Id 
            FROM Event 
            WHERE WhoId = :leadId 
              AND StartDateTime > :System.now()
        ];
        if (!futureEvents.isEmpty()) {
            delete futureEvents;
        }

        // Delete open tasks
        List<Task> openTasks = [
            SELECT Id 
            FROM Task 
            WHERE WhoId = :leadId 
              AND Status != 'Completed'
        ];
        if (!openTasks.isEmpty()) {
            delete openTasks;
        }

    }
}