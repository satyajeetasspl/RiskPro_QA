public with sharing class CommissionCalculatorController {
    
    @AuraEnabled(cacheable=false)
    public static CommissionResult calculateCommission(Id recordId, String objectApiName) {
        CommissionResult result = new CommissionResult();
        
        try {
            String stateCode = '';
            
            // 1. Fetch the state from the active record
            if (objectApiName == 'Lead') {
                Lead l = [SELECT State FROM Lead WHERE Id = :recordId LIMIT 1];
                stateCode = l.State;
            } else if (objectApiName == 'Account') {
                Account a = [SELECT Address_Property__StateCode__s FROM Account WHERE Id = :recordId LIMIT 1];
                stateCode = a.Address_Property__StateCode__s;
            } else if (objectApiName == 'Opportunity') {
                Opportunity opp = [SELECT AccountId, Account.Address_Property__StateCode__s FROM Opportunity WHERE Id = :recordId LIMIT 1];
                if (opp.AccountId != null) {
                    stateCode = opp.Account.Address_Property__StateCode__s;
                }
            } else {
                throw new AuraHandledException('Unsupported object type: ' + objectApiName);
            }
            
            if (String.isBlank(stateCode)) {
                result.isError = true;
                result.message = 'No State found on the record. Please ensure the Address State is populated.';
                return result;
            }
            
            // 2. Query Custom Metadata
            List<State_Commission_Rule__mdt> rules = [
                SELECT MasterLabel, Commission_Fee__c, Is_Eligible__c 
                FROM State_Commission_Rule__mdt 
                WHERE MasterLabel = :stateCode 
                LIMIT 1
            ];
            
            if (rules.isEmpty()) {
                result.isError = true;
                result.message = 'No commission rules found in Metadata for State: ' + stateCode + '. Please add it in Setup -> Custom Metadata Types.';
                return result;
            }
            
            State_Commission_Rule__mdt rule = rules[0];
            
            result.isError = false;
            result.state = stateCode;
            result.commissionFee = rule.Commission_Fee__c != null ? rule.Commission_Fee__c : 0.00;
            result.isEligible = rule.Is_Eligible__c;
            result.message = 'Commission calculated successfully.';
            
            return result;
            
        } catch(Exception e) {
            result.isError = true;
            result.message = e.getMessage();
            return result;
        }
    }
    
    public class CommissionResult {
        @AuraEnabled public Boolean isError {get;set;}
        @AuraEnabled public String message {get;set;}
        @AuraEnabled public String state {get;set;}
        @AuraEnabled public Decimal commissionFee {get;set;}
        @AuraEnabled public Boolean isEligible {get;set;}
    }
    
    @AuraEnabled
    public static void saveCommissionToRecord(Id recordId, String objectApiName, Decimal fee, Boolean eligible) {
        if (objectApiName == 'Lead') {
            Lead l = new Lead(Id = recordId, Agency_Service_Fee__c = fee, Fee_Eligible_State__c = eligible);
            update l;
        } else if (objectApiName == 'Opportunity') {
            Opportunity o = new Opportunity(Id = recordId, Agency_Service_Fee__c = fee, Fee_Eligible_State__c = eligible);
            update o;
        }
    }
}