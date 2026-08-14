public with sharing class QBO_InvoiceController {
    private static QuickBooks_Setting__mdt cachedSetting;
    private static QuickBooks_Setting__mdt activeSetting {
        get {
            if (cachedSetting == null) {
                List<QuickBooks_Setting__mdt> settings = [SELECT Realm_ID__c, Named_Credential__c FROM QuickBooks_Setting__mdt WHERE Is_Active__c = true LIMIT 1];
                if (!settings.isEmpty()) {
                    cachedSetting = settings[0];
                } else {
                    throw new AuraHandledException('QuickBooks Setting is not configured. Please configure and activate a QuickBooks Setting in Custom Metadata.');
                }
            }
            return cachedSetting;
        }
    }

    @AuraEnabled
    public static String createQBOInvoice(Id recordId) {
        try {
            // 1. Fetch record data (Lead or Account)
            String objectName = recordId.getSObjectType().getDescribe().getName();
            String query = 'SELECT Id, Name, Email, Phone, ' + 
                          (objectName == 'Lead' ? 'Borrowers_Phone_Number__c' : 'Phone') + 
                          ' FROM ' + objectName + ' WHERE Id = :recordId LIMIT 1';
            SObject record = Database.query(query);
            
            String name = (String)record.get('Name');
            String email = (String)record.get('Email');
            
            // 2. Fetch Policies for Fees
            List<Policy_Information__c> allFeePolicies = [SELECT Id, Agency_Fee__c, Credit_Applied_Amount__c, Lines__c, Policy_Status__c FROM Policy_Information__c WHERE (Lead__c = :recordId OR Opportunity__c = :recordId OR Account__c = :recordId) AND Agency_Fee__c > 0];
            
            if (allFeePolicies.isEmpty()) {
                return 'ERROR: Cannot generate invoice. No policies with an agency fee were found on this record.';
            }

            List<Policy_Information__c> approvedPolicies = new List<Policy_Information__c>();
            Decimal totalFee = 0;
            for (Policy_Information__c p : allFeePolicies) {
                if (p.Policy_Status__c == 'Approved' || p.Policy_Status__c == 'Approved - With Post-Bind Conditions') {
                    approvedPolicies.add(p);
                    Decimal fee = p.Agency_Fee__c != null ? p.Agency_Fee__c : 0;
                    Decimal credit = p.Credit_Applied_Amount__c != null ? p.Credit_Applied_Amount__c : 0;
                    totalFee += (fee - credit);
                }
            }
            if (totalFee < 0) totalFee = 0;

            if (approvedPolicies.isEmpty()) {
                return 'ERROR: Cannot generate invoice. The policy quote must be approved before an agency fee invoice can be created.';
            }

            // 3. Find or Create Customer in QBO
            String customerId = findOrCreateCustomer(record);
            if (customerId.startsWith('ERROR')) return customerId;

            // 4. Create Invoice in QBO
            return createInvoice(customerId, totalFee, email, recordId, approvedPolicies);

        } catch (Exception e) {
            return 'CRITICAL ERROR: ' + e.getMessage() + '\n' + e.getStackTraceString();
        }
    }

    private static String findOrCreateCustomer(SObject record) {
        String sfId = (String)record.get('Id');
        String name = (String)record.get('Name');
        String displayName = name + ' (' + sfId + ')';
        
        // Search by DisplayName
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:' + activeSetting.Named_Credential__c + '/v3/company/' + activeSetting.Realm_ID__c + '/query?query=' + EncodingUtil.urlEncode('SELECT * FROM Customer WHERE DisplayName = \'' + displayName.replace('\'', '\\\'') + '\'', 'UTF-8'));
        req.setMethod('GET');
        req.setHeader('Accept', 'application/json');
        
        Http http = new Http();
        HttpResponse res = http.send(req);
        
        if (res.getStatusCode() == 200) {
            Map<String, Object> body = (Map<String, Object>)JSON.deserializeUntyped(res.getBody());
            Map<String, Object> queryRes = (Map<String, Object>)body.get('QueryResponse');
            List<Object> customers = (List<Object>)queryRes.get('Customer');
            
            if (customers != null && !customers.isEmpty()) {
                Map<String, Object> customer = (Map<String, Object>)customers[0];
                return (String)customer.get('Id');
            }
        }

        // If not found, create (similar to QBO_CustomerSyncController)
        return syncCustomer(record);
    }

    private static String syncCustomer(SObject record) {
        String name = (String)record.get('Name');
        Id sfId = (Id)record.get('Id');
        String phone = (String)record.get('Phone');
        
        QBO_CustomerRequestWrapper wrapper = new QBO_CustomerRequestWrapper(name, sfId, phone);
        
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:' + activeSetting.Named_Credential__c + '/v3/company/' + activeSetting.Realm_ID__c + '/customer?minorversion=69');
        req.setMethod('POST');
        req.setHeader('Accept', 'application/json');
        req.setHeader('Content-Type', 'application/json');
        req.setBody(JSON.serialize(wrapper, true));
        
        Http http = new Http();
        HttpResponse res = http.send(req);
        
        if (res.getStatusCode() == 200) {
            Map<String, Object> body = (Map<String, Object>)JSON.deserializeUntyped(res.getBody());
            Map<String, Object> customer = (Map<String, Object>)body.get('Customer');
            return (String)customer.get('Id');
        }
        return 'ERROR: Failed to sync customer - ' + res.getBody();
    }

    private static String createInvoice(String customerId, Decimal amount, String email, Id recordId, List<Policy_Information__c> approvedPolicies) {
        Map<String, Object> invoice = new Map<String, Object>();
        
        // Line Items
        List<Map<String, Object>> lines = new List<Map<String, Object>>();
        Map<String, Object> line = new Map<String, Object>();
        line.put('Amount', amount);
        line.put('Description', 'Agency Service Fee');
        line.put('DetailType', 'SalesItemLineDetail');
        
        Map<String, Object> detail = new Map<String, Object>();
        // ItemRef for "Services" or similar - usually 1 in many QBO setups, but can be dynamic.
        // We will use a default or generic one if possible. 
        // For robustness, we could search for an item named "Agency Fee".
        Map<String, Object> itemRef = new Map<String, Object>();
        itemRef.put('value', '1'); 
        itemRef.put('name', 'Services');
        detail.put('ItemRef', itemRef);
        line.put('SalesItemLineDetail', detail);
        lines.add(line);
        
        invoice.put('Line', lines);
        
        // Customer
        Map<String, Object> customerRef = new Map<String, Object>();
        customerRef.put('value', customerId);
        invoice.put('CustomerRef', customerRef);
        
        // Email
        if (String.isNotBlank(email)) {
            Map<String, Object> billEmail = new Map<String, Object>();
            billEmail.put('Address', email);
            invoice.put('BillEmail', billEmail);
            invoice.put('EmailStatus', 'NeedToSend');
        }

        // Add PrivateNote with SF Id
        invoice.put('PrivateNote', 'Generated from Salesforce Record ID: ' + recordId);
        
        // Enable online payments so QBO generates the InvoiceLink
        invoice.put('AllowOnlineCreditCardPayment', true);
        invoice.put('AllowOnlineACHPayment', false);
        
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:' + activeSetting.Named_Credential__c + '/v3/company/' + activeSetting.Realm_ID__c + '/invoice?minorversion=69');
        req.setMethod('POST');
        req.setHeader('Accept', 'application/json');
        req.setHeader('Content-Type', 'application/json');
        req.setBody(JSON.serialize(invoice));
        
        Http http = new Http();
        HttpResponse res = http.send(req);
        
        if (res.getStatusCode() == 200) {
            Map<String, Object> body = (Map<String, Object>)JSON.deserializeUntyped(res.getBody());
            Map<String, Object> invRes = (Map<String, Object>)body.get('Invoice');
            String invoiceId = (String)invRes.get('Id');
            String invoiceLink = (String)invRes.get('InvoiceLink');
            
            // If POST doesn't return InvoiceLink, explicitly GET it as required by Intuit API
            if (String.isBlank(invoiceLink)) {
                HttpRequest getReq = new HttpRequest();
                getReq.setEndpoint('callout:' + activeSetting.Named_Credential__c + '/v3/company/' + activeSetting.Realm_ID__c + '/invoice/' + invoiceId + '?minorversion=69&include=invoiceLink');
                getReq.setMethod('GET');
                getReq.setHeader('Accept', 'application/json');
                HttpResponse getRes = http.send(getReq);
                if (getRes.getStatusCode() == 200) {
                    Map<String, Object> getBody = (Map<String, Object>)JSON.deserializeUntyped(getRes.getBody());
                    Map<String, Object> getInvRes = (Map<String, Object>)getBody.get('Invoice');
                    invoiceLink = (String)getInvRes.get('InvoiceLink');
                }
            }
            
            if (String.isNotBlank(invoiceLink) && invoiceLink.contains('scs')) {
                invoiceLink = 'https://connect.intuit.com/t/scs' + invoiceLink.substringAfter('scs');
            }
            
            if (String.isNotBlank(invoiceLink)) {
                // Update policies with the new link
                for (Policy_Information__c p : approvedPolicies) {
                    p.QBO_Invoice_Link__c = invoiceLink;
                }
                update approvedPolicies;
                
                return invoiceLink;
            }
            
            // Fallback to customer profile if InvoiceLink is somehow missing
            return 'https://app.sandbox.qbo.intuit.com/app/customerdetail?nameId=' + customerId;
        }
        return 'ERROR: Failed to create invoice - ' + res.getBody();
    }

    private static void sendInvoiceEmail(String invoiceId) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:' + activeSetting.Named_Credential__c + '/v3/company/' + activeSetting.Realm_ID__c + '/invoice/' + invoiceId + '/send?minorversion=69');
        req.setMethod('POST');
        req.setHeader('Accept', 'application/json');
        req.setHeader('Content-Type', 'application/json');
        
        Http http = new Http();
        http.send(req); // Fire and forget or handle error if needed
    }

    @AuraEnabled
    public static String generateInvoiceForPolicy(Id policyId) {
        try {
            // Fetch policy
            Policy_Information__c p = [SELECT Id, Lead__c, Opportunity__c, Account__c, Agency_Fee__c, Credit_Applied_Amount__c, Lines__c, Carrier__c, Quote__c, QBO_Invoice_Link__c FROM Policy_Information__c WHERE Id = :policyId LIMIT 1];
            
            if (p.Agency_Fee__c == null || p.Agency_Fee__c <= 0) return 'ERROR: No agency fee on this policy.';
            if (String.isNotBlank(p.QBO_Invoice_Link__c)) return p.QBO_Invoice_Link__c; // Already generated

            Id recordId = p.Lead__c != null ? p.Lead__c : (p.Opportunity__c != null ? p.Opportunity__c : p.Account__c);
            if (recordId == null) return 'ERROR: Policy is not linked to a Lead, Opp, or Account.';
            
            String objectName = recordId.getSObjectType().getDescribe().getName();
            String query = 'SELECT Id, Name, Email, Phone, ' + 
                          (objectName == 'Lead' ? 'Borrowers_Phone_Number__c' : 'Phone') + 
                          ' FROM ' + objectName + ' WHERE Id = :recordId LIMIT 1';
            SObject record = Database.query(query);
            
            String name = (String)record.get('Name');
            String email = (String)record.get('Email');
            
            String customerId = findOrCreateCustomer(record);
            if (customerId.startsWith('ERROR')) return customerId;

            return createInvoiceForSinglePolicy(customerId, email, recordId, p, name);

        } catch (Exception e) {
            return 'CRITICAL ERROR: ' + e.getMessage() + '\n' + e.getStackTraceString();
        }
    }

    @future(callout=true)
    public static void generateInvoicesForPoliciesFuture(List<Id> policyIds) {
        if (policyIds == null || policyIds.isEmpty()) return;
        for (Id pId : policyIds) {
            generateInvoiceForPolicy(pId);
        }
    }

    private static String createInvoiceForSinglePolicy(String customerId, String email, Id recordId, Policy_Information__c p, String clientName) {
        Map<String, Object> invoice = new Map<String, Object>();
        
        Decimal fee = p.Agency_Fee__c != null ? p.Agency_Fee__c : 0;
        Decimal credit = p.Credit_Applied_Amount__c != null ? p.Credit_Applied_Amount__c : 0;
        Decimal amountToCharge = fee - credit;
        if (amountToCharge < 0) amountToCharge = 0;

        List<Map<String, Object>> lines = new List<Map<String, Object>>();
        Map<String, Object> line = new Map<String, Object>();
        line.put('Amount', amountToCharge);
        line.put('Description', 'Agency Service Fee');
        line.put('DetailType', 'SalesItemLineDetail');
        
        Map<String, Object> detail = new Map<String, Object>();
        Map<String, Object> itemRef = new Map<String, Object>();
        itemRef.put('value', '1'); 
        itemRef.put('name', 'Services');
        detail.put('ItemRef', itemRef);
        line.put('SalesItemLineDetail', detail);
        lines.add(line);
        invoice.put('Line', lines);
        
        Map<String, Object> customerRef = new Map<String, Object>();
        customerRef.put('value', customerId);
        invoice.put('CustomerRef', customerRef);
        
        if (String.isNotBlank(email)) {
            Map<String, Object> billEmail = new Map<String, Object>();
            billEmail.put('Address', email);
            invoice.put('BillEmail', billEmail);
            invoice.put('EmailStatus', 'NeedToSend');
        }

        invoice.put('PrivateNote', 'Generated from Salesforce Policy ID: ' + p.Id);
        invoice.put('AllowOnlineCreditCardPayment', true);
        invoice.put('AllowOnlineACHPayment', false);
        
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:' + activeSetting.Named_Credential__c + '/v3/company/' + activeSetting.Realm_ID__c + '/invoice?minorversion=69');
        req.setMethod('POST');
        req.setHeader('Accept', 'application/json');
        req.setHeader('Content-Type', 'application/json');
        req.setBody(JSON.serialize(invoice));
        
        Http http = new Http();
        HttpResponse res = http.send(req);
        
        if (res.getStatusCode() == 200) {
            Map<String, Object> body = (Map<String, Object>)JSON.deserializeUntyped(res.getBody());
            Map<String, Object> invRes = (Map<String, Object>)body.get('Invoice');
            String invoiceId = (String)invRes.get('Id');
            String invoiceLink = (String)invRes.get('InvoiceLink');
            
            // If POST doesn't return InvoiceLink, explicitly GET it as required by Intuit API
            if (String.isBlank(invoiceLink)) {
                HttpRequest getReq = new HttpRequest();
                getReq.setEndpoint('callout:' + activeSetting.Named_Credential__c + '/v3/company/' + activeSetting.Realm_ID__c + '/invoice/' + invoiceId + '?minorversion=69&include=invoiceLink');
                getReq.setMethod('GET');
                getReq.setHeader('Accept', 'application/json');
                HttpResponse getRes = http.send(getReq);
                if (getRes.getStatusCode() == 200) {
                    Map<String, Object> getBody = (Map<String, Object>)JSON.deserializeUntyped(getRes.getBody());
                    Map<String, Object> getInvRes = (Map<String, Object>)getBody.get('Invoice');
                    invoiceLink = (String)getInvRes.get('InvoiceLink');
                }
            }
            
            if (String.isNotBlank(invoiceLink) && invoiceLink.contains('scs')) {
                invoiceLink = 'https://connect.intuit.com/t/scs' + invoiceLink.substringAfter('scs');
            }
            
            String docNumber = (String)invRes.get('DocNumber');
            String txnDateStr = (String)invRes.get('TxnDate');
            String dueDateStr = (String)invRes.get('DueDate');
            
            Date invoiceDate = String.isNotBlank(txnDateStr) ? Date.valueOf(txnDateStr) : Date.today();
            Date dueDate = String.isNotBlank(dueDateStr) ? Date.valueOf(dueDateStr) : Date.today();
            
            // We no longer trigger the QuickBooks email. We let Salesforce LWC handle it.
            // sendInvoiceEmail(invoiceId);
            
            // Create Agency_Fee_Invoice__c record
            Agency_Fee_Invoice__c afi = new Agency_Fee_Invoice__c();
            afi.Lead__c = p.Lead__c;
            afi.Policy_Information__c = p.Id;
            afi.Client_Name__c = clientName;
            afi.Client_Email__c = email;
            afi.Payee__c = 'Aspire Insurance Group, LLC'; // Consider moving to Custom Metadata
            afi.DBA__c = 'Risk Pros Insurance'; // Consider moving to Custom Metadata
            afi.Line_of_Business__c = p.Lines__c;
            afi.Carrier__c = p.Carrier__c;
            afi.Quote_Number__c = p.Quote__c;
            afi.Agency_Service_Fee_Amount__c = p.Agency_Fee__c;
            afi.QuickBooks_Customer__c = clientName;
            afi.QuickBooks_Customer_ID__c = customerId;
            afi.QuickBooks_Invoice_Number__c = docNumber;
            afi.QuickBooks_Invoice_ID__c = invoiceId;
            afi.Invoice_Date__c = invoiceDate;
            afi.Due_Date__c = dueDate;
            afi.Sent_Date_Time__c = DateTime.now();
            afi.Sent_By__c = UserInfo.getUserId();
            afi.Payment_Link__c = invoiceLink;
            afi.Payment_Methods_Accepted__c = 'Debit Card, Credit Card, Apple Pay, Google Pay';
            afi.Payment_Methods_Not_Accepted__c = 'ACH / Bank Transfer';
            Decimal balance = 0;
            if (invRes.get('Balance') != null) {
                balance = Decimal.valueOf(String.valueOf(invRes.get('Balance')));
            } else {
                balance = p.Agency_Fee__c;
            }
            
            String emailStatus = (String)invRes.get('EmailStatus');
            String dynamicStatus = 'Not Sent'; // Default to Not Sent since Salesforce will send it
            
            if (balance <= 0 && p.Agency_Fee__c > 0 && amountToCharge <= 0) {
                dynamicStatus = 'Paid';
            }
            
            afi.Status__c = dynamicStatus;
            
            insert afi;
            
            p.QBO_Invoice_Link__c = invoiceLink;
            update p;
            
            if (String.isNotBlank(invoiceLink)) return invoiceLink;
            return 'https://app.sandbox.qbo.intuit.com/app/customerdetail?nameId=' + customerId;
        }
        return 'ERROR: Failed to create invoice - ' + res.getBody();
    }

    // --- Custom UI Ledger Fetch ---
    
    public class QboLedgerItem {
        @AuraEnabled public String id { get; set; }
        @AuraEnabled public String docNumber { get; set; }
        @AuraEnabled public String type { get; set; }
        @AuraEnabled public Date txDate { get; set; }
        @AuraEnabled public Decimal totalAmount { get; set; }
        @AuraEnabled public Decimal balance { get; set; }
        @AuraEnabled public String status { get; set; }
    }

    @AuraEnabled
    public static List<QboLedgerItem> getCustomerLedger(Id recordId) {
        List<QboLedgerItem> ledger = new List<QboLedgerItem>();
        
        // Query actual policies on this record that have an agency fee
        List<Policy_Information__c> policies = [SELECT Id, Name, Agency_Fee__c, CreatedDate 
                                                FROM Policy_Information__c 
                                                WHERE (Lead__c = :recordId OR Opportunity__c = :recordId OR Account__c = :recordId) 
                                                AND Agency_Fee__c > 0 
                                                ORDER BY CreatedDate ASC];
                                                
        if (policies.isEmpty()) {
            return ledger; // Return empty if no fees
        }
        
        Integer counter = 1000;
        for (Policy_Information__c p : policies) {
            counter++;
            
            // Create a mock invoice based on the real policy agency fee
            QboLedgerItem inv = new QboLedgerItem();
            inv.id = 'INV-' + counter;
            inv.docNumber = String.valueOf(counter);
            inv.type = 'Invoice';
            inv.txDate = p.CreatedDate.date();
            inv.totalAmount = p.Agency_Fee__c;
            
            // For realism, we are mocking the successful payment flow
            // The invoice is Paid and has a corresponding payment.
            inv.balance = 0.00;
            inv.status = 'Paid';
            ledger.add(inv);
            
            // Add corresponding payment
            QboLedgerItem pay = new QboLedgerItem();
            pay.id = 'PAY-9' + counter;
            pay.docNumber = '9' + counter;
            pay.type = 'Payment';
            pay.txDate = p.CreatedDate.date();
            pay.totalAmount = p.Agency_Fee__c;
            pay.balance = 0.00;
            pay.status = 'Applied';
            ledger.add(pay);
        }
        
        // Sort ledger by date descending
        // Note: For simplicity in the mock, we can just return it. The UI can handle it or it's fine as is.
        return ledger;
    }

    @AuraEnabled
    public static String simulateQboPayment(String customerId, String invoiceId, Decimal amount, String paymentMethod, String referenceNumber, String cardNumber, String cardExp, String cardName) {
        try {
            Map<String, Object> payment = new Map<String, Object>();
            payment.put('TotalAmt', amount);
            
            if (String.isNotBlank(referenceNumber)) {
                payment.put('PaymentRefNum', referenceNumber);
            }
            
            String note = 'Payment processed via Salesforce Simulation.';
            if (String.isNotBlank(paymentMethod)) {
                note += ' Method: ' + paymentMethod;
            }
            if (String.isNotBlank(referenceNumber)) {
                note += ', Ref: ' + referenceNumber;
            }
            payment.put('PrivateNote', note);

            // Note: QuickBooks API explicitly rejects raw credit card details in the Accounting API for PCI Compliance.
            // We must use the PrivateNote to store these details for the mockup.

            Map<String, Object> paymentMethodRef = new Map<String, Object>();
            if (paymentMethod == 'Credit') {
                paymentMethodRef.put('value', '3'); // Standard Sandbox ID for Credit Card
            } else if (paymentMethod == 'Bank') {
                paymentMethodRef.put('value', '2'); // Standard Sandbox ID for Check/Bank Transfer
            }
            if (!paymentMethodRef.isEmpty()) {
                payment.put('PaymentMethodRef', paymentMethodRef);
            }

            Map<String, Object> customerRef = new Map<String, Object>();
            customerRef.put('value', customerId);
            payment.put('CustomerRef', customerRef);

            List<Map<String, Object>> lines = new List<Map<String, Object>>();
            Map<String, Object> line = new Map<String, Object>();
            line.put('Amount', amount);

            List<Map<String, Object>> linkedTxns = new List<Map<String, Object>>();
            Map<String, Object> linkedTxn = new Map<String, Object>();
            linkedTxn.put('TxnId', invoiceId);
            linkedTxn.put('TxnType', 'Invoice');
            linkedTxns.add(linkedTxn);

            line.put('LinkedTxn', linkedTxns);
            lines.add(line);

            payment.put('Line', lines);

            HttpRequest req = new HttpRequest();
            req.setEndpoint('callout:' + activeSetting.Named_Credential__c + '/v3/company/' + activeSetting.Realm_ID__c + '/payment?minorversion=69');
            req.setMethod('POST');
            req.setHeader('Accept', 'application/json');
            req.setHeader('Content-Type', 'application/json');
            req.setBody(JSON.serialize(payment));

            Http http = new Http();
            HttpResponse res = http.send(req);

            if (res.getStatusCode() == 200) {
                // Update Agency_Fee_Invoice__c to Paid
                List<Agency_Fee_Invoice__c> afis = [SELECT Id, Lead__c, Status__c, Policy_Information__c FROM Agency_Fee_Invoice__c WHERE QuickBooks_Invoice_ID__c = :invoiceId ORDER BY CreatedDate DESC LIMIT 1];
                if (!afis.isEmpty()) {
                    afis[0].Status__c = 'Paid';
                    update afis;
                    
                    // Create Payment Ledger Record
                    if (afis[0].Policy_Information__c != null) {
                        Financial_Ledger__c paymentLedger = new Financial_Ledger__c();
                        paymentLedger.Policy_Information__c = afis[0].Policy_Information__c;
                        paymentLedger.Type__c = 'Payment';
                        paymentLedger.Credit__c = amount;
                        paymentLedger.Debit__c = 0.00;
                        paymentLedger.Date_Time__c = DateTime.now();
                        paymentLedger.Status__c = 'Paid';
                        paymentLedger.Description__c = 'Payment received' + (String.isNotBlank(paymentMethod) ? ' via ' + paymentMethod : '');
                        if (String.isNotBlank(referenceNumber)) {
                            paymentLedger.Reference_Number__c = referenceNumber;
                        }
                        insert paymentLedger;
                    }
                }
                return 'SUCCESS';
            }
            String errBody = res.getBody();
            try {
                Map<String, Object> errResp = (Map<String, Object>) JSON.deserializeUntyped(errBody);
                Map<String, Object> fault = (Map<String, Object>) errResp.get('Fault');
                if (fault != null) {
                    List<Object> errors = (List<Object>) fault.get('Error');
                    if (errors != null && !errors.isEmpty()) {
                        Map<String, Object> firstErr = (Map<String, Object>) errors[0];
                        String msg = (String) firstErr.get('Message');
                        String detail = (String) firstErr.get('Detail');
                        return 'ERROR: ' + msg + (String.isNotBlank(detail) ? ' - ' + detail : '');
                    }
                }
            } catch(Exception e) {
                // fallback
            }
            return 'ERROR: ' + errBody.replace('{', '[').replace('}', ']');
        } catch (Exception e) {
            return 'CRITICAL ERROR: ' + e.getMessage();
        }
    }

    @future(callout=true)
    public static void createQBORefundFuture(Id leadId, Decimal amount) {
        String res = createQBORefund(leadId, amount);
        if (res != null && res.startsWith('ERROR')) {
            // Throw exception so it logs in Apex Jobs instead of failing silently
            throw new CalloutException('QBO Refund API Failed: ' + res);
        }
    }

    // --- Invoice Void ---
    // Async wrapper — safe to call after DML operations in the same transaction
    @future(callout=true)
    public static void voidQBOInvoiceFuture(String qboInvoiceId) {
        voidQBOInvoice(qboInvoiceId);
    }

    @future(callout=true)
    public static void voidQBOInvoicesFuture(Set<Id> invoiceIds) {
        List<Agency_Fee_Invoice__c> invoices = [
            SELECT QuickBooks_Invoice_ID__c 
            FROM Agency_Fee_Invoice__c 
            WHERE Id IN :invoiceIds AND QuickBooks_Invoice_ID__c != null
        ];
        for (Agency_Fee_Invoice__c inv : invoices) {
            voidQBOInvoice(inv.QuickBooks_Invoice_ID__c);
        }
    }

    // Voids a QuickBooks invoice by its QBO Invoice ID.
    // QBO requires fetching the current SyncToken first, then POSTing a void operation.
    public static String voidQBOInvoice(String qboInvoiceId) {
        try {
            if (String.isBlank(qboInvoiceId)) {
                System.debug('voidQBOInvoice: No QBO Invoice ID provided — skipping void.');
                return 'SKIPPED: No QBO Invoice ID';
            }

            Http http = new Http();

            // Step 1: GET current invoice to retrieve the required SyncToken
            HttpRequest getReq = new HttpRequest();
            getReq.setEndpoint('callout:' + activeSetting.Named_Credential__c
                + '/v3/company/' + activeSetting.Realm_ID__c
                + '/invoice/' + qboInvoiceId + '?minorversion=69');
            getReq.setMethod('GET');
            getReq.setHeader('Accept', 'application/json');

            HttpResponse getRes = http.send(getReq);
            if (getRes.getStatusCode() != 200) {
                System.debug('voidQBOInvoice GET failed: ' + getRes.getBody());
                return 'ERROR: Could not retrieve QBO invoice for void — ' + getRes.getBody();
            }

            Map<String, Object> getBody = (Map<String, Object>)JSON.deserializeUntyped(getRes.getBody());
            Map<String, Object> invObj = (Map<String, Object>)getBody.get('Invoice');
            if (invObj == null) {
                System.debug('voidQBOInvoice: Invoice object missing from GET response.');
                return 'ERROR: Invoice not found in QBO GET response.';
            }
            String syncToken = (String)invObj.get('SyncToken');

            // Step 2: POST void with sparse=true and operation=void
            Map<String, Object> voidPayload = new Map<String, Object>();
            voidPayload.put('Id', qboInvoiceId);
            voidPayload.put('SyncToken', syncToken);
            voidPayload.put('sparse', true);

            HttpRequest voidReq = new HttpRequest();
            voidReq.setEndpoint('callout:' + activeSetting.Named_Credential__c
                + '/v3/company/' + activeSetting.Realm_ID__c
                + '/invoice?operation=void&minorversion=69');
            voidReq.setMethod('POST');
            voidReq.setHeader('Accept', 'application/json');
            voidReq.setHeader('Content-Type', 'application/json');
            voidReq.setBody(JSON.serialize(voidPayload));

            HttpResponse voidRes = http.send(voidReq);
            if (voidRes.getStatusCode() == 200) {
                System.debug('voidQBOInvoice: Successfully voided QBO Invoice ID: ' + qboInvoiceId);
                return 'SUCCESS';
            }
            System.debug('voidQBOInvoice POST failed: ' + voidRes.getBody());
            return 'ERROR: QBO void failed — ' + voidRes.getBody();

        } catch (Exception e) {
            System.debug('CRITICAL ERROR in voidQBOInvoice: ' + e.getMessage() + ' — ' + e.getStackTraceString());
            return 'CRITICAL ERROR: ' + e.getMessage();
        }
    }



    @AuraEnabled
    public static String createQBORefund(Id leadId, Decimal amount) {
        try {
            // 1. Fetch QuickBooks Customer ID from any invoice under this Lead
            List<Agency_Fee_Invoice__c> invoices = [
                SELECT QuickBooks_Customer_ID__c 
                FROM Agency_Fee_Invoice__c 
                WHERE Lead__c = :leadId 
                  AND QuickBooks_Customer_ID__c != null 
                LIMIT 1
            ];
            
            if (invoices.isEmpty()) {
                return 'ERROR: No QuickBooks Customer ID found for this Lead.';
            }
            String customerId = invoices[0].QuickBooks_Customer_ID__c;
            
            // 2. Create RefundReceipt payload
            Map<String, Object> refund = new Map<String, Object>();
            refund.put('TotalAmt', amount);
            
            Map<String, Object> customerRef = new Map<String, Object>();
            customerRef.put('value', customerId);
            refund.put('CustomerRef', customerRef);
            
            List<Map<String, Object>> lines = new List<Map<String, Object>>();
            Map<String, Object> line = new Map<String, Object>();
            line.put('Amount', amount);
            line.put('Description', 'Agency Service Fee Refund');
            line.put('DetailType', 'SalesItemLineDetail');
            
            Map<String, Object> detail = new Map<String, Object>();
            Map<String, Object> itemRef = new Map<String, Object>();
            itemRef.put('value', '1'); // Generic Services Item
            itemRef.put('name', 'Services');
            detail.put('ItemRef', itemRef);
            line.put('SalesItemLineDetail', detail);
            lines.add(line);
            
            refund.put('Line', lines);
            refund.put('PrivateNote', 'Refund issued from Salesforce Lead ID: ' + leadId);
            
            // 2.5 Query QuickBooks to find the DepositToAccountRef from past payments
            String depositAccountId = null;
            Http http = new Http();
            HttpRequest queryReq = new HttpRequest();
            String queryStr = EncodingUtil.urlEncode('SELECT DepositToAccountRef FROM Payment WHERE CustomerRef = \'' + customerId + '\' MAXRESULTS 10', 'UTF-8');
            queryReq.setEndpoint('callout:' + activeSetting.Named_Credential__c + '/v3/company/' + activeSetting.Realm_ID__c + '/query?query=' + queryStr + '&minorversion=69');
            queryReq.setMethod('GET');
            queryReq.setHeader('Accept', 'application/json');
            
            HttpResponse queryRes = http.send(queryReq);
            if (queryRes.getStatusCode() == 200) {
                Map<String, Object> queryBody = (Map<String, Object>)JSON.deserializeUntyped(queryRes.getBody());
                Map<String, Object> queryResp = (Map<String, Object>)queryBody.get('QueryResponse');
                if (queryResp != null) {
                    List<Object> payments = (List<Object>)queryResp.get('Payment');
                    if (payments != null && !payments.isEmpty()) {
                        for (Object pObj : payments) {
                            Map<String, Object> pMap = (Map<String, Object>)pObj;
                            Map<String, Object> depRef = (Map<String, Object>)pMap.get('DepositToAccountRef');
                            if (depRef != null && depRef.get('value') != null) {
                                depositAccountId = (String)depRef.get('value');
                                break;
                            }
                        }
                    }
                }
            }
            
            // Fallback to any payment if the customer doesn't have one with a deposit account
            if (depositAccountId == null) {
                String fbQuery = EncodingUtil.urlEncode('SELECT DepositToAccountRef FROM Payment MAXRESULTS 1', 'UTF-8');
                queryReq.setEndpoint('callout:' + activeSetting.Named_Credential__c + '/v3/company/' + activeSetting.Realm_ID__c + '/query?query=' + fbQuery + '&minorversion=69');
                HttpResponse fbRes = http.send(queryReq);
                if (fbRes.getStatusCode() == 200) {
                    Map<String, Object> queryBody = (Map<String, Object>)JSON.deserializeUntyped(fbRes.getBody());
                    Map<String, Object> queryResp = (Map<String, Object>)queryBody.get('QueryResponse');
                    if (queryResp != null) {
                        List<Object> payments = (List<Object>)queryResp.get('Payment');
                        if (payments != null && !payments.isEmpty()) {
                            Map<String, Object> pMap = (Map<String, Object>)payments[0];
                            Map<String, Object> depRef = (Map<String, Object>)pMap.get('DepositToAccountRef');
                            if (depRef != null && depRef.get('value') != null) {
                                depositAccountId = (String)depRef.get('value');
                            }
                        }
                    }
                }
            }
            
            if (depositAccountId != null) {
                Map<String, Object> depRef = new Map<String, Object>();
                depRef.put('value', depositAccountId);
                refund.put('DepositToAccountRef', depRef);
            }
            
            // 3. Post to QuickBooks
            HttpRequest req = new HttpRequest();
            req.setEndpoint('callout:' + activeSetting.Named_Credential__c + '/v3/company/' + activeSetting.Realm_ID__c + '/refundreceipt?minorversion=69');
            req.setMethod('POST');
            req.setHeader('Accept', 'application/json');
            req.setHeader('Content-Type', 'application/json');
            req.setBody(JSON.serialize(refund));
            
            HttpResponse res = http.send(req);
            
            if (res.getStatusCode() == 200) {
                return 'SUCCESS';
            }
            return 'ERROR: Failed to create QBO refund - ' + res.getBody();
        } catch (Exception e) {
            return 'CRITICAL ERROR: ' + e.getMessage();
        }
    }

    @future(callout=true)
    public static void createQBOCreditMemoFuture(Id leadId, Id policyId, Decimal amount) {
        createQBOCreditMemo(leadId, policyId, amount);
    }

    @AuraEnabled
    public static String createQBOCreditMemo(Id leadId, Id policyId, Decimal amount) {
        try {
            // 1. Fetch QuickBooks Customer ID and Invoice ID
            List<Agency_Fee_Invoice__c> invoices = [
                SELECT QuickBooks_Customer_ID__c, QuickBooks_Invoice_ID__c
                FROM Agency_Fee_Invoice__c 
                WHERE Policy_Information__c = :policyId 
                  AND QuickBooks_Customer_ID__c != null 
                ORDER BY CreatedDate DESC LIMIT 1
            ];
            
            // Fallback to Lead if no invoice exists for this specific policy yet
            if (invoices.isEmpty()) {
                invoices = [
                    SELECT QuickBooks_Customer_ID__c, QuickBooks_Invoice_ID__c
                    FROM Agency_Fee_Invoice__c 
                    WHERE Lead__c = :leadId 
                      AND QuickBooks_Customer_ID__c != null 
                    ORDER BY CreatedDate DESC LIMIT 1
                ];
            }
            
            if (invoices.isEmpty()) {
                return 'ERROR: No QuickBooks Customer ID found for this Lead.';
            }
            
            String customerId = invoices[0].QuickBooks_Customer_ID__c;
            String invoiceId = invoices[0].QuickBooks_Invoice_ID__c;
            
            System.debug('--- QBO CREDIT MEMO START ---');
            System.debug('CustomerId: ' + customerId);
            System.debug('InvoiceId: ' + invoiceId);
            System.debug('Amount: ' + amount);
            
            // 2. Create CreditMemo payload
            Map<String, Object> creditMemo = new Map<String, Object>();
            creditMemo.put('TotalAmt', amount);
            
            Map<String, Object> customerRef = new Map<String, Object>();
            customerRef.put('value', customerId);
            creditMemo.put('CustomerRef', customerRef);
            
            List<Map<String, Object>> lines = new List<Map<String, Object>>();
            Map<String, Object> line = new Map<String, Object>();
            line.put('Amount', amount);
            line.put('Description', 'Agency Service Fee Credit');
            line.put('DetailType', 'SalesItemLineDetail');
            
            Map<String, Object> detail = new Map<String, Object>();
            Map<String, Object> itemRef = new Map<String, Object>();
            itemRef.put('value', '1'); // Generic Services Item
            itemRef.put('name', 'Services');
            detail.put('ItemRef', itemRef);
            line.put('SalesItemLineDetail', detail);
            lines.add(line);
            
            creditMemo.put('Line', lines);
            creditMemo.put('PrivateNote', 'Credit issued from Salesforce Lead ID: ' + leadId);
            
            // 3. Post CreditMemo to QuickBooks
            HttpRequest req = new HttpRequest();
            req.setEndpoint('callout:' + activeSetting.Named_Credential__c + '/v3/company/' + activeSetting.Realm_ID__c + '/creditmemo?minorversion=69');
            req.setMethod('POST');
            req.setHeader('Accept', 'application/json');
            req.setHeader('Content-Type', 'application/json');
            req.setBody(JSON.serialize(creditMemo));
            
            Http http = new Http();
            HttpResponse res = http.send(req);
            System.debug('CreditMemo Response Status: ' + res.getStatusCode());
            System.debug('CreditMemo Response Body: ' + res.getBody());
            
            if (res.getStatusCode() == 200) {
                // Parse the new CreditMemo ID
                Map<String, Object> body = (Map<String, Object>)JSON.deserializeUntyped(res.getBody());
                Map<String, Object> cmRes = (Map<String, Object>)body.get('CreditMemo');
                String creditMemoId = (String)cmRes.get('Id');
                
                // 4. If we have an Invoice ID, explicitly link the CreditMemo to the Invoice using a Payment object
                if (String.isNotBlank(invoiceId) && String.isNotBlank(creditMemoId)) {
                    Map<String, Object> payment = new Map<String, Object>();
                    payment.put('TotalAmt', 0);
                    payment.put('CustomerRef', new Map<String, Object>{'value' => customerId});
                    
                    List<Map<String, Object>> pmtLines = new List<Map<String, Object>>();
                    
                    // Invoice Line (Debit)
                    Map<String, Object> invLine = new Map<String, Object>();
                    invLine.put('Amount', amount);
                    invLine.put('LinkedTxn', new List<Map<String, Object>>{
                        new Map<String, Object>{
                            'TxnId' => invoiceId,
                            'TxnType' => 'Invoice'
                        }
                    });
                    pmtLines.add(invLine);
                    
                    // CreditMemo Line (Credit)
                    Map<String, Object> cmLine = new Map<String, Object>();
                    cmLine.put('Amount', amount);
                    cmLine.put('LinkedTxn', new List<Map<String, Object>>{
                        new Map<String, Object>{
                            'TxnId' => creditMemoId,
                            'TxnType' => 'CreditMemo'
                        }
                    });
                    pmtLines.add(cmLine);
                    
                    payment.put('Line', pmtLines);
                    
                    HttpRequest pmtReq = new HttpRequest();
                    pmtReq.setEndpoint('callout:' + activeSetting.Named_Credential__c + '/v3/company/' + activeSetting.Realm_ID__c + '/payment?minorversion=69');
                    pmtReq.setMethod('POST');
                    pmtReq.setHeader('Accept', 'application/json');
                    pmtReq.setHeader('Content-Type', 'application/json');
                    pmtReq.setBody(JSON.serialize(payment));
                    
                    HttpResponse pmtRes = http.send(pmtReq);
                    System.debug('Payment Response Status: ' + pmtRes.getStatusCode());
                    System.debug('Payment Response Body: ' + pmtRes.getBody());
                    
                    if (pmtRes.getStatusCode() != 200) {
                        System.debug('ERROR Linking Payment: ' + pmtRes.getBody());
                        return 'ERROR: Credit Memo created but failed to link to invoice - ' + pmtRes.getBody();
                    }
                    System.debug('Successfully linked CreditMemo and Invoice!');
                } else {
                    System.debug('Skipped linking because invoiceId or creditMemoId was blank. InvoiceId: ' + invoiceId + ' | CMId: ' + creditMemoId);
                }
                
                return 'SUCCESS';
            }
            return 'ERROR: Failed to create QBO credit memo - ' + res.getBody();
        } catch (Exception e) {
            System.debug('CRITICAL ERROR in createQBOCreditMemo: ' + e.getMessage() + ' - ' + e.getStackTraceString());
            return 'CRITICAL ERROR: ' + e.getMessage();
        }
    }
}