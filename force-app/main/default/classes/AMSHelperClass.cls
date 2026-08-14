public class AMSHelperClass {
    
    public static AMSWrapper getAMSBusinesUnit(
        String leadStatus,
        String partnerName,
        String ownerId
    ) {
        
        // -------------------- Defaults --------------------
        String branchHAName = 'HOUSE ACCOUNT';
        String divMBPName   = 'Mortgage Broker Partners';
        String divHAName    = 'HOUSE ACCOUNT';
        String deptName     = 'Department 1';
        String groupName    = 'Group one';
        
        AMSWrapper wrapper = new AMSWrapper();
        
        // Normalize partner name for case-insensitive matching
        String partner = partnerName != null ? partnerName.toLowerCase() : '';
        
        // -------------------- Division & Branch Logic --------------------
        if (leadStatus == 'Partner') {
            
            wrapper.DivId = getIdByName(
                'vert__AMS360_Division__c',
                divMBPName
            );
            
            // Fetch all branches
            Map<String, Id> branchMap = getBranchName();
            
            // Match partner name against specific lenders
            if (
                partner.contains('lend-a-loan') ||
                partner.contains('rapid home lending')
            ) {
                for (String branchName : branchMap.keySet()) {
                    if (branchName != null &&
                        branchName.toLowerCase().contains(partner)
                       ) {
                           wrapper.BranchId = branchMap.get(branchName);
                           break;
                       }
                }
            }
            
        } else {
            
            wrapper.DivId = getIdByName(
                'vert__AMS360_Division__c',
                divHAName
            );
            
            wrapper.BranchId = getIdByName(
                'vert__AMS360_Branch__c',
                branchHAName
            );
        }
        
        // -------------------- Department & Group --------------------
        wrapper.DeptId = getIdByName(
            'vert__AMS360_Department__c',
            deptName
        );
        
        wrapper.GroupId = getIdByName(
            'vert__AMS360_Group__c',
            groupName
        );
        
        // -------------------- Executive --------------------
        wrapper.excutiveId = getEmployeeID(ownerId);
        
        // -------------------- Debug Logs --------------------
        System.debug('DeptId   => ' + wrapper.DeptId);
        System.debug('GroupId  => ' + wrapper.GroupId);
        System.debug('DivId    => ' + wrapper.DivId);
        System.debug('BranchId => ' + wrapper.BranchId);
        System.debug('excutiveId => ' + wrapper.excutiveId);
        
        return wrapper;
    }
    
    // -------------------- Helpers --------------------
    
    private static Id getIdByName(String sObjectName, String nameValue) {
        if (String.isBlank(nameValue)) {
            return null;
        }
        
        String soql =
            'SELECT Id FROM ' + sObjectName +
            ' WHERE Name = :nameValue LIMIT 1';
        
        List<SObject> records = Database.query(soql);
        return records.isEmpty() ? null : records[0].Id;
    }
    
    private static Map<String, Id> getBranchName() {
        Map<String, Id> branchMap = new Map<String, Id>();
        
        for (vert__AMS360_Branch__c branch :
             [SELECT Id, Name FROM vert__AMS360_Branch__c]
            ) {
                branchMap.put(branch.Name, branch.Id);
            }
        
        return branchMap;
    }
    
    private static Id getEmployeeID(String ownerId) {
    if (String.isBlank(ownerId)) {
        return null;
    }
    List<vert__AMS360_Employee__c> employees = [
        SELECT Id
        FROM vert__AMS360_Employee__c
        WHERE vert__AMS360_Assign_To__c = :ownerId
        LIMIT 1
    ];
    return employees.isEmpty() ? null : employees[0].Id;
}

    
    // -------------------- Wrapper --------------------
    
    public class AMSWrapper {
        public Id BranchId   { get; set; }
        public Id DivId      { get; set; }
        public Id DeptId     { get; set; }
        public Id GroupId    { get; set; }
        public Id excutiveId { get; set; }
    }
}