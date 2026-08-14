public without sharing class QuoteAgencyHelper {
    
    /**
     * Processes waiver requests for quotes, generates tokens, and sends consolidated notification emails.
     * Runs in 'without sharing' to ensure system-level actions (tokens, emails, approvals) 
     * are not blocked by the end-user's limited permissions.
     */
    public static void processWaiverRequests(Id recordId, List<Policy_Information__c> quotesToUpsert) {
        if (recordId == null || quotesToUpsert == null || quotesToUpsert.isEmpty()) {
            return;
        }

        // 1. Generate tokens for waiver requests if missing
        List<Policy_Information__c> quotesWithTokens = new List<Policy_Information__c>();
        for (Policy_Information__c q : quotesToUpsert) {
            if (q.Agency_Fee_Waiver_Request__c == true && String.isBlank(q.Waiver_Token__c)) {
                // Generate a unique token for this specific quote
                q.Waiver_Token__c = EncodingUtil.convertToHex(Crypto.generateDigest('SHA-256', Blob.valueOf(q.Id + '-' + System.now().formatLong())));
                quotesWithTokens.add(new Policy_Information__c(Id = q.Id, Waiver_Token__c = q.Waiver_Token__c));
            }
        }
        
        if (!quotesWithTokens.isEmpty()) {
            update quotesWithTokens;
        }

        // 2. Prepare Approval Process Requests and Email Data
        List<Approval.ProcessSubmitRequest> approvalRequests = new List<Approval.ProcessSubmitRequest>();
        List<Policy_Information__c> pendingWaivers = new List<Policy_Information__c>();
        
        for (Policy_Information__c quote : quotesToUpsert) {
            if (quote.Agency_Fee_Waiver_Request__c == true && (quote.Agency_Fee_Waiver_Decision__c == 'Pending' || quote.Agency_Fee_Waiver_Decision__c == null)) {
                pendingWaivers.add(quote);
                
                // Prepare Approval Request
                Approval.ProcessSubmitRequest req = new Approval.ProcessSubmitRequest();
                req.setComments('Submitting request for agency fee waiver.');
                req.setObjectId(quote.Id);
                approvalRequests.add(req);
            }
        }

        if (pendingWaivers.isEmpty()) {
            return;
        }

        // 3. Initiate Approval Processes
        if (!approvalRequests.isEmpty()) {
            try {
                Approval.process(approvalRequests);
            } catch (Exception approvalEx) {
                System.debug('Approval Process could not be initiated automatically. Error: ' + approvalEx.getMessage());
            }
        }

        // 4. Send Consolidated Actionable Email
        String approverEmail = System.Label.Agency_Fee_Approver_Email;
        String baseUrl = System.Label.Agency_Waiver_Base_URL;
        
        if (String.isNotBlank(approverEmail)) {
            SObjectType sType = recordId.getSObjectType();
            String recordName = 'Record';
            String recordUrl = URL.getOrgDomainUrl().toExternalForm() + '/lightning/r/';
            
            if (sType == Lead.SObjectType) {
                Lead l = [SELECT Name FROM Lead WHERE Id = :recordId LIMIT 1];
                recordName = l.Name;
                recordUrl += 'Lead/' + recordId + '/view';
            } else if (sType == Opportunity.SObjectType) {
                Opportunity o = [SELECT Name FROM Opportunity WHERE Id = :recordId LIMIT 1];
                recordName = o.Name;
                recordUrl += 'Opportunity/' + recordId + '/view';
            }

            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setToAddresses(new String[] { approverEmail });
            mail.setSubject('Action Required: Agency Fee Waiver Requested for ' + sType.getDescribe().getLabel() + ' - ' + recordName);
            
            String htmlBody = '<div style="font-family: Arial, sans-serif; line-height: 1.6; color: #333; max-width: 800px;">' +
                              '<h2>Agency Fee Waiver Requested</h2>' +
                              '<p>One or more Agency Service Fee Waivers have been requested for <strong>' + recordName + '</strong>.</p>' +
                              '<p>Please review the details below and select an action for each quote:</p>' +
                              '<table style="width:100%; border-collapse: collapse; margin-top: 20px;">' +
                              '<thead>' +
                              '<tr style="background-color: #f2f2f2;">' +
                              '<th style="border: 1px solid #ddd; padding: 12px; text-align: left;">Carrier</th>' +
                              '<th style="border: 1px solid #ddd; padding: 12px; text-align: left;">Line of Business</th>' +
                              '<th style="border: 1px solid #ddd; padding: 12px; text-align: left;">Waiver Reason</th>' +
                              '<th style="border: 1px solid #ddd; padding: 12px; text-align: center;">Actions</th>' +
                              '</tr>' +
                              '</thead>' +
                              '<tbody>';

            for (Policy_Information__c quote : pendingWaivers) {
                String reasonText = String.isNotBlank(quote.Waiver_Reason__c) ? (quote.Waiver_Reason__c == 'Others' && String.isNotBlank(quote.Waiver_Comment__c) ? quote.Waiver_Reason__c + ' - ' + quote.Waiver_Comment__c : quote.Waiver_Reason__c) : (String.isNotBlank(quote.Waiver_Comment__c) ? quote.Waiver_Comment__c : 'No reason provided');

                htmlBody += '<tr>' +
                            '<td style="border: 1px solid #ddd; padding: 12px;">' + (quote.Carrier__c != null ? quote.Carrier__c : 'N/A') + '</td>' +
                            '<td style="border: 1px solid #ddd; padding: 12px;">' + (quote.Lines__c != null ? quote.Lines__c : 'N/A') + '</td>' +
                            '<td style="border: 1px solid #ddd; padding: 12px;">' + reasonText + '</td>' +
                            '<td style="border: 1px solid #ddd; padding: 12px; text-align: center; min-width: 200px;">' +
                                '<a href="' + recordUrl + '" style="background-color: #2e7d32; color: white; padding: 8px 15px; text-decoration: none; border-radius: 4px; font-weight: bold; margin-bottom: 5px; display: inline-block;">Accept</a> ' +
                                '<a href="' + recordUrl + '" style="background-color: #c62828; color: white; padding: 8px 15px; text-decoration: none; border-radius: 4px; font-weight: bold; display: inline-block;">Reject</a>' +
                            '</td>' +
                            '</tr>';
            }
            
            htmlBody += '</tbody></table>' +
                        '<p style="font-size: 14px; color: #777; margin-top: 30px;">This is an automated notification from the Agency Fee Management system.</p>' +
                        '</div>';
                        
            mail.setHtmlBody(htmlBody);
            
            try {
                Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ mail });
            } catch (Exception emailEx) {
                System.debug('Failed to send consolidated waiver notification email: ' + emailEx.getMessage());
            }
        }
    }
}