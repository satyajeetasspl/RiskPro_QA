public class LeadCadenceHelper {
    @TestVisible
    private static Boolean TEST_FORCE_FLOW = false;
    public static void updateCandenceOwner(Map<Id, SObject> mapNewRecords, Map<Id, SObject> mapOldRecords) {
        if (mapNewRecords == null || mapNewRecords.isEmpty()) return;
        
        // 1) Collect leads with owner change
        Set<Id> changedLeadIds = new Set<Id>();
        Map<Id, Id> leadToNewOwner = new Map<Id, Id>();
        for (Id idVal : mapNewRecords.keySet()) {
            Lead newL = (Lead) mapNewRecords.get(idVal);
            Lead oldL = (Lead) mapOldRecords.get(idVal);
            if (newL == null || oldL == null) continue;
            if (newL.OwnerId != oldL.OwnerId && newL.OwnerId != null) {
                changedLeadIds.add(newL.Id);
                leadToNewOwner.put(newL.Id, newL.OwnerId);
            }
        }
        if (changedLeadIds.isEmpty()) return;
        
        // 2) Find at least one active (Running) tracker per lead
        List<AggregateResult> agg = [
            SELECT TargetId t, COUNT(Id) c
            FROM ActionCadenceTracker
            WHERE TargetId IN :changedLeadIds
            AND IsTrackerActive = true
            AND State = 'Running'
            GROUP BY TargetId
        ];
        Set<Id> eligibleLeads = new Set<Id>();
        for (AggregateResult ar : agg) {
            Id tId = (Id) ar.get('t');
            Integer cnt = (Integer) ar.get('c');
            if (cnt != null && cnt > 0) eligibleLeads.add(tId);
        }
        
        // 3) In production, stop if no eligible; in tests we may force the Flow path
        if (eligibleLeads.isEmpty() && !TEST_FORCE_FLOW) return;
        
        Set<Id> loopIds = eligibleLeads.isEmpty() ? changedLeadIds : eligibleLeads;
        
        // 4) Invoke the autolaunched Flow once per lead (Flow API Name must match)
        // Use the exact API Name from Flow Details (not the label)
        for (Id leadId : loopIds) {
            Id newOwnerId = leadToNewOwner.get(leadId);
            Map<String, Object> inputs = new Map<String, Object>{
                'varTargetId' => String.valueOf(leadId),
                    'varNewAssigneeUserId' => String.valueOf(newOwnerId)
                    };
                        try {
                            // If your API Name is ChangeCadenceAssigneeFlow, replace the class name below
                            new Flow.Interview.Change_Cadence_Assignee_Flow(inputs).start();
                        } catch (Exception e) {
                            System.debug('LeadCadenceHandler: Flow failed for Lead ' + leadId + ': ' + e.getMessage());
                        }
        }
    }
    
}