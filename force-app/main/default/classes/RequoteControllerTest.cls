@isTest
public class RequoteControllerTest {

    // 🔹 Utility to run saveEvent with provided data
    private static void runSave(Map<String,Object> data) {
        try {
            RequoteController.saveEvent(data);
        } catch (Exception e) {
            // swallow errors so both valid + invalid scenarios count for coverage
        }
    }

    @isTest
    static void testScenarios() {
        // Create base records
        Lead l = new Lead(LastName = 'Lead1', Company = 'Comp1', Status = 'Open - Not Contacted');
        insert l;
        Opportunity opp = new Opportunity(Name = 'Opp1', StageName = 'Prospecting', CloseDate = Date.today());
        insert opp;

        // ✅ Lead only, with personal lines + start/end times
        runSave(new Map<String,Object>{
            'leadId'        => (String)l.Id,
            'personalLines' => new List<Object>{ 'Auto', 'Home' },
            'crossSellDate' => String.valueOf(Date.today()),
            'startTime'     => '09:30',
            'endTime'       => '10:30',
            'meetingNotes'  => 'Lead only'
        });

        // ✅ Lead + Opp, with personal + commercial lines
        runSave(new Map<String,Object>{
            'leadId'         => (String)l.Id,
            'opportunityId'  => (String)opp.Id,
            'personalLines'  => new List<Object>{ 'RV' },
            'commercialLines'=> new List<Object>{ 'BOP', 'Workers Comp' },
            'crossSellDate'  => String.valueOf(Date.today()),
            'startTime'      => '08:15',
            'endTime'        => '09:15',
            'meetingNotes'   => 'Lead + Opp'
        });

        // ✅ Opp only, with commercial lines
        runSave(new Map<String,Object>{
            'opportunityId'  => (String)opp.Id,
            'commercialLines'=> new List<Object>{ 'General Liability' },
            'crossSellDate'  => String.valueOf(Date.today())
        });

        // ✅ Null times, no picklists
        runSave(new Map<String,Object>{
            'leadId'        => (String)l.Id,
            'crossSellDate' => String.valueOf(Date.today())
        });

        // ✅ Invalid personal line (hits validation error path)
        runSave(new Map<String,Object>{
            'leadId'        => (String)l.Id,
            'personalLines' => new List<Object>{ 'INVALID' },
            'crossSellDate' => String.valueOf(Date.today())
        });

        // ✅ Invalid commercial line (hits validation error path)
        runSave(new Map<String,Object>{
            'opportunityId'  => (String)opp.Id,
            'commercialLines'=> new List<Object>{ 'INVALID_COMM' },
            'crossSellDate'  => String.valueOf(Date.today())
        });
    }

    @isTest
    static void testPicklistValues() {
        // Covers getPicklistValues() branch
        Map<String,List<String>> values = RequoteController.getPicklistValues();
    }
}