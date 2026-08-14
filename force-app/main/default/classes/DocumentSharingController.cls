public with sharing class DocumentSharingController {
    
    public class Input {
        @InvocableVariable(label='Content Version ID' required=true)
        public Id contentVersionId;
        
        @InvocableVariable(label='Password' required=false)
        public String password;
    }
    
    public class Output {
        @InvocableVariable(label='Public Link')
        public String publicLink;
    }

    @InvocableMethod(label='Generate Public Document Link' description='Generates a publicly shareable link for a document.')
    public static List<Output> generatePublicDocumentLinks(List<Input> inputs) {
        List<Output> outputs = new List<Output>();
        for (Input input : inputs) {
            Output output = new Output();
            output.publicLink = createPublicLink(input.contentVersionId, input.password);
            outputs.add(output);
        }
        return outputs;
    }

    @AuraEnabled
    public static String createPublicLink(Id contentVersionId, String password) {
        try {
            ContentVersion cv = [SELECT ContentDocumentId, Title FROM ContentVersion WHERE Id = :contentVersionId LIMIT 1];
            
            ContentDistribution cd = new ContentDistribution();
            cd.Name = cv.Title;
            cd.ContentVersionId = cv.Id;
            cd.PreferencesAllowViewInBrowser = true;
            cd.PreferencesLinkLatestVersion = true;
            cd.PreferencesNotifyOnVisit = false;
            cd.PreferencesPasswordRequired = String.isNotBlank(password);
            
            insert cd;
            
            cd = [SELECT DistributionPublicUrl FROM ContentDistribution WHERE Id = :cd.Id];
            return cd.DistributionPublicUrl;
        } catch (Exception e) {
            throw new AuraHandledException('Error creating sharing link: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static void clearPublicLinks(Id contentDocumentId) {
        try {
            delete [SELECT Id FROM ContentDistribution WHERE ContentDocumentId = :contentDocumentId];
        } catch (Exception e) {
            throw new AuraHandledException('Error clearing sharing links: ' + e.getMessage());
        }
    }
}