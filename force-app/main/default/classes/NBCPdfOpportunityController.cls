public with sharing class NBCPdfOpportunityController {

    public NBCWrapper wrapperObj { get; set; }
    public String pdfTitle { get; set; }

    public NBCPdfOpportunityController() {
        Id oppId = ApexPages.currentPage().getParameters().get('id');
        if (oppId != null) {
            this.wrapperObj = loadData(oppId);
            String oppName = (wrapperObj.opp != null) ? wrapperObj.opp.Name : 'Checklist';
            this.pdfTitle = 'NBC Checklist - ' + oppName;
        }
    }

    public class NBCWrapper {
        public Opportunity opp { get; set; }
        public Account acc { get; set; }
        public List<Policy_Information__c> policies { get; set; }
    }

    private static NBCWrapper loadData(Id opportunityId) {
        NBCWrapper w = new NBCWrapper();

        w.opp = [
            SELECT Id, Name, Owner.Name, Owner.Email, AccountId, LeadSource,
                   Agent_2__r.Name, 
                   Date_Bound__c, 
                   Rewrite__c, 
                   CSR_Work_Order__c, 
                   Notes_For_CSR__c, 
                   Agent_Notes__c
            FROM Opportunity
            WHERE Id = :opportunityId
            LIMIT 1
        ];

        w.acc = new Account(); 
        if (w.opp.AccountId != null) {
            w.acc = [
                SELECT Id, Name, Phone, Email__c,
                       NBC_Address__Street__s,
                       NBC_Address__City__s,
                       NBC_Address__StateCode__s,
                       NBC_Address__PostalCode__s,
                       NBC_Address__CountryCode__s,
                       Add_Second_Named_Insured__c,
                       Second_Insured_First_Name__c,
                       Second_Insured_Last_Name__c,
                       Second_Insured_Phone__c,
                       Second_Insured_Email__c,
                       Comments__c
                FROM Account
                WHERE Id = :w.opp.AccountId
                LIMIT 1
            ];
        }

        w.policies = [
            SELECT Carrier__c, Lines__c, Policy__c, Agency_Fee__c,
                   Premium__c, Effective_Date__c
            FROM Policy_Information__c
            WHERE Opportunity__c = :opportunityId
            AND Policy_Type__c != 'Quote'
            ORDER BY CreatedDate ASC
        ];

        return w;
    }
}