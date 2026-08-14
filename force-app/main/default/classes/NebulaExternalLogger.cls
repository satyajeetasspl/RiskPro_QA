@RestResource(urlMapping='/ExternalLogger/*')
global with sharing class NebulaExternalLogger {
    global class LogEntry {
        public String loggingLevel;
        public String message;
        public String originLocation;
    }
    global class LogRequest {
        public String fileName;
        public Integer totalLeads;
        public Integer successCount;
        public Integer failedCount;
        public List<LogEntry> logEntries;
    }
 
    @HttpPost
    global static void createLogs() {
        RestRequest req = RestContext.request;
        String requestBody = req.requestBody.toString();
        try {
            LogRequest payload = (LogRequest)JSON.deserialize(requestBody, LogRequest.class);
            if (payload.logEntries != null) {
                for (LogEntry entry : payload.logEntries) {
                    // Map the string level to Nebula's LoggingLevel enum
                    System.LoggingLevel level = System.LoggingLevel.ERROR;
                    if (entry.loggingLevel == 'WARN') level = System.LoggingLevel.WARN;
                    else if (entry.loggingLevel == 'INFO') level = System.LoggingLevel.INFO;
                    else if (entry.loggingLevel == 'DEBUG') level = System.LoggingLevel.DEBUG;
                    // Create the Nebula Log entry
                    Logger.error('[' + entry.originLocation + '] ' + entry.message);
                }
                // Commit the logs to the database
                Logger.saveLog();

                // Send email alert if lead summary counts are provided
                if (payload.totalLeads != null) {
                    List<String> errorMessages = new List<String>();
                    for (LogEntry entry : payload.logEntries) {
                        if (entry.loggingLevel == 'ERROR') {
                            errorMessages.add('[' + entry.originLocation + '] ' + entry.message);
                        }
                    }
                    EmailAlertUtility.sendLeadProcessingEmail(
                        payload.fileName != null ? payload.fileName : 'External Logger',
                        payload.totalLeads,
                        payload.successCount != null ? payload.successCount : 0,
                        payload.failedCount != null ? payload.failedCount : 0,
                        errorMessages
                    );
                }
            }
        } catch (Exception e) {
            System.debug('Failed to parse external log: ' + e.getMessage());
        }
    }
}