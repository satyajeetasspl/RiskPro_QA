public with sharing class AgencyFeeHelper {
    
    // Property Lines mapping to "Home"
    private static final Set<String> PROPERTY_LINES = new Set<String>{
        'Home', 'Landlord', 'Condo', 'Secondary Property', 
        'Manufactured Home', 'Mobile Home', 'Mobile / Manufactured Home'
    };

    /**
     * Normalizes a Line of Business value to its category for fee table lookups.
     */
    public static String normalizeLOB(String lob) {
        if (String.isBlank(lob)) return '';
        
        if (PROPERTY_LINES.contains(lob)) {
            return 'Home';
        }
        
        // Ensure standard cases return correctly
        if (lob.equalsIgnoreCase('Auto')) return 'Auto';
        if (lob.equalsIgnoreCase('Flood')) return 'Flood';
        
        return lob;
    }

    /**
     * Calculates the Agency Fee for Arkansas policies: MIN($25, Premium * 20%).
     */
    public static Decimal calculateArkansasFee(Decimal premium) {
        if (premium == null || premium <= 0) return 0.00;
        return Math.min(25.00, (premium * 0.20)).setScale(2);
    }

    /**
     * Returns the appropriate agency fee based on state, normalized LOB, and premium.
     */
    public static Decimal getCalculatedFee(String state, String lob, Decimal premium, Map<String, Decimal> feeMap) {
        if (String.isBlank(state)) return 0.00;

        // Arkansas special rule
        if (state == 'AR' || state.equalsIgnoreCase('Arkansas')) {
            return calculateArkansasFee(premium);
        }

        // Standard state rule
        String normalizedLOB = normalizeLOB(lob);
        String key = state.toUpperCase() + '|' + normalizedLOB.toUpperCase();
        
        if (feeMap != null && feeMap.containsKey(key)) {
            return feeMap.get(key);
        }

        // Fallback or No Fee
        return 0.00;
    }

    /**
     * Adjusts the final fee amount based on the waiver decision.
     */
    public static Decimal applyWaiverDecision(Decimal calculatedFee, String decision) {
        if (decision == 'Accepted') {
            return 0.00;
        }
        return (calculatedFee != null) ? calculatedFee : 0.00;
    }
}