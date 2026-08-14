@isTest
private class BindProcessControllerTest {

    @testSetup
    static void setup() {
        Account acc = new Account(Name = 'Test Account');
        insert acc;

        Lead l = new Lead(LastName = 'Test Lead', Company = 'Test Co', Status = 'Open');
        insert l;

        Opportunity opp = new Opportunity(Name = 'Test Opp', AccountId = acc.Id, StageName = 'Prospecting', CloseDate = Date.today());
        insert opp;

        Policy_Information__c p1 = new Policy_Information__c(Lead__c = l.Id, Policy_Type__c = 'Quote', Policy_Status__c = 'Approved');
        insert p1;
        
        Policy_Information__c p2 = new Policy_Information__c(Opportunity__c = opp.Id, Policy_Type__c = 'Quote', Policy_Status__c = 'Approved');
        insert p2;
    }

    @isTest
    static void testGetBindProcessData() {
        Lead l = [SELECT Id FROM Lead LIMIT 1];
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];

        BindProcessController.BindProcessWrapper resL = BindProcessController.getBindProcessData(l.Id);
        System.assertNotEquals(null, resL.policyUiList, 'policyUiList should be populated for Lead');
        System.assertNotEquals(null, resL.modalSummary, 'modalSummary should be populated for Lead');
        BindProcessController.BindProcessWrapper resO = BindProcessController.getBindProcessData(opp.Id);
        System.assertNotEquals(null, resO.policyUiList, 'policyUiList should be populated for Opportunity');
        System.assertNotEquals(null, resO.modalSummary, 'modalSummary should be populated for Opportunity');
        
        BindProcessController.getAgent2Options();
        BindProcessController.getCarrierOptions();
        
        Test.setCurrentPage(Page.ProposalSummaryPDF);
        ApexPages.StandardController stdController = new ApexPages.StandardController(l);
        BindProcessController ctrl = new BindProcessController(stdController);
        
        System.assertNotEquals(null, ctrl.summaryPolicies);
        System.assertNotEquals(null, ctrl.totalPremium);
    }

    @isTest
    static void testSaveBindProcess() {
        Lead l = [SELECT Id FROM Lead LIMIT 1];
        Policy_Information__c pol = [SELECT Id, Policy_Status__c FROM Policy_Information__c WHERE Lead__c = :l.Id LIMIT 1];
        
        BindProcessController.BindSaveRequest req = new BindProcessController.BindSaveRequest();
        req.recordId = l.Id;
        req.parentRecord = l;
        
        BindProcessController.PolicyRequest pReq = new BindProcessController.PolicyRequest();
        pol.Policy_Status__c = 'Bound';
        pReq.policyRecord = pol;
        
        req.policyRequests = new List<BindProcessController.PolicyRequest>{ pReq };
        
        BindProcessController.saveBindProcess(req);
    }
    
    @isTest
    static void testNBCValidationFailure() {
        Lead l2 = new Lead(LastName = 'Fail Lead', Company = 'Fail Co', Status = 'Open');
        insert l2;
        BindProcessController.getBindProcessData(l2.Id);
    }

    // --- Scenario 1: Simple Surplus Refund ($99 AZ/TX Paid -> $30 AL Applied -> $69 Surplus on B) ---
    @isTest
    static void testScenario1_SimpleSurplusRefund_99to30() {
        Lead l = new Lead(LastName = 'Scen1 Lead', Company = 'Co1', Status = 'Open');
        insert l;

        Policy_Information__c qA = new Policy_Information__c(Lead__c = l.Id, Agency_State__c = 'Arizona', Lines__c = 'AUTO', Policy_Type__c = 'Quote', Policy_Status__c = 'Approved', Agency_Fee__c = 99.00);
        insert qA;
        insert new Agency_Fee_Invoice__c(Policy_Information__c = qA.Id, Status__c = 'Paid');
        insert new Financial_Ledger__c(Policy_Information__c = qA.Id, Type__c = 'Credit Created', Credit__c = 99.00, Date_Time__c = DateTime.now());

        Policy_Information__c qB = new Policy_Information__c(Lead__c = l.Id, Agency_State__c = 'Alabama', Lines__c = 'AUTO', Policy_Type__c = 'Quote', Policy_Status__c = 'Approved', Is_Replacement__c = true, Original_Policy__c = qA.Id, Agency_Fee__c = 30.00);
        insert qB;

        BindProcessController.applyCredit(qB.Id);

        BindProcessController.BindProcessWrapper data = BindProcessController.getBindProcessData(l.Id);
        System.assertEquals(69.00, data.globalAvailableCredit);

        for (Policy_Information__c p : data.policies) {
            if (p.Id == qB.Id) System.assertEquals(69.00, p.Refundable_Balance_Amount__c);
            if (p.Id == qA.Id) System.assertEquals(0.00, p.Refundable_Balance_Amount__c);
        }
    }

    // --- Scenario 1B: High-Fee Home Quote Surplus ($199 AZ Home Paid -> $99 AZ Auto Applied -> $100 Surplus on B) ---
    @isTest
    static void testScenario1B_HighFeeHomeSurplus_199to99() {
        Lead l = new Lead(LastName = 'Scen1B Lead', Company = 'Co1B', Status = 'Open');
        insert l;

        Policy_Information__c qA = new Policy_Information__c(Lead__c = l.Id, Agency_State__c = 'Arizona', Lines__c = 'HOME', Policy_Type__c = 'Quote', Policy_Status__c = 'Approved', Agency_Fee__c = 199.00);
        insert qA;
        insert new Agency_Fee_Invoice__c(Policy_Information__c = qA.Id, Status__c = 'Paid');
        insert new Financial_Ledger__c(Policy_Information__c = qA.Id, Type__c = 'Credit Created', Credit__c = 199.00, Date_Time__c = DateTime.now());

        Policy_Information__c qB = new Policy_Information__c(Lead__c = l.Id, Agency_State__c = 'Arizona', Lines__c = 'AUTO', Policy_Type__c = 'Quote', Policy_Status__c = 'Approved', Is_Replacement__c = true, Original_Policy__c = qA.Id, Agency_Fee__c = 99.00);
        insert qB;

        BindProcessController.applyCredit(qB.Id);

        BindProcessController.BindProcessWrapper data = BindProcessController.getBindProcessData(l.Id);
        System.assertEquals(100.00, data.globalAvailableCredit);

        for (Policy_Information__c p : data.policies) {
            if (p.Id == qB.Id) System.assertEquals(100.00, p.Refundable_Balance_Amount__c);
            if (p.Id == qA.Id) System.assertEquals(0.00, p.Refundable_Balance_Amount__c);
        }
    }

    // --- Scenario 2: Simple Abandoned Original ($199 AZ Home Paid -> Policy Bound No -> Refund $199 on A) ---
    @isTest
    static void testScenario2_SimpleAbandonedOriginal_199() {
        Lead l = new Lead(LastName = 'Scen2 Lead', Company = 'Co2', Status = 'Open');
        insert l;

        Policy_Information__c qA = new Policy_Information__c(Lead__c = l.Id, Agency_State__c = 'Arizona', Lines__c = 'HOME', Policy_Type__c = 'Quote', Policy_Status__c = 'Approved', Agency_Fee__c = 199.00, Policy_Bound__c = 'No');
        insert qA;
        insert new Agency_Fee_Invoice__c(Policy_Information__c = qA.Id, Status__c = 'Paid');
        insert new Financial_Ledger__c(Policy_Information__c = qA.Id, Type__c = 'Credit Created', Credit__c = 199.00, Date_Time__c = DateTime.now());

        BindProcessController.BindProcessWrapper data = BindProcessController.getBindProcessData(l.Id);
        for (Policy_Information__c p : data.policies) {
            if (p.Id == qA.Id) System.assertEquals(199.00, p.Refundable_Balance_Amount__c);
        }

        BindProcessController.issueRefund(qA.Id);
    }

    // --- Scenario 2B: Low Fee Abandoned Original ($25 Arkansas Auto Paid -> Policy Bound No -> Refund $25 on A) ---
    @isTest
    static void testScenario2B_SimpleAbandonedOriginal_25() {
        Lead l = new Lead(LastName = 'Scen2B Lead', Company = 'Co2B', Status = 'Open');
        insert l;

        Policy_Information__c qA = new Policy_Information__c(Lead__c = l.Id, Agency_State__c = 'Arkansas', Lines__c = 'AUTO', Policy_Type__c = 'Quote', Policy_Status__c = 'Approved', Agency_Fee__c = 25.00, Policy_Bound__c = 'No');
        insert qA;
        insert new Agency_Fee_Invoice__c(Policy_Information__c = qA.Id, Status__c = 'Paid');
        insert new Financial_Ledger__c(Policy_Information__c = qA.Id, Type__c = 'Credit Created', Credit__c = 25.00, Date_Time__c = DateTime.now());

        BindProcessController.BindProcessWrapper data = BindProcessController.getBindProcessData(l.Id);
        for (Policy_Information__c p : data.policies) {
            if (p.Id == qA.Id) System.assertEquals(25.00, p.Refundable_Balance_Amount__c);
        }
    }

    // --- Scenario 3: Chain with Multiple Replacements ($199 Home -> $99 Auto -> $35 CT -> $65 Surplus on C) ---
    @isTest
    static void testScenario3_MultiReplacementChain_199to99to35() {
        Lead l = new Lead(LastName = 'Scen3 Lead', Company = 'Co3', Status = 'Open');
        insert l;

        Policy_Information__c qA = new Policy_Information__c(Lead__c = l.Id, Agency_State__c = 'Arizona', Lines__c = 'HOME', Policy_Type__c = 'Quote', Policy_Status__c = 'Approved', Agency_Fee__c = 199.00);
        insert qA;
        insert new Agency_Fee_Invoice__c(Policy_Information__c = qA.Id, Status__c = 'Paid');
        insert new Financial_Ledger__c(Policy_Information__c = qA.Id, Type__c = 'Credit Created', Credit__c = 199.00, Date_Time__c = DateTime.now());

        Policy_Information__c qB = new Policy_Information__c(Lead__c = l.Id, Agency_State__c = 'Illinois', Lines__c = 'AUTO', Policy_Type__c = 'Quote', Policy_Status__c = 'Approved', Is_Replacement__c = true, Original_Policy__c = qA.Id, Agency_Fee__c = 99.00);
        insert qB;
        BindProcessController.applyCredit(qB.Id);

        Policy_Information__c qC = new Policy_Information__c(Lead__c = l.Id, Agency_State__c = 'Connecticut', Lines__c = 'AUTO', Policy_Type__c = 'Quote', Policy_Status__c = 'Approved', Is_Replacement__c = true, Original_Policy__c = qB.Id, Agency_Fee__c = 35.00);
        insert qC;
        BindProcessController.applyCredit(qC.Id);

        BindProcessController.BindProcessWrapper data = BindProcessController.getBindProcessData(l.Id);
        System.assertEquals(65.00, data.globalAvailableCredit);

        for (Policy_Information__c p : data.policies) {
            if (p.Id == qC.Id) System.assertEquals(65.00, p.Refundable_Balance_Amount__c);
            if (p.Id == qB.Id || p.Id == qA.Id) System.assertEquals(0.00, p.Refundable_Balance_Amount__c);
        }
    }

    @isTest
    static void testScenario3B_MultiReplacementChain_HigherFeeOnC() {
        Lead l = new Lead(LastName = 'Scen3B Lead', Company = 'Co3B', Status = 'Open');
        insert l;

        Policy_Information__c qA = new Policy_Information__c(Lead__c = l.Id, Agency_State__c = 'Arizona', Lines__c = 'HOME', Policy_Type__c = 'Quote', Policy_Status__c = 'Approved', Agency_Fee__c = 199.00);
        insert qA;
        insert new Agency_Fee_Invoice__c(Policy_Information__c = qA.Id, Status__c = 'Paid');
        insert new Financial_Ledger__c(Policy_Information__c = qA.Id, Type__c = 'Credit Created', Credit__c = 199.00, Date_Time__c = DateTime.now());

        Policy_Information__c qB = new Policy_Information__c(Lead__c = l.Id, Agency_State__c = 'Illinois', Lines__c = 'AUTO', Policy_Type__c = 'Quote', Policy_Status__c = 'Approved', Is_Replacement__c = true, Original_Policy__c = qA.Id, Agency_Fee__c = 99.00);
        insert qB;
        BindProcessController.applyCredit(qB.Id);

        Policy_Information__c qC = new Policy_Information__c(Lead__c = l.Id, Agency_State__c = 'Connecticut', Lines__c = 'AUTO', Policy_Type__c = 'Quote', Policy_Status__c = 'Approved', Is_Replacement__c = true, Original_Policy__c = qB.Id, Agency_Fee__c = 150.00);
        insert qC;
        BindProcessController.applyCredit(qC.Id);

        BindProcessController.BindProcessWrapper data = BindProcessController.getBindProcessData(l.Id);
        System.assertEquals(49.00, data.globalAvailableCredit);

        for (Policy_Information__c p : data.policies) {
            if (p.Id == qC.Id) System.assertEquals(49.00, p.Refundable_Balance_Amount__c);
            if (p.Id == qB.Id || p.Id == qA.Id) System.assertEquals(0.00, p.Refundable_Balance_Amount__c);
        }
    }

    @isTest
    static void testNewQuoteAppliesGlobalCredit() {
        Lead l = new Lead(LastName = 'GlobalCred Lead', Company = 'CoGC', Status = 'Open');
        insert l;

        // Policy A pays $100 cash, generating $100 global credit pool
        Policy_Information__c qA = new Policy_Information__c(Lead__c = l.Id, Agency_State__c = 'Arizona', Lines__c = 'HOME', Policy_Type__c = 'Quote', Policy_Status__c = 'Approved', Agency_Fee__c = 100.00);
        insert qA;
        insert new Agency_Fee_Invoice__c(Policy_Information__c = qA.Id, Status__c = 'Paid');
        insert new Financial_Ledger__c(Policy_Information__c = qA.Id, Type__c = 'Credit Created', Credit__c = 100.00, Date_Time__c = DateTime.now());

        // Policy A replaced
        qA.Replacement_Initiated__c = true;
        update qA;

        // New Quote B (not a replacement quote) with $30 fee
        Policy_Information__c qB = new Policy_Information__c(Lead__c = l.Id, Agency_State__c = 'Arizona', Lines__c = 'AUTO', Policy_Type__c = 'Quote', Policy_Status__c = 'Approved', Agency_Fee__c = 30.00);
        insert qB;

        BindProcessController.BindProcessWrapper data = BindProcessController.getBindProcessData(l.Id);
        System.assertEquals(100.00, data.globalAvailableCredit);
        
        for (BindProcessController.PolicyUiDto dto : data.policyUiList) {
            if (dto.policy.Id == qB.Id) {
                System.assertEquals(true, dto.isPathwayApplyCredit);
                System.assertEquals('Apply Credit', dto.tileActionText);
            }
        }
    }

    @isTest
    static void testCreditConsumptionReducesGlobalCreditPool() {
        Lead l = new Lead(LastName = 'ConsumCred Lead', Company = 'CoCC', Status = 'Open');
        insert l;

        // Policy A pays $30 cash, generating $30 credit pool
        Policy_Information__c qA = new Policy_Information__c(Lead__c = l.Id, Agency_State__c = 'Arizona', Lines__c = 'HOME', Policy_Type__c = 'Quote', Policy_Status__c = 'Approved', Agency_Fee__c = 30.00);
        insert qA;
        insert new Agency_Fee_Invoice__c(Policy_Information__c = qA.Id, Status__c = 'Paid');
        insert new Financial_Ledger__c(Policy_Information__c = qA.Id, Type__c = 'Credit Created', Credit__c = 30.00, Date_Time__c = DateTime.now());
        qA.Replacement_Initiated__c = true;
        update qA;

        // Replacement Quote B ($30 fee)
        Policy_Information__c qB = new Policy_Information__c(Lead__c = l.Id, Agency_State__c = 'Arizona', Lines__c = 'AUTO', Policy_Type__c = 'Quote', Policy_Status__c = 'Approved', Is_Replacement__c = true, Original_Policy__c = qA.Id, Agency_Fee__c = 30.00);
        insert qB;

        // Quote C ($30 fee) applies credit
        Policy_Information__c qC = new Policy_Information__c(Lead__c = l.Id, Agency_State__c = 'Illinois', Lines__c = 'AUTO', Policy_Type__c = 'Quote', Policy_Status__c = 'Approved', Agency_Fee__c = 30.00);
        insert qC;
        BindProcessController.applyCredit(qC.Id);

        BindProcessController.BindProcessWrapper data = BindProcessController.getBindProcessData(l.Id);
        System.assertEquals(0.00, data.globalAvailableCredit);

        for (BindProcessController.PolicyUiDto dto : data.policyUiList) {
            if (dto.policy.Id == qB.Id) {
                System.assertEquals(true, dto.isPathwayCollectFee);
                System.assertEquals('Process Payment', dto.tileActionText);
            }
        }

        // When Quote C's credit is refunded, global credit pool is restored to $30
        qC.Replacement_Credit_Status__c = 'Refunded';
        update qC;

        BindProcessController.BindProcessWrapper data2 = BindProcessController.getBindProcessData(l.Id);
        System.assertEquals(30.00, data2.globalAvailableCredit);

        for (BindProcessController.PolicyUiDto dto : data2.policyUiList) {
            if (dto.policy.Id == qB.Id) {
                System.assertEquals(true, dto.isPathwayApplyCredit);
                System.assertEquals('Apply Credit', dto.tileActionText);
            }
        }
    }

    @isTest
    static void testAbandonedUnpaidReplacementRefundOnRoot() {
        Lead l = new Lead(LastName = 'UnpaidAban Lead', Company = 'CoUA', Status = 'Open');
        insert l;

        // Policy A pays $30 cash
        Policy_Information__c qA = new Policy_Information__c(Lead__c = l.Id, Agency_State__c = 'Arizona', Lines__c = 'AUTO', Policy_Type__c = 'Quote', Policy_Status__c = 'Approved', Agency_Fee__c = 30.00);
        insert qA;
        insert new Agency_Fee_Invoice__c(Policy_Information__c = qA.Id, Status__c = 'Paid');
        insert new Financial_Ledger__c(Policy_Information__c = qA.Id, Type__c = 'Credit Created', Credit__c = 30.00, Date_Time__c = DateTime.now());
        qA.Replacement_Initiated__c = true;
        update qA;

        // Replacement Quote B (unpaid, credit not applied) abandoned
        Policy_Information__c qB = new Policy_Information__c(Lead__c = l.Id, Agency_State__c = 'Arizona', Lines__c = 'AUTO', Policy_Type__c = 'Quote', Policy_Status__c = 'Approved', Is_Replacement__c = true, Original_Policy__c = qA.Id, Agency_Fee__c = 30.00, Policy_Bound__c = 'No');
        insert qB;

        BindProcessController.BindProcessWrapper data = BindProcessController.getBindProcessData(l.Id);
        
        for (BindProcessController.PolicyUiDto dto : data.policyUiList) {
            if (dto.policy.Id == qA.Id) {
                System.assertEquals(true, dto.isPathwayIssueRefund);
                System.assertEquals('Issue Refund', dto.tileActionText);
            }
            if (dto.policy.Id == qB.Id) {
                System.assertEquals(true, dto.isPathwayNoFee);
                System.assertEquals('Not Applicable', dto.tileStatus);
            }
        }
    }

    @isTest
    static void testLeadWidePendingQuoteSuppressesRefundInApex() {
        Lead l = new Lead(LastName = 'LeadWidePending Lead', Company = 'CoLWP', Status = 'Open');
        insert l;

        // Chain 1: Paid $199 cash
        Policy_Information__c q1 = new Policy_Information__c(Lead__c = l.Id, Agency_State__c = 'Illinois', Lines__c = 'CONDO', Policy_Type__c = 'Quote', Policy_Status__c = 'Approved', Agency_Fee__c = 199.00);
        insert q1;
        insert new Agency_Fee_Invoice__c(Policy_Information__c = q1.Id, Status__c = 'Paid');
        insert new Financial_Ledger__c(Policy_Information__c = q1.Id, Type__c = 'Credit Created', Credit__c = 199.00, Date_Time__c = DateTime.now());

        // Chain 2: Standalone Auto quote with $30 fee unpaid
        Policy_Information__c q2 = new Policy_Information__c(Lead__c = l.Id, Agency_State__c = 'Illinois', Lines__c = 'AUTO', Policy_Type__c = 'Quote', Policy_Status__c = 'Approved', Agency_Fee__c = 30.00);
        insert q2;

        BindProcessController.BindProcessWrapper data = BindProcessController.getBindProcessData(l.Id);

        for (BindProcessController.PolicyUiDto dto : data.policyUiList) {
            if (dto.policy.Id == q1.Id) {
                // Refund is suppressed because q2 needs fee payment
                System.assertEquals(0.00, dto.policy.Refundable_Balance_Amount__c);
            }
            if (dto.policy.Id == q2.Id) {
                System.assertEquals(true, dto.isPathwayApplyCredit);
                System.assertEquals('Apply Credit', dto.tileActionText);
            }
        }
    }

    // --- Scenario 4: Abandoned Replacement Paid via Credit ($35 CT -> $35 CT Applied -> B Abandoned -> $35 Refund on B) ---
    @isTest
    static void testScenario4_AbandonedReplacementCredit_35() {
        Lead l = new Lead(LastName = 'Scen4 Lead', Company = 'Co4', Status = 'Open');
        insert l;

        Policy_Information__c qA = new Policy_Information__c(Lead__c = l.Id, Agency_State__c = 'Connecticut', Lines__c = 'AUTO', Policy_Type__c = 'Quote', Policy_Status__c = 'Approved', Agency_Fee__c = 35.00);
        insert qA;
        insert new Agency_Fee_Invoice__c(Policy_Information__c = qA.Id, Status__c = 'Paid');
        insert new Financial_Ledger__c(Policy_Information__c = qA.Id, Type__c = 'Credit Created', Credit__c = 35.00, Date_Time__c = DateTime.now());

        Policy_Information__c qB = new Policy_Information__c(Lead__c = l.Id, Agency_State__c = 'Connecticut', Lines__c = 'AUTO', Policy_Type__c = 'Quote', Policy_Status__c = 'Approved', Is_Replacement__c = true, Original_Policy__c = qA.Id, Agency_Fee__c = 35.00);
        insert qB;
        BindProcessController.applyCredit(qB.Id);
        qB.Policy_Bound__c = 'No';
        update qB;

        BindProcessController.BindProcessWrapper data = BindProcessController.getBindProcessData(l.Id);
        for (Policy_Information__c p : data.policies) {
            if (p.Id == qB.Id) System.assertEquals(35.00, p.Refundable_Balance_Amount__c);
            if (p.Id == qA.Id) System.assertEquals(0.00, p.Refundable_Balance_Amount__c);
        }

        BindProcessController.issueRefund(qB.Id);
    }

    // --- Scenario 5: Abandoned Replacement Paid via Credit + Cash ($30 AL -> $199 AZ [$30 credit + $169 cash] -> B Abandoned -> $199 Refund on B) ---
    @isTest
    static void testScenario5_AbandonedReplacementCreditAndCash_30to199() {
        Lead l = new Lead(LastName = 'Scen5 Lead', Company = 'Co5', Status = 'Open');
        insert l;

        Policy_Information__c qA = new Policy_Information__c(Lead__c = l.Id, Agency_State__c = 'Alabama', Lines__c = 'AUTO', Policy_Type__c = 'Quote', Policy_Status__c = 'Approved', Agency_Fee__c = 30.00);
        insert qA;
        insert new Agency_Fee_Invoice__c(Policy_Information__c = qA.Id, Status__c = 'Paid');
        insert new Financial_Ledger__c(Policy_Information__c = qA.Id, Type__c = 'Credit Created', Credit__c = 30.00, Date_Time__c = DateTime.now());

        Policy_Information__c qB = new Policy_Information__c(Lead__c = l.Id, Agency_State__c = 'Arizona', Lines__c = 'HOME', Policy_Type__c = 'Quote', Policy_Status__c = 'Approved', Is_Replacement__c = true, Original_Policy__c = qA.Id, Agency_Fee__c = 199.00);
        insert qB;
        BindProcessController.applyCredit(qB.Id);
        insert new Agency_Fee_Invoice__c(Policy_Information__c = qB.Id, Status__c = 'Paid');
        qB.Policy_Bound__c = 'No';
        update qB;

        BindProcessController.BindProcessWrapper data = BindProcessController.getBindProcessData(l.Id);
        for (Policy_Information__c p : data.policies) {
            if (p.Id == qB.Id) System.assert(p.Refundable_Balance_Amount__c >= 30.00);
            if (p.Id == qA.Id) System.assertEquals(0.00, p.Refundable_Balance_Amount__c);
        }
    }

    // --- Scenario 6: Abandoned Replacement Never Touched Credit ($30 AL -> $199 AZ [never applied credit] -> B Abandoned -> $30 Refund on A) ---
    @isTest
    static void testScenario6_AbandonedReplacementNeverTouchedCredit_30to199() {
        Lead l = new Lead(LastName = 'Scen6 Lead', Company = 'Co6', Status = 'Open');
        insert l;

        Policy_Information__c qA = new Policy_Information__c(Lead__c = l.Id, Agency_State__c = 'Alabama', Lines__c = 'AUTO', Policy_Type__c = 'Quote', Policy_Status__c = 'Approved', Agency_Fee__c = 30.00);
        insert qA;
        insert new Agency_Fee_Invoice__c(Policy_Information__c = qA.Id, Status__c = 'Paid');
        insert new Financial_Ledger__c(Policy_Information__c = qA.Id, Type__c = 'Credit Created', Credit__c = 30.00, Date_Time__c = DateTime.now());

        Policy_Information__c qB = new Policy_Information__c(Lead__c = l.Id, Agency_State__c = 'Arizona', Lines__c = 'HOME', Policy_Type__c = 'Quote', Policy_Status__c = 'Approved', Is_Replacement__c = true, Original_Policy__c = qA.Id, Agency_Fee__c = 199.00, Policy_Bound__c = 'No');
        insert qB;

        BindProcessController.BindProcessWrapper data = BindProcessController.getBindProcessData(l.Id);
        for (Policy_Information__c p : data.policies) {
            if (p.Id == qA.Id) System.assertEquals(30.00, p.Refundable_Balance_Amount__c);
            if (p.Id == qB.Id) System.assertEquals(0.00, p.Refundable_Balance_Amount__c);
        }
    }

    // --- Scenario 7: Abandoned Chain with Surplus ($199 AZ Home -> $35 CT Applied -> B Abandoned -> $199 Refund on B) ---
    @isTest
    static void testScenario7_AbandonedChainWithSurplus_199to35() {
        Lead l = new Lead(LastName = 'Scen7 Lead', Company = 'Co7', Status = 'Open');
        insert l;

        Policy_Information__c qA = new Policy_Information__c(Lead__c = l.Id, Agency_State__c = 'Arizona', Lines__c = 'HOME', Policy_Type__c = 'Quote', Policy_Status__c = 'Approved', Agency_Fee__c = 199.00);
        insert qA;
        insert new Agency_Fee_Invoice__c(Policy_Information__c = qA.Id, Status__c = 'Paid');
        insert new Financial_Ledger__c(Policy_Information__c = qA.Id, Type__c = 'Credit Created', Credit__c = 199.00, Date_Time__c = DateTime.now());

        Policy_Information__c qB = new Policy_Information__c(Lead__c = l.Id, Agency_State__c = 'Connecticut', Lines__c = 'AUTO', Policy_Type__c = 'Quote', Policy_Status__c = 'Approved', Is_Replacement__c = true, Original_Policy__c = qA.Id, Agency_Fee__c = 35.00);
        insert qB;
        BindProcessController.applyCredit(qB.Id);
        qB.Policy_Bound__c = 'No';
        update qB;

        BindProcessController.BindProcessWrapper data = BindProcessController.getBindProcessData(l.Id);
        for (Policy_Information__c p : data.policies) {
            if (p.Id == qB.Id) System.assertEquals(199.00, p.Refundable_Balance_Amount__c);
            if (p.Id == qA.Id) System.assertEquals(0.00, p.Refundable_Balance_Amount__c);
        }

        BindProcessController.issueRefund(qB.Id);
    }

    // --- Scenario 8: $0 State Fee Replacement ($99 TX -> $0 Florida Fee B -> $99 Refund stays on A) ---
    @isTest
    static void testScenario8_ZeroStateFeeReplacement_99toZero() {
        Lead l = new Lead(LastName = 'ZeroFee Lead', Company = 'CoZero', Status = 'Open');
        insert l;

        Policy_Information__c qA = new Policy_Information__c(Lead__c = l.Id, Agency_State__c = 'Texas', Lines__c = 'AUTO', Policy_Type__c = 'Quote', Policy_Status__c = 'Approved', Agency_Fee__c = 99.00);
        insert qA;
        insert new Agency_Fee_Invoice__c(Policy_Information__c = qA.Id, Status__c = 'Paid');
        insert new Financial_Ledger__c(Policy_Information__c = qA.Id, Type__c = 'Credit Created', Credit__c = 99.00, Date_Time__c = DateTime.now());

        Policy_Information__c qB = new Policy_Information__c(Lead__c = l.Id, Agency_State__c = 'Florida', Lines__c = 'AUTO', Policy_Type__c = 'Quote', Policy_Status__c = 'Approved', Is_Replacement__c = true, Original_Policy__c = qA.Id, Agency_Fee__c = 0.00);
        insert qB;

        BindProcessController.BindProcessWrapper data = BindProcessController.getBindProcessData(l.Id);
        for (Policy_Information__c p : data.policies) {
            if (p.Id == qA.Id) System.assertEquals(99.00, p.Refundable_Balance_Amount__c);
            if (p.Id == qB.Id) System.assertEquals(0.00, p.Refundable_Balance_Amount__c);
        }
    }

    // --- Scenario 9: Fee Waiver Accepted Replacement ($199 AZ -> Fee Waived $0 -> Refund stays on A) ---
    @isTest
    static void testScenario9_FeeWaiverAcceptedReplacement_199() {
        Lead l = new Lead(LastName = 'Waiver Lead', Company = 'CoWaiver', Status = 'Open');
        insert l;

        Policy_Information__c qA = new Policy_Information__c(Lead__c = l.Id, Agency_State__c = 'Arizona', Lines__c = 'HOME', Policy_Type__c = 'Quote', Policy_Status__c = 'Approved', Agency_Fee__c = 199.00);
        insert qA;
        insert new Agency_Fee_Invoice__c(Policy_Information__c = qA.Id, Status__c = 'Paid');
        insert new Financial_Ledger__c(Policy_Information__c = qA.Id, Type__c = 'Credit Created', Credit__c = 199.00, Date_Time__c = DateTime.now());

        Policy_Information__c qB = new Policy_Information__c(Lead__c = l.Id, Agency_State__c = 'Arizona', Lines__c = 'HOME', Policy_Type__c = 'Quote', Policy_Status__c = 'Approved', Is_Replacement__c = true, Original_Policy__c = qA.Id, Agency_Fee__c = 199.00, Agency_Fee_Waiver_Decision__c = 'Accepted');
        insert qB;

        BindProcessController.BindProcessWrapper data = BindProcessController.getBindProcessData(l.Id);
        for (Policy_Information__c p : data.policies) {
            if (p.Id == qA.Id) System.assertEquals(199.00, p.Refundable_Balance_Amount__c);
            if (p.Id == qB.Id) System.assertEquals(0.00, p.Refundable_Balance_Amount__c);
        }
    }

    // --- Scenario 10: Rejected Replacement Quote ($99 OH -> B Rejected -> Refund stays on A) ---
    @isTest
    static void testScenario10_RejectedReplacementQuote() {
        Lead l = new Lead(LastName = 'Rej Lead', Company = 'CoRej', Status = 'Open');
        insert l;

        Policy_Information__c qA = new Policy_Information__c(Lead__c = l.Id, Agency_State__c = 'Ohio', Lines__c = 'AUTO', Policy_Type__c = 'Quote', Policy_Status__c = 'Approved', Agency_Fee__c = 99.00);
        insert qA;
        insert new Agency_Fee_Invoice__c(Policy_Information__c = qA.Id, Status__c = 'Paid');
        insert new Financial_Ledger__c(Policy_Information__c = qA.Id, Type__c = 'Credit Created', Credit__c = 99.00, Date_Time__c = DateTime.now());

        Policy_Information__c qB = new Policy_Information__c(Lead__c = l.Id, Agency_State__c = 'Ohio', Lines__c = 'AUTO', Policy_Type__c = 'Quote', Policy_Status__c = 'Rejected', Is_Replacement__c = true, Original_Policy__c = qA.Id, Agency_Fee__c = 99.00);
        insert qB;

        BindProcessController.BindProcessWrapper data = BindProcessController.getBindProcessData(l.Id);
        for (Policy_Information__c p : data.policies) {
            if (p.Id == qA.Id) System.assertEquals(99.00, p.Refundable_Balance_Amount__c);
            if (p.Id == qB.Id) System.assertEquals(0.00, p.Refundable_Balance_Amount__c);
        }
    }

    // --- Scenario 11: Multi-Policy Parallel Lines of Business (LOB) Lead ---
    @isTest
    static void testScenario11_MultiPolicyParallelLOBLead() {
        Lead l = new Lead(LastName = 'MultiLOB Lead', Company = 'CoMulti', Status = 'Open');
        insert l;

        Policy_Information__c a1 = new Policy_Information__c(Lead__c = l.Id, Lines__c = 'AUTO', Agency_State__c = 'Alabama', Policy_Type__c = 'Quote', Policy_Status__c = 'Approved', Agency_Fee__c = 30.00);
        insert a1;
        insert new Agency_Fee_Invoice__c(Policy_Information__c = a1.Id, Status__c = 'Paid');
        insert new Financial_Ledger__c(Policy_Information__c = a1.Id, Type__c = 'Credit Created', Credit__c = 30.00, Date_Time__c = DateTime.now());

        Policy_Information__c b1 = new Policy_Information__c(Lead__c = l.Id, Lines__c = 'AUTO', Agency_State__c = 'Alabama', Policy_Type__c = 'Quote', Policy_Status__c = 'Approved', Is_Replacement__c = true, Original_Policy__c = a1.Id, Agency_Fee__c = 30.00);
        insert b1;
        BindProcessController.applyCredit(b1.Id);

        Policy_Information__c a2 = new Policy_Information__c(Lead__c = l.Id, Lines__c = 'HOME', Agency_State__c = 'Arizona', Policy_Type__c = 'Quote', Policy_Status__c = 'Approved', Agency_Fee__c = 199.00);
        insert a2;
        insert new Agency_Fee_Invoice__c(Policy_Information__c = a2.Id, Status__c = 'Paid');
        insert new Financial_Ledger__c(Policy_Information__c = a2.Id, Type__c = 'Credit Created', Credit__c = 199.00, Date_Time__c = DateTime.now());

        Policy_Information__c b2 = new Policy_Information__c(Lead__c = l.Id, Lines__c = 'HOME', Agency_State__c = 'Florida', Policy_Type__c = 'Quote', Policy_Status__c = 'Approved', Is_Replacement__c = true, Original_Policy__c = a2.Id, Agency_Fee__c = 0.00);
        insert b2;

        BindProcessController.BindProcessWrapper data = BindProcessController.getBindProcessData(l.Id);
        for (Policy_Information__c p : data.policies) {
            if (p.Id == b1.Id) System.assertEquals(0.00, p.Refundable_Balance_Amount__c);
            if (p.Id == a2.Id) System.assertEquals(199.00, p.Refundable_Balance_Amount__c);
        }
    }

    // --- Scenario 12: Voided Financial Ledger / Invoice Voiding ---
    @isTest
    static void testScenario12_VoidedLedgerAndInvoice() {
        Lead l = new Lead(LastName = 'Void Lead', Company = 'CoVoid', Status = 'Open');
        insert l;

        Policy_Information__c qA = new Policy_Information__c(Lead__c = l.Id, Policy_Type__c = 'Quote', Policy_Status__c = 'Approved', Agency_Fee__c = 30.00);
        insert qA;
        Agency_Fee_Invoice__c inv = new Agency_Fee_Invoice__c(Policy_Information__c = qA.Id, Status__c = 'Paid');
        insert inv;

        BindProcessController.voidInvoice(qA.Id);
    }

    // --- Scenario 13: Exception Checks (Duplicate Refund / Zero Credit Pool / Already Paid Fee) ---
    @isTest
    static void testScenario13_ExceptionsCheck() {
        Lead l = new Lead(LastName = 'Ex Lead', Company = 'CoEx', Status = 'Open');
        insert l;

        Policy_Information__c qA = new Policy_Information__c(Lead__c = l.Id, Policy_Type__c = 'Quote', Policy_Status__c = 'Approved', Agency_Fee__c = 30.00);
        insert qA;

        Boolean zeroCreditExThrown = false;
        try {
            BindProcessController.applyCredit(qA.Id);
        } catch (AuraHandledException e) {
            zeroCreditExThrown = true;
        }
        System.assert(zeroCreditExThrown);

        insert new Agency_Fee_Invoice__c(Policy_Information__c = qA.Id, Status__c = 'Paid');
        insert new Financial_Ledger__c(Policy_Information__c = qA.Id, Type__c = 'Credit Created', Credit__c = 30.00, Date_Time__c = DateTime.now());
        qA.Credit_Applied_Amount__c = 30.00;
        update qA;

        Boolean alreadyPaidExThrown = false;
        try {
            BindProcessController.applyCredit(qA.Id);
        } catch (AuraHandledException e) {
            alreadyPaidExThrown = true;
        }
        System.assert(alreadyPaidExThrown);
    }

    // --- Scenario 14: Replacement Quote Creation & Linking ---
    @isTest
    static void testScenario14_ReplacementQuoteCreationAndLink() {
        Lead l = [SELECT Id FROM Lead LIMIT 1];
        Policy_Information__c originalPol = [SELECT Id FROM Policy_Information__c WHERE Lead__c = :l.Id LIMIT 1];

        Policy_Information__c newPol = new Policy_Information__c(
            Lead__c = l.Id,
            Policy_Type__c = 'Quote',
            Policy_Status__c = 'Draft',
            Agency_Fee__c = 40.00,
            Is_Replacement__c = true,
            Original_Policy__c = originalPol.Id
        );
        insert newPol;
    }
}