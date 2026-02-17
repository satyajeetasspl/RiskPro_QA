public with sharing class CaseToLeadController {

    private static final Pattern RAPID_PATTERN = Pattern.compile('(?i)Rapid\\s*(Home|HL|Lending)?');

    @AuraEnabled
    public static String caseToLead(Id caseId) {
        if (caseId == null) {
            throw new AuraHandledException('Case Id is required.');
        }

        Case c = [SELECT Id, Description FROM Case WHERE Id = :caseId LIMIT 1];

        if (String.isBlank(c.Description)) {
            throw new AuraHandledException('The Case Description is empty. Cannot generate a lead.');
        }

        try {
            List<Lead> leads = CreateLeadFromCaseHandler.parseDescription(new List<Id>{ c.Id });

            if (leads.isEmpty() || leads[0] == null) {
                throw new AuraHandledException('No valid lead data found in the Case Description.');
            }

            Lead newLead = leads[0];
            String description = c.Description;

            Matcher rapidMatcher = RAPID_PATTERN.matcher(description);
            Boolean isRapid = rapidMatcher.find();

            if (isRapid) {
                System.debug('Detected Rapid Variation: ' + rapidMatcher.group());
                newLead.Company = 'N/A';
                newLead.Referral_Source_Name__c = 'Rapid Home Lending';
                newLead.LeadSource = 'Partner';
                newLead.Can_we_contact_the_borrower_directly__c = 'Yes - you can call the prospect directly';
                newLead.Partner_Name__c = 'Rapid Home Lending';
            } 
            else if (description.containsIgnoreCase('Lead Type: Homeowners')) {
                newLead.Referral_Source_Name__c = 'Homeowners';
                if (String.isBlank(newLead.Company)) {
                    newLead.Company = 'Individual';
                }
            }

            Database.SaveResult[] results = Database.insert(new List<Lead>{newLead}, false);

            for (Database.SaveResult sr : results) {
                if (!sr.isSuccess()) {
                    String finalErrorMessage = '';
                    for (Database.Error err : sr.getErrors()) {
                        if (err instanceof Database.DuplicateError) {
                            finalErrorMessage = 'A lead with similar information already exists. Please search for the existing lead to avoid creating duplicates.';
                            break; 
                        } else {
                            finalErrorMessage = err.getMessage();
                        }
                    }
                    throw new AuraHandledException(finalErrorMessage);
                }
            }

            copyFilesToLead(c.Id, newLead.Id);

            return 'Lead created successfully with Id: ' + newLead.Id;

        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (Exception e) {
            System.debug('An unexpected error occurred in CaseToLeadController: ' + e.getMessage());
            throw new AuraHandledException('An unexpected error occurred: ' + e.getMessage());
        }
    }

    @AuraEnabled(cacheable=false)
    public static void deleteCase(Id caseId) {
        try {
            Case caseToDelete = new Case(Id = caseId);
            delete caseToDelete;
        } catch (Exception e) {
            throw new AuraHandledException('Could not delete the original case: ' + e.getMessage());
        }
    }

    @TestVisible
    private static void copyFilesToLead(Id caseId, Id leadId) {
        Set<Id> contentDocumentIds = new Set<Id>();
        List<ContentDocumentLink> newLinks = new List<ContentDocumentLink>();

        Set<Id> entityIds = new Set<Id>();
        entityIds.add(caseId); // Add the Case ID

        for(EmailMessage em : [SELECT Id FROM EmailMessage WHERE ParentId = :caseId]) {
            entityIds.add(em.Id);
        }

        List<ContentDocumentLink> allLinks = [
            SELECT ContentDocumentId, ContentDocument.ContentSize 
            FROM ContentDocumentLink 
            WHERE LinkedEntityId IN :entityIds
        ];

        for (ContentDocumentLink link : allLinks) {
            // Filter: Ignore files smaller than 5KB (Signatures/Logos)
            if (link.ContentDocument.ContentSize < 5120) {
                continue; 
            }

            if (contentDocumentIds.contains(link.ContentDocumentId)) {
                continue;
            }
            contentDocumentIds.add(link.ContentDocumentId);

            ContentDocumentLink cdl = new ContentDocumentLink();
            cdl.ContentDocumentId = link.ContentDocumentId;
            cdl.LinkedEntityId = leadId; 
            cdl.ShareType = 'V'; 
            newLinks.add(cdl);
        }

        if (!newLinks.isEmpty()) {
            Database.insert(newLinks, false);
        }
    }
}