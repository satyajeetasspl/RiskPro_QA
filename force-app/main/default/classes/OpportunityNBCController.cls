public with sharing class OpportunityNBCController {
        
        public NBCWrapper wrapperObj { get; set; }
    
        public OpportunityNBCController() {
            Id oppId = ApexPages.currentPage().getParameters().get('id');
            if (oppId != null) {
                this.wrapperObj = getOpportunityNBC(oppId);
            }
        }
        
        public class NBCWrapper {
            @AuraEnabled public Opportunity opportunity { get; set; }
            @AuraEnabled public Account account { get; set; }
            @AuraEnabled public List<Policy_Information__c> policies { get; set; }
            @AuraEnabled public Boolean isSystemAdmin { get; set; }
        }
    
    private static String getCountryIsoCode(String countryName) {
        if (String.isBlank(countryName)) {
            return 'US';
        }
        if (countryName == 'United States' || countryName == 'USA' || countryName == 'US') {
            return 'US';
        }
        return countryName; // Fallback
    }

    private static String getStateIsoCode(String stateName) {
        Map<String, String> stateMap = new Map<String, String>{
            'Alabama' => 'AL', 'Alaska' => 'AK', 'Arizona' => 'AZ', 'Arkansas' => 'AR', 'California' => 'CA',
            'Colorado' => 'CO', 'Connecticut' => 'CT', 'Delaware' => 'DE', 'Florida' => 'FL', 'Georgia' => 'GA',
            'Hawaii' => 'HI', 'Idaho' => 'ID', 'Illinois' => 'IL', 'Indiana' => 'IN', 'Iowa' => 'IA',
            'Kansas' => 'KS', 'Kentucky' => 'KY', 'Louisiana' => 'LA', 'Maine' => 'ME', 'Maryland' => 'MD',
            'Massachusetts' => 'MA', 'Michigan' => 'MI', 'Minnesota' => 'MN', 'Mississippi' => 'MS', 'Missouri' => 'MO',
            'Montana' => 'MT', 'Nebraska' => 'NE', 'Nevada' => 'NV', 'New Hampshire' => 'NH', 'New Jersey' => 'NJ',
            'New Mexico' => 'NM', 'New York' => 'NY', 'North Carolina' => 'NC', 'North Dakota' => 'ND', 'Ohio' => 'OH',
            'Oklahoma' => 'OK', 'Oregon' => 'OR', 'Pennsylvania' => 'PA', 'Rhode Island' => 'RI', 'South Carolina' => 'SC',
            'South Dakota' => 'SD', 'Tennessee' => 'TN', 'Texas' => 'TX', 'Utah' => 'UT', 'Vermont' => 'VT',
            'Virginia' => 'VA', 'Washington' => 'WA', 'West Virginia' => 'WV', 'Wisconsin' => 'WI', 'Wyoming' => 'WY',
            'District of Columbia' => 'DC'
        };
        
        if (stateMap.containsKey(stateName)) {
            return stateMap.get(stateName);
        }
        return stateName; 
    }
        
                @AuraEnabled(cacheable=true)
        public static NBCWrapper getOpportunityNBC(Id opportunityId) {
            Opportunity opp = [
                SELECT Id, Name, Owner.Name, Owner.Email, AccountId,
                       Agent_2__c, Agent_2__r.Name, Agent_2__r.Email, 
                       Date_Bound__c, Rewrite__c, LeadSource,         
                       CSR_Work_Order__c, Notes_For_CSR__c, Comments__c,           
                       Agent_Notes__c, Is_NBC__c
                FROM Opportunity
                WHERE Id = :opportunityId
            ];
            
            Account acc = new Account();
    if (opp.AccountId != null) {
        acc = [
            SELECT Name, Phone, Email__c, 
                    ShippingStreet, ShippingCity, ShippingState, ShippingPostalCode, ShippingCountry,
                    BillingStreet, BillingCity, BillingState, BillingPostalCode, BillingCountry,
                    NBC_Address__Street__s, NBC_Address__City__s,
                    NBC_Address__StateCode__s, NBC_Address__PostalCode__s,
                    NBC_Address__CountryCode__s, Address_Property__Street__s, Address_Property__City__s, 
                    Address_Property__StateCode__s, Address_Property__PostalCode__s, 
                    Address_Property__CountryCode__s, Add_Second_Named_Insured__c, Comments__c, 
                    Second_Insured_First_Name__c, Second_Insured_Last_Name__c,
                    Second_Insured_Phone__c, Second_Insured_Email__c
            FROM Account
            WHERE Id = :opp.AccountId
            LIMIT 1
        ];
    }
            
            List<Policy_Information__c> policies = [
                SELECT Id, Carrier__c, Lines__c, Policy__c, Premium__c,
                       Agency_Fee__c, Agency_Fee_Waiver_Request__c, Agency_Fee_Waiver_Decision__c,
                       Paid_To_Date__c, Effective_Date__c, Generate_Invoice__c,
                       Additional_Comments__c, Email_Invoice__c,
                       Selected_Address__Street__s, Selected_Address__City__s,
                       Selected_Address__StateCode__s, Selected_Address__PostalCode__s,
                       Selected_Address__CountryCode__s
                FROM Policy_Information__c
                WHERE Opportunity__c = :opportunityId
                AND (
                (Policy_Type__c = 'Quote' AND Policy_Status__c = 'Approved')
                OR 
                (Policy_Type__c != 'Quote')
                )
                ORDER BY CreatedDate ASC
            ];
            
            NBCWrapper w = new NBCWrapper();
            Profile p = [SELECT Name FROM Profile WHERE Id = :UserInfo.getProfileId() LIMIT 1];
            w.isSystemAdmin = (p.Name == 'System Administrator');
            w.opportunity = opp;
            w.account = acc;
            w.policies = policies;
            
            return w;
        }
        
       @AuraEnabled
    public static void saveOpportunityNBC(
        Opportunity opp, 
        Account acc,   
        List<Policy_Information__c> policies,
        String selectedAddressType,
        Map<String, String> invoiceTypes
    ) {
        String street, city, state, postal, country;
        
        if (selectedAddressType == 'PROPERTY') {
            street = acc.Address_Property__Street__s;
            city = acc.Address_Property__City__s;
            state = getStateIsoCode(acc.Address_Property__StateCode__s);      
            postal = acc.Address_Property__PostalCode__s;
            country = getCountryIsoCode(acc.Address_Property__CountryCode__s); 
        } else if (selectedAddressType == 'INSURED') {
            street = acc.BillingStreet;
            city = acc.BillingCity;
            state = getStateIsoCode(acc.BillingState);    
            postal = acc.BillingPostalCode;
            country = getCountryIsoCode(acc.BillingCountry); 
        }
        
        Account accToUpdate = new Account(Id = acc.Id);
        accToUpdate.NBC_Address__Street__s = street;
        accToUpdate.NBC_Address__City__s = city;
        accToUpdate.NBC_Address__StateCode__s = state;
        accToUpdate.NBC_Address__PostalCode__s = postal;
        accToUpdate.NBC_Address__CountryCode__s = country;
        update accToUpdate;
        
        Opportunity currentOpp = [SELECT OwnerId FROM Opportunity WHERE Id = :opp.Id LIMIT 1];
        opp.Agent_1__c = currentOpp.OwnerId;
        
        opp.Is_NBC__c = true;
        opp.StageName = 'NBC';
        update opp;
        
        // --- NEW LOGIC: Query existing policies to protect Date_Bound__c ---
        Set<Id> existingPolicyIds = new Set<Id>();
        for (Policy_Information__c p : policies) {
            if (p.Id != null) existingPolicyIds.add(p.Id);
        }
        
        Map<Id, Policy_Information__c> dbPoliciesMap = new Map<Id, Policy_Information__c>();
        if (!existingPolicyIds.isEmpty()) {
            dbPoliciesMap = new Map<Id, Policy_Information__c>([
                SELECT Id, Policy_Type__c, Agent_1__c, Agent_2__c, Date_Bound__c 
                FROM Policy_Information__c 
                WHERE Id IN :existingPolicyIds
            ]);
        }
        // -------------------------------------------------------------------
        
        List<Policy_Information__c> inserts = new List<Policy_Information__c>();
        List<Policy_Information__c> updates = new List<Policy_Information__c>();
        
        for (Policy_Information__c p : policies) {
            p.Account__c = acc.Id;
            p.Opportunity__c = opp.Id;
            
            p.Address__Street__s = street;
            p.Address__City__s = city;
            p.Address__StateCode__s = state;
            p.Address__PostalCode__s = postal;
            p.Address__CountryCode__s = country;
            
            p.Selected_Address__Street__s = street;
            p.Selected_Address__City__s = city;
            p.Selected_Address__StateCode__s = state;
            p.Selected_Address__PostalCode__s = postal;
            p.Selected_Address__CountryCode__s = country;
            
            if (p.Id == null) {
                // Brand new policy created directly on NBC screen
                p.Agent_1__c = currentOpp.OwnerId;  
                p.Agent_2__c = opp.Agent_2__c;      
                p.Date_Bound__c = opp.Date_Bound__c; 
                p.Policy_Type__c = 'NBC';
                p.Final_Agency_Fee__c = (p.Agency_Fee__c != null) ? p.Agency_Fee__c : 0;
                inserts.add(p);
            } else {
                // Pre-existing Policy (From Policy Check LWC)
                Policy_Information__c dbPol = dbPoliciesMap.get(p.Id);
                
                // Only convert to NBC and stamp the dates IF it hasn't been done yet
                if (dbPol != null && dbPol.Policy_Type__c != 'NBC') {
                    p.Policy_Type__c = 'NBC';
                    p.Agent_1__c = (dbPol.Agent_1__c != null) ? dbPol.Agent_1__c : currentOpp.OwnerId;
                    p.Agent_2__c = (dbPol.Agent_2__c != null) ? dbPol.Agent_2__c : opp.Agent_2__c;
                    p.Date_Bound__c = (dbPol.Date_Bound__c != null) ? dbPol.Date_Bound__c : opp.Date_Bound__c;
                    p.Final_Agency_Fee__c = (p.Agency_Fee__c != null) ? p.Agency_Fee__c : 0;
                } else if (dbPol != null && dbPol.Policy_Type__c == 'NBC') {
                     p.Date_Bound__c = dbPol.Date_Bound__c;
                }
                
                updates.add(p);
            }
        }
        
        if (!inserts.isEmpty()) insert inserts;
        if (!updates.isEmpty()) update updates;
        
        // Trigger Invoices
        Map<String, List<Id>> policyGroups = new Map<String, List<Id>>();
        for (Integer i = 0; i < policies.size(); i++) {
            Policy_Information__c p = policies[i];
            if (p.Generate_Invoice__c == true) {
                String type = (invoiceTypes != null && invoiceTypes.containsKey(String.valueOf(i))) ? invoiceTypes.get(String.valueOf(i)) : 'Direct Bill';
                if (!policyGroups.containsKey(type)) policyGroups.put(type, new List<Id>());
                policyGroups.get(type).add(p.Id);
            }
        }

        for (String type : policyGroups.keySet()) {
            System.enqueueJob(new GeneratePolicyInvoiceJob(acc.Id, policyGroups.get(type), opp.Id, type));
        }
    }
        
        @AuraEnabled
    public static void generateNBCPdf(Id opportunityId) {
        // CHANGE 1: Query the Opportunity Name instead of Account.Name
        Opportunity opp = [SELECT Name FROM Opportunity WHERE Id = :opportunityId LIMIT 1];
        
        // CHANGE 2: Use Opportunity Name for the variable
        String fileNameSuffix = opp.Name;
        
        PageReference pdf = Page.NBC_PDF_OPPORTUNITY; 
        pdf.getParameters().put('id', opportunityId);
        
        Blob content;
        String fileName;
        
        try {
            if (Test.isRunningTest()) { 
                content = Blob.valueOf('Test'); 
            } else {
                content = pdf.getContentAsPDF(); 
            }
            // CHANGE 3: Use the Opportunity Name in the filename
            fileName = 'NBC_Checklist - ' + fileNameSuffix + '.pdf';
            
        } catch (Exception e) {
            System.debug('PDF Generation Failed: ' + e.getMessage());
            content = Blob.valueOf('Error: ' + e.getMessage());
            fileName = 'ERROR_LOG - ' + fileNameSuffix + '.txt';
        }
        
        ContentVersion cv = new ContentVersion(
            Title = fileName.removeEnd('.pdf').removeEnd('.txt'),
            PathOnClient = fileName,
            VersionData = content,
            FirstPublishLocationId = opportunityId,
            Type__c = 'New Business Checklist'
        );
        insert cv;
    }
        
        private static void generateInvoicesFromNBC(Id opportunityId) {
            Opportunity opp = [SELECT AccountId FROM Opportunity WHERE Id = :opportunityId];
            
            List<Policy_Information__c> policiesToInvoice = [
                SELECT Id, Carrier__c, Policy__c, Premium__c,
                Paid_To_Date__c, Additional_Comments__c, Email_Invoice__c, Lead__c
                FROM Policy_Information__c
                WHERE Opportunity__c = :opportunityId
                AND Generate_Invoice__c = TRUE
            ];
            
            if (policiesToInvoice.isEmpty()) return;
    
            Id fallbackLeadId = null;
            if (opp.AccountId != null) {
                List<Lead> leads = [SELECT Id FROM Lead WHERE ConvertedAccountId = :opp.AccountId ORDER BY CreatedDate DESC LIMIT 1];
                if (!leads.isEmpty()) {
                    fallbackLeadId = leads[0].Id;
                }
            }
    
            // Mark all as processed
            List<Policy_Information__c> updates = new List<Policy_Information__c>();
            for (Policy_Information__c p : policiesToInvoice) {
                updates.add(new Policy_Information__c(Id = p.Id, Generate_Invoice__c = false));
            }
            update updates;
    
            // Collect all IDs and enqueue ONE consolidated invoice job
            List<Id> allPolicyIds = new List<Id>();
            Id targetId = null;
            for (Policy_Information__c p : policiesToInvoice) {
                allPolicyIds.add(p.Id);
                if (targetId == null) {
                    targetId = p.Lead__c != null ? p.Lead__c : fallbackLeadId;
                }
            }
            if (targetId == null && opp.AccountId != null) targetId = opp.AccountId;
    
            if (targetId != null && !allPolicyIds.isEmpty()) {
                System.enqueueJob(new GeneratePolicyInvoiceJob(targetId, allPolicyIds, opportunityId));
            }
        }
    
        @AuraEnabled
        public static Boolean pdfExists(Id opportunityId) {
            List<ContentDocumentLink> existingLinks = [
                SELECT ContentDocument.Title
                FROM ContentDocumentLink
                WHERE LinkedEntityId = :opportunityId
                AND ContentDocument.Title LIKE 'NBC_Checklist%'
                LIMIT 1
            ];
            return !existingLinks.isEmpty();
        }
    
        @AuraEnabled(cacheable=true)
        public static List<Carrier__c> getCarrierOptions() {
            return [
                SELECT Id, Company_Name__c, 
                   Payment_Address__c,
                   Overnight_Payments__c
                FROM Carrier__c
                ORDER BY Company_Name__c
            ];
        }
        
        @AuraEnabled(cacheable=true)
        public static List<User> getAgent2Options() {
            return [
                SELECT Id, Name
                FROM User
                WHERE IsActive = true
                AND (Profile.Name = 'RISK  PRO Standard Profile' OR Profile.Name = 'System Administrator')
                ORDER BY Name
            ];
        }
    
    @AuraEnabled(cacheable=true)
public static List<Policy_Information__c> getAMS360Policies(Id accountId) {
    List<Policy_Information__c> mappedPolicies = new List<Policy_Information__c>();
    
    if (accountId == null) return mappedPolicies;

    List<vert__AMS360_Policy__c> amsPolicies = [
        SELECT Name, vert__AMS360_Parent_Company__c, vert__AMS360_Parent_Company__r.Name, 
               vert__AMS360_Full_Term_Premium__c, vert__AMS360_Effective_Date__c, 
               vert__AMS360_Type_of_Business__c, Paid_To_Date__c
        FROM vert__AMS360_Policy__c
        WHERE vert__AMS360_Account_Name__c = :accountId
        ORDER BY vert__AMS360_Effective_Date__c DESC
    ];

    for (vert__AMS360_Policy__c ams : amsPolicies) {
        String carrierName = ams.vert__AMS360_Parent_Company__r?.Name;
        mappedPolicies.add(new Policy_Information__c(
            Policy__c = ams.Name,
            Carrier__c = ams.vert__AMS360_Parent_Company__r.Name,
            Premium__c = ams.vert__AMS360_Full_Term_Premium__c != null ? String.valueOf(ams.vert__AMS360_Full_Term_Premium__c) : '0',
            Paid_To_Date__c = ams.Paid_To_Date__c != null ? String.valueOf(ams.Paid_To_Date__c) : '0',
            Effective_Date__c = ams.vert__AMS360_Effective_Date__c,
            Lines__c = ams.vert__AMS360_Type_of_Business__c
        ));
    }
    return mappedPolicies;
}
    
    // GATEKEEPER WRAPPER
    public class PolicyCheckValidation {
        @AuraEnabled public Boolean allowNBC { get; set; }
        @AuraEnabled public Integer maxPolicies { get; set; }
        @AuraEnabled public String errorMessage { get; set; }
    }

    // GATEKEEPER VALIDATION METHOD
    @AuraEnabled(cacheable=true)
    public static PolicyCheckValidation getPolicyCheckValidation(Id opportunityId) {
        PolicyCheckValidation result = new PolicyCheckValidation();
        result.allowNBC = true;
        result.maxPolicies = 0;
        result.errorMessage = '';

        // Query all related Policy Checks (Quotes) for this Opportunity
        List<Policy_Information__c> quotes = [
            SELECT Id, Policy_Status__c 
            FROM Policy_Information__c 
            WHERE Opportunity__c = :opportunityId 
            AND Policy_Type__c = 'Quote'
        ];

        Integer submittedCount = 0;
        Integer approvedCount = 0;

        for (Policy_Information__c quote : quotes) {
            if (quote.Policy_Status__c == 'Submitted') submittedCount++;
            else if (quote.Policy_Status__c == 'Approved') approvedCount++;
        }

        if (submittedCount > 0) {
            result.allowNBC = false;
            result.errorMessage = 'Cannot create NBC: A Policy Check approval is required to create an NBC.';
        } else if (approvedCount == 0) {
            result.allowNBC = false;
            result.errorMessage = 'Cannot create NBC:  A Policy Check approval is required to create an NBC.';
        } else {
            result.allowNBC = true;
            result.maxPolicies = approvedCount;
        }

        return result;
    }
    }