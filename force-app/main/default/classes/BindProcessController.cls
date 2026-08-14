public without sharing class BindProcessController {
    
    // --- Visualforce Properties for Proposal Summary PDF ---
    public List<SummaryPolicyWrapper> summaryPolicies { get; set; }
    public String totalPremium { get; set; }
    public String totalAgencyFee { get; set; }
    public String grandTotal { get; set; }

    public class SummaryPolicyWrapper {
        public Policy_Information__c policy { get; set; }
        public String iconUrl { get; set; }
        public String displayLines { get; set; }
        public String formattedEffectiveDate { get; set; }
        public String formattedExpirationDate { get; set; }
        public String premiumFormatted { get; set; }
        public String agencyFeeFormatted { get; set; }
        public String totalFormatted { get; set; }
    }

    private String formatCurrency(Decimal val) {
        if (val == null) val = 0.00;
        val = val.setScale(2);
        String s = val.format();
        if (!s.contains('.')) {
            s += '.00';
        } else if (s.substringAfter('.').length() == 1) {
            s += '0';
        }
        return '$' + s;
    }

    public BindProcessController(ApexPages.StandardController stdController) {
        Id recordId = stdController.getId();
        if (recordId == null) return;
        
        BindProcessWrapper data = getBindProcessData(recordId);
        summaryPolicies = new List<SummaryPolicyWrapper>();
        
        Decimal dTotalPremium = 0.00;
        Decimal dTotalAgencyFee = 0.00;
        Decimal dGrandTotal = 0.00;

        for (Policy_Information__c p : data.policies) {
            // Exclude inactive, rejected, abandoned, replaced, or not-bound policies from proposal summary
            Boolean isInactiveOrReplaced = (p.Policy_Status__c == 'Rejected' || p.Policy_Status__c == 'Abandoned' || p.Policy_Bound__c == 'No' || p.Replacement_Initiated__c == true);
            if (isInactiveOrReplaced) continue;

            SummaryPolicyWrapper wrapper = new SummaryPolicyWrapper();
            wrapper.policy = p;
            
            // Format dates
            if (p.Effective_Date__c != null) {
                wrapper.formattedEffectiveDate = ((DateTime)p.Effective_Date__c).format('MM-dd-yyyy', 'UTC');
            } else {
                wrapper.formattedEffectiveDate = '';
            }
            if (p.Expiration_Date__c != null) {
                wrapper.formattedExpirationDate = ((DateTime)p.Expiration_Date__c).format('MM-dd-yyyy', 'UTC');
            } else {
                wrapper.formattedExpirationDate = '';
            }

            // Format amounts
            Decimal prem = 0.00;
            if (p.Premium__c != null) {
                try { prem = Decimal.valueOf(String.valueOf(p.Premium__c)); } catch(Exception e) {}
            }
            Decimal fee = 0.00;
            if (p.Agency_Fee__c != null) {
                try { fee = Decimal.valueOf(String.valueOf(p.Agency_Fee__c)); } catch(Exception e) {}
            }
            Decimal tot = prem + fee;

            dTotalPremium += prem;
            dTotalAgencyFee += fee;
            dGrandTotal += tot;

            wrapper.premiumFormatted = formatCurrency(prem);
            wrapper.agencyFeeFormatted = formatCurrency(fee);
            wrapper.totalFormatted = formatCurrency(tot);

            // Display Lines
            wrapper.displayLines = p.Lines__c;

            // Icon Mapping
            String line = p.Lines__c != null ? p.Lines__c.toUpperCase() : '';
            Set<String> validIcons = new Set<String>{
                'AUTO', 'BOAT', 'BUILDERS RISK', 'BUSINESS OWNERS', 'CARGO', 'COMMERCIAL AUTO', 
                'COMMERCIAL PROPERTY', 'COMMERCIAL UMBRELLA', 'CONDO', 'D&O', 'E&O', 'EXCESS LIABILITY', 
                'FLOOD', 'GARAGE LIABILITY', 'GARAGEKEEPERS', 'HEALTH', 'HOME', 'I', 'LANDLORD', 'LIFE', 
                'MOBILE HOME', 'MOTORCYCLE', 'PROFESSIONAL LIABILITY', 'RENTERS', 'RV', 'SECONDARY HOME', 'UMBRELLA'
            };

            if (validIcons.contains(line)) {
                wrapper.iconUrl = 'LOBICONS/' + line + '_icon.png';
            } else if (line.contains('AUTO')) {
                wrapper.iconUrl = 'LOBICONS/AUTO_icon.png';
            } else if (line.contains('HOME')) {
                wrapper.iconUrl = 'LOBICONS/HOME_icon.png';
            } else if (line.contains('UMBRELLA')) {
                wrapper.iconUrl = 'LOBICONS/UMBRELLA_icon.png';
            } else if (line.contains('BOAT')) {
                wrapper.iconUrl = 'LOBICONS/BOAT_icon.png';
            } else if (line.contains('MOTORCYCLE')) {
                wrapper.iconUrl = 'LOBICONS/MOTORCYCLE_icon.png';
            } else if (line.contains('COMMERCIAL')) {
                wrapper.iconUrl = 'LOBICONS/COMMERCIAL PROPERTY_icon.png';
            } else if (line.contains('RENTER')) {
                wrapper.iconUrl = 'LOBICONS/RENTERS_icon.png';
            } else if (line.contains('FLOOD')) {
                wrapper.iconUrl = 'LOBICONS/FLOOD_icon.png';
            } else if (line.contains('CONDO')) {
                wrapper.iconUrl = 'LOBICONS/CONDO_icon.png';
            } else if (line.contains('LANDLORD')) {
                wrapper.iconUrl = 'LOBICONS/LANDLORD_icon.png';
            } else {
                wrapper.iconUrl = 'LOBICONS/HOME_icon.png'; 
            }

            summaryPolicies.add(wrapper);
        }

        totalPremium = formatCurrency(dTotalPremium);
        totalAgencyFee = formatCurrency(dTotalAgencyFee);
        grandTotal = formatCurrency(dGrandTotal);
    }

    // --- Data Wrappers ---
    public class BindProcessWrapper {
        @AuraEnabled public SObject recordDetail { get; set; }
        @AuraEnabled public List<Policy_Information__c> policies { get; set; }
        @AuraEnabled public List<PolicyUiDto> policyUiList { get; set; }
        @AuraEnabled public Boolean isSystemAdmin { get; set; }
        @AuraEnabled public Map<Id, List<FeedItem>> policyChatterMap { get; set; }
        @AuraEnabled public Map<Id, List<ContentDocumentLink>> policyFilesMap { get; set; }
        @AuraEnabled public List<String> leadLinesList { get; set; }
        @AuraEnabled public Boolean allowNBC { get; set; }
        @AuraEnabled public String validationError { get; set; }
        @AuraEnabled public Integer maxPolicies { get; set; }
        @AuraEnabled public String smeTransactionStatus { get; set; }
        @AuraEnabled public String smeTransactionId { get; set; }
        @AuraEnabled public Decimal globalAvailableCredit { get; set; }
        @AuraEnabled public Decimal globalOutstandingAmount { get; set; }
        @AuraEnabled public Decimal globalNetRefundOwed { get; set; }
        @AuraEnabled public ModalSummaryDto modalSummary { get; set; }
    }

    public class ModalSummaryDto {
        @AuraEnabled public String totalFees { get; set; }
        @AuraEnabled public String collected { get; set; }
        @AuraEnabled public String outstanding { get; set; }
        @AuraEnabled public String refundsDue { get; set; }
        @AuraEnabled public String availableCredit { get; set; }
        @AuraEnabled public String availableCreditSubtext { get; set; }
        @AuraEnabled public Integer activePolicyCount { get; set; }
        @AuraEnabled public Integer linksReq { get; set; }
        @AuraEnabled public Integer linksSent { get; set; }
        @AuraEnabled public Integer linksNotSent { get; set; }
        @AuraEnabled public Integer paymentsPaid { get; set; }
        @AuraEnabled public Integer paymentsPending { get; set; }
        @AuraEnabled public String collectedSubtext { get; set; }
        @AuraEnabled public String outstandingSubtext { get; set; }
        @AuraEnabled public Boolean hasRefundDueGlobal { get; set; }
        @AuraEnabled public Boolean hasCreditGlobal { get; set; }
        @AuraEnabled public Boolean hasCreditApplied { get; set; }
        @AuraEnabled public Boolean showCreditAppliedTile { get; set; }
        @AuraEnabled public String creditApplied { get; set; }
        @AuraEnabled public String creditAppliedSubtext { get; set; }
        @AuraEnabled public Boolean showRefundIssuedTile { get; set; }
        @AuraEnabled public String refundsIssued { get; set; }
        @AuraEnabled public String refundsIssuedSubtext { get; set; }
    }

    public class PolicyUiDto {
        @AuraEnabled public Policy_Information__c policy { get; set; }
        @AuraEnabled public String tileStatus { get; set; }
        @AuraEnabled public String tileActionText { get; set; }
        @AuraEnabled public String feeAmountFormatted { get; set; }
        @AuraEnabled public String tileStatusColor { get; set; }
        @AuraEnabled public Boolean hasTileAction { get; set; }
        @AuraEnabled public Boolean isPathwayCollectFee { get; set; }
        @AuraEnabled public Boolean isPathwayApplyCredit { get; set; }
        @AuraEnabled public Boolean isPathwayIssueRefund { get; set; }
        @AuraEnabled public Boolean isPathwayNoFee { get; set; }
        @AuraEnabled public String modalStatusText { get; set; }
        @AuraEnabled public String modalActionText { get; set; }
        @AuraEnabled public String modalStatusPillClass { get; set; }
        @AuraEnabled public String modalActionBtnClass { get; set; }
        @AuraEnabled public Boolean isActionDisabled { get; set; }
        @AuraEnabled public Boolean hasPaymentLink { get; set; }
        @AuraEnabled public Boolean isReplacementPathwayActive { get; set; }
        @AuraEnabled public Boolean isNewQuotePathwayActive { get; set; }
        @AuraEnabled public Boolean isReplacement5Step { get; set; }
        @AuraEnabled public Integer numSteps { get; set; }
        @AuraEnabled public Decimal availableCreditAmt { get; set; }
        @AuraEnabled public Decimal estimatedRefundAmt { get; set; }
        @AuraEnabled public Decimal balanceDueAmt { get; set; }
        @AuraEnabled public String availableCreditText { get; set; }
        @AuraEnabled public String estimatedRefundText { get; set; }
        @AuraEnabled public String balanceDueText { get; set; }
        @AuraEnabled public String statusDateText { get; set; }
        @AuraEnabled public String creditSubtext { get; set; }
        @AuraEnabled public String creditSubtextStyle { get; set; }
        @AuraEnabled public String balanceSubtext { get; set; }
        @AuraEnabled public String balanceSubtextStyle { get; set; }
    }

    public class BindSaveRequest {
        @AuraEnabled public Id recordId { get; set; }
        @AuraEnabled public SObject parentRecord { get; set; }
        @AuraEnabled public List<PolicyRequest> policyRequests { get; set; }
        @AuraEnabled public List<Id> deletedPolicyIds { get; set; }
        @AuraEnabled public Boolean isFinalSubmission { get; set; }
        @AuraEnabled public String processType { get; set; } // 'Policy Check' or 'NBC'
        @AuraEnabled public String selectedAddressType { get; set; }
        @AuraEnabled public Map<String, String> invoiceTypes { get; set; }
    }

    public class PolicyRequest {
        @AuraEnabled public Policy_Information__c policyRecord { get; set; }
        @AuraEnabled public String chatterText { get; set; }
        @AuraEnabled public String mentionUserId { get; set; }
        @AuraEnabled public String fileIdToAttach { get; set; }
    }

    // --- Data Retrieval ---
    @AuraEnabled(cacheable=true)
    public static BindProcessWrapper getBindProcessData(Id recordId) {
        BindProcessWrapper w = new BindProcessWrapper();
        Profile p = [SELECT Name FROM Profile WHERE Id = :UserInfo.getProfileId() LIMIT 1];
        w.isSystemAdmin = (p.Name == 'System Administrator');
        
        SObjectType sType = recordId.getSObjectType();
        
        // 1. Parent Details
        if (sType == Lead.SObjectType) {
            List<Lead> leads = [SELECT Id, Name, OwnerId, Owner.Name, Owner.Email, Status, Street, City, State, PostalCode, Country, 
                Policy_Check_Status__c, Agent_2__c, Agent_2__r.Name, Agent_2__r.Email, Policy_Check_Comments__c, 
                Personal_Lines__c, Commercial_Lines__c, Insured_Address__Street__s, Insured_Address__City__s, 
                Insured_Address__StateCode__s, Insured_Address__PostalCode__s, Insured_Address__CountryCode__s,
                Date_Bound__c, Rewrite__c, LeadSource, Notes_For_CSR__c, Agent_Notes__c, Add_Second_Named_Insured__c, 
                CSR_Work_Order__c, Comments__c, Second_Insured_First_Name__c, Second_Insured_Last_Name__c, 
                Borrowers_Phone_Number__c, Email, Second_Insured_Phone_1__c, Second_Insured_Email__c, 
                Lead_Priority__c, Zillow_Link__c, Bind_Process_State__c, QBO_Payment_Received__c,
                Referral_Source_Name__c, Partner_Name__c, Loan_Officer_Name__c, Processor_Name__c, Loan_Associate_Name__c,
                NBC_Address__Street__s, NBC_Address__City__s, NBC_Address__StateCode__s, NBC_Address__PostalCode__s, NBC_Address__CountryCode__s, Is_signed_proposal_required__c
                FROM Lead WHERE Id = :recordId LIMIT 1];
                
            if (leads.isEmpty()) {
                throw new AuraHandledException('Lead record not found or inaccessible for ID: ' + recordId);
            }
            w.recordDetail = leads[0];
            Lead l = leads[0];
            List<String> finalLines = new List<String>();
            if (l.Personal_Lines__c != null) finalLines.addAll(l.Personal_Lines__c.split(';'));
            if (l.Commercial_Lines__c != null) finalLines.addAll(l.Commercial_Lines__c.split(';'));
            w.leadLinesList = finalLines;
            
            // NBC Validation for Lead
            validateLeadForNBC(recordId, w);
        } 
        else if (sType == Opportunity.SObjectType) {
            List<Opportunity> opps = [SELECT Id, Name, AccountId, Account.Name, OwnerId, Owner.Name, Owner.Email, 
                Account.Address_Property__Street__s, Account.Address_Property__City__s, Account.Address_Property__StateCode__s, Account.Address_Property__PostalCode__s, 
                Account.BillingStreet, Account.BillingCity, Account.BillingState, Account.BillingPostalCode, Account.Phone, Account.Email__c, 
                Account.Second_Insured_First_Name__c, Account.Second_Insured_Last_Name__c, 
                Policy_Check_Status__c, Agent_2__c, Agent_2__r.Name, Agent_2__r.Email, Policy_Check_Comments__c, 
                Date_Bound__c, Rewrite__c, LeadSource, CSR_Work_Order__c, Comments__c, Notes_For_CSR__c, Agent_Notes__c, Bind_Process_State__c,
                Account.Referral_Source_Name__c, Account.Partner_Name__c, Account.Loan_Officer_Name__c, Account.Processor_Name__c, Account.Loan_Associate_Name__c
                FROM Opportunity WHERE Id = :recordId LIMIT 1];
            if (opps.isEmpty()) {
                throw new AuraHandledException('Opportunity record not found or inaccessible for ID: ' + recordId);
            }
            w.recordDetail = opps[0];
            w.leadLinesList = new List<String>();
            
            // NBC Validation for Opportunity
            validateOpportunityForNBC(recordId, w);
        }

        // 2. Policies
        String query = 'SELECT Id, CreatedDate, LastModifiedDate, Lead__c, Carrier__c, Lines__c, Quote__c, Agency_State__c, Policy__c, Date_Bound__c, Premium__c, Agency_Fee__c, Agency_Fee_Waiver_Request__c, Agency_Fee_Waiver_Decision__c, Waiver_Reason__c, Waiver_Comment__c, Effective_Date__c, Policy_Status__c, Additional_Comments__c, Term__c, Expiration_Date__c, Generate_Invoice__c, Paid_To_Date__c, Policy_Type__c, Policy_Bound__c, Reason_Not_Bound__c, Replacement_Initiated__c, Is_Replacement__c, Original_Policy__c, Replacement_Credit_Status__c, Available_Credit_Amount__c, Refundable_Balance_Amount__c, Credit_Applied_Amount__c, (SELECT Status__c FROM Agency_Fee_Invoices__r ORDER BY CreatedDate DESC LIMIT 1), (SELECT Id, Type__c, Credit__c, Debit__c, Balance__c, Date_Time__c, Status__c, Description__c, Reference_Number__c, Policy_Information__c, Policy_Information__r.Quote__c, Policy_Information__r.Carrier__c, Policy_Information__r.Lines__c, Policy_Information__r.Lead__c, Policy_Information__r.Original_Policy__c, Related_Policy__c, Related_Policy__r.Quote__c, Related_Policy__r.Carrier__c, Related_Policy__r.Lines__c FROM Financial_Ledgers__r ORDER BY Date_Time__c ASC) FROM Policy_Information__c WHERE ';
        if (sType == Lead.SObjectType) query += 'Lead__c = :recordId';
        else if (sType == Opportunity.SObjectType) query += 'Opportunity__c = :recordId';
        query += ' ORDER BY CreatedDate ASC';
        
        w.policies = Database.query(query);
        
        // Self-heal: calculate actual available credit from ledger and sync with policy records using single economic ownership
        List<Financial_Ledger__c> ledgers = new List<Financial_Ledger__c>();
        Map<Id, Decimal> policyToCreditApplied = new Map<Id, Decimal>();
        Map<Id, Decimal> policyToRefundIssued = new Map<Id, Decimal>();
        Set<Id> policiesWithDirectPayment = new Set<Id>();

        if (w.policies != null && !w.policies.isEmpty()) {
            // Auto-heal: Ensure every paid policy has a Credit Created ledger entry so Financial_Ledger__c is the single source of truth
            ledgers = ensureLedgersForPaidPolicies(w.policies, false);

            LeadCreditComputation creditState = computeLeadCreditFromLedgers(w.policies, ledgers);
            policyToCreditApplied = creditState.policyToCreditApplied;
            policyToRefundIssued = creditState.policyToRefundIssued;
            policiesWithDirectPayment = creditState.policiesWithDirectPayment;
            w.globalAvailableCredit = creditState.globalAvailableCredit;
            w.globalOutstandingAmount = creditState.globalOutstandingAmount;
            w.globalNetRefundOwed = creditState.globalNetRefundOwed;
        } else {
            w.globalAvailableCredit = 0.00;
            w.globalOutstandingAmount = 0.00;
            w.globalNetRefundOwed = 0.00;
        }

        Map<Id, Policy_Information__c> polMap = (w.policies != null) ? new Map<Id, Policy_Information__c>(w.policies) : new Map<Id, Policy_Information__c>();
        Set<Id> allReplacedParentIds = new Set<Id>();
        DateTime earliestCreatedDate = null;
        for (Policy_Information__c pol : w.policies) {
            Boolean isChildAbandoned = (pol.Policy_Status__c == 'Rejected' || pol.Policy_Status__c == 'Abandoned' || pol.Policy_Bound__c == 'No');
            if (pol.Original_Policy__c != null && !isChildAbandoned) {
                allReplacedParentIds.add(pol.Original_Policy__c);
            }
            Boolean isRep = (pol.Is_Replacement__c == true || pol.Original_Policy__c != null);
            if (!isRep && pol.CreatedDate != null) {
                if (earliestCreatedDate == null || pol.CreatedDate < earliestCreatedDate) {
                    earliestCreatedDate = pol.CreatedDate;
                }
            }
        }

        Decimal leadCashCollected = 0.00;
        Decimal leadRefundsIssued = 0.00;
        for (Policy_Information__c pCheck : w.policies) {
            if (pCheck.Agency_Fee_Invoices__r != null && !pCheck.Agency_Fee_Invoices__r.isEmpty() && pCheck.Agency_Fee_Invoices__r[0].Status__c == 'Paid') {
                Decimal pFee = pCheck.Agency_Fee__c != null ? pCheck.Agency_Fee__c : 0.00;
                Decimal pCredit = pCheck.Credit_Applied_Amount__c != null ? pCheck.Credit_Applied_Amount__c : 0.00;
                leadCashCollected += Math.max(0, pFee - pCredit);
            }
            if (pCheck.Financial_Ledgers__r != null) {
                for (Financial_Ledger__c flCheck : pCheck.Financial_Ledgers__r) {
                    if (flCheck.Type__c == 'Refund Issued' && flCheck.Debit__c != null) {
                        leadRefundsIssued += flCheck.Debit__c;
                    }
                }
            }
        }
        Decimal leadRemainingRefundableCash = Math.max(0.00, leadCashCollected - leadRefundsIssued);

        // Parse Bind_Process_State__c to identify quotes added after Step 1_2 / 1_3
        String bindStateJson = w.recordDetail != null ? (String) w.recordDetail.get('Bind_Process_State__c') : null;
        Map<String, Object> stateMap = new Map<String, Object>();
        if (String.isNotBlank(bindStateJson)) {
            try {
                stateMap = (Map<String, Object>) JSON.deserializeUntyped(bindStateJson);
            } catch (Exception e) {
                System.debug('Error parsing Bind_Process_State__c in Apex: ' + e.getMessage());
            }
        }

        String quotingClosedAtStr = (String) stateMap.get('initialQuotingClosedAt');
        DateTime quotingClosedAt = null;
        if (String.isNotBlank(quotingClosedAtStr)) {
            try {
                quotingClosedAt = (DateTime) JSON.deserialize('"' + quotingClosedAtStr + '"', DateTime.class);
            } catch (Exception e) {
                System.debug('Error parsing initialQuotingClosedAt in Apex: ' + e.getMessage());
            }
        }

        // Build pre-calculated UI DTOs for 100% synchronized rendering
        List<PolicyUiDto> uiList = new List<PolicyUiDto>();
        for (Policy_Information__c pol : w.policies) {
            PolicyUiDto dto = new PolicyUiDto();
            dto.policy = pol;

            Decimal feeAmt = (pol.Agency_Fee_Waiver_Decision__c == 'Accepted' || pol.Agency_Fee_Waiver_Request__c == true) ? 0.00 : (pol.Agency_Fee__c != null ? pol.Agency_Fee__c : 0.00);
            
            // Single Source of Truth: Rely strictly on Financial Ledger for payments and credits
            Decimal ledgerCreditApplied = policyToCreditApplied.get(pol.Id) != null ? policyToCreditApplied.get(pol.Id) : 0.00;
            Decimal ledgerRefundIssued = policyToRefundIssued.get(pol.Id) != null ? policyToRefundIssued.get(pol.Id) : 0.00;
            Decimal childNetApplied = Math.max(0, ledgerCreditApplied - ledgerRefundIssued);
            Boolean ledgerHasDirectPayment = policiesWithDirectPayment.contains(pol.Id);
            
            Decimal creditApp = ledgerCreditApplied > 0 ? ledgerCreditApplied : childNetApplied;
            pol.Credit_Applied_Amount__c = creditApp; // Preserve full applied credit for summary and ledger
            
            Decimal rawRefBal = pol.Refundable_Balance_Amount__c != null ? pol.Refundable_Balance_Amount__c : 0.00;
            Decimal refBal = (w.globalAvailableCredit != null && w.globalAvailableCredit <= 0.00) ? 0.00 : rawRefBal;
            Boolean isPaid = ledgerHasDirectPayment || (creditApp > 0 && feeAmt > 0 && creditApp >= feeAmt);
            Boolean isAbandoned = (pol.Policy_Status__c == 'Rejected' || pol.Policy_Status__c == 'Abandoned' || pol.Policy_Bound__c == 'No');
            Boolean isReplaced = pol.Replacement_Initiated__c == true || allReplacedParentIds.contains(pol.Id);
            Boolean isReplacement = (pol.Is_Replacement__c == true || pol.Original_Policy__c != null);
            Boolean hasLedgerHistory = (pol.Financial_Ledgers__r != null && !pol.Financial_Ledgers__r.isEmpty());
            Boolean isRefunded = pol.Replacement_Credit_Status__c == 'Refunded';
            Boolean isCreditAlreadyApplied = pol.Replacement_Credit_Status__c == 'Applied' || (creditApp >= feeAmt && feeAmt > 0);

            dto.isPathwayCollectFee = false;
            dto.isPathwayApplyCredit = false;
            dto.isPathwayIssueRefund = false;
            dto.isPathwayNoFee = false;
            dto.isActionDisabled = false;
            dto.hasPaymentLink = false;

            Boolean isExplicitNew = stateMap.containsKey('newQuote_' + pol.Id) && Boolean.valueOf(stateMap.get('newQuote_' + pol.Id));
            Boolean isExplicitInitial = stateMap.containsKey('initialQuote_' + pol.Id) && Boolean.valueOf(stateMap.get('initialQuote_' + pol.Id));
            Boolean isNewQuote = false;
            if (isExplicitNew) {
                isNewQuote = true;
            } else if (isExplicitInitial) {
                isNewQuote = false;
            } else if (quotingClosedAt != null && pol.CreatedDate != null && pol.CreatedDate > quotingClosedAt) {
                isNewQuote = true;
            }

            if (isReplaced) {
                dto.isReplacementPathwayActive = false;
                dto.isNewQuotePathwayActive = isNewQuote && !isReplacement;
                dto.isReplacement5Step = false;
                if (feeAmt == 0.00) {
                    dto.isPathwayNoFee = true;
                    dto.numSteps = 3;
                } else {
                    dto.isPathwayCollectFee = isNewQuote;
                    dto.isPathwayNoFee = !isNewQuote;
                    dto.numSteps = isNewQuote ? 5 : 3;
                }
            } else if (isReplacement) {
                dto.isReplacementPathwayActive = true;
                dto.isNewQuotePathwayActive = false;
                if (feeAmt == 0.00) {
                    dto.isPathwayNoFee = true;
                    dto.isReplacement5Step = false;
                    dto.numSteps = 3;
                } else {
                    dto.isReplacement5Step = true;
                    dto.isPathwayNoFee = false;
                    dto.numSteps = 5;
                }
            } else {
                dto.isReplacementPathwayActive = false;
                dto.isNewQuotePathwayActive = isNewQuote;

                if (feeAmt == 0.00) {
                    dto.isPathwayNoFee = true;
                    dto.isReplacement5Step = false;
                    dto.numSteps = 3;
                } else {
                    dto.isPathwayCollectFee = isNewQuote;
                    dto.isPathwayNoFee = !isNewQuote;
                    dto.numSteps = isNewQuote ? 5 : 3;
                }
            }

            Boolean hasPendingCreditReplacement = false;
            for (Policy_Information__c other : w.policies) {
                Boolean otherAbandoned = (other.Policy_Status__c == 'Rejected' || other.Policy_Status__c == 'Abandoned' || other.Policy_Bound__c == 'No');
                Boolean otherReplaced = (other.Replacement_Initiated__c == true || allReplacedParentIds.contains(other.Id));
                Boolean otherWaived = (other.Agency_Fee_Waiver_Decision__c == 'Accepted');
                Decimal otherFee = otherWaived ? 0.00 : (other.Agency_Fee__c != null ? other.Agency_Fee__c : 0.00);
                Decimal otherLedgerApplied = policyToCreditApplied.get(other.Id) != null ? policyToCreditApplied.get(other.Id) : 0.00;
                Decimal otherLedgerRefunded = policyToRefundIssued.get(other.Id) != null ? policyToRefundIssued.get(other.Id) : 0.00;
                Decimal otherNetApplied = Math.max(0, otherLedgerApplied - otherLedgerRefunded);
                Boolean otherLedgerHasDirectPayment = policiesWithDirectPayment.contains(other.Id);
                
                Decimal otherCredit = otherNetApplied;
                Boolean otherPaid = otherLedgerHasDirectPayment || (otherCredit > 0 && otherFee > 0 && otherCredit >= otherFee);

                if (!otherAbandoned && !otherReplaced && otherFee > 0 && !otherPaid) {
                    hasPendingCreditReplacement = true;
                    break;
                }
            }

            if (isReplaced && isPaid) {
                if (isRefunded) {
                    dto.isPathwayNoFee = (feeAmt == 0.00);
                    dto.tileStatus = 'Refunded';
                    dto.tileActionText = 'None';
                    dto.feeAmountFormatted = '$' + refBal.setScale(2);
                    dto.tileStatusColor = '#64748b';
                    dto.hasTileAction = false;

                    dto.modalStatusText = 'Refunded';
                    dto.modalActionText = 'View Details';
                    dto.modalStatusPillClass = 'pill-blue';
                    dto.modalActionBtnClass = 'btn-white-blue';
                    dto.hasPaymentLink = true;
                    dto.isActionDisabled = false;
                } else if (refBal > 0) {
                    dto.isPathwayIssueRefund = true;
                    dto.tileStatus = 'Refund Due';
                    dto.tileActionText = 'Issue Refund';
                    dto.feeAmountFormatted = '$' + refBal.setScale(2);
                    dto.tileStatusColor = '#e28705';
                    dto.hasTileAction = true;

                    dto.modalStatusText = 'Paid';
                    dto.modalActionText = 'Issue Refund';
                    dto.modalStatusPillClass = 'pill-green';
                    dto.modalActionBtnClass = 'btn-orange-filled';
                    dto.hasPaymentLink = true;
                } else {
                    dto.isPathwayNoFee = (feeAmt == 0.00);
                    dto.tileStatus = 'Paid';
                    dto.tileActionText = 'View Details';
                    dto.feeAmountFormatted = '$' + feeAmt.setScale(2);
                    dto.tileStatusColor = '#166534';
                    dto.hasTileAction = false;

                    dto.modalStatusText = 'Paid';
                    dto.modalActionText = 'View Details';
                    dto.modalStatusPillClass = 'pill-green';
                    dto.modalActionBtnClass = 'btn-white-blue';
                    dto.hasPaymentLink = true;
                }
            } else if (isAbandoned) {

                if (isRefunded) {
                    dto.isPathwayNoFee = (feeAmt == 0.00);
                    dto.tileStatus = 'Refunded';
                    dto.tileActionText = 'None';
                    dto.feeAmountFormatted = '$' + refBal.setScale(2);
                    dto.tileStatusColor = '#64748b';
                    dto.hasTileAction = false;

                    dto.modalStatusText = 'Refunded';
                    dto.modalActionText = 'View Details';
                    dto.modalStatusPillClass = 'pill-blue';
                    dto.modalActionBtnClass = 'btn-white-blue';
                    dto.hasPaymentLink = true;
                    dto.isActionDisabled = false;
                } else if (refBal > 0) {
                    dto.isPathwayIssueRefund = true;
                    dto.tileStatus = 'Refund Due';
                    dto.tileActionText = 'Issue Refund';
                    dto.feeAmountFormatted = '$' + refBal.setScale(2);
                    dto.tileStatusColor = '#e28705';
                    dto.hasTileAction = true;

                    dto.modalStatusText = 'Paid';
                    dto.modalActionText = 'Issue Refund';
                    dto.modalStatusPillClass = 'pill-green';
                    dto.modalActionBtnClass = 'btn-orange-filled';
                    dto.hasPaymentLink = true;
                } else {
                    Boolean isActuallyPaid = isPaid;
                    if (isActuallyPaid) {
                        dto.isPathwayNoFee = (feeAmt == 0.00);
                        dto.tileStatus = 'Paid';
                        dto.tileActionText = 'View Details';
                        dto.feeAmountFormatted = '$' + feeAmt.setScale(2);
                        dto.tileStatusColor = '#166534';
                        dto.hasTileAction = false;

                        dto.modalStatusText = 'Paid';
                        dto.modalActionText = 'View Details';
                        dto.modalStatusPillClass = 'pill-green';
                        dto.modalActionBtnClass = 'btn-white-blue';
                        dto.hasPaymentLink = true;
                        dto.isActionDisabled = false;
                    } else if (hasLedgerHistory) {
                        dto.isPathwayNoFee = (feeAmt == 0.00);
                        dto.tileStatus = 'Not Applicable';
                        dto.tileActionText = 'View Details';
                        dto.feeAmountFormatted = '$0.00';
                        dto.tileStatusColor = '#64748b';
                        dto.hasTileAction = false;

                        dto.modalStatusText = 'Not Applicable';
                        dto.modalActionText = 'View Details';
                        dto.modalStatusPillClass = 'pill-gray-disabled';
                        dto.modalActionBtnClass = 'btn-white-blue';
                        dto.isActionDisabled = false;
                    } else {
                        dto.isPathwayNoFee = (feeAmt == 0.00);
                        dto.tileStatus = 'Not Applicable';
                        dto.tileActionText = 'None';
                        dto.feeAmountFormatted = '$0.00';
                        dto.tileStatusColor = '#64748b';
                        dto.hasTileAction = false;

                        dto.modalStatusText = 'Not Applicable';
                        dto.modalActionText = 'Not Applicable';
                        dto.modalStatusPillClass = 'pill-gray-disabled';
                        dto.modalActionBtnClass = 'btn-white-blue';
                        dto.isActionDisabled = true;
                    }
                }
            } else if (feeAmt == 0) {
                Boolean isPaidBeforeWaiver = ledgerHasDirectPayment || creditApp > 0;

                if (isRefunded) {
                    dto.isPathwayNoFee = true;
                    dto.tileStatus = 'Refunded';
                    dto.tileActionText = 'None';
                    dto.feeAmountFormatted = '$0.00';
                    dto.tileStatusColor = '#64748b';
                    dto.hasTileAction = false;

                    dto.modalStatusText = 'Refunded';
                    dto.modalActionText = 'View Details';
                    dto.modalStatusPillClass = 'pill-blue';
                    dto.modalActionBtnClass = 'btn-white-blue';
                    dto.hasPaymentLink = true;
                    dto.isActionDisabled = false;
                } else if (isPaidBeforeWaiver && refBal > 0) {
                    dto.isPathwayIssueRefund = true;
                    dto.tileStatus = 'Refund Due';
                    dto.tileActionText = 'Issue Refund';
                    dto.feeAmountFormatted = '$' + refBal.setScale(2);
                    dto.tileStatusColor = '#e28705';
                    dto.hasTileAction = true;

                    dto.modalStatusText = 'Refund Due';
                    dto.modalActionText = 'Issue Refund';
                    dto.modalStatusPillClass = 'pill-orange';
                    dto.modalActionBtnClass = 'btn-orange-filled';
                    dto.hasPaymentLink = true;
                    dto.isActionDisabled = false;

                    dto.estimatedRefundAmt = refBal;
                    dto.estimatedRefundText = 'Estimated refund: $' + refBal.setScale(2);
                } else if (isPaidBeforeWaiver) {
                    dto.isPathwayNoFee = true;
                    dto.tileStatus = 'Paid';
                    dto.tileActionText = 'None';
                    dto.feeAmountFormatted = '$0.00';
                    dto.tileStatusColor = '#166534';
                    dto.hasTileAction = false;

                    dto.modalStatusText = 'Paid';
                    dto.modalActionText = 'View Details';
                    dto.modalStatusPillClass = 'pill-green';
                    dto.modalActionBtnClass = 'btn-white-blue';
                    dto.hasPaymentLink = true;
                    dto.isActionDisabled = false;
                } else {
                    dto.isPathwayNoFee = true;
                    dto.tileStatus = 'No Agency Fee Balance';
                    dto.tileActionText = 'None';
                    dto.feeAmountFormatted = '$0.00';
                    dto.tileStatusColor = '#166534';
                    dto.hasTileAction = false;

                    dto.modalStatusText = 'Not Applicable';
                    dto.modalActionText = 'Not Applicable';
                    dto.modalStatusPillClass = 'pill-gray-disabled';
                    dto.modalActionBtnClass = 'btn-white-blue';
                    dto.isActionDisabled = true;
                }
            } else if (isPaid || (creditApp >= feeAmt && feeAmt > 0) || (pol.Replacement_Credit_Status__c == 'Applied' && creditApp >= feeAmt)) {
                if (isRefunded) {
                    dto.isPathwayNoFee = (feeAmt == 0.00);
                    dto.tileStatus = 'Refunded';
                    dto.tileActionText = 'None';
                    dto.feeAmountFormatted = '$' + refBal.setScale(2);
                    dto.tileStatusColor = '#64748b';
                    dto.hasTileAction = false;

                    dto.modalStatusText = 'Refunded';
                    dto.modalActionText = 'View Details';
                    dto.modalStatusPillClass = 'pill-blue';
                    dto.modalActionBtnClass = 'btn-white-blue';
                    dto.hasPaymentLink = true;
                    dto.isActionDisabled = false;
                } else if (refBal > 0 && !hasPendingCreditReplacement) {
                    dto.isPathwayIssueRefund = true;
                    dto.tileStatus = 'Refund Due';
                    dto.tileActionText = 'Issue Refund';
                    dto.feeAmountFormatted = '$' + feeAmt.setScale(2);
                    dto.tileStatusColor = '#e28705';
                    dto.hasTileAction = true;

                    dto.modalStatusText = 'Paid';
                    dto.modalActionText = 'Issue Refund';
                    dto.modalStatusPillClass = 'pill-green';
                    dto.modalActionBtnClass = 'btn-orange-filled';
                    dto.hasPaymentLink = true;

                    dto.estimatedRefundAmt = refBal;
                    dto.estimatedRefundText = 'Estimated refund: $' + refBal.setScale(2);
                } else {
                    dto.isPathwayCollectFee = (feeAmt > 0.00);
                    dto.isPathwayNoFee = (feeAmt == 0.00);
                    dto.tileStatus = 'Paid';
                    dto.tileActionText = 'None';
                    dto.feeAmountFormatted = '$' + feeAmt.setScale(2);
                    dto.tileStatusColor = '#166534';
                    dto.hasTileAction = false;

                    dto.modalStatusText = 'Paid';
                    dto.modalActionText = 'View Details';
                    dto.modalStatusPillClass = 'pill-green';
                    dto.modalActionBtnClass = 'btn-white-blue';
                    dto.hasPaymentLink = true;
                }
            } else if (creditApp > 0 && creditApp < feeAmt) {
                if (isAbandoned || isReplaced) {
                    if (isRefunded) {
                        dto.isPathwayNoFee = true;
                        dto.tileStatus = 'Refunded';
                        dto.tileActionText = 'None';
                        dto.feeAmountFormatted = '$' + refBal.setScale(2);
                        dto.tileStatusColor = '#64748b';
                        dto.hasTileAction = false;
                        dto.modalStatusText = 'Refunded';
                        dto.modalActionText = 'View Details';
                        dto.modalStatusPillClass = 'pill-blue';
                        dto.modalActionBtnClass = 'btn-white-blue';
                        dto.hasPaymentLink = true;
                        dto.isActionDisabled = false;
                    } else if (refBal > 0 && !hasPendingCreditReplacement) {
                        dto.isPathwayIssueRefund = true;
                        dto.tileStatus = 'Refund Due';
                        dto.tileActionText = 'Issue Refund';
                        dto.feeAmountFormatted = '$' + refBal.setScale(2);
                        dto.tileStatusColor = '#e28705';
                        dto.hasTileAction = true;
                        dto.modalStatusText = 'Not Applicable';
                        dto.modalActionText = 'Issue Refund';
                        dto.modalStatusPillClass = 'pill-orange';
                        dto.modalActionBtnClass = 'btn-orange-filled';
                        dto.hasPaymentLink = true;
                    } else if (hasLedgerHistory) {
                        dto.isPathwayNoFee = true;
                        dto.tileStatus = 'Not Applicable';
                        dto.tileActionText = 'View Details';
                        dto.feeAmountFormatted = '$0.00';
                        dto.tileStatusColor = '#64748b';
                        dto.hasTileAction = false;
                        dto.modalStatusText = 'Not Applicable';
                        dto.modalActionText = 'View Details';
                        dto.modalStatusPillClass = 'pill-gray-disabled';
                        dto.modalActionBtnClass = 'btn-white-blue';
                        dto.isActionDisabled = false;
                    } else {
                        dto.isPathwayNoFee = true; // No fee to collect
                        dto.tileStatus = 'Not Applicable';
                        dto.tileActionText = 'None';
                        dto.feeAmountFormatted = '$0.00';
                        dto.tileStatusColor = '#64748b';
                        dto.hasTileAction = false;
                        dto.modalStatusText = 'Not Applicable';
                        dto.modalActionText = 'Not Applicable';
                        dto.modalStatusPillClass = 'pill-gray-disabled';
                        dto.modalActionBtnClass = 'btn-white-blue';
                        dto.isActionDisabled = true;
                    }
                } else {
                    Decimal remaining = feeAmt - creditApp;
                    dto.isPathwayCollectFee = true;
                    dto.tileStatus = 'Balance Due';
                    dto.tileActionText = 'Process Payment';
                    dto.feeAmountFormatted = '$' + remaining.setScale(2);
                    dto.tileStatusColor = '#0176d3';
                    dto.hasTileAction = true;
    
                    dto.modalStatusText = 'Not Sent';
                    dto.modalActionText = 'Send Payment Link';
                    dto.modalStatusPillClass = 'pill-gray';
                    dto.modalActionBtnClass = 'btn-blue-filled';
                    dto.hasPaymentLink = true;
                }
            } else if (!isCreditAlreadyApplied && pol.Agency_Fee_Waiver_Decision__c != 'Accepted' && feeAmt > 0 && w.globalAvailableCredit > 0) {
                dto.isPathwayApplyCredit = true;
                dto.tileStatus = 'Available Credit';
                dto.tileActionText = 'Apply Credit';
                Decimal availAmt = Math.min(feeAmt, w.globalAvailableCredit);
                dto.feeAmountFormatted = '$' + availAmt.setScale(2);
                dto.tileStatusColor = '#8b5cf6';
                dto.hasTileAction = true;

                dto.modalStatusText = 'Not Sent';
                dto.modalActionText = 'Apply Credit';
                dto.modalStatusPillClass = 'pill-gray';
                dto.modalActionBtnClass = 'btn-purple-filled';
                dto.hasPaymentLink = true;

                dto.availableCreditAmt = w.globalAvailableCredit;
                dto.availableCreditText = 'Available credit: $' + w.globalAvailableCredit.setScale(2);

                if (w.globalAvailableCredit > feeAmt) {
                    Decimal estRefund = w.globalAvailableCredit - feeAmt;
                    dto.estimatedRefundAmt = estRefund;
                    dto.estimatedRefundText = 'Estimated refund: $' + estRefund.setScale(2);
                } else if (w.globalAvailableCredit < feeAmt) {
                    Decimal balDue = feeAmt - w.globalAvailableCredit;
                    dto.balanceDueAmt = balDue;
                    dto.balanceDueText = 'Balance due: $' + balDue.setScale(2);
                } else {
                    dto.balanceDueAmt = 0.00;
                    dto.balanceDueText = 'Balance due: $0.00';
                }
                Boolean isApproved = (pol.Policy_Status__c == 'Approved' || pol.Policy_Status__c == 'Approved - With Post-Bind Conditions');
                dto.isActionDisabled = !isApproved;
            } else {
                dto.isPathwayCollectFee = true;
                dto.tileStatus = 'Balance Due';
                dto.tileActionText = 'Process Payment';
                dto.feeAmountFormatted = '$' + feeAmt.setScale(2);
                dto.tileStatusColor = '#0176d3';
                dto.hasTileAction = true;

                Boolean isSentInv = (pol.Agency_Fee_Invoices__r != null && !pol.Agency_Fee_Invoices__r.isEmpty() && pol.Agency_Fee_Invoices__r[0].Status__c == 'Sent');
                dto.modalStatusText = isSentInv ? 'Sent' : 'Not Sent';
                dto.modalActionText = isSentInv ? 'Resend Payment Link' : 'Send Payment Link';
                dto.modalStatusPillClass = isSentInv ? 'pill-blue' : 'pill-gray';
                dto.modalActionBtnClass = 'btn-blue-filled';
                dto.hasPaymentLink = true;
            }

            // Ensure statusDateText is ALWAYS set for any paid policy (including Issue Refund)
            Boolean isPaidStatus = (dto.modalStatusText == 'Paid' || dto.tileStatus == 'Paid' || isPaid || ledgerHasDirectPayment);
            if (isPaidStatus) {
                DateTime paidDt = pol.LastModifiedDate != null ? pol.LastModifiedDate : (pol.CreatedDate != null ? pol.CreatedDate : DateTime.now());
                dto.statusDateText = 'Paid on ' + paidDt.format('M/d/yyyy');
            }

            if (isRefunded || dto.modalStatusText == 'Refunded' || dto.tileStatus == 'Refunded') {
                Decimal actualRefund = ledgerRefundIssued;
                Decimal refAmt = actualRefund > 0 ? actualRefund : ((pol.Refundable_Balance_Amount__c != null && pol.Refundable_Balance_Amount__c > 0) ? pol.Refundable_Balance_Amount__c : refBal);
                if (refAmt > 0) {
                    dto.creditSubtext = 'Refund issued: $' + refAmt.setScale(2);
                    dto.creditSubtextStyle = 'color: #ea580c; font-size: 12px; font-weight: 500;';
                } else if (creditApp > 0) {
                    dto.creditSubtext = 'Credit applied: $' + creditApp.setScale(2);
                    dto.creditSubtextStyle = 'color: #8b5cf6; font-size: 12px; font-weight: 500;';
                }
                dto.balanceSubtext = 'Balance due: $0.00';
                dto.balanceSubtextStyle = 'color: #2563eb; font-size: 12px;';
            } else if (dto.isPathwayIssueRefund || refBal > 0 || dto.modalActionText == 'Issue Refund' || dto.tileActionText == 'Issue Refund') {
                if (creditApp > 0) {
                    dto.creditSubtext = 'Credit applied: $' + creditApp.setScale(2);
                    dto.creditSubtextStyle = 'color: #8b5cf6; font-size: 12px; font-weight: 500;';
                }
                Decimal estAmt = (pol.Refundable_Balance_Amount__c != null && pol.Refundable_Balance_Amount__c > 0) ? pol.Refundable_Balance_Amount__c : (w.globalAvailableCredit > 0 ? w.globalAvailableCredit : (refBal > 0 ? refBal : feeAmt));
                dto.balanceSubtext = 'Estimated refund: $' + estAmt.setScale(2);
                dto.balanceSubtextStyle = 'color: #ea580c; font-size: 12px; font-weight: 600;';
            } else if (dto.isPathwayApplyCredit) {
                dto.creditSubtext = 'Available credit: $' + w.globalAvailableCredit.setScale(2);
                dto.creditSubtextStyle = 'color: #8b5cf6; font-size: 12px; font-weight: 500;';
                if (w.globalAvailableCredit >= feeAmt) {
                    dto.balanceSubtext = 'Balance due: $0.00';
                    dto.balanceSubtextStyle = 'color: #2563eb; font-size: 12px;';
                } else {
                    Decimal balDue = feeAmt - w.globalAvailableCredit;
                    dto.balanceSubtext = 'Balance due: $' + balDue.setScale(2);
                    dto.balanceSubtextStyle = 'color: #2563eb; font-size: 12px; font-weight: 600;';
                }
            } else if (isPaid || dto.modalStatusText == 'Paid' || dto.tileStatus == 'Paid') {
                if (creditApp > 0) {
                    dto.creditSubtext = 'Credit applied: $' + creditApp.setScale(2);
                    dto.creditSubtextStyle = 'color: #8b5cf6; font-size: 12px; font-weight: 500;';
                    dto.balanceSubtext = 'Balance due: $0.00';
                    dto.balanceSubtextStyle = 'color: #2563eb; font-size: 12px;';
                }
            } else if (creditApp > 0 && feeAmt > creditApp) {
                dto.creditSubtext = 'Credit applied: $' + creditApp.setScale(2);
                dto.creditSubtextStyle = 'color: #8b5cf6; font-size: 12px; font-weight: 500;';
                Decimal balDue = feeAmt - creditApp;
                dto.balanceSubtext = 'Balance due: $' + balDue.setScale(2);
                dto.balanceSubtextStyle = 'color: #2563eb; font-size: 12px; font-weight: 600;';
            } else if (creditApp > 0) {
                dto.creditSubtext = 'Credit applied: $' + creditApp.setScale(2);
                dto.creditSubtextStyle = 'color: #8b5cf6; font-size: 12px; font-weight: 500;';
                dto.balanceSubtext = 'Balance due: $0.00';
                dto.balanceSubtextStyle = 'color: #2563eb; font-size: 12px;';
            }

            uiList.add(dto);
        }
        w.policyUiList = uiList;

        // Build pre-calculated ModalSummaryDto for 100% backend financial summary
        ModalSummaryDto sumDto = new ModalSummaryDto();
        Decimal totalFees = 0.00;
        Decimal totalCollected = 0.00;
        Integer activeCount = 0;
        Integer linksReq = 0;
        Integer linksSent = 0;
        Integer paymentsPaid = 0;
        Integer paymentsPending = 0;

        for (Policy_Information__c pol : w.policies) {
            Boolean isAbandoned = (pol.Policy_Status__c == 'Rejected' || pol.Policy_Status__c == 'Abandoned' || pol.Policy_Bound__c == 'No');
            Boolean isReplaced = pol.Replacement_Initiated__c == true || allReplacedParentIds.contains(pol.Id);
            Boolean isWaived = pol.Agency_Fee_Waiver_Decision__c == 'Accepted';
            Decimal fee = isWaived ? 0.00 : (pol.Agency_Fee__c != null ? pol.Agency_Fee__c : 0.00);
            Decimal creditApp = pol.Credit_Applied_Amount__c != null ? pol.Credit_Applied_Amount__c : 0.00;
            Boolean isPaid = (pol.Agency_Fee_Invoices__r != null && !pol.Agency_Fee_Invoices__r.isEmpty() && pol.Agency_Fee_Invoices__r[0].Status__c == 'Paid');
            Boolean isSent = (pol.Agency_Fee_Invoices__r != null && !pol.Agency_Fee_Invoices__r.isEmpty() && pol.Agency_Fee_Invoices__r[0].Status__c == 'Sent');

            if (isPaid) {
                Decimal cashPaid = 0.00;
                if (pol.Financial_Ledgers__r != null && !pol.Financial_Ledgers__r.isEmpty()) {
                    for (Financial_Ledger__c fl : pol.Financial_Ledgers__r) {
                        if (fl.Type__c == 'Payment' && fl.Credit__c != null && fl.Credit__c > 0) {
                            cashPaid += fl.Credit__c;
                        }
                    }
                }
                if (cashPaid == 0.00 && ledgers != null) {
                    for (Financial_Ledger__c fl : ledgers) {
                        if (fl.Policy_Information__c == pol.Id && fl.Type__c == 'Payment' && fl.Credit__c != null && fl.Credit__c > 0) {
                            cashPaid += fl.Credit__c;
                        }
                    }
                }
                totalCollected += cashPaid;
                paymentsPaid++;
            }

            if (!isAbandoned && !isReplaced) {
                totalFees += fee;
                activeCount++;

                if (!isPaid) {
                    Boolean isCoveredByCreditOrWaiver = ((creditApp >= fee && fee > 0) || isWaived);

                    if (isCoveredByCreditOrWaiver) {
                        paymentsPaid++;
                    } else if (fee > 0) {
                        paymentsPending++;
                    }

                    if (fee > 0 && !isCoveredByCreditOrWaiver) {
                        linksReq++;
                        if (isSent) {
                            linksSent++;
                        }
                    }
                }
            }
        }

        Integer linksNotSent = Math.max(0, linksReq - linksSent);

        Decimal netRefundDue = (w.globalOutstandingAmount > 0) ? 0.00 : w.globalNetRefundOwed;
        Decimal totalRefundIssued = 0.00;
        Integer refundIssuedCount = 0;
        for (Financial_Ledger__c fl : ledgers) {
            if (fl.Type__c == 'Refund Issued' && fl.Debit__c != null && fl.Debit__c > 0) {
                totalRefundIssued += fl.Debit__c;
                refundIssuedCount++;
            }
        }

        if (totalRefundIssued >= totalCollected && totalCollected > 0) {
            netRefundDue = 0.00;
        }

        sumDto.totalFees = '$' + totalFees.setScale(2);
        sumDto.collected = '$' + totalCollected.setScale(2);
        sumDto.outstanding = '$' + w.globalOutstandingAmount.setScale(2);
        sumDto.refundsDue = '$' + netRefundDue.setScale(2);
        sumDto.availableCredit = '$' + w.globalAvailableCredit.setScale(2);
        sumDto.availableCreditSubtext = 'Available in credit pool';
        sumDto.activePolicyCount = activeCount;
        sumDto.linksReq = linksReq;
        sumDto.linksSent = linksSent;
        sumDto.linksNotSent = linksNotSent;
        sumDto.paymentsPaid = paymentsPaid;
        sumDto.paymentsPending = paymentsPending;
        sumDto.collectedSubtext = paymentsPaid + ' paid';
        sumDto.outstandingSubtext = paymentsPending + ' pending / not sent';
        Decimal totalCreditApplied = 0.00;
        Integer creditAppliedCount = 0;
        for (Policy_Information__c pol : w.policies) {
            if (pol.Credit_Applied_Amount__c != null && pol.Credit_Applied_Amount__c > 0) {
                totalCreditApplied += pol.Credit_Applied_Amount__c;
                creditAppliedCount++;
            } else if (pol.Replacement_Credit_Status__c == 'Applied' && pol.Agency_Fee__c != null && pol.Agency_Fee__c > 0) {
                totalCreditApplied += pol.Agency_Fee__c;
                creditAppliedCount++;
            }
        }

        Boolean hasApplyCreditQuote = false;
        Boolean hasIssueRefundQuote = false;
        if (uiList != null) {
            for (PolicyUiDto dto : uiList) {
                if (dto.modalActionText == 'Apply Credit' || dto.tileActionText == 'Apply Credit' || dto.isPathwayApplyCredit == true) {
                    hasApplyCreditQuote = true;
                }
                if (dto.modalActionText == 'Issue Refund' || dto.tileActionText == 'Issue Refund' || dto.isPathwayIssueRefund == true) {
                    hasIssueRefundQuote = true;
                }
            }
        }

        sumDto.showCreditAppliedTile = (totalCreditApplied > 0);

        if (hasApplyCreditQuote && w.globalAvailableCredit > 0) {
            sumDto.hasCreditGlobal = true;
            sumDto.hasRefundDueGlobal = false;
        } else if (hasIssueRefundQuote || netRefundDue > 0 || w.globalNetRefundOwed > 0) {
            Decimal displayRefundDue = (netRefundDue > 0) ? netRefundDue : (w.globalNetRefundOwed > 0 ? w.globalNetRefundOwed : w.globalAvailableCredit);
            sumDto.refundsDue = '$' + displayRefundDue.setScale(2);
            sumDto.hasRefundDueGlobal = true;
            sumDto.hasCreditGlobal = false;
        } else {
            sumDto.hasCreditGlobal = false;
            sumDto.hasRefundDueGlobal = false;
        }

        sumDto.showRefundIssuedTile = (totalRefundIssued > 0 && !sumDto.hasRefundDueGlobal);

        sumDto.creditApplied = '$' + totalCreditApplied.setScale(2);
        sumDto.creditAppliedSubtext = creditAppliedCount + ' quote(s)';

        if (totalRefundIssued > 0) {
            sumDto.refundsIssued = '$' + totalRefundIssued.setScale(2);
            sumDto.refundsIssuedSubtext = refundIssuedCount + ' refund(s)';
        } else {
            sumDto.refundsIssued = '$0.00';
            sumDto.refundsIssuedSubtext = '0 refund(s)';
        }

        w.modalSummary = sumDto;

        // 3. SME Transaction Status
        String smeQuery = 'SELECT hic_signeasy__Status__c FROM hic_signeasy__Transaction__c WHERE ';
        if (sType == Lead.SObjectType) smeQuery += 'hic_signeasy__Lead__c = :recordId ';
        else if (sType == Opportunity.SObjectType) smeQuery += 'hic_signeasy__Opportunity__c = :recordId ';
        smeQuery += 'ORDER BY CreatedDate DESC LIMIT 1';
        
        try {
            List<SObject> smeTransactions = Database.query(smeQuery);
            if (!smeTransactions.isEmpty()) {
                w.smeTransactionStatus = (String)smeTransactions[0].get('hic_signeasy__Status__c');
                w.smeTransactionId = (String)smeTransactions[0].get('Id');
            } else {
                w.smeTransactionStatus = 'None';
                w.smeTransactionId = null;
            }
        } catch (Exception e) {
            w.smeTransactionStatus = 'Error';
            System.debug('Error querying SME Transactions: ' + e.getMessage());
        }
        
        return w;
    }

    private static void validateLeadForNBC(Id leadId, BindProcessWrapper w) {
        List<Policy_Information__c> quotes = [SELECT Id, Policy_Status__c FROM Policy_Information__c WHERE Lead__c = :leadId AND Policy_Type__c = 'Quote'];
        Integer blockingCount = 0;
        Integer approvedCount = 0;
        for (Policy_Information__c q : quotes) {
            if (q.Policy_Status__c == 'Submitted' || q.Policy_Status__c == 'Pending - Pre-Bind Requirements Needed') blockingCount++;
            else if (q.Policy_Status__c == 'Approved' || q.Policy_Status__c == 'Approved - With Post-Bind Conditions') approvedCount++;
        }
        w.allowNBC = (blockingCount == 0 && approvedCount > 0);
        w.maxPolicies = approvedCount;
        if (!w.allowNBC) w.validationError = 'A Policy Check approval is required to create an NBC.';
    }

    private static void validateOpportunityForNBC(Id oppId, BindProcessWrapper w) {
        List<Policy_Information__c> quotes = [SELECT Id, Policy_Status__c FROM Policy_Information__c WHERE Opportunity__c = :oppId AND Policy_Type__c = 'Quote'];
        Integer blockingCount = 0;
        Integer approvedCount = 0;
        for (Policy_Information__c q : quotes) {
            if (q.Policy_Status__c == 'Submitted' || q.Policy_Status__c == 'Pending - Pre-Bind Requirements Needed') blockingCount++;
            else if (q.Policy_Status__c == 'Approved' || q.Policy_Status__c == 'Approved - With Post-Bind Conditions') approvedCount++;
        }
        w.allowNBC = (blockingCount == 0 && approvedCount > 0);
        w.maxPolicies = approvedCount;
        if (!w.allowNBC) w.validationError = 'A Policy Check approval is required to create an NBC.';
    }

    @AuraEnabled
    public static void saveBindProcess(BindSaveRequest request) {
        if (request.recordId == null) throw new AuraHandledException('Record ID is missing.');
        
        // Strip related fields from parentRecord before update
        SObject parentToUpdate = request.parentRecord;
        if (parentToUpdate != null) {
            Map<String, Object> fields = parentToUpdate.getPopulatedFieldsAsMap();
            SObject cleanParent = request.recordId.getSObjectType().newSObject(request.recordId);
            Map<String, Schema.SObjectField> sObjectFields = request.recordId.getSObjectType().getDescribe().fields.getMap();
            for (String f : fields.keySet()) {
                if (!f.contains('.') && !f.endsWith('__r') && f != 'Owner' && f != 'Account' && f != 'RecordType' && f != 'Id') { 
                    Schema.SObjectField sField = sObjectFields.get(f);
                    if (sField != null && sField.getDescribe().isUpdateable()) {
                        cleanParent.put(f, fields.get(f));
                    }
                }
            }
            update cleanParent;
        }
        
        // Upsert Policies
        if (request.policyRequests != null) {
            List<Policy_Information__c> policiesToUpsert = new List<Policy_Information__c>();
            List<Policy_Information__c> newPolicies = new List<Policy_Information__c>();
            Set<Id> potentialRejectedIds = new Set<Id>();
            Set<Id> existingPolIds = new Set<Id>();
            for (PolicyRequest req : request.policyRequests) {
                if (req.policyRecord.Id != null) existingPolIds.add(req.policyRecord.Id);
            }
            if (!existingPolIds.isEmpty()) {
                Map<Id, Policy_Information__c> existingPolMap = new Map<Id, Policy_Information__c>(
                    [SELECT Id, Agency_Fee_Waiver_Decision__c, Agency_Fee_Waiver_Request__c FROM Policy_Information__c WHERE Id IN :existingPolIds]
                );
                for (PolicyRequest req : request.policyRequests) {
                    if (req.policyRecord.Id != null && existingPolMap.containsKey(req.policyRecord.Id)) {
                        Policy_Information__c dbPol = existingPolMap.get(req.policyRecord.Id);
                        if (dbPol.Agency_Fee_Waiver_Decision__c != null && req.policyRecord.Agency_Fee_Waiver_Decision__c == null) {
                            req.policyRecord.Agency_Fee_Waiver_Decision__c = dbPol.Agency_Fee_Waiver_Decision__c;
                        }
                        if (dbPol.Agency_Fee_Waiver_Request__c == true) {
                            req.policyRecord.Agency_Fee_Waiver_Request__c = true;
                        }
                        if (dbPol.Agency_Fee_Waiver_Decision__c == 'Accepted' || dbPol.Agency_Fee_Waiver_Request__c == true) {
                            req.policyRecord.Agency_Fee__c = 0.00;
                        }
                    }
                }
            }

            for (PolicyRequest req : request.policyRequests) {
                if (req.policyRecord.Id == null) {
                    newPolicies.add(req.policyRecord);
                }
                policiesToUpsert.add(req.policyRecord);
                if (req.policyRecord.Id != null && req.policyRecord.Policy_Status__c == 'Rejected') {
                    potentialRejectedIds.add(req.policyRecord.Id);
                }
            }
            
            if (!potentialRejectedIds.isEmpty()) {
                Map<Id, Policy_Information__c> origMap = new Map<Id, Policy_Information__c>([
                    SELECT Id, Agency_Fee__c, Credit_Applied_Amount__c, Replacement_Credit_Status__c,Policy_Status__c,
                           (SELECT Id, Status__c FROM Agency_Fee_Invoices__r ORDER BY CreatedDate DESC LIMIT 1),
                           (SELECT Id, Type__c, Credit__c, Debit__c, Balance__c, Date_Time__c, Status__c, Description__c, Reference_Number__c, Policy_Information__c, Policy_Information__r.Quote__c, Policy_Information__r.Carrier__c, Policy_Information__r.Lines__c, Policy_Information__r.Lead__c, Policy_Information__r.Original_Policy__c, Related_Policy__c, Related_Policy__r.Quote__c, Related_Policy__r.Carrier__c, Related_Policy__r.Lines__c FROM Financial_Ledgers__r WHERE Type__c IN ('Payment', 'Credit Applied', 'Credit Created'))
                    FROM Policy_Information__c 
                    WHERE Id IN :potentialRejectedIds
                ]);
                List<Financial_Ledger__c> newLedgers = new List<Financial_Ledger__c>();
                Set<Id> invoicesToVoid = new Set<Id>();
                List<Financial_Ledger__c> ledgersToDelete = new List<Financial_Ledger__c>();
                
                for (Id pId : potentialRejectedIds) {
                    Policy_Information__c orig = origMap.get(pId);
                    if (orig != null) {
                        Decimal directCash = 0.00;
                        Boolean hasExistingCreditCreated = false;
                        
                        for (Financial_Ledger__c fl : orig.Financial_Ledgers__r) {
                            if (fl.Type__c == 'Credit Applied') {
                                ledgersToDelete.add(fl);
                            } else if (fl.Type__c == 'Payment' && fl.Credit__c != null) {
                                directCash += fl.Credit__c;
                            } else if (fl.Type__c == 'Credit Created') {
                                hasExistingCreditCreated = true;
                            }
                        }
                        
                        // Also find Credit Applied where this policy is the Related_Policy__c
                        
                        if (directCash > 0 && !hasExistingCreditCreated) {
                            Financial_Ledger__c creditCreated = new Financial_Ledger__c();
                            creditCreated.Policy_Information__c = orig.Id;
                            creditCreated.Type__c = 'Credit Created';
                            creditCreated.Credit__c = directCash;
                            creditCreated.Date_Time__c = DateTime.now();
                            creditCreated.Status__c = 'Credit Available';
                            creditCreated.Description__c = 'Credit generated due to abandoned/rejected quote';
                            newLedgers.add(creditCreated);
                        } else if (directCash == 0 && orig.Agency_Fee_Invoices__r != null && !orig.Agency_Fee_Invoices__r.isEmpty()) {
                            if (orig.Agency_Fee_Invoices__r[0].Status__c != 'Voided') {
                                invoicesToVoid.add(orig.Agency_Fee_Invoices__r[0].Id);
                            }
                        }
                    }
                }
                if (!newLedgers.isEmpty()) {
                    insert newLedgers;
                }
                
                // Credit remains associated with the recipient policy upon abandonment (no credit revert)
                
                if (!invoicesToVoid.isEmpty()) {
                    List<Agency_Fee_Invoice__c> voidInvs = new List<Agency_Fee_Invoice__c>();
                    for (Id invId : invoicesToVoid) {
                        voidInvs.add(new Agency_Fee_Invoice__c(Id = invId, Status__c = 'Voided'));
                    }
                    update voidInvs;
                    QBO_InvoiceController.voidQBOInvoicesFuture(invoicesToVoid);
                }
            }

            upsert policiesToUpsert;
            
            // Automatically generate invoices for newly added quotes in QuickBooks
            if (!newPolicies.isEmpty()) {
                List<Id> newPolicyIds = new List<Id>();
                for (Policy_Information__c np : newPolicies) {
                    if (np.Id != null) newPolicyIds.add(np.Id);
                }
                if (!newPolicyIds.isEmpty()) {
                    QBO_InvoiceController.generateInvoicesForPoliciesFuture(newPolicyIds);
                }
            }
        }
        
        // Delete Removed Policies
        if (request.deletedPolicyIds != null && !request.deletedPolicyIds.isEmpty()) {
            List<Policy_Information__c> policiesToDelete = [SELECT Id FROM Policy_Information__c WHERE Id IN :request.deletedPolicyIds];
            if (!policiesToDelete.isEmpty()) {
                delete policiesToDelete;
            }
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<User> getAgent2Options() {
        return [SELECT Id, Name, Email FROM User WHERE IsActive = true AND (Profile.Name = 'RISK  PRO Standard Profile' OR Profile.Name = 'System Administrator') ORDER BY Name];
    }

    @AuraEnabled(cacheable=true)
    public static List<Carrier__c> getCarrierOptions() {
        return [SELECT Id, Company_Name__c, Quote_Specific_Website__c FROM Carrier__c ORDER BY Company_Name__c];
    }
    
    @AuraEnabled
    public static List<ContentVersion> getProposalFiles(Id recordId) {
        Set<Id> cdIds = new Set<Id>();
        for(ContentDocumentLink cdl : [SELECT ContentDocumentId FROM ContentDocumentLink WHERE LinkedEntityId = :recordId]) {
            cdIds.add(cdl.ContentDocumentId);
        }
        return [SELECT Id, ContentDocumentId, Title, FileExtension, Type__c, LOB__c, ContentDocument.Description FROM ContentVersion WHERE ContentDocumentId IN :cdIds AND IsLatest = true AND Type__c IN ('Proposal', 'Proposal Summary') ORDER BY CreatedDate DESC];
    }
    
    @AuraEnabled
public static Policy_Information__c createReplacementQuote(Id originalPolicyId, String reasonNotBound, Id parentRecordId) {
    if (originalPolicyId == null || parentRecordId == null) {
        throw new AuraHandledException('Original Policy ID and Parent Record ID are required.');
    }
    
    Policy_Information__c original = [
        SELECT Id, Lead__c, Account__c, Opportunity__c, Carrier__c, Lines__c, Quote__c, Premium__c, Agency_Fee__c, 
        Agency_State__c, Term__c, Effective_Date__c, Expiration_Date__c, Policy_Type__c, Agency_Fee_Waiver_Request__c, 
        Agency_Fee_Waiver_Decision__c, Waiver_Reason__c, Credit_Applied_Amount__c, 
        Is_Replacement__c, Original_Policy__c, Policy_Status__c,
        (SELECT Id FROM Agency_Fee_Invoices__r WHERE Status__c = 'Paid' LIMIT 1)
        FROM Policy_Information__c WHERE Id = :originalPolicyId LIMIT 1
    ];
    
    Boolean isOriginalPaid = (original.Agency_Fee_Invoices__r != null && !original.Agency_Fee_Invoices__r.isEmpty()) || 
                             (original.Credit_Applied_Amount__c != null && original.Agency_Fee__c != null && original.Credit_Applied_Amount__c >= original.Agency_Fee__c);

    Id targetOriginalPolicyId = original.Id;

    if (original.Is_Replacement__c == true || original.Original_Policy__c != null) {
        if (!isOriginalPaid) {
            // Quote B is unpaid. Quote C bypasses Quote B and points to Quote A.
            if (original.Original_Policy__c != null) {
                targetOriginalPolicyId = original.Original_Policy__c;
            }
        }
        // If Quote B is paid, targetOriginalPolicyId remains Quote B, and we let Quote B become read-only naturally.
    }
    
    update new Policy_Information__c(
        Id = original.Id,
        Replacement_Initiated__c = true,
        Reason_Not_Bound__c = reasonNotBound,
        Policy_Bound__c = 'No'
    );
    
    Policy_Information__c replacement = original.clone(false, true, false, false);
    replacement.Original_Policy__c = targetOriginalPolicyId;
    replacement.Is_Replacement__c = true;
    replacement.Policy_Status__c = 'Submitted';
    replacement.Quote__c = null;
    replacement.Is_Quote__c = true;
    replacement.Policy_Type__c = 'Quote';
    
    // --- FIX: CLEAR CLONED FINANCIAL FIELDS SO 2ND REPLACEMENTS START CLEAN ---
    replacement.Agency_Fee__c = 0;
    replacement.Credit_Applied_Amount__c = 0;
    replacement.Refundable_Balance_Amount__c = 0;
    replacement.Replacement_Credit_Status__c = null;
    replacement.Available_Credit_Amount__c = 0; 
    

    
    if (isOriginalPaid && original.Agency_Fee__c != null && original.Agency_Fee__c > 0) {
        // replacement.Available_Credit_Amount__c = original.Agency_Fee__c;
    }
    insert replacement;
    
    Decimal origFee = original.Agency_Fee__c != null ? original.Agency_Fee__c : 0.00;
    Decimal origApplied = original.Credit_Applied_Amount__c != null ? original.Credit_Applied_Amount__c : 0.00;
    Decimal cashPortion = Math.max(0, origFee - origApplied);
    Boolean hasPaidInvoice = (original.Agency_Fee_Invoices__r != null && !original.Agency_Fee_Invoices__r.isEmpty());
    
    // We no longer manually insert a Credit Created ledger here.
    // The original Payment ledger already exists on Quote A and serves as the cash source
    // for the global credit pool in getDedupedCashInByPolicy().
    
    SObjectType sType = parentRecordId.getSObjectType();
    Field_UW_Requirement__c uwReq = new Field_UW_Requirement__c(
        Policy_Information__c = replacement.Id,
        Requirement_Type__c = 'Replacement Quote / Resubmission',
        UW_Timing__c = 'Pre-Bind',
        UW_Status__c = 'Open',
        Producer_Comments__c = 'Resubmission / Replacement Quote. This replacement quote replaces the previous quote: ' + (String.isNotBlank(original.Carrier__c) ? original.Carrier__c : 'Unknown Carrier') + ' - ' + (String.isNotBlank(original.Quote__c) ? original.Quote__c : 'Unknown Quote') + '. Reason for replacement: ' + reasonNotBound
    );
    
    if (sType == Lead.SObjectType) uwReq.Lead__c = parentRecordId;
    else if (sType == Account.SObjectType) uwReq.Account__c = parentRecordId;
    else if (sType == Opportunity.SObjectType) uwReq.Opportunity__c = parentRecordId;
    
    insert uwReq;
    
    return replacement;
}
    @AuraEnabled
public static void linkReplacementQuote(Id originalPolicyId, Id newPolicyId, String reasonNotBound, Id parentRecordId) {
    if (originalPolicyId == null || newPolicyId == null || parentRecordId == null) {
        throw new AuraHandledException('Original Policy ID, New Policy ID, and Parent Record ID are required.');
    }
    
    // FIX: Add Credit_Applied_Amount__c to the SOQL
    Policy_Information__c original = [
        SELECT Id, Carrier__c, Quote__c, Agency_Fee__c, Credit_Applied_Amount__c, 
        Is_Replacement__c, Original_Policy__c, Policy_Status__c,
        (SELECT Id FROM Agency_Fee_Invoices__r WHERE Status__c = 'Paid' LIMIT 1)
        FROM Policy_Information__c WHERE Id = :originalPolicyId LIMIT 1
    ];
    
    Boolean isOriginalPaid = (original.Agency_Fee_Invoices__r != null && !original.Agency_Fee_Invoices__r.isEmpty()) || 
                             (original.Credit_Applied_Amount__c != null && original.Agency_Fee__c != null && original.Credit_Applied_Amount__c >= original.Agency_Fee__c);

    Id targetOriginalPolicyId = original.Id;

    if (original.Is_Replacement__c == true || original.Original_Policy__c != null) {
        if (!isOriginalPaid) {
            // Quote B is unpaid. Quote C bypasses Quote B and points to Quote A.
            if (original.Original_Policy__c != null) {
                targetOriginalPolicyId = original.Original_Policy__c;
            }
        }
    }
    
    update new Policy_Information__c(
        Id = original.Id,
        Replacement_Initiated__c = true,
        Reason_Not_Bound__c = reasonNotBound,
        Policy_Bound__c = 'No'
    );
    
    Policy_Information__c newRep = new Policy_Information__c(
        Id = newPolicyId,
        Original_Policy__c = targetOriginalPolicyId,
        Is_Replacement__c = true,
        Policy_Status__c = 'Submitted',
        Is_Quote__c = true,
        Policy_Type__c = 'Quote',
        // --- FIX: CLEAR CLONED FINANCIAL FIELDS ---
        Credit_Applied_Amount__c = 0,
        Refundable_Balance_Amount__c = 0,
        Replacement_Credit_Status__c = null,
        Available_Credit_Amount__c = 0
    );
    

    
    if (isOriginalPaid && original.Agency_Fee__c != null && original.Agency_Fee__c > 0) {
        // newRep.Available_Credit_Amount__c = original.Agency_Fee__c;
    }
    update newRep;
    
    if (isOriginalPaid && original.Agency_Fee__c != null && original.Agency_Fee__c > 0) {
        // We no longer manually insert a Credit Created ledger here.
    }
    
    // UW logic remains exactly the same below...
    SObjectType sType = parentRecordId.getSObjectType();
    Field_UW_Requirement__c uwReq = new Field_UW_Requirement__c(
        Policy_Information__c = newPolicyId,
        Requirement_Type__c = 'Replacement Quote / Resubmission',
        UW_Timing__c = 'Pre-Bind',
        UW_Status__c = 'Open',
        Producer_Comments__c = 'Resubmission / Replacement Quote...'
    );
    
    if (sType == Lead.SObjectType) uwReq.Lead__c = parentRecordId;
    else if (sType == Account.SObjectType) uwReq.Account__c = parentRecordId;
    else if (sType == Opportunity.SObjectType) uwReq.Opportunity__c = parentRecordId;
    
    insert uwReq;
}
    @AuraEnabled
    public static void submitWaiverRequest(List<Id> policyIds, String waiverReason, String waiverNotes, String waiverDecision) {
        if (policyIds == null || policyIds.isEmpty()) return;
        List<Policy_Information__c> policiesToUpdate = new List<Policy_Information__c>();
        
        Set<Id> pIds = new Set<Id>(policyIds);
        List<Policy_Information__c> queriedPolicies = [
            SELECT Id, Lead__c, Opportunity__c, Lead__r.Owner.Email, Lead__r.Owner.Name, Lead__r.Name, 
                   Opportunity__r.Owner.Email, Opportunity__r.Owner.Name, Opportunity__r.Name,
                   Replacement_Credit_Status__c, Credit_Applied_Amount__c, Agency_Fee__c,
                   (SELECT Status__c FROM Agency_Fee_Invoices__r ORDER BY CreatedDate DESC LIMIT 1)
            FROM Policy_Information__c 
            WHERE Id IN :pIds
        ];
        
        Set<Id> leadIdsToSync = new Set<Id>();
        Set<Id> policiesWithRevertedCredit = new Set<Id>();
        Boolean hasAcceptedWaiver = false;
        List<Financial_Ledger__c> newLedgers = new List<Financial_Ledger__c>();
        Set<Id> invoicesToVoid = new Set<Id>();

        for (Policy_Information__c qp : queriedPolicies) {
            Policy_Information__c pUpdate = new Policy_Information__c(
                Id = qp.Id,
                Agency_Fee_Waiver_Request__c = true,
                Waiver_Reason__c = waiverReason,
                Additional_Comments__c = waiverNotes
            );
            if (String.isNotBlank(waiverDecision)) {
                pUpdate.Agency_Fee_Waiver_Decision__c = waiverDecision;
                if (waiverDecision == 'Accepted') {
                    // Check if the quote was already paid before wiping the fee
                    Boolean isAlreadyPaid = false;
                    if (qp.Agency_Fee_Invoices__r != null && !qp.Agency_Fee_Invoices__r.isEmpty()) {
                        if (qp.Agency_Fee_Invoices__r[0].Status__c == 'Paid') {
                            isAlreadyPaid = true;
                        }
                    }

                    // Check if credit was already applied from another policy
                    Boolean hasCreditApplied = (qp.Credit_Applied_Amount__c != null && qp.Credit_Applied_Amount__c > 0) || (qp.Replacement_Credit_Status__c == 'Applied');

                    // If paid in DIRECT CASH (not credit applied), safely move the cash into the credit pool
                    if (isAlreadyPaid && !hasCreditApplied && qp.Agency_Fee__c != null && qp.Agency_Fee__c > 0) {
                        Financial_Ledger__c creditCreated = new Financial_Ledger__c();
                        creditCreated.Policy_Information__c = qp.Id;
                        creditCreated.Type__c = 'Credit Created';
                        creditCreated.Credit__c = qp.Agency_Fee__c;
                        creditCreated.Date_Time__c = DateTime.now();
                        creditCreated.Status__c = 'Credit Available';
                        creditCreated.Description__c = 'Credit generated due to accepted fee waiver';
                        newLedgers.add(creditCreated);
                    }

                    pUpdate.Agency_Fee__c = 0; // Now safe to zero out
                    
                    // Do not wipe Credit_Applied_Amount__c on waiver acceptance so applied credit becomes refundable balance
                    if (qp.Lead__c != null) {
                        leadIdsToSync.add(qp.Lead__c);
                    }
                    hasAcceptedWaiver = true;
                    
                    if (!isAlreadyPaid && qp.Agency_Fee_Invoices__r != null && !qp.Agency_Fee_Invoices__r.isEmpty()) {
                        if (qp.Agency_Fee_Invoices__r[0].Status__c != 'Voided') {
                            invoicesToVoid.add(qp.Agency_Fee_Invoices__r[0].Id);
                        }
                    }
                }
            }
            policiesToUpdate.add(pUpdate);
        }
        
        if (!policiesToUpdate.isEmpty()) {
            update policiesToUpdate;
        }

        if (!newLedgers.isEmpty()) {
            insert newLedgers;
        }
        
        if (!invoicesToVoid.isEmpty()) {
            List<Agency_Fee_Invoice__c> voidInvs = new List<Agency_Fee_Invoice__c>();
            for (Id invId : invoicesToVoid) {
                voidInvs.add(new Agency_Fee_Invoice__c(Id = invId, Status__c = 'Voided'));
            }
            update voidInvs;
            QBO_InvoiceController.voidQBOInvoicesFuture(invoicesToVoid);
        }
        
        if (hasAcceptedWaiver && !leadIdsToSync.isEmpty()) {
            // Keep Credit Applied ledgers intact to preserve replacement credit history
            
            if (!leadIdsToSync.isEmpty()) {
                List<Financial_Ledger__c> allLeadLedgers = [
                    SELECT Id, Type__c, Credit__c, Debit__c, Balance__c, Date_Time__c, Status__c, Description__c, Reference_Number__c, 
                           Policy_Information__c, Policy_Information__r.Quote__c, Policy_Information__r.Carrier__c, Policy_Information__r.Lines__c, 
                           Policy_Information__r.Lead__c, Policy_Information__r.Original_Policy__c, 
                           Related_Policy__c, Related_Policy__r.Quote__c, Related_Policy__r.Carrier__c, Related_Policy__r.Lines__c 
                    FROM Financial_Ledger__c 
                    WHERE Policy_Information__r.Lead__c IN :leadIdsToSync 
                      AND Type__c IN ('Credit Created', 'Refund Issued', 'Credit Applied')
                ];
                
                Map<Id, Decimal> leadToAvailCredit = new Map<Id, Decimal>();
                for (Id lId : leadIdsToSync) {
                    leadToAvailCredit.put(lId, 0.00);
                }
                
                for(Financial_Ledger__c fl : allLeadLedgers) {
                    Id lId = fl.Policy_Information__r.Lead__c;
                    Decimal currentVal = leadToAvailCredit.get(lId);
                    if (currentVal == null) currentVal = 0.00;
                    
                    if (fl.Type__c == 'Credit Created' && fl.Credit__c != null) {
                        currentVal += fl.Credit__c;
                    }
                    if (fl.Type__c == 'Refund Issued' && fl.Debit__c != null) {
                        currentVal -= fl.Debit__c;
                    }
                    if (fl.Type__c == 'Credit Applied' && fl.Credit__c != null) {
                        currentVal -= fl.Credit__c;
                    }
                    leadToAvailCredit.put(lId, currentVal);
                }
                
                List<Policy_Information__c> allRepPolicies = [
                    SELECT Id, Lead__c, Available_Credit_Amount__c, Refundable_Balance_Amount__c 
                    FROM Policy_Information__c 
                    WHERE Lead__c IN :leadIdsToSync AND Is_Replacement__c = true
                ];
                
                for (Policy_Information__c rp : allRepPolicies) {
                    // Decimal leftover = leadToAvailCredit.get(rp.Lead__c);
                    // We NO LONGER store the global leftover on the specific policy record to prevent multi-policy overwrites.
                    // rp.Available_Credit_Amount__c = leftover;
                    // rp.Refundable_Balance_Amount__c = leftover;
                }
                if (!allRepPolicies.isEmpty()) {
                    update allRepPolicies;
                }
            }
        }
        
        if (!queriedPolicies.isEmpty()) {
            Policy_Information__c firstPol = queriedPolicies[0];
            String ownerEmail;
            String ownerName;
            String clientName;
            if (firstPol.Lead__c != null) {
                ownerEmail = firstPol.Lead__r.Owner.Email;
                ownerName = firstPol.Lead__r.Owner.Name;
                clientName = firstPol.Lead__r.Name;
            } else if (firstPol.Opportunity__c != null) {
                ownerEmail = firstPol.Opportunity__r.Owner.Email;
                ownerName = firstPol.Opportunity__r.Owner.Name;
                clientName = firstPol.Opportunity__r.Name;
            }
            
            if (String.isNotBlank(ownerEmail)) {
                Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
                mail.setToAddresses(new String[] { ownerEmail });
                mail.setSubject('New Waiver Request Submitted for ' + clientName);
                String body = 'Hello ' + ownerName + ',<br><br>' +
                              'A new agency fee waiver request has been submitted for <b>' + clientName + '</b>.<br><br>' +
                              '<b>Waiver Reason:</b> ' + (String.isNotBlank(waiverReason) ? waiverReason : 'N/A') + '<br>' +
                              '<b>Additional Notes:</b> ' + (String.isNotBlank(waiverNotes) ? waiverNotes : 'None') + '<br><br>' +
                              'Please review the request in Salesforce.<br><br>Thank you.';
                mail.setHtmlBody(body);
                mail.setSaveAsActivity(false);
                
                OrgWideEmailAddress[] owea = [SELECT Id FROM OrgWideEmailAddress WHERE Address = 'it@myriskpros.com' LIMIT 1];
                if (owea.size() > 0) {
                    mail.setOrgWideEmailAddressId(owea[0].Id);
                }
                
                try {
                    Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
                } catch (Exception e) {
                    System.debug('Error sending waiver request email: ' + e.getMessage());
                }
            }
        }
    }
    
    public class InvoicePayload {
        @AuraEnabled public String recipientType { get; set; }
        @AuraEnabled public String recipientName { get; set; }
        @AuraEnabled public Id policyId { get; set; }
        @AuraEnabled public Decimal amount { get; set; }
        @AuraEnabled public String carrier { get; set; }
        @AuraEnabled public String lineOfBusiness { get; set; }
    }

    @AuraEnabled
    public static void generateAndSaveInvoices(Id recordId, String billingType, String additionalInformation, String invoicesJson) {
        try {
            List<InvoicePayload> invoices = (List<InvoicePayload>) JSON.deserialize(invoicesJson, List<InvoicePayload>.class);
            
            List<ContentVersion> cvList = new List<ContentVersion>();
            
            // Update Policy Additional Comments before rendering PDF
            List<Policy_Information__c> policiesToUpdate = new List<Policy_Information__c>();
            Set<Id> policyIdsToUpdate = new Set<Id>();
            for (InvoicePayload inv : invoices) {
                if (!policyIdsToUpdate.contains(inv.policyId)) {
                    policiesToUpdate.add(new Policy_Information__c(Id = inv.policyId, Additional_Comments__c = additionalInformation));
                    policyIdsToUpdate.add(inv.policyId);
                }
            }
            if(!policiesToUpdate.isEmpty()) {
                update policiesToUpdate;
            }
            
            String sObjType = recordId.getSObjectType().getDescribe().getName();
            
            for (InvoicePayload inv : invoices) {
                PageReference pdfPage;
                if (inv.recipientType == 'Insured') {
                    if (billingType == 'Direct Bill') pdfPage = Page.Client_DirectBill_Invoice_PDF;
                    else pdfPage = Page.Client_AgencyBill_Invoice_PDF;
                } else {
                    if (billingType == 'Direct Bill') pdfPage = Page.LeadSource_DirectBill_Invoice_PDF;
                    else pdfPage = Page.LeadSource_AgencyBill_Invoice_PDF;
                }
                
                if (sObjType == 'Lead') pdfPage.getParameters().put('leadId', recordId);
                else pdfPage.getParameters().put('opportunityId', recordId);
                
                pdfPage.getParameters().put('policyId', inv.policyId);
                
                Blob pdfBlob;
                if (Test.isRunningTest()) {
                    pdfBlob = Blob.valueOf('Test PDF');
                } else {
                    pdfBlob = pdfPage.getContentAsPDF();
                }
                
                String carrierName = String.isNotBlank(inv.carrier) ? inv.carrier : 'Carrier';
                String lob = String.isNotBlank(inv.lineOfBusiness) ? inv.lineOfBusiness : 'Line of Business';
                String recipient = String.isNotBlank(inv.recipientName) ? inv.recipientName : 'Recipient';
                
                // "Invoice - Carrier - Line of Business - Recipient"
                String title = 'Invoice - ' + carrierName + ' - ' + lob + ' - ' + recipient;
                
                ContentVersion cv = new ContentVersion();
                cv.Title = title;
                cv.PathOnClient = title + '.pdf';
                cv.VersionData = pdfBlob;
                cv.IsMajorVersion = true;
                cvList.add(cv);
            }
            
            if (!cvList.isEmpty()) {
                insert cvList;
                
                List<ContentDocumentLink> cdlList = new List<ContentDocumentLink>();
                Set<Id> cvIds = new Set<Id>();
                for (ContentVersion cv : cvList) {
                    cvIds.add(cv.Id);
                }
                
                for (ContentVersion cv : [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id IN :cvIds]) {
                    ContentDocumentLink cdl = new ContentDocumentLink();
                    cdl.ContentDocumentId = cv.ContentDocumentId;
                    cdl.LinkedEntityId = recordId;
                    cdl.ShareType = 'V';
                    cdl.Visibility = 'AllUsers';
                    cdlList.add(cdl);
                }
                insert cdlList;
            }
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    public class GlobalInvoiceData {
        @AuraEnabled public List<InvoicePaymentDetail> policiesData { get; set; }
        @AuraEnabled public List<LedgerItem> globalLedger { get; set; }
        @AuraEnabled public Decimal globalAvailableCredit { get; set; }
        @AuraEnabled public Integer creditQuotesCount { get; set; }
        @AuraEnabled public List<LeadCreditPoolItem> leadCreditPool { get; set; }
    }

    public class LeadCreditPoolItem {
        @AuraEnabled public String id { get; set; }
        @AuraEnabled public String creditSource { get; set; }
        @AuraEnabled public Decimal createdAmt { get; set; }
        @AuraEnabled public Decimal appliedAmt { get; set; }
        @AuraEnabled public Decimal refundedAmt { get; set; }
        @AuraEnabled public Decimal availableAmt { get; set; }
        @AuraEnabled public String created { get; set; }
        @AuraEnabled public String applied { get; set; }
        @AuraEnabled public String refunded { get; set; }
        @AuraEnabled public String available { get; set; }
        @AuraEnabled public String requiredAction { get; set; }
        @AuraEnabled public String status { get; set; }
        @AuraEnabled public String statusClass { get; set; }
        @AuraEnabled public Decimal rawAvailable { get; set; }
    }

    public class InvoicePaymentDetail {
        @AuraEnabled public Id policyId { get; set; }
        @AuraEnabled public String statusText { get; set; }
        @AuraEnabled public String statusPillClass { get; set; }
        @AuraEnabled public String statusDateText { get; set; }
        @AuraEnabled public String statusTimeText { get; set; }
        @AuraEnabled public String actionText { get; set; }
        @AuraEnabled public String actionBtnClass { get; set; }
        @AuraEnabled public Boolean hasPaymentLink { get; set; }
        
        @AuraEnabled public Decimal availableCreditAmt { get; set; }
        @AuraEnabled public Decimal refundOwedAmt { get; set; }
        @AuraEnabled public Decimal creditAppliedAmt { get; set; }
        @AuraEnabled public String replacementCreditStatus { get; set; }
        @AuraEnabled public Boolean isReplacement { get; set; }
        @AuraEnabled public Id originalPolicyId { get; set; }
        @AuraEnabled public Boolean isOriginalQuote { get; set; }
        @AuraEnabled public Boolean hasPaymentReceived { get; set; }
        
        @AuraEnabled public String metaSfId { get; set; }
        @AuraEnabled public String metaQboCustId { get; set; }
        @AuraEnabled public String metaQboInvNum { get; set; }
        @AuraEnabled public String metaQboInvId { get; set; }
        @AuraEnabled public String metaInvDate { get; set; }
        @AuraEnabled public String metaDueDate { get; set; }
        @AuraEnabled public String metaSentDateTime { get; set; }
        @AuraEnabled public String metaSentBy { get; set; }
        @AuraEnabled public String metaPaymentDate { get; set; }
        @AuraEnabled public String metaPaymentMethod { get; set; }
        @AuraEnabled public String metaPaymentId { get; set; }
        @AuraEnabled public String metaPaymentLink { get; set; }
        @AuraEnabled public String metaPayee { get; set; }
        @AuraEnabled public String metaDBA { get; set; }
        @AuraEnabled public String paymentMethodsAccepted { get; set; }
        @AuraEnabled public String paymentMethodsNotAccepted { get; set; }
        
        
        @AuraEnabled public List<LedgerItem> ledgerItems { get; set; }
    }

    public class LedgerItem implements Comparable {
        @AuraEnabled public String id { get; set; }
        @AuraEnabled public String dateStr { get; set; }
        @AuraEnabled public String timeStr { get; set; }
        @AuraEnabled public String type { get; set; }
        @AuraEnabled public String no { get; set; }
        @AuraEnabled public String relatedTo { get; set; }
        @AuraEnabled public String debit { get; set; }
        @AuraEnabled public String credit { get; set; }
        @AuraEnabled public String balance { get; set; }
        @AuraEnabled public String statusClass { get; set; }
        @AuraEnabled public String status { get; set; }
        @AuraEnabled public String lineOfBusiness { get; set; }
        @AuraEnabled public String carrier { get; set; }
        @AuraEnabled public String quote { get; set; }
        @AuraEnabled public String description { get; set; }
        @AuraEnabled public String refNo { get; set; }
        
        @AuraEnabled public DateTime rawDateTime { get; set; }
        @AuraEnabled public Decimal rawDebit { get; set; }
        @AuraEnabled public Decimal rawCredit { get; set; }
        
        public LedgerItem cloneItem() {
            LedgerItem cloned = new LedgerItem();
            cloned.id = this.id;
            cloned.dateStr = this.dateStr;
            cloned.timeStr = this.timeStr;
            cloned.type = this.type;
            cloned.no = this.no;
            cloned.relatedTo = this.relatedTo;
            cloned.debit = this.debit;
            cloned.credit = this.credit;
            cloned.balance = this.balance;
            cloned.statusClass = this.statusClass;
            cloned.status = this.status;
            cloned.lineOfBusiness = this.lineOfBusiness;
            cloned.carrier = this.carrier;
            cloned.quote = this.quote;
            cloned.description = this.description;
            cloned.refNo = this.refNo;
            cloned.rawDateTime = this.rawDateTime;
            cloned.rawDebit = this.rawDebit;
            cloned.rawCredit = this.rawCredit;
            return cloned;
        }
        
        private Integer getTypeRank(String t) {
            if (t == 'Invoice') return 1;
            if (t == 'Credit Applied') return 2;
            if (t == 'Payment' || t == 'Payment Received') return 3;
            if (t == 'Refund Issued') return 4;
            return 5;
        }
        
        public Integer compareTo(Object compareTo) {
            LedgerItem other = (LedgerItem)compareTo;
            
            Long timeA = this.rawDateTime != null ? this.rawDateTime.getTime() : 0;
            Long timeB = other.rawDateTime != null ? other.rawDateTime.getTime() : 0;
            
            if (timeA == timeB) {
                String quoteA = this.quote != null ? this.quote : '';
                String quoteB = other.quote != null ? other.quote : '';
                
                if (quoteA > quoteB) return 1;
                if (quoteA < quoteB) return -1;
                
                Integer rankA = getTypeRank(this.type);
                Integer rankB = getTypeRank(other.type);
                
                if (rankA > rankB) return 1;
                if (rankA < rankB) return -1;
                return 0;
            }
            
            if (timeA > timeB) return 1;
            return -1;
        }
    }

    @AuraEnabled
    public static void generateInvoicesForPolicies(List<Id> policyIds) {
        if (policyIds == null || policyIds.isEmpty()) return;
        
        List<Policy_Information__c> policies = [
            SELECT Id,Policy_Status__c FROM Policy_Information__c 
            WHERE Id IN :policyIds 
            AND Agency_Fee__c > 0 AND (Policy_Status__c = 'Approved' OR Policy_Status__c = 'Approved - With Post-Bind Conditions' OR Is_Replacement__c = true)
            AND Id NOT IN (SELECT Policy_Information__c FROM Agency_Fee_Invoice__c)
        ];
        
        List<Id> idsToProcess = new List<Id>();
        for (Policy_Information__c p : policies) {
            idsToProcess.add(p.Id);
        }
        
        if (!idsToProcess.isEmpty()) {
            System.enqueueJob(new QBO_InvoiceQueueable(idsToProcess));
        }
    }

    @AuraEnabled
    public static GlobalInvoiceData getInvoicePaymentDetails(List<Id> policyIds) {
        GlobalInvoiceData response = new GlobalInvoiceData();
        response.policiesData = new List<InvoicePaymentDetail>();
        response.globalLedger = new List<LedgerItem>();
        
        if (policyIds == null || policyIds.isEmpty()) return response;

        List<Policy_Information__c> policies = [
            SELECT Id, Agency_Fee__c, Carrier__c, Lines__c, Quote__c, QBO_Invoice_Link__c, CreatedDate, Lead__c,Policy_Status__c,
                   Is_Replacement__c, Original_Policy__c, Original_Paid_Amount__c, Original_Policy__r.Agency_Fee__c,
                   Available_Credit_Amount__c, Credit_Applied_Amount__c, Refundable_Balance_Amount__c, Replacement_Credit_Status__c,
                   Policy_Bound__c, Replacement_Initiated__c,
                   (SELECT Id, Name, Client_Name__c, Client_Email__c, Payee__c, DBA__c, 
                           QuickBooks_Customer__c, QuickBooks_Customer_ID__c, 
                           QuickBooks_Invoice_Number__c, QuickBooks_Invoice_ID__c, 
                           Invoice_Date__c, Due_Date__c, Sent_Date_Time__c, Sent_By__r.Name, 
                           Payment_Link__c, Payment_Methods_Accepted__c, 
                           Payment_Methods_Not_Accepted__c, Status__c 
                    FROM Agency_Fee_Invoices__r ORDER BY CreatedDate DESC LIMIT 1),
                   (SELECT Id, Type__c, Debit__c, Credit__c, Balance__c, Date_Time__c, Status__c, Description__c, Reference_Number__c, Related_Policy__c, Related_Policy__r.Quote__c, Related_Policy__r.Lines__c, Related_Policy__r.Carrier__c
                    FROM Financial_Ledgers__r ORDER BY Date_Time__c ASC)
            FROM Policy_Information__c
            WHERE Id IN :policyIds
        ];

        Set<Id> originalPolicyIds = new Set<Id>();
        for (Policy_Information__c p : policies) {
            if (p.Original_Policy__c != null && p.Is_Replacement__c) {
                originalPolicyIds.add(p.Original_Policy__c);
            }
        }
        for (Policy_Information__c rep : [SELECT Original_Policy__c FROM Policy_Information__c WHERE Original_Policy__c IN :policyIds AND Is_Replacement__c = true]) {
            originalPolicyIds.add(rep.Original_Policy__c);
        }

        Set<Id> paidOriginalPolicyIds = new Set<Id>();
        if (!originalPolicyIds.isEmpty()) {
            for (Agency_Fee_Invoice__c inv : [SELECT Policy_Information__c FROM Agency_Fee_Invoice__c WHERE Policy_Information__c IN :originalPolicyIds AND Status__c = 'Paid']) {
                paidOriginalPolicyIds.add(inv.Policy_Information__c);
            }
        }
        
        Decimal leadGlobalAvailableCredit = 0.00;
        LeadCreditComputation leadCreditState = null;
        Map<Id, Policy_Information__c> syncedLeadPolicyMap = new Map<Id, Policy_Information__c>();
        
        Id leadId = null;
        for (Policy_Information__c p : policies) {
            if (p.Lead__c != null) {
                leadId = p.Lead__c;
                break;
            }
        }
               List<Financial_Ledger__c> allLeadLedgers = new List<Financial_Ledger__c>();
        if (leadId != null) {
            // Auto-heal: Ensure all paid policies for this Lead have a Credit Created ledger entry
            List<Policy_Information__c> leadPolicies = [
                SELECT Id, Quote__c, Agency_Fee__c, Credit_Applied_Amount__c, Replacement_Credit_Status__c, Policy_Status__c, Policy_Bound__c,
                       Replacement_Initiated__c, Is_Replacement__c, Original_Policy__c, Agency_Fee_Waiver_Decision__c,
                       Refundable_Balance_Amount__c, Available_Credit_Amount__c,
                       (SELECT Status__c FROM Agency_Fee_Invoices__r ORDER BY CreatedDate DESC LIMIT 1)
                FROM Policy_Information__c
                WHERE Lead__c = :leadId
            ];
            ensureLedgersForPaidPolicies(leadPolicies, true);

            allLeadLedgers = [
                SELECT Id, Type__c, Debit__c, Credit__c, Balance__c, Date_Time__c, Status__c, Description__c, Reference_Number__c,
                       Policy_Information__r.Quote__c, Policy_Information__r.Carrier__c, Policy_Information__r.Lines__c,
                       Policy_Information__c, Policy_Information__r.Lead__c, Policy_Information__r.Original_Policy__c,
                       Related_Policy__c, Related_Policy__r.Quote__c, Related_Policy__r.Lines__c, Related_Policy__r.Carrier__c
                FROM Financial_Ledger__c
                WHERE Policy_Information__r.Lead__c = :leadId
                ORDER BY Date_Time__c ASC
            ];

            leadCreditState = computeLeadCreditFromLedgers(leadPolicies, allLeadLedgers);
            leadGlobalAvailableCredit = leadCreditState.globalAvailableCredit;
            syncedLeadPolicyMap = new Map<Id, Policy_Information__c>(leadPolicies);
        }
        
        response.globalAvailableCredit = leadGlobalAvailableCredit;

        Set<Id> allReplacedParentIds = new Set<Id>();
        if (leadId != null) {
            for (Policy_Information__c leadPol : [
                SELECT Id, Original_Policy__c, Replacement_Initiated__c, Policy_Status__c, Policy_Bound__c
                FROM Policy_Information__c
                WHERE Lead__c = :leadId
            ]) {
                Boolean isChildAbandoned = (leadPol.Policy_Status__c == 'Rejected' || leadPol.Policy_Status__c == 'Abandoned' || leadPol.Policy_Bound__c == 'No');
                if (leadPol.Original_Policy__c != null && !isChildAbandoned) {
                    allReplacedParentIds.add(leadPol.Original_Policy__c);
                }
                if (leadPol.Replacement_Initiated__c == true) {
                    allReplacedParentIds.add(leadPol.Id);
                }
            }
        }

        Integer ledgerIdCounter = 1;

        for (Policy_Information__c p : policies) {
            InvoicePaymentDetail detail = new InvoicePaymentDetail();
            detail.policyId = p.Id;
            
            Agency_Fee_Invoice__c afi = null;
            if (p.Agency_Fee_Invoices__r != null && !p.Agency_Fee_Invoices__r.isEmpty()) {
                afi = p.Agency_Fee_Invoices__r[0];
            }
            
            Decimal feeWithCredit = (p.Agency_Fee__c != null ? p.Agency_Fee__c : 0.00) - (p.Credit_Applied_Amount__c != null ? p.Credit_Applied_Amount__c : 0.00);
            if (feeWithCredit < 0) feeWithCredit = 0.00;
            String feeFormatted = p.Agency_Fee__c != null ? '$' + p.Agency_Fee__c.setScale(2) : '$0.00';
            
            if (afi != null) {
                detail.metaSfId = afi.Name;
                detail.metaQboCustId = afi.QuickBooks_Customer_ID__c;
                detail.metaQboInvNum = afi.QuickBooks_Invoice_Number__c;
                detail.metaQboInvId = afi.QuickBooks_Invoice_ID__c;
                detail.metaInvDate = afi.Invoice_Date__c != null ? afi.Invoice_Date__c.format() : '-';
                detail.metaDueDate = afi.Due_Date__c != null ? afi.Due_Date__c.format() : '-';
                detail.metaSentDateTime = afi.Sent_Date_Time__c != null ? afi.Sent_Date_Time__c.format() : '-';
                detail.metaSentBy = afi.Sent_By__r != null ? afi.Sent_By__r.Name : '-';
                detail.metaPaymentLink = afi.Payment_Link__c != null ? afi.Payment_Link__c : '-';
                detail.metaPayee = afi.Payee__c != null ? afi.Payee__c : '-';
                detail.metaDBA = afi.DBA__c != null ? afi.DBA__c : '-';
                detail.paymentMethodsAccepted = afi.Payment_Methods_Accepted__c != null ? afi.Payment_Methods_Accepted__c : '-';
                detail.paymentMethodsNotAccepted = afi.Payment_Methods_Not_Accepted__c != null ? afi.Payment_Methods_Not_Accepted__c : '-';
                
                // Status defaults
                detail.statusText = afi.Status__c;
                if (afi.Status__c == 'Paid') {
                    detail.statusPillClass = 'pill-green';
                    detail.statusDateText = 'Paid on ' + detail.metaInvDate;
                    detail.statusTimeText = '';
                    detail.actionText = 'View Details';
                    detail.actionBtnClass = 'btn-white-blue';
                } else if (afi.Status__c == 'Sent') {
                    detail.statusPillClass = 'pill-blue';
                    detail.statusDateText = 'Sent on ' + detail.metaInvDate;
                    detail.statusTimeText = '';
                    detail.actionText = 'Resend Payment Link';
                    detail.actionBtnClass = 'btn-blue-filled';
                } else if (afi.Status__c == 'Voided') {
                    detail.statusText = 'Not Applicable';
                    detail.statusPillClass = 'pill-gray';
                    detail.statusDateText = '';
                    detail.statusTimeText = '';
                    detail.actionText = 'None';
                    detail.actionBtnClass = 'btn-gray-filled';
                    detail.hasPaymentLink = false;
                } else {
                    detail.statusPillClass = 'pill-gray';
                    detail.statusDateText = '';
                    detail.statusTimeText = '';
                    detail.actionText = 'Send Payment Link';
                    detail.actionBtnClass = 'btn-blue-filled';
                }
                detail.hasPaymentLink = true;
            } else {
                detail.metaSfId = '-';
                detail.metaQboCustId = '-';
                detail.metaQboInvNum = '-';
                detail.metaQboInvId = '-';
                detail.metaInvDate = '-';
                detail.metaDueDate = '-';
                detail.metaSentDateTime = '-';
                detail.metaSentBy = '-';
                detail.metaPaymentLink = '-';
                detail.metaPayee = '-';
                detail.metaDBA = '-';
                detail.paymentMethodsAccepted = '-';
                detail.paymentMethodsNotAccepted = '-';
                
                detail.statusText = 'Not Sent';
                detail.statusPillClass = 'pill-gray';
                detail.statusDateText = '';
                detail.statusTimeText = '';
                detail.actionText = 'Send Payment Link';
                detail.actionBtnClass = 'btn-blue-filled';
                detail.hasPaymentLink = true;
            }
            
            detail.availableCreditAmt = leadGlobalAvailableCredit;
            Boolean isPolReplaced = p.Replacement_Initiated__c == true || allReplacedParentIds.contains(p.Id);
            Policy_Information__c syncedPol = syncedLeadPolicyMap.containsKey(p.Id) ? syncedLeadPolicyMap.get(p.Id) : p;
            Decimal creditAppliedAmt = 0.00;
            if (leadCreditState != null && leadCreditState.policyToCreditApplied.containsKey(p.Id)) {
                creditAppliedAmt = leadCreditState.policyToCreditApplied.get(p.Id);
            } else if (syncedPol.Credit_Applied_Amount__c != null) {
                creditAppliedAmt = syncedPol.Credit_Applied_Amount__c;
            }
            detail.creditAppliedAmt = creditAppliedAmt;

            Decimal refundOwed = isPolReplaced ? 0.00 : (syncedPol.Refundable_Balance_Amount__c != null ? syncedPol.Refundable_Balance_Amount__c : 0.00);

            if (!isPolReplaced && refundOwed == 0.00 && p.Policy_Bound__c == 'No') {
                if (afi != null && afi.Status__c == 'Paid') {
                    Boolean hasReplacement = false;
                    for (Policy_Information__c child : policies) {
                        if (child.Original_Policy__c == p.Id) {
                            hasReplacement = true;
                            break;
                        }
                    }
                    if (!hasReplacement) {
                        refundOwed = p.Agency_Fee__c != null ? p.Agency_Fee__c : 0.00;
                    }
                } else if (p.Credit_Applied_Amount__c != null && p.Credit_Applied_Amount__c > 0) {
                    refundOwed = p.Credit_Applied_Amount__c;
                }
            }
            if (p.Replacement_Credit_Status__c == 'Refunded') {
                List<Financial_Ledger__c> refundLedgers = [
                    SELECT Debit__c 
                    FROM Financial_Ledger__c 
                    WHERE Policy_Information__c = :p.Id 
                      AND Type__c = 'Refund Issued'
                    LIMIT 1
                ];
                if (!refundLedgers.isEmpty() && refundLedgers[0].Debit__c != null) {
                    refundOwed = refundLedgers[0].Debit__c;
                }
            }
            detail.refundOwedAmt = refundOwed;
            detail.replacementCreditStatus = p.Replacement_Credit_Status__c;
            detail.isReplacement = p.Is_Replacement__c;
            detail.originalPolicyId = p.Original_Policy__c;
            detail.isOriginalQuote = originalPolicyIds.contains(p.Id);
            
           detail.hasPaymentReceived = false;
if (p.Financial_Ledgers__r != null) {
    for (Financial_Ledger__c fl : p.Financial_Ledgers__r) {
        // FIX: If it has a Void ledger, it means it WAS paid, so mark it true!
        if (fl.Type__c == 'Payment' || fl.Type__c == 'Void') {
            detail.hasPaymentReceived = true;
            break;
        }
    }
}
            
            // Adjust status/action based on ledger-derived credit (all quote types)
            if (creditAppliedAmt > 0 || detail.replacementCreditStatus == 'Applied' || detail.replacementCreditStatus == 'Refunded') {
                Decimal agencyFee = p.Agency_Fee__c != null ? p.Agency_Fee__c : 0.00;
                if (agencyFee > 0 && creditAppliedAmt >= agencyFee) {
                    detail.statusText = 'Paid';
                    detail.statusPillClass = 'pill-green';
                    detail.actionText = 'View Details';
                    detail.actionBtnClass = 'btn-white-blue';
                } else if (creditAppliedAmt > 0) {
                    detail.statusText = 'Credit Applied';
                    detail.statusPillClass = 'pill-purple';
                    detail.actionText = 'Process Payment';
                    detail.actionBtnClass = 'btn-blue-filled';
                }
            }
            
            // Override for abandoned/voided quotes that haven't been paid
            Boolean isAbandoned = (p.Policy_Status__c == 'Rejected' || p.Policy_Status__c == 'Abandoned' || p.Policy_Bound__c == 'No');
            if (isAbandoned && !detail.hasPaymentReceived && detail.statusText != 'Paid' && detail.refundOwedAmt <= 0) {
                detail.statusText = 'Not Applicable';
                detail.statusPillClass = 'pill-gray-disabled';
                detail.actionText = 'Not Applicable';
                detail.actionBtnClass = 'btn-white-blue';
                detail.hasPaymentLink = false;
            }
            
            detail.ledgerItems = new List<LedgerItem>();
            
            Boolean isOrigQuote = detail.isOriginalQuote;

            if (afi != null || (p.Agency_Fee__c != null && p.Agency_Fee__c > 0)) {
                LedgerItem invoiceItem = new LedgerItem();
                invoiceItem.id = String.valueOf(ledgerIdCounter++);
                invoiceItem.dateStr = detail.metaInvDate;
                invoiceItem.timeStr = afi != null && afi.Sent_Date_Time__c != null ? afi.Sent_Date_Time__c.format('h:mm a') : '-';
                invoiceItem.type = 'Invoice';
                invoiceItem.no = afi != null && afi.QuickBooks_Invoice_Number__c != null ? afi.QuickBooks_Invoice_Number__c : '-';
                invoiceItem.relatedTo = p.Lines__c + ' - ' + p.Carrier__c + ' - ' + p.Quote__c;
                invoiceItem.debit = feeFormatted;
                invoiceItem.credit = '-';
                invoiceItem.balance = feeFormatted;
                invoiceItem.statusClass = 'pill-blue';
                invoiceItem.status = 'Invoiced';
                
                invoiceItem.rawDateTime = afi != null && afi.Sent_Date_Time__c != null ? afi.Sent_Date_Time__c : (p.CreatedDate != null ? p.CreatedDate : DateTime.now());
                invoiceItem.rawDebit = p.Agency_Fee__c != null ? p.Agency_Fee__c : 0.00;
                invoiceItem.rawCredit = 0.00;
                
                invoiceItem.lineOfBusiness = p.Lines__c;
                invoiceItem.carrier = p.Carrier__c;
                invoiceItem.quote = p.Quote__c;
                invoiceItem.description = 'Agency fee invoice created';
                invoiceItem.refNo = invoiceItem.no;
                
                detail.ledgerItems.add(invoiceItem);
                response.globalLedger.add(invoiceItem.cloneItem());
            }
            
            if (p.Financial_Ledgers__r != null && !p.Financial_Ledgers__r.isEmpty()) {
                for (Financial_Ledger__c fl : p.Financial_Ledgers__r) {
                    LedgerItem li = new LedgerItem();
                    li.id = fl.Id;
                    li.dateStr = fl.Date_Time__c != null ? fl.Date_Time__c.format('MM/dd/yyyy') : '-';
                    li.timeStr = fl.Date_Time__c != null ? fl.Date_Time__c.format('h:mm a') : '-';
                    li.type = fl.Type__c;
                    li.no = fl.Reference_Number__c != null ? fl.Reference_Number__c : '-';
                    
                if (fl.Type__c == 'Credit Applied') {
                    String relStr = '';
                    if (fl.Related_Policy__c != null) {
                        if (String.isNotBlank(fl.Related_Policy__r.Lines__c)) relStr += fl.Related_Policy__r.Lines__c + ' - ';
                        if (String.isNotBlank(fl.Related_Policy__r.Carrier__c)) relStr += fl.Related_Policy__r.Carrier__c + ' - ';
                        if (String.isNotBlank(fl.Related_Policy__r.Quote__c)) relStr += fl.Related_Policy__r.Quote__c;
                    }
                    li.quote = p.Quote__c;
                    li.lineOfBusiness = p.Lines__c;
                    li.carrier = p.Carrier__c;
                    if (fl.Debit__c != null && fl.Debit__c > 0) {
                        li.relatedTo = String.isNotBlank(relStr) ? 'Transferred to ' + relStr : '-';
                        li.description = 'Credit applied to ' + relStr;
                    } else {
                        li.relatedTo = String.isNotBlank(relStr) ? 'Received from ' + relStr : '-';
                        li.description = 'Credit applied from ' + relStr;
                    }
                } else if (fl.Type__c == 'Credit Created') {
                        li.relatedTo = p.Quote__c;
                        li.quote = p.Quote__c;
                        li.lineOfBusiness = p.Lines__c;
                        li.carrier = p.Carrier__c;
                    } else {
                        li.relatedTo = p.Lines__c + ' - ' + p.Carrier__c + ' - ' + p.Quote__c;
                        li.quote = p.Quote__c;
                        li.lineOfBusiness = p.Lines__c;
                        li.carrier = p.Carrier__c;
                    }
                    
                    Decimal debitAmt = fl.Debit__c != null ? fl.Debit__c : 0.00;
                    Decimal creditAmt = fl.Credit__c != null ? fl.Credit__c : 0.00;
                    
                    li.rawDateTime = fl.Date_Time__c;
                    li.rawDebit = debitAmt;
                    li.rawCredit = creditAmt;
                    
                    li.debit = debitAmt > 0 ? '$' + debitAmt.setScale(2) : '-';
                    li.credit = creditAmt > 0 ? '$' + creditAmt.setScale(2) : '-';
                    li.balance = '-';
                    
                    li.status = fl.Status__c != null ? fl.Status__c : 'Completed';
                    if (li.status == 'Completed' || li.status == 'Applied' || li.status == 'Paid') {
                        li.statusClass = 'pill-green';
                    } else if (li.status == 'Pending') {
                        li.statusClass = 'pill-orange';
                    } else {
                        li.statusClass = 'pill-blue';
                    }
                    
                    if (li.type == 'Credit Applied' || li.type == 'Credit Created' || li.type == 'Credit Debited') {
                        li.statusClass = 'pill-purple';
                    } else if (li.type == 'Refund Issued') {
                        li.statusClass = 'pill-orange';
                    } else if (li.type == 'Void') {
                        li.statusClass = 'pill-red';
                        li.status = 'Void';
                    }
                    
                    if (li.description == null) {
                        li.description = fl.Description__c != null ? fl.Description__c : fl.Type__c;
                    }
                    li.refNo = li.no;
                    
                    Boolean includeLocal = true;
                    if (fl.Type__c == 'Credit Created' || fl.Type__c == 'Credit Available') includeLocal = false;
                    if (isOrigQuote) {
                        if (fl.Type__c == 'Credit Applied' && debitAmt > 0) includeLocal = false;
                        if (fl.Type__c == 'Credit Debited' && creditAmt > 0) includeLocal = false;
                    }
                    if (includeLocal) {
                        detail.ledgerItems.add(li);
                    }
                    
                    Boolean excludeGlobal = (fl.Type__c == 'Credit Created' || fl.Type__c == 'Credit Available') ||
                                            (fl.Type__c == 'Credit Applied' && fl.Debit__c != null && fl.Debit__c > 0) ||
                                            (fl.Type__c == 'Credit Debited' && fl.Credit__c != null && fl.Credit__c > 0);
                    if (!excludeGlobal) {
                        response.globalLedger.add(li.cloneItem());
                    }
                }
            }

            if (detail.ledgerItems != null && !detail.ledgerItems.isEmpty()) {
                detail.ledgerItems.sort();
                Decimal policyRunningBal = 0.00;
                for (LedgerItem li : detail.ledgerItems) {
                    Decimal d = li.rawDebit != null ? li.rawDebit : 0.00;
                    Decimal c = li.rawCredit != null ? li.rawCredit : 0.00;
                    
                    if (li.type == 'Void') {
                        Decimal voidAmt = (d > 0) ? d : (c > 0 ? c : 0.00);
                        policyRunningBal -= voidAmt;
                    } else if (li.type == 'Refund Issued') {
                        // Refund Issued settles existing credit
                    } else {
                        policyRunningBal = policyRunningBal + d - c;
                    }
                    
                    li.balance = (policyRunningBal < 0 ? '(-$' + Math.abs(policyRunningBal).setScale(2) + ')' : '$' + policyRunningBal.setScale(2));
                }
            }
            
            response.policiesData.add(detail);
        }
        
        Set<Id> queriedPolicyIds = new Set<Id>();
        for (Policy_Information__c p : policies) {
            queriedPolicyIds.add(p.Id);
        }
        
        if (allLeadLedgers != null) {
            List<Agency_Fee_Invoice__c> allLeadInvoices = new List<Agency_Fee_Invoice__c>();
            if (leadId != null) {
                allLeadInvoices = [
                    SELECT Id, QuickBooks_Invoice_Number__c, Sent_Date_Time__c, Status__c, 
                           Policy_Information__c, Policy_Information__r.Lines__c, Policy_Information__r.Carrier__c, Policy_Information__r.Quote__c,
                           Policy_Information__r.Agency_Fee__c, CreatedDate
                    FROM Agency_Fee_Invoice__c
                    WHERE Policy_Information__r.Lead__c = :leadId
                ];
            }
            
            for (Agency_Fee_Invoice__c inv : allLeadInvoices) {
                if (!queriedPolicyIds.contains(inv.Policy_Information__c)) {
                    LedgerItem li = new LedgerItem();
                    li.id = inv.Id;
                    li.dateStr = inv.Sent_Date_Time__c != null ? inv.Sent_Date_Time__c.format('MM/dd/yyyy') : '-';
                    li.timeStr = inv.Sent_Date_Time__c != null ? inv.Sent_Date_Time__c.format('h:mm a') : '-';
                    li.rawDateTime = inv.Sent_Date_Time__c != null ? inv.Sent_Date_Time__c : inv.CreatedDate;
                    li.type = 'Invoice';
                    li.no = inv.QuickBooks_Invoice_Number__c != null ? inv.QuickBooks_Invoice_Number__c : '-';
                    li.refNo = li.no;
                    li.relatedTo = (inv.Policy_Information__r.Lines__c != null ? inv.Policy_Information__r.Lines__c : '') + ' - ' + 
                                   (inv.Policy_Information__r.Carrier__c != null ? inv.Policy_Information__r.Carrier__c : '') + ' - ' + 
                                   (inv.Policy_Information__r.Quote__c != null ? inv.Policy_Information__r.Quote__c : '');
                    li.quote = inv.Policy_Information__r.Quote__c;
                    li.lineOfBusiness = inv.Policy_Information__r.Lines__c;
                    li.carrier = inv.Policy_Information__r.Carrier__c;
                    li.description = 'Agency fee invoice created';
                    li.status = inv.Status__c != null ? inv.Status__c : 'Invoiced';
                    li.statusClass = 'pill-blue';
                    if (li.status == 'Paid') li.statusClass = 'pill-green';
                    if (li.status == 'Voided') { li.statusClass = 'pill-gray'; li.status = 'Voided'; }
                    li.rawDebit = inv.Policy_Information__r.Agency_Fee__c != null ? inv.Policy_Information__r.Agency_Fee__c : 0.00;
                    li.rawCredit = 0.00;
                    li.debit = li.rawDebit > 0 ? '$' + li.rawDebit.setScale(2) : '-';
                    li.credit = '-';
                    li.balance = '-';
                    
                    response.globalLedger.add(li);
                }
            }

            for (Financial_Ledger__c fl : allLeadLedgers) {
                if (!queriedPolicyIds.contains(fl.Policy_Information__c)) {
                    LedgerItem li = new LedgerItem();
                    li.id = fl.Id;
                    li.dateStr = fl.Date_Time__c != null ? fl.Date_Time__c.format('MM/dd/yyyy') : '-';
                    li.timeStr = fl.Date_Time__c != null ? fl.Date_Time__c.format('h:mm a') : '-';
                    li.rawDateTime = fl.Date_Time__c;
                    li.type = fl.Type__c;
                    li.no = fl.Type__c == 'Invoice' ? (fl.Reference_Number__c != null ? fl.Reference_Number__c : '-') : '-';
                    li.refNo = fl.Reference_Number__c != null ? fl.Reference_Number__c : '-';
                    
                    if (fl.Type__c == 'Credit Applied') {
                        String relStr = '';
                        if (fl.Related_Policy__c != null) {
                            if (String.isNotBlank(fl.Related_Policy__r.Lines__c)) relStr += fl.Related_Policy__r.Lines__c + ' - ';
                            if (String.isNotBlank(fl.Related_Policy__r.Carrier__c)) relStr += fl.Related_Policy__r.Carrier__c + ' - ';
                            if (String.isNotBlank(fl.Related_Policy__r.Quote__c)) relStr += fl.Related_Policy__r.Quote__c;
                        }
                        li.relatedTo = String.isNotBlank(relStr) ? relStr : '-';
                        li.quote = fl.Policy_Information__r.Quote__c;
                        li.lineOfBusiness = fl.Policy_Information__r.Lines__c;
                        li.carrier = fl.Policy_Information__r.Carrier__c;
                        if (fl.Debit__c != null && fl.Debit__c > 0) {
                            li.description = 'Credit applied to ' + li.relatedTo;
                        } else {
                            li.description = 'Credit applied from ' + li.relatedTo;
                        }
                    } else if (fl.Type__c == 'Credit Created') {
                        li.relatedTo = fl.Policy_Information__r.Quote__c;
                        li.quote = fl.Policy_Information__r.Quote__c;
                        li.lineOfBusiness = fl.Policy_Information__r.Lines__c;
                        li.carrier = fl.Policy_Information__r.Carrier__c;
                    } else {
                        li.relatedTo = fl.Policy_Information__r.Quote__c;
                        li.quote = fl.Policy_Information__r.Quote__c;
                        li.lineOfBusiness = fl.Policy_Information__r.Lines__c;
                        li.carrier = fl.Policy_Information__r.Carrier__c;
                    }
                    
                    li.debit = fl.Debit__c != null ? '$' + fl.Debit__c.setScale(2) : '-';
                    li.credit = fl.Credit__c != null ? '$' + fl.Credit__c.setScale(2) : '-';
                    li.rawDebit = fl.Debit__c != null ? fl.Debit__c : 0;
                    li.rawCredit = fl.Credit__c != null ? fl.Credit__c : 0;
                    li.balance = fl.Balance__c != null ? '$' + fl.Balance__c.setScale(2) : '-';
                    
                    if (fl.Status__c == 'Paid' || fl.Status__c == 'Credit Applied') {
                        li.statusClass = 'pill-green';
                    } else if (fl.Status__c == 'Credit Available') {
                        li.statusClass = 'pill-blue';
                    } else {
                        li.statusClass = 'pill-orange';
                    }
                    
                    if (li.type == 'Credit Applied' || li.type == 'Credit Created' || li.type == 'Credit Debited') {
                        li.statusClass = 'pill-purple';
                    } else if (li.type == 'Refund Issued') {
                        li.statusClass = 'pill-orange';
                    } else if (li.type == 'Void') {
                        li.statusClass = 'pill-red';
                        li.status = 'Void';
                    }
                    
                    li.status = fl.Status__c != null ? fl.Status__c : '-';
                    if (li.description == null) {
                        li.description = fl.Description__c != null ? fl.Description__c : fl.Type__c;
                    }
                    
                    Boolean excludeGlobalLead = (fl.Type__c == 'Credit Applied' && fl.Debit__c != null && fl.Debit__c > 0) ||
                                                (fl.Type__c == 'Credit Debited' && fl.Credit__c != null && fl.Credit__c > 0);
                    if (!excludeGlobalLead) {
                        response.globalLedger.add(li);
                    }
                }
            }
        }
        
        if (response.policiesData != null) {
            for (InvoicePaymentDetail detailItem : response.policiesData) {
                if (detailItem.ledgerItems != null) {
                    for (LedgerItem li : detailItem.ledgerItems) {
                        li.refNo = formatLedgerRefNo(li.type, li.refNo);
                    }
                }
            }
        }

        if (response.globalLedger != null && !response.globalLedger.isEmpty()) {
            response.globalLedger.sort();
            Decimal globalRunningBalance = 0.00;
            for (LedgerItem li : response.globalLedger) {
                li.refNo = formatLedgerRefNo(li.type, li.refNo);
                Decimal d = li.rawDebit != null ? li.rawDebit : 0.00;
                Decimal c = li.rawCredit != null ? li.rawCredit : 0.00;
                
                if (li.type == 'Void') {
                    Decimal voidAmt = (d > 0) ? d : (c > 0 ? c : 0.00);
                    globalRunningBalance -= voidAmt;
                } else if (li.type == 'Refund Issued') {
                    // Refund Issued settles an existing credit balance, does not add to debit balance
                } else {
                    globalRunningBalance = globalRunningBalance + d - c;
                }
                
                li.balance = (globalRunningBalance < 0 ? '(-$' + Math.abs(globalRunningBalance).setScale(2) + ')' : '$' + globalRunningBalance.setScale(2));
            }
        }
        response.leadCreditPool = new List<LeadCreditPoolItem>();
        Map<Id, LeadCreditPoolItem> poolMap = new Map<Id, LeadCreditPoolItem>();
        Set<String> creditQuotes = new Set<String>();
        if (allLeadLedgers != null) {
            // 1. Identify sources (Credit Created, Payment, Void with Credit)
            for (Financial_Ledger__c fl : allLeadLedgers) {
                if ((fl.Type__c == 'Credit Created' || fl.Type__c == 'Payment' || fl.Type__c == 'Void') && fl.Credit__c != null && fl.Policy_Information__c != null) {
                    Id sourceId = fl.Policy_Information__c;
                    if (!poolMap.containsKey(sourceId)) {
                        LeadCreditPoolItem lcp = new LeadCreditPoolItem();
                        lcp.id = sourceId;
                        lcp.creditSource = 'Quote ' + (fl.Policy_Information__r.Quote__c != null ? fl.Policy_Information__r.Quote__c : '');
                        if (fl.Policy_Information__r.Lines__c != null) {
                            lcp.creditSource += ' (' + fl.Policy_Information__r.Lines__c + ')';
                        }
                        lcp.createdAmt = 0.00;
                        lcp.appliedAmt = 0.00;
                        lcp.refundedAmt = 0.00;
                        poolMap.put(sourceId, lcp);
                        if (fl.Policy_Information__r.Quote__c != null) {
                            creditQuotes.add(fl.Policy_Information__r.Quote__c);
                        }
                    }
                    poolMap.get(sourceId).createdAmt += fl.Credit__c;
                }
            }
            
            // 2. Aggregate Applied and Refunded
            for (Financial_Ledger__c fl : allLeadLedgers) {
                if (fl.Type__c == 'Credit Applied' && fl.Debit__c != null && fl.Debit__c > 0) {
                    Id sourceId = fl.Policy_Information__c;
                    if (poolMap.containsKey(sourceId)) {
                        poolMap.get(sourceId).appliedAmt += fl.Debit__c;
                    }
                } else if (fl.Type__c == 'Refund Issued' && fl.Debit__c != null && fl.Debit__c > 0) {
                    Id sourceId = fl.Policy_Information__c;
                    if (!poolMap.containsKey(sourceId) && fl.Policy_Information__r.Original_Policy__c != null) {
                        sourceId = fl.Policy_Information__r.Original_Policy__c;
                    }
                    if (poolMap.containsKey(sourceId)) {
                        poolMap.get(sourceId).refundedAmt += fl.Debit__c;
                    }
                }
            }
            
            // 3. Finalize items
            for (LeadCreditPoolItem lcp : poolMap.values()) {
                Decimal unconsumed = Math.max(0.00, lcp.createdAmt - lcp.appliedAmt - lcp.refundedAmt);
                Decimal globalAvail = leadCreditState != null ? leadCreditState.globalAvailableCredit : 0.00;
                lcp.availableAmt = Math.min(unconsumed, globalAvail);
                if (lcp.availableAmt < 0) lcp.availableAmt = 0.00; // Prevent negative display
                
                lcp.created = '$' + lcp.createdAmt.setScale(2);
                lcp.applied = '$' + lcp.appliedAmt.setScale(2);
                lcp.refunded = '$' + lcp.refundedAmt.setScale(2);
                lcp.available = '$' + lcp.availableAmt.setScale(2);
                
                lcp.rawAvailable = lcp.availableAmt;
                
                if (lcp.availableAmt > 0) {
                    lcp.status = 'Available';
                    lcp.statusClass = 'pill-green';
                    lcp.requiredAction = 'Apply / Refund';
                } else {
                    if (lcp.refundedAmt > 0 && lcp.appliedAmt == 0) {
                        lcp.status = 'Refunded';
                        lcp.statusClass = 'pill-gray';
                    } else if (lcp.appliedAmt > 0 && lcp.refundedAmt == 0) {
                        lcp.status = 'Applied';
                        lcp.statusClass = 'pill-gray';
                    } else {
                        lcp.status = 'Resolved';
                        lcp.statusClass = 'pill-gray';
                    }
                    lcp.requiredAction = 'None';
                }
                response.leadCreditPool.add(lcp);
            }
        }
        response.creditQuotesCount = creditQuotes.size();
        
        return response;
    }

    @AuraEnabled
    public static void sendPaymentLinkEmail(Id policyId, String clientEmail, String clientFirstName, String lines, String carrier, String quoteNumber, String amountDue, String paymentLink) {
        if (String.isBlank(clientEmail) || !Pattern.matches('^[a-zA-Z0-9._|\\\\%#~`=?&/$^*!}{+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,4}$', clientEmail)) {
            throw new AuraHandledException('A valid Client email is required to send the payment link.');
        }

        List<EmailTemplate> templates = [SELECT Id, Subject, HtmlValue FROM EmailTemplate WHERE DeveloperName = 'Agency_Service_Fee_Payment_Link' LIMIT 1];
        if (templates.isEmpty()) {
            throw new AuraHandledException('Email template "Agency_Service_Fee_Payment_Link" not found.');
        }
        
        EmailTemplate template = templates[0];
        
        String subject = template.Subject != null ? template.Subject : 'Risk Pros Insurance Agency - Agency Service Fee Payment Link - {{Line of Business}}';
        subject = subject.replace('{{Line of Business}}', (String.isNotBlank(lines) ? lines : ''));
        
        String body = template.HtmlValue != null ? template.HtmlValue : '';
        body = body.replace('{{Client First Name}}', (String.isNotBlank(clientFirstName) ? clientFirstName : 'Client'));
        body = body.replace('{{Line of Business}}', (String.isNotBlank(lines) ? lines : ''));
        body = body.replace('{{Carrier Name}}', (String.isNotBlank(carrier) ? carrier : ''));
        body = body.replace('{{Quote Number}}', (String.isNotBlank(quoteNumber) ? quoteNumber : 'Not Applicable'));
        body = body.replace('{{Agency Fee Amount}}', (String.isNotBlank(amountDue) ? amountDue : '$0.00'));
        body = body.replace('{{Payment Link}}', (String.isNotBlank(paymentLink) ? paymentLink : ''));

        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setToAddresses(new String[] { clientEmail });
        mail.setSubject(subject);
        mail.setHtmlBody(body);
        
        // Use the verified Organization-Wide Email Address
        OrgWideEmailAddress[] owea = [SELECT Id FROM OrgWideEmailAddress WHERE Address = 'it@myriskpros.com' LIMIT 1];
        if (owea.size() > 0) {
            mail.setOrgWideEmailAddressId(owea[0].Id);
        } else {
            throw new AuraHandledException('Verified Org-Wide Email Address (it@myriskpros.com) not found or not accessible to your profile.');
        }
        
        // Remove mail.setReplyTo because Salesforce may be validating the Reply-To domain as well,
        // which throws the same 'domain isn't verified' error if the user's email is unverified.
        
        // Important: if not associating with a Contact/Lead record via setTargetObjectId, 
        // we must not save it as an activity or it will throw an exception.
        mail.setSaveAsActivity(false);

        try {
            Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
            
            List<Agency_Fee_Invoice__c> invoices = [SELECT Id, Status__c, Sent_Date_Time__c, Sent_By__c FROM Agency_Fee_Invoice__c WHERE Policy_Information__c = :policyId ORDER BY CreatedDate DESC LIMIT 1];
            if (!invoices.isEmpty()) {
                if (invoices[0].Status__c != 'Paid') {
                    invoices[0].Status__c = 'Sent';
                }
                invoices[0].Sent_Date_Time__c = System.now();
                invoices[0].Sent_By__c = UserInfo.getUserId();
                update invoices[0];
            }
        } catch (Exception e) {
            throw new AuraHandledException('Failed to send email: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static Map<String, Object> applyCredit(Id replacementPolicyId) {
        try {
            Policy_Information__c rep = [
                SELECT Id, Lead__c, Original_Policy__c, Agency_Fee__c, Available_Credit_Amount__c, 
                       Credit_Applied_Amount__c, Refundable_Balance_Amount__c, Replacement_Credit_Status__c, Policy_Status__c, Policy_Bound__c, QBO_Invoice_Link__c
                FROM Policy_Information__c 
                WHERE Id = :replacementPolicyId 
                FOR UPDATE
            ];
            
            Boolean isAbandoned = (rep.Policy_Status__c == 'Rejected' || rep.Policy_Status__c == 'Abandoned' || rep.Policy_Bound__c == 'No');
            if (isAbandoned) {
                AuraHandledException aex = new AuraHandledException('Cannot apply credit to a rejected or abandoned policy.');
                aex.setMessage('Cannot apply credit to a rejected or abandoned policy.');
                throw aex;
            }
            
            if (rep.Replacement_Credit_Status__c == 'Applied' || rep.Replacement_Credit_Status__c == 'Refunded') {
                if (rep.Credit_Applied_Amount__c == null || rep.Credit_Applied_Amount__c == 0.00) {
                    // It was corrupted, allow it to self-heal
                } else if (rep.Credit_Applied_Amount__c >= rep.Agency_Fee__c) {
                    AuraHandledException aex = new AuraHandledException('Credit has already been processed for this policy.');
                    aex.setMessage('Credit has already been processed for this policy.');
                    throw aex;
                }
            }
            
            // Query all available credit ledgers for the lead
            List<Financial_Ledger__c> allLeadLedgers = [
                SELECT Id, Type__c, Credit__c, Debit__c, Balance__c, Date_Time__c, Status__c, Description__c, Reference_Number__c, 
                       Policy_Information__c, Policy_Information__r.Quote__c, Policy_Information__r.Carrier__c, Policy_Information__r.Lines__c, 
                       Policy_Information__r.Lead__c, Policy_Information__r.Original_Policy__c, 
                       Related_Policy__c, Related_Policy__r.Quote__c, Related_Policy__r.Carrier__c, Related_Policy__r.Lines__c 
                FROM Financial_Ledger__c 
                WHERE Policy_Information__r.Lead__c = :rep.Lead__c 
                  AND Type__c IN ('Credit Created', 'Payment', 'Refund Issued', 'Credit Applied', 'Credit Debited', 'Void')
                FOR UPDATE
            ];
            
            List<Policy_Information__c> leadPoliciesForCredit = [
                SELECT Id, Original_Policy__c, Replacement_Initiated__c, Agency_Fee__c, Policy_Status__c, Policy_Bound__c, Agency_Fee_Waiver_Decision__c,
                       Is_Replacement__c, Replacement_Credit_Status__c, Credit_Applied_Amount__c, Refundable_Balance_Amount__c, Available_Credit_Amount__c
                FROM Policy_Information__c 
                WHERE Lead__c = :rep.Lead__c
            ];
            Set<Id> replacedPolicyIds = new Set<Id>();
            for (Policy_Information__c p : leadPoliciesForCredit) {
                if (p.Original_Policy__c != null) replacedPolicyIds.add(p.Original_Policy__c);
                if (p.Replacement_Initiated__c == true) replacedPolicyIds.add(p.Id);
            }

            LeadCreditComputation creditState = computeLeadCreditFromLedgers(leadPoliciesForCredit, allLeadLedgers);
            Decimal totalAvailableCredit = creditState.globalAvailableCredit;
            
            if (totalAvailableCredit <= 0.00) {
                // Discover any paid invoices on the lead that don't have a Credit Created ledger yet
                List<Agency_Fee_Invoice__c> leadPaidInvoices = [
                    SELECT Id, Policy_Information__c, Policy_Information__r.Agency_Fee__c, Policy_Information__r.Credit_Applied_Amount__c
                    FROM Agency_Fee_Invoice__c 
                    WHERE Policy_Information__r.Lead__c = :rep.Lead__c AND Status__c = 'Paid'
                ];
                
                if (!leadPaidInvoices.isEmpty()) {
                    Set<Id> paidPolIds = new Set<Id>();
                    for (Agency_Fee_Invoice__c inv : leadPaidInvoices) {
                        paidPolIds.add(inv.Policy_Information__c);
                    }
                    
                    List<Financial_Ledger__c> existingLedgers = [
                        SELECT Policy_Information__c 
                        FROM Financial_Ledger__c 
                        WHERE Policy_Information__c IN :paidPolIds AND (Type__c = 'Credit Created' OR Type__c = 'Payment')
                    ];
                    Set<Id> policiesWithLedgers = new Set<Id>();
                    for (Financial_Ledger__c fl : existingLedgers) {
                        policiesWithLedgers.add(fl.Policy_Information__c);
                    }
                    
                    List<Financial_Ledger__c> ledgersToInsert = new List<Financial_Ledger__c>();
                    for (Agency_Fee_Invoice__c inv : leadPaidInvoices) {
                        if (policiesWithLedgers.contains(inv.Policy_Information__c)) {
                            continue;
                        }
                        Decimal fee = inv.Policy_Information__r.Agency_Fee__c != null ? inv.Policy_Information__r.Agency_Fee__c : 0.00;
                        Decimal applied = inv.Policy_Information__r.Credit_Applied_Amount__c != null ? inv.Policy_Information__r.Credit_Applied_Amount__c : 0.00;
                        Decimal cashPaid = Math.max(0, fee - applied);
                        if (cashPaid > 0) {
                            totalAvailableCredit += cashPaid;
                            Financial_Ledger__c creditCreated = new Financial_Ledger__c();
                            creditCreated.Policy_Information__c = inv.Policy_Information__c;
                            creditCreated.Type__c = 'Credit Created';
                            creditCreated.Credit__c = cashPaid;
                            creditCreated.Date_Time__c = DateTime.now();
                            creditCreated.Status__c = 'Credit Available';
                            ledgersToInsert.add(creditCreated);
                        }
                    }
                    if (!ledgersToInsert.isEmpty()) {
                        insert ledgersToInsert;
                        allLeadLedgers.addAll(ledgersToInsert);
                    }
                    creditState = computeLeadCreditFromLedgers(leadPoliciesForCredit, allLeadLedgers);
                    totalAvailableCredit = creditState.globalAvailableCredit;
                }
            }
            
            // Fix race condition: If QBO Webhook auto-matched the invoice and ensureLedgersForPaidPolicies
            // inserted a Credit Created ledger before the user clicked Apply Credit, delete it to prevent double counting.
            List<Financial_Ledger__c> falseCreditsToDelete = [
                SELECT Id FROM Financial_Ledger__c 
                WHERE Policy_Information__c = :rep.Id AND Type__c = 'Credit Created'
            ];
            if (!falseCreditsToDelete.isEmpty()) {
                delete falseCreditsToDelete;
                // Remove them from allLeadLedgers so computeLeadCreditFromLedgers doesn't double-count them
                for (Integer i = allLeadLedgers.size() - 1; i >= 0; i--) {
                    if (allLeadLedgers[i].Policy_Information__c == rep.Id && allLeadLedgers[i].Type__c == 'Credit Created') {
                        allLeadLedgers.remove(i);
                    }
                }
            }
            
            if (totalAvailableCredit <= 0.00) {
                AuraHandledException aex = new AuraHandledException('No available credit pool for this lead.');
                aex.setMessage('No available credit pool for this lead.');
                throw aex;
            }
            
            Decimal repFee = rep.Agency_Fee__c != null ? rep.Agency_Fee__c : 0.00;
            Decimal alreadyApplied = rep.Credit_Applied_Amount__c != null ? rep.Credit_Applied_Amount__c : 0.00;
            Decimal remainingFee = repFee - alreadyApplied;
            
            if (remainingFee <= 0) {
                throw new AuraHandledException('This policy fee is already fully paid or applied.');
            }
            
            Decimal creditToApply = Math.min(totalAvailableCredit, remainingFee);
            
            rep.Credit_Applied_Amount__c = alreadyApplied + creditToApply;
            rep.Replacement_Credit_Status__c = 'Applied';
            
            // Recalculate global balance across all lead policies
            computeLeadCreditFromLedgers(leadPoliciesForCredit, allLeadLedgers);
            update leadPoliciesForCredit;
            
            List<Financial_Ledger__c> ledgersToInsert = new List<Financial_Ledger__c>();
            
            // Determine originalPolicyId by finding the policy that actually has available credit
            Map<Id, Decimal> availableCreditMap = new Map<Id, Decimal>(getDedupedCashInByPolicy(allLeadLedgers));
            
            // Deduct the policy's own fee so we only pull from true surplus
            for (Policy_Information__c p : leadPoliciesForCredit) {
                if (availableCreditMap.containsKey(p.Id)) {
                    Boolean pIsAbandoned = (p.Policy_Status__c == 'Rejected' || p.Policy_Status__c == 'Abandoned' || p.Policy_Bound__c == 'No' || p.Replacement_Initiated__c == true);
                    Boolean isWaived = (p.Agency_Fee_Waiver_Decision__c == 'Accepted');
                    Decimal fee = (pIsAbandoned || isWaived) ? 0.00 : (p.Agency_Fee__c != null ? p.Agency_Fee__c : 0.00);
                    availableCreditMap.put(p.Id, availableCreditMap.get(p.Id) - fee);
                }
            }

            for(Financial_Ledger__c fl : allLeadLedgers) {
                if (fl.Type__c == 'Credit Applied' && fl.Debit__c != null && fl.Policy_Information__c != null) {
                    if (availableCreditMap.containsKey(fl.Policy_Information__c)) {
                        availableCreditMap.put(fl.Policy_Information__c, availableCreditMap.get(fl.Policy_Information__c) - fl.Debit__c);
                    }
                } else if (fl.Type__c == 'Refund Issued' && fl.Debit__c != null && fl.Policy_Information__c != null) {
                    Id sourceId = fl.Policy_Information__c;
                    if (!availableCreditMap.containsKey(sourceId) && fl.Policy_Information__r.Original_Policy__c != null) {
                        sourceId = fl.Policy_Information__r.Original_Policy__c;
                    }
                    if (availableCreditMap.containsKey(sourceId)) {
                        availableCreditMap.put(sourceId, availableCreditMap.get(sourceId) - fl.Debit__c);
                    }
                }
            }
            
            Id originalPolicyId = null;
            // Prefer rep.Original_Policy__c if it actually has credit
            if (rep.Original_Policy__c != null && availableCreditMap.containsKey(rep.Original_Policy__c) && availableCreditMap.get(rep.Original_Policy__c) > 0) {
                originalPolicyId = rep.Original_Policy__c;
            } else {
                // Otherwise find the first policy with available credit
                for (Id pid : availableCreditMap.keySet()) {
                    if (availableCreditMap.get(pid) > 0) {
                        originalPolicyId = pid;
                        break;
                    }
                }
            }
            
            // Fallback just in case
            if (originalPolicyId == null) {
                if (rep.Original_Policy__c != null) {
                    originalPolicyId = rep.Original_Policy__c;
                } else {
                    for (Financial_Ledger__c fl : allLeadLedgers) {
                        if ((fl.Type__c == 'Credit Created' || fl.Type__c == 'Payment' || fl.Type__c == 'Void') && fl.Policy_Information__c != null) {
                            originalPolicyId = fl.Policy_Information__c;
                            break;
                        }
                    }
                }
            }
            
            // 1. Debit Entry on Original Policy
            if (originalPolicyId != null) {
                Financial_Ledger__c creditAppliedOrg = new Financial_Ledger__c();
                creditAppliedOrg.Policy_Information__c = originalPolicyId;
                creditAppliedOrg.Type__c = 'Credit Applied';
                creditAppliedOrg.Debit__c = creditToApply;
                creditAppliedOrg.Date_Time__c = DateTime.now();
                creditAppliedOrg.Status__c = 'Credit Applied';
                creditAppliedOrg.Related_Policy__c = rep.Id;
                ledgersToInsert.add(creditAppliedOrg);
            }
            
            // 2. Credit Entry on Replacement Policy
            Financial_Ledger__c creditAppliedRep = new Financial_Ledger__c();
            creditAppliedRep.Policy_Information__c = rep.Id;
            creditAppliedRep.Type__c = 'Credit Applied';
            creditAppliedRep.Credit__c = creditToApply;
            creditAppliedRep.Date_Time__c = DateTime.now();
            creditAppliedRep.Status__c = 'Credit Applied';
            creditAppliedRep.Related_Policy__c = originalPolicyId;
            ledgersToInsert.add(creditAppliedRep);
            
            insert ledgersToInsert;
            
            // Synchronize all replacement policies under the same Lead
            if (rep.Lead__c != null) {
                List<Policy_Information__c> allRepPolicies = [
                    SELECT Id, Available_Credit_Amount__c, Refundable_Balance_Amount__c 
                    FROM Policy_Information__c 
                    WHERE Lead__c = :rep.Lead__c AND Is_Replacement__c = true
                ];
                for (Policy_Information__c rp : allRepPolicies) {
                    // rp.Available_Credit_Amount__c = leftover;
                    // rp.Refundable_Balance_Amount__c = leftover;
                }
                update allRepPolicies;
            }
            
            // Call QBO Credit Memo API asynchronously to avoid uncommitted work pending callout error
            if (rep.Lead__c != null) {
                QBO_InvoiceController.createQBOCreditMemoFuture(rep.Lead__c, rep.Id, creditToApply);
            }
            
            // Mark existing invoices as Paid if the credit covers it, instead of deleting them.
            // This preserves the chronological creation timestamp in the ledger.
            List<Agency_Fee_Invoice__c> existingInvoices = [
                SELECT Id, QuickBooks_Invoice_ID__c, Status__c
                FROM Agency_Fee_Invoice__c 
                WHERE Policy_Information__c = :rep.Id
            ];
            if (!existingInvoices.isEmpty()) {
                for (Agency_Fee_Invoice__c afi : existingInvoices) {
                    if (remainingFee - creditToApply <= 0) {
                        afi.Status__c = 'Paid';
                    } else if (creditToApply > 0) {
                        afi.Status__c = 'Credit Applied';
                    }
                }
                update existingInvoices;
            }
            
            // Removed "Account Settled" ledger insertion as requested by user.

            Map<String, Object> result = new Map<String, Object>();
            result.put('status', 'success');
            result.put('creditApplied', creditToApply);
            Decimal finalLeftover = rep.Refundable_Balance_Amount__c != null ? rep.Refundable_Balance_Amount__c : 0.00;
            result.put('refundableBalance', finalLeftover);
            return result;
            
        } catch(Exception e) {
            AuraHandledException aex = new AuraHandledException(e.getMessage());
            aex.setMessage(e.getMessage());
            throw aex;
        }
    }

    @AuraEnabled
    public static Map<String, Object> issueRefund(Id replacementPolicyId, Decimal refundAmt) {
        try {
            if (replacementPolicyId == null) {
                throw new AuraHandledException('Invalid request: Policy ID is null.');
            }
            List<Policy_Information__c> reps = [
                SELECT Id, Agency_Fee__c, Refundable_Balance_Amount__c, Credit_Applied_Amount__c, Replacement_Credit_Status__c, Policy_Status__c, Policy_Bound__c, Lead__c, Lead__r.FirstName, Lead__r.Email 
                FROM Policy_Information__c 
                WHERE Id = :replacementPolicyId 
                FOR UPDATE
            ];
            if (reps.isEmpty()) {
                throw new AuraHandledException('Policy record not found for ID: ' + replacementPolicyId);
            }
            Policy_Information__c rep = reps[0];
            
            List<Financial_Ledger__c> allLeadLedgers = [
                SELECT Id, Type__c, Credit__c, Debit__c, Balance__c, Date_Time__c, Status__c, Description__c, Reference_Number__c, 
                       Policy_Information__c, Policy_Information__r.Quote__c, Policy_Information__r.Carrier__c, Policy_Information__r.Lines__c, 
                       Policy_Information__r.Lead__c, Policy_Information__r.Original_Policy__c, 
                       Related_Policy__c, Related_Policy__r.Quote__c, Related_Policy__r.Carrier__c, Related_Policy__r.Lines__c 
                FROM Financial_Ledger__c 
                WHERE Policy_Information__r.Lead__c = :rep.Lead__c 
                  AND Type__c IN ('Credit Created', 'Refund Issued', 'Credit Applied', 'Void')
                FOR UPDATE
            ];
            
            Decimal targetRefund = refundAmt != null ? refundAmt : 0.00;
            if (targetRefund == 0.00) {
                if (rep.Refundable_Balance_Amount__c != null && rep.Refundable_Balance_Amount__c > 0) {
                    targetRefund = rep.Refundable_Balance_Amount__c;
                } else if (rep.Credit_Applied_Amount__c != null && rep.Credit_Applied_Amount__c > 0) {
                    targetRefund = rep.Credit_Applied_Amount__c;
                } else if (rep.Agency_Fee__c != null && rep.Agency_Fee__c > 0) {
                    targetRefund = rep.Agency_Fee__c;
                }

                if (targetRefund == 0.00) {
                    for (Financial_Ledger__c fl : allLeadLedgers) {
                        if (fl.Policy_Information__c == rep.Id && (fl.Type__c == 'Credit Created' || fl.Type__c == 'Payment') && fl.Credit__c != null && fl.Credit__c > 0) {
                            targetRefund = fl.Credit__c;
                            break;
                        }
                    }
                }
            }
            Decimal finalRefundAmt = targetRefund;

            // Cap refund amount strictly to net cash collected on Lead minus refunds already issued
            Decimal totalCashCollectedOnLead = 0.00;
            if (rep.Lead__c != null) {
                List<Financial_Ledger__c> leadCashLedgers = [
                    SELECT Credit__c, Policy_Information__r.Agency_Fee__c, Policy_Information__r.Credit_Applied_Amount__c 
                    FROM Financial_Ledger__c 
                    WHERE Policy_Information__r.Lead__c = :rep.Lead__c AND Type__c = 'Payment'
                ];
                for (Financial_Ledger__c fl : leadCashLedgers) {
                    if (fl.Credit__c != null && fl.Credit__c > 0) {
                        totalCashCollectedOnLead += fl.Credit__c;
                    }
                }
                if (totalCashCollectedOnLead == 0.00) {
                    List<Agency_Fee_Invoice__c> allPaidInvoicesOnLead = [
                        SELECT Id, Policy_Information__r.Agency_Fee__c, Policy_Information__r.Credit_Applied_Amount__c 
                        FROM Agency_Fee_Invoice__c 
                        WHERE Policy_Information__r.Lead__c = :rep.Lead__c AND Status__c = 'Paid'
                    ];
                    for (Agency_Fee_Invoice__c inv : allPaidInvoicesOnLead) {
                        Decimal fee = inv.Policy_Information__r != null && inv.Policy_Information__r.Agency_Fee__c != null ? inv.Policy_Information__r.Agency_Fee__c : 0.00;
                        Decimal creditApp = inv.Policy_Information__r != null && inv.Policy_Information__r.Credit_Applied_Amount__c != null ? inv.Policy_Information__r.Credit_Applied_Amount__c : 0.00;
                        totalCashCollectedOnLead += Math.max(0, fee - creditApp);
                    }
                }
            }
            Decimal totalRefundsIssuedOnLead = 0.00;
            if (rep.Lead__c != null) {
                List<Financial_Ledger__c> leadRefundLedgers = [
                    SELECT Debit__c 
                    FROM Financial_Ledger__c 
                    WHERE Policy_Information__r.Lead__c = :rep.Lead__c AND Type__c = 'Refund Issued'
                ];
                for (Financial_Ledger__c fl : leadRefundLedgers) {
                    if (fl.Debit__c != null) totalRefundsIssuedOnLead += fl.Debit__c;
                }
            }
            Decimal maxRefundableCash = Math.max(0.00, totalCashCollectedOnLead - totalRefundsIssuedOnLead);
            if (finalRefundAmt > maxRefundableCash) {
                finalRefundAmt = maxRefundableCash;
            }
            
            if (rep.Replacement_Credit_Status__c == 'Refunded') {
                AuraHandledException aex = new AuraHandledException('Refund has already been issued.');
                aex.setMessage('Refund has already been issued.');
                throw aex;
            }
            
            if (finalRefundAmt == null || finalRefundAmt <= 0) {
                AuraHandledException aex = new AuraHandledException('No available credit remaining to refund.');
                aex.setMessage('No available credit remaining to refund.');
                throw aex;
            }
            
            // Do not clear Refundable_Balance_Amount__c because we no longer use it for global balance.
            rep.Replacement_Credit_Status__c = 'Refunded';
            rep.Refundable_Balance_Amount__c = finalRefundAmt;
            update rep;
            
            Financial_Ledger__c refundIssued = new Financial_Ledger__c();
            refundIssued.Policy_Information__c = rep.Id;
            refundIssued.Type__c = 'Refund Issued';
            refundIssued.Debit__c = finalRefundAmt; 
            refundIssued.Date_Time__c = DateTime.now();
            refundIssued.Status__c = 'Refund Issued';
            insert refundIssued;
            
            // Synchronize all replacement policies under the same Lead
            if (rep.Lead__c != null) {
                List<Policy_Information__c> allRepPolicies = [
                    SELECT Id, Available_Credit_Amount__c, Refundable_Balance_Amount__c 
                    FROM Policy_Information__c 
                    WHERE Lead__c = :rep.Lead__c AND Is_Replacement__c = true
                ];
                for (Policy_Information__c rp : allRepPolicies) {
                    // rp.Available_Credit_Amount__c = 0.00;
                    // rp.Refundable_Balance_Amount__c = 0.00;
                }
                update allRepPolicies;
            }
            
            // Call QBO Refund API asynchronously to avoid uncommitted work pending callout error
            if (rep.Lead__c != null) {
                QBO_InvoiceController.createQBORefundFuture(rep.Lead__c, finalRefundAmt);
            }
            
            Decimal remainingCash = maxRefundableCash - finalRefundAmt;
            // Removed 'Account Settled' ledger insertion because Type__c is a restricted picklist and the 0-balance is calculated dynamically.

            // --- Send Refund Confirmation Email ---
            if (rep.Lead__c != null && rep.Lead__r.Email != null) {
                OrgWideEmailAddress[] owea = [SELECT Id FROM OrgWideEmailAddress WHERE Address = 'it@myriskpros.com' LIMIT 1];
                
                Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
                mail.setTargetObjectId(rep.Lead__c);
                if (!owea.isEmpty()) {
                    mail.setOrgWideEmailAddressId(owea[0].Id);
                }
                mail.setSaveAsActivity(true);
                mail.setSubject('Risk Pros Insurance - Refund Confirmation');
                String htmlBody = '<div style="font-family: Arial, sans-serif; font-size: 14px; color: #000000;">' +
                    '<p>Hi ' + (rep.Lead__r.FirstName != null ? rep.Lead__r.FirstName : 'Client') + ',</p>' +
                    '<p>We are writing to confirm that a refund has been initiated for the applicable agency service fee.</p>' +
                    '<p>Refund Amount: <strong>$' + finalRefundAmt.setScale(2) + '</strong></p>' +
                    '<p>The refund will be issued back to the original payment method, when available, within approximately 7-10 business days.</p>' +
                    '<p>Processing times may vary depending on the payment provider or financial institution.</p>' +
                    '<p>Thank you,<br/><strong>Risk Pros Insurance</strong></p>' +
                    '<div style="margin-top: 30px; border-top: 1px solid #e2e8f0; padding-top: 20px; font-size: 12px; color: #475569;">' +
                    '<p style="font-weight: bold; color: #1e293b; margin-bottom: 12px;">If you have any questions, please contact your Risk Pros Insurance representative.</p>' +
                    '<table width="100%" cellpadding="0" cellspacing="0" border="0" style="font-size: 11px;"><tr>' +
                    '<td style="width: 25%;"><strong>Office:</strong><br/>(614) 647-9644</td>' +
                    '<td style="width: 25%;"><strong>Fax:</strong><br/>(614) 349-1581</td>' +
                    '<td style="width: 25%;"><strong>Email:</strong><br/>it@myriskpros.com</td>' +
                    '<td style="width: 25%;"><strong>Website:</strong><br/>myriskpros.com</td>' +
                    '</tr></table>' +
                    '</div>' +
                    '</div>';
                mail.setHtmlBody(htmlBody);
                try {
                    Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
                } catch (Exception emailEx) {
                    System.debug('Could not send refund confirmation email: ' + emailEx.getMessage());
                }
            }
            // --------------------------------------
            
            Map<String, Object> result = new Map<String, Object>();
            result.put('status', 'success');
            result.put('refundIssued', refundAmt);
            return result;
            
        } catch(Exception e) {
            AuraHandledException auraEx = new AuraHandledException(e.getMessage());
            auraEx.setMessage(e.getMessage());
            throw auraEx;
        }
    }
    @AuraEnabled
    public static void sendProposalUpdateEmail(Id leadId) {
        if (leadId == null) {
            throw new AuraHandledException('Lead ID is missing.');
        }

        Lead l = [SELECT Email FROM Lead WHERE Id = :leadId LIMIT 1];
        if (String.isBlank(l.Email) || !Pattern.matches('^[a-zA-Z0-9._|\\\\%#~`=?&/$^*!}{+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,4}$', l.Email)) {
            throw new AuraHandledException('A valid email address is required to send the email. Please update the Lead record.');
        }

        try {
            // 1. Fetch Email Template
            List<EmailTemplate> templates = [SELECT Id FROM EmailTemplate WHERE DeveloperName = 'Proposal_Summary' LIMIT 1];
            if (templates.isEmpty()) {
                System.debug('Email template "Proposal_Summary" not found.');
                throw new AuraHandledException('Email template "Proposal_Summary" not found.');
            }
            
            // 2. Fetch Org-Wide Email Address
            List<OrgWideEmailAddress> owea = [SELECT Id FROM OrgWideEmailAddress WHERE Address = 'it@myriskpros.com' LIMIT 1];
            if (owea.isEmpty()) {
                throw new AuraHandledException('Verified Org-Wide Email Address not found or not accessible.');
            }

            // 3. Generate PDF from Visualforce Page
            PageReference pdfPage = Page.ProposalSummaryPDF;
            pdfPage.getParameters().put('id', leadId);
            pdfPage.getParameters().put('isUpdate', 'true');
            
            Blob pdfBlob;
            if (Test.isRunningTest()) {
                pdfBlob = Blob.valueOf('Test PDF');
            } else {
                pdfBlob = pdfPage.getContentAsPDF();
            }

            // 4. Create Attachment
            Messaging.EmailFileAttachment efa = new Messaging.EmailFileAttachment();
            efa.setFileName('Proposal_Summary.pdf');
            efa.setBody(pdfBlob);
            efa.setContentType('application/pdf');

            // 5. Construct Email
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setTargetObjectId(leadId); // Populates {!Lead.FirstName} / {!Lead.Name}
            mail.setTemplateId(templates[0].Id);
            mail.setOrgWideEmailAddressId(owea[0].Id);
            mail.setSaveAsActivity(true); // Record email activity
            mail.setFileAttachments(new Messaging.EmailFileAttachment[] { efa });

            // 6. Send Email
            Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
            
        } catch (Exception e) {
            throw new AuraHandledException('Failed to send Proposal Update email: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static void sendMergedProposalUpdateEmail(Id leadId, Id contentDocumentId) {
        if (leadId == null || contentDocumentId == null) {
            throw new AuraHandledException('Lead ID or ContentDocumentId is missing.');
        }

        Lead l = [SELECT Email FROM Lead WHERE Id = :leadId LIMIT 1];
        if (String.isBlank(l.Email) || !Pattern.matches('^[a-zA-Z0-9._|\\\\%#~`=?&/$^*!}{+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,4}$', l.Email)) {
            throw new AuraHandledException('A valid email address is required to send the email. Please update the Lead record.');
        }

        try {
            // 1. Fetch Email Template
            List<EmailTemplate> templates = [SELECT Id FROM EmailTemplate WHERE DeveloperName = 'Proposal_Update' LIMIT 1];
            if (templates.isEmpty()) {
                throw new AuraHandledException('Email template "Proposal_Update" not found.');
            }
            
            // 2. Fetch Org-Wide Email Address
            List<OrgWideEmailAddress> owea = [SELECT Id FROM OrgWideEmailAddress WHERE Address = 'it@myriskpros.com' LIMIT 1];
            if (owea.isEmpty()) {
                throw new AuraHandledException('Verified Org-Wide Email Address not found or not accessible.');
            }

            // 3. Query ContentVersion for the given ContentDocumentId
            ContentVersion cv = [SELECT Title, PathOnClient, VersionData FROM ContentVersion WHERE ContentDocumentId = :contentDocumentId AND IsLatest = true LIMIT 1];

            // 4. Create Attachment
            Messaging.EmailFileAttachment efa = new Messaging.EmailFileAttachment();
            efa.setFileName(cv.Title + '.pdf'); 
            efa.setBody(cv.VersionData);
            efa.setContentType('application/pdf');

            // 5. Construct Email
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setTargetObjectId(leadId); // Populates {!Lead.FirstName} / {!Lead.Name}
            mail.setTemplateId(templates[0].Id);
            mail.setOrgWideEmailAddressId(owea[0].Id);
            mail.setSaveAsActivity(true); // Record email activity
            mail.setFileAttachments(new Messaging.EmailFileAttachment[] { efa });

            // 6. Send Email
            Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
            
        } catch (Exception e) {
            throw new AuraHandledException('Failed to send merged Proposal Update email: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static void generateProposalSummaryFile(Id recordId) {
        if (recordId == null) throw new AuraHandledException('Record ID is missing.');
        try {
            PageReference pdfPage = Page.ProposalSummaryPDF;
            pdfPage.getParameters().put('id', recordId);
            pdfPage.getParameters().put('isUpdate', 'false');
            
            Blob pdfBlob;
            if (Test.isRunningTest()) {
                pdfBlob = Blob.valueOf('Test PDF');
            } else {
                pdfBlob = pdfPage.getContentAsPDF();
            }

            ContentVersion cv = new ContentVersion();
            cv.Title = 'Proposal Summary';
            cv.PathOnClient = 'Proposal_Summary.pdf';
            cv.VersionData = pdfBlob;
            cv.Type__c = 'Proposal'; // Fixed to use valid picklist value 'Proposal' instead of 'Proposal Summary'
            insert cv;

            Id conDocId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id =:cv.Id].ContentDocumentId;

            ContentDocumentLink cdl = new ContentDocumentLink();
            cdl.LinkedEntityId = recordId;
            cdl.ContentDocumentId = conDocId;
            cdl.ShareType = 'I';
            cdl.Visibility = 'AllUsers';
            insert cdl;

        } catch (Exception e) {
            throw new AuraHandledException('Failed to generate Proposal Summary: ' + e.getMessage());
        }
    }

    // ---------------------------------------------------------------------------
    // voidInvoice — called when a quote is abandoned with Policy Bound = No
    // and no replacement quote. Handles two sub-cases:
    //   1. Invoice NOT paid   → mark as Void in SF + QBO, insert Invoice Void ledger
    //   2. Invoice already PAID → return 'refund_required' so UI shows Issue Refund
    // ---------------------------------------------------------------------------
 
    @AuraEnabled
    public static Map<String, Object> voidInvoice(Id policyId) {
        try {
            if (policyId == null) {
                throw new AuraHandledException('voidInvoice: policyId is required.');
            }

            // Added subquery for Financial_Ledgers__r to check for previous payments
            Policy_Information__c pol = [
                SELECT Id, Agency_Fee__c, Lead__c,Policy_Status__c,
                       (SELECT Id, Status__c, QuickBooks_Invoice_ID__c
                        FROM Agency_Fee_Invoices__r
                        ORDER BY CreatedDate DESC LIMIT 1),
                       (SELECT Id, Type__c, Credit__c, Debit__c, Balance__c, Date_Time__c, Status__c, Description__c, Reference_Number__c, Policy_Information__c, Policy_Information__r.Quote__c, Policy_Information__r.Carrier__c, Policy_Information__r.Lines__c, Policy_Information__r.Lead__c, Policy_Information__r.Original_Policy__c, Related_Policy__c, Related_Policy__r.Quote__c, Related_Policy__r.Carrier__c, Related_Policy__r.Lines__c FROM Financial_Ledgers__r ORDER BY Date_Time__c ASC)
                FROM Policy_Information__c
                WHERE Id = :policyId
                LIMIT 1
            ];

            Decimal feeAmt = pol.Agency_Fee__c != null ? pol.Agency_Fee__c : 0.00;
            Boolean invoiceExists = pol.Agency_Fee_Invoices__r != null && !pol.Agency_Fee_Invoices__r.isEmpty();
            String currentStatus  = invoiceExists ? pol.Agency_Fee_Invoices__r[0].Status__c : null;
            String qboInvoiceId   = invoiceExists ? pol.Agency_Fee_Invoices__r[0].QuickBooks_Invoice_ID__c : null;

            Map<String, Object> result = new Map<String, Object>();

            // ── Guard: Already voided ────────────────────────────────────────────
            // Idempotency: if a void ledger entry already exists, skip silently.
            List<Financial_Ledger__c> existingVoid = [
                SELECT Id FROM Financial_Ledger__c
                WHERE Policy_Information__c = :policyId
                  AND Type__c = 'Void'
                LIMIT 1
            ];
            
            if (!existingVoid.isEmpty()) {
                result.put('status', 'success');
                result.put('voidedAmount', feeAmt);
                result.put('message', 'Already voided.');
                return result;
            }

            // ── Step 1: Check if the policy was actually paid before voiding ─────
            Boolean wasPaid = false;
            Decimal directCash = 0.00;
            Boolean hasExistingCreditCreated = false;

            if (currentStatus == 'Paid') {
                wasPaid = true;
            }
            if (pol.Financial_Ledgers__r != null) {
                for (Financial_Ledger__c fl : pol.Financial_Ledgers__r) {
                    if (fl.Type__c == 'Payment' || fl.Type__c == 'Credit Applied') {
                        wasPaid = true;
                    }
                    if (fl.Type__c == 'Payment' && fl.Credit__c != null) {
                        directCash += fl.Credit__c;
                    }
                    if (fl.Type__c == 'Credit Created') {
                        hasExistingCreditCreated = true;
                    }
                }
            }

            // ── Revert applied credits by inserting Credit Debited ledgers ──
            // REMOVED: We no longer revert credits to the global pool here. 
            // The credit remains on this quote so it can be refunded directly.

            pol.Credit_Applied_Amount__c = 0;
            pol.Replacement_Credit_Status__c = null;
            pol.Available_Credit_Amount__c = 0;
            pol.Refundable_Balance_Amount__c = 0;

            // ── Step 2: Mark invoice Void in Salesforce & QBO ONLY IF NO CASH PAID ─────
            if (invoiceExists && currentStatus != 'Void' && directCash == 0) {
                Agency_Fee_Invoice__c inv = pol.Agency_Fee_Invoices__r[0];
                inv.Status__c = 'Void';
                update inv;

                // Void in QuickBooks (async — cannot callout after DML)
                if (String.isNotBlank(qboInvoiceId)) {
                    QBO_InvoiceController.voidQBOInvoiceFuture(qboInvoiceId);
                }
            }

            // ── Step 3: If cash was paid, convert it to Credit Created so it enters the pool ─────
            // We no longer manually convert cash to Credit Created here.
            // The original Payment ledger remains the cash source for the credit pool.
            
            result.put('status', 'success');
            result.put('voidedAmount', feeAmt);

            update pol;

            // Insert a Void Financial Ledger entry to document quote abandonment in Payment Ledger table
            Financial_Ledger__c voidLedger = new Financial_Ledger__c();
            voidLedger.Policy_Information__c = pol.Id;
            voidLedger.Type__c = 'Void';
            voidLedger.Status__c = 'Void';
            voidLedger.Debit__c = 0.00;
            voidLedger.Credit__c = 0.00;
            voidLedger.Date_Time__c = DateTime.now();
            voidLedger.Description__c = 'Invoice voided due to policy abandonment / policy bound = no';
            insert voidLedger;

            result.put('status', 'success');
            result.put('voidedAmount', feeAmt);
            return result;

        } catch (Exception e) {
            throw new AuraHandledException('voidInvoice failed: ' + e.getMessage());
        }
    }

    private class LeadCreditComputation {
        Decimal globalAvailableCredit = 0.00;
        Decimal globalOutstandingAmount = 0.00;
        Decimal globalNetRefundOwed = 0.00;
        Map<Id, Decimal> policyToCreditApplied = new Map<Id, Decimal>();
        Map<Id, Decimal> policyToRefundIssued = new Map<Id, Decimal>();
        Map<Id, Decimal> policyToCreditDebited = new Map<Id, Decimal>();
        Set<Id> policiesWithDirectPayment = new Set<Id>();
    }

    private static Map<Id, Decimal> getDedupedCashInByPolicy(List<Financial_Ledger__c> ledgers) {
        Map<Id, Decimal> paymentByPolicy = new Map<Id, Decimal>();
        Map<Id, Decimal> creditCreatedByPolicy = new Map<Id, Decimal>();
        Map<Id, Decimal> voidByPolicy = new Map<Id, Decimal>();
        Map<Id, Decimal> creditAppliedInByPolicy = new Map<Id, Decimal>();
        Map<Id, Decimal> creditAppliedOutByPolicy = new Map<Id, Decimal>();

        if (ledgers == null) {
            return new Map<Id, Decimal>();
        }

        for (Financial_Ledger__c fl : ledgers) {
            if (fl.Policy_Information__c == null) {
                continue;
            }
            if (fl.Type__c == 'Payment' && fl.Credit__c != null && fl.Credit__c > 0) {
                addLedgerAmount(paymentByPolicy, fl.Policy_Information__c, fl.Credit__c);
            } else if (fl.Type__c == 'Credit Created' && fl.Credit__c != null && fl.Credit__c > 0) {
                addLedgerAmount(creditCreatedByPolicy, fl.Policy_Information__c, fl.Credit__c);
            } else if (fl.Type__c == 'Void' && fl.Credit__c != null && fl.Credit__c > 0) {
                addLedgerAmount(voidByPolicy, fl.Policy_Information__c, fl.Credit__c);
            } else if (fl.Type__c == 'Credit Applied' || fl.Type__c == 'Credit Debited') {
                if (fl.Credit__c != null && fl.Credit__c > 0) {
                    addLedgerAmount(creditAppliedInByPolicy, fl.Policy_Information__c, fl.Credit__c);
                }
                if (fl.Debit__c != null && fl.Debit__c > 0) {
                    addLedgerAmount(creditAppliedOutByPolicy, fl.Policy_Information__c, fl.Debit__c);
                }
            }
        }

        Set<Id> allPolicyIds = new Set<Id>();
        allPolicyIds.addAll(paymentByPolicy.keySet());
        allPolicyIds.addAll(creditCreatedByPolicy.keySet());
        allPolicyIds.addAll(voidByPolicy.keySet());
        allPolicyIds.addAll(creditAppliedInByPolicy.keySet());
        allPolicyIds.addAll(creditAppliedOutByPolicy.keySet());

        Map<Id, Decimal> result = new Map<Id, Decimal>();
        for (Id pid : allPolicyIds) {
            Decimal payment = paymentByPolicy.containsKey(pid) ? paymentByPolicy.get(pid) : 0.00;
            Decimal created = creditCreatedByPolicy.containsKey(pid) ? creditCreatedByPolicy.get(pid) : 0.00;
            Decimal voidAmt = voidByPolicy.containsKey(pid) ? voidByPolicy.get(pid) : 0.00;
            Decimal creditIn = creditAppliedInByPolicy.containsKey(pid) ? creditAppliedInByPolicy.get(pid) : 0.00;
            Decimal creditOut = creditAppliedOutByPolicy.containsKey(pid) ? creditAppliedOutByPolicy.get(pid) : 0.00;
            
            Decimal cashIn = payment > 0 ? payment : created;
            cashIn += voidAmt;
            
            if (cashIn > 0) {
                result.put(pid, cashIn);
            }
        }
        return result;
    }

    private static void addLedgerAmount(Map<Id, Decimal> amounts, Id policyId, Decimal value) {
        Decimal current = amounts.containsKey(policyId) ? amounts.get(policyId) : 0.00;
        amounts.put(policyId, current + value);
    }

    private static Boolean policyPaidByCreditOnly(Id policyId, List<Financial_Ledger__c> ledgers) {
        if (ledgers == null) {
            return false;
        }
        for (Financial_Ledger__c fl : ledgers) {
            if (fl.Policy_Information__c == policyId
                && fl.Type__c == 'Credit Applied'
                && fl.Credit__c != null
                && fl.Credit__c > 0) {
                return true;
            }
        }
        return false;
    }

    private static Map<Id, List<Policy_Information__c>> buildReplacementChainMap(List<Policy_Information__c> policies) {
        Map<Id, Policy_Information__c> polMap = new Map<Id, Policy_Information__c>(policies);
        Map<Id, List<Policy_Information__c>> chainMap = new Map<Id, List<Policy_Information__c>>();

        for (Policy_Information__c pol : policies) {
            Policy_Information__c root = pol;
            Set<Id> visited = new Set<Id>{ root.Id };
            while (root.Original_Policy__c != null && polMap.containsKey(root.Original_Policy__c) && !visited.contains(root.Original_Policy__c)) {
                root = polMap.get(root.Original_Policy__c);
                visited.add(root.Id);
            }
            if (!chainMap.containsKey(root.Id)) {
                chainMap.put(root.Id, new List<Policy_Information__c>());
            }
            chainMap.get(root.Id).add(pol);
        }
        return chainMap;
    }

    private static LeadCreditComputation computeLeadCreditFromLedgers(List<Policy_Information__c> policies, List<Financial_Ledger__c> ledgers) {
        LeadCreditComputation result = new LeadCreditComputation();
        if (policies == null || policies.isEmpty()) {
            return result;
        }

        Map<Id, Decimal> dedupedCashIn = getDedupedCashInByPolicy(ledgers);
        Map<Id, Policy_Information__c> polMap = new Map<Id, Policy_Information__c>(policies);
        Map<Id, List<Policy_Information__c>> chainMap = buildReplacementChainMap(policies);

        for (Policy_Information__c pol : policies) {
            result.policyToCreditApplied.put(pol.Id, 0.00);
            result.policyToRefundIssued.put(pol.Id, 0.00);
            result.policyToCreditDebited.put(pol.Id, 0.00);
        }

        if (ledgers != null) {
            for (Financial_Ledger__c fl : ledgers) {
                if (fl.Policy_Information__c == null) {
                    continue;
                }
                if ((fl.Type__c == 'Payment' || fl.Type__c == 'Credit Created') && fl.Credit__c != null && fl.Credit__c > 0) {
                    result.policiesWithDirectPayment.add(fl.Policy_Information__c);
                }
                if (!result.policyToCreditApplied.containsKey(fl.Policy_Information__c)) {
                    continue;
                }
                if (fl.Type__c == 'Credit Applied' && fl.Credit__c != null && fl.Credit__c > 0) {
                    addLedgerAmount(result.policyToCreditApplied, fl.Policy_Information__c, fl.Credit__c);
                }
                if ((fl.Type__c == 'Credit Applied' || fl.Type__c == 'Credit Debited') && fl.Debit__c != null && fl.Debit__c > 0) {
                    addLedgerAmount(result.policyToCreditDebited, fl.Policy_Information__c, fl.Debit__c);
                }
                if (fl.Type__c == 'Refund Issued' && fl.Debit__c != null && fl.Debit__c > 0) {
                    addLedgerAmount(result.policyToRefundIssued, fl.Policy_Information__c, fl.Debit__c);
                }
            }
        }

        Decimal globalNetCashIn = 0.00;
        Decimal globalActiveCashConsumed = 0.00;
        Decimal globalActiveCreditConsumed = 0.00;
        
        Map<Id, Decimal> chainNetCashIn = new Map<Id, Decimal>();
        Map<Id, Decimal> chainActiveCashConsumed = new Map<Id, Decimal>();
        
        Set<Id> replacedParentIds = new Set<Id>();
        for (Policy_Information__c cp : policies) {
            Boolean isAbandoned = cp.Policy_Status__c == 'Rejected' || cp.Policy_Status__c == 'Abandoned' || cp.Policy_Status__c == 'Not Applicable' || cp.Policy_Bound__c == 'No' || cp.Agency_Fee_Waiver_Decision__c == 'Accepted';
            if (cp.Original_Policy__c != null && !isAbandoned) {
                replacedParentIds.add(cp.Original_Policy__c);
            }
        }

        // Pass 0: Compute global pools and chain metrics
        for (Id rootId : chainMap.keySet()) {
            List<Policy_Information__c> chain = chainMap.get(rootId);
            Decimal activeCash = 0.00;
            Decimal activeCredit = 0.00;
            
            Decimal chainGrossCash = 0.00;
            Decimal chainGrossRefund = 0.00;
            
            for (Policy_Information__c cp : chain) {
                Boolean isAbandoned = cp.Policy_Status__c == 'Rejected' || cp.Policy_Status__c == 'Abandoned' || cp.Policy_Status__c == 'Not Applicable' || cp.Policy_Bound__c == 'No' || cp.Agency_Fee_Waiver_Decision__c == 'Accepted';
                Boolean isReplaced = cp.Replacement_Initiated__c == true || replacedParentIds.contains(cp.Id);
                Boolean isActive = !isAbandoned && !isReplaced;
                
                Decimal cashPaid = dedupedCashIn.get(cp.Id) != null ? dedupedCashIn.get(cp.Id) : 0.00;
                Decimal refundIssued = result.policyToRefundIssued.get(cp.Id) != null ? result.policyToRefundIssued.get(cp.Id) : 0.00;
                
                chainGrossCash += cashPaid;
                chainGrossRefund += refundIssued;
                
                Decimal cpNetCash = Math.max(0, cashPaid - refundIssued);
                
                if (isActive) {
                    Decimal fee = cp.Agency_Fee__c != null ? cp.Agency_Fee__c : 0.00;
                    Decimal creditApp = result.policyToCreditApplied.get(cp.Id) != null ? result.policyToCreditApplied.get(cp.Id) : 0.00;
                    Boolean isWaivedQuote = cp.Agency_Fee_Waiver_Decision__c == 'Accepted';
                    Decimal consumedCredit = isWaivedQuote ? creditApp : Math.min(creditApp, fee);
                    activeCredit += consumedCredit;
                    
                    Decimal remainingFee = Math.max(0, fee - consumedCredit);
                    activeCash += Math.min(cpNetCash, remainingFee);
                }
                
                cp.Refundable_Balance_Amount__c = 0.00;
                cp.Available_Credit_Amount__c = 0.00;
            }
            
            Decimal netCashIn = Math.max(0, chainGrossCash - chainGrossRefund);
            
            globalNetCashIn += netCashIn;
            globalActiveCashConsumed += activeCash;
            globalActiveCreditConsumed += activeCredit;
            
            chainNetCashIn.put(rootId, netCashIn);
            chainActiveCashConsumed.put(rootId, activeCash + activeCredit);
        }

        Decimal workingGlobalAvailable = Math.max(0, globalNetCashIn - globalActiveCashConsumed - globalActiveCreditConsumed);
        result.globalAvailableCredit = workingGlobalAvailable;

        Boolean hasLeadPendingQuoteNeedingCredit = false;
        for (Policy_Information__c pol : policies) {
            Boolean isAbandoned = pol.Policy_Status__c == 'Rejected' || pol.Policy_Status__c == 'Abandoned' || pol.Policy_Status__c == 'Not Applicable' || pol.Policy_Bound__c == 'No' || pol.Agency_Fee_Waiver_Decision__c == 'Accepted';
            Boolean isReplaced = pol.Replacement_Initiated__c == true || replacedParentIds.contains(pol.Id);
            Boolean isActive = !isAbandoned && !isReplaced;
            
            Decimal fee = pol.Agency_Fee__c != null ? pol.Agency_Fee__c : 0.00;
            Decimal childLedgerApplied = result.policyToCreditApplied.get(pol.Id) != null ? result.policyToCreditApplied.get(pol.Id) : 0.00;
            Decimal childLedgerRefunded = result.policyToRefundIssued.get(pol.Id) != null ? result.policyToRefundIssued.get(pol.Id) : 0.00;
            Decimal netApplied = Math.max(0, childLedgerApplied - childLedgerRefunded);
            Boolean isPaid = result.policiesWithDirectPayment.contains(pol.Id) || (netApplied > 0 && fee > 0 && netApplied >= fee);
            
            if (isActive && fee > 0 && !isPaid) {
                hasLeadPendingQuoteNeedingCredit = true;
                Decimal remaining = fee - netApplied;
                if (remaining > 0) {
                    result.globalOutstandingAmount += remaining;
                }
            }
        }

        if (!hasLeadPendingQuoteNeedingCredit && workingGlobalAvailable > 0) {
            Map<Id, Decimal> chainPass1Refunds = new Map<Id, Decimal>();
            
            // Pass 1: Removed (Cash ownership transfers inherently now)
            for (Id rootId : chainMap.keySet()) {
                chainPass1Refunds.put(rootId, 0.00);
            }
            
            // Pass 2: Refund Cash Surplus
            Decimal totalClaims = 0.00;
            Map<Id, Decimal> chainPass2Claim = new Map<Id, Decimal>();
            for (Id rootId : chainMap.keySet()) {
                Decimal claim = chainNetCashIn.get(rootId) - chainActiveCashConsumed.get(rootId) - chainPass1Refunds.get(rootId);
                if (claim < 0) claim = 0.00;
                chainPass2Claim.put(rootId, claim);
                totalClaims += claim;
            }
            
            if (totalClaims > 0 && workingGlobalAvailable > 0) {
                Decimal remainingRefund = workingGlobalAvailable;
                for (Id rootId : chainMap.keySet()) {
                    List<Policy_Information__c> chain = chainMap.get(rootId);
                    if (chain != null) {
                        for (Policy_Information__c cp : chain) {
                            Boolean isAbandoned = cp.Policy_Status__c == 'Rejected' || cp.Policy_Status__c == 'Abandoned' || cp.Policy_Status__c == 'Not Applicable' || cp.Policy_Bound__c == 'No' || cp.Agency_Fee_Waiver_Decision__c == 'Accepted';
                            Boolean isReplaced = cp.Replacement_Initiated__c == true || replacedParentIds.contains(cp.Id);
                            Boolean isActive = !isAbandoned && !isReplaced;
                            
                            if (!isActive) {
                                Decimal cashPaid = dedupedCashIn.get(cp.Id) != null ? dedupedCashIn.get(cp.Id) : 0.00;
                                Decimal creditApplied = (result.policyToCreditApplied != null && result.policyToCreditApplied.get(cp.Id) != null) ? result.policyToCreditApplied.get(cp.Id) : 0.00;
                                Decimal creditDebited = (result.policyToCreditDebited != null && result.policyToCreditDebited.get(cp.Id) != null) ? result.policyToCreditDebited.get(cp.Id) : 0.00;
                                Decimal refundIssued = result.policyToRefundIssued.get(cp.Id) != null ? result.policyToRefundIssued.get(cp.Id) : 0.00;
                                
                                Decimal cpNetValue = Math.max(0, Math.max(cashPaid, creditApplied) - creditDebited - refundIssued);
                                Decimal portion = Math.min(remainingRefund, cpNetValue);
                                
                                if (portion > 0) {
                                    cp.Refundable_Balance_Amount__c = (cp.Refundable_Balance_Amount__c != null ? cp.Refundable_Balance_Amount__c : 0.00) + portion;
                                    remainingRefund -= portion;
                                }
                            }
                        }
                    }
                }
            }
        }

        System.debug('📊 [computeLeadCreditFromLedgers] Starting calculation for ' + policies.size() + ' policies.');
        System.debug('💵 [computeLeadCreditFromLedgers] globalNetCashIn=' + globalNetCashIn + ' | globalActiveCashConsumed=' + globalActiveCashConsumed + ' | globalActiveCreditConsumed=' + globalActiveCreditConsumed + ' | workingGlobalAvailable=' + workingGlobalAvailable);

        for (Policy_Information__c pol : policies) {
            Boolean isAbandoned = pol.Policy_Status__c == 'Rejected' || pol.Policy_Status__c == 'Abandoned' || pol.Policy_Status__c == 'Not Applicable' || pol.Policy_Bound__c == 'No' || pol.Agency_Fee_Waiver_Decision__c == 'Accepted';
            Boolean isReplaced = pol.Replacement_Initiated__c == true || replacedParentIds.contains(pol.Id);
            Boolean isActive = !isAbandoned && !isReplaced;
            
            if (isActive) {
                pol.Available_Credit_Amount__c = result.globalAvailableCredit;
            }
            if (pol.Refundable_Balance_Amount__c != null && pol.Refundable_Balance_Amount__c > 0) {
                result.globalNetRefundOwed += pol.Refundable_Balance_Amount__c;
            }
            String quoteLabel = pol.isSet(Policy_Information__c.Quote__c) ? String.valueOf(pol.get('Quote__c')) : String.valueOf(pol.Id);
            System.debug('📋 [Policy Balance Result] Quote ' + quoteLabel + ' (' + pol.Id + '): RefundableBal=' + pol.Refundable_Balance_Amount__c + ' | AvailCredit=' + pol.Available_Credit_Amount__c + ' | CreditApplied=' + pol.Credit_Applied_Amount__c);
        }

        System.debug('✅ [computeLeadCreditFromLedgers Final] globalAvailableCredit=' + result.globalAvailableCredit + ' | globalNetRefundOwed=' + result.globalNetRefundOwed);
        return result;
    }

    private static List<Financial_Ledger__c> ensureLedgersForPaidPolicies(List<Policy_Information__c> policies, Boolean doDml) {
        if (policies == null || policies.isEmpty()) return new List<Financial_Ledger__c>();
        
        Set<Id> policyIds = new Map<Id, Policy_Information__c>(policies).keySet();
        List<Financial_Ledger__c> existingLedgers = [
            SELECT Id, Type__c, Credit__c, Debit__c, Balance__c, Date_Time__c, Status__c, Description__c, Reference_Number__c, 
                   Policy_Information__c, Policy_Information__r.Quote__c, Policy_Information__r.Carrier__c, Policy_Information__r.Lines__c, 
                   Policy_Information__r.Lead__c, Policy_Information__r.Original_Policy__c, 
                   Related_Policy__c, Related_Policy__r.Quote__c, Related_Policy__r.Carrier__c, Related_Policy__r.Lines__c 
            FROM Financial_Ledger__c 
            WHERE Policy_Information__c IN :policyIds
        ];
        
        Set<Id> policiesWithCreatedLedger = new Set<Id>();
        Set<Id> policiesWithPaymentLedger = new Set<Id>();
        Set<Id> policiesPaidByCreditOnly = new Set<Id>();
        List<Financial_Ledger__c> ledgersToDelete = new List<Financial_Ledger__c>();
        List<Financial_Ledger__c> deduplicatedLedgers = new List<Financial_Ledger__c>();

        for (Financial_Ledger__c fl : existingLedgers) {
            if (fl.Type__c == 'Payment') {
                policiesWithPaymentLedger.add(fl.Policy_Information__c);
            }
        }

        for (Financial_Ledger__c fl : existingLedgers) {
            if (fl.Type__c == 'Payment') {
                deduplicatedLedgers.add(fl);
            } else if (fl.Type__c == 'Credit Created') {
                if (policiesWithPaymentLedger.contains(fl.Policy_Information__c)) {
                    ledgersToDelete.add(fl);
                } else if (policiesWithCreatedLedger.contains(fl.Policy_Information__c)) {
                    ledgersToDelete.add(fl);
                } else {
                    policiesWithCreatedLedger.add(fl.Policy_Information__c);
                    deduplicatedLedgers.add(fl);
                }
            } else {
                if (fl.Type__c == 'Credit Applied' && fl.Credit__c != null && fl.Credit__c > 0) {
                    policiesPaidByCreditOnly.add(fl.Policy_Information__c);
                }
                deduplicatedLedgers.add(fl);
            }
        }

        if (doDml && !ledgersToDelete.isEmpty()) {
            delete ledgersToDelete;
            existingLedgers = deduplicatedLedgers;
        } else if (!ledgersToDelete.isEmpty()) {
            existingLedgers = deduplicatedLedgers;
        }
        
        List<Financial_Ledger__c> newlyCreatedLedgers = new List<Financial_Ledger__c>();
        for (Policy_Information__c pol : policies) {
            Boolean isPaid = (pol.Agency_Fee_Invoices__r != null && !pol.Agency_Fee_Invoices__r.isEmpty() && pol.Agency_Fee_Invoices__r[0].Status__c == 'Paid');
            Decimal fee = pol.Agency_Fee__c != null ? pol.Agency_Fee__c : 0.00;
            Boolean hasPaymentLedger = policiesWithPaymentLedger.contains(pol.Id);
            Boolean hasCreatedLedger = policiesWithCreatedLedger.contains(pol.Id);
            Boolean paidByCreditOnly = policiesPaidByCreditOnly.contains(pol.Id);

            // Only backfill Credit Created for real cash payments without an existing cash-in ledger row.
            if (isPaid && fee > 0 && !hasCreatedLedger && !hasPaymentLedger && !paidByCreditOnly) {
                Financial_Ledger__c creditCreated = new Financial_Ledger__c();
                creditCreated.Policy_Information__c = pol.Id;
                creditCreated.Type__c = 'Credit Created';
                creditCreated.Credit__c = fee;
                creditCreated.Date_Time__c = DateTime.now();
                creditCreated.Status__c = 'Credit Available';
                creditCreated.Description__c = 'Auto-created ledger entry for paid policy fee';
                newlyCreatedLedgers.add(creditCreated);
            }
        }
        
        if (!newlyCreatedLedgers.isEmpty()) {
            if (doDml) {
                insert newlyCreatedLedgers;
            }
            existingLedgers.addAll(newlyCreatedLedgers);
        }
        
        return existingLedgers;
    }

    public static String formatLedgerRefNo(String type, String rawRef) {
        if (String.isBlank(rawRef) || rawRef == '-') return '-';
        String cleanRef = rawRef.trim();
        if (type == 'Invoice') {
            if (!cleanRef.startsWithIgnoreCase('INV-')) {
                return 'INV-' + cleanRef;
            }
        } else if (type == 'Payment') {
            if (!cleanRef.startsWithIgnoreCase('PMT-')) {
                return 'PMT-' + cleanRef;
            }
        } else if (type == 'Refund Issued' || type == 'Refund') {
            if (!cleanRef.startsWithIgnoreCase('RF-')) {
                return 'RF-' + cleanRef;
            }
        } else if (type != null && type.contains('Credit')) {
            if (!cleanRef.startsWithIgnoreCase('CR-')) {
                return 'CR-' + cleanRef;
            }
        }
        return cleanRef;
    }
}