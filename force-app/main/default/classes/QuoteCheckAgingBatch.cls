public class QuoteCheckAgingBatch implements Database.Batchable<sObject>, Schedulable {

    public void execute(SchedulableContext sc) {
        Database.executeBatch(new QuoteCheckAgingBatch(), 200);
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {
        // Query open Quote Checks (unresolved or approved but not converted)
        // We look at Leads, Accounts, Opportunities where Policy_Check_Status__c is not empty and Quote_Check_Submitted_Date__c is not null.
        // We will just query Leads for now, as it's the primary object. 
        // Wait, aging applies to Unresolved Quote Checks and Approved Quote Checks where Lead has not converted.
        // Let's write a dynamic query or just query Leads in this batch, and we could have separate batches or combine them.
        // Combining them is easiest if we use a base object, but SObjects don't work that way.
        // Let's just run it for Leads.
        String query = 'SELECT Id, OwnerId, Policy_Check_Status__c, Quote_Check_Submitted_Date__c, ' +
                       'Quote_Check_Age_Days__c, Quote_Check_Stale__c, Quote_Check_Closure_Reason__c, IsConverted ' +
                       'FROM Lead ' +
                       'WHERE Quote_Check_Submitted_Date__c != null ' +
                       'AND Policy_Check_Status__c != null ' +
                       'AND Quote_Check_Closure_Reason__c = null ' +
                       'AND (Policy_Check_Status__c NOT IN (\'Rejected\', \'Rejected / Do Not Proceed\') ' +
                       'OR (Policy_Check_Status__c = \'Approved\' AND IsConverted = false))';
        return Database.getQueryLocator(query);
    }

    public void execute(Database.BatchableContext bc, List<Lead> scope) {
        List<Lead> leadsToUpdate = new List<Lead>();
        List<FeedItem> chatterPosts = new List<FeedItem>();
        
        for (Lead l : scope) {
            Integer daysOld = l.Quote_Check_Submitted_Date__c.date().daysBetween(System.today());
            Boolean isStale = (daysOld >= 7);
            
            Boolean needsUpdate = false;
            if (l.Quote_Check_Age_Days__c != daysOld) {
                l.Quote_Check_Age_Days__c = daysOld;
                needsUpdate = true;
            }
            if (isStale && l.Quote_Check_Stale__c != true) {
                l.Quote_Check_Stale__c = true;
                needsUpdate = true;
            }
            
            if (needsUpdate) {
                leadsToUpdate.add(l);
            }
            
            // Generate Chatter notifications at 1, 3, 5, 7 days
            if (daysOld == 1 || daysOld == 3 || daysOld == 5) {
                FeedItem post = new FeedItem();
                post.ParentId = l.Id;
                post.Body = 'Reminder: This Quote Check has been open for ' + daysOld + ' days. Please review and process.';
                chatterPosts.add(post);
            } else if (daysOld == 7 && isStale) {
                FeedItem post = new FeedItem();
                post.ParentId = l.Id;
                post.Body = 'Action Required: This Quote Check is now stale (7+ days). Please revalidate or close with a reason.';
                chatterPosts.add(post);
            }
        }
        
        if (!leadsToUpdate.isEmpty()) {
            Database.update(leadsToUpdate, false, AccessLevel.SYSTEM_MODE);
        }
        if (!chatterPosts.isEmpty()) {
            Database.insert(chatterPosts, false, AccessLevel.SYSTEM_MODE);
        }
    }

    public void finish(Database.BatchableContext bc) {
        // Optional: Chain to Account and Opportunity aging batches if necessary
    }
}