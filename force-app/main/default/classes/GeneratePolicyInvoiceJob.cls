public class GeneratePolicyInvoiceJob implements Queueable, Database.AllowsCallouts {

    private Id leadId;
    private List<Id> policyIds;
    private Id targetRecordId;
    private String invoiceType;

    // Multi-Policy Constructor (Preferred for NBC)
    public GeneratePolicyInvoiceJob(Id leadId, List<Id> policyIds, Id targetRecordId, String invoiceType) {
        this.leadId = leadId;
        this.policyIds = policyIds;
        this.targetRecordId = targetRecordId;
        this.invoiceType = invoiceType;
    }

    public GeneratePolicyInvoiceJob(Id leadId, List<Id> policyIds, Id targetRecordId) {
        this(leadId, policyIds, targetRecordId, 'Direct Bill');
    }

    // Single-Policy Constructor (Backward Compatibility)
    public GeneratePolicyInvoiceJob(Id leadId, Id policyId, Id targetRecordId, String invoiceType) {
        this.leadId = leadId;
        this.policyIds = new List<Id>{ policyId };
        this.targetRecordId = targetRecordId;
        this.invoiceType = invoiceType;
    }

    public GeneratePolicyInvoiceJob(Id leadId, Id policyId, Id targetRecordId) {
        this(leadId, policyId, targetRecordId, 'Direct Bill');
    }

    public GeneratePolicyInvoiceJob(Id leadId, Id policyId) {
        this(leadId, policyId, leadId, 'Direct Bill');
    }

    public void execute(QueueableContext context) {
        if (policyIds == null || policyIds.isEmpty()) return;

        try {
            // 1. Prepare Parameters
            String idsParam = '';
            for (Id pid : policyIds) {
                idsParam += (idsParam == '' ? '' : ',') + pid;
            }

            // 2. Setup File Name & Metadata
            String fileName;
            String cvTitle;
            
            if (policyIds.size() == 1) {
                Policy_Information__c p = [SELECT Carrier__c, Policy__c, Lines__c FROM Policy_Information__c WHERE Id = :policyIds[0] LIMIT 1];
                String carrier = p.Carrier__c != null ? p.Carrier__c : 'Insurance';
                String line = p.Lines__c != null ? p.Lines__c : 'Policy';
                String num = p.Policy__c != null ? p.Policy__c : 'TBD';
                
                // Professional Format: Invoice - Carrier - LOB - Policy#
                fileName = 'Invoice - ' + carrier + ' - ' + line + ' - ' + num + '.pdf';
                cvTitle = fileName.replace('.pdf', '');
            } else {
                Policy_Information__c p = [SELECT Carrier__c, Lines__c FROM Policy_Information__c WHERE Id = :policyIds[0] LIMIT 1];
                String carrier = p.Carrier__c != null ? p.Carrier__c : 'Insurance';
                
                String formattedDate = Date.today().format();
                
                fileName = 'Consolidated Invoice - ' + formattedDate + '.pdf';
                cvTitle = 'Consolidated Invoice - ' + formattedDate;
            }

            // 3. Setup Page Reference
            PageReference pdfPage;
            if (this.invoiceType == 'Agency Bill') {
                pdfPage = Page.Agency_Billed_Invoice_PDF;
                fileName = fileName.replace('Invoice', 'Agency Bill');
                cvTitle = cvTitle.replace('Invoice', 'Agency Bill');
            } else {
                pdfPage = Page.Policy_Invoice_PDF;
            }
            
            pdfPage.getParameters().put('leadId', leadId);
            
            if (policyIds.size() == 1) {
                pdfPage.getParameters().put('policyId', policyIds[0]);
            } else {
                pdfPage.getParameters().put('policyIds', idsParam);
            }

            // 4. Generate PDF
            Blob pdfBlob;
            if (Test.isRunningTest()) {
                pdfBlob = Blob.valueOf('Test PDF');
            } else {
                pdfBlob = pdfPage.getContentAsPDF();
            }

            if (pdfBlob == null) return;

            // 5. Insert ContentVersion
            ContentVersion cv = new ContentVersion();
            cv.Title = cvTitle;
            cv.PathOnClient = fileName;
            cv.VersionData = pdfBlob;
            cv.FirstPublishLocationId = targetRecordId;
            insert cv;

            // 6. Mark policies as processed
            List<Policy_Information__c> updates = new List<Policy_Information__c>();
            for (Id pid : policyIds) {
                updates.add(new Policy_Information__c(Id = pid, Generate_Invoice__c = false));
            }
            update updates;

        } catch (Exception e) {
            System.debug('Error in GeneratePolicyInvoiceJob: ' + e.getMessage());
            System.debug('Stack Trace: ' + e.getStackTraceString());
        }
    }
}