import { LightningElement, api, wire, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { encodeDefaultFieldValues } from 'lightning/pageReferenceUtils';
import { getRecordNotifyChange } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import getDashboardDetails from '@salesforce/apex/AccountDashboardController.getDashboardDetails';
import saveContactDetails from '@salesforce/apex/AccountDashboardController.saveContactDetails';
import saveAccountDetails from '@salesforce/apex/AccountDashboardController.saveAccountDetails';
import updateFileDetails from '@salesforce/apex/AccountDashboardController.updateFileDetails';
import getPolicies from '@salesforce/apex/AccountDashboardController.getPolicies';
import getCases from '@salesforce/apex/AccountDashboardController.getCases';
import getFiles from '@salesforce/apex/AccountDashboardController.getFiles';
import getTasks from '@salesforce/apex/AccountDashboardController.getTasks';
import getEvents from '@salesforce/apex/AccountDashboardController.getEvents';
import getEmails from '@salesforce/apex/AccountDashboardController.getEmails';
import getAmsPoliciesByAccount from '@salesforce/apex/AccountDashboardController.getAmsPoliciesByAccount';
import getNotes from '@salesforce/apex/AccountDashboardController.getNotes';
import createContentNote from '@salesforce/apex/AccountDashboardController.createContentNote';
import CONTENT_VERSION_OBJECT from '@salesforce/schema/ContentVersion';
import updateContentNote from '@salesforce/apex/AccountDashboardController.updateContentNote';

import { getObjectInfo } from 'lightning/uiObjectInfoApi';
import { getPicklistValues } from 'lightning/uiObjectInfoApi';
import ACCOUNT_OBJECT from '@salesforce/schema/Account';
import PARTNER_NAME_FIELD from '@salesforce/schema/Account.Partner_Name__c';
import CONTACT_OBJECT from '@salesforce/schema/Contact';
import MARITAL_STATUS_FIELD from '@salesforce/schema/Contact.Marital_Status__c';
import TYPE_FIELD from '@salesforce/schema/ContentVersion.Type__c';

const US_STATES = [
    { label: 'Alabama', value: 'AL' }, { label: 'Alaska', value: 'AK' }, { label: 'Arizona', value: 'AZ' },
    { label: 'Arkansas', value: 'AR' }, { label: 'California', value: 'CA' }, { label: 'Colorado', value: 'CO' },
    { label: 'Connecticut', value: 'CT' }, { label: 'Delaware', value: 'DE' }, { label: 'Florida', value: 'FL' },
    { label: 'Georgia', value: 'GA' }, { label: 'Hawaii', value: 'HI' }, { label: 'Idaho', value: 'ID' },
    { label: 'Illinois', value: 'IL' }, { label: 'Indiana', value: 'IN' }, { label: 'Iowa', value: 'IA' },
    { label: 'Kansas', value: 'KS' }, { label: 'Kentucky', value: 'KY' }, { label: 'Louisiana', value: 'LA' },
    { label: 'Maine', value: 'ME' }, { label: 'Maryland', value: 'MD' }, { label: 'Massachusetts', value: 'MA' },
    { label: 'Michigan', value: 'MI' }, { label: 'Minnesota', value: 'MN' }, { label: 'Mississippi', value: 'MS' },
    { label: 'Missouri', value: 'MO' }, { label: 'Montana', value: 'MT' }, { label: 'Nebraska', value: 'NE' },
    { label: 'Nevada', value: 'NV' }, { label: 'New Hampshire', value: 'NH' }, { label: 'New Jersey', value: 'NJ' },
    { label: 'New Mexico', value: 'NM' }, { label: 'New York', value: 'NY' }, { label: 'North Carolina', value: 'NC' },
    { label: 'North Dakota', value: 'ND' }, { label: 'Ohio', value: 'OH' }, { label: 'Oklahoma', value: 'OK' },
    { label: 'Oregon', value: 'OR' }, { label: 'Pennsylvania', value: 'PA' }, { label: 'Rhode Island', value: 'RI' },
    { label: 'South Carolina', value: 'SC' }, { label: 'South Dakota', value: 'SD' }, { label: 'Tennessee', value: 'TN' },
    { label: 'Texas', value: 'TX' }, { label: 'Utah', value: 'UT' }, { label: 'Vermont', value: 'VT' },
    { label: 'Virginia', value: 'VA' }, { label: 'Washington', value: 'WA' }, { label: 'West Virginia', value: 'WV' },
    { label: 'Wisconsin', value: 'WI' }, { label: 'Wyoming', value: 'WY' }
];

export default class AccountDetailLWC extends NavigationMixin(LightningElement) {
    @api recordId;
    @track account;
    @track primaryInsured;
    @track secondaryInsured;
    @track editedPrimaryInsured = {};
    @track editedSecondaryInsured = {};
    @track editedAccount = {};
    @track partnerNameOptions = [];
    @track activities = [];
    @track notes = [];
    @track maritalStatusOptions = [];
    @track isCreatingNote = false;
    @track isStepOne = true; 
    @track fileDescription = '';
    @track uploadedFileIds = [];
    @track fileType = '';
    @track typeOptions = [];
    @track isNoteEditMode = false;
    @track editingNoteId = null;
    newNoteTitle = '';
    newNoteBody = '';

    @track isEditingAbout = false;
    isPrimaryFromAccount = false;

    error;
    _wiredDetailsResult;

    policies = [];
    cases = [];
    files = [];
    tasks = [];
    events = [];

    showFileUploader = false;
    acceptedFormats = ['.pdf', '.png', '.jpg', '.jpeg', '.doc', '.docx'];

    @wire(getObjectInfo, { objectApiName: CONTACT_OBJECT })
    contactInfo;

    @wire(getPicklistValues, {
        recordTypeId: '$contactInfo.data.defaultRecordTypeId',
        fieldApiName: MARITAL_STATUS_FIELD
    })
    wiredMaritalStatus({ error, data }) {
        if (data) {
            this.maritalStatusOptions = data.values;
        }
    }

    @wire(getObjectInfo, { objectApiName: CONTENT_VERSION_OBJECT })
    contentVersionInfo;

    @wire(getPicklistValues, {
        recordTypeId: '$contentVersionInfo.data.defaultRecordTypeId',
        fieldApiName: TYPE_FIELD
    })
    wiredTypePicklist({ error, data }) {
        if (data) {
            this.typeOptions = data.values;
        } else if (error) {
            console.error('Error loading type picklist:', error);
        }
    }

    get stateOptions() {
        return US_STATES;
    }

    get uploadTitle() {
        return this.isStepOne ? 'Upload Files' : 'Add Description';
    }

    get uploadedFileCount() {
        return this.uploadedFileIds ? this.uploadedFileIds.length : 0;
    }

    get noteModalTitle() {
        return this.isNoteEditMode ? 'Edit Note' : 'New Note';
    }

    @wire(getDashboardDetails, { accountId: '$recordId' })
    wiredDetails(result) {
        this._wiredDetailsResult = result;
        if (result.data) {
            this.account = result.data.account;
            this.primaryInsured = result.data.primaryInsured;
            this.secondaryInsured = result.data.secondaryInsured;
            this.isPrimaryFromAccount = result.data.isPrimaryFromAccount;
            this.error = undefined;
            this.loadRelatedData();
        } else if (result.error) {
            this.handleError(result.error);
        }
    }

    @wire(getObjectInfo, { objectApiName: ACCOUNT_OBJECT })
    accountInfo;

    @wire(getPicklistValues, {
        recordTypeId: '$accountInfo.data.defaultRecordTypeId',
        fieldApiName: PARTNER_NAME_FIELD
    })
    wiredPartnerPicklist({ error, data }) {
        if (data) {
            this.partnerNameOptions = data.values.map(picklistValue => ({
                label: picklistValue.label,
                value: picklistValue.value
            }));
        } else if (error) {
            console.error('Error loading partner name picklist values:', error);
        }
    }

    get casesWithClass() {
        return (this.cases || []).map(c => ({
            ...c,
            statusClass: c.Status === 'Closed' ? 'status-closed' : 'status-open',
            commentCount: c.CaseComments ? c.CaseComments.length : 0
        }));
    }

    get limitedCases() {
    return this.casesWithClass || [];
}

get limitedPolicies() {
    return this.policies ? this.policies : [];
}

get limitedActivities() {
    return this.activities ? this.activities : [];
}

get limitedNotes() {
    return this.notes ? this.notes : [];
}

get limitedFiles() {
    return this.files ? this.files : [];
}

    get formattedInsuredPhoneLink() {
        return this.primaryInsured?.Phone ? `tel:${this.primaryInsured.Phone}` : null;
    }

    get formattedInsuredMobileLink() {
        return this.primaryInsured?.MobilePhone ? `tel:${this.primaryInsured.MobilePhone}` : null;
    }

    get formattedSecondInsuredPhoneLink() {
        return this.secondaryInsured?.Phone ? `tel:${this.secondaryInsured.Phone}` : null;
    }

    get formattedSecondInsuredMobileLink() {
        return this.secondaryInsured?.MobilePhone ? `tel:${this.secondaryInsured.MobilePhone}` : null;
    }

    get insuredAddress() {
        if (!this.primaryInsured) return '';
        const addr = this.primaryInsured;
        return [addr.MailingStreet, addr.MailingCity, addr.MailingState, addr.MailingPostalCode, addr.MailingCountry].filter(Boolean).join(', ');
    }

    get propertyAddress() {
        if (!this.secondaryInsured) return '';
        const addr = this.secondaryInsured;
        return [addr.OtherStreet, addr.OtherCity, addr.OtherState, addr.OtherPostalCode, addr.OtherCountry].filter(Boolean).join(', ');
    }

    get hasManyCases() {
        return Array.isArray(this.cases) && this.cases.length > 4;
    }

    get hasManyPolicies() {
        return Array.isArray(this.policies) && this.policies.length > 4;
    }

    get hasManyFiles() {
        return Array.isArray(this.files) && this.files.length > 4;
    }

    get hasManyNotes() {
        return Array.isArray(this.notes) && this.notes.length > 4;
    }

    get hasManyActivities() {
        return Array.isArray(this.activities) && this.activities.length > 4;
    }

    get primaryInsuredDOB() {
        return this.primaryInsured?.Birthdate ? this.formatDOB(this.primaryInsured.Birthdate) : '';
    }

    get secondaryInsuredDOB() {
        return this.secondaryInsured?.Birthdate ? this.formatDOB(this.secondaryInsured.Birthdate) : '';
    }

    formatDOB(dateStr) {
        if (!dateStr) return '';
        const [year, month, day] = dateStr.split('-');
        return `${month}/${day}/${year}`;
    }

    handleEditAbout() {
        const p = this.primaryInsured || {};
        const s = this.secondaryInsured || {};

        this.editedPrimaryInsured = {
            Id: p.Id,
            AccountId: this.recordId,
            Insured_Role__c: p.Insured_Role__c || 'First Insured',
            FirstName: p.FirstName,
            LastName: p.LastName,
            Phone: p.Phone,
            MobilePhone: p.MobilePhone,
            Email: p.Email,
            Birthdate: p.Birthdate,
            Occupation__c: p.Occupation__c,
            Marital_Status__c: p.Marital_Status__c,
            Drivers_License__c: p.Drivers_License__c,
            MailingStreet: p.MailingStreet,
            MailingCity: p.MailingCity,
            MailingState: p.MailingState,
            MailingPostalCode: p.MailingPostalCode,
            MailingCountry: p.MailingCountry
        };

        this.editedSecondaryInsured = {
            Id: s.Id,
            AccountId: this.recordId,
            Insured_Role__c: s.Insured_Role__c || 'Second Named Insured',
            FirstName: s.FirstName,
            LastName: s.LastName,
            Phone: s.Phone,
            MobilePhone: s.MobilePhone,
            Email: s.Email,
            Birthdate: s.Birthdate,
            Occupation__c: s.Occupation__c,
            Marital_Status__c: s.Marital_Status__c,
            Drivers_License__c: s.Drivers_License__c,
            OtherStreet: s.OtherStreet,
            OtherCity: s.OtherCity,
            OtherState: s.OtherState,
            OtherPostalCode: s.OtherPostalCode,
            OtherCountry: s.OtherCountry
        };

        this.editedAccount = {
            Id: this.account?.Id,
            Partner_Name__c: this.account?.Partner_Name__c,
            Referral_Source_Name__c: this.account?.Referral_Source_Name__c,
            vert__AMS360_First_Name__c: this.account?.vert__AMS360_First_Name__c,
            vert__AMS360_Last_Name__c: this.account?.vert__AMS360_Last_Name__c,
            vert__AMS360_Firm_Name__c: this.account?.vert__AMS360_Firm_Name__c,
            vert__Mobile_Phone__c: this.account?.vert__Mobile_Phone__c,
            vert__Other_Phone__c: this.account?.vert__Other_Phone__c,
            vert__AMS360_Company_Email_Address2__c: this.account?.vert__AMS360_Company_Email_Address2__c
        };

        this.isEditingAbout = true;
    }

    handleCancelAbout() {
        this.isEditingAbout = false;
    }

    handleNavigateToContact(event) {
    event.preventDefault();
    const contactId = event.currentTarget.dataset.id;
    
    if (contactId) {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: contactId,
                objectApiName: 'Contact',
                actionName: 'view'
            }
        });
    } else {
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Note',
                message: 'No separate contact record exists for this insured.',
                variant: 'info'
            })
        );
    }
}

    handleCopyNote(event) {
        event.stopPropagation();
        
        const content = event.target.dataset.content;

        if (!content) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Warning',
                message: 'Note body is empty.',
                variant: 'warning'
            }));
            return;
        }

        if (navigator.clipboard && navigator.clipboard.writeText) {
            navigator.clipboard.writeText(content)
                .then(() => {
                    this.dispatchEvent(new ShowToastEvent({
                        title: 'Success',
                        message: 'Note copied to clipboard.',
                        variant: 'success'
                    }));
                })
                .catch(err => {
                    console.error('Copy failed', err);
                    this.dispatchEvent(new ShowToastEvent({
                        title: 'Error',
                        message: 'Failed to copy note.',
                        variant: 'error'
                    }));
                });
        } else {
            // Fallback for older browsers or specific security contexts
            const textArea = document.createElement("textarea");
            textArea.value = content;
            document.body.appendChild(textArea);
            textArea.select();
            document.execCommand("copy");
            document.body.removeChild(textArea);
            
            this.dispatchEvent(new ShowToastEvent({
                title: 'Success',
                message: 'Note copied to clipboard.',
                variant: 'success'
            }));
        }
    }

    handleAboutChange(event) {
        const field = event.target.dataset.field;
        const recordType = event.target.dataset.record;
        const value = event.detail?.value !== undefined ? event.detail.value : event.target.value;

        if (recordType === 'primary') {
            this.editedPrimaryInsured[field] = value;
        } else if (recordType === 'secondary') {
            this.editedSecondaryInsured[field] = value;
        } else if (recordType === 'account') {
            this.editedAccount[field] = value;
        }
    }

handleSaveAbout() {
        const savePromises = [];

        const secondaryToSave = (this.editedSecondaryInsured.Id || this.editedSecondaryInsured.LastName)
            ? this.editedSecondaryInsured
            : null;

        if (this.isPrimaryFromAccount) {

            const fName = this.editedPrimaryInsured.FirstName || '';
            const lName = this.editedPrimaryInsured.LastName || '';
            const fullName = `${fName} ${lName}`.trim();
            this.editedAccount.Name = fullName;

            if (this.editedPrimaryInsured.FirstName !== undefined) {
                this.editedAccount.First_Name_FI__c = this.editedPrimaryInsured.FirstName;
                this.editedAccount.vert__AMS360_First_Name__c = this.editedPrimaryInsured.FirstName;
            }
            
            if (this.editedPrimaryInsured.LastName) {
                this.editedAccount.Last_Name_FI__c = this.editedPrimaryInsured.LastName;
                this.editedAccount.vert__AMS360_Last_Name__c = this.editedPrimaryInsured.LastName;
                this.editedAccount.vert__AMS360_Firm_Name__c = this.editedPrimaryInsured.LastName;
            }
            
            if (this.editedPrimaryInsured.Phone) {
                this.editedAccount.Phone = this.editedPrimaryInsured.Phone;
                this.editedAccount.vert__Mobile_Phone__c = this.editedPrimaryInsured.Phone;
            }
            if (this.editedPrimaryInsured.MobilePhone !== undefined) {
                this.editedAccount.Phone_2_FI__c = this.editedPrimaryInsured.MobilePhone;
                this.editedAccount.vert__Other_Phone__c = this.editedPrimaryInsured.MobilePhone;
            }
            if (this.editedPrimaryInsured.Email) {
                this.editedAccount.Email__c = this.editedPrimaryInsured.Email;
                this.editedAccount.vert__AMS360_Company_Email_Address2__c = this.editedPrimaryInsured.Email;
            }
            if (this.editedPrimaryInsured.Birthdate) {
                this.editedAccount.Insured_DOB__c = this.editedPrimaryInsured.Birthdate;
            }
            if (this.editedPrimaryInsured.Occupation__c !== undefined) {
                this.editedAccount.First_Insured_Occupation__c = this.editedPrimaryInsured.Occupation__c;
            }
            if (this.editedPrimaryInsured.Marital_Status__c !== undefined) {
                this.editedAccount.First_Insured_Marital_Status__c = this.editedPrimaryInsured.Marital_Status__c;
            }
            if (this.editedPrimaryInsured.Drivers_License__c !== undefined) {
                this.editedAccount.First_Insured_Driver_S_License__c = this.editedPrimaryInsured.Drivers_License__c;
            }

            this.editedAccount.BillingStreet = this.editedPrimaryInsured.MailingStreet;
            this.editedAccount.BillingCity = this.editedPrimaryInsured.MailingCity;
            this.editedAccount.BillingState = this.editedPrimaryInsured.MailingState;
            this.editedAccount.BillingPostalCode = this.editedPrimaryInsured.MailingPostalCode;
            this.editedAccount.BillingCountry = this.editedPrimaryInsured.MailingCountry;

            savePromises.push(saveAccountDetails({
                accountToUpdate: this.editedAccount
            }));

            if (this.editedPrimaryInsured.Id) {
                savePromises.push(saveContactDetails({
                    primaryContact: this.editedPrimaryInsured,
                    secondaryContact: secondaryToSave
                }));
            } else {
                savePromises.push(saveContactDetails({
                    primaryContact: null,
                    secondaryContact: secondaryToSave
                }));
            }

        } else {
            const primaryToSave = (this.editedPrimaryInsured.Id || this.editedPrimaryInsured.LastName)
                ? this.editedPrimaryInsured
                : null;

            savePromises.push(saveContactDetails({
                primaryContact: primaryToSave,
                secondaryContact: secondaryToSave
            }));

            savePromises.push(saveAccountDetails({
                accountToUpdate: this.editedAccount
            }));
        }

        Promise.all(savePromises)
            .then(() => {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Success',
                    message: 'Details updated.',
                    variant: 'success'
                }));
                this.isEditingAbout = false;

               setTimeout(() => {
                    window.location.reload();
                }, 1500);
            })
            .catch(error => {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Error Updating Records',
                    message: error.body?.message || error.message || 'Unknown error',
                    variant: 'error'
                }));
            });
    }

    loadRelatedData() {
        Promise.all([
            getPolicies({ accountId: this.recordId }),
            getCases({ accountId: this.recordId }),
            getFiles({ accountId: this.recordId }),
            getEvents({ accountId: this.recordId }),
            getTasks({ accountId: this.recordId }),
            getEmails({ accountId: this.recordId }),
            getAmsPoliciesByAccount({ accountId: this.recordId }),
            getNotes({ accountId: this.recordId })
        ])
            .then(([policies, cases, files, events, tasks, emails, amsPolicies, notes]) => {
                const amsRows = (amsPolicies || []).map(r => ({
                    Id: r.amsPolicy.Id,
                    policyNumber: r.amsPolicy.Name,
                    term:
                        (r.amsPolicy.vert__AMS360_Effective_Date__c
                            ? this.formatDateExact(r.amsPolicy.vert__AMS360_Effective_Date__c)
                            : ''
                        )
                        + ' - ' +
                        (r.amsPolicy.vert__AMS360_Expiration_Date__c
                            ? this.formatDateExact(r.amsPolicy.vert__AMS360_Expiration_Date__c)
                            : ''
                        ),
                    company: r.amsPolicy.vert__AMS360_Parent_Company__r?.Name || '',
                    type: r.businessLineItem || '',
                    status: r.amsPolicy.vert__AMS360_Policy_Status__c || '',
                    Executive: r.amsPolicy.vert__AMS360_Employee_Policy_Exec__r?.Name || '',
                    Description: r.amsPolicy.vert__AMS360_Description__c || '',
                    PolicyDecUrl: r.amsPolicy.vert__AMS360_Policy_Dec_Url__c || ''
                }));

                this.policies = amsRows.map(r => ({
                    ...r,
                    statusClass: 'status-active'
                }));

                this.cases = cases || [];
                this.files = (files || []).map((file, index) => ({
                    ...file,
                    serialNo: index + 1
                }));
                const uniqueNotes = Array.from(
                     new Map((notes || []).map(note => [note.Id, note])).values()
                );
                console.log('noteUnique'+uniqueNotes.length);
                
                this.notes = uniqueNotes.map((note, index) => ({
                    ...note,
                    serialNo: index + 1,
                    description: note.TextPreview
                }));

                
                
                console.log('NotesSIZE'+this.notes.length);

                this.mergeActivities({
                    events: events || [],
                    tasks: tasks || [],
                    emails: emails || []
                });
            })
            .catch(err => this.handleError(err));
    }

    openNoteModal() {
        this.newNoteTitle = '';
        this.newNoteBody = '';
        this.isNoteEditMode = false;
        this.editingNoteId = null;
        this.isCreatingNote = true;
    }

    closeNoteModal() {
        this.isCreatingNote = false;
    }

    handleNoteInput(event) {
        const field = event.target.dataset.field;
        if (field === 'title') this.newNoteTitle = event.target.value;
        if (field === 'body') this.newNoteBody = event.target.value;
    }

    handleEditNote(event) {
        const noteId = event.currentTarget.dataset.id;
        const noteToEdit = this.notes.find(n => n.Id === noteId);

        if (noteToEdit) {
            this.newNoteTitle = noteToEdit.Title;
            this.newNoteBody = noteToEdit.description;
            this.editingNoteId = noteId; 
            this.isNoteEditMode = true;
            this.isCreatingNote = true;
        }
    }

   handleSaveNote() {
        if (!this.newNoteTitle) {
            this.dispatchEvent(new ShowToastEvent({ title: 'Error', message: 'Title is required', variant: 'error' }));
            return;
        }

        if (this.isNoteEditMode) {
            updateContentNote({ 
                noteId: this.editingNoteId, 
                title: this.newNoteTitle, 
                body: this.newNoteBody,
                parentRecordId: this.recordId
            })
            .then(() => {
                this.dispatchEvent(new ShowToastEvent({ title: 'Success', message: 'Note updated.', variant: 'success' }));
                this.closeNoteModal();

                setTimeout(() => {
                    window.location.reload();
                }, 1000);
            })
            .catch(error => {
                this.dispatchEvent(new ShowToastEvent({ title: 'Error', message: error.body?.message || error.message, variant: 'error' }));
            });

        } else {
            createContentNote({ parentId: this.recordId, title: this.newNoteTitle, text: this.newNoteBody })
            .then(() => {
                this.dispatchEvent(new ShowToastEvent({ title: 'Success', message: 'Note created.', variant: 'success' }));
                this.closeNoteModal();

                setTimeout(() => {
                    window.location.reload();
                }, 1000);
            })
            .catch(error => {
                this.dispatchEvent(new ShowToastEvent({ title: 'Error', message: error.body?.message || error.message, variant: 'error' }));
            });
        }
    }

    refreshNotesList(result) {
        const uniqueNotes = Array.from(
                new Map((result || []).map(note => [note.Id, note])).values()
        );
        this.notes = uniqueNotes.map((note, index) => ({
            ...note,
            serialNo: index + 1,          
            description: note.TextPreview 
        }));
    }

    handleViewAllNotes() {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordRelationshipPage',
            attributes: {
                recordId: this.recordId,
                objectApiName: 'Account',
                relationshipApiName: 'AttachedContentNotes',
                actionName: 'view'
            }
        });
    }

    handleViewAllFiles() {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordRelationshipPage',
            attributes: {
                recordId: this.recordId,
                objectApiName: 'Account',
                relationshipApiName: 'AttachedContentDocuments',
                actionName: 'view'
            }
        });
    }
    handleViewAllPolicies() {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordRelationshipPage',
            attributes: {
                recordId: this.recordId,
                objectApiName: 'Account',
                relationshipApiName: 'vert__AMS360_Policies__r',
                actionName: 'view'
            }
        });
    }

    handleViewAllCases() {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordRelationshipPage',
            attributes: {
                recordId: this.recordId,
                objectApiName: 'Account',
                relationshipApiName: 'Cases',
                actionName: 'view'
            }
        });
    }

    handleViewAllActivities() {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordRelationshipPage',
            attributes: {
                recordId: this.recordId,
                objectApiName: 'Account',
                relationshipApiName: 'OpenActivities',
                actionName: 'view'
            }
        });
    }
    mergeActivities(activityMap) {
        const tasks = activityMap?.tasks || [];
        const events = activityMap?.events || [];
        const emails = activityMap?.emails || [];

        const normalized = [
            ...tasks.map(t => ({
                type: 'Task',
                typeLower: 'task',
                subject: t.Subject,
                description: t.Description,
                date: t.ActivityDate || t.CreatedDate,
                id: t.Id,
                ownerName: t.Owner?.Name
            })),
            ...events.map(e => ({
                type: 'Event',
                typeLower: 'event',
                subject: e.Subject,
                description: e.Description,
                date: e.StartDateTime || e.CreatedDate,
                id: e.Id,
                ownerName: e.Owner?.Name
            })),
            ...emails.map(m => ({
                type: 'Email',
                typeLower: 'email',
                subject: m.Subject,
                description: m.TextBody,
                date: m.MessageDate,
                id: m.Id,
                ownerName: m.FromName || 'System'
            }))
        ];

        this.activities = normalized.sort((a, b) => new Date(b.date) - new Date(a.date));
    }
    formatDateExact(dateStr) {
        if (!dateStr) return '';
        const [year, month, day] = dateStr.split('-');
        return `${month}/${day}/${year}`;
    }


    handleError(err) {
        this.error = err?.body?.message || err?.message || 'An unknown error occurred.';
        console.error('Error Details:', JSON.stringify(err));
    }

    handleEmailClick(event) {
        event.preventDefault();
        const email = event.currentTarget.dataset.email;
        if (!email) return;

        const pageRef = {
            type: 'standard__quickAction',
            attributes: { apiName: 'Global.SendEmail' },
            state: {
                recordId: this.recordId,
                defaultFieldValues: encodeDefaultFieldValues({
                    ToAddress: email,
                    Subject: `Regarding your account: ${this.account.Name}`
                })
            }
        };
        this[NavigationMixin.Navigate](pageRef);
    }

    handleNavigateToCase(event) {
        event.preventDefault();
        const caseId = event.currentTarget.dataset.id;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: caseId,
                objectApiName: 'Case',
                actionName: 'view'
            }
        });
    }
    handleNavigateToAMS360Policy(event) {
        event.preventDefault();
        const policyId = event.currentTarget.dataset.id;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: policyId,
                objectApiName: 'vert__AMS360_Policy__c',
                actionName: 'view'
            }
        });
    }
    handleNavigateToAMS360PolicyDec(event) {
        event.preventDefault();
        const policyUrl = event.currentTarget.dataset.id;
        if (policyUrl) {
            window.open(policyUrl, '_blank');
        }
    }

    handleCreateCase() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: { objectApiName: 'Case', actionName: 'new' },
            state: { defaultFieldValues: `AccountId=${this.recordId}` }
        });
    }

    handleAddPolicy = () => {
        const defaults = encodeDefaultFieldValues({ Account__c: this.recordId });
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: { objectApiName: 'Policy_Information__c', actionName: 'new' },
            state: { defaultFieldValues: defaults }
        });
    };

    handleAddTask = () => {
        const defaults = encodeDefaultFieldValues({ WhatId: this.recordId });
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: { objectApiName: 'Task', actionName: 'new' },
            state: { defaultFieldValues: defaults }
        });
    };

    handleAddEvent = () => {
        const defaults = encodeDefaultFieldValues({ WhatId: this.recordId });
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: { objectApiName: 'Event', actionName: 'new' },
            state: { defaultFieldValues: defaults }
        });
    };

   openFileUpload() { 
        this.fileDescription = '';
        this.fileType = '';
        this.uploadedFileIds = [];
        this.isStepOne = true; 
        this.showFileUploader = true; 
    }

    handleTypeChange(event) {
        this.fileType = event.detail.value;
    }

    handleSaveDetails() {
        // Calls the correct Apex method: updateFileDetails
        updateFileDetails({ 
            documentIds: this.uploadedFileIds, 
            description: this.fileDescription,
            fileType: this.fileType
        })
        .then(() => {
            this.dispatchEvent(new ShowToastEvent({ title: 'Success', message: 'File details saved successfully.', variant: 'success' }));
            this.handleFinish();
        })
        .catch(error => {
            console.error('Error saving details', error);
            this.dispatchEvent(new ShowToastEvent({ title: 'Error', message: 'Files uploaded, but details could not be saved.', variant: 'error' }));
            this.handleFinish();
        });
    }

    closeUploadModal() {
        this.showFileUploader = false;
    }

    handleUploadFinished(event) {
        const uploadedFiles = event.detail.files;
        if (uploadedFiles && uploadedFiles.length > 0) {
            this.uploadedFileIds = uploadedFiles.map(file => file.documentId);
            this.isStepOne = false; 
        }
    }

    handleDescriptionChange(event) {
        this.fileDescription = event.target.value;
    }

    handleFinish() {
        this.showFileUploader = false;
        getFiles({ accountId: this.recordId }).then(result => { 
            this.files = result || []; 
            setTimeout(() => { window.location.reload(); }, 1000);
        });
    }

    handleRowClick(event) {
        const recId = event.currentTarget.dataset.id;
        const type = event.currentTarget.dataset.type;
        let objectApiName;

        switch (type) {
            case 'policy':
                objectApiName = 'Policy_Information__c';
                break;
            case 'task':
                objectApiName = 'Task';
                break;
            case 'event':
                objectApiName = 'Event';
                break;
            case 'email':
                objectApiName = 'EmailMessage';
                break;

            case 'note':
                this[NavigationMixin.Navigate]({
                    type: 'standard__recordPage',
                    attributes: {
                        recordId: recId,
                        objectApiName: 'ContentNote',
                        actionName: 'view'
                    }
                });
                return;

            case 'file':
                const contentDocId = event.currentTarget.dataset.contentdocumentid;
                this[NavigationMixin.Navigate]({
                    type: 'standard__namedPage',
                    attributes: {
                        pageName: 'filePreview'
                    },
                    state: {
                        selectedRecordId: contentDocId
                    }
                });
                return;


            default:
                return;
        }

        if (recId && objectApiName) {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: recId,
                    objectApiName: objectApiName,
                    actionName: 'view'
                }
            });
        }
    }

    handlePreviewClick(event) {
        event.stopPropagation();
        const versionId = event.currentTarget.dataset.id;
        const row = event.currentTarget.closest('tr');
        const contentDocId = row.dataset.contentdocumentid;

        console.log('VersionId:', versionId, 'ContentDocId:', contentDocId);

        this[NavigationMixin.Navigate]({
            type: 'standard__namedPage',
            attributes: {
                pageName: 'filePreview'
            },
            state: {
                selectedRecordId: contentDocId || versionId
            }
        });
    }
}
