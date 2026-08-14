public with sharing class GayaServiceNew02 {

    public class Request {
        @InvocableVariable(required=true)
        public Id leadId;
    }

    public class Response {
        @InvocableVariable
        public String result;
    }

    @InvocableMethod(label='Send Lead to Gaya')
    public static List<Response> sendLeadToGaya(List<Request> requests) {
        List<Response> responses = new List<Response>();

        if (requests == null || requests.isEmpty()) {
            return responses;
        }

        for (Request reqInput : requests) {
            try {
                if (reqInput == null || reqInput.leadId == null) {
                    Response badResponse = new Response();
                    badResponse.result = 'Skipped: Lead Id is null.';
                    responses.add(badResponse);
                    continue;
                }

                // Safe Lead query using List to avoid QueryException
                List<Lead> leadList = [
                    SELECT
                        FirstName, LastName, Email,
                        Insured_Address__Street__s, Insured_Address__City__s,
                        Insured_Address__StateCode__s, Insured_Address__PostalCode__s,
                        Borrowers_Phone_Number__c, Phone_2__c,
                        Borrower_DOB__c, First_Insured_Occupation__c,
                        Education__c, Marital_Status_FI__c,
                        Driver_s_License__c, Drivers_License_State__c,
                        Second_Insured_First_Name__c, Second_Insured_Last_Name__c,
                        Relationship_to_Insured__c, Second_Insured_Email__c,
                        Second_Insured_Phone_1__c, Second_Insured_Phone_2__c,
                        Second_Insureds_DOB__c, Second_Insured_Occupation__c,
                        Second_Insured_Education__c, Marital_Status_SI__c,
                        Second_Insured_Drivers_License__c,
                        Second_Insured_Drivers_License_State__c,
                        Street, City, State, PostalCode,
                        Property_Type__c, Coverage_Form__c
                    FROM Lead
                    WHERE Id = :reqInput.leadId
                    LIMIT 1
                ];

                if (leadList.isEmpty()) {
                    Response badResponse = new Response();
                    badResponse.result = 'Skipped: Lead not found for Id: ' + reqInput.leadId;
                    responses.add(badResponse);
                    continue;
                }

                Lead l = leadList[0];

                // Vehicle__c
                List<Vehicle__c> vehicles = [
                    SELECT
                        Vehicle_Type__c, Make__c, Model__c, Year__c,
                        Purchase_Year__c, VIN__c, Annual_Miles__c,
                        Lienholder__c, Registered_To__c,
                        Registered_To__r.Driver_Full_Name__c
                    FROM Vehicle__c
                    WHERE Lead__c = :reqInput.leadId
                ];

                // Properties__c — now also selecting Address fields
                List<Properties__c> properties = [
                    SELECT Id, Property_Type__c, Coverage_Form__c,
                           Loan__c, Mortgagee_Clause__c,
                           Address__Street__s, Address__City__s,
                           Address__StateCode__s, Address__PostalCode__s,
                           Estimated_Closing_Date__c
                    FROM Properties__c
                    WHERE Lead__c = :reqInput.leadId
                ];

                // ── FIX: Query Property_Information__c DIRECTLY by Lead__c ──────────────
                // Root cause confirmed: Property_Information__c records have Lead__c set
                // but Properties__c lookup is null, so the old WHERE Properties__c IN
                // :propertyIds query returned 0 rows and the entire property section
                // was silently skipped.
                List<Property_Information__c> allPropInfos = [
                    SELECT
                        Properties__c, Lead__c,
                        X3_4_Bath__c, Age_of_Dwelling__c,
                        Alarm_System__c, Any_smokers_in_the_Household__c,
                        Auxiliary_Heat_Type__c, Community__c, Complete__c,
                        Construction__c, Distance_to_Coastline__c,
                        Diving_Board__c, Exterior_Paint__c, Fence_2__c,
                        Fence__c, Foundation_Type__c, Full_Bath__c,
                        Hail_Resistive_Roof__c, Half_Bath__c,
                        Heating_Year__c, Heating_Type__c, Is_Hot_Tub__c,
                        Hot_Tub_on_Premises__c, Is_Alarm_System__c,
                        Is_Animal__c, Locked__c, Locked_Secure_Cover__c,
                        Members_in_Household__c, Net__c,
                        Number_of_Families__c, Number_of_Mortgages__c,
                        Number_of_Roof_Layers__c, Number_of_Stories__c,
                        Partial__c, Plumbing__c, Plumbing_Year__c,
                        Is_Pool__c, Primary_Heat_Type__c,
                        Purchased_Rental_Date__c,
                        Removable_Retracting_Locking__c, Roof_ACV__c,
                        Roof_Shape__c, Roof_Type__c, Roof_Yr__c,
                        Slide__c, Square_Footage__c,
                        Swimming_Pool_on_Premises__c, Is_Trampoline__c,
                        Winning__c, Wiring_Year__c, Year_Built__c
                    FROM Property_Information__c
                    WHERE Lead__c = :reqInput.leadId
                ];

                // Build propInfoByPropId for leads that DO have Properties__c records
                // with the lookup correctly set
                Map<Id, Property_Information__c> propInfoByPropId = new Map<Id, Property_Information__c>();
                for (Property_Information__c pi : allPropInfos) {
                    if (pi.Properties__c != null && !propInfoByPropId.containsKey(pi.Properties__c)) {
                        propInfoByPropId.put(pi.Properties__c, pi);
                    }
                }

                System.debug(LoggingLevel.ERROR, '🏠 PROPERTY DEBUG: properties count = ' + properties.size());
                System.debug(LoggingLevel.ERROR, '🏠 PROPERTY DEBUG: allPropInfos count = ' + allPropInfos.size());
                System.debug(LoggingLevel.ERROR, '🏠 PROPERTY DEBUG: propInfoByPropId size = ' + propInfoByPropId.size());

                // Prior_Insurance_Information__c
                List<Prior_Insurance_Information__c> homePolicies = [
                    SELECT
                        Bodily_Injury_Limits__c, Carrier_Name__c,
                        Carrier_Name_Link__c, Expiration_Date__c,
                        Length_of_Continuous_Coverage__c,
                        Length_with_Current_Carrier__c, Line__c,
                        Policy_Number__c, Premium__c
                    FROM Prior_Insurance_Information__c
                    WHERE Lead__c = :reqInput.leadId
                ];

                // Driver__c
                List<Driver__c> drivers = [
                    SELECT
                        First_Name__c, Last_Name__c, Date_of_Birth__c,
                        DL__c, Education__c, State__c, Marital_Status__c,
                        Occupation__c, Relationship_to_Insured__c,
                        Driver_Full_Name__c
                    FROM Driver__c
                    WHERE Lead__c = :reqInput.leadId
                ];

                // Home_Losses_Claims__c
                List<Home_Losses_Claims__c> losses = [
                    SELECT
                        Amount_Paid__c, Carrier__c, Catastrophic_Related__c,
                        Cause_of_Loss__c, Claim_Status__c, Date_of_Loss__c,
                        Description__c, Policy_Type__c, Property_Liability__c,
                        Risk_Address__c, Weather_Related__c
                    FROM Home_Losses_Claims__c
                    WHERE Lead__c = :reqInput.leadId
                ];

                // Auto_Incidents_Violations__c
                List<Auto_Incidents_Violations__c> accidentsViolations = [
                    SELECT
                        Additional_Information__c, Carrier__c, Date__c,
                        Incident_Description__c, Operator__c,
                        Operator__r.Driver_Full_Name__c
                    FROM Auto_Incidents_Violations__c
                    WHERE Lead__c = :reqInput.leadId
                ];

                // ── Build entities list ───────────────────────────────────────────────────

                List<Object> entitiesList = new List<Object>();

                // ── Customer ─────────────────────────────────────────────────────────────
                List<Object> customerFields = new List<Object>();
                addField(customerFields, 'first_name', l.FirstName);
                addField(customerFields, 'last_name', l.LastName);
                addField(customerFields, 'email', l.Email);
                addField(customerFields, 'address_1', buildAddress(l));
                addField(customerFields, 'phone_number', l.Borrowers_Phone_Number__c);
                addField(customerFields, 'secondary_phone', l.Phone_2__c);
                addField(customerFields, 'date_of_birth', formatDate(l.Borrower_DOB__c));
                addField(customerFields, 'occupation', l.First_Insured_Occupation__c);
                addField(customerFields, 'education', l.Education__c);
                addField(customerFields, 'marital_status', l.Marital_Status_FI__c);
                addField(customerFields, 'license_number', l.Driver_s_License__c);
                addField(customerFields, 'driver_license_state', l.Drivers_License_State__c);

                if (!customerFields.isEmpty()) {
                    entitiesList.add(new Map<String, Object>{
                        'entity' => 'customer',
                        'index'  => 1,
                        'fields' => customerFields
                    });
                }

                // ── Household ─────────────────────────────────────────────────────────────
                List<Object> householdFields = new List<Object>();
                addField(householdFields, 'first_name', l.Second_Insured_First_Name__c);
                addField(householdFields, 'last_name', l.Second_Insured_Last_Name__c);
                addField(householdFields, 'relationship', l.Relationship_to_Insured__c);
                addField(householdFields, 'email', l.Second_Insured_Email__c);
                addField(householdFields, 'phone_number', l.Second_Insured_Phone_1__c);
                addField(householdFields, 'secondary_phone', l.Second_Insured_Phone_2__c);
                addField(householdFields, 'date_of_birth', formatDate(l.Second_Insureds_DOB__c));
                addField(householdFields, 'occupation', l.Second_Insured_Occupation__c);
                addField(householdFields, 'education', l.Second_Insured_Education__c);
                addField(householdFields, 'marital_status', l.Marital_Status_SI__c);
                addField(householdFields, 'license_number', l.Second_Insured_Drivers_License__c);
                addField(householdFields, 'driver_license_state', l.Second_Insured_Drivers_License_State__c);

                if (!householdFields.isEmpty()) {
                    entitiesList.add(new Map<String, Object>{
                        'entity' => 'household',
                        'index'  => 2,
                        'fields' => householdFields
                    });
                }

                // ── Property ──────────────────────────────────────────────────────────────
                // CASE A: No Properties__c records exist for this Lead (confirmed root cause).
                // Property_Information__c records exist but their Properties__c lookup is null.
                // Or neither exists.
                // We must use the Lead's standard Address and Property fields.
                
                List<Object> baseLeadPropertyFields = new List<Object>();
                addField(baseLeadPropertyFields, 'property_type', l.Property_Type__c);
                addField(baseLeadPropertyFields, 'coverage_form', l.Coverage_Form__c);
                if (!String.isBlank(l.Street))     addField(baseLeadPropertyFields, 'address_1', l.Street.trim());
                if (!String.isBlank(l.City))       addField(baseLeadPropertyFields, 'city', l.City.trim());
                if (!String.isBlank(l.State))      addField(baseLeadPropertyFields, 'state', l.State.trim());
                if (!String.isBlank(l.PostalCode)) addField(baseLeadPropertyFields, 'zip_code', l.PostalCode.trim());
                if (properties.isEmpty()) {
                    if (!allPropInfos.isEmpty()) {
                        Integer propertyIndex = 1;
                        for (Property_Information__c pi : allPropInfos) {
                            List<Object> propertyFields = new List<Object>();
                            
                            if (propertyIndex == 1) {
                                propertyFields.addAll(baseLeadPropertyFields);
                            }

                            addField(propertyFields, 'number_of_3_4_bath', pi.X3_4_Bath__c);
                        addField(propertyFields, 'dwelling_age', pi.Age_of_Dwelling__c);
                        addField(propertyFields, 'alarm_system_type', pi.Alarm_System__c);
                        addBoolField(propertyFields, 'any_smokers_in_the_household', pi.Any_smokers_in_the_Household__c);
                        addField(propertyFields, 'auxiliary_heat_type', pi.Auxiliary_Heat_Type__c);
                        addField(propertyFields, 'secured_community', pi.Community__c);
                        addBoolField(propertyFields, 'do_you_have_a_completed_building_code_certificate', pi.Complete__c);
                        addField(propertyFields, 'construction_style', pi.Construction__c);
                        addField(propertyFields, 'distance_to_coastline_miles', pi.Distance_to_Coastline__c);
                        addBoolField(propertyFields, 'pool_diving_board', pi.Diving_Board__c);
                        addField(propertyFields, 'exterior_paint_renovation_year', pi.Exterior_Paint__c);
                        addBoolField(propertyFields, 'pool_fence', pi.Fence_2__c);
                        addBoolField(propertyFields, 'approved_fence', pi.Fence__c);
                        addField(propertyFields, 'foundation_type', pi.Foundation_Type__c);
                        addField(propertyFields, 'number_of_full_bath', pi.Full_Bath__c);
                        addField(propertyFields, 'hail_resistive_roof_class', pi.Hail_Resistive_Roof__c);
                        addField(propertyFields, 'number_of_half_bath', pi.Half_Bath__c);
                        addField(propertyFields, 'heating_renovation_year', pi.Heating_Year__c);
                        addField(propertyFields, 'heating_renovation_type', pi.Heating_Type__c);
                        addBoolField(propertyFields, 'sauna_hot_tub_on_premises', pi.Is_Hot_Tub__c);
                        addField(propertyFields, 'hot_tub_type', pi.Hot_Tub_on_Premises__c);
                        addBoolField(propertyFields, 'alarm_central_station_reporting', pi.Is_Alarm_System__c);
                        addBoolField(propertyFields, 'any_animals_on_premises', pi.Is_Animal__c);
                        addBoolField(propertyFields, 'is_the_building_entrance_locked', pi.Locked__c);
                        addBoolField(propertyFields, 'dead_bolt_locks', pi.Locked_Secure_Cover__c);
                        addField(propertyFields, 'members_in_household', pi.Members_in_Household__c);
                        addBoolField(propertyFields, 'trampoline_safety_net', pi.Net__c);
                        addField(propertyFields, 'number_of_families', pi.Number_of_Families__c);
                        addField(propertyFields, 'number_of_mortgages', pi.Number_of_Mortgages__c);
                        addField(propertyFields, 'number_of_roof_layers', pi.Number_of_Roof_Layers__c);
                        addField(propertyFields, 'number_of_stories', pi.Number_of_Stories__c);
                        addBoolField(propertyFields, 'any_structure_partially_or_entirely_over_water', pi.Partial__c);
                        addField(propertyFields, 'plumbing_renovation_type', pi.Plumbing__c);
                        addField(propertyFields, 'plumbing_renovation_year', pi.Plumbing_Year__c);
                        addBoolField(propertyFields, 'swimming_pool_on_premises', pi.Is_Pool__c);
                        addField(propertyFields, 'primary_heat_type', pi.Primary_Heat_Type__c);
                        addField(propertyFields, 'purchase_rental_date', formatDate(pi.Purchased_Rental_Date__c));
                        addBoolField(propertyFields, 'are_there_deadbolt_locks_and_fire_extinguishers_in_the_property', pi.Removable_Retracting_Locking__c);
                        addBoolField(propertyFields, 'is_the_roof_surfacing_covered_on_an_actual_cash_value_basis', pi.Roof_ACV__c);
                        addField(propertyFields, 'roof_shape', pi.Roof_Shape__c);
                        addField(propertyFields, 'roof_type', pi.Roof_Type__c);
                        addField(propertyFields, 'year_roof_installed', pi.Roof_Yr__c);
                        addBoolField(propertyFields, 'pool_slide', pi.Slide__c);
                        addField(propertyFields, 'square_footage_living_area_excluding_basement', pi.Square_Footage__c);
                        addField(propertyFields, 'swimming_pool_type', pi.Swimming_Pool_on_Premises__c);
                        addBoolField(propertyFields, 'trampoline_on_premises', pi.Is_Trampoline__c);
                        addBoolField(propertyFields, 'electrical_renovation_type', pi.Winning__c);
                        addField(propertyFields, 'year_wiring_installed', pi.Wiring_Year__c);
                        addField(propertyFields, 'year_built', pi.Year_Built__c);

                        if (!propertyFields.isEmpty()) {
                            entitiesList.add(new Map<String, Object>{
                                'entity' => 'property',
                                'index'  => propertyIndex,
                                'fields' => propertyFields
                            });
                            propertyIndex++;
                        }
                    }
                    } else if (!baseLeadPropertyFields.isEmpty()) {
                        entitiesList.add(new Map<String, Object>{
                            'entity' => 'property',
                            'index'  => 1,
                            'fields' => baseLeadPropertyFields
                        });
                    }
                }
                // CASE B: Properties__c records exist — use them as the primary loop
                // and enrich with Property_Information__c via the map (original logic).
                else if (!properties.isEmpty()) {
                    Integer propertyIndex = 1;
                    for (Properties__c prop : properties) {
                        List<Object> propertyFields = new List<Object>();

                        addField(propertyFields, 'property_type', prop.Property_Type__c);
                        addField(propertyFields, 'coverage_form', prop.Coverage_Form__c);
                        addField(propertyFields, 'serial_number', prop.Loan__c);
                        addField(propertyFields, 'is_there_a_mortgagee', prop.Mortgagee_Clause__c);

                        // Address from Properties__c
                        if (!String.isBlank(prop.Address__Street__s))     addField(propertyFields, 'address_1', prop.Address__Street__s.trim());
                        if (!String.isBlank(prop.Address__City__s))       addField(propertyFields, 'city', prop.Address__City__s.trim());
                        if (!String.isBlank(prop.Address__StateCode__s))  addField(propertyFields, 'state', prop.Address__StateCode__s.trim());
                        if (!String.isBlank(prop.Address__PostalCode__s)) addField(propertyFields, 'zip_code', prop.Address__PostalCode__s.trim());

                        // Enrich with Property_Information__c if the lookup is set
                        Property_Information__c pi = propInfoByPropId.get(prop.Id);
                        if (pi != null) {
                            addField(propertyFields, 'number_of_3_4_bath', pi.X3_4_Bath__c);
                            addField(propertyFields, 'dwelling_age', pi.Age_of_Dwelling__c);
                            addField(propertyFields, 'alarm_system_type', pi.Alarm_System__c);
                            addBoolField(propertyFields, 'any_smokers_in_the_household', pi.Any_smokers_in_the_Household__c);
                            addField(propertyFields, 'auxiliary_heat_type', pi.Auxiliary_Heat_Type__c);
                            addField(propertyFields, 'secured_community', pi.Community__c);
                            addBoolField(propertyFields, 'do_you_have_a_completed_building_code_certificate', pi.Complete__c);
                            addField(propertyFields, 'construction_style', pi.Construction__c);
                            addField(propertyFields, 'distance_to_coastline_miles', pi.Distance_to_Coastline__c);
                            addBoolField(propertyFields, 'pool_diving_board', pi.Diving_Board__c);
                            addField(propertyFields, 'exterior_paint_renovation_year', pi.Exterior_Paint__c);
                            addBoolField(propertyFields, 'pool_fence', pi.Fence_2__c);
                            addBoolField(propertyFields, 'approved_fence', pi.Fence__c);
                            addField(propertyFields, 'foundation_type', pi.Foundation_Type__c);
                            addField(propertyFields, 'number_of_full_bath', pi.Full_Bath__c);
                            addField(propertyFields, 'hail_resistive_roof_class', pi.Hail_Resistive_Roof__c);
                            addField(propertyFields, 'number_of_half_bath', pi.Half_Bath__c);
                            addField(propertyFields, 'heating_renovation_year', pi.Heating_Year__c);
                            addField(propertyFields, 'heating_renovation_type', pi.Heating_Type__c);
                            addBoolField(propertyFields, 'sauna_hot_tub_on_premises', pi.Is_Hot_Tub__c);
                            addField(propertyFields, 'hot_tub_type', pi.Hot_Tub_on_Premises__c);
                            addBoolField(propertyFields, 'alarm_central_station_reporting', pi.Is_Alarm_System__c);
                            addBoolField(propertyFields, 'any_animals_on_premises', pi.Is_Animal__c);
                            addBoolField(propertyFields, 'is_the_building_entrance_locked', pi.Locked__c);
                            addBoolField(propertyFields, 'dead_bolt_locks', pi.Locked_Secure_Cover__c);
                            addField(propertyFields, 'members_in_household', pi.Members_in_Household__c);
                            addBoolField(propertyFields, 'trampoline_safety_net', pi.Net__c);
                            addField(propertyFields, 'number_of_families', pi.Number_of_Families__c);
                            addField(propertyFields, 'number_of_mortgages', pi.Number_of_Mortgages__c);
                            addField(propertyFields, 'number_of_roof_layers', pi.Number_of_Roof_Layers__c);
                            addField(propertyFields, 'number_of_stories', pi.Number_of_Stories__c);
                            addBoolField(propertyFields, 'any_structure_partially_or_entirely_over_water', pi.Partial__c);
                            addField(propertyFields, 'plumbing_renovation_type', pi.Plumbing__c);
                            addField(propertyFields, 'plumbing_renovation_year', pi.Plumbing_Year__c);
                            addBoolField(propertyFields, 'swimming_pool_on_premises', pi.Is_Pool__c);
                            addField(propertyFields, 'primary_heat_type', pi.Primary_Heat_Type__c);
                            addField(propertyFields, 'purchase_rental_date', formatDate(pi.Purchased_Rental_Date__c));
                            addBoolField(propertyFields, 'are_there_deadbolt_locks_and_fire_extinguishers_in_the_property', pi.Removable_Retracting_Locking__c);
                            addBoolField(propertyFields, 'is_the_roof_surfacing_covered_on_an_actual_cash_value_basis', pi.Roof_ACV__c);
                            addField(propertyFields, 'roof_shape', pi.Roof_Shape__c);
                            addField(propertyFields, 'roof_type', pi.Roof_Type__c);
                            addField(propertyFields, 'year_roof_installed', pi.Roof_Yr__c);
                            addBoolField(propertyFields, 'pool_slide', pi.Slide__c);
                            addField(propertyFields, 'square_footage_living_area_excluding_basement', pi.Square_Footage__c);
                            addField(propertyFields, 'swimming_pool_type', pi.Swimming_Pool_on_Premises__c);
                            addBoolField(propertyFields, 'trampoline_on_premises', pi.Is_Trampoline__c);
                            addBoolField(propertyFields, 'electrical_renovation_type', pi.Winning__c);
                            addField(propertyFields, 'year_wiring_installed', pi.Wiring_Year__c);
                            addField(propertyFields, 'year_built', pi.Year_Built__c);
                        }

                        if (!propertyFields.isEmpty()) {
                            entitiesList.add(new Map<String, Object>{
                                'entity' => 'property',
                                'index'  => propertyIndex,
                                'fields' => propertyFields
                            });
                            propertyIndex++;
                        }
                    }
                }

                // ── Home Policy ───────────────────────────────────────────────────────────
                Map<String, Integer> policyIndexMap = new Map<String, Integer>();
                for (Prior_Insurance_Information__c hp : homePolicies) {
                    List<Object> hpFields = new List<Object>();
                    addField(hpFields, 'personal_injury_liability_coverage', hp.Bodily_Injury_Limits__c);
                    addField(hpFields, 'current_carrier_name', hp.Carrier_Name__c);
                    addField(hpFields, 'prior_policy_carrier_name', hp.Carrier_Name_Link__c);
                    addField(hpFields, 'expiration_date', formatDate(hp.Expiration_Date__c));
                    addField(hpFields, 'length_of_continuous_coverage_years', hp.Length_of_Continuous_Coverage__c);
                    addField(hpFields, 'years_with_prior_carrier', hp.Length_with_Current_Carrier__c);
                    addField(hpFields, 'line_of_business', hp.Line__c);
                    addField(hpFields, 'policy_number', hp.Policy_Number__c);
                    addField(hpFields, 'total_policy_premium', formatPremium(hp.Premium__c));

                    if (!hpFields.isEmpty()) {
                        String entityName = 'home_policy';
                        if (String.isNotBlank(hp.Line__c)) {
                            String lineLower = hp.Line__c.toLowerCase();
                            if      (lineLower.contains('auto'))       entityName = 'auto_policy';
                            else if (lineLower.contains('home'))       entityName = 'home_policy';
                            else if (lineLower.contains('flood'))      entityName = 'flood_policy';
                            else if (lineLower.contains('umbrella'))   entityName = 'umbrella_policy';
                            else if (lineLower.contains('commercial')) entityName = 'commercial_policy';
                            else if (lineLower.contains('life'))       entityName = 'life_policy';
                            else if (lineLower.contains('health'))     entityName = 'health_policy';
                        }

                        if (!policyIndexMap.containsKey(entityName)) {
                            policyIndexMap.put(entityName, 1);
                        }
                        Integer currentIndex = policyIndexMap.get(entityName);

                        entitiesList.add(new Map<String, Object>{
                            'entity' => entityName,
                            'index'  => currentIndex,
                            'fields' => hpFields
                        });

                        policyIndexMap.put(entityName, currentIndex + 1);
                    }
                }

                // ── Driver ────────────────────────────────────────────────────────────────
                Integer driverIndex = 1;
                for (Driver__c d : drivers) {
                    List<Object> driverFields = new List<Object>();
                    addField(driverFields, 'first_name', d.First_Name__c);
                    addField(driverFields, 'last_name', d.Last_Name__c);
                    addField(driverFields, 'date_of_birth', formatDate(d.Date_of_Birth__c));
                    addField(driverFields, 'license_number', d.DL__c);
                    addField(driverFields, 'education', d.Education__c);
                    addField(driverFields, 'driver_license_state', d.State__c);
                    addField(driverFields, 'marital_status', d.Marital_Status__c);
                    addField(driverFields, 'occupation', d.Occupation__c);
                    addField(driverFields, 'relationship', d.Relationship_to_Insured__c);
                    addField(driverFields, 'name', d.Driver_Full_Name__c);

                    if (!driverFields.isEmpty()) {
                        entitiesList.add(new Map<String, Object>{
                            'entity' => 'driver',
                            'index'  => driverIndex,
                            'fields' => driverFields
                        });
                        driverIndex++;
                    }
                }

                // ── Car ───────────────────────────────────────────────────────────────────
                Integer carIndex = 1;
                for (Vehicle__c v : vehicles) {
                    List<Object> carFields = new List<Object>();
                    addField(carFields, 'vehicle_type', normalizeVehicleType(v.Vehicle_Type__c));
                    addField(carFields, 'make', v.Make__c);
                    addField(carFields, 'model', v.Model__c);
                    addField(carFields, 'car_year', v.Year__c);
                    addField(carFields, 'purchase_year', v.Purchase_Year__c);
                    addField(carFields, 'vin', v.VIN__c);
                    addField(carFields, 'annual_miles', v.Annual_Miles__c);
                    addField(carFields, 'lien_holder', v.Lienholder__c);


                    if (!carFields.isEmpty()) {
                        entitiesList.add(new Map<String, Object>{
                            'entity' => 'car',
                            'index'  => carIndex,
                            'fields' => carFields
                        });
                        carIndex++;
                    }
                }

                // ── Loss ──────────────────────────────────────────────────────────────────
                Integer lossIndex = 1;
                for (Home_Losses_Claims__c loss : losses) {
                    List<Object> lossFields = new List<Object>();
                    addField(lossFields, 'amount_paid', loss.Amount_Paid__c);
                    addField(lossFields, 'current_carrier_name', loss.Carrier__c);
                    addBoolField(lossFields, 'catastrophic_loss', loss.Catastrophic_Related__c);
                    addField(lossFields, 'cause_of_loss', loss.Cause_of_Loss__c);
                    addField(lossFields, 'claim_status', loss.Claim_Status__c);
                    addField(lossFields, 'date_of_loss', formatDate(loss.Date_of_Loss__c));
                    addField(lossFields, 'description', loss.Description__c);
                    addField(lossFields, 'policy_type', loss.Policy_Type__c);
                    addField(lossFields, 'property_liability', loss.Property_Liability__c);
                    addField(lossFields, 'risk_address', loss.Risk_Address__c);
                    addBoolField(lossFields, 'any_weather_related_losses', loss.Weather_Related__c);

                    if (!lossFields.isEmpty()) {
                        entitiesList.add(new Map<String, Object>{
                            'entity' => 'loss',
                            'index'  => lossIndex,
                            'fields' => lossFields
                        });
                        lossIndex++;
                    }
                }

                // ── Accident & Violation ──────────────────────────────────────────────────
                Integer avIndex = 1;
                for (Auto_Incidents_Violations__c av : accidentsViolations) {
                    List<Object> avFields = new List<Object>();
                    addField(avFields, 'type_of_accident', av.Additional_Information__c);
                    addField(avFields, 'current_carrier_name', av.Carrier__c);
                    addField(avFields, 'date', formatDate(av.Date__c));
                    addField(avFields, 'description', av.Incident_Description__c);
                    addField(avFields, 'driver',
                        av.Operator__r != null ? av.Operator__r.Driver_Full_Name__c : null);

                    if (!avFields.isEmpty()) {
                        entitiesList.add(new Map<String, Object>{
                            'entity' => 'accident_violation',
                            'index'  => avIndex,
                            'fields' => avFields
                        });
                        avIndex++;
                    }
                }

                // ── Build payload and send ────────────────────────────────────────────────
                Map<String, Object> requestBody = new Map<String, Object>{
                    'industry' => 'personal_line_insurance',
                    'entities' => entitiesList
                };

                String jsonBody = JSON.serialize(requestBody);

                System.debug(LoggingLevel.ERROR,
                    '🔥 GAYA REQUEST JSON:\n' + JSON.serializePretty(JSON.deserializeUntyped(jsonBody))
                );

                HttpRequest httpReq = new HttpRequest();
                httpReq.setEndpoint('callout:Gaya_Production/clipboard_records');
                httpReq.setMethod('POST');
                httpReq.setHeader('Content-Type', 'application/json');
                httpReq.setBody(jsonBody);

                Http http = new Http();
                HttpResponse res = http.send(httpReq);

                System.debug(LoggingLevel.ERROR, '🔥 GAYA RESPONSE STATUS: ' + res.getStatusCode());

                try {
                    System.debug(LoggingLevel.ERROR,
                        '🔥 GAYA RESPONSE:\n' + JSON.serializePretty(JSON.deserializeUntyped(res.getBody()))
                    );
                } catch (Exception debugEx) {
                    System.debug(LoggingLevel.ERROR, '🔥 GAYA RESPONSE (raw): ' + res.getBody());
                }

                Response r = new Response();
                r.result = res.getBody();
                responses.add(r);

            } catch (Exception e) {
                Response errResponse = new Response();
                errResponse.result = 'Error: ' + e.getMessage() + ' | Line: ' + e.getLineNumber();
                responses.add(errResponse);
                System.debug(LoggingLevel.ERROR,
                    '🔥 GAYA ERROR: ' + e.getMessage() +
                    ' at line ' + e.getLineNumber() +
                    '\n' + e.getStackTraceString()
                );
            }
        }

        return responses;
    }

    // ─── Helpers ─────────────────────────────────────────────────────────────────

    private static void addField(List<Object> fields, String name, Object value) {
        if (value == null) return;
        String stringValue = String.valueOf(value);
        if (String.isBlank(stringValue)) return;
        fields.add(new Map<String, Object>{ 'name' => name, 'value' => stringValue });
    }

    // Boolean → Yes/No (for actual Checkbox fields)
    private static void addBoolField(List<Object> fields, String name, Boolean value) {
        if (value == null) return;
        fields.add(new Map<String, Object>{
            'name'  => name,
            'value' => value ? 'Yes' : 'No'
        });
    }

    // Boolean → Yes/No (for String fields containing "true"/"false")
    private static void addBoolField(List<Object> fields, String name, String value) {
        if (String.isBlank(value)) return;
        String normalized = value.trim().toLowerCase();
        String display = (normalized == 'true')  ? 'Yes'
                       : (normalized == 'false') ? 'No'
                       : value;
        fields.add(new Map<String, Object>{
            'name'  => name,
            'value' => display
        });
    }

    // Date formatter — strips the time portion
    private static String formatDate(Date d) {
        if (d == null) return null;
        return String.valueOf(d.year()).leftPad(4, '0')
            + '-' + String.valueOf(d.month()).leftPad(2, '0')
            + '-' + String.valueOf(d.day()).leftPad(2, '0');
    }

    private static String buildAddress(Lead l) {
        List<String> parts = new List<String>();
        if (l == null) return null;
        if (!String.isBlank(l.Insured_Address__Street__s))     parts.add(l.Insured_Address__Street__s.trim());
        if (!String.isBlank(l.Insured_Address__City__s))       parts.add(l.Insured_Address__City__s.trim());
        if (!String.isBlank(l.Insured_Address__StateCode__s))  parts.add(l.Insured_Address__StateCode__s.trim());
        if (!String.isBlank(l.Insured_Address__PostalCode__s)) parts.add(l.Insured_Address__PostalCode__s.trim());
        return parts.isEmpty() ? null : String.join(parts, ', ');
    }

    private static String formatPremium(Object premiumValue) {
        if (premiumValue == null) return null;
        if (premiumValue instanceof Decimal) {
            return String.valueOf(((Decimal)premiumValue).setScale(2));
        }
        return String.valueOf(premiumValue);
    }

    private static String normalizeVehicleType(String vehicleType) {
        if (String.isBlank(vehicleType)) return vehicleType;
        String cleaned = vehicleType.trim();
        if (cleaned.equalsIgnoreCase('Motorcyle')) return 'Motorcycle';
        return cleaned;
    }
}