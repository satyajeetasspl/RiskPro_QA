public with sharing class CadenceAssigneeService {

    // ---- TEST HOOK: set to true from tests to force invoking the Flow path ----
    // Visible to tests only and defaults to false in normal runs.
    @TestVisible
    public static Boolean TEST_FORCE_INVOKE_FLOW = false;
    // ----------------------------------------------------------------------------

    public static void handleOwnerChanges(List<Lead> newList, Map<Id, Lead> oldMap) {
        if (newList == null || newList.isEmpty()) return;

        // Gather leads whose owner changed
        Set<Id> changedLeadIds = new Set<Id>();
        Map<Id, Id> leadToNewOwner = new Map<Id, Id>();
        for (Lead ld : newList) {
            Lead oldLd = oldMap.get(ld.Id);
            if (oldLd == null) continue;
            if (ld.OwnerId != oldLd.OwnerId && ld.OwnerId != null) {
                changedLeadIds.add(ld.Id);
                leadToNewOwner.put(ld.Id, ld.OwnerId);
            }
        }
        if (changedLeadIds.isEmpty()) return;

        // Find active (Running) cadence trackers per lead
        List<AggregateResult> ar = [
            SELECT TargetId t, COUNT(Id) c
            FROM ActionCadenceTracker
            WHERE TargetId IN :changedLeadIds
              AND IsTrackerActive = true
              AND State = 'Running'
            GROUP BY TargetId
        ];
        Set<Id> eligibleLeads = new Set<Id>();
        Map<Id, Integer> activeCounts = new Map<Id, Integer>();
        for (AggregateResult row : ar) {
            Id t = (Id) row.get('t');
            Integer c = (Integer) row.get('c');
            if (c != null && c > 0) {
                eligibleLeads.add(t);
                activeCounts.put(t, c);
            }
        }

        // -------- TEST HOOK: when running tests, optionally force invocation for changed leads -------
        if (Test.isRunningTest() && TEST_FORCE_INVOKE_FLOW) {
            for (Id forced : changedLeadIds) {
                if (!eligibleLeads.contains(forced)) {
                    eligibleLeads.add(forced);
                    activeCounts.put(forced, (activeCounts.containsKey(forced) ? activeCounts.get(forced) : 1));
                }
            }
        }
        // --------------------------------------------------------------------------------------------

        if (eligibleLeads.isEmpty()) return;

        // Invoke Flow once per eligible lead (works for multiple active cadences)
        for (Id leadId : eligibleLeads) {
            Id newOwnerId = leadToNewOwner.get(leadId);
            Map<String, Object> ip = new Map<String, Object>{
                'varTargetId' => String.valueOf(leadId),
                'varNewAssigneeUserId' => String.valueOf(newOwnerId)
            };
            try {
                System.debug('Cadence transfer for Lead ' + leadId +
                             ' active trackers=' + activeCounts.get(leadId));
                new Flow.Interview.Change_Cadence_Assignee_Flow(ip).start();
            } catch (Exception e) {
                System.debug('Cadence transfer failed for Lead ' + leadId + ': ' + e.getMessage());
            }
        }
    }
}