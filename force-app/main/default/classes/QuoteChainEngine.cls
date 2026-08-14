public with sharing class QuoteChainEngine {

    public class ChainEngineResult {
        public Map<Id, Policy_Information__c> polMap { get; set; }
        public Map<Id, List<Policy_Information__c>> chainMap { get; set; }
        public Set<Id> allReplacedParentIds { get; set; }
        public FinancialOwnershipEngine.EngineResult financials { get; set; }

        public ChainEngineResult() {
            this.polMap = new Map<Id, Policy_Information__c>();
            this.chainMap = new Map<Id, List<Policy_Information__c>>();
            this.allReplacedParentIds = new Set<Id>();
            this.financials = new FinancialOwnershipEngine.EngineResult();
        }
    }

    public static ChainEngineResult buildAndProcessChains(List<Policy_Information__c> policies, List<Financial_Ledger__c> ledgers) {
        ChainEngineResult res = new ChainEngineResult();
        if (policies == null || policies.isEmpty()) return res;

        res.polMap = new Map<Id, Policy_Information__c>(policies);

        for (Policy_Information__c pol : policies) {
            if (pol.Original_Policy__c != null) {
                res.allReplacedParentIds.add(pol.Original_Policy__c);
            }
            Policy_Information__c root = pol;
            Set<Id> visited = new Set<Id>{ root.Id };
            while (root.Original_Policy__c != null && res.polMap.containsKey(root.Original_Policy__c) && !visited.contains(root.Original_Policy__c)) {
                root = res.polMap.get(root.Original_Policy__c);
                visited.add(root.Id);
            }
            if (!res.chainMap.containsKey(root.Id)) {
                res.chainMap.put(root.Id, new List<Policy_Information__c>());
            }
            res.chainMap.get(root.Id).add(pol);
        }

        res.financials = FinancialOwnershipEngine.processFinancials(res.chainMap, res.polMap, ledgers);
        return res;
    }
}