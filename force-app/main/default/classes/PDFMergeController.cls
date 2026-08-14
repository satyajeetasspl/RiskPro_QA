public with sharing class PDFMergeController {

    /**
     * @description Gets all PDF ContentDocument Ids linked to a specific record.
     * @param recordId The Id of the record.
     * @return List of ContentDocument Ids.
     */
    @AuraEnabled(cacheable=true)
    public static List<Id> getRecordPDFIds(Id recordId) {
        List<Id> docIds = new List<Id>();
        for (ContentDocumentLink cdl : [
            SELECT ContentDocumentId 
            FROM ContentDocumentLink 
            WHERE LinkedEntityId = :recordId
        ]) {
            docIds.add(cdl.ContentDocumentId);
        }
        
        // Filter to only include actual PDFs
        List<Id> pdfIds = new List<Id>();
        for (ContentVersion cv : [
            SELECT ContentDocumentId 
            FROM ContentVersion 
            WHERE ContentDocumentId IN :docIds AND FileType = 'PDF' AND IsLatest = true
        ]) {
            pdfIds.add(cv.ContentDocumentId);
        }
        return pdfIds;
    }

    /**
     * @description Fetches the Base64 data of the specified documents to send to the LWC.
     * @param contentDocumentIds List of ContentDocument Ids to fetch.
     * @return List of Maps containing 'Title' and 'Base64Data' for each document.
     */
    @AuraEnabled
    public static List<Map<String, String>> getBase64Documents(List<Id> contentDocumentIds) {
        if (contentDocumentIds == null || contentDocumentIds.isEmpty()) {
            throw new AuraHandledException('No documents provided for merging.');
        }

        try {
            List<ContentVersion> cvs = [
                SELECT Id, Title, VersionData, ContentDocumentId 
                FROM ContentVersion 
                WHERE ContentDocumentId IN :contentDocumentIds 
                AND IsLatest = true
            ];
            
            List<Map<String, String>> documents = new List<Map<String, String>>();
            for(ContentVersion cv : cvs) {
                Map<String, String> docMap = new Map<String, String>();
                docMap.put('Id', cv.ContentDocumentId);
                docMap.put('Title', cv.Title);
                docMap.put('Base64Data', EncodingUtil.base64Encode(cv.VersionData));
                documents.add(docMap);
            }
            
            return documents;
        } catch(Exception e) {
            throw new AuraHandledException('Error fetching documents: ' + e.getMessage());
        }
    }

    /**
     * @description Saves the merged PDF base64 string as a new ContentVersion back to Salesforce.
     * @param base64Data The merged PDF data.
     * @param outputName The desired file name for the new document.
     * @param linkedRecordId The record Id to link the document to.
     * @return The ContentDocumentId of the newly inserted merged PDF.
     */
    @AuraEnabled
    public static String saveMergedDocument(String base64Data, String outputName, Id linkedRecordId) {
        if (String.isBlank(base64Data)) {
            throw new AuraHandledException('No data provided to save.');
        }

        try {
            ContentVersion mergedCv = new ContentVersion();
            mergedCv.Title = outputName;
            mergedCv.PathOnClient = outputName.endsWithIgnoreCase('.pdf') ? outputName : outputName + '.pdf';
            mergedCv.VersionData = EncodingUtil.base64Decode(base64Data);
            if (linkedRecordId != null) {
                mergedCv.FirstPublishLocationId = linkedRecordId;
            }
            insert mergedCv;
            
            mergedCv = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :mergedCv.Id];
            return mergedCv.ContentDocumentId;
        } catch(Exception e) {
            throw new AuraHandledException('Error saving merged document: ' + e.getMessage());
        }
    }
}