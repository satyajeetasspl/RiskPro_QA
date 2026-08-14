public class QBO_InvoiceQueueable implements Queueable, Database.AllowsCallouts {
    private List<Id> policyIds;
    
    public QBO_InvoiceQueueable(List<Id> policyIds) {
        this.policyIds = policyIds;
    }
    
    public void execute(QueueableContext context) {
        if (this.policyIds == null || this.policyIds.isEmpty()) return;
        
        // 1. Process the first policy ID in this transaction
        Id currentPolicyId = this.policyIds.remove(0);
        try {
            QBO_InvoiceController.generateInvoiceForPolicy(currentPolicyId);
        } catch(Exception e) {
            System.debug('Error in QBO_InvoiceQueueable for Policy ' + currentPolicyId + ': ' + e.getMessage() + ' - ' + e.getStackTraceString());
        }
        
        // 2. Chaining: Enqueue the remaining policies for the next isolated transaction
        if (!this.policyIds.isEmpty()) {
            if (!Test.isRunningTest()) {
                System.enqueueJob(new QBO_InvoiceQueueable(this.policyIds));
            }
        }
    }
}