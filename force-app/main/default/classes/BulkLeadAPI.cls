@RestResource(urlMapping='/BulkLeads/*')
global with sharing class BulkLeadAPI {

    @HttpPost
    global static void processLeads() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        res.addHeader('Content-Type', 'application/json');

        BulkLeadAPIWrapper.Response responseWrapper = new BulkLeadAPIWrapper.Response();
        List<BulkLeadAPIWrapper.LeadInput> leadInputs = new List<BulkLeadAPIWrapper.LeadInput>();
        String requestBody = '';

        try {
            requestBody = req.requestBody != null ? req.requestBody.toString() : '';
            if (String.isBlank(requestBody)) {
                res.statusCode = 400;
                res.responseBody = Blob.valueOf('{"error": "Empty request body"}');
                return;
            }

            // Deserialize the list of leads
            leadInputs = (List<BulkLeadAPIWrapper.LeadInput>) JSON.deserialize(requestBody, List<BulkLeadAPIWrapper.LeadInput>.class);
            responseWrapper.totalReceived = leadInputs.size();

            List<Lead> leadsToInsert = new List<Lead>();

            // Setup DML Options to enforce Duplicate Rules during insert
            Database.DMLOptions dml = new Database.DMLOptions();
            dml.DuplicateRuleHeader.allowSave = false; // Ensures duplicate rules (like Email/Phone) block the save if they match
            dml.DuplicateRuleHeader.runAsCurrentUser = true;

            for (BulkLeadAPIWrapper.LeadInput input : leadInputs) {
                Lead newLead = new Lead();
                newLead.FirstName = input.FirstName;
                newLead.LastName = input.LastName;
                newLead.Company = String.isNotBlank(input.Company) ? input.Company : 'Unknown';
                newLead.Email = input.Email;
                newLead.Phone = input.Phone;
                newLead.Status = input.Status;
                newLead.Title = input.Title;
                newLead.LeadSource = input.LeadSource;
                newLead.Street = input.Street;
                newLead.City = input.City;
                newLead.State = input.State;
                newLead.PostalCode = input.PostalCode;
                newLead.Country = input.Country;

                // Apply DML options to each record
                newLead.setOptions(dml);
                leadsToInsert.add(newLead);
            }

            // Insert records with partial success allowed (allOrNone = false)
            if (!leadsToInsert.isEmpty()) {
                Database.SaveResult[] results = Database.insert(leadsToInsert, false);
                List<String> allErrorsForLog = new List<String>();

                for (Integer i = 0; i < results.size(); i++) {
                    Database.SaveResult sr = results[i];
                    if (sr.isSuccess()) {
                        responseWrapper.successCount++;
                        responseWrapper.successes.add(new BulkLeadAPIWrapper.LeadResult(sr.getId()));
                    } else {
                        responseWrapper.failedCount++;
                        List<String> errorMessages = new List<String>();
                        for (Database.Error err : sr.getErrors()) {
                            errorMessages.add(err.getMessage());
                        }
                        String combinedError = String.join(errorMessages, '; ');
                        responseWrapper.errors.add(new BulkLeadAPIWrapper.ErrorResult(combinedError, leadInputs[i]));
                        allErrorsForLog.add('Lead Index ' + i + ' (' + leadInputs[i].Email + '): ' + combinedError);
                    }
                }

                // Log the summary and any errors using Nebula Logger
                Logger.info('BulkLeadAPI processed ' + responseWrapper.totalReceived + ' leads. Successes: ' + responseWrapper.successCount + ', Failures: ' + responseWrapper.failedCount);
                if (!allErrorsForLog.isEmpty()) {
                    for (String errMsg : allErrorsForLog) {
                        Logger.error(errMsg);
                    }
                }
                Logger.saveLog();

                // Send email alert for lead processing results
                EmailAlertUtility.sendLeadProcessingEmail(
                    'BulkLeadAPI_Payload',
                    responseWrapper.totalReceived,
                    responseWrapper.successCount,
                    responseWrapper.failedCount,
                    allErrorsForLog
                );
            }
            res.statusCode = 200;
            res.responseBody = Blob.valueOf(JSON.serializePretty(responseWrapper));

        } catch (Exception e) {
            // Log the critical exception using Nebula Logger
            Logger.error('Critical Error in BulkLeadAPI', e);
            Logger.saveLog();

            res.statusCode = 500;
            res.responseBody = Blob.valueOf('{"error": "' + e.getMessage() + '"}');
        }
    }
}