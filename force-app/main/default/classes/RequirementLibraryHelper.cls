public with sharing class RequirementLibraryHelper {
    
    public class LibraryItem {
        @AuraEnabled public String type { get; set; }
        @AuraEnabled public String category { get; set; }
        @AuraEnabled public String item { get; set; }
        @AuraEnabled public String details { get; set; }
        @AuraEnabled public Boolean isCommon { get; set; }

        public LibraryItem(String type, String category, String item, String details, Boolean isCommon) {
            this.type = type;
            this.category = category;
            this.item = item;
            this.details = details;
            this.isCommon = isCommon;
        }
    }

    private static List<LibraryItem> fullLibrary = new List<LibraryItem>{
        // COMMON ITEMS
        new LibraryItem('Photos', 'Property Photos', 'Roof Photos', 'Upload clear roof photos, including close-up photos showing condition, age, damage, missing shingles, moss, curling, or repairs.', true),
        new LibraryItem('Photos', 'Property Photos', 'Four-Side Exterior Photos', 'Upload clear photos of the front, rear, left side, and right side of the property.', true),
        new LibraryItem('Photos', 'Vehicle Photos', 'Vehicle Photos', 'Upload clear photos of the vehicle, including all four sides, VIN plate, odometer, and any existing damage.', true),
        new LibraryItem('Photos', 'Property Photos', 'Pool / Trampoline Photos', 'Upload photos showing the pool, trampoline, fencing, gate, safety features, and surrounding area.', true),
        
        new LibraryItem('Proof / Documents', 'Prior Insurance', 'Proof of Prior Insurance', 'Upload the prior declarations page showing carrier, policy term, limits, and continuous coverage.', true),
        new LibraryItem('Proof / Documents', 'Prior Insurance', 'Prior Dec Page', 'Upload the current or prior policy declarations page.', true),
        new LibraryItem('Proof / Documents', 'Prior Insurance', 'Proof of No Lapse', 'Upload documentation showing there was no lapse in coverage between policies.', true),
        new LibraryItem('Proof / Documents', 'Auto / Vehicle Proof', 'Proof of Good Student', 'Upload report card, transcript, or school portal screenshot showing eligibility.', true),
        new LibraryItem('Proof / Documents', 'Auto / Vehicle Proof', 'Mileage Verification', 'Upload a current odometer photo, mileage verification form, service record, inspection record, emissions record, or other documentation supporting annual mileage.', true),
        new LibraryItem('Proof / Documents', 'Auto / Vehicle Proof', 'Proof of Garaging Address', 'Upload registration, utility bill, lease, school address, employer letter, or other documentation supporting where the vehicle is primarily kept.', true),
        new LibraryItem('Proof / Documents', 'Auto / Vehicle Proof', 'Proof of Vehicle Ownership / VIN', 'Upload title, registration, bill of sale, lease agreement, VIN plate photo, or other documentation confirming ownership and VIN.', true),
        new LibraryItem('Proof / Documents', 'Home / Property Proof', 'Proof of Homeownership', 'Upload deed, mortgage statement, closing disclosure, tax record, or county property record.', true),
        new LibraryItem('Proof / Documents', 'Home / Property Proof', 'Proof of Roof Replacement / Roof Age', 'Upload paid invoice, permit, contractor letter, roof certification, inspection, prior dec page, or other documentation supporting roof replacement date or roof age.', true),
        new LibraryItem('Proof / Documents', 'Forms / Disclosures', 'Signed Forms / Disclosures', 'Upload the required signed carrier forms, applications, waivers, disclosures, or acknowledgments.', true),
        new LibraryItem('Proof / Documents', 'Inspection / Report Proof', 'Four-Point / Wind Mitigation / Inspection Report', 'Upload the required four-point inspection, wind mitigation inspection, roof inspection, home inspection, or carrier inspection report.', true),
        new LibraryItem('Proof / Documents', 'Mortgage / Closing Proof', 'Mortgage / Closing Document', 'Upload the mortgagee clause, Evidence of Insurance, Replacement Cost Estimator, paid receipt, loan number confirmation, or closing-related documentation.', true),
        new LibraryItem('Proof / Documents', 'Mortgage / Closing Proof', 'Proof of Payment / Billing', 'Upload the receipt, invoice, down payment confirmation, agency fee payment confirmation, escrow confirmation, or payment authorization.', true),

        new LibraryItem('Conversation / Disclosure', 'Coverage Conversation', 'Liability Limits Conversation', 'Discuss liability coverage limits with insured, notate conversation, and provide link to phone recording/conversation.', true),
        new LibraryItem('Conversation / Disclosure', 'Coverage Conversation', 'Coverage Limits Conversation', 'Discuss coverage limits with insured, notate conversation, and provide link to phone recording/conversation.', true),
        new LibraryItem('Conversation / Disclosure', 'Coverage Conversation', 'Deductible Amount', 'Discuss deductible amount with insured, notate conversation, and provide link to phone recording/conversation.', true),
        new LibraryItem('Conversation / Disclosure', 'Coverage Conversation', 'Coverage Limitation / Exclusion', 'Discuss applicable coverage limitation, exclusion, or declined coverage with insured, notate conversation, and provide link to phone recording/conversation.', true),
        new LibraryItem('Conversation / Disclosure', 'Driver / Auto Conversation', 'Household Drivers / Members', 'Confirm all household members, regular operators, youthful drivers, and excluded drivers have been discussed and documented.', true),
        new LibraryItem('Conversation / Disclosure', 'Billing / Fee Conversation', 'Agency Fee', 'Confirm the insured understands the agency fee amount, whether it is waived, and when payment is required.', true),

        new LibraryItem('Inspection / Repair', 'Inspection Reports', 'Four-Point Inspection', 'Upload a completed four-point inspection showing roof, electrical, plumbing, and HVAC condition.', true),
        new LibraryItem('Inspection / Repair', 'Inspection Reports', 'Wind Mitigation Inspection', 'Upload a completed wind mitigation inspection report.', true),
        new LibraryItem('Inspection / Repair', 'Inspection Reports', 'Roof Inspection / Certification', 'Upload a roof inspection or certification confirming roof condition, age, material, and remaining useful life.', true),
        new LibraryItem('Inspection / Repair', 'Repair / Mitigation', 'Repair / Mitigation Proof', 'Upload proof that the required repair or mitigation item was completed, including photos, contractor invoice, paid receipt, or completion letter.', true),

        new LibraryItem('Approval / Exception', 'Carrier / UW Action', 'Carrier UW Approval Required', 'Producer must contact carrier underwriting, obtain approval to proceed, notate the conversation, and provide the name of the underwriter, date/time of approval, and a link to the call recording, email, or supporting documentation.', true),
        new LibraryItem('Approval / Exception', 'Carrier / UW Action', 'Exception / Waiver Approval', 'Obtain carrier or management approval for the requested underwriting exception or waiver. Notate the approval details and attach or link any supporting documentation.', true),

        // FULL LIBRARY - Photos - Property Photos
        new LibraryItem('Photos', 'Property Photos', 'Roof Close-Up Photos', 'Upload close-up photos of the roof showing condition, age, material, moss, curling, missing shingles, or repairs.', false),
        new LibraryItem('Photos', 'Property Photos', 'Front Exterior Photo', 'Upload a clear photo of the front exterior of the property.', false),
        new LibraryItem('Photos', 'Property Photos', 'Rear Exterior Photo', 'Upload a clear photo of the rear exterior of the property.', false),
        new LibraryItem('Photos', 'Property Photos', 'Side Exterior Photos', 'Upload clear photos of the left and right sides of the property.', false),
        new LibraryItem('Photos', 'Property Photos', 'Detached Structure Photos', 'Upload photos of any detached garage, barn, shed, guest house, pool house, workshop, or other detached structure.', false),
        new LibraryItem('Photos', 'Property Photos', 'Garage / Carport Photos', 'Upload photos of the garage or carport showing structure type, condition, occupancy, and use.', false),
        new LibraryItem('Photos', 'Property Photos', 'Pool Photos', 'Upload photos of the pool, fencing, gate, diving board, slide, enclosure, screen cage, and overall condition.', false),
        new LibraryItem('Photos', 'Property Photos', 'Trampoline Photos', 'Upload photos of the trampoline, safety net, placement, and surrounding area.', false),
        new LibraryItem('Photos', 'Property Photos', 'Hot Tub / Spa Photos', 'Upload photos of the hot tub or spa, including cover, platform, and visible safety concerns.', false),
        new LibraryItem('Photos', 'Property Photos', 'Deck / Porch / Balcony Photos', 'Upload photos showing deck, porch, balcony, railing, stair, and structural condition.', false),
        new LibraryItem('Photos', 'Property Photos', 'Steps / Stairs Photos', 'Upload photos of exterior steps, stairs, handrails, and visible trip hazards.', false),
        new LibraryItem('Photos', 'Property Photos', 'Tree Overhang Photos', 'Upload photos showing trees touching or overhanging the roof, structure, garage, or power lines.', false),
        new LibraryItem('Photos', 'Property Photos', 'Siding / Exterior Wall Photos', 'Upload photos of siding, exterior wall condition, cracks, peeling paint, or missing materials.', false),
        new LibraryItem('Photos', 'Property Photos', 'Foundation Photos', 'Upload photos of foundation cracks, settlement, crawlspace entry, water intrusion signs, or other foundation concerns.', false),
        new LibraryItem('Photos', 'Property Photos', 'Electrical Panel Photo', 'Upload a clear photo of the electrical panel showing panel brand, breakers/fuses, condition, and visible amperage if available.', false),
        new LibraryItem('Photos', 'Property Photos', 'Plumbing Photos', 'Upload photos of visible plumbing, water heater, pipe material, corrosion, leaks, or plumbing concerns.', false),
        new LibraryItem('Photos', 'Property Photos', 'Heating System Photos', 'Upload photos of the furnace, boiler, heat pump, HVAC unit, or other heating system.', false),
        new LibraryItem('Photos', 'Property Photos', 'Wood Stove / Fireplace Photos', 'Upload photos of the wood stove, fireplace, chimney, hearth, and visible clearances.', false),
        new LibraryItem('Photos', 'Property Photos', 'Prior Damage Photos', 'Upload photos of existing damage, prior repairs, storm damage, or any unresolved condition concerns.', false),
        new LibraryItem('Photos', 'Property Photos', 'Renovation / Construction Photos', 'Upload photos showing current renovation or construction status, materials, open walls, occupancy status, and project stage.', false),
        new LibraryItem('Photos', 'Property Photos', 'Vacant Property Photos', 'Upload interior and exterior photos showing property condition, secured doors/windows, utilities, and signs of occupancy or vacancy.', false),
        new LibraryItem('Photos', 'Property Photos', 'Short-Term Rental Photos', 'Upload photos showing exterior, interior, pool/hot tub, safety devices, and rental setup.', false),
        new LibraryItem('Photos', 'Property Photos', 'Animal / Dog Photos', 'Upload photos supporting animal or dog breed verification, enclosure, fencing, or related exposure.', false),
        new LibraryItem('Photos', 'Property Photos', 'Signage Photos', 'Upload photos of commercial signage, business name, tenant sign, or required warning signs.', false),
        new LibraryItem('Photos', 'Property Photos', 'Fire Protection Photos', 'Upload photos of fire extinguishers, sprinklers, alarm panel, smoke detectors, or suppression system.', false),

        // Photos - Vehicle / Equipment
        new LibraryItem('Photos', 'Vehicle / Equipment Photos', 'Classic / Collector Vehicle Photos', 'Upload exterior, interior, engine bay, odometer, storage location, and restoration condition photos.', false),
        new LibraryItem('Photos', 'Vehicle / Equipment Photos', 'Recreational Vehicle Photos', 'Upload photos of the RV, motorcycle, ATV, snowmobile, camper, or trailer showing condition and identifying information.', false),
        new LibraryItem('Photos', 'Vehicle / Equipment Photos', 'Trailer Photos', 'Upload photos of the trailer condition, VIN plate, use, and attached equipment.', false),
        new LibraryItem('Photos', 'Vehicle / Equipment Photos', 'Boat / Watercraft Photos', 'Upload photos of the hull, motor, registration numbers, trailer, and storage location.', false),

        // Photos - Business / Commercial
        new LibraryItem('Photos', 'Business / Commercial Photos', 'Business Operations Photos', 'Upload commercial storefront, interior, signage, equipment, inventory, and public area photos.', false),
        new LibraryItem('Photos', 'Business / Commercial Photos', 'Commercial Building Photos', 'Upload exterior building, roof, parking lot, entrances, loading areas, and tenant space photos.', false),

        // FULL LIBRARY - Proof / Documents - Prior Insurance
        new LibraryItem('Proof / Documents', 'Prior Insurance', 'Proof of Prior Liability Insurance', 'Upload declarations page or coverage confirmation showing prior liability coverage carrier, limits, and policy term.', false),
        new LibraryItem('Proof / Documents', 'Prior Insurance', 'Proof of Continuous Coverage', 'Upload documentation confirming uninterrupted insurance coverage with no lapse between policies.', false),
        new LibraryItem('Proof / Documents', 'Prior Insurance', 'Proof of Loss History', 'Upload loss run or claims history from the prior carrier confirming claim dates, types, and amounts.', false),
        new LibraryItem('Proof / Documents', 'Prior Insurance', 'Loss Run Report', 'Upload a formal loss run report from the prior insurance carrier covering the requested period.', false),
        new LibraryItem('Proof / Documents', 'Prior Insurance', 'Non-Renewal / Cancellation Notice', 'Upload the non-renewal or cancellation notice from the prior carrier explaining the reason for termination.', false),
        new LibraryItem('Proof / Documents', 'Prior Insurance', 'Proof of New Policy Binding', 'Upload binder, cover note, or confirmation showing the new policy has been bound.', false),

        // Proof / Documents - Auto / Vehicle
        new LibraryItem('Proof / Documents', 'Auto / Vehicle Proof', 'Vehicle Registration', 'Upload the current vehicle registration confirming owner name, VIN, year, make, model, and address.', false),
        new LibraryItem('Proof / Documents', 'Auto / Vehicle Proof', 'Bill of Sale', 'Upload the bill of sale confirming vehicle purchase, buyer, seller, VIN, and date of sale.', false),
        new LibraryItem('Proof / Documents', 'Auto / Vehicle Proof', 'Lease Agreement', 'Upload the vehicle lease agreement confirming lessee, lessor, VIN, and term.', false),
        new LibraryItem('Proof / Documents', 'Auto / Vehicle Proof', 'Vehicle Title', 'Upload the certificate of title confirming ownership, VIN, year, make, and model.', false),
        new LibraryItem('Proof / Documents', 'Auto / Vehicle Proof', 'Odometer Reading / Mileage Photo', 'Upload a current odometer photo confirming mileage for annual mileage verification.', false),
        new LibraryItem('Proof / Documents', 'Auto / Vehicle Proof', 'Mileage Verification Form', 'Upload a signed mileage verification form supporting the stated annual mileage.', false),
        new LibraryItem('Proof / Documents', 'Auto / Vehicle Proof', 'Emissions / Inspection Record', 'Upload the state emissions or vehicle inspection record confirming mileage and vehicle condition.', false),
        new LibraryItem('Proof / Documents', 'Auto / Vehicle Proof', 'Employer Verification Letter', 'Upload an employer letter confirming employee work location and required vehicle use for garaging or mileage purposes.', false),
        new LibraryItem('Proof / Documents', 'Auto / Vehicle Proof', 'School Enrollment / Address Confirmation', 'Upload school enrollment document confirming student address, school location, and attendance status.', false),

        // Proof / Documents - Driver / Household
        new LibraryItem('Proof / Documents', 'Driver / Household Proof', 'Driver License Copy', 'Upload a clear copy of the driver license for the required household member or operator.', false),
        new LibraryItem('Proof / Documents', 'Driver / Household Proof', 'Driver Exclusion Form', 'Upload the signed driver exclusion form for the excluded household member or operator.', false),
        new LibraryItem('Proof / Documents', 'Driver / Household Proof', 'Proof of Separate Residence', 'Upload utility bill, lease, bank statement, or government mail confirming a household member resides at a different address.', false),
        new LibraryItem('Proof / Documents', 'Driver / Household Proof', 'Good Student Report Card', 'Upload official report card or transcript confirming GPA eligibility for good student discount.', false),
        new LibraryItem('Proof / Documents', 'Driver / Household Proof', 'Defensive Driving Course Certificate', 'Upload certificate of completion for an approved defensive driving or safe driver course.', false),
        new LibraryItem('Proof / Documents', 'Driver / Household Proof', 'MVR / Driving Record', 'Upload the official motor vehicle record from the state DMV for the required driver.', false),
        new LibraryItem('Proof / Documents', 'Driver / Household Proof', 'SR-22 Filing Confirmation', 'Upload confirmation that the SR-22 certificate of insurance has been filed with the state.', false),

        // Proof / Documents - Home / Property
        new LibraryItem('Proof / Documents', 'Home / Property Proof', 'Property Deed', 'Upload the recorded deed confirming legal ownership of the insured property.', false),
        new LibraryItem('Proof / Documents', 'Home / Property Proof', 'Tax Record / Property Record', 'Upload the county property tax record confirming ownership, property description, and assessed value.', false),
        new LibraryItem('Proof / Documents', 'Home / Property Proof', 'Closing Disclosure', 'Upload the closing disclosure from the purchase transaction confirming buyer, property, and purchase price.', false),
        new LibraryItem('Proof / Documents', 'Home / Property Proof', 'Lease Agreement (Property)', 'Upload the property lease agreement confirming tenant, landlord, property address, and term.', false),
        new LibraryItem('Proof / Documents', 'Home / Property Proof', 'Roof Replacement Invoice', 'Upload the contractor invoice for roof replacement confirming date, materials, contractor, and completion.', false),
        new LibraryItem('Proof / Documents', 'Home / Property Proof', 'Roof Permit', 'Upload the building permit for roof replacement confirming issue date, scope of work, and approval.', false),
        new LibraryItem('Proof / Documents', 'Home / Property Proof', 'Roof Certification', 'Upload the roof certification from a licensed contractor confirming roof condition, age, materials, and remaining useful life.', false),
        new LibraryItem('Proof / Documents', 'Home / Property Proof', 'Home Purchase Agreement', 'Upload the executed purchase agreement confirming buyer, seller, property, and closing date.', false),
        new LibraryItem('Proof / Documents', 'Home / Property Proof', 'Electrical Upgrade Permit / Invoice', 'Upload documentation confirming electrical panel upgrade, rewiring, or system update.', false),
        new LibraryItem('Proof / Documents', 'Home / Property Proof', 'Plumbing Upgrade Documentation', 'Upload documentation confirming plumbing upgrades, pipe replacement, or system updates.', false),
        new LibraryItem('Proof / Documents', 'Home / Property Proof', 'Heating System Service Record', 'Upload service record, inspection report, or maintenance documentation for the heating system.', false),

        // Proof / Documents - Inspection / Report
        new LibraryItem('Proof / Documents', 'Inspection / Report Proof', 'General Home Inspection Report', 'Upload a full home inspection report from a licensed inspector confirming overall property condition.', false),
        new LibraryItem('Proof / Documents', 'Inspection / Report Proof', 'Electrical Inspection Report', 'Upload an electrical inspection report from a licensed electrician or inspector.', false),
        new LibraryItem('Proof / Documents', 'Inspection / Report Proof', 'Plumbing Inspection Report', 'Upload a plumbing inspection report from a licensed plumber or inspector.', false),
        new LibraryItem('Proof / Documents', 'Inspection / Report Proof', 'Roof Inspection Report', 'Upload a roof inspection report from a licensed roofer or inspector confirming condition and age.', false),
        new LibraryItem('Proof / Documents', 'Inspection / Report Proof', 'Pool Inspection Report', 'Upload a pool inspection report confirming equipment condition, safety devices, and compliance.', false),

        // Proof / Documents - Mortgage / Closing
        new LibraryItem('Proof / Documents', 'Mortgage / Closing Proof', 'Mortgagee Clause Confirmation', 'Upload the mortgagee clause with lender name, address, and loan number for the evidence of insurance.', false),
        new LibraryItem('Proof / Documents', 'Mortgage / Closing Proof', 'Loan Number Confirmation', 'Upload confirmation of the mortgage loan number from the lender for inclusion on the policy.', false),
        new LibraryItem('Proof / Documents', 'Mortgage / Closing Proof', 'Evidence of Insurance (EOI)', 'Upload the completed evidence of insurance or binder letter required by the lender or closing agent.', false),
        new LibraryItem('Proof / Documents', 'Mortgage / Closing Proof', 'Replacement Cost Estimator (RCE)', 'Upload the replacement cost estimator or report used to determine the dwelling coverage amount.', false),
        new LibraryItem('Proof / Documents', 'Mortgage / Closing Proof', 'Paid Receipt / Down Payment Confirmation', 'Upload the paid receipt, down payment confirmation, or agency fee payment documentation.', false),
        new LibraryItem('Proof / Documents', 'Mortgage / Closing Proof', 'Escrow Confirmation', 'Upload confirmation that insurance premium is escrowed with the mortgage lender.', false),

        // Proof / Documents - Commercial
        new LibraryItem('Proof / Documents', 'Commercial Proof', 'Business License', 'Upload the current business license or certificate of authority confirming legal business operation.', false),
        new LibraryItem('Proof / Documents', 'Commercial Proof', 'Articles of Incorporation / Organization', 'Upload articles of incorporation, articles of organization, or state formation documents.', false),
        new LibraryItem('Proof / Documents', 'Commercial Proof', 'Certificate of Good Standing', 'Upload the state-issued certificate of good standing confirming the business is in active, compliant status.', false),
        new LibraryItem('Proof / Documents', 'Commercial Proof', 'FEIN / EIN Confirmation', 'Upload IRS confirmation of the Federal Employer Identification Number (FEIN/EIN).', false),
        new LibraryItem('Proof / Documents', 'Commercial Proof', 'Payroll / Revenue Documentation', 'Upload payroll records, tax returns, financial statements, or other documentation supporting stated payroll or revenue.', false),
        new LibraryItem('Proof / Documents', 'Commercial Proof', 'Contract / Client Agreement', 'Upload executed contracts, client agreements, or scopes of work supporting stated operations.', false),
        new LibraryItem('Proof / Documents', 'Commercial Proof', 'Certificate of Insurance (COI)', 'Upload the certificate of insurance issued to a third party, additional insured, or certificate holder.', false),
        new LibraryItem('Proof / Documents', 'Commercial Proof', 'Additional Insured Request', 'Upload the additional insured request, endorsement, or written agreement supporting the AI addition.', false),
        new LibraryItem('Proof / Documents', 'Commercial Proof', 'Waiver of Subrogation Request', 'Upload the waiver of subrogation request or contract requirement supporting the endorsement.', false),
        new LibraryItem('Proof / Documents', 'Commercial Proof', 'Workers Compensation Exemption', 'Upload the state-issued workers compensation exemption certificate.', false),
        new LibraryItem('Proof / Documents', 'Commercial Proof', 'Subcontractor Agreement / COI', 'Upload subcontractor agreements and certificates of insurance confirming subcontractor coverage.', false),

        // Proof / Documents - Forms / Disclosures
        new LibraryItem('Proof / Documents', 'Forms / Disclosures', 'Carrier Application', 'Upload the signed carrier insurance application.', false),
        new LibraryItem('Proof / Documents', 'Forms / Disclosures', 'Coverage Rejection / Waiver Form', 'Upload the signed form rejecting or waiving the offered coverage.', false),
        new LibraryItem('Proof / Documents', 'Forms / Disclosures', 'Uninsured / Underinsured Motorist Rejection', 'Upload the signed UM/UIM rejection or selection form as required by state.', false),
        new LibraryItem('Proof / Documents', 'Forms / Disclosures', 'PIP / Med Pay Election or Rejection', 'Upload the signed PIP or Medical Payments election or rejection form.', false),
        new LibraryItem('Proof / Documents', 'Forms / Disclosures', 'Named Non-Owner Form', 'Upload the signed named non-owner policy application or endorsement request.', false),
        new LibraryItem('Proof / Documents', 'Forms / Disclosures', 'Homeowner Warranty / Guarantee', 'Upload the builder warranty, home warranty plan, or roof guarantee documentation.', false),

        // FULL LIBRARY - Conversation / Disclosure - Coverage Conversation
        new LibraryItem('Conversation / Disclosure', 'Coverage Conversation', 'Policy Limits Discussion', 'Confirm policy limits have been discussed with the insured and notate the conversation.', false),
        new LibraryItem('Conversation / Disclosure', 'Coverage Conversation', 'Replacement Cost vs. Actual Cash Value', 'Confirm whether replacement cost or actual cash value coverage was explained and selected.', false),
        new LibraryItem('Conversation / Disclosure', 'Coverage Conversation', 'Flood Coverage Conversation', 'Discuss flood coverage availability, NFIP options, private flood, and the insured\'s decision. Notate conversation.', false),
        new LibraryItem('Conversation / Disclosure', 'Coverage Conversation', 'Earthquake Coverage Conversation', 'Discuss earthquake coverage availability and the insured\'s decision. Notate conversation.', false),
        new LibraryItem('Conversation / Disclosure', 'Coverage Conversation', 'Water Backup Coverage Conversation', 'Discuss water backup and sewer coverage availability and the insured\'s election or rejection.', false),
        new LibraryItem('Conversation / Disclosure', 'Coverage Conversation', 'Scheduled Personal Property Conversation', 'Discuss whether the insured has jewelry, art, collectibles, or other high-value items needing scheduled coverage.', false),
        new LibraryItem('Conversation / Disclosure', 'Coverage Conversation', 'Umbrella / Excess Liability Conversation', 'Discuss umbrella or excess liability coverage availability and the insured\'s decision.', false),
        new LibraryItem('Conversation / Disclosure', 'Coverage Conversation', 'Gap Coverage Conversation', 'Discuss GAP insurance availability for the financed or leased vehicle and the insured\'s decision.', false),
        new LibraryItem('Conversation / Disclosure', 'Coverage Conversation', 'Rental Reimbursement Conversation', 'Discuss rental reimbursement coverage availability and the insured\'s election or rejection.', false),
        new LibraryItem('Conversation / Disclosure', 'Coverage Conversation', 'Roadside Assistance Conversation', 'Discuss roadside assistance coverage availability and the insured\'s election or rejection.', false),
        new LibraryItem('Conversation / Disclosure', 'Coverage Conversation', 'New Car Replacement Conversation', 'Discuss new car replacement coverage for recently purchased vehicles and the insured\'s decision.', false),

        // Conversation / Disclosure - Exclusion / Limitation
        new LibraryItem('Conversation / Disclosure', 'Exclusion / Limitation Conversation', 'Named Exclusion Conversation', 'Discuss a specific named exclusion on the policy with the insured. Notate conversation and provide link to recording.', false),
        new LibraryItem('Conversation / Disclosure', 'Exclusion / Limitation Conversation', 'Coverage Reduction Conversation', 'Confirm that a coverage reduction or downgrade was discussed with the insured and the insured\'s decision was documented.', false),
        new LibraryItem('Conversation / Disclosure', 'Exclusion / Limitation Conversation', 'Wind / Hail Exclusion Conversation', 'Discuss wind and/or hail exclusion or separate deductible with insured. Notate conversation.', false),
        new LibraryItem('Conversation / Disclosure', 'Exclusion / Limitation Conversation', 'Mold / Fungi Exclusion Conversation', 'Discuss mold and fungi exclusion or limited coverage with insured. Notate conversation.', false),
        new LibraryItem('Conversation / Disclosure', 'Exclusion / Limitation Conversation', 'Business Pursuits Exclusion Conversation', 'Discuss the exclusion of business pursuits or home-based business activities with the insured.', false),
        new LibraryItem('Conversation / Disclosure', 'Exclusion / Limitation Conversation', 'Animal / Dog Exclusion Conversation', 'Discuss the animal or dog liability exclusion with the insured and document their acknowledgment.', false),
        new LibraryItem('Conversation / Disclosure', 'Exclusion / Limitation Conversation', 'Trampoline / Pool Exclusion Conversation', 'Discuss any trampoline, pool, or recreational equipment exclusions or surcharges with the insured.', false),

        // Conversation / Disclosure - Driver / Auto
        new LibraryItem('Conversation / Disclosure', 'Driver / Auto Conversation', 'Excluded Driver Conversation', 'Discuss the driver exclusion with the insured, confirm understanding, and document the conversation.', false),
        new LibraryItem('Conversation / Disclosure', 'Driver / Auto Conversation', 'Youthful Driver Conversation', 'Discuss youthful driver inclusion, impact on premium, required discounts, and any documentation needed.', false),
        new LibraryItem('Conversation / Disclosure', 'Driver / Auto Conversation', 'Usage / Mileage Conversation', 'Discuss annual mileage, vehicle use type, and garaging address with insured and document responses.', false),
        new LibraryItem('Conversation / Disclosure', 'Driver / Auto Conversation', 'Rideshare / TNC Conversation', 'Discuss rideshare or TNC use and any applicable endorsement or exclusion.', false),
        new LibraryItem('Conversation / Disclosure', 'Driver / Auto Conversation', 'SR-22 / FR-44 Conversation', 'Discuss SR-22 or FR-44 filing requirement, duration, and cost with the insured.', false),

        // Conversation / Disclosure - Property Risk
        new LibraryItem('Conversation / Disclosure', 'Property Risk Conversation', 'Pool / Trampoline Safety Conversation', 'Discuss pool and/or trampoline safety requirements, fencing, locking gates, and carrier requirements.', false),
        new LibraryItem('Conversation / Disclosure', 'Property Risk Conversation', 'Roof Condition Conversation', 'Discuss roof condition, age, material, planned replacement, and carrier requirements with insured.', false),
        new LibraryItem('Conversation / Disclosure', 'Property Risk Conversation', 'Occupancy Conversation', 'Discuss occupancy type (primary, secondary, seasonal, rental, vacant) and verify carrier eligibility.', false),
        new LibraryItem('Conversation / Disclosure', 'Property Risk Conversation', 'Short-Term Rental Conversation', 'Discuss short-term rental or vacation rental activities, frequency, platform, and required coverage.', false),
        new LibraryItem('Conversation / Disclosure', 'Property Risk Conversation', 'Home Business / Office Conversation', 'Discuss home-based business or office operations and confirm no business exclusion applies.', false),
        new LibraryItem('Conversation / Disclosure', 'Property Risk Conversation', 'Animal / Dog Breed Conversation', 'Discuss the animal or dog breed, bite history, and any exclusion or denial that applies.', false),

        // Conversation / Disclosure - Billing / Fee
        new LibraryItem('Conversation / Disclosure', 'Billing / Fee Conversation', 'Payment Plan Conversation', 'Discuss available payment plan options, down payment amount, installment schedule, and fees.', false),
        new LibraryItem('Conversation / Disclosure', 'Billing / Fee Conversation', 'EFT / Autopay Setup Conversation', 'Confirm EFT or autopay enrollment, bank account or card information authorization, and confirmation.', false),
        new LibraryItem('Conversation / Disclosure', 'Billing / Fee Conversation', 'Returned Payment / NSF Conversation', 'Discuss returned payment or NSF situation, fees, reinstatement, and resolution with insured.', false),
        new LibraryItem('Conversation / Disclosure', 'Billing / Fee Conversation', 'Premium Increase Conversation', 'Discuss policy premium increase at renewal or endorsement with insured and document acknowledgment.', false),

        // Conversation / Disclosure - Commercial
        new LibraryItem('Conversation / Disclosure', 'Commercial Conversation', 'Business Operations Conversation', 'Discuss business operations, services, products, revenue, employees, and exposures with the insured.', false),
        new LibraryItem('Conversation / Disclosure', 'Commercial Conversation', 'Additional Insured Conversation', 'Discuss additional insured requests, contractual requirements, and endorsement details.', false),
        new LibraryItem('Conversation / Disclosure', 'Commercial Conversation', 'Workers Compensation Conversation', 'Discuss workers compensation requirements, exemptions, payroll, and coverage options.', false),

        // FULL LIBRARY - Inspection / Repair
        new LibraryItem('Inspection / Repair', 'Inspection Reports', 'Carrier Inspection Report', 'Upload the completed carrier-ordered property inspection report.', false),
        new LibraryItem('Inspection / Repair', 'Inspection Reports', 'Interior Home Inspection', 'Upload a full interior inspection report from a licensed inspector.', false),
        new LibraryItem('Inspection / Repair', 'Inspection Reports', 'Electrical Inspection Report', 'Upload the electrical system inspection report from a licensed electrician or inspector.', false),
        new LibraryItem('Inspection / Repair', 'Inspection Reports', 'Plumbing Inspection Report', 'Upload the plumbing system inspection report from a licensed plumber or inspector.', false),
        new LibraryItem('Inspection / Repair', 'Inspection Reports', 'HVAC Inspection Report', 'Upload the HVAC system inspection report confirming equipment condition and service history.', false),
        new LibraryItem('Inspection / Repair', 'Inspection Reports', 'Pool / Spa Inspection Report', 'Upload the pool or spa inspection report confirming equipment, safety, and compliance.', false),
        new LibraryItem('Inspection / Repair', 'Inspection Reports', 'Commercial Property Inspection Report', 'Upload the commercial property inspection report from a certified inspector.', false),
        new LibraryItem('Inspection / Repair', 'Repair / Mitigation', 'Electrical Repair Proof', 'Upload invoice, permit, and before/after photos confirming completion of required electrical repair.', false),
        new LibraryItem('Inspection / Repair', 'Repair / Mitigation', 'Plumbing Repair Proof', 'Upload invoice, permit, and before/after photos confirming completion of required plumbing repair.', false),
        new LibraryItem('Inspection / Repair', 'Repair / Mitigation', 'Roof Repair Proof', 'Upload invoice, permit, and photos confirming completion of required roof repair or replacement.', false),
        new LibraryItem('Inspection / Repair', 'Repair / Mitigation', 'Deck / Structural Repair Proof', 'Upload invoice, permit, and photos confirming completion of deck, balcony, or structural repair.', false),
        new LibraryItem('Inspection / Repair', 'Repair / Mitigation', 'Foundation Repair Proof', 'Upload engineering report, invoice, warranty, and photos confirming foundation repair or stabilization.', false),
        new LibraryItem('Inspection / Repair', 'Repair / Mitigation', 'Tree Removal / Trimming Proof', 'Upload invoice or photos confirming tree trimming or removal to address overhanging roof or structure concern.', false),
        new LibraryItem('Inspection / Repair', 'Repair / Mitigation', 'Pool Fencing / Gate Repair Proof', 'Upload invoice or photos confirming pool fencing, locking gate, or enclosure repair or installation.', false),
        new LibraryItem('Inspection / Repair', 'Repair / Mitigation', 'Hurricane Shutter / Opening Protection Proof', 'Upload invoice, permit, or photos confirming hurricane shutters or opening protection installation.', false),
        new LibraryItem('Inspection / Repair', 'Repair / Mitigation', 'Chimney / Fireplace Repair Proof', 'Upload invoice or photos confirming chimney cleaning, liner installation, or fireplace repair.', false),
        new LibraryItem('Inspection / Repair', 'Repair / Mitigation', 'Heating System Replacement Proof', 'Upload invoice, permit, and photos confirming replacement or upgrade of the heating system.', false),

        // Inspection / Repair - additional repair types
        new LibraryItem('Inspection / Repair', 'Repair / Mitigation', 'Roof Replacement Proof', 'Upload contractor invoice, permit, and photos confirming full roof replacement was completed.', false),
        new LibraryItem('Inspection / Repair', 'Repair / Mitigation', 'Mold / Remediation Proof', 'Upload remediation report, invoice, clearance testing, and photos confirming mold remediation was completed.', false),
        new LibraryItem('Inspection / Repair', 'Repair / Mitigation', 'Siding / Exterior Repair Proof', 'Upload invoice, permit, and photos confirming siding, stucco, or exterior wall repair or replacement.', false),
        new LibraryItem('Inspection / Repair', 'Repair / Mitigation', 'Foundation Stabilization / Engineering Report', 'Upload engineering evaluation, repair plan, invoice, and photos confirming foundation stabilization work.', false),
        new LibraryItem('Inspection / Repair', 'Repair / Mitigation', 'Steps / Handrail Repair Proof', 'Upload invoice or photos confirming exterior steps, stair, or handrail repair or replacement.', false),
        new LibraryItem('Inspection / Repair', 'Repair / Mitigation', 'Trampoline Removal Proof', 'Upload invoice or photos confirming trampoline removal from the insured property.', false),
        new LibraryItem('Inspection / Repair', 'Repair / Mitigation', 'Dog / Animal Fence Proof', 'Upload invoice or photos confirming enclosure, fence, or containment installation for the animal.', false),
        new LibraryItem('Inspection / Repair', 'Repair / Mitigation', 'Wood Stove / Fireplace Repair Proof', 'Upload invoice, permit, and photos confirming chimney, liner, or fireplace repair or installation.', false),
        new LibraryItem('Inspection / Repair', 'Repair / Mitigation', 'Knob & Tube / Aluminum Wiring Remediation', 'Upload electrician invoice, permit, and photos confirming removal or remediation of the identified wiring.', false),

        // Inspection / Repair - additional inspection types
        new LibraryItem('Inspection / Repair', 'Inspection Reports', 'Mold / Air Quality Inspection Report', 'Upload the mold or air quality inspection report from a certified inspector.', false),
        new LibraryItem('Inspection / Repair', 'Inspection Reports', 'Structural / Engineering Inspection Report', 'Upload the structural or engineering inspection report from a licensed engineer.', false),
        new LibraryItem('Inspection / Repair', 'Inspection Reports', 'Chimney / Fireplace Inspection Report', 'Upload the chimney or fireplace inspection report from a certified chimney sweep or inspector.', false),
        new LibraryItem('Inspection / Repair', 'Inspection Reports', 'Pest / WDO Inspection Report', 'Upload the wood-destroying organism (WDO) or pest inspection report confirming treatment and clearance.', false),
        new LibraryItem('Inspection / Repair', 'Inspection Reports', 'Septic / Sewer Inspection Report', 'Upload the septic or sewer line inspection report confirming system condition and compliance.', false),

        // Photos - additional property photos missing from spec
        new LibraryItem('Photos', 'Property Photos', 'Water Heater Photos', 'Upload photos of the water heater showing type, age, condition, and visible corrosion or leaks.', false),
        new LibraryItem('Photos', 'Property Photos', 'Security Camera / System Photos', 'Upload photos of security cameras, alarm panel, or monitoring system showing coverage and equipment.', false),
        new LibraryItem('Photos', 'Property Photos', 'Fence / Gate Photos', 'Upload photos of fencing, gates, and enclosures showing condition, height, and locking mechanism.', false),
        new LibraryItem('Photos', 'Property Photos', 'Mold / Water Damage Photos', 'Upload photos showing water staining, mold growth, active leaks, or water intrusion areas.', false),
        new LibraryItem('Photos', 'Property Photos', 'Knob & Tube / Aluminum Wiring Photos', 'Upload photos of identified knob & tube or aluminum wiring in the electrical system.', false),

        // Approval / Exception - full library additional items
        new LibraryItem('Approval / Exception', 'Carrier / UW Action', 'Binding Authority Exception', 'Obtain management or carrier approval for a risk that falls outside standard binding authority. Document approval with name, date, and reference number.', false),
        new LibraryItem('Approval / Exception', 'Carrier / UW Action', 'Premium Finance Approval', 'Obtain carrier or management approval to bind using premium financing. Attach signed finance agreement.', false),
        new LibraryItem('Approval / Exception', 'Carrier / UW Action', 'Named Exclusion Approval', 'Obtain carrier or management approval to issue a policy with a named exclusion. Document the approval chain.', false),
        new LibraryItem('Approval / Exception', 'Carrier / UW Action', 'High-Value Property Exception', 'Obtain carrier UW approval to bind a high-value property or item exceeding standard guidelines.', false),
        new LibraryItem('Approval / Exception', 'Carrier / UW Action', 'Lapse in Coverage Exception', 'Obtain carrier or management approval to bind despite a lapse in prior coverage. Notate reason and approval details.', false),
        new LibraryItem('Approval / Exception', 'Management Approval', 'Agency Manager Approval', 'Obtain agency manager sign-off for the exception, coverage, or action requiring elevated authorization. Document in the producer notes.', false),
        new LibraryItem('Approval / Exception', 'Management Approval', 'Fee Waiver Approval', 'Obtain manager approval to waive the agency fee for this transaction. Document reason and approver in notes.', false),
        new LibraryItem('Approval / Exception', 'Management Approval', 'Backdating / Effective Date Exception', 'Obtain manager or carrier approval to backdate or adjust the effective date outside standard guidelines.', false),

        // Conversation / Disclosure - additional items from spec
        new LibraryItem('Conversation / Disclosure', 'Coverage Conversation', 'Service Line Coverage Conversation', 'Discuss service line coverage availability for underground utility lines and the insured\'s election or rejection.', false),
        new LibraryItem('Conversation / Disclosure', 'Coverage Conversation', 'Identity Theft Coverage Conversation', 'Discuss identity theft or cyber coverage availability and the insured\'s election or rejection.', false),
        new LibraryItem('Conversation / Disclosure', 'Coverage Conversation', 'Equipment Breakdown Coverage Conversation', 'Discuss equipment breakdown or mechanical breakdown coverage and the insured\'s election or rejection.', false),
        new LibraryItem('Conversation / Disclosure', 'Coverage Conversation', 'Monoline vs. Package Conversion Conversation', 'Discuss the benefits of moving from monoline to a package policy with the insured.', false),
        new LibraryItem('Conversation / Disclosure', 'Coverage Conversation', 'Non-Renewal Conversation', 'Discuss the non-renewal of the policy with the insured, explain the reason, and document next steps.', false),
        new LibraryItem('Conversation / Disclosure', 'Coverage Conversation', 'Renewal / Premium Change Conversation', 'Discuss the renewal premium change, coverage modifications, and the insured\'s decision to renew or shop.', false),
        new LibraryItem('Conversation / Disclosure', 'Driver / Auto Conversation', 'At-Fault Accident Conversation', 'Discuss impact of an at-fault accident on premium, surcharge period, and available discounts with insured.', false),
        new LibraryItem('Conversation / Disclosure', 'Driver / Auto Conversation', 'DUI / Major Violation Conversation', 'Discuss the impact of a DUI or major violation on eligibility, premium, SR-22 requirement, and coverage options.', false),
        new LibraryItem('Conversation / Disclosure', 'Property Risk Conversation', 'Knob & Tube / Aluminum Wiring Conversation', 'Discuss the identified wiring concern with the insured, carrier requirements, and required remediation steps.', false),
        new LibraryItem('Conversation / Disclosure', 'Property Risk Conversation', 'Vacancy / Extended Absence Conversation', 'Discuss vacancy clause, extended absence provisions, and any required endorsements with the insured.', false),
        new LibraryItem('Conversation / Disclosure', 'Billing / Fee Conversation', 'Agency Fee Waiver Conversation', 'Confirm with insured that the agency fee is being waived and document the reason and approver.', false),

        // Items from search keyword spec
        new LibraryItem('Proof / Documents', 'Auto / Vehicle Proof', 'Annual Mileage Verification', 'Upload a current odometer photo or service record supporting the stated annual mileage for the policy term.', false),
        new LibraryItem('Proof / Documents', 'Driver / Household Proof', 'Proof of Student Away at School', 'Upload documentation confirming the student resides more than 100 miles from the garaging address without a vehicle.', false),
        new LibraryItem('Proof / Documents', 'Driver / Household Proof', 'Proof of Driver Training', 'Upload certificate of completion for an approved driver training or driver education course.', false),
        new LibraryItem('Proof / Documents', 'Prior Insurance', 'Proof of Claim Closure', 'Upload documentation from the prior carrier confirming the claim has been closed with no further payment pending.', false),
        new LibraryItem('Proof / Documents', 'Prior Insurance', 'Proof of Repairs After Claim', 'Upload paid invoices and photos confirming that repairs related to the prior claim have been fully completed.', false),
        new LibraryItem('Conversation / Disclosure', 'Coverage Conversation', 'Umbrella / Excess Liability Discussion', 'Discuss the availability and benefits of an umbrella or excess liability policy with the insured.', false),

        // 25 Additional items to reach ~234+ total
        new LibraryItem('Photos', 'Business / Commercial Photos', 'Inventory / Stock Photos', 'Upload photos of the business inventory, stock, storage areas, and high-value equipment.', false),
        new LibraryItem('Photos', 'Business / Commercial Photos', 'Commercial Kitchen / Cooking Area', 'Upload photos of the commercial cooking area showing suppression system, hood, filters, and deep fryers.', false),
        new LibraryItem('Photos', 'Property Photos', 'Parking Lot / Sidewalk Condition', 'Upload photos showing condition of the parking lot, sidewalks, and any visible trip/slip hazards.', false),
        new LibraryItem('Photos', 'Property Photos', 'Neighboring Exposure Photos', 'Upload photos showing the proximity and nature of neighboring buildings or exposures.', false),
        
        new LibraryItem('Proof / Documents', 'Home / Property Proof', 'Lead Paint Disclosure / Certification', 'Upload the signed lead-based paint disclosure or lead-free certification for the property.', false),
        new LibraryItem('Proof / Documents', 'Home / Property Proof', 'Radon Test Results', 'Upload the radon test results confirming acceptable levels or mitigation status.', false),
        new LibraryItem('Proof / Documents', 'Home / Property Proof', 'Sinkhole Inspection / Engineering Report', 'Upload the sinkhole evaluation or engineering report confirming property stability.', false),
        new LibraryItem('Proof / Documents', 'Home / Property Proof', 'Termite / WDO Treatment Warranty', 'Upload the termite treatment contract and active warranty for the property.', false),
        new LibraryItem('Proof / Documents', 'Forms / Disclosures', 'Deductible Buy-Back Form', 'Upload the signed selection or rejection form for the deductible buy-back coverage.', false),
        new LibraryItem('Proof / Documents', 'Forms / Disclosures', 'Named Storm / Hurricane Deductible Form', 'Upload the signed form acknowledging the specific named storm or hurricane deductible.', false),
        new LibraryItem('Proof / Documents', 'Forms / Disclosures', 'Windstorm Selection / Rejection Form', 'Upload the signed form for windstorm coverage selection or rejection in catastrophe-prone areas.', false),
        new LibraryItem('Proof / Documents', 'Commercial Proof', 'Liquor Liability Operations Proof', 'Upload documentation supporting liquor sales, licensing, and server training certification.', false),
        new LibraryItem('Proof / Documents', 'Commercial Proof', 'Professional Liability / E&O Proof', 'Upload documentation supporting professional operations, licensing, and prior E&O coverage.', false),
        
        new LibraryItem('Conversation / Disclosure', 'Coverage Conversation', 'Cyber Liability Conversation', 'Discuss cyber liability exposure and the available coverage options with the insured.', false),
        new LibraryItem('Conversation / Disclosure', 'Coverage Conversation', 'Employment Practices Liability (EPLI)', 'Discuss EPLI coverage availability and benefits for the business owner.', false),
        new LibraryItem('Conversation / Disclosure', 'Coverage Conversation', 'Hired / Non-Owned Auto Conversation', 'Discuss exposure for hired or non-owned vehicles used in business operations.', false),
        new LibraryItem('Conversation / Disclosure', 'Driver / Auto Conversation', 'Speeding Violation Conversation', 'Discuss impact of speeding violations on policy eligibility and premium with the insured.', false),
        new LibraryItem('Conversation / Disclosure', 'Driver / Auto Conversation', 'Distracted Driving Conversation', 'DiscussDistracted driving violation impact and carrier safety requirements with the insured.', false),
        new LibraryItem('Conversation / Disclosure', 'Property Risk Conversation', 'Wood Burning Stove Safety', 'Discuss specific safety, clearance, and cleaning requirements for the wood-burning stove.', false),
        new LibraryItem('Conversation / Disclosure', 'Property Risk Conversation', 'Solar Panel / Net Metering Conversation', 'Discuss the solar panel installation, roof impact, and net metering agreement with the insured.', false),
        
        new LibraryItem('Inspection / Repair', 'Inspection Reports', 'Lead Paint Inspection Report', 'Upload the lead paint inspection report from a certified professional.', false),
        new LibraryItem('Inspection / Repair', 'Inspection Reports', 'Radon Mitigation System Inspection', 'Upload the inspection or service record for the active radon mitigation system.', false),
        new LibraryItem('Inspection / Repair', 'Repair / Mitigation', 'Lead Abatement Proof', 'Upload documentation confirming lead paint abatement has been completed by a certified contractor.', false),
        new LibraryItem('Inspection / Repair', 'Repair / Mitigation', 'Radon Mitigation Installation Proof', 'Upload the invoice and photos confirming installation of a radon mitigation system.', false),
        new LibraryItem('Inspection / Repair', 'Repair / Mitigation', 'Asbestos Remediation Proof', 'Upload documentation confirming asbestos removal or encapsulation by a certified professional.', false),

new LibraryItem('Conversation / Disclosure', 'Coverage Conversation', 'Wind/Hail Deductible', 'Confirm the client understands the separate wind/hail deductible and how it applies; notate conversation and provide link to phone recording/conversation.', false),
new LibraryItem('Conversation / Disclosure', 'Coverage Conversation', 'Hurricane Deductible', 'Confirm the client understands the hurricane deductible, including whether it is percentage-based; notate conversation and provide link to phone recording/conversation.', false),
new LibraryItem('Conversation / Disclosure', 'Coverage Conversation', 'Roof Settlement', 'Confirm the client understands any roof settlement limitation, roof payment schedule, cosmetic exclusion, or ACV roof provision.', false),
new LibraryItem('Conversation / Disclosure', 'Coverage Conversation', 'Ordinance or Law', 'Confirm the client understands the ordinance or law coverage limit and the potential exposure for older homes or buildings.', false),


new LibraryItem('Conversation / Disclosure', 'Exclusion/Limitation Conversation', 'Sewer/Drain Backup Exclusion', 'Confirm the client understands the exclusion if coverage is declined or unavailable.', false)
    };



    public static List<LibraryItem> getCommonItems(String reqType) {
        List<LibraryItem> results = new List<LibraryItem>();
        for (LibraryItem li : fullLibrary) {
            if (li.isCommon && (String.isBlank(reqType) || li.type == reqType)) {
                results.add(li);
            }
        }
        return results;
    }

    public static List<LibraryItem> searchLibrary(String keyword) {
        if (String.isBlank(keyword)) return fullLibrary;
        String kw = keyword.toLowerCase();
        List<LibraryItem> results = new List<LibraryItem>();
        for (LibraryItem li : fullLibrary) {
            if (li.item.toLowerCase().contains(kw) || li.category.toLowerCase().contains(kw) || li.details.toLowerCase().contains(kw)) {
                results.add(li);
            }
        }
        return results;
    }
}