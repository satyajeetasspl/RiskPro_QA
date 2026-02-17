public with sharing class PolicyInvoiceController {
    
    public Lead leadRecord { get; private set; }
    public Policy_Information__c policyRecord { get; private set; }
    public Carrier__c CarrierRecord { get; private set; }
    
    public PolicyInvoiceController() {
        Id leadId = ApexPages.currentPage().getParameters().get('leadId');
        Id policyId = ApexPages.currentPage().getParameters().get('policyId');

        try {
            if (policyId == null) return;

            this.policyRecord = [
                SELECT Id, Carrier__c, Policy__c, Premium__c, Paid_To_Date__c,
                       Effective_Date__c, Lines__c, Additional_Comments__c,
                       Account__c, Opportunity__c, Lead__c,
                       Carrier_Payment_Address__Street__s, 
                       Carrier_Payment_Address__City__s,
                       Carrier_Payment_Address__StateCode__s, 
                       Carrier_Payment_Address__PostalCode__s
                FROM Policy_Information__c
                WHERE Id = :policyId
                LIMIT 1
            ];

            if (this.policyRecord.Account__c != null || this.policyRecord.Opportunity__c != null) {
                Id targetAccountId = this.policyRecord.Account__c;
                
                if (targetAccountId == null && this.policyRecord.Opportunity__c != null) {
                    Opportunity opp = [SELECT AccountId FROM Opportunity WHERE Id = :this.policyRecord.Opportunity__c LIMIT 1];
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
                this.leadRecord = [
                    SELECT Id, Name, Second_Insured_First_Name__c, Second_Insured_Last_Name__c,
                           Street, City, State, PostalCode, Country,
                           Add_Second_Named_Insured__c
                    FROM Lead
                    WHERE Id = :leadId
                    LIMIT 1
                ];
            }

            if (this.policyRecord.Carrier__c != null) {
                this.CarrierRecord = [
                    SELECT Id, Company_Name__c,
                           Payment_Address__Street__s,
                           Payment_Address__City__s,
                           Payment_Address__StateCode__s,
                           Payment_Address__PostalCode__s
                    FROM Carrier__c
                    WHERE Company_Name__c = :policyRecord.Carrier__c
                    LIMIT 1
                ];
            }

        } catch (Exception e) {
            System.debug('PolicyInvoiceController Error: ' + e.getMessage());
        }
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
    
    public String getPaymentStreet(){
    // Priority 1: Use the specific address stamped on the Policy
    if (policyRecord != null && String.isNotBlank(policyRecord.Carrier_Payment_Address__Street__s)) {
        return policyRecord.Carrier_Payment_Address__Street__s.trim().removeEnd(',');
    }
    
    // Priority 2: Fallback to the default Carrier Address
    if (CarrierRecord != null && String.isNotBlank(CarrierRecord.Payment_Address__Street__s)) {
            return CarrierRecord.Payment_Address__Street__s.trim().removeEnd(',');
    }
    
    return '';
}

    public String getPaymentCityStateCode(){
    String address = '';

    // Priority 1: Use the specific address stamped on the Policy
    if (policyRecord != null && (String.isNotBlank(policyRecord.Carrier_Payment_Address__City__s) || String.isNotBlank(policyRecord.Carrier_Payment_Address__StateCode__s))) {
            if (String.isNotBlank(policyRecord.Carrier_Payment_Address__City__s)) address += policyRecord.Carrier_Payment_Address__City__s + ', ';
            if (String.isNotBlank(policyRecord.Carrier_Payment_Address__StateCode__s)) address += policyRecord.Carrier_Payment_Address__StateCode__s + ' ';
            if (String.isNotBlank(policyRecord.Carrier_Payment_Address__PostalCode__s)) address += policyRecord.Carrier_Payment_Address__PostalCode__s;
            
            return address.trim().removeEnd(',');
    }

    // Priority 2: Fallback to the default Carrier Address
    if (CarrierRecord != null) {
        if (String.isNotBlank(CarrierRecord.Payment_Address__City__s)) address += CarrierRecord.Payment_Address__City__s + ', ';
        if (String.isNotBlank(CarrierRecord.Payment_Address__StateCode__s)) address += CarrierRecord.Payment_Address__StateCode__s + ' ';
        if (String.isNotBlank(CarrierRecord.Payment_Address__PostalCode__s)) address += CarrierRecord.Payment_Address__PostalCode__s;
    }
    
    return address.trim().removeEnd(',');
}

    public Decimal getBalanceDue() {
        if (policyRecord == null) return 0;
        
        Decimal premium = 0;
        Decimal paid = 0;
        
        try {
            if (policyRecord.Premium__c != null) {
                premium = Decimal.valueOf(String.valueOf(policyRecord.Premium__c));
            }
            if (policyRecord.Paid_To_Date__c != null) {
                paid = Decimal.valueOf(String.valueOf(policyRecord.Paid_To_Date__c));
            }
            
        } catch (Exception e) {
            System.debug('Error parsing numeric fields: ' + e.getMessage());
        }
        
        Decimal balance = premium - paid;
        return balance;
    }

    public Decimal getPaidToDate(){
        Decimal paid = 0;
        if (policyRecord != null && policyRecord.Paid_To_Date__c != null) {
            try {
                paid = Decimal.valueOf(String.valueOf(policyRecord.Paid_To_Date__c));
            } catch (Exception e) {
                paid = 0;
            }
        }
        return paid;
    }

    public Decimal getTotalPremium(){
        Decimal totalPremium = 0;
        if (policyRecord != null && policyRecord.Premium__c != null) {
            try {
                totalPremium = Decimal.valueOf(String.valueOf(policyRecord.Premium__c));
            } catch (Exception e) {
                totalPremium = 0;
            }
        }
        return totalPremium;
    } 

    public String getInsuredName() {
        if (leadRecord == null) return '';
        
        if (leadRecord.Id == null) {
            return leadRecord.LastName; 
        }
        
        return String.isNotBlank(leadRecord.Name) ? leadRecord.Name : leadRecord.LastName;
    }
}