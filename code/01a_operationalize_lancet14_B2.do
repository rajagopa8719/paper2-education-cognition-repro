*==============================================================================
* Lancet14_Operationalize_B2.do
* Paper 2: Operationalize 14 Lancet Commission 2024 Risk Factors in LASI-DAD B.2
* Created: May 11, 2026
* Data: H_LASI_DAD_b2.dta (N=6,168, 1,995 vars)
*==============================================================================

clear all
set more off
set maxvar 10000

* --- SECTION 1: Load Data ---------------------------------------------------

use "//Skyhub/Resources/Data/GGAD-LASI-Public/LASI-DAD/Harmonized Data/H_LASI_DAD_b2.dta", clear

* Strip haven labels immediately (Stata equivalent of zap_labels)
ds, has(vallabel)
foreach v of varlist `r(varlist)' {
    capture label values `v' .
}

di "Loaded N = " _N " observations"
describe, short

* --- SECTION 2: Verify All Variables Exist -----------------------------------

local vars_needed ///
    r2sgcp raedyrs raeduc_l ragender r2hagey r2hwtresp ///
    r2hhibpe r2hsysto r2hdiasto r2hmbmi r2hcesdl10 ///
    r2hdiabe r2diabetes r2headinje ///
    r2h_bptacat r2h_bpta ///
    r2hpcholldl r2ldl ///
    hh2pm25 ///
    r2hruralc r2hcastec r2hmstat isoa3

di _n "===== VARIABLE VERIFICATION ====="
foreach v of local vars_needed {
    capture confirm variable `v'
    if _rc == 0 {
        di "`v' : FOUND"
    }
    else {
        di "`v' : *** MISSING ***"
    }
}

* Check smoking (may be r1smoken or r2smoken in B.2)
di _n "--- Smoking variable search ---"
ds r*smoke*, detail
ds r*smok*, detail

* Check sight/vision (may be r2dsighta or different)
di _n "--- Vision variable search ---"
ds r*sight*, detail
ds r*vision*, detail

* Check physical activity / walking
di _n "--- Physical activity variable search ---"
ds r*walk*, detail
ds r*pact*, detail
ds r*vigor*, detail

* Check social activities
di _n "--- Social activity variable search ---"
ds r2sa*, detail

* Check alcohol
di _n "--- Alcohol variable search ---"
ds r*alcoh*, detail
ds r*beer*, detail
ds r*liquor*, detail
ds r*wine*, detail
ds r*tdy*, detail

* --- SECTION 3: Operationalize 14 Lancet Factors ----------------------------

di _n "===== OPERATIONALIZING LANCET 14 FACTORS ====="

* ---- EARLY LIFE ----

* 1. EDUCATION (PAF = 7% globally, 22.5% India per Angrisani 2024)
*    India-specific: no formal education = risk
*    HIC definition: less than secondary education
gen lancet_noedu = (raedyrs == 0) if !missing(raedyrs)
gen lancet_lessedu = (raedyrs < 10) if !missing(raedyrs)
label var lancet_noedu "Lancet: No formal education (India-specific)"
label var lancet_lessedu "Lancet: Less than secondary education (HIC)"
tab lancet_noedu, m
tab lancet_lessedu, m

* ---- MIDLIFE ----

* 2. HEARING LOSS (PAF = 8% globally)
*    UPGRADE over Angrisani: objective PTA instead of self-report
*    r2h_bptacat: categorical PTA hearing loss
*    Cutoff: moderate+ hearing loss (PTA > 35 dB)
capture {
    tab r2h_bptacat, m
    * Create binary: moderate+ hearing loss
    * Check coding first - values may be 0/1/2/3 or labeled
    gen lancet_hearing = .
    * If categorical: 0=normal, 1=mild, 2=moderate, 3=severe
    replace lancet_hearing = (r2h_bptacat >= 2) if !missing(r2h_bptacat)
    label var lancet_hearing "Lancet: Hearing loss (PTA moderate+, objective)"
    tab lancet_hearing, m
    
    * Also check continuous PTA for verification
    summ r2h_bpta, detail
}

* Fallback: if PTA categories don't work as expected
* Replace the line above after checking actual coding

* 3. TBI (PAF = 3% globally)
*    NEW: Angrisani excluded TBI. We include it.
*    r2headinje: ever had head injury (binary, 12.7% prevalence)
capture {
    gen lancet_tbi = (r2headinje == 1) if !missing(r2headinje)
    label var lancet_tbi "Lancet: Traumatic brain injury (self-report)"
    tab lancet_tbi, m
}

* 4. HYPERTENSION (PAF = 2% globally, 5.0% India)
*    Dual definition: diagnosed OR measured BP >= 140/90
capture {
    gen lancet_htn = 0 if !missing(r2hhibpe)
    replace lancet_htn = 1 if r2hhibpe == 1
    * Add measured BP criterion
    replace lancet_htn = 1 if r2hsysto >= 140 & !missing(r2hsysto)
    replace lancet_htn = 1 if r2hdiasto >= 90 & !missing(r2hdiasto)
    label var lancet_htn "Lancet: Hypertension (diagnosed or measured)"
    tab lancet_htn, m
}

* 5. ALCOHOL >21 units/week (PAF = 1% globally)
*    r2evalcohl: ever consumed alcohol
*    r2nowalcohl: currently consumes alcohol
*    Frequency vars: r2beerf, r2tdyf, r2liquorf, r2winef (9-pt scale)
*    Need to convert frequency to units/week
capture {
    tab r2evalcohl, m
    tab r2nowalcohl, m
    
    * Check frequency variable coding
    summ r2beerf r2tdyf r2liquorf r2winef, detail
    
    * Placeholder: define excessive as current drinker
    * UPDATE after checking frequency scale coding
    gen lancet_alcohol = (r2nowalcohl == 1) if !missing(r2nowalcohl)
    label var lancet_alcohol "Lancet: Current alcohol use (refine to >21 units)"
    tab lancet_alcohol, m
}

* 6. OBESITY / BMI (PAF = 1% globally)
*    India-specific cutoffs (Association of Physicians in India):
*    Underweight: BMI < 18
*    Normal: 18-23
*    Overweight: 23-25
*    Obese: BMI >= 25
capture {
    gen bmi_india_cat = .
    replace bmi_india_cat = 1 if r2hmbmi < 18 & !missing(r2hmbmi)
    replace bmi_india_cat = 2 if r2hmbmi >= 18 & r2hmbmi < 23 & !missing(r2hmbmi)
    replace bmi_india_cat = 3 if r2hmbmi >= 23 & r2hmbmi < 25 & !missing(r2hmbmi)
    replace bmi_india_cat = 4 if r2hmbmi >= 25 & !missing(r2hmbmi)
    label define bmi_india_lbl 1 "Underweight (<18)" 2 "Normal (18-23)" ///
        3 "Overweight (23-25)" 4 "Obese (>=25)"
    label values bmi_india_cat bmi_india_lbl
    label var bmi_india_cat "BMI India-specific categories"
    tab bmi_india_cat, m
    
    * Binary: obese (India cutoff)
    gen lancet_obese = (r2hmbmi >= 25) if !missing(r2hmbmi)
    label var lancet_obese "Lancet: Obese (BMI >= 25, India cutoff)"
    
    * Binary: underweight (India cutoff)
    gen lancet_underweight = (r2hmbmi < 18) if !missing(r2hmbmi)
    label var lancet_underweight "Lancet: Underweight (BMI < 18, India cutoff)"
    
    tab lancet_obese, m
    tab lancet_underweight, m
    
    * BMI deviation from mean (Sijiu's suggestion for robustness)
    summ r2hmbmi
    gen bmi_dev = abs(r2hmbmi - r(mean)) if !missing(r2hmbmi)
    label var bmi_dev "BMI deviation from sample mean (absolute)"
}

* ---- LATER LIFE ----

* 7. SMOKING (PAF = 5% globally)
*    Check which variable exists in B.2
*    Core has r1smoken; B.2 may have different prefix
capture {
    * Try W2 first, then W1
    capture confirm variable r2smoken
    if _rc == 0 {
        gen lancet_smoking = (r2smoken == 1) if !missing(r2smoken)
        label var lancet_smoking "Lancet: Current smoker (W2)"
    }
    else {
        capture confirm variable r1smoken
        if _rc == 0 {
            gen lancet_smoking = (r1smoken == 1) if !missing(r1smoken)
            label var lancet_smoking "Lancet: Current smoker (W1, carried forward)"
        }
        else {
            di "*** SMOKING VARIABLE NOT FOUND. Check ds r*smok* output above. ***"
        }
    }
    capture tab lancet_smoking, m
}

* 8. DEPRESSION (PAF = 4% globally, 2.6% India)
*    r2hcesdl10: CESD-10 Likert scale, 0-30
*    Cutoff >= 10 for depression screening positive
capture {
    gen lancet_depression = (r2hcesdl10 >= 10) if !missing(r2hcesdl10)
    label var lancet_depression "Lancet: Depression (CESD-10 >= 10)"
    tab lancet_depression, m
    summ r2hcesdl10, detail
}

* 9. SOCIAL ISOLATION (PAF = 4% globally, 8.2% India)
*    Build index from 12 r2sa* social activity items
*    Angrisani used: not married/cohabiting + less than monthly social contact
*    + living alone
capture {
    * List all social activity variables
    ds r2sa*
    
    * Create count of social activities participated in
    * Each r2sa* item is likely binary (0/1)
    egen social_count = rowtotal(r2sa*), missing
    label var social_count "Count of social activities (from r2sa* items)"
    summ social_count, detail
    
    * Define isolation as bottom quartile (or 0-1 activities)
    * UPDATE threshold after seeing distribution
    gen lancet_isolated = (social_count <= 1) if !missing(social_count)
    label var lancet_isolated "Lancet: Social isolation (0-1 activities)"
    tab lancet_isolated, m
    
    * Also check marital status for Angrisani-style definition
    tab r2hmstat, m
}

* 10. PHYSICAL INACTIVITY (PAF = 2% globally, 12.5% India)
*     Walking variables: r2walkdy, r2walkrec, r2walknw, r2walkwrk
capture {
    summ r2walkdy r2walkrec r2walknw r2walkwrk, detail
    
    * Define inactivity: no recreational walking AND no work walking
    * OR: walks 0 days per week
    gen lancet_inactive = .
    replace lancet_inactive = 1 if r2walkdy == 0 & !missing(r2walkdy)
    replace lancet_inactive = 0 if r2walkdy > 0 & !missing(r2walkdy)
    label var lancet_inactive "Lancet: Physically inactive (walks 0 days/week)"
    tab lancet_inactive, m
    
    * Alternative: no recreational walking
    capture {
        gen inactive_rec = (r2walkrec == 0) if !missing(r2walkrec)
        label var inactive_rec "No recreational walking"
        tab inactive_rec, m
    }
}

* 11. AIR POLLUTION (PAF = 2% globally)
*     hh2pm25: indoor PM2.5 measured by UPAS (N approx 1,488)
*     Outdoor PM2.5: inaccessible (empty folder)
capture {
    summ hh2pm25, detail
    
    * WHO guideline: annual mean PM2.5 > 15 ug/m3 (2021 AQG)
    * Indian NAAQS: annual mean PM2.5 > 40 ug/m3
    gen lancet_airpoll = (hh2pm25 > 15) if !missing(hh2pm25)
    label var lancet_airpoll "Lancet: Indoor PM2.5 > 15 ug/m3 (WHO guideline)"
    tab lancet_airpoll, m
    
    * Also create Indian standard version
    gen airpoll_india = (hh2pm25 > 40) if !missing(hh2pm25)
    label var airpoll_india "Air pollution: Indoor PM2.5 > 40 ug/m3 (Indian NAAQS)"
    tab airpoll_india, m
}

* 12. DIABETES (PAF = 1% globally)
*     r2diabetes: biomarker-based (HbA1c >= 6.5)
*     r2hdiabe: self-report (ever diagnosed)
capture {
    gen lancet_diabetes = (r2diabetes == 1) if !missing(r2diabetes)
    label var lancet_diabetes "Lancet: Diabetes (HbA1c >= 6.5, biomarker)"
    tab lancet_diabetes, m
    
    * Self-report sensitivity check
    gen diabetes_selfrep = (r2hdiabe == 1) if !missing(r2hdiabe)
    label var diabetes_selfrep "Diabetes self-report (ever diagnosed)"
    tab diabetes_selfrep, m
    
    * Combined: either biomarker OR self-report
    gen diabetes_either = 0
    replace diabetes_either = 1 if lancet_diabetes == 1 | diabetes_selfrep == 1
    replace diabetes_either = . if missing(lancet_diabetes) & missing(diabetes_selfrep)
    label var diabetes_either "Diabetes (biomarker OR self-report)"
    tab diabetes_either, m
}

* ---- NEW IN LANCET 2024 ----

* 13. VISION LOSS (RR = 1.47, Lancet 2024)
*     No objective visual acuity in B.2
*     Fallback: r2dsighta from Core (self-report, W2)
*     Also check r1dsighta (W1) if W2 not available
capture {
    * Search for any sight variable in B.2
    ds *sight*, detail
    
    capture confirm variable r2dsighta
    if _rc == 0 {
        * Check coding
        tab r2dsighta, m
        * Assume higher values = worse sight
        * Define poor/blind as risk
        gen lancet_vision = (r2dsighta >= 4) if !missing(r2dsighta)
        label var lancet_vision "Lancet: Vision loss (self-report, poor/blind)"
        tab lancet_vision, m
    }
    else {
        capture confirm variable r1dsighta
        if _rc == 0 {
            tab r1dsighta, m
            gen lancet_vision = (r1dsighta >= 4) if !missing(r1dsighta)
            label var lancet_vision "Lancet: Vision loss (W1 self-report, poor/blind)"
            tab lancet_vision, m
        }
        else {
            di "*** VISION VARIABLE NOT FOUND IN B.2. ***"
            di "*** Need to merge r1dsighta from Core. ***"
        }
    }
}

* 14. HIGH LDL CHOLESTEROL (RR = 1.33, Lancet 2024)
*     r2hpcholldl: LDL >= 130 mg/dL (clinical flag, 22% prevalence)
*     Also have continuous r2ldl
capture {
    gen lancet_ldl = (r2hpcholldl == 1) if !missing(r2hpcholldl)
    label var lancet_ldl "Lancet: High LDL (>= 130 mg/dL)"
    tab lancet_ldl, m
    summ r2ldl, detail
}

* --- SECTION 4: Covariates ---------------------------------------------------

di _n "===== COVARIATES ====="

* Age
summ r2hagey, detail

* Gender
tab ragender, m

* Marital status
tab r2hmstat, m

* Caste
tab r2hcastec, m

* Urban/rural
tab r2hruralc, m

* State
tab isoa3, m

* --- SECTION 5: Outcome Variable ---------------------------------------------

di _n "===== OUTCOME ====="

* General cognitive performance
summ r2sgcp, detail

* Also check W1
capture summ r1sgcp, detail

* --- SECTION 6: Prevalence Summary -------------------------------------------

di _n "===== LANCET 14 PREVALENCE SUMMARY ====="

local lancet_vars lancet_noedu lancet_lessedu lancet_hearing lancet_tbi ///
    lancet_htn lancet_alcohol lancet_obese lancet_underweight ///
    lancet_smoking lancet_depression lancet_isolated lancet_inactive ///
    lancet_airpoll lancet_diabetes lancet_vision lancet_ldl

foreach v of local lancet_vars {
    capture {
        qui summ `v'
        local n = r(N)
        local mean = r(mean)
        local pct = round(`mean' * 100, 0.1)
        di "`v' : `pct'% (N = `n')"
    }
}

* --- SECTION 7: Education Gradient for Each Factor ----------------------------

di _n "===== EDUCATION GRADIENT (mean by education group) ====="

* Create education categories
gen edu_cat = .
replace edu_cat = 0 if raedyrs == 0
replace edu_cat = 1 if raedyrs >= 1 & raedyrs <= 5
replace edu_cat = 2 if raedyrs >= 6 & !missing(raedyrs)
label define edu_cat_lbl 0 "None" 1 "Primary (1-5)" 2 "Secondary+ (6+)"
label values edu_cat edu_cat_lbl

foreach v of local lancet_vars {
    capture {
        di _n "--- `v' by education ---"
        tab edu_cat `v', row nofreq
    }
}

* GCP by education
table edu_cat, stat(mean r2sgcp) stat(sd r2sgcp) stat(freq)

* --- SECTION 8: Analytic Sample Count ----------------------------------------

di _n "===== ANALYTIC SAMPLE ====="

* Count complete cases on core variables
gen core_complete = !missing(r2sgcp) & !missing(raedyrs) & ///
    !missing(ragender) & !missing(r2hagey)
tab core_complete

* Count how many have each Lancet factor
foreach v of local lancet_vars {
    capture {
        qui count if !missing(`v') & core_complete == 1
        di "`v' : N = " r(N) " with core complete"
    }
}

* --- SECTION 9: Save Operationalized Dataset ---------------------------------

* Keep key variables
local keepvars r2sgcp r1sgcp raedyrs raeduc_l ragender r2hagey r2hwtresp ///
    r2hruralc r2hcastec r2hmstat isoa3 ///
    lancet_* bmi_india_cat bmi_dev diabetes_* social_count ///
    inactive_rec airpoll_india edu_cat core_complete

* Save to output
save "//Skyhub/Resources/Project/GGAD00-0080/output/Lancet14_B2_operationalized.dta", replace
di "Saved operationalized dataset."

* --- SECTION 10: Export Prevalence Table as CSV --------------------------------

* Build prevalence table
capture postclose prev_tbl
postfile prev_tbl str30 factor str10 type n_valid n_positive pct_positive ///
    using "//Skyhub/Resources/Project/GGAD00-0080/output/Lancet14_prevalence.csv", replace

foreach v in lancet_noedu lancet_hearing lancet_tbi lancet_htn ///
    lancet_alcohol lancet_obese lancet_underweight lancet_smoking ///
    lancet_depression lancet_isolated lancet_inactive lancet_airpoll ///
    lancet_diabetes lancet_vision lancet_ldl {
    
    capture {
        qui count if !missing(`v')
        local nv = r(N)
        qui count if `v' == 1
        local np = r(N)
        local pp = round(`np' / `nv' * 100, 0.1)
        post prev_tbl ("`v'") ("binary") (`nv') (`np') (`pp')
    }
}

postclose prev_tbl
use "//Skyhub/Resources/Project/GGAD00-0080/output/Lancet14_prevalence.csv", clear
export delimited using "//Skyhub/Resources/Project/GGAD00-0080/output/Lancet14_prevalence.csv", replace
di "Prevalence table exported."

di _n "===== DONE ====="
di "Next steps:"
di "1. Check VARIABLE VERIFICATION output above for any MISSING variables"
di "2. Check smoking variable name from ds output"
di "3. Check vision variable availability"
di "4. Check social activity item coding (binary? frequency?)"
di "5. Refine alcohol threshold after checking frequency scale"
di "6. Refine physical inactivity after checking walking variable coding"
di "7. Adjust hearing loss cutoff after checking r2h_bptacat coding"
