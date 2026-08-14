public with sharing class LeadTriggerHandler implements TriggerInterface {
    public void beforeInsert(List<SObject> newRecords) {}
    public void beforeUpdate(Map<Id, SObject> mapNewRecords, Map<Id, SObject> mapOldRecords) {
        validateAgencyFeesForDispositions(mapNewRecords, mapOldRecords);
    }

    private void validateAgencyFeesForDispositions(Map<Id, SObject> mapNewRecords, Map<Id, SObject> mapOldRecords) {
        Set<Id> leadIdsToCheck = new Set<Id>();
        for (Id leadId : mapNewRecords.keySet()) {
            Lead newLd = (Lead) mapNewRecords.get(leadId);
            Lead oldLd = (Lead) mapOldRecords.get(leadId);
            if ((newLd.IsConverted && !oldLd.IsConverted) || (newLd.Status == 'Not Sold' && oldLd.Status != 'Not Sold')) {
                leadIdsToCheck.add(leadId);
            }
        }
        
        if (leadIdsToCheck.isEmpty()) {
            return;
        }

        List<Policy_Information__c> policies = [
            SELECT Id, Lead__c, Premium__c, Agency_Fee__c, Policy_Status__c, Policy_Bound__c, 
                   Replacement_Initiated__c, Is_Replacement__c, Original_Policy__c, 
                   Replacement_Credit_Status__c, Available_Credit_Amount__c, Refundable_Balance_Amount__c, 
                   Credit_Applied_Amount__c,
                   (SELECT Status__c FROM Agency_Fee_Invoices__r ORDER BY CreatedDate DESC LIMIT 1)
            FROM Policy_Information__c
            WHERE Lead__c IN :leadIdsToCheck
        ];

        Map<Id, List<Policy_Information__c>> leadToPolicies = new Map<Id, List<Policy_Information__c>>();
        for (Policy_Information__c p : policies) {
            if (!leadToPolicies.containsKey(p.Lead__c)) {
                leadToPolicies.put(p.Lead__c, new List<Policy_Information__c>());
            }
            leadToPolicies.get(p.Lead__c).add(p);
        }

        for (Id leadId : leadIdsToCheck) {
            Lead newLd = (Lead) mapNewRecords.get(leadId);
            List<Policy_Information__c> leadPols = leadToPolicies.get(leadId);
            if (leadPols == null) continue;
            
            Boolean hasUnresolved = false;
            String unresolvedReason = '';
            
            for (Policy_Information__c p : leadPols) {
                // Ignore Rejected or Abandoned quotes
                if (p.Policy_Status__c == 'Rejected' || p.Policy_Status__c == 'Abandoned') {
                    continue;
                }
                
                // 1. Check for balance due on active quotes
                if (p.Policy_Bound__c != 'No' && !p.Replacement_Initiated__c) {
                    Decimal newFee = p.Agency_Fee__c != null ? p.Agency_Fee__c : 0;
                    if (newFee > 0) {
                        Boolean isPaid = false;
                        if (p.Agency_Fee_Invoices__r != null && !p.Agency_Fee_Invoices__r.isEmpty()) {
                            if (p.Agency_Fee_Invoices__r[0].Status__c == 'Paid') {
                                isPaid = true;
                            }
                        }
                        Boolean isCreditApplied = (p.Replacement_Credit_Status__c == 'Applied' || p.Replacement_Credit_Status__c == 'Refunded');
                        Decimal creditAppliedAmt = p.Credit_Applied_Amount__c != null ? p.Credit_Applied_Amount__c : 0;
                        if (creditAppliedAmt >= newFee) {
                            isCreditApplied = true;
                        }
                        
                        if (!isPaid && !isCreditApplied) {
                            hasUnresolved = true;
                            unresolvedReason = 'Quote #' + (p.Quote__c != null ? p.Quote__c : 'N/A') + ' has an unpaid agency fee balance of $' + newFee.setScale(2) + '.';
                            break;
                        }
                    }
                }
                
                // 2. Check for original policies that have been replaced and have unresolved credit/refunds
                if (p.Replacement_Initiated__c || p.Policy_Bound__c == 'No') {
                    Decimal availCredit = p.Available_Credit_Amount__c != null ? p.Available_Credit_Amount__c : 0;
                    Decimal refundBal = p.Refundable_Balance_Amount__c != null ? p.Refundable_Balance_Amount__c : 0;
                    if (availCredit > 0 || refundBal > 0) {
                        Boolean isCreditAppliedOrRefunded = (p.Replacement_Credit_Status__c == 'Applied' || p.Replacement_Credit_Status__c == 'Refunded');
                        if (!isCreditAppliedOrRefunded) {
                            hasUnresolved = true;
                            unresolvedReason = 'Quote #' + (p.Quote__c != null ? p.Quote__c : 'N/A') + ' has an outstanding credit or refund of $' + (availCredit > 0 ? availCredit : refundBal).setScale(2) + ' that has not been applied or issued.';
                            break;
                        }
                    }
                }
            }
            
            if (hasUnresolved) {
                if (newLd.IsConverted) {
                    newLd.addError('Cannot convert Lead while unresolved agency-fee activity exists: ' + unresolvedReason);
                } else {
                    newLd.addError('Cannot set Lead stage to Not Sold while unresolved agency-fee activity exists: ' + unresolvedReason);
                }
            }
        }
    }
    public void beforeDelete(Map<Id, SObject> mapOldRecords) {}
    public void afterInsert(Map<Id, SObject> mapNewRecords) {}
    public void afterDelete(Map<Id, SObject> mapOldRecords) {}
    public void afterUnDelete(Map<Id, SObject> mapNewRecords) {}

    public void afterUpdate(Map<Id, SObject> mapNewRecords, Map<Id, SObject> mapOldRecords) {
        System.debug('### LeadTriggerHandler: afterUpdate Started');
        HistoryTrackingController.processChanges(mapNewRecords.values(), mapOldRecords, 'Lead');
        LeadCadenceHelper.updateCandenceOwner(mapNewRecords, mapOldRecords);

        Id nbcQueueId;
        List<Group> queues = [SELECT Id FROM Group WHERE Type = 'Queue' AND Name = 'NBC Queue' LIMIT 1];
        if (!queues.isEmpty()) nbcQueueId = queues[0].Id;
        
        // Standard Conversion Lists
        List<Lead> leadsToConvert = new List<Lead>();
        Map<String, String> leadAccountMap = new Map<String, String>();
        List<Contact> contactsToUpsert = new List<Contact>();
        List<Case> casesToInsert = new List<Case>();
        List<Account> accountsToUpdate = new List<Account>(); 
        List<Opportunity> oppsToUpsert = new List<Opportunity>();
        Map<Id, Id> leadOppMap = new Map<Id, Id>(); 
        Map<Id, Opportunity> leadToOppMapForFiles = new Map<Id, Opportunity>(); 
        List<Policy_Information__c> policyInfosToUpdate = new List<Policy_Information__c>();
        
        // Custom Object Lists (Now including Drivers and Vehicles)
        List<Auto_Incidents_Violations__c> incidentsToUpdate = new List<Auto_Incidents_Violations__c>();
        List<Property_Information__c> propInfosToUpdate = new List<Property_Information__c>();
        List<Properties__c> propertiesToUpdate = new List<Properties__c>();
        List<Home_Losses_Claims__c> homeLossesToUpdate = new List<Home_Losses_Claims__c>();
        List<Driver__c> driversToUpdate = new List<Driver__c>(); 
        List<Vehicle__c> vehiclesToUpdate = new List<Vehicle__c>();
        List<Prior_Insurance_Information__c> priorInfoToUpdate = new List<Prior_Insurance_Information__c>();
        List<Cross_Sell__c> crossSellsToUpdate = new List<Cross_Sell__c>(); 
        List<History_Tracking__c> historyTrackingToUpdate = new List<History_Tracking__c>(); 
        List<Note_History_Logs__c> noteHistoryLogsToUpdate = new List<Note_History_Logs__c>(); 

        Set<String> neededBranchNames = new Set<String>{'HOUSE ACCOUNT'};
        Set<String> neededDivNames = new Set<String>{'Mortgage Broker Partners', 'HOUSE ACCOUNT'};
        Set<String> neededDeptNames = new Set<String>{'Department one'};
        Set<String> neededGroupNames = new Set<String>{'Group one'};
        
        // 1. Collect Branch Names needed
        for (Id leadId : mapNewRecords.keySet()) {
            Lead l = (Lead) mapNewRecords.get(leadId);
            Lead oldL = (Lead) mapOldRecords.get(leadId);
            if (l.IsConverted && !oldL.IsConverted && l.LeadSource == 'Partner' && l.Partner_Name__c != null) {
                neededBranchNames.add(l.Partner_Name__c);
            }
        }
        System.debug('### Needed Branches: ' + neededBranchNames); 

        // 2. Query Setup Data
        Map<String, Id> branchMap = new Map<String, Id>();
        for (vert__AMS360_Branch__c b : [SELECT Id, Name FROM vert__AMS360_Branch__c WHERE Name IN :neededBranchNames]) {
            branchMap.put(b.Name, b.Id);
        }

        Map<String, Id> divisionMap = new Map<String, Id>();
        for (vert__AMS360_Division__c d : [SELECT Id, Name FROM vert__AMS360_Division__c WHERE Name IN :neededDivNames]) {
            divisionMap.put(d.Name, d.Id);
        }

        Map<String, Id> deptMap = new Map<String, Id>();
        for (vert__AMS360_Department__c d : [SELECT Id, Name FROM vert__AMS360_Department__c WHERE Name IN :neededDeptNames]) {
            deptMap.put(d.Name, d.Id);
        }

        Map<String, Id> groupMap = new Map<String, Id>();
        for (vert__AMS360_Group__c g : [SELECT Id, Name FROM vert__AMS360_Group__c WHERE Name IN :neededGroupNames]) {
            groupMap.put(g.Name, g.Id);
        }


        // 3. Main Loop: Process Conversion Logic
        for (Id leadId : mapNewRecords.keySet()) {
            Lead newLd = (Lead) mapNewRecords.get(leadId);
            Lead oldLd = (Lead) mapOldRecords.get(leadId);

            if (newLd.IsConverted && !oldLd.IsConverted && newLd.ConvertedAccountId != null) {
                System.debug('### Processing Conversion for Lead: ' + newLd.Id + ' -> Account: ' + newLd.ConvertedAccountId); 
                leadAccountMap.put(newLd.Id, newLd.ConvertedAccountId);
                leadsToConvert.add(newLd);
                
                if (newLd.ConvertedOpportunityId != null) {
                    leadOppMap.put(newLd.Id, newLd.ConvertedOpportunityId);
                }

                // --- Contact Logic ---
                if (newLd.ConvertedContactId != null) {
                    Contact primaryContact = new Contact(Id = newLd.ConvertedContactId);
                    primaryContact.Insured_Role__c = 'First Insured';
                    primaryContact.Phone = newLd.Borrowers_Phone_Number__c;
                    primaryContact.MobilePhone = newLd.Phone_2__c;
                    primaryContact.Email = newLd.Email;
                    primaryContact.vert__AMS360_Contact_Email__c = newLd.Email;
                    primaryContact.Birthdate = newLd.Borrower_DOB__c;
                    primaryContact.Occupation__c = newLd.First_insured_Occupation__c;
                    primaryContact.Education__c = newLd.Education__c;
                    primaryContact.Marital_Status__c = newLd.Marital_Status_FI__c;
                    primaryContact.Drivers_License__c = newLd.Driver_s_License__c;
                    primaryContact.Drivers_License_State__c = newLd.Drivers_License_State__c;
                    primaryContact.Fax = newLd.Fax;
                    primaryContact.Title = newLd.Title;
                    primaryContact.MailingStreet = newLd.Insured_Address__Street__s;
                    primaryContact.MailingCity = newLd.Insured_Address__City__s;
                    primaryContact.MailingState = newLd.Insured_Address__StateCode__s;
                    primaryContact.MailingPostalCode = newLd.Insured_Address__PostalCode__s;
                    primaryContact.MailingCountry = newLd.Insured_Address__CountryCode__s;
                    contactsToUpsert.add(primaryContact);
                }

                if (String.isNotBlank(newLd.Second_Insured_First_Name__c)) {
                    Contact secondaryContact = new Contact();
                    secondaryContact.AccountId = newLd.ConvertedAccountId;
                    secondaryContact.Insured_Role__c = 'Second Named Insured';
                    secondaryContact.FirstName = newLd.Second_Insured_First_Name__c;
                    secondaryContact.LastName = newLd.Second_Insured_Last_Name__c;
                    secondaryContact.Marital_Status__c = newLd.Marital_Status_SI__c;
                    secondaryContact.Occupation__c = newLd.Second_Insured_Occupation__c;
                    secondaryContact.Education__c = newLd.Second_Insured_Education__c;
                    secondaryContact.Phone = newLd.Second_Insured_Phone_1__c;
                    secondaryContact.MobilePhone = newLd.Second_Insured_Phone_2__c;
                    secondaryContact.Email = newLd.Second_Insured_Email__c;
                    secondaryContact.Birthdate = newLd.Second_Insureds_DOB__c;
                    secondaryContact.Drivers_License__c = newLd.Second_Insured_Drivers_License__c;
                    secondaryContact.Drivers_License_State__c = newLd.Second_Insured_Drivers_License_State__c;
                    secondaryContact.OtherStreet = newLd.Street;
                    secondaryContact.OtherCity = newLd.City;
                    secondaryContact.OtherState = newLd.State;
                    secondaryContact.OtherPostalCode = newLd.PostalCode;
                    secondaryContact.OtherCountry = newLd.Country;
                    contactsToUpsert.add(secondaryContact);
                }

                // --- Account Logic ---
                Account acc = new Account(Id = newLd.ConvertedAccountId);      
                
                String constructedName = (String.isNotBlank(newLd.FirstName) ? newLd.FirstName + ' ' : '') + 
                                         (newLd.LastName != null ? newLd.LastName : '');
                acc.Policy_Check_Comments__c = newLd.Policy_Check_Comments__c;
                acc.Policy_Check_Status__c = newLd.Policy_Check_Status__c;
                acc.Policy_Check_Summary__c = newLd.Policy_Check_Summary__c;
                acc.Notes_For_CSR__c = newLd.Notes_For_CSR__c;
                acc.Agent_Notes__c = newLd.Agent_Notes__c;
                acc.CSR_Work_Order__c = newLd.CSR_Work_Order__c;
                acc.Comments__c = newLd.Comments__c;

                acc.Name = constructedName; 
                acc.vert__AMS360_Firm_Name__c = constructedName; 
                acc.vert__AMS360_First_Name__c = newLd.FirstName;
                acc.vert__AMS360_Last_Name__c = newLd.LastName;
                acc.vert__AMS360_Group__c = newLd.vert__AMS360_Group__c;
                acc.vert__AMS360_Branch__c = newLd.vert__AMS360_Branch__c;
                acc.vert__AMS360_Department__c = newLd.vert__AMS360_Department__c;
                acc.vert__AMS360_Division__c = newLd.vert__AMS360_Division__c;
                acc.vert__AMS360_Company_Email_Address2__c = newLd.Email;
                acc.vert__Mobile_Phone__c = newLd.Borrowers_Phone_Number__c;
                acc.vert__Other_Phone__c = newLd.Phone_2__c;
                acc.vert__AMS360_Employee_Account_Exec__c = newLd.vert__AMS360_Employee_Account_Exec__c;
                acc.vert__AMS360_Employee_Account_Rep__c = newLd.vert__AMS360_Employee_Account_Rep__c;
                acc.vert__AMS360_Type_of_Business__c = newLd.vert__AMS360_Type_of_Business__c;
                
                acc.BillingStreet = newLd.Insured_Address__Street__s;
                acc.BillingCity = newLd.Insured_Address__City__s;
                acc.BillingState = newLd.Insured_Address__StateCode__s;
                acc.BillingPostalCode = newLd.Insured_Address__PostalCode__s;
                acc.BillingCountry = newLd.Insured_Address__CountryCode__s;
                acc.Address_Property__Street__s     =newLd.street;
                acc.Address_Property__City__s       = newLd.city;
                acc.Address_Property__StateCode__s   = newLd.State;
                acc.Address_Property__PostalCode__s = newLd.postalCode;

                
                acc.First_Name_FI__c = newLd.FirstName;
                acc.Last_Name_FI__c = newLd.LastName;
                acc.Company__c = newLd.Company;
                acc.Commercial_Lines__c = newLd.Commercial_Lines__c;
                acc.Personal_Lines__c = newLd.Personal_Lines__c;
                acc.Phone = newLd.Borrowers_Phone_Number__c;
                acc.Same_Address_listed_in_Insured_s_Contact__c = newLd.Same_Address_listed_in_Insured_s_Contact__c;
                acc.Add_Second_Named_Insured__c = newLd.Add_Second_Named_Insured__c;
                acc.Fax = newLd.Fax;
                acc.Website = newLd.Website;
                acc.Phone_2_FI__c = newLd.Phone_2__c;
                acc.Email__c = newLd.Email;
                acc.Insured_DOB__c = newLd.Borrower_DOB__c;
                acc.First_Insured_Occupation__c = newLd.First_insured_Occupation__c;
                acc.First_Insured_Education__c = newLd.Education__c;
                acc.First_Insured_Marital_Status__c = newLd.Marital_Status_FI__c;
                acc.First_Insured_Driver_S_License__c = newLd.Driver_s_License__c;
                acc.First_Insured_Driver_S_License_State__c = newLd.Drivers_License_State__c;
				acc.Referral_Type__c = newLd.Referral_Type__c;
				acc.Referral_Source_Name__c = newLd.Referral_Source_Name__c;
				acc.Lead_Source__c = newLd.LeadSource; 
				acc.Lead_Status__c = newLd.Status;
				acc.Can_we_contact_the_prospect_directly__c = newLd.Can_we_contact_the_borrower_directly__c;
				acc.Loan_Officer_Name__c = newLd.Loan_Officer_Name__c; 
				acc.Loan_Officer_Email__c = newLd.Loan_Officer_Email__c;
				acc.Estimated_Closing_Date__c = newLd.Estimated_Closing_Date__c;
				acc.Escrowed__c = newLd.Escrowed__c;
				acc.Initial_Payment_Method_If_Escrowed__c = newLd.Initial_Payment__c;
				acc.Loan__c = newLd.Loan__c;
				acc.Mortgage_Type__c = newLd.Mortgage_Type__c;
				acc.Mortgage_Amount__c = newLd.Mortgage_Amount__c;
				acc.Mortgagee_Clause__c = newLd.Mortgagee_Clause__c;
                acc.Processor_Name__c = newLd.Processor_Name__c;
                acc.Processor_Email__c = newLd.Processor_Email__c;
                acc.Relationship_to_Insured__c = newLd.Relationship_to_Insured__c;
                acc.Partner_Name__c = newLd.Partner_Name__c;
                acc.Prospect_Type__c = newLd.Prospect_Type__c;
                acc.Description = newLd.Description;
                acc.Agent_2__c = newLd.Agent_2__c;
                acc.Date_Bound__c = newLd.Date_Bound__c;
                acc.Rewrite__c = newLd.Rewrite__c;
                acc.Is_NBC__c = newLd.Is_NBC__c;
                
                // Map NBC Address (Custom Address fields must be mapped by component)
                acc.NBC_Address__Street__s      = newLd.NBC_Address__Street__s;
                acc.NBC_Address__City__s        = newLd.NBC_Address__City__s;
                acc.NBC_Address__StateCode__s   = newLd.NBC_Address__StateCode__s;
                acc.NBC_Address__PostalCode__s  = newLd.NBC_Address__PostalCode__s;
                acc.NBC_Address__CountryCode__s = newLd.NBC_Address__CountryCode__s;
                
                if (String.isNotBlank(newLd.Second_Insured_First_Name__c)) {
                acc.Second_Insured_First_Name__c = newLd.Second_Insured_First_Name__c;
                acc.Second_Insured_Last_Name__c = newLd.Second_Insured_Last_Name__c;
                acc.Second_Insured_Email__c = newLd.Second_Insured_Email__c;
                acc.Second_Insured_Phone__c = newLd.Second_Insured_Phone_1__c;
                acc.Second_Insured_Phone_2__c = newLd.Second_Insured_Phone_2__c;
                acc.Second_Insured_DOB__c = newLd.Second_Insureds_DOB__c;
                acc.Second_Insured_Occupation__c = newLd.Second_Insured_Occupation__c;
                acc.Second_Insured_Education__c = newLd.Second_Insured_Education__c;
                acc.Second_Insured_Marital_Status__c = newLd.Marital_Status_SI__c;
                acc.Second_Insured_Drivers_License__c = newLd.Second_Insured_Drivers_License__c;
                acc.Second_Insured_Drivers_License_State__c = newLd.Second_Insured_Drivers_License_State__c;
                acc.Add_Second_Named_Insured__c = true;
            }
                
                if (acc.vert__AMS360_Department__c == null && deptMap.containsKey('Department one')) {
                    acc.vert__AMS360_Department__c = deptMap.get('Department one');
                }
                if (acc.vert__AMS360_Group__c == null && groupMap.containsKey('Group one')) {
                    acc.vert__AMS360_Group__c = groupMap.get('Group one');
                }

                if (newLd.LeadSource == 'Partner') {
                    if (acc.vert__AMS360_Division__c == null && divisionMap.containsKey('Mortgage Broker Partners')) {
                        acc.vert__AMS360_Division__c = divisionMap.get('Mortgage Broker Partners');
                    }
                    if (newLd.Partner_Name__c != null && branchMap.containsKey(newLd.Partner_Name__c)) {
                        acc.vert__AMS360_Branch__c = branchMap.get(newLd.Partner_Name__c);
                    }
                } else {
                    if (acc.vert__AMS360_Division__c == null && divisionMap.containsKey('HOUSE ACCOUNT')) {
                        acc.vert__AMS360_Division__c = divisionMap.get('HOUSE ACCOUNT');
                    }
                    if (acc.vert__AMS360_Branch__c == null && branchMap.containsKey('HOUSE ACCOUNT')) {
                        acc.vert__AMS360_Branch__c = branchMap.get('HOUSE ACCOUNT');
                    }
                }
				System.debug(JSON.serializePretty(acc));
                System.debug(JSON.serializePretty(newLd));
                accountsToUpdate.add(acc);

                // --- Case Logic ---
                Case convCase = new Case();
                String fullName = (String.isNotBlank(newLd.FirstName) ? newLd.FirstName + ' ' : '') + (newLd.LastName != null ? newLd.LastName : '');
                convCase.Subject = 'NBC - ' + fullName.trim();
                convCase.Origin = 'Lead Conversion';
                convCase.AccountId = newLd.ConvertedAccountId;
                convCase.ContactId = newLd.ConvertedContactId;
                convCase.Priority = 'Medium';
                convCase.OwnerId = (nbcQueueId != null) ? nbcQueueId : newLd.OwnerId;
                casesToInsert.add(convCase);
                
                // --- OPPORTUNITY BLOCK ---
                Opportunity opp = new Opportunity();
                
                if (newLd.ConvertedOpportunityId != null) {
                    opp.Id = newLd.ConvertedOpportunityId;
                } else {
                    opp.AccountId = newLd.ConvertedAccountId;
                    opp.Name = fullName.trim() + ' - Policy Opportunity';
                    opp.CloseDate = Date.today().addDays(30);
                    opp.StageName = 'New'; 
                }

                // Map fields over so the LWC modals work perfectly
                opp.Is_NBC__c = newLd.Is_NBC__c; 
                opp.Policy_Check_Status__c = newLd.Policy_Check_Status__c;
                opp.Policy_Check_Comments__c = newLd.Policy_Check_Comments__c;
                opp.Agent_2__c = newLd.Agent_2__c;
                opp.Date_Bound__c = newLd.Date_Bound__c;
                opp.Rewrite__c = newLd.Rewrite__c;
                
                oppsToUpsert.add(opp);
                leadToOppMapForFiles.put(newLd.Id, opp);
            }
        }

        // 4. Custom Object Logic: Re-parenting (NOW INCLUDES DRIVERS & VEHICLES)
        if (!leadAccountMap.isEmpty()) {
            
            // Auto Incidents
            for (Auto_Incidents_Violations__c rec : [SELECT Id, Lead__c FROM Auto_Incidents_Violations__c WHERE Lead__c IN :leadAccountMap.keySet()]) {
                if(leadAccountMap.containsKey(rec.Lead__c)) {
                    rec.Account__c = leadAccountMap.get(rec.Lead__c);
                    incidentsToUpdate.add(rec);
                }
            }

            // Property Information
            for (Property_Information__c rec : [SELECT Id, Lead__c FROM Property_Information__c WHERE Lead__c IN :leadAccountMap.keySet()]) {
                if(leadAccountMap.containsKey(rec.Lead__c)) {
                    rec.Account__c = leadAccountMap.get(rec.Lead__c);
                    propInfosToUpdate.add(rec);
                }
            }

            // Properties
            for (Properties__c rec : [SELECT Id, Lead__c FROM Properties__c WHERE Lead__c IN :leadAccountMap.keySet()]) {
                if(leadAccountMap.containsKey(rec.Lead__c)) {
                    rec.Account__c = leadAccountMap.get(rec.Lead__c);
                    propertiesToUpdate.add(rec);
                }
            }

            // Home Losses Claims
            for (Home_Losses_Claims__c rec : [SELECT Id, Lead__c FROM Home_Losses_Claims__c WHERE Lead__c IN :leadAccountMap.keySet()]) {
                if(leadAccountMap.containsKey(rec.Lead__c)) {
                    rec.Account__c = leadAccountMap.get(rec.Lead__c);
                    homeLossesToUpdate.add(rec);
                }
            }
            
            // Drivers 
            for (Driver__c rec : [SELECT Id, Lead__c FROM Driver__c WHERE Lead__c IN :leadAccountMap.keySet()]) {
                if(leadAccountMap.containsKey(rec.Lead__c)) {
                    rec.Account__c = leadAccountMap.get(rec.Lead__c);
                    driversToUpdate.add(rec);
                }
            }

            // Vehicles 
            for (Vehicle__c rec : [SELECT Id, Lead__c FROM Vehicle__c WHERE Lead__c IN :leadAccountMap.keySet()]) {
                if(leadAccountMap.containsKey(rec.Lead__c)) {
                    rec.Account__c = leadAccountMap.get(rec.Lead__c);
                    vehiclesToUpdate.add(rec);
                }
            }
        // Prior Insurance Information
            for (Prior_Insurance_Information__c rec : [SELECT Id, Lead__c FROM Prior_Insurance_Information__c WHERE Lead__c IN :leadAccountMap.keySet()]) {
                if(leadAccountMap.containsKey(rec.Lead__c)) {
                    rec.Account__c = leadAccountMap.get(rec.Lead__c);
                    priorInfoToUpdate.add(rec);
                }
            }

            // Cross Sell
            for (Cross_Sell__c rec : [SELECT Id, Lead__c FROM Cross_Sell__c WHERE Lead__c IN :leadAccountMap.keySet()]) {
                if(leadAccountMap.containsKey(rec.Lead__c)) {
                    rec.Account__c = leadAccountMap.get(rec.Lead__c);
                    crossSellsToUpdate.add(rec);
                }
            }

            Map<String, String> stringIdToAccountMap = new Map<String, String>();
            for(String ldId : leadAccountMap.keySet()) {
                if(ldId != null) {
                    stringIdToAccountMap.put(ldId, leadAccountMap.get(ldId));
                    if(ldId.length() >= 15) {
                        stringIdToAccountMap.put(ldId.substring(0, 15), leadAccountMap.get(ldId));
                    }
                }
            }

            // History Tracking
            for (History_Tracking__c rec : [SELECT Id, Parent_ID__c FROM History_Tracking__c WHERE Parent_ID__c IN :stringIdToAccountMap.keySet()]) {
                if(stringIdToAccountMap.containsKey(rec.Parent_ID__c)) {
                    rec.Parent_ID__c = stringIdToAccountMap.get(rec.Parent_ID__c);
                    historyTrackingToUpdate.add(rec);
                }
            }

            // Note History Logs
            for (Note_History_Logs__c rec : [SELECT Id, Parent_Record_Id__c FROM Note_History_Logs__c WHERE Parent_Record_Id__c IN :stringIdToAccountMap.keySet()]) {
                if(stringIdToAccountMap.containsKey(rec.Parent_Record_Id__c)) {
                    rec.Parent_Record_Id__c = stringIdToAccountMap.get(rec.Parent_Record_Id__c);
                    noteHistoryLogsToUpdate.add(rec);
                }
            }
        }

        // 5. Final DML Operations
        if (!leadsToConvert.isEmpty()) {
            LeadToAccountHelper.convertLeadsToAccounts(leadsToConvert, leadAccountMap);
        }
        
        if (!contactsToUpsert.isEmpty()) {
            try { 
                upsert contactsToUpsert; 
                System.debug('### Contacts Upserted Successfully'); 
            } catch (Exception e) { 
                System.debug('### Contact error: ' + e.getMessage()); 
                System.debug('### Trace: ' + e.getStackTraceString()); 
            }
        }
        
        if (!accountsToUpdate.isEmpty()) {
            try { 
                System.debug('### Attempting to update ' + accountsToUpdate.size() + ' Accounts'); 
                update accountsToUpdate; 
                System.debug('### Account Update Successful'); 
            } catch (Exception e) { 
                System.debug('### Account FI update error: ' + e.getMessage()); 
                System.debug('### Trace: ' + e.getStackTraceString()); 
            }
        }
        
        if (!casesToInsert.isEmpty()) {
            try { 
                insert casesToInsert; 
            } catch (Exception e) { 
                System.debug('### Case error: ' + e.getMessage()); 
            }
        }

        // Custom Object Updates
        if (!incidentsToUpdate.isEmpty()) {
            try { update incidentsToUpdate; } catch (Exception e) { System.debug('### Error moving Auto Incidents: ' + e.getMessage()); }
        }
        if (!propInfosToUpdate.isEmpty()) {
            try { update propInfosToUpdate; } catch (Exception e) { System.debug('### Error moving Property Info: ' + e.getMessage()); }
        }
        if (!propertiesToUpdate.isEmpty()) {
            try { update propertiesToUpdate; } catch (Exception e) { System.debug('### Error moving Properties: ' + e.getMessage()); }
        }
        if (!homeLossesToUpdate.isEmpty()) {
            try { update homeLossesToUpdate; } catch (Exception e) { System.debug('### Error moving Home Losses: ' + e.getMessage()); }
        }

        if (!driversToUpdate.isEmpty()) {
            try { update driversToUpdate; } catch (Exception e) { System.debug('### Error moving Drivers: ' + e.getMessage()); }
        }
        if (!vehiclesToUpdate.isEmpty()) {
            try { update vehiclesToUpdate; } catch (Exception e) { System.debug('### Error moving Vehicles: ' + e.getMessage()); }
        }
        if (!priorInfoToUpdate.isEmpty()) {
            try { update priorInfoToUpdate; } catch (Exception e) { System.debug('### Error moving Prior Info: ' + e.getMessage()); }
        }
        if (!crossSellsToUpdate.isEmpty()) {
            try { update crossSellsToUpdate; } catch (Exception e) { System.debug('### Error moving Cross Sells: ' + e.getMessage()); }
        }
        
        if (!historyTrackingToUpdate.isEmpty()) {
            try { update historyTrackingToUpdate; } catch (Exception e) { System.debug('### Error moving History Tracking: ' + e.getMessage()); }
        }
        if (!noteHistoryLogsToUpdate.isEmpty()) {
            try { update noteHistoryLogsToUpdate; } catch (Exception e) { System.debug('### Error moving Note History Logs: ' + e.getMessage()); }
        }
        
        // 1. UPSERT OPPORTUNITIES 
        if (!oppsToUpsert.isEmpty()) {
            try { 
                upsert oppsToUpsert; 
                // Now that Opportunities are saved, get the Ids of any that were created manually 
                for(Id leadId : leadToOppMapForFiles.keySet()){
                    Opportunity savedOpp = leadToOppMapForFiles.get(leadId);
                    if(savedOpp.Id != null) {
                        leadOppMap.put(leadId, savedOpp.Id);
                    }
                }
            } catch (Exception e) { 
                System.debug('### Opportunity error: ' + e.getMessage()); 
            }
        }
        
        if (!leadAccountMap.isEmpty()) {
            for (Policy_Information__c rec : [SELECT Id, Lead__c FROM Policy_Information__c WHERE Lead__c IN :leadAccountMap.keySet()]) {
                if(leadAccountMap.containsKey(rec.Lead__c)) {
                    rec.Account__c = leadAccountMap.get(rec.Lead__c); // Link to Account
                    
                    if(leadOppMap.containsKey(rec.Lead__c)) {
                        rec.Opportunity__c = leadOppMap.get(rec.Lead__c); // Link to Opportunity
                    }
                    policyInfosToUpdate.add(rec);
                }
            }
        }

        // 2. UPDATE POLICY INFORMATION
        if (!policyInfosToUpdate.isEmpty()) { 
            try { 
                update policyInfosToUpdate; 
            } catch (Exception e) { 
                System.debug('### Error moving Policy Info: ' + e.getMessage()); 
            } 
        }

        // 3. TRANSFER FILES TO OPPORTUNITY
        if (!leadToOppMapForFiles.isEmpty()) {
            List<ContentDocumentLink> newFileLinks = new List<ContentDocumentLink>();
            
            for (ContentDocumentLink cdl : [SELECT ContentDocumentId, LinkedEntityId, ShareType, Visibility 
                                            FROM ContentDocumentLink 
                                            WHERE LinkedEntityId IN :leadToOppMapForFiles.keySet()]) {
                                                
                Opportunity relatedOpp = leadToOppMapForFiles.get(cdl.LinkedEntityId);
                
                if (relatedOpp != null && relatedOpp.Id != null) {
                    ContentDocumentLink newCdl = new ContentDocumentLink();
                    newCdl.ContentDocumentId = cdl.ContentDocumentId;
                    newCdl.LinkedEntityId = relatedOpp.Id; 
                    newCdl.ShareType = cdl.ShareType;
                    newCdl.Visibility = cdl.Visibility;
                    newFileLinks.add(newCdl);
                }
            }
            
            if (!newFileLinks.isEmpty()) {
                try {
                    // 'false' allows it to gracefully succeed even if Salesforce auto-moved some files
                    Database.insert(newFileLinks, false);
                    System.debug('### Files Transferred to Opportunity Successfully');
                } catch (Exception e) {
                    System.debug('### Error transferring files: ' + e.getMessage());
               
    }
}
        }
    }
}