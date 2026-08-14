@IsTest
public class AgencyFeeHelperTest {
    
    @IsTest
    static void testNormalizeLOB() {
        System.assertEquals('Home', AgencyFeeHelper.normalizeLOB('Home'));
        System.assertEquals('Home', AgencyFeeHelper.normalizeLOB('Condo'));
        System.assertEquals('Home', AgencyFeeHelper.normalizeLOB('Landlord'));
        System.assertEquals('Home', AgencyFeeHelper.normalizeLOB('Manufactured Home'));
        System.assertEquals('Auto', AgencyFeeHelper.normalizeLOB('Auto'));
        System.assertEquals('Flood', AgencyFeeHelper.normalizeLOB('Flood'));
        System.assertEquals('Custom', AgencyFeeHelper.normalizeLOB('Custom'));
    }

    @IsTest
    static void testCalculateArkansasFee() {
        System.assertEquals(20.00, AgencyFeeHelper.calculateArkansasFee(100.00));
        System.assertEquals(25.00, AgencyFeeHelper.calculateArkansasFee(125.00));
        System.assertEquals(25.00, AgencyFeeHelper.calculateArkansasFee(2000.00));
        System.assertEquals(0.00, AgencyFeeHelper.calculateArkansasFee(0.00));
    }

    @IsTest
    static void testGetCalculatedFee() {
        Map<String, Decimal> feeMap = new Map<String, Decimal>{
            'OH|AUTO' => 25.00,
            'OH|HOME' => 50.00
        };

        // Arkansas
        System.assertEquals(20.00, AgencyFeeHelper.getCalculatedFee('Arkansas', 'Auto', 100.00, feeMap));
        System.assertEquals(20.00, AgencyFeeHelper.getCalculatedFee('AR', 'Auto', 100.00, feeMap));

        // Standard
        System.assertEquals(25.00, AgencyFeeHelper.getCalculatedFee('OH', 'Auto', 1000.00, feeMap));
        System.assertEquals(50.00, AgencyFeeHelper.getCalculatedFee('OH', 'Condo', 1000.00, feeMap)); // Normalized to Home

        // Missing
        System.assertEquals(0.00, AgencyFeeHelper.getCalculatedFee('NY', 'Auto', 1000.00, feeMap));
    }

    @IsTest
    static void testApplyWaiverDecision() {
        System.assertEquals(0.00, AgencyFeeHelper.applyWaiverDecision(25.00, 'Accepted'));
        System.assertEquals(25.00, AgencyFeeHelper.applyWaiverDecision(25.00, 'Rejected'));
        System.assertEquals(25.00, AgencyFeeHelper.applyWaiverDecision(25.00, 'Pending'));
        System.assertEquals(25.00, AgencyFeeHelper.applyWaiverDecision(25.00, null));
    }
}