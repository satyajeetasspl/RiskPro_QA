public with sharing class LeadFilesController {

    @AuraEnabled(cacheable=true)
    public static List<ContentDocumentLink> getFilesForLead(Id leadId) {

        // Safety check
        if (leadId == null) {
            return new List<ContentDocumentLink>();
        }

        /*
         * IMPORTANT:
         * - File metadata lives on ContentDocument
         * - Custom/global picklist Type__c lives on ContentVersion
         * - Always traverse through LatestPublishedVersion
         */

        return [
            SELECT
                Id,
                ContentDocumentId,

                /* ContentDocument fields */
                ContentDocument.Title,
                ContentDocument.Description,
                ContentDocument.CreatedDate,
                ContentDocument.CreatedBy.Name,

                /* Latest ContentVersion fields */
                ContentDocument.LatestPublishedVersion.Id,
                ContentDocument.LatestPublishedVersion.FileExtension,
                ContentDocument.LatestPublishedVersion.Type__c

            FROM ContentDocumentLink
            WHERE LinkedEntityId = :leadId

            // Optional: exclude Salesforce Notes if you ever need it
            // AND ContentDocument.LatestPublishedVersion.FileType != 'SNOTE'

            ORDER BY ContentDocument.CreatedDate DESC
        ];
    }
}