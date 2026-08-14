public class FileExtractionWrapper {
    // Customer Information
    @AuraEnabled public String customerName;
    @AuraEnabled public String customerAddress;
    @AuraEnabled public String city;
    @AuraEnabled public String state;
    @AuraEnabled public String zipCode;

    // Agency Information
    @AuraEnabled public String agencyName;
    @AuraEnabled public String agencyAddress;

    // Policy Information
    @AuraEnabled public String insuranceCompany;
    @AuraEnabled public String policyType;
    @AuraEnabled public String quoteNumber;
    @AuraEnabled public Date policyEffectiveDate;
    @AuraEnabled public String term;
    @AuraEnabled public Decimal totalPremium;
    @AuraEnabled public Decimal estimatedBasicPremium;

    // Property Details
    @AuraEnabled public String constructionType;
    @AuraEnabled public String protectionClass;
    @AuraEnabled public String yearBuilt;
    @AuraEnabled public String squareFootage;
    @AuraEnabled public String territory;
    @AuraEnabled public Integer numberOfResidents;
    @AuraEnabled public Integer numberOfMortgages;
    @AuraEnabled public String pool;
    @AuraEnabled public String dogs;

    // Coverage Details
    @AuraEnabled public Decimal dwellingCoverage;
    @AuraEnabled public Decimal otherStructuresCoverage;
    @AuraEnabled public Decimal personalPropertyCoverage;
    @AuraEnabled public Decimal lossOfUseCoverage;
    @AuraEnabled public Decimal personalLiabilityCoverage;
    @AuraEnabled public Decimal medicalPaymentsCoverage;

    // Additional Coverages
    @AuraEnabled public Decimal fungiCoverage;
    @AuraEnabled public Decimal liabilityAggregateSublimit;
    @AuraEnabled public String personalPropertyReplacementCost;
    @AuraEnabled public Decimal increasedMedicalPayments;

    // Deductible Information
    @AuraEnabled public Decimal deductible;

    // Loss Information
    @AuraEnabled public Date lossDate;
    @AuraEnabled public String lossDescription;
}