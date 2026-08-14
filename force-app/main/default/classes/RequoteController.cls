public class RequoteController {
    @AuraEnabled
    public static void saveEvent(Map<String, Object> data) {
        try {
            Event ev = new Event();

            // --- 1. SAFE ID EXTRACTION & ROUTING ---
            Id validWhoId = null;
            Id validWhatId = null;

            // Check 'leadId' param
            if (data.containsKey('leadId') && String.isNotBlank((String)data.get('leadId'))) {
                Id tempId = (Id)data.get('leadId');
                String sObjName = tempId.getSObjectType().getDescribe().getName();
                
                if (sObjName == 'Lead' || sObjName == 'Contact') {
                    validWhoId = tempId;
                } else if (sObjName == 'Opportunity') {
                    validWhatId = tempId; // Auto-correct if Opp ID was passed as Lead
                }
            }

            // Check 'opportunityId' param
            if (data.containsKey('opportunityId') && String.isNotBlank((String)data.get('opportunityId'))) {
                Id tempId = (Id)data.get('opportunityId');
                if (tempId.getSObjectType().getDescribe().getName() == 'Opportunity') {
                    validWhatId = tempId;
                }
            }

            // --- 2. ASSIGN IDS TO EVENT ---
            // Rule: You cannot link a Lead (WhoId) and an Opportunity (WhatId) at the same time.
            if (validWhoId != null && validWhoId.getSObjectType() == Lead.SObjectType) {
                ev.WhoId = validWhoId;
                ev.WhatId = null; // Explicitly ensure WhatId is null
            } else {
                //ev.WhoId = validWhoId;
                ev.WhatId = validWhatId;
            }

            // --- 3. CUSTOM FIELDS ---
            if (data.containsKey('personalLines') && data.get('personalLines') != null) {
                List<Object> pl = (List<Object>)data.get('personalLines');
                List<String> plStrings = new List<String>();
                for (Object o : pl) plStrings.add(String.valueOf(o));
                
                if (!plStrings.isEmpty()) {
                    validatePersonalLines(plStrings);
                    ev.Personal_Lines__c = String.join(plStrings, ';');
                }
            }
            if (data.containsKey('commercialLines') && data.get('commercialLines') != null) {
                List<Object> cl = (List<Object>)data.get('commercialLines');
                List<String> clStrings = new List<String>();
                for (Object o : cl) clStrings.add(String.valueOf(o));
                
                if (!clStrings.isEmpty()) {
                    validateCommercialLines(clStrings);
                    ev.Commercial_Lines__c = String.join(clStrings, ';');
                }
            }

            // --- 4. DATE & TIME HANDLING ---
            if (data.get('crossSellDate') != null) {
                ev.Requote_Date__c = Date.valueOf((String)data.get('crossSellDate'));
            }

            if (data.get('startTime') != null && data.get('crossSellDate') != null) {
                ev.StartDateTime = combineDateAndTime(
                    (String)data.get('crossSellDate'),
                    (String)data.get('startTime')
                );
                // Default EndTime = StartTime + 30 mins
                if (data.get('endTime') == null) {
                    ev.EndDateTime = ev.StartDateTime.addMinutes(30);
                }
            }

            if (data.get('endTime') != null && data.get('crossSellDate') != null) {
                ev.EndDateTime = combineDateAndTime(
                    (String)data.get('crossSellDate'),
                    (String)data.get('endTime')
                );
            }

            // --- 5. FINAL FIELDS & INSERT ---
            ev.Meeting_Notes__c = (String)data.get('meetingNotes');
            ev.Subject = 'Requote Meeting';
            ev.Requote__c = true;
            
            insert ev;

            // --- 6. UPDATE RELATED RECORDS ---
            // Optimized: No SOQL queries needed to update via ID
            
            if (validWhoId != null && validWhoId.getSObjectType() == Lead.SObjectType) {
                Lead l = new Lead(Id = validWhoId, Requote__c = true);
                update l;
            }
            
            // Update Opportunity if validWhatId exists (even if not linked to Event due to Lead rule)
            if (validWhatId != null) {
                Opportunity opp = new Opportunity(Id = validWhatId, Requote__c = true);
                update opp;
            }

        } catch (Exception e) {
            System.debug('❌ EventController Error: ' + e.getMessage());
            // Pass the REAL error message to LWC
            throw new AuraHandledException(e.getMessage());
        }
    }

    // --- UTILITIES (Unchanged) ---
    private static Datetime combineDateAndTime(String dateStr, String timeStr) {
        if (String.isBlank(dateStr) || String.isBlank(timeStr)) return null;
        Date d = Date.valueOf(dateStr);
        List<String> parts = timeStr.split(':');
        Integer hour   = Integer.valueOf(parts[0]);
        Integer minute = parts.size() > 1 ? Integer.valueOf(parts[1]) : 0;
        return Datetime.newInstance(d.year(), d.month(), d.day(), hour, minute, 0);
    }

    private static void validatePersonalLines(List<String> incoming) {
        Set<String> allowed = new Set<String>(getPersonalLines());
        for (String val : incoming) {
            if (!allowed.contains(val)) throw new AuraHandledException('Invalid Personal Line value: ' + val);
        }
    }

    private static void validateCommercialLines(List<String> incoming) {
        Set<String> allowed = new Set<String>(getCommercialLines());
        for (String val : incoming) {
            if (!allowed.contains(val)) throw new AuraHandledException('Invalid Commercial Line value: ' + val);
        }
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, List<String>> getPicklistValues() {
        Map<String, List<String>> result = new Map<String, List<String>>();
        result.put('personalLines', getPersonalLines());
        result.put('commercialLines', getCommercialLines());
        return result;
    }

    private static List<String> getPersonalLines() {
        return new List<String>{
            'Auto','Boat','Classic','Condo','Earthquake','Flood','Golf Cart',
            'Home','Inland Marine','Manufactured','Mobile','Motorcycle','Off-Road',
            'Pet','Renters','RV','Snowmobile','SPP','Umbrella'
        };
    }

    private static List<String> getCommercialLines() {
        return new List<String>{
            'BOP','Builders Risk','Comm’l Auto','Comm’l Flood','Comm’l Package',
            'Comm’l Property','Comm’l Umbrella','Cyber Liability','D&O','E&O',
            'EPLI','Event','Garagekeepers','Garage Liability','General Liability',
            'Inland Marine','Liquor Liability','Product Liability','Trucking','Workers Comp'
        };
    }
}