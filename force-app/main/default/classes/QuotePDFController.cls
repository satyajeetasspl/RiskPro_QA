public with sharing class QuotePDFController {
    public List<QuoteWrapper> quotes { get; set; }
    public String leadName { get; set; }
    public String createdDate { get; set; }
    public Decimal grandTotal { get; set; } 
    public Decimal totalPremium { get; set; } 
    public Decimal totalFee { get; set; } 

    public QuotePDFController() {
        String quotesJson = ApexPages.currentPage().getParameters().get('quotes');
        leadName = ApexPages.currentPage().getParameters().get('leadName');
        createdDate = ApexPages.currentPage().getParameters().get('createdDate');
        grandTotal = 0.00; 
        totalPremium = 0.00;
        totalFee = 0.00;
        
        if (String.isNotBlank(quotesJson)) {
            quotes = (List<QuoteWrapper>) JSON.deserialize(quotesJson, List<QuoteWrapper>.class);
            
            for (QuoteWrapper q : quotes) {
                if (q.Premium != null) {
                    totalPremium += q.Premium;
                }
                if (q.AgencyFee != null) {
                    totalFee += q.AgencyFee;
                }
            }
            grandTotal = totalPremium + totalFee;
        } else {
            quotes = new List<QuoteWrapper>();
        }
    }

    public class QuoteWrapper {
        public String Carrier { get; set; }
        public String Lines { get; set; }
        public String QuoteNum { get; set; } 
        public String AgencyState {get; set;}
        public String EffectiveDate {get; set;}
        public String Term { get; set; }
        public String ExpirationDate { get; set; }
        public Decimal Premium { get; set; }
        public Decimal AgencyFee {get; set;}
        public Decimal TotalAmount { get; set; }
        public Boolean WaiverRequested { get; set; }
        public String WaiverReason { get; set; }
        public String WaiverComment { get; set; }
        public String WaiverDecision { get; set; }
        
        public String getSafeState() {
            return AgencyState;
        }
    }
}