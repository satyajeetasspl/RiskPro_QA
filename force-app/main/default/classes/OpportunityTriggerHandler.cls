public with sharing class OpportunityTriggerHandler implements TriggerInterface {
    public OpportunityTriggerHandler() {
        System.debug('### OpportunityTriggerHandler Constructor Fired!');
    }
    public void beforeInsert(List<SObject> newRecords) {}
    public void beforeUpdate(Map<Id, SObject> mapNewRecords, Map<Id, SObject> mapOldRecords) {}
    public void beforeDelete(Map<Id, SObject> mapOldRecords) {}
    public void afterInsert(Map<Id, SObject> mapNewRecords) {}
    public void afterDelete(Map<Id, SObject> mapOldRecords) {}
    public void afterUnDelete(Map<Id, SObject> mapNewRecords) {}

    public void afterUpdate(Map<Id, SObject> mapNewRecords, Map<Id, SObject> mapOldRecords) {
        System.debug('### OpportunityTriggerHandler: afterUpdate Started');

        List<Case> casesToInsert = new List<Case>();
        Id nbcQueueId;
        List<Group> queues = [SELECT Id FROM Group WHERE Type = 'Queue' AND Name = 'NBC Queue' LIMIT 1];
        System.debug('### Queues found: ' + queues.size());
        if (!queues.isEmpty()) {
            nbcQueueId = queues[0].Id;
            System.debug('### NBC Queue Id: ' + nbcQueueId);
        }

        // Collect accounts to check for existing NBC cases to avoid duplicates
        Set<Id> accountIdsToCheck = new Set<Id>();
        List<Opportunity> candidateOpps = new List<Opportunity>();

        for (Id oppId : mapNewRecords.keySet()) {
            Opportunity newOpp = (Opportunity) mapNewRecords.get(oppId);
            Opportunity oldOpp = (Opportunity) mapOldRecords.get(oppId);

            Boolean isNbcNow = (newOpp.Is_NBC__c == true);
            Boolean isNbcStage = (newOpp.StageName == 'NBC' || newOpp.StageName == 'Closed Won');
            Boolean stageOrNbcChanged = (oldOpp.StageName != newOpp.StageName || oldOpp.Is_NBC__c != newOpp.Is_NBC__c);

            if (isNbcNow && isNbcStage && stageOrNbcChanged) {
                candidateOpps.add(newOpp);
                if (newOpp.AccountId != null) {
                    accountIdsToCheck.add(newOpp.AccountId);
                }
            }
        }

        Map<Id, Set<String>> existingCaseSubjectsByAccId = new Map<Id, Set<String>>();
        if (!accountIdsToCheck.isEmpty()) {
            for (Case c : [SELECT Id, AccountId, Subject FROM Case WHERE AccountId IN :accountIdsToCheck]) {
                if (!existingCaseSubjectsByAccId.containsKey(c.AccountId)) {
                    existingCaseSubjectsByAccId.put(c.AccountId, new Set<String>());
                }
                if (String.isNotBlank(c.Subject)) {
                    existingCaseSubjectsByAccId.get(c.AccountId).add(c.Subject.trim().toLowerCase());
                }
            }
        }

        for (Opportunity newOpp : candidateOpps) {
            String oppName = String.isNotBlank(newOpp.Name) ? newOpp.Name : 'Opportunity';
            String targetSubject = 'NBC - ' + oppName.trim();
            
            // Check if duplicate case already exists for this account with same NBC subject
            Set<String> existingSubjects = existingCaseSubjectsByAccId.get(newOpp.AccountId);
            if (existingSubjects != null && existingSubjects.contains(targetSubject.toLowerCase())) {
                System.debug('### Skipping Case creation - duplicate NBC Case already exists for Account: ' + newOpp.AccountId);
                continue;
            }

            Case convCase = new Case();
            convCase.Subject = targetSubject;
            convCase.Origin = 'Opportunity Closed Won';
            convCase.AccountId = newOpp.AccountId;
            convCase.Priority = 'Medium';
            convCase.OwnerId = (nbcQueueId != null) ? nbcQueueId : newOpp.OwnerId;

            casesToInsert.add(convCase);
            System.debug('### Case added to list: ' + convCase);
        }

        System.debug('### Total Cases to insert: ' + casesToInsert.size());
        if (!casesToInsert.isEmpty()) {
            try {
                insert casesToInsert;
                System.debug('### NBC Cases inserted for Opportunities successfully');
            } catch (Exception e) {
                System.debug('### Case error: ' + e.getMessage());
            }
        }
        System.debug('### OpportunityTriggerHandler: afterUpdate Finished');
    }
}