public class PartnerTriggerHandler implements TriggerInterface {

    // PHASE 1: GENERATE THE CODE (Before Insert)
    public void beforeInsert(List<SObject> newList) {
        for (SObject so : newList) {
            Partner__c p = (Partner__c) so; // Cast generic SObject to Partner__c
            
            Integer randomCode = Crypto.getRandomInteger();
            p.Verification_Code__c = String.valueOf(Math.abs(randomCode)).leftPad(6, '0').substring(0,6);
            p.Is_Verified__c = false;
        }
    }

    // PHASE 2: SEND THE EMAIL (After Insert)
    public void afterInsert(Map<Id, SObject> newMap) {
        List<Messaging.SingleEmailMessage> emailsToSend = new List<Messaging.SingleEmailMessage>();

        // Notice we iterate over newMap.values() here based on your Factory setup
        for (SObject so : newMap.values()) {
            Partner__c p = (Partner__c) so; 
            
            if (String.isNotBlank(p.Email__c)) {
                Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
                mail.setToAddresses(new String[] { p.Email__c });
                mail.setSubject('Verify Your Riskpro Account');
                
                String messageBody = 'Hello,\n\n';
                messageBody += 'Please verify your account.\n';
                messageBody += 'Your Verification Code is: ' + p.Verification_Code__c + '\n\n';
               
                
                mail.setPlainTextBody(messageBody);
                emailsToSend.add(mail);
            }
        }

        if (!emailsToSend.isEmpty()) {
            Messaging.sendEmail(emailsToSend);
        }
    }

    // Unused interface methods must still be included but left blank
    public void beforeUpdate(Map<Id, SObject> newMap, Map<Id, SObject> oldMap) {}
    public void beforeDelete(Map<Id, SObject> oldMap) {}
    public void afterUpdate(Map<Id, SObject> newMap, Map<Id, SObject> oldMap) {}
    public void afterDelete(Map<Id, SObject> oldMap) {}
    public void afterUnDelete(Map<Id, SObject> newMap) {}
}