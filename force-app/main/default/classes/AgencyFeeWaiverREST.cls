@RestResource(urlMapping='/WaiverAction/*')
global without sharing class AgencyFeeWaiverREST {

    @HttpGet
    global static void handleWaiver() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;

        String quoteId = req.params.get('id');
        String decision = req.params.get('decision');
        String token = req.params.get('token');

        String htmlResponse = '';

        try {
            if (String.isBlank(quoteId) || String.isBlank(decision) || String.isBlank(token)) {
                throw new AgencyWaiverException('Missing required parameters.');
            }

            // Query using security token
            List<Policy_Information__c> quotes = [
                SELECT Id, Agency_Fee_Waiver_Decision__c, Waiver_Token__c, Lead__c 
                FROM Policy_Information__c 
                WHERE Id = :quoteId 
                LIMIT 1
            ];

            if (quotes.isEmpty()) {
                throw new AgencyWaiverException('Record not found.');
            }

            Policy_Information__c quote = quotes[0];

            // Security check
            if (String.isBlank(quote.Waiver_Token__c) || quote.Waiver_Token__c != token) {
                throw new AgencyWaiverException('Invalid security token.');
            }

            if (quote.Agency_Fee_Waiver_Decision__c != 'Pending' && quote.Agency_Fee_Waiver_Decision__c != null) {
                htmlResponse = generateHtml('Notice', 'This request has already been processed: <strong>' + quote.Agency_Fee_Waiver_Decision__c + '</strong>.', '#f0ad4e');
            } else {
                quote.Agency_Fee_Waiver_Decision__c = decision;
                // Field update
                update quote;

                String color = (decision == 'Accepted') ? '#2e7d32' : '#c62828';
                htmlResponse = generateHtml('Success', 'The Agency Fee Waiver has been <strong>' + decision + '</strong>.', color);
            }

        } catch (Exception e) {
            htmlResponse = generateHtml('Request Failed', e.getMessage(), '#c62828');
        }

        res.addHeader('Content-Type', 'text/html');
        res.responseBody = Blob.valueOf(htmlResponse);
    }

    private static String generateHtml(String title, String message, String color) {
        return '<!DOCTYPE html><html><head><meta charset="utf-8"/><meta name="viewport" content="width=device-width, initial-scale=1">' +
               '<style>body{font-family: "Segoe UI", Tahoma, Geneva, Verdana, sans-serif; display: flex; justify-content: center; align-items: center; height: 100vh; margin: 0; background-color: #f5f5f5;}' +
               '.card{background: white; padding: 3rem; border-radius: 12px; box-shadow: 0 10px 25px rgba(0,0,0,0.05); text-align: center; max-width: 450px; width: 90%; border-top: 6px solid ' + color + ';}' +
               'h1{color: #333; margin-bottom: 1rem; font-size: 24px;} p{color: #555; font-size: 18px; line-height: 1.6;}</style></head>' +
               '<body><div class="card"><h1>' + title + '</h1><p>' + message + '</p></div></body></html>';
    }

    private class AgencyWaiverException extends Exception {}
}