@isTest
public with sharing class CarrierMapControllerTest {

    @isTest
    static void testGetCarriersByState() {
        Carrier__c carrier = new Carrier__c(
            Company_Name__c = 'Test Company',
            Agency_Code__c = 'AG001',
            Lines__c = 'Auto',
            Overnight_Payments__c = 'Yes', 
            Payment_Address__Street__s = '123 Test St',
            Payment_Address__City__s = 'Test City',
            Payment_Address__StateCode__s = 'CA',
            Payment_Address__PostalCode__s = '90001',
            Payment_Address__CountryCode__s = 'US'
        );
        insert carrier;

        Test.startTest();
        List<Carrier__c> result = CarrierMapController.getCarriersByState('CA');
        List<Carrier__c> emptyResult = CarrierMapController.getCarriersByState('');
        Test.stopTest();
    }
}