public with sharing class VINDecoderControllerNew {

    @AuraEnabled(cacheable=false)
    public static VehicleData fetchLatestVINData(String vin) {
        if (String.isBlank(vin)) {
            throw new AuraHandledException('VIN cannot be empty.');
        }

        Http http = new Http();
        HttpRequest req = new HttpRequest();

        // NHTSA public VIN decoder API
        String apiUrl = 'https://vpic.nhtsa.dot.gov/api/vehicles/DecodeVinValuesExtended/' 
                        + vin + '?format=json';
        req.setEndpoint(apiUrl);
        req.setMethod('GET');

        HttpResponse res;
        try {
            res = http.send(req);
        } catch (Exception e) {
            throw new AuraHandledException('Callout failed: ' + e.getMessage());
        }

        if (res.getStatusCode() != 200) {
            throw new AuraHandledException('Failed to fetch VIN data. Status Code: ' + res.getStatusCode());
        }

        Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        List<Object> results = (List<Object>) result.get('Results');
        if (results.isEmpty()) {
            throw new AuraHandledException('No data found for VIN: ' + vin);
        }

        Map<String, Object> r = (Map<String, Object>) results.get(0);

        VehicleData vd = new VehicleData();
        vd.Make = (String) r.get('Make');
        vd.Model = (String) r.get('Model');
        vd.ModelYear = (String) r.get('ModelYear');
        vd.AnnualMiles = '';
        vd.Lienholder = '';
        return vd;
    }

    /**
     * Insert or Update Vehicle__c Record
     */
    @AuraEnabled
    public static Id saveVehicleRecord(Map<String, Object> vehicleData) {
        if (vehicleData == null || vehicleData.isEmpty()) {
            throw new AuraHandledException('No vehicle data provided.');
        }

        Vehicle__c v = new Vehicle__c();

        if (vehicleData.containsKey('Id') && String.valueOf(vehicleData.get('Id')) != null) {
            v.Id = (Id) vehicleData.get('Id');
        }

        v.VIN__c = (String) vehicleData.get('VIN__c');
        v.Make__c = (String) vehicleData.get('Make__c');
        v.Model__c = (String) vehicleData.get('Model__c');
        v.Year__c = (String) vehicleData.get('Year__c');
        v.Annual_Miles__c = (String) vehicleData.get('Annual_Miles__c');
        v.Lienholder__c = (String) vehicleData.get('Lienholder__c');
        v.Lead__c = (String) vehicleData.get('Lead__c');
        v.Registered_To__c = (String) vehicleData.get('Registered_To__c');
        v.Vehicle_Type__c = (String) vehicleData.get('Vehicle_Type__c');

        try {
            if (v.Id == null) {
                insert v;
            } else {
                update v;
            }
            return v.Id;
        } catch (Exception e) {
            throw new AuraHandledException('Error saving vehicle: ' + e.getMessage());
        }
    }

    public class VehicleData {
        @AuraEnabled public String Make;
        @AuraEnabled public String Model;
        @AuraEnabled public String ModelYear;
        @AuraEnabled public String AnnualMiles;
        @AuraEnabled public String Lienholder;
    }
}