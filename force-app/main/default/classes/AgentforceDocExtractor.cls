public class AgentforceDocExtractor {
    @InvocableMethod(label='Get Text From Document' description='Extracts text from a ContentDocument')
    public static List<String> extractText(List<Id> documentIds) {
        List<String> results = new List<String>();
        
        for(Id docId : documentIds) {
            ContentVersion cv = [SELECT VersionData, FileExtension FROM ContentVersion WHERE ContentDocumentId = :docId AND IsLatest = true LIMIT 1];
            
            String extractedText = '';
            if(cv.FileExtension == 'txt' || cv.FileExtension == 'csv') {
                extractedText = cv.VersionData.toString();
            } else if (cv.FileExtension == 'pdf') {
                // TODO: In a real environment, you make an HTTP Callout to an OCR API here.
                // For your Dev Org testing, we will mock the response based on your example document.
                extractedText = 'Name: Gary Mehalick, Address: 161 Mallard LOOP, Waynesville, NC 28785-8883, Agency: Risk Pros Insurance, Phone: (614) 647-9644, Email: clientrelations@myriskpros.com';
            }
            results.add(extractedText);
        }
        return results;
    }
}