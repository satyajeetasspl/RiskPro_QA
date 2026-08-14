public class AgentforceLeadParser {
    public class LeadData {
        @InvocableVariable public String FirstName;
        @InvocableVariable public String LastName;
        @InvocableVariable public String Company;
        @InvocableVariable public String Email;
        @InvocableVariable public String Phone;
    }

    @InvocableMethod(label='Parse Lead JSON' description='Parses JSON from Prompt Builder into Lead fields')
    public static List<LeadData> parseJson(List<String> jsonStrings) {
        List<LeadData> results = new List<LeadData>();
        for(String jsonString : jsonStrings) {
            // Remove markdown formatting that LLMs sometimes add (like ```json ... ```)
            String cleanJson = jsonString.replaceAll('```json\n?', '').replaceAll('```', '').trim();
            LeadData data = (LeadData)JSON.deserialize(cleanJson, LeadData.class);
            results.add(data);
        }
        return results;
    }
}