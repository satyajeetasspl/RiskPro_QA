public class BulkLeadAPIWrapper {
    
    // Request wrapper for individual Lead data
    public class LeadInput {
        public String FirstName;
        public String LastName;
        public String Company;
        public String Email;
        public String Phone;
        public String Status;
        public String Title;
        public String LeadSource;
        public String Street;
        public String City;
        public String State;
        public String PostalCode;
        public String Country;
    }

    // Main Response Wrapper
    public class Response {
        public Integer totalReceived;
        public Integer successCount;
        public Integer failedCount;
        public List<LeadResult> successes;
        public List<ErrorResult> errors;
        
        public Response() {
            totalReceived = 0;
            successCount = 0;
            failedCount = 0;
            successes = new List<LeadResult>();
            errors = new List<ErrorResult>();
        }
    }

    public class LeadResult {
        public String leadId;
        public LeadResult(String leadId) {
            this.leadId = leadId;
        }
    }

    public class ErrorResult {
        public String message;
        public LeadInput leadData;
        public ErrorResult(String message, LeadInput leadData) {
            this.message = message;
            this.leadData = leadData;
        }
    }
}