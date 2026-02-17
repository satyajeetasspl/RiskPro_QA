public with sharing class CarrierMapController {
    
    @AuraEnabled(cacheable=true)
    public static List<Carrier__c> getCarriersByState(String stateCode) {
        if (String.isBlank(stateCode)) {
            return new List<Carrier__c>();
        }
        return [
            SELECT Id, 
                   Name, 
                   Company_Name__c, 
                   Agency_Code__c, 
                   Lines__c, 
                   Overnight_Payments__c,
                   Payment_Address__Street__s,
                   Payment_Address__City__s,
                   Payment_Address__StateCode__s,
                   Payment_Address__PostalCode__s,
                   Payment_Address__CountryCode__s
            FROM Carrier__c
            WHERE Payment_Address__StateCode__s = :stateCode 
            LIMIT 100
        ];
    }
}