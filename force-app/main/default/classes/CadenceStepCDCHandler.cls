public class CadenceStepCDCHandler {
    private static final Set<String> CONNECT_OUTCOMES = new Set<String>{ 'Meaningful Connect' };
    private static final Set<String> REPLY_OUTCOMES = new Set<String>{ 'Replied', 'Reply', 'Email Replied', 'SMS Replied' };

    // Make sure the signature exactly matches the Trigger.New type
    public static void process(List<ActionCadenceStepTrackerChangeEvent> events) {
        if (events == null || events.isEmpty()) {
            System.debug('Handler: No events received.');
            return;
        }

        System.debug('Handler: Received ' + events.size() + ' events');

        Set<Id> leadIds = new Set<Id>();
        Integer i = 0;

        for (ActionCadenceStepTrackerChangeEvent e : events) {
            i++;

            // ----- Safely read ChangeType from ChangeEventHeader -----
            // ChangeEventHeader is provided as a Map when accessed via e.get(...)
            String changeType = null;
            Object rawHeader = e.get('ChangeEventHeader');
            if (rawHeader != null && rawHeader instanceof Map<String, Object>) {
                Map<String, Object> hdr = (Map<String, Object>) rawHeader;
                // Key is 'changeType' (lowercase c) in the header map
                if (hdr.containsKey('changeType')) {
                    changeType = (String) hdr.get('changeType');
                }
            }

            // ----- Read fields using e.get(...) (works with namespaced fields) -----
            String state    = (String) e.get('State__c');
            String outcome  = (String) e.get('Outcome__c');
            String stepType = (String) e.get('StepType__c');
            Id     targetId = (Id)     e.get('TargetId__c');

            System.debug('Event #' + i + ' — changeType=' + changeType
                         + ', state=' + state
                         + ', outcome=' + outcome
                         + ', stepType=' + stepType
                         + ', targetId=' + targetId);

            // Only handle CREATE / UPDATE
            if (changeType != 'CREATE' && changeType != 'UPDATE') {
                System.debug('Event #' + i + ' skipped: changeType not CREATE/UPDATE');
                continue;
            }

            if (state == null || !state.equalsIgnoreCase('Completed')) {
                System.debug('Event #' + i + ' skipped: state is not Completed');
                continue;
            }

            Boolean isConnect = (outcome != null && CONNECT_OUTCOMES.contains(outcome));
            Boolean isReply = (outcome != null && REPLY_OUTCOMES.contains(outcome)
                                && (stepType == null
                                    || stepType.equalsIgnoreCase('Email')
                                    || stepType.equalsIgnoreCase('SMS')));

            if ((isConnect || isReply) && targetId != null && String.valueOf(targetId).startsWith('00Q')) {
                System.debug('Event #' + i + ' qualifies. Adding Lead Id ' + targetId);
                leadIds.add(targetId);
            } else {
                System.debug('Event #' + i + ' does not qualify. isConnect=' + isConnect + ', isReply=' + isReply);
            }
        }

        if (leadIds.isEmpty()) {
            System.debug('Handler: No qualifying Lead Ids to update.');
            return;
        }

        System.debug('Handler: Fetching Leads to update. Ids=' + leadIds);

        List<Lead> leads = [
            SELECT Id, Status
            FROM Lead
            WHERE Id IN :leadIds
              AND Status = 'New'
            FOR UPDATE
        ];

        System.debug('Handler: Leads fetched with Status=New: ' + leads.size());

        if (leads.isEmpty()) {
            return;
        }

        for (Lead l : leads) {
            System.debug('Updating Lead ' + l.Id + ' Status: New -> Contacted');
            l.Status = 'Contacted';
        }

        update leads;

        System.debug('Handler: Update complete for ' + leads.size() + ' leads.');
    }
}