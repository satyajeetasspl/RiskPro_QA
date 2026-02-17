@RestResource(urlMapping='/LeadRestAPI/*')
global with sharing class LeadRestAPI {

    @HttpPost
    global static void createLead() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        res.addHeader('Content-Type','application/json');

        try {
            String body = req.requestBody == null ? '' : req.requestBody.toString();
            if (String.isBlank(body)) {
                res.statusCode = 400;
                res.responseBody = Blob.valueOf(JSON.serializePretty(new Map<String,Object>{'error'=>'Empty request body'}));
                return;
            }

            // Parse JSON into either a single map or a list of maps
            Object payload = JSON.deserializeUntyped(body);
            List<Object> recordsPayload = new List<Object>();
            if (payload instanceof Map<String,Object>) {
                recordsPayload.add(payload);
            } else if (payload instanceof List<Object>) {
                recordsPayload = (List<Object>) payload;
            } else {
                res.statusCode = 400;
                res.responseBody = Blob.valueOf(JSON.serializePretty(new Map<String,Object>{'error'=>'Invalid JSON payload'}));
                return;
            }

            // Describe Lead fields
            Map<String, Schema.SObjectField> leadFields = Schema.SObjectType.Lead.fields.getMap();

            List<Lead> toInsert = new List<Lead>();
            List<Map<String,Object>> resultList = new List<Map<String,Object>>();
            List<Map<String,Object>> errorList = new List<Map<String,Object>>();

            for (Object recObj : recordsPayload) {
                Map<String, Object> recMap = (Map<String, Object>) recObj;
                Lead l = new Lead();

                // Dynamic field population
                for (String key : recMap.keySet()) {
                    if (!leadFields.containsKey(key)) continue; // skip unknown fields

                    Schema.DescribeFieldResult dfr = leadFields.get(key).getDescribe();
                    if (!dfr.isCreateable()) continue; // respect FLS

                    Object raw = recMap.get(key);
                    if (raw == null) continue;

                    try {
                        Schema.DisplayType dt = dfr.getType();
                        String rawStr = String.valueOf(raw);

                        if (dt == Schema.DisplayType.BOOLEAN) {
                            l.put(key, Boolean.valueOf(rawStr));
                        } else if (dt == Schema.DisplayType.INTEGER) {
                            l.put(key, Integer.valueOf(rawStr));
                        } else if (dt == Schema.DisplayType.DOUBLE
                                || dt == Schema.DisplayType.CURRENCY
                                || dt == Schema.DisplayType.PERCENT) {
                            l.put(key, Double.valueOf(rawStr));
                        } else if (dt == Schema.DisplayType.DATE) {
                            // Expect YYYY-MM-DD
                            l.put(key, Date.valueOf(rawStr));
                        } else if (dt == Schema.DisplayType.DATETIME) {
                            // Accept 'YYYY-MM-DD HH:MM:SS' or ISO
                            l.put(key, Datetime.valueOf(rawStr));
                        } else {
                            // Strings, picklists, phone, email, reference, multipicklist (semicolon-delimited)
                            l.put(key, rawStr);
                        }
                    } catch (Exception exField) {
                        // conversion error for this field — record and continue
                        // we'll add a small note into the recMap errors if needed
                        // keep processing other fields
                        continue;
                    }
                }

                // Enforce required fields per Lead
                if (String.isBlank(l.LastName) && !recMap.containsKey('LastName')) {
                    // if user didn't provide LastName -> error
                    errorList.add(new Map<String,Object>{'error'=>'Missing LastName','payload'=>recMap});
                    continue;
                }
                if (String.isBlank(l.Company) && !recMap.containsKey('Company')) {
                    errorList.add(new Map<String,Object>{'error'=>'Missing Company','payload'=>recMap});
                    continue;
                }

                toInsert.add(l);
            }

            // If no records to insert (all had missing required fields)
            if (toInsert.isEmpty()) {
                res.statusCode = 400;
                res.responseBody = Blob.valueOf(JSON.serializePretty(new Map<String,Object>{'errors'=>errorList}));
                return;
            }

            // Try insert and collect successes/failures
            Database.SaveResult[] results = Database.insert(toInsert, false); // allOrNone = false => partial success possible

            for (Integer i = 0; i < results.size(); i++) {
                Database.SaveResult sr = results[i];
                if (sr.isSuccess()) {
                    resultList.add(new Map<String,Object>{'id'=>sr.getId(),'success'=>true});
                } else {
                    List<String> errs = new List<String>();
                    for (Database.Error e : sr.getErrors()) errs.add(e.getMessage());
                    errorList.add(new Map<String,Object>{'index'=>i,'errors'=>errs});
                }
            }

            // Build response object
            Map<String,Object> out = new Map<String,Object>{
                'successes' => resultList,
                'errors' => errorList
            };
            res.statusCode = (resultList.size() > 0) ? 201 : 400;
            res.responseBody = Blob.valueOf(JSON.serializePretty(out));
            return;

        } catch (Exception ex) {
            res.statusCode = 500;
            res.responseBody = Blob.valueOf(JSON.serializePretty(new Map<String,Object>{'error' => ex.getMessage()}));
            return;
        }
    }
}