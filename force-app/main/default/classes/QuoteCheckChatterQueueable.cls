public class QuoteCheckChatterQueueable implements Queueable {
    
    private Id parentRecordId;
    private List<QuoteCheckController.QuoteSaveRequest> requests;
    private List<Policy_Information__c> savedPolicies;

    public QuoteCheckChatterQueueable(Id parentRecordId, List<QuoteCheckController.QuoteSaveRequest> requests, List<Policy_Information__c> savedPolicies) {
        this.parentRecordId = parentRecordId;
        this.requests = requests;
        this.savedPolicies = savedPolicies;
    }

    public void execute(QueueableContext context) {
        List<ContentDocumentLink> fileLinksToInsert = new List<ContentDocumentLink>();
        String baseUrl = URL.getOrgDomainUrl().toExternalForm();
        String networkId = Network.getNetworkId();

        // 1. Handle Consolidation
        ConnectApi.FeedItemInput combinedPost = new ConnectApi.FeedItemInput();
        ConnectApi.MessageBodyInput combinedBody = new ConnectApi.MessageBodyInput();
        combinedBody.messageSegments = new List<ConnectApi.MessageSegmentInput>();
        Boolean hasContent = false;
        Set<String> allFileIds = new Set<String>();

        for (Integer i = 0; i < requests.size(); i++) {
            QuoteCheckController.QuoteSaveRequest req = requests[i];
            if (i >= savedPolicies.size()) break;
            Policy_Information__c p = savedPolicies[i]; 

            // Track files for linking
            if (req.fileIdsToAttach != null) {
                for (String fId : req.fileIdsToAttach) {
                    allFileIds.add(fId);
                    fileLinksToInsert.add(new ContentDocumentLink(
                        LinkedEntityId = p.Id, 
                        ContentDocumentId = fId,
                        ShareType = 'V', Visibility = 'AllUsers'
                    ));
                }
            }

            // Group Chatter Text
            if (String.isNotBlank(req.chatterText)) {
                hasContent = true;
                ConnectApi.TextSegmentInput textSeg = new ConnectApi.TextSegmentInput();
                textSeg.text = '\n[' + (p.Lines__c != null ? p.Lines__c : 'Quote') + ']: ' + req.chatterText;
                combinedBody.messageSegments.add(textSeg);
            }
        }

        // Post ONE time if there are files or text
        if (hasContent || !allFileIds.isEmpty()) {
            if (!allFileIds.isEmpty()) {
                ConnectApi.FilesCapabilityInput filesInput = new ConnectApi.FilesCapabilityInput();
                filesInput.items = new List<ConnectApi.FileIdInput>();
                for (String fId : allFileIds) {
                    ConnectApi.FileIdInput idInput = new ConnectApi.FileIdInput();
                    idInput.id = fId;
                    filesInput.items.add(idInput);
                }
                ConnectApi.FeedElementCapabilitiesInput capabilities = new ConnectApi.FeedElementCapabilitiesInput();
                capabilities.files = filesInput;
                combinedPost.capabilities = capabilities;
                
                if (!hasContent) {
                    ConnectApi.TextSegmentInput fileNote = new ConnectApi.TextSegmentInput();
                    fileNote.text = 'New files attached during Quote Check.';
                    combinedBody.messageSegments.add(fileNote);
                }
            }
            
            combinedPost.body = combinedBody;
            combinedPost.subjectId = this.parentRecordId;
            if (!Test.isRunningTest()) {
                ConnectApi.ChatterFeeds.postFeedElement(networkId, combinedPost);
            }
        }

        if (!fileLinksToInsert.isEmpty()) {
            Database.insert(fileLinksToInsert, false);
        }
    }
}