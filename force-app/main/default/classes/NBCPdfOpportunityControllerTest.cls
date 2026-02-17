@IsTest(seeAllData=true)
public class NBCPdfOpportunityControllerTest {

    @IsTest
    static void testNBCPdfOpportunityController() {

        // Get any existing Opportunity with an Account
        Opportunity opp = [
            SELECT Id, AccountId
            FROM Opportunity
            WHERE AccountId != null
            LIMIT 1
        ];

        // Ensure Account exists (required for controller)
        Account acc = [
            SELECT Id, Name
            FROM Account
            WHERE Id = :opp.AccountId
            LIMIT 1
        ];

        // Create a Policy tied to Opportunity (required for policies query)
        Policy_Information__c pol = new Policy_Information__c(
            Carrier__c = 'Test Carrier',
            Policy__c = 'POL-OPP-001',
            Premium__c = '500',
            Opportunity__c = opp.Id,
            Account__c = acc.Id
        );
        insert pol;

        Test.startTest();

        // Simulate Visualforce page parameter
        ApexPages.currentPage().getParameters().put('id', opp.Id);

        // Invoke controller constructor
        NBCPdfOpportunityController ctrl =
            new NBCPdfOpportunityController();

        Test.stopTest();
    }
}