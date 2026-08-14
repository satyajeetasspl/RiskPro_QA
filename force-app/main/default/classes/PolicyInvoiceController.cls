public with sharing class PolicyInvoiceController {
    
    public Lead leadRecord { get; private set; }
    public List<Policy_Information__c> policies { get; private set; }
    public Carrier__c carrierRecord { get; private set; }
    
    public PolicyInvoiceController() {
        Id leadId = ApexPages.currentPage().getParameters().get('leadId');
        Id opportunityId = ApexPages.currentPage().getParameters().get('opportunityId');
        String policyIdsStr = ApexPages.currentPage().getParameters().get('policyIds');

        try {
            List<Id> policyIds = new List<Id>();
            if (String.isNotBlank(policyIdsStr)) {
                for (String s : policyIdsStr.split(',')) {
                    policyIds.add((Id)s.trim());
                }
            }

            if (policyIds.isEmpty()) {
                // Compatibility for old individual invoice logic
                Id singlePolicyId = ApexPages.currentPage().getParameters().get('policyId');
                if (singlePolicyId != null) {
                    policyIds.add(singlePolicyId);
                } else if (leadId != null) {
                    // If called from a Lead button, find all policies for this lead
                    for (Policy_Information__c p : [SELECT Id FROM Policy_Information__c WHERE Lead__c = :leadId]) {
                        policyIds.add(p.Id);
                    }
                }
            }

            if (policyIds.isEmpty()) return;

            this.policies = [
                SELECT Id, Carrier__c, Policy__c, Premium__c, Paid_To_Date__c, Agency_Fee__c,
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

            // Load Insured Info from the first policy's context
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

            // Load Carrier Info (for the first policy or a common one)
            if (firstPolicy.Carrier__c != null) {
                this.carrierRecord = [SELECT Id, Company_Name__c, Payment_Address__Street__s, Payment_Address__City__s, Payment_Address__StateCode__s, Payment_Address__PostalCode__s FROM Carrier__c WHERE Company_Name__c = :firstPolicy.Carrier__c LIMIT 1];
            }

        } catch (Exception e) {
            System.debug('PolicyInvoiceController Error: ' + e.getMessage());
        }
    }

    public List<PolicyWrapper> getPolicyWrappers() {
        List<PolicyWrapper> wrappers = new List<PolicyWrapper>();
        if (policies == null) return wrappers;
        for (Policy_Information__c p : policies) {
            wrappers.add(new PolicyWrapper(p));
        }
        return wrappers;
    }

    public class PolicyWrapper {
        public Policy_Information__c pol { get; private set; }
        public Decimal premium { get; private set; }
        public Decimal agencyFee { get; private set; }
        public Decimal total { get; private set; }
        
        public PolicyWrapper(Policy_Information__c p) {
            this.pol = p;
            this.premium = (p.Premium__c != null) ? Decimal.valueOf(String.valueOf(p.Premium__c)) : 0;
            this.agencyFee = (p.Agency_Fee__c != null) ? p.Agency_Fee__c : 0;
            this.total = this.premium + this.agencyFee;
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

    public Decimal getTotalAgencyFee() {
        Decimal total = 0;
        if (policies == null) return 0;
        for (Policy_Information__c p : policies) {
            if (p.Agency_Fee__c != null) total += p.Agency_Fee__c;
        }
        return total;
    }

    public Decimal getGrandTotal() {
        return getTotalPremium() + getTotalAgencyFee();
    }

    public Decimal getPaidToDate() {
        Decimal total = 0;
        if (policies == null) return 0;
        for (Policy_Information__c p : policies) {
            if (p.Paid_To_Date__c != null) total += Decimal.valueOf(String.valueOf(p.Paid_To_Date__c));
        }
        return total;
    }

    public Decimal getBalanceDue() {
        return getGrandTotal() - getPaidToDate();
    }

    public String getSecondInsuredName() {
        if (leadRecord != null && leadRecord.Add_Second_Named_Insured__c == true) {
            return (String.isNotBlank(leadRecord.Second_Insured_First_Name__c) ? leadRecord.Second_Insured_First_Name__c + ' ' : '') +
                   (String.isNotBlank(leadRecord.Second_Insured_Last_Name__c) ? leadRecord.Second_Insured_Last_Name__c : '');
        }
        return '';
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
    public string getPolicyNumber(){
        if (policies != null && !policies.isEmpty() && String.isNotBlank(policies[0].Policy__c)) {
            return policies[0].Policy__c;
        }
        return '';

        
    }
    public string getAdditionalComments(){
         if (policies != null && !policies.isEmpty() && String.isNotBlank(policies[0].Additional_Comments__c)) {
            return policies[0].Additional_Comments__c;
        }
        return '';
        
    }
}