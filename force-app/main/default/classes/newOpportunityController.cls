public with sharing class newOpportunityController {
    @AuraEnabled(cacheable=true)
    public static Account getAccountDetails(Id accountId) {
        return [SELECT Id, Name, 
                // FETCHING FROM ACCOUNT (READ-ONLY)
                Referral_Type__c, Referral_Source_Name__c, 
                Lead_Source__c, Partner_Name__c, 
                Can_we_contact_the_prospect_directly__c,
                Loan_Officer_Name__c, Loan_Officer_Email__c, 
                Processor_Name__c, Processor_Email__c
                
                FROM Account WHERE Id = :accountId LIMIT 1];
    }
}