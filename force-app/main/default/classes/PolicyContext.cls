public with sharing class PolicyContext {
    public Decimal feeAmount { get; set; }
    public Decimal creditApplied { get; set; }
    public Decimal refundableBalance { get; set; }
    public Boolean isPaid { get; set; }
    public Boolean isAbandoned { get; set; }
    public Boolean isReplaced { get; set; }
    public Boolean isRefunded { get; set; }
    public Boolean hasPendingCreditReplacement { get; set; }
    public Decimal globalAvailableCredit { get; set; }

    public PolicyContext() {
        this.feeAmount = 0.00;
        this.creditApplied = 0.00;
        this.refundableBalance = 0.00;
        this.isPaid = false;
        this.isAbandoned = false;
        this.isReplaced = false;
        this.isRefunded = false;
        this.hasPendingCreditReplacement = false;
        this.globalAvailableCredit = 0.00;
    }
}