@isTest
private class QuotePDFControllerTest {

    @isTest
    static void testConstructorWithValidQuotes() {
        List<QuotePDFController.QuoteWrapper> wrappers = new List<QuotePDFController.QuoteWrapper>();

        QuotePDFController.QuoteWrapper q1 = new QuotePDFController.QuoteWrapper();
        q1.Carrier = 'Test Carrier';
        q1.Lines = 'Property';
        q1.QuoteNum = 'Q-001';
        q1.AgencyState = 'TX';
        q1.EffectiveDate = '2026-05-01';
        q1.Term = '12 Months';
        q1.ExpirationDate = '2027-05-01';
        q1.Premium = 1500.00;
        q1.AgencyFee = 200.00;
        q1.TotalAmount = 1700.00;
        q1.WaiverRequested = false;
        wrappers.add(q1);

        QuotePDFController.QuoteWrapper q2 = new QuotePDFController.QuoteWrapper();
        q2.Carrier = 'Another Carrier';
        q2.Lines = 'Auto';
        q2.QuoteNum = 'Q-002';
        q2.AgencyState = 'LA';
        q2.EffectiveDate = '2026-06-01';
        q2.Term = '6 Months';
        q2.ExpirationDate = '2026-12-01';
        q2.Premium = 2000.00;
        q2.AgencyFee = 300.00;
        q2.TotalAmount = 2300.00;
        q2.WaiverRequested = true;
        wrappers.add(q2);

        String quotesJson = JSON.serialize(wrappers);

        PageReference pageRef = new PageReference('/apex/QuotePDF');
        pageRef.getParameters().put('quotes', quotesJson);
        pageRef.getParameters().put('leadName', 'John Doe');
        pageRef.getParameters().put('createdDate', '2026-04-22');
        Test.setCurrentPage(pageRef);

        Test.startTest();
        QuotePDFController controller = new QuotePDFController();
        String safeState = controller.quotes[0].getSafeState();
        Test.stopTest();
    }

    @isTest
    static void testConstructorWithNullPremiumAndFee() {
        List<QuotePDFController.QuoteWrapper> wrappers = new List<QuotePDFController.QuoteWrapper>();

        QuotePDFController.QuoteWrapper q = new QuotePDFController.QuoteWrapper();
        q.Carrier = 'Null Carrier';
        q.Lines = 'GL';
        q.Premium = null;
        q.AgencyFee = null;
        wrappers.add(q);

        String quotesJson = JSON.serialize(wrappers);

        PageReference pageRef = new PageReference('/apex/QuotePDF');
        pageRef.getParameters().put('quotes', quotesJson);
        pageRef.getParameters().put('leadName', 'Jane Smith');
        pageRef.getParameters().put('createdDate', '2026-04-22');
        Test.setCurrentPage(pageRef);

        Test.startTest();
        QuotePDFController controller = new QuotePDFController();
        Test.stopTest();
    }

    @isTest
    static void testConstructorWithBlankJson() {
        PageReference pageRef = new PageReference('/apex/QuotePDF');
        pageRef.getParameters().put('quotes', '');
        pageRef.getParameters().put('leadName', 'Empty Test');
        pageRef.getParameters().put('createdDate', '2026-04-22');
        Test.setCurrentPage(pageRef);

        Test.startTest();
        QuotePDFController controller = new QuotePDFController();
        Test.stopTest();
    }

    @isTest
    static void testConstructorWithNoParameters() {
        PageReference pageRef = new PageReference('/apex/QuotePDF');
        Test.setCurrentPage(pageRef);

        Test.startTest();
        QuotePDFController controller = new QuotePDFController();
        Test.stopTest();
    }
}