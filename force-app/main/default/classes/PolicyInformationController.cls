public with sharing class PolicyInformationController {
    
    public NBCWrapper wrapperObj { get; set; }
    
    public PolicyInformationController() {
        Id leadId = ApexPages.currentPage().getParameters().get('id');
        if (leadId != null) {
            wrapperObj = getLeadNBCDetail(leadId);
        }
    }
    
    public class NBCWrapper {
        @AuraEnabled public Lead leadDetail { get; set; }
        @AuraEnabled public List<Policy_Information__c> policyInformationList { get; set; }
        @AuraEnabled public Boolean isSystemAdmin { get; set; }
    }
    
    @AuraEnabled(cacheable=true)
    public static NBCWrapper getLeadNBCDetail(Id leadId) {
        NBCWrapper w = new NBCWrapper();
        
        Profile p = [SELECT Name FROM Profile WHERE Id = :UserInfo.getProfileId() LIMIT 1];
        w.isSystemAdmin = (p.Name == 'System Administrator');
        
        w.leadDetail = [
            SELECT Id, Owner.Name, Owner.Email,
            Insured_Address__Street__s, Insured_Address__City__s, Insured_Address__StateCode__s,
            Insured_Address__PostalCode__s, Insured_Address__CountryCode__s,
            Street, City, State, PostalCode, Country, NBC_Address__Street__s, NBC_Address__City__s, NBC_Address__StateCode__s,
            NBC_Address__PostalCode__s, NBC_Address__CountryCode__s,
            Name, Second_Insured_First_Name__c, Second_Insured_Last_Name__c,
            Borrowers_Phone_Number__c, Email,
            Second_Insured_Phone_1__c, Second_Insured_Email__c,
            Date_Bound__c, Rewrite__c, LeadSource,
            Notes_For_CSR__c, Agent_Notes__c, Agent_2__r.Name, Add_Second_Named_Insured__c,
            CSR_Work_Order__c, Comments__c
            FROM Lead
            WHERE Id = :leadId
            LIMIT 1
        ];
        
        w.policyInformationList = [
            SELECT Id, Carrier__c, Lines__c, Policy__c, Premium__c, Agency_Fee__c,
                   Agency_Fee_Waiver_Request__c, Agency_Fee_Waiver_Decision__c,
                   Effective_Date__c, Generate_Invoice__c, Email_Invoice__c, 
                   Paid_To_Date__c, Additional_Comments__c, Selected_Address__c, Date_Bound__c
            FROM Policy_Information__c
            WHERE Lead__c = :leadId
            AND (
            (Policy_Type__c = 'Quote' AND Policy_Status__c = 'Approved')
            OR 
            (Policy_Type__c != 'Quote')
            )
            ORDER BY CreatedDate ASC
        ];
        
        return w;
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
    
    @AuraEnabled
    public static void saveLeadNBC(Lead lead, List<Policy_Information__c> policies, String selectedAddress, Map<String, String> invoiceTypes) {
        try {
            String street, city, state, postalCode, country;

            Lead fullLead = [
                SELECT Street, City, State, PostalCode, Country,LeadSource,Partner_Name__c,
                       Insured_Address__Street__s, Insured_Address__City__s, 
                       Insured_Address__StateCode__s, Insured_Address__PostalCode__s, 
                       Insured_Address__CountryCode__s,ownerId
                FROM Lead
                WHERE Id = :lead.Id
                LIMIT 1
            ];

            if (selectedAddress == 'PROPERTY') {
                street = fullLead.Street;
                city = fullLead.City;
                state = getStateIsoCode(fullLead.State);
                postalCode = fullLead.PostalCode;
                country = getCountryIsoCode(fullLead.Country);
            } else if (selectedAddress == 'INSURED') {
                street = fullLead.Insured_Address__Street__s;
                city = fullLead.Insured_Address__City__s;
                state = fullLead.Insured_Address__StateCode__s;
                postalCode = fullLead.Insured_Address__PostalCode__s;
                country = fullLead.Insured_Address__CountryCode__s;
            }

            lead.NBC_Address__Street__s = street;
            lead.NBC_Address__City__s = city;
            lead.NBC_Address__StateCode__s = state; 
            lead.NBC_Address__PostalCode__s = postalCode;
            lead.NBC_Address__CountryCode__s = country; 
            
            lead.Agent_1__c = fullLead.OwnerId;
            lead.Is_NBC__c = true;
            AMSHelperClass.AMSWrapper AMSDetailWrapper =
            AMSHelperClass.getAMSBusinesUnit(
                fullLead.LeadSource,
                fullLead.Partner_Name__c,
                fullLead.ownerId
            );
            
            if (AMSDetailWrapper != null) {
                lead.vert__AMS360_Branch__c=AMSDetailWrapper.BranchId;
                lead.vert__AMS360_Division__c=AMSDetailWrapper.DivId;
                lead.vert__AMS360_Department__c=AMSDetailWrapper.DeptId;
                lead.vert__AMS360_Group__c=AMSDetailWrapper.groupId;
                lead.vert__AMS360_Employee_Account_Exec__c=AMSDetailWrapper.excutiveId;
            }
            
            update lead;
            
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
            
            List<Policy_Information__c> toInsert = new List<Policy_Information__c>();
            List<Policy_Information__c> toUpdate = new List<Policy_Information__c>();
            
            for (Policy_Information__c p : policies) {
                p.Address__Street__s = street;
                p.Address__City__s = city;
                p.Address__StateCode__s = state; 
                p.Address__PostalCode__s = postalCode;
                p.Address__CountryCode__s = country;
                p.Lead__c = lead.Id;
                
                if (p.Id == null) { 
                    p.Agent_1__c = fullLead.OwnerId; 
                    p.Agent_2__c = lead.Agent_2__c;  
                    p.Date_Bound__c = lead.Date_Bound__c; 
                    p.Policy_Type__c = 'NBC';
                    p.Final_Agency_Fee__c = (p.Agency_Fee__c != null) ? p.Agency_Fee__c : 0;
                    toInsert.add(p);
                } else {
                    Policy_Information__c dbPol = dbPoliciesMap.get(p.Id);
                    
                    if (dbPol != null && dbPol.Policy_Type__c != 'NBC') {
                        p.Policy_Type__c = 'NBC';
                        p.Agent_1__c = (dbPol.Agent_1__c != null) ? dbPol.Agent_1__c : fullLead.OwnerId;
                        p.Agent_2__c = (dbPol.Agent_2__c != null) ? dbPol.Agent_2__c : lead.Agent_2__c;
                        p.Date_Bound__c = (dbPol.Date_Bound__c != null) ? dbPol.Date_Bound__c : lead.Date_Bound__c;
                        p.Final_Agency_Fee__c = (p.Agency_Fee__c != null) ? p.Agency_Fee__c : 0;
                    } else if (dbPol != null && dbPol.Policy_Type__c == 'NBC') {
                        p.Date_Bound__c = dbPol.Date_Bound__c;
                    }
                    
                    toUpdate.add(p);
                }
            }
            
            if (!toInsert.isEmpty()) insert toInsert;
            if (!toUpdate.isEmpty()) update toUpdate;

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
                System.enqueueJob(new GeneratePolicyInvoiceJob(lead.Id, policyGroups.get(type), lead.Id, type));
            }
            
        } catch (Exception e) {
            throw new AuraHandledException('Error saving Lead/Policies: ' + e.getMessage());
        }
    }
    
    
    @AuraEnabled
    public static String getPdfUrl(Id leadId) {
        PageReference pdfPage = Page.NBC_PDF;
        pdfPage.getParameters().put('id', leadId);
        return pdfPage.getUrl();
    }
    
    @AuraEnabled
    public static String savePdfLink(Id leadId) {
        try {
            Lead leadRec = [
                SELECT Id, OwnerId, Name
                FROM Lead
                WHERE Id = :leadId
                LIMIT 1
            ];
        
            PageReference pdfPage = Page.NBC_PDF;
            pdfPage.getParameters().put('id', leadId);
        
            Blob pdfBlob;
            if (Test.isRunningTest()) {
                pdfBlob = Blob.valueOf('Test PDF content');
            } else {
                pdfBlob = pdfPage.getContentAsPDF();
            }
        
            ContentVersion cv = new ContentVersion();
            cv.Title = 'NBC Checklist - ' + leadRec.Name;
            cv.PathOnClient = 'NBC_Checklist.pdf';
            cv.VersionData = pdfBlob;
            cv.FirstPublishLocationId = leadId;
            cv.Type__c = 'New Business Checklist';
            insert cv;
            
            // Removed generatePolicyInvoicesFuture(leadId); to avoid duplicates as saveLeadNBC now handles it.
            
            return 'NBC PDF saved. Policy invoices will be generated shortly.';
            
        } catch (Exception e) {
            throw new AuraHandledException('Error: ' + e.getMessage() + ' | Line: ' + e.getLineNumber());
        }
    }

    public static void generatePolicyInvoicesFuture(Id leadId) {
        try {
            List<Policy_Information__c> policies = [
                SELECT Id, Carrier__c, Policy__c, Premium__c, Effective_Date__c, Generate_Invoice__c, Additional_Comments__c
                FROM Policy_Information__c
                WHERE Lead__c = :leadId AND Generate_Invoice__c = TRUE
                ORDER BY CreatedDate ASC
            ];

            if (policies.isEmpty()) return;

            // Collect all IDs and enqueue ONE consolidated invoice job
            List<Id> allPolicyIds = new List<Id>();
            for (Policy_Information__c p : policies) {
                allPolicyIds.add(p.Id);
            }
            System.enqueueJob(new GeneratePolicyInvoiceJob(leadId, allPolicyIds, leadId));

        } catch (Exception e) {
            System.debug('Error enqueueing jobs: ' + e.getMessage());
            throw new AuraHandledException('Error: ' + e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static Boolean hasExistingNBC(Id leadId) {
        Integer countNBC = [
            SELECT COUNT()
            FROM Policy_Information__c
            WHERE Lead__c = :leadId
        ];
        return countNBC > 0;
    }

    @AuraEnabled(cacheable=true)
    public static Boolean pdfExists(Id leadId) {
        List<ContentDocumentLink> existingLinks = [
            SELECT ContentDocument.Title
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :leadId
            AND ContentDocument.Title LIKE 'NBC Checklist%'
            LIMIT 1
        ];
        return !existingLinks.isEmpty();
    }
    
    @AuraEnabled(cacheable=true)
    public static List<Policy_Information__c> getPoliciesForLookup(Id leadId) {
        return [
            SELECT Id, Carrier__c, Lines__c, Policy__c, Premium__c, Effective_Date__c, 
                   Paid_To_Date__c, Additional_Comments__c, Email_Invoice__c, Lead__c
            FROM Policy_Information__c
            WHERE Lead__c = :leadId
            ORDER BY CreatedDate DESC
        ];
    }
    
    @AuraEnabled(cacheable=true)
    public static List<Policy_Information__c> getPoliciesForAccount(Id accountId) {
        return [
            SELECT Id, Carrier__c, Lines__c, Policy__c, Premium__c, Effective_Date__c, 
                   Paid_To_Date__c, Additional_Comments__c, Email_Invoice__c,
                   Lead__c 
            FROM Policy_Information__c
            WHERE Account__c = :accountId
            ORDER BY CreatedDate DESC
        ];
    }

    @AuraEnabled
    public static void saveSinglePolicyAndInvoice(Id recordId, String sObjectType, Policy_Information__c policy, Boolean isManualEntry, String invoiceType) {
        
        Id policyIdToInvoice;
        Id leadIdForJob; 
        
        if (isManualEntry) {
            policy.Generate_Invoice__c = true;
            
            policy.Carrier_Payment_Address__StateCode__s = getStateIsoCode(policy.Carrier_Payment_Address__StateCode__s);
            policy.Carrier_Payment_Address__CountryCode__s = getCountryIsoCode(policy.Carrier_Payment_Address__CountryCode__s);
            
            policy.Selected_Address__StateCode__s = getStateIsoCode(policy.Selected_Address__StateCode__s);
            policy.Selected_Address__CountryCode__s = getCountryIsoCode(policy.Selected_Address__CountryCode__s);
            
            if (sObjectType == 'Lead') {
                policy.Lead__c = recordId;
                leadIdForJob = recordId;

            } else if (sObjectType == 'Account') {
                policy.Account__c = recordId;
                
                List<Policy_Information__c> existingPols = [
                    SELECT Lead__c 
                    FROM Policy_Information__c 
                    WHERE Account__c = :recordId AND Lead__c != null 
                    LIMIT 1
                ];
                
                if (!existingPols.isEmpty()) {
                    leadIdForJob = existingPols[0].Lead__c;
                }
                
                if (leadIdForJob == null) {
                    List<Lead> originalLeads = [
                        SELECT Id 
                        FROM Lead 
                        WHERE ConvertedAccountId = :recordId 
                        ORDER BY CreatedDate DESC 
                        LIMIT 1
                    ];

                    if (!originalLeads.isEmpty()) {
                        leadIdForJob = originalLeads[0].Id;
                    }
                }

                if (leadIdForJob == null) {
                   policy.Lead__c = null;
                   leadIdForJob = recordId;
                } else {
                   policy.Lead__c = leadIdForJob;
                }
            }
            
            insert policy;
            policyIdToInvoice = policy.Id;

        } else {
            Policy_Information__c existingPolicy = new Policy_Information__c(
                Id = policy.Id,
                Additional_Comments__c = policy.Additional_Comments__c,
                Email_Invoice__c = policy.Email_Invoice__c,
                Generate_Invoice__c = true,
                
                Carrier_Payment_Address__Street__s = policy.Carrier_Payment_Address__Street__s,
                Carrier_Payment_Address__City__s = policy.Carrier_Payment_Address__City__s,
                Carrier_Payment_Address__StateCode__s = getStateIsoCode(policy.Carrier_Payment_Address__StateCode__s),
                Carrier_Payment_Address__PostalCode__s = policy.Carrier_Payment_Address__PostalCode__s,
                Carrier_Payment_Address__CountryCode__s = getCountryIsoCode(policy.Carrier_Payment_Address__CountryCode__s),
                
                Selected_Address__Street__s = policy.Selected_Address__Street__s,
                Selected_Address__City__s = policy.Selected_Address__City__s,
                Selected_Address__StateCode__s = getStateIsoCode(policy.Selected_Address__StateCode__s),
                Selected_Address__PostalCode__s = policy.Selected_Address__PostalCode__s,
                Selected_Address__CountryCode__s = getCountryIsoCode(policy.Selected_Address__CountryCode__s)
            );
            update existingPolicy;
            policyIdToInvoice = existingPolicy.Id;
            
            if(policy.Lead__c != null){
                    leadIdForJob = policy.Lead__c;
            } else {
                    try {
                        Policy_Information__c p = [SELECT Lead__c FROM Policy_Information__c WHERE Id = :policyIdToInvoice];
                        leadIdForJob = p.Lead__c;
                    } catch (Exception e) {
                        throw new AuraHandledException('Error finding Lead ID for existing policy: ' + e.getMessage());
                    }
            }
        }
        
        if (leadIdForJob == null) {
            leadIdForJob = recordId;
        }
        
        try {
            System.enqueueJob(new GeneratePolicyInvoiceJob(leadIdForJob, policyIdToInvoice, recordId, invoiceType));
        } catch (Exception e) {
            throw new AuraHandledException('Failed to enqueue invoice job: ' + e.getMessage());
        }
    } 
    
    @AuraEnabled(cacheable=true)
    public static List<Properties__c> getRelatedProperties(Id recordId, String sObjectType) {
        if (recordId == null || sObjectType == null) return new List<Properties__c>();
        List<Properties__c> relatedProps = new List<Properties__c>();

        if (sObjectType == 'Lead') {
            relatedProps = [SELECT Id, Name, Address__Street__s, Address__City__s, Address__StateCode__s, 
                        Address__PostalCode__s, Address__CountryCode__s FROM Properties__c WHERE Lead__c = :recordId];
        } else if (sObjectType == 'Account') {
            relatedProps = [SELECT Id, Name, Address__Street__s, Address__City__s, Address__StateCode__s, 
                        Address__PostalCode__s, Address__CountryCode__s FROM Properties__c WHERE Account__c = :recordId];
        }

        return relatedProps;
    }
    
    @AuraEnabled(cacheable=true)
    public static Map<String, Map<String, String>> getLeadAddresses(Id leadId) {
        Map<String, Map<String, String>> result = new Map<String, Map<String, String>>();

        Lead l = [
            SELECT
                Street, City, State, PostalCode, Country,
                Insured_Address__Street__s,
                Insured_Address__City__s,
                Insured_Address__StateCode__s,
                Insured_Address__PostalCode__s,
                Insured_Address__CountryCode__s
            FROM Lead
            WHERE Id = :leadId
            LIMIT 1
        ];

        result.put('property', new Map<String, String>{
            'street' => l.Street,
            'city' => l.City,
            'state' => l.State,
            'postal' => l.PostalCode,
            'country' => l.Country
        });

        result.put('insured', new Map<String, String>{
            'street' => l.Insured_Address__Street__s,
            'city' => l.Insured_Address__City__s,
            'state' => l.Insured_Address__StateCode__s,
            'postal' => l.Insured_Address__PostalCode__s,
            'country' => l.Insured_Address__CountryCode__s
        });

        return result;
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, Map<String, String>> getAccountAddresses(Id accountId) {
        Map<String, Map<String, String>> result = new Map<String, Map<String, String>>();
        Account accountAddress=[SELECT Address_Property__Street__s,
                                Address_Property__City__s,
                                Address_Property__StateCode__s,
                                Address_Property__PostalCode__s,
                                Address_Property__CountryCode__s 
                                FROM Account WHERE ID=:accountId];
        List<Contact> contacts = [
            SELECT Insured_Role__c, MailingStreet, MailingCity, MailingState, MailingPostalCode, MailingCountry,
                   OtherStreet, OtherCity, OtherState, OtherPostalCode, OtherCountry
            FROM Contact
            WHERE AccountId = :accountId
            AND Insured_Role__c IN ('First Insured') LIMIT 1
        ];

        for (Contact c : contacts) {
            if (c.Insured_Role__c == 'First Insured') {
                result.put('firstInsured_insured', new Map<String, String>{
                    'street' => c.MailingStreet,
                    'city' => c.MailingCity,
                    'state' => c.MailingState,
                    'postal' => c.MailingPostalCode,
                    'country' => c.MailingCountry
                });
            } 
        }

        if (!result.containsKey('firstInsured_insured')) {
            result.put('firstInsured_insured', new Map<String, String>());
        }
        if (accountAddress!=null && accountAddress.Address_Property__Street__s!=null) {
            result.put('secondInsured_property', new Map<String, String>{
                    'street' => accountAddress.Address_Property__Street__s,
                    'city' => accountAddress.Address_Property__City__s,
                    'state' => accountAddress.Address_Property__StateCode__s,
                    'postal' => accountAddress.Address_Property__PostalCode__s,
                    'country' => accountAddress.Address_Property__CountryCode__s
                });
        }

        return result;
    }
    
    private static String getCountryIsoCode(String countryName) {
        if (String.isBlank(countryName)) {
            return 'US';
        }
        if (countryName == 'United States' || countryName == 'USA' || countryName == 'US') {
            return 'US';
        }
        return countryName;
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
    public static List<Policy_Information__c> getAMS360Policies(Id accountId) {
        List<Policy_Information__c> mappedPolicies = new List<Policy_Information__c>();
        
        if (accountId == null) return mappedPolicies;

        // Use the same corrected lookup field logic
        List<vert__AMS360_Policy__c> amsPolicies = [
            SELECT Name, vert__AMS360_Parent_Company__r.Name, 
                   vert__AMS360_Full_Term_Premium__c, vert__AMS360_Effective_Date__c, 
                   vert__AMS360_Type_of_Business__c
            FROM vert__AMS360_Policy__c
            WHERE vert__AMS360_Account_Name__c = :accountId
            ORDER BY vert__AMS360_Effective_Date__c DESC
        ];

        for (vert__AMS360_Policy__c ams : amsPolicies) {
            mappedPolicies.add(new Policy_Information__c(
                Policy__c = ams.Name,
                Carrier__c = ams.vert__AMS360_Parent_Company__r?.Name,
                Premium__c = ams.vert__AMS360_Full_Term_Premium__c != null ? String.valueOf(ams.vert__AMS360_Full_Term_Premium__c) : '0',
                Effective_Date__c = ams.vert__AMS360_Effective_Date__c,
                Lines__c = ams.vert__AMS360_Type_of_Business__c
            ));
        }
        return mappedPolicies;
    }
    
    public class PolicyCheckValidation {
        @AuraEnabled public Boolean allowNBC { get; set; }
        @AuraEnabled public Integer maxPolicies { get; set; }
        @AuraEnabled public String errorMessage { get; set; }
    }

    @AuraEnabled(cacheable=true)
    public static PolicyCheckValidation getPolicyCheckValidation(Id leadId) {
        PolicyCheckValidation result = new PolicyCheckValidation();
        result.allowNBC = true;
        result.maxPolicies = 0;
        result.errorMessage = '';

        // Query all related Policy Checks (Quotes) for this Lead
        List<Policy_Information__c> quotes = [
            SELECT Id, Policy_Status__c 
            FROM Policy_Information__c 
            WHERE Lead__c = :leadId 
            AND Policy_Type__c = 'Quote'
        ];

        Integer submittedCount = 0;
        Integer approvedCount = 0;

        // Tally up the statuses
        for (Policy_Information__c quote : quotes) {
            if (quote.Policy_Status__c == 'Submitted') {
                submittedCount++;
            } else if (quote.Policy_Status__c == 'Approved') {
                approvedCount++;
            }
        }

        // Apply Gatekeeper Rules
        if (submittedCount > 0) {
            result.allowNBC = false;
            result.errorMessage = 'Cannot create NBC: A Policy Check approval is required to create an NBC.';
        } else if (approvedCount == 0) {
            result.allowNBC = false;
            result.errorMessage = 'Cannot create NBC:  A Policy Check approval is required to create an NBC.';
        } else {
            // Passed validation! Set the limit.
            result.allowNBC = true;
            result.maxPolicies = approvedCount;
        }

        return result;
    }
}