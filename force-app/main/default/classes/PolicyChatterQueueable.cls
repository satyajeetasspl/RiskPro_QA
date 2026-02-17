public class PolicyChatterQueueable implements Queueable {
    
    private Id parentRecordId;
    private List<PolicyCheckController.PolicySaveRequest> requests;
    private List<Policy_Information__c> savedPolicies;

    // Constructor to pass data from the Controller to this Job
    public PolicyChatterQueueable(Id parentRecordId, List<PolicyCheckController.PolicySaveRequest> requests, List<Policy_Information__c> savedPolicies) {
        this.parentRecordId = parentRecordId;
        this.requests = requests;
        this.savedPolicies = savedPolicies;
    }

    public void execute(QueueableContext context) {
        List<ContentDocumentLink> fileLinksToInsert = new List<ContentDocumentLink>();
        String baseUrl = URL.getOrgDomainUrl().toExternalForm();
        String networkId = Network.getNetworkId();

        for (Integer i = 0; i < requests.size(); i++) {
            PolicyCheckController.PolicySaveRequest req = requests[i];
            // Ensure we don't go out of bounds if lists don't match (safety check)
            if (i >= savedPolicies.size()) break;
            
            Policy_Information__c p = savedPolicies[i]; 

            // 1. Handle Chatter Logic
            if (String.isNotBlank(req.chatterText) || String.isNotBlank(req.fileIdToAttach)) {
                ConnectApi.FeedItemInput feedItemInput = new ConnectApi.FeedItemInput();
                ConnectApi.MessageBodyInput messageBodyInput = new ConnectApi.MessageBodyInput();
                messageBodyInput.messageSegments = new List<ConnectApi.MessageSegmentInput>();

                // -- Build Message Segments (Link to Policy) --
                ConnectApi.MarkupBeginSegmentInput linkStart = new ConnectApi.MarkupBeginSegmentInput();
                linkStart.markupType = ConnectApi.MarkupType.Hyperlink;
                linkStart.url = baseUrl + '/' + p.Id;
                messageBodyInput.messageSegments.add(linkStart);

                ConnectApi.TextSegmentInput linkText = new ConnectApi.TextSegmentInput();
                linkText.text = (p.Lines__c != null ? p.Lines__c : 'Policy');
                messageBodyInput.messageSegments.add(linkText);

                ConnectApi.MarkupEndSegmentInput linkEnd = new ConnectApi.MarkupEndSegmentInput();
                linkEnd.markupType = ConnectApi.MarkupType.Hyperlink;
                messageBodyInput.messageSegments.add(linkEnd);

                ConnectApi.TextSegmentInput separator = new ConnectApi.TextSegmentInput();
                separator.text = ' — ';
                messageBodyInput.messageSegments.add(separator);

                // -- User Mention --
                if (String.isNotBlank(req.mentionUserId)) {
                    ConnectApi.MentionSegmentInput userMention = new ConnectApi.MentionSegmentInput();
                    userMention.id = req.mentionUserId;
                    messageBodyInput.messageSegments.add(userMention);
                    
                    ConnectApi.TextSegmentInput space = new ConnectApi.TextSegmentInput();
                    space.text = ' ';
                    messageBodyInput.messageSegments.add(space);
                }

                // -- Text Body --
                ConnectApi.TextSegmentInput textSegment = new ConnectApi.TextSegmentInput();
                if (String.isNotBlank(req.chatterText)) {
                    textSegment.text = req.chatterText;
                } else {
                    textSegment.text = 'File Attached.';
                }
                messageBodyInput.messageSegments.add(textSegment);

                feedItemInput.body = messageBodyInput;

                // -- File Attachment Capability --
                if (String.isNotBlank(req.fileIdToAttach)) {
                    ConnectApi.FilesCapabilityInput filesInput = new ConnectApi.FilesCapabilityInput();
                    filesInput.items = new List<ConnectApi.FileIdInput>();
                    ConnectApi.FileIdInput idInput = new ConnectApi.FileIdInput();
                    idInput.id = req.fileIdToAttach;
                    filesInput.items.add(idInput);

                    ConnectApi.FeedElementCapabilitiesInput capabilities = new ConnectApi.FeedElementCapabilitiesInput();
                    capabilities.files = filesInput;
                    feedItemInput.capabilities = capabilities;
                }

                // -- POST TO CHATTER --
                if (!Test.isRunningTest()) {
                                        
                    // Post to Parent Record (Lead/Opp) - optional based on your requirements
                    feedItemInput.subjectId = this.parentRecordId;
                    ConnectApi.ChatterFeeds.postFeedElement(networkId, feedItemInput);
                }
            }

            // 2. Prepare File Links
            if (String.isNotBlank(req.fileIdToAttach)) {
                fileLinksToInsert.add(new ContentDocumentLink(
                    LinkedEntityId = this.parentRecordId, 
                    ContentDocumentId = req.fileIdToAttach,
                    ShareType = 'V',
                    Visibility = 'AllUsers'
                ));
            }
        }

        // Insert File Links (Bulkified)
        if (!fileLinksToInsert.isEmpty()) {
            Database.insert(fileLinksToInsert, false);
        }
    }
}