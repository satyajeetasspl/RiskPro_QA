public with sharing class EmailAlertUtility {

    public static void sendLeadProcessingEmail(String fileName, Integer totalLeads, Integer successCount, Integer failedCount, List<String> errorMessages) {
        try {
            String toAddress = Label.Lead_Integration_Owner_Email;
            
            if (String.isBlank(toAddress)) {
                System.debug('EmailAlertUtility: No recipient email address defined in Label.Lead_Integration_Owner_Email');
                return;
            }
            
            String displayFileName = String.isNotBlank(fileName) ? fileName : 'API Payload';
            
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setToAddresses(new List<String>{ toAddress });
            mail.setSubject('Lead Processing Status - ' + displayFileName);
            
            String htmlBody = '<div style="font-family: Arial, sans-serif;">';
            htmlBody += '<p>Hello Team,</p>';
            htmlBody += '<p>The lead processing has been completed successfully.</p>';
            htmlBody += '<br/>';
            htmlBody += '<h3>Processing Summary:</h3>';
            htmlBody += '<ul>';
            htmlBody += '<li><b>File Name:</b> ' + displayFileName + '</li>';
            htmlBody += '<li><b>Number of Leads Passed:</b> ' + successCount + '</li>';
            htmlBody += '<li><b>Number of Leads Failed:</b> <span style="' + (failedCount > 0 ? 'color: red;' : 'color: green;') + '">' + failedCount + '</span></li>';
            htmlBody += '<li><b>Processed Date & Time:</b> ' + System.now().format() + '</li>';
            htmlBody += '</ul>';
            
            htmlBody += '<p>Please review the failed leads if any further action is required.</p>';
            htmlBody += '<p>Regards,<br/>Automation System</p>';
            
            if (failedCount > 0 && errorMessages != null && !errorMessages.isEmpty()) {
                htmlBody += '<br/><h3>Failure Reasons / Errors:</h3>';
                htmlBody += '<table style="border-collapse: collapse; width: 100%; border: 1px solid #ddd;">';
                htmlBody += '<tr style="background-color: #f2f2f2;"><th style="border: 1px solid #ddd; padding: 8px; text-align: left;">Error Detail</th></tr>';
                
                for (String errMsg : errorMessages) {
                    htmlBody += '<tr><td style="border: 1px solid #ddd; padding: 8px;">' + errMsg.escapeHtml4() + '</td></tr>';
                }
                
                htmlBody += '</table>';
            }
            
            htmlBody += '</div>';
            
            mail.setHtmlBody(htmlBody);
            
            List<Messaging.SendEmailResult> results = Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ mail }, false);
            
            for (Messaging.SendEmailResult res : results) {
                if (!res.isSuccess()) {
                    List<String> errMsgs = new List<String>();
                    for (Messaging.SendEmailError err : res.getErrors()) {
                        errMsgs.add(err.getMessage());
                    }
                    Logger.error('EmailAlertUtility Failed to Send Email: ' + String.join(errMsgs, '; '));
                    Logger.saveLog();
                }
            }
            
        } catch (Exception ex) {
            Logger.error('Exception in EmailAlertUtility.sendLeadProcessingEmail: ' + ex.getMessage(), ex);
            Logger.saveLog();
        }
    }
}