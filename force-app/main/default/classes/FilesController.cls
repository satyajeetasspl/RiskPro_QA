public with sharing class FilesController {

    @AuraEnabled(cacheable=true)
    public static List<ContentDocumentLink> getFilesForRecord(Id recordId) {

        if (recordId == null) {
            return new List<ContentDocumentLink>();
        }

        return [
            SELECT
                Id,
                ContentDocumentId,
                ContentDocument.Title,
                ContentDocument.Description,
                ContentDocument.CreatedDate,
                ContentDocument.CreatedBy.Name,
                ContentDocument.LatestPublishedVersion.Id,
                ContentDocument.LatestPublishedVersion.FileExtension,
                ContentDocument.LatestPublishedVersion.Type__c
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :recordId
            AND ContentDocument.LatestPublishedVersion.FileType != 'SNOTE'
            ORDER BY ContentDocument.CreatedDate DESC
        ];
    }
}