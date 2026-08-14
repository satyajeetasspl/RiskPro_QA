public class QBO_CustomerRequestWrapper {
    public String DisplayName;
    public String CompanyName;
    public PrimaryEmailAddr PrimaryEmailAddr;
    public PrimaryPhone PrimaryPhone;
    
    // Constructor to map Salesforce Account data to QBO format
    public QBO_CustomerRequestWrapper(Account acc) {
        this(acc.Name, acc.Id, acc.Phone);
    }

    // Flexible constructor for Leads or generic syncing
    public QBO_CustomerRequestWrapper(String name, Id sfId, String phone) {
        // QBO requires DisplayName to be unique. Appending the SFDC ID is a safe practice.
        this.DisplayName = name + ' (' + sfId + ')';
        this.CompanyName = name;
        
        if (String.isNotBlank(phone)) {
            this.PrimaryPhone = new PrimaryPhone();
            this.PrimaryPhone.FreeFormNumber = phone;
        }
    }

    public class PrimaryEmailAddr {
        public String Address;
    }

    public class PrimaryPhone {
        public String FreeFormNumber;
    }
}