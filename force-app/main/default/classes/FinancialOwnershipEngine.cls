public with sharing class FinancialOwnershipEngine {

    public class EngineResult {
        public Decimal globalAvailableCredit { get; set; }
        public Decimal globalOutstandingAmount { get; set; }
        public Decimal globalNetRefundOwed { get; set; }

        public EngineResult() {
            this.globalAvailableCredit = 0.00;
            this.globalOutstandingAmount = 0.00;
            this.globalNetRefundOwed = 0.00;
        }
    }

    private static Decimal parsePaidToDate(String val) {
        if (String.isBlank(val)) return 0.00;
        if (val.equalsIgnoreCase('Paid') || val.equalsIgnoreCase('Yes') || val.equalsIgnoreCase('True')) return 1.00;
        try {
            String cleaned = val.replaceAll('[^0-9.]', '');
            if (String.isNotBlank(cleaned)) return Decimal.valueOf(cleaned);
        } catch (Exception e) {}
        return 0.00;
    }

    public static EngineResult processFinancials(Map<Id, List<Policy_Information__c>> chainMap, Map<Id, Policy_Information__c> polMap, List<Financial_Ledger__c> ledgers) {
        EngineResult res = new EngineResult();
        if (chainMap == null || chainMap.isEmpty()) return res;

        Decimal totalGlobalSurplus = 0.00;

        for (Id rootId : chainMap.keySet()) {
            List<Policy_Information__c> chain = chainMap.get(rootId);
            Policy_Information__c rootPol = polMap.get(rootId);

            Set<Id> chainPolicyIds = new Set<Id>();
            for (Policy_Information__c cp : chain) {
                chainPolicyIds.add(cp.Id);
            }

            Decimal chainCreated = 0.00;
            Decimal chainRefunded = 0.00;
            Decimal chainApplied = 0.00;

            for (Financial_Ledger__c fl : ledgers) {
                if (fl.Policy_Information__c != null && chainPolicyIds.contains(fl.Policy_Information__c)) {
                    if (fl.Type__c == 'Refund Issued' && fl.Debit__c != null) chainRefunded += fl.Debit__c;
                }
            }

            for (Policy_Information__c cp : chain) {
                if (cp.Credit_Applied_Amount__c != null && cp.Credit_Applied_Amount__c > 0) {
                    chainApplied += cp.Credit_Applied_Amount__c;
                }
                Boolean isInvoicePaid = (cp.Agency_Fee_Invoices__r != null && !cp.Agency_Fee_Invoices__r.isEmpty() && cp.Agency_Fee_Invoices__r[0].Status__c == 'Paid');
                Decimal paidToDateAmt = parsePaidToDate(cp.Paid_To_Date__c);
                Boolean isPaidToDate = (paidToDateAmt > 0);
                if (isInvoicePaid || isPaidToDate) {
                    Decimal invFee = cp.Agency_Fee__c != null ? cp.Agency_Fee__c : 0.00;
                    Decimal creditApp = cp.Credit_Applied_Amount__c != null ? cp.Credit_Applied_Amount__c : 0.00;
                    Decimal cashPaid = Math.max(0, invFee - creditApp);
                    if (cashPaid == 0 && isPaidToDate) {
                        cashPaid = paidToDateAmt;
                    } else if (cashPaid == 0 && invFee > 0) {
                        cashPaid = invFee;
                    }
                    chainCreated += cashPaid;
                }
            }

            if (chainCreated == 0) {
                for (Financial_Ledger__c fl : ledgers) {
                    if (fl.Policy_Information__c != null && chainPolicyIds.contains(fl.Policy_Information__c)) {
                        if (fl.Type__c == 'Credit Created' && fl.Credit__c != null) {
                            chainCreated += fl.Credit__c;
                        }
                    }
                }
            }

            Set<Id> replacedParentIds = new Set<Id>();
            for (Policy_Information__c cp : chain) {
                if (cp.Original_Policy__c != null) {
                    replacedParentIds.add(cp.Original_Policy__c);
                }
            }

            Decimal chainActiveCashPaid = 0.00;
            for (Policy_Information__c cp : chain) {
                Boolean isCpAbandoned = (cp.Policy_Status__c == 'Rejected' || cp.Policy_Status__c == 'Abandoned' || cp.Policy_Bound__c == 'No');
                Boolean isCpReplaced = cp.Replacement_Initiated__c == true || replacedParentIds.contains(cp.Id);
                Boolean isCpInvoicePaid = (cp.Agency_Fee_Invoices__r != null && !cp.Agency_Fee_Invoices__r.isEmpty() && cp.Agency_Fee_Invoices__r[0].Status__c == 'Paid');
                Decimal cpPaidToDateAmt = parsePaidToDate(cp.Paid_To_Date__c);
                Boolean isCpPaidToDate = (cpPaidToDateAmt > 0);

                if (!isCpAbandoned && !isCpReplaced) {
                    if (isCpInvoicePaid || isCpPaidToDate) {
                        Decimal invFee = cp.Agency_Fee__c != null ? cp.Agency_Fee__c : 0.00;
                        Decimal creditApp = cp.Credit_Applied_Amount__c != null ? cp.Credit_Applied_Amount__c : 0.00;
                        Decimal cashPaid = Math.max(0, invFee - creditApp);
                        if (cashPaid == 0 && isCpPaidToDate) cashPaid = cpPaidToDateAmt;
                        else if (cashPaid == 0 && invFee > 0) cashPaid = invFee;
                        chainActiveCashPaid += cashPaid;
                    }
                }
            }

            Decimal unallocatedSurplus = chainCreated - chainApplied - chainActiveCashPaid - chainRefunded;
            if (unallocatedSurplus < 0) unallocatedSurplus = 0.00;

            totalGlobalSurplus += unallocatedSurplus;

            Policy_Information__c economicOwner = rootPol;

            // Ownership transfers ONLY if a replacement quote applied credit
            for (Policy_Information__c candidate : chain) {
                if (candidate.Id == rootId) continue;
                Boolean hasCreditApplied = (candidate.Replacement_Credit_Status__c == 'Applied' || (candidate.Credit_Applied_Amount__c != null && candidate.Credit_Applied_Amount__c > 0));
                if (hasCreditApplied) {
                    economicOwner = candidate;
                }
            }

            Decimal ownerCreditApplied = economicOwner.Credit_Applied_Amount__c != null ? economicOwner.Credit_Applied_Amount__c : 0.00;
            Boolean isOwnerAbandoned = (economicOwner.Policy_Status__c == 'Rejected' || economicOwner.Policy_Status__c == 'Abandoned' || economicOwner.Policy_Bound__c == 'No');
            Decimal ownerTotalHeld = isOwnerAbandoned ? (ownerCreditApplied + unallocatedSurplus) : unallocatedSurplus;
            if (chainCreated > 0 && ownerTotalHeld > chainCreated) {
                ownerTotalHeld = chainCreated;
            }

            for (Policy_Information__c pol : chain) {
                if (pol.Id == economicOwner.Id) {
                    if (isOwnerAbandoned) {
                        pol.Refundable_Balance_Amount__c = ownerTotalHeld;
                        pol.Available_Credit_Amount__c = unallocatedSurplus;
                    } else if (unallocatedSurplus > 0) {
                        pol.Refundable_Balance_Amount__c = unallocatedSurplus;
                        pol.Available_Credit_Amount__c = unallocatedSurplus;
                    } else {
                        pol.Refundable_Balance_Amount__c = 0.00;
                        pol.Available_Credit_Amount__c = 0.00;
                    }
                } else {
                    pol.Refundable_Balance_Amount__c = 0.00;
                    pol.Available_Credit_Amount__c = 0.00;
                }
            }
        }

        res.globalAvailableCredit = totalGlobalSurplus;

        // Compute global outstanding
        Decimal globalOutstanding = 0.00;
        for (Policy_Information__c pol : polMap.values()) {
            Boolean isWaived = pol.Agency_Fee_Waiver_Decision__c == 'Accepted';
            Decimal fee = isWaived ? 0.00 : (pol.Agency_Fee__c != null ? pol.Agency_Fee__c : 0.00);
            Boolean isPaid = (pol.Agency_Fee_Invoices__r != null && !pol.Agency_Fee_Invoices__r.isEmpty() && pol.Agency_Fee_Invoices__r[0].Status__c == 'Paid') ||
                            (pol.Replacement_Credit_Status__c == 'Applied' && pol.Credit_Applied_Amount__c != null && pol.Credit_Applied_Amount__c >= fee);
            Boolean isAbandoned = pol.Policy_Status__c == 'Rejected' || pol.Policy_Status__c == 'Abandoned' || pol.Policy_Bound__c == 'No';

            if (!isAbandoned && fee > 0 && !isPaid) {
                Decimal applied = pol.Credit_Applied_Amount__c != null ? pol.Credit_Applied_Amount__c : 0.00;
                Decimal remaining = fee - applied;
                if (remaining > 0) globalOutstanding += remaining;
            }
        }
        res.globalOutstandingAmount = globalOutstanding;

        // Compute global net refund
        Decimal globalNetRefund = 0.00;
        for (Policy_Information__c pol : polMap.values()) {
            if (pol.Refundable_Balance_Amount__c != null && pol.Refundable_Balance_Amount__c > 0) {
                globalNetRefund += pol.Refundable_Balance_Amount__c;
            }
        }
        res.globalNetRefundOwed = globalNetRefund;

        return res;
    }
}