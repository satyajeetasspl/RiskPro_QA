public with sharing class LeadEmailInvoker {

    @InvocableMethod(label='Send Processor Email')
    public static void sendEmail(List<Request> requests) {

        System.debug('=== LeadEmailInvoker: START ===');
        System.debug('Incoming Requests: ' + JSON.serialize(requests));

        for (Request req : requests) {
            System.debug('--- Processing New Request ---');

            if (req.leadId == null) {
                System.debug('Missing LeadId, skipping.');
                continue;
            }

            Lead leadRecord = [
                SELECT Id,
                       FirstName,
                       LastName,
                       Loan__c,
                       Processor_Email__c,
                       Processor_Name__c,
                       Owner.Name,
                       Owner.Email
                FROM Lead
                WHERE Id = :req.leadId
                LIMIT 1
            ];

            System.debug('Lead Record: ' + JSON.serialize(leadRecord));

            if (leadRecord.Processor_Email__c == null) {
                System.debug('❌ ERROR: Processor email is null. Stopping.');
                continue;
            }

            String subjectText =
                (leadRecord.FirstName != null ? leadRecord.FirstName : '') +
                (leadRecord.LastName != null ? ' ' + leadRecord.LastName : '') +
                ' - ' + (leadRecord.Loan__c != null ? leadRecord.Loan__c : '') +
                ' - Quote Request Received';

            String bodyHtml =
                'Hello <b>' + (leadRecord.Processor_Name__c != null ? leadRecord.Processor_Name__c : '') + '</b>,<br/><br/>' +
                'The quote request for <b>' +
                    (leadRecord.FirstName != null ? leadRecord.FirstName : '') + ' ' +
                    (leadRecord.LastName != null ? leadRecord.LastName : '') +
                '</b> — Loan #: <b>' + (leadRecord.Loan__c != null ? leadRecord.Loan__c : '') + '</b>' +
                ' has been received and has been assigned to <b>' +
                    (leadRecord.Owner.Name != null ? leadRecord.Owner.Name : '') +
                '</b> (' + (leadRecord.Owner.Email != null ? leadRecord.Owner.Email : '') + ').<br/><br/>' +
                'Please allow us one business day to complete and return the quote. ' +
                'If a response has not been received within that time, please escalate this to management ' +
                'by emailing williambakow@myriskpros.com.<br/><br/>' +
                'Thank you!<br/>' +
                'The Risk Pros Team<br/>' +
                '614-647-9644';

            System.debug('Email Subject: ' + subjectText);
            System.debug('Email Body (HTML): ' + bodyHtml);

            try {
                Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();

                email.setToAddresses(new String[]{ leadRecord.Processor_Email__c });
                email.setSubject(subjectText);
                email.setHtmlBody(bodyHtml);
                email.setTreatTargetObjectAsRecipient(false);
                email.setSaveAsActivity(false);

                System.debug('Sending Email...');
                Messaging.SendEmailResult[] result =
                    Messaging.sendEmail(new Messaging.SingleEmailMessage[]{ email });

                System.debug('SendEmail Result: ' + JSON.serialize(result));
            }
            catch (Exception e) {
                System.debug('❌ APEX ERROR: ' + e.getMessage());
                System.debug(e.getStackTraceString());
            }
        }

        System.debug('=== LeadEmailInvoker: END ===');
    }

    public class Request {
        @InvocableVariable(required=true)
        public Id leadId;
    }
}