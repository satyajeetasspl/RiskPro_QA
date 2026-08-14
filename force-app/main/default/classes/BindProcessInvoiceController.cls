public with sharing class BindProcessInvoiceController {
    
    public Lead leadRecord { get; private set; }
    public List<Policy_Information__c> policies { get; private set; }
    public Carrier__c carrierRecord { get; private set; }
    public String invoiceNumberStr { get; private set; }
    
    public BindProcessInvoiceController() {
        Id leadId = ApexPages.currentPage().getParameters().get('leadId');
        Id opportunityId = ApexPages.currentPage().getParameters().get('opportunityId');
        String policyIdsStr = ApexPages.currentPage().getParameters().get('policyIds');

        // Generate a dynamic 5-digit invoice number
        Integer rand = Math.round(Math.random() * 89999) + 10000;
        this.invoiceNumberStr = String.valueOf(rand);

        try {
            List<Id> policyIds = new List<Id>();
            if (String.isNotBlank(policyIdsStr)) {
                for (String s : policyIdsStr.split(',')) {
                    policyIds.add((Id)s.trim());
                }
            }

            if (policyIds.isEmpty()) {
                Id singlePolicyId = ApexPages.currentPage().getParameters().get('policyId');
                if (singlePolicyId != null) {
                    policyIds.add(singlePolicyId);
                } else if (leadId != null) {
                    for (Policy_Information__c p : [SELECT Id FROM Policy_Information__c WHERE Lead__c = :leadId]) {
                        policyIds.add(p.Id);
                    }
                }
            }

            if (policyIds.isEmpty()) return;

            this.policies = [
                SELECT Id, Carrier__c, Policy__c, Premium__c, Paid_To_Date__c,
                       Effective_Date__c, Lines__c, Additional_Comments__c,
                       Account__c, Opportunity__c, Lead__c,
                       Carrier_Payment_Address__Street__s, 
                       Carrier_Payment_Address__City__s,
                       Carrier_Payment_Address__StateCode__s, 
                       Carrier_Payment_Address__PostalCode__s
                FROM Policy_Information__c
                WHERE Id IN :policyIds
                ORDER BY Lines__c ASC
            ];

            if (this.policies.isEmpty()) return;

            Policy_Information__c firstPolicy = this.policies[0];
            
            if (firstPolicy.Account__c != null || firstPolicy.Opportunity__c != null) {
                Id targetAccountId = firstPolicy.Account__c;
                if (targetAccountId == null && firstPolicy.Opportunity__c != null) {
                    Opportunity opp = [SELECT AccountId FROM Opportunity WHERE Id = :firstPolicy.Opportunity__c LIMIT 1];
                    targetAccountId = opp.AccountId;
                }

                if (targetAccountId != null) {
                    Account acc = [
                        SELECT Name, 
                               NBC_Address__Street__s, NBC_Address__City__s, 
                               NBC_Address__StateCode__s, NBC_Address__PostalCode__s,
                               Second_Insured_First_Name__c, Second_Insured_Last_Name__c,
                               Add_Second_Named_Insured__c
                        FROM Account
                        WHERE Id = :targetAccountId
                        LIMIT 1
                    ];

                    this.leadRecord = new Lead();
                    this.leadRecord.LastName = acc.Name; 
                    this.leadRecord.Street = acc.NBC_Address__Street__s;
                    this.leadRecord.City = acc.NBC_Address__City__s;
                    this.leadRecord.State = acc.NBC_Address__StateCode__s;
                    this.leadRecord.PostalCode = acc.NBC_Address__PostalCode__s;
                    this.leadRecord.Second_Insured_First_Name__c = acc.Second_Insured_First_Name__c;
                    this.leadRecord.Second_Insured_Last_Name__c = acc.Second_Insured_Last_Name__c;
                    this.leadRecord.Add_Second_Named_Insured__c = acc.Add_Second_Named_Insured__c;
                }
            } 
            else if (leadId != null) {
                this.leadRecord = [SELECT Id, Name, Second_Insured_First_Name__c, Second_Insured_Last_Name__c, Street, City, State, PostalCode, Country, Add_Second_Named_Insured__c FROM Lead WHERE Id = :leadId LIMIT 1];
            }

            if (firstPolicy.Carrier__c != null) {
                this.carrierRecord = [SELECT Id, Company_Name__c, Payment_Address__Street__s, Payment_Address__City__s, Payment_Address__StateCode__s, Payment_Address__PostalCode__s FROM Carrier__c WHERE Company_Name__c = :firstPolicy.Carrier__c LIMIT 1];
            }

        } catch (Exception e) {
            System.debug('BindProcessInvoiceController Error: ' + e.getMessage());
        }
    }

    public Decimal getTotalPremium() {
        Decimal total = 0;
        if (policies == null) return 0;
        for (Policy_Information__c p : policies) {
            if (p.Premium__c != null) total += Decimal.valueOf(String.valueOf(p.Premium__c));
        }
        return total;
    }

    public Decimal getPaidToDate() {
        Decimal total = 0;
        if (policies == null) return 0;
        for (Policy_Information__c p : policies) {
            if (p.Paid_To_Date__c != null) total += Decimal.valueOf(String.valueOf(p.Paid_To_Date__c));
        }
        return total;
    }

    public Decimal getPolicyBalanceDue() {
        return getTotalPremium() - getPaidToDate();
    }

    public String getPropertyAddress() {
        if (leadRecord == null) return '';
        String address = '';
        if (String.isNotBlank(leadRecord.Street)) address += leadRecord.Street + ', ';
        if (String.isNotBlank(leadRecord.City)) address += leadRecord.City + ', ';
        if (String.isNotBlank(leadRecord.State)) address += leadRecord.State + ' ';
        if (String.isNotBlank(leadRecord.PostalCode)) address += leadRecord.PostalCode;
        return address.trim().removeEnd(',');
    }

    public String getInsuredName() {
        if (leadRecord == null) return '';
        if (leadRecord.Id == null) return leadRecord.LastName; 
        return String.isNotBlank(leadRecord.Name) ? leadRecord.Name : leadRecord.LastName;
    }

    public String getPaymentStreet(){
        if (policies != null && !policies.isEmpty() && String.isNotBlank(policies[0].Carrier_Payment_Address__Street__s)) {
            return policies[0].Carrier_Payment_Address__Street__s.trim().removeEnd(',');
        }
        if (carrierRecord != null && String.isNotBlank(carrierRecord.Payment_Address__Street__s)) {
            return carrierRecord.Payment_Address__Street__s.trim().removeEnd(',');
        }
        return '';
    }

    public String getPaymentCityStateCode(){
        String address = '';
        if (policies != null && !policies.isEmpty() && (String.isNotBlank(policies[0].Carrier_Payment_Address__City__s) || String.isNotBlank(policies[0].Carrier_Payment_Address__StateCode__s))) {
            if (String.isNotBlank(policies[0].Carrier_Payment_Address__City__s)) address += policies[0].Carrier_Payment_Address__City__s + ', ';
            if (String.isNotBlank(policies[0].Carrier_Payment_Address__StateCode__s)) address += policies[0].Carrier_Payment_Address__StateCode__s + ' ';
            if (String.isNotBlank(policies[0].Carrier_Payment_Address__PostalCode__s)) address += policies[0].Carrier_Payment_Address__PostalCode__s;
            return address.trim().removeEnd(',');
        }
        if (carrierRecord != null) {
            if (String.isNotBlank(carrierRecord.Payment_Address__City__s)) address += carrierRecord.Payment_Address__City__s + ', ';
            if (String.isNotBlank(carrierRecord.Payment_Address__StateCode__s)) address += carrierRecord.Payment_Address__StateCode__s + ' ';
            if (String.isNotBlank(carrierRecord.Payment_Address__PostalCode__s)) address += carrierRecord.Payment_Address__PostalCode__s;
        }
        return address.trim().removeEnd(',');
    }
    
    public String getPolicyNumber(){
        if (policies != null && !policies.isEmpty() && String.isNotBlank(policies[0].Policy__c)) {
            return policies[0].Policy__c;
        }
        return '';
    }
    
    public String getAdditionalComments(){
         if (policies != null && !policies.isEmpty() && String.isNotBlank(policies[0].Additional_Comments__c)) {
            return policies[0].Additional_Comments__c;
        }
        return '';
    }

    public String getInvoiceNumber() {
        return invoiceNumberStr;
    }

    public String getLineOfBusiness() {
        if (policies != null && !policies.isEmpty() && String.isNotBlank(policies[0].Lines__c)) {
            return policies[0].Lines__c;
        }
        return '';
    }
}