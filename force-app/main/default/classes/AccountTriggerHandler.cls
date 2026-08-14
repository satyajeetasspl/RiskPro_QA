public class AccountTriggerHandler {

    /**
     * Before Insert handler.
     *
     * Pre-populates the four AMS360 lookup fields that the vert__ managed-package
     * trigger requires before it attempts an AMS360 sync. Without these values the
     * package throws "The following fields must have a value to sync to AMS360".
     *
     * We reuse AMSHelperClass (which already resolves the correct IDs by name) and
     * call it once per unique owner so we stay within governor limits on bulk inserts.
     *
     * This is the recommended workaround when the AMS360 integration license has
     * expired or is unavailable in this sandbox org.
     */
    public static void handleBeforeInsert(List<Account> newAccounts) {

        // Collect distinct owner IDs so we can batch the AMSHelperClass calls
        Set<Id> ownerIds = new Set<Id>();
        for (Account acc : newAccounts) {
            if (acc.OwnerId != null) {
                ownerIds.add(acc.OwnerId);
            }
        }

        // Build a map: ownerId → AMSWrapper (one SOQL round-trip per owner)
        Map<Id, AMSHelperClass.AMSWrapper> wrapperByOwner = new Map<Id, AMSHelperClass.AMSWrapper>();
        for (Id ownerId : ownerIds) {
            // Use default (non-Partner) AMS path → HOUSE ACCOUNT Division & Branch
            AMSHelperClass.AMSWrapper w = AMSHelperClass.getAMSBusinesUnit(
                'Default',   // leadSource  – not Partner, so HOUSE ACCOUNT path
                '',          // partnerName – not needed for default path
                ownerId
            );
            wrapperByOwner.put(ownerId, w);
        }

        // Stamp the AMS360 lookup IDs on every new Account
        for (Account acc : newAccounts) {
            AMSHelperClass.AMSWrapper w = (acc.OwnerId != null)
                ? wrapperByOwner.get(acc.OwnerId)
                : null;

            if (w != null) {
                if (acc.vert__AMS360_Division__c   == null) acc.vert__AMS360_Division__c   = w.DivId;
                if (acc.vert__AMS360_Branch__c     == null) acc.vert__AMS360_Branch__c     = w.BranchId;
                if (acc.vert__AMS360_Department__c == null) acc.vert__AMS360_Department__c = w.DeptId;
                if (acc.vert__AMS360_Group__c      == null) acc.vert__AMS360_Group__c      = w.GroupId;
            }
        }
    }
}