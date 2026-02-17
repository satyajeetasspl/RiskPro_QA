public class GeneratePolicyInvoiceJob implements Queueable, Database.AllowsCallouts {

    private Id leadId;
    private Id policyId;
    private Id targetRecordId;
    
    @TestVisible static Boolean forceNullPdfForTest = false;

    public GeneratePolicyInvoiceJob(Id leadId, Id policyId, Id targetRecordId) {
        this.leadId = leadId;
        this.policyId = policyId;
        this.targetRecordId = targetRecordId;
    }

    public GeneratePolicyInvoiceJob(Id leadId, Id policyId) {
        this(leadId, policyId, leadId);
    }

    public void execute(QueueableContext context) {
        try {
            // 1. Get Policy Details for File Name
            Policy_Information__c policyRec = [
                SELECT Carrier__c, Policy__c, Lead__c
                FROM Policy_Information__c 
                WHERE Id = :policyId 
                LIMIT 1
            ];

            String carrierName = policyRec.Carrier__c != null ? policyRec.Carrier__c : 'Unknown';
            String policyNum = policyRec.Policy__c != null ? policyRec.Policy__c : 'NoNum';
            
            String fullFileName = 'Invoice - ' + carrierName + ' - ' + policyNum + '.pdf';
            
            // 2. Setup Page Reference
PageReference pdfPage = new PageReference('/apex/Policy_Invoice_PDF');
pdfPage.getParameters().put('leadId', leadId);
pdfPage.getParameters().put('policyId', policyId);

// 3. Generate PDF - FIXED ERROR HANDLING
Blob pdfBlob;
if (Test.isRunningTest()) {
    pdfBlob = Blob.valueOf('Test PDF: ' + policyNum);
} else {
    pdfBlob = pdfPage.getContentAsPDF();
  System.debug('PDF generated. Size: ' + (pdfBlob != null ? String.valueOf(pdfBlob.size()) : 'NULL'));

    if (pdfBlob == null) {
        System.debug(' PDF FAILED - Page: Policy_Invoice_PDF, leadId: ' + leadId + ', policyId: ' + policyId);
        return; // Exit gracefully
    }
}

            ContentVersion cv = new ContentVersion();
            cv.Title = 'Invoice - ' + carrierName + ' - ' + policyNum;
            cv.PathOnClient = fullFileName;
            cv.VersionData = pdfBlob;
            cv.FirstPublishLocationId = targetRecordId;  
            
            insert cv;

            // 5. Mark policy as processed
            Policy_Information__c policyToUpdate = new Policy_Information__c(
                Id = policyId,
                Generate_Invoice__c = false
            );
            update policyToUpdate;

            System.debug(' Invoice generated: ' + fullFileName + ' attached to: ' + targetRecordId);

        } catch (Exception e) {
            System.debug(' Error in GeneratePolicyInvoiceJob: ' + e.getMessage());
            System.debug('Stack Trace: ' + e.getStackTraceString());
            System.debug('leadId: ' + leadId + ', policyId: ' + policyId + ', targetRecordId: ' + targetRecordId);
        }
    }
}