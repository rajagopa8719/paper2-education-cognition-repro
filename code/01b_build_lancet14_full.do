*==============================================================================
* Paper2_Lancet14_Full.do
* Self-contained: load B.2, merge Core, generate all 14 Lancet indicators,
* tab everything, save .dta, export CSV, build income quintiles, OLS mediation
* Run in Enclave. Save this file and source() it.
*==============================================================================

clear all
set more off
set maxvar 10000

* Project output directory for Gateway Enclave
global OUTDIR "//Skyhub/Resources/Project/GGAD00-0080/output"

* ==============================================================================
* SECTION 1: LOAD B.2
* ==============================================================================

di _n "===== SECTION 1: LOADING B.2 ====="

use "//Skyhub/Resources/Data/GGAD-LASI-Public/LASI-DAD/Harmonized Data/H_LASI_DAD_b2.dta", clear

di "B.2 loaded: " _N " obs, " c(k) " vars"

* ==============================================================================
* SECTION 2: MERGE CORE A.3
* ==============================================================================

di _n "===== SECTION 2: MERGING CORE A.3 ====="

merge 1:1 prim_key using "//Skyhub/Resources/Data/GGAD-LASI-Public/LASI core/Harmonized data/H_LASI_a3.dta", ///
    keepusing(r1smoken r1smokev r1dsighta r1nsighta r1iearn r1ipen r1ipubpen r1agey rascst) ///
    keep(master match) nogenerate

di "After merge: " _N " obs"
di "r1smoken non-missing: " 
count if !missing(r1smoken)
di "r1dsighta non-missing: "
count if !missing(r1dsighta)
di "r1iearn non-missing: "
count if !missing(r1iearn)
di "r1ipen non-missing: "
count if !missing(r1ipen)

* ==============================================================================
* SECTION 3: GENERATE ALL 14 LANCET INDICATORS
* ==============================================================================

di _n "===== SECTION 3: GENERATING LANCET 14 ====="

* Drop any prior versions (safe for re-runs)
foreach v in lancet_noedu lancet_lessedu lancet_hearing_mod lancet_hearing_mild ///
    lancet_tbi lancet_htn lancet_alcohol lancet_obese lancet_underweight ///
    lancet_smoking lancet_depression lancet_isolated lancet_inactive ///
    lancet_airpoll lancet_diabetes lancet_vision lancet_ldl ///
    social_count diabetes_selfrep diabetes_either ///
    income_total income_quintile {
    capture drop `v'
}

* --- 1. EDUCATION (no formal education) ---
gen lancet_noedu = (raedyrs == 0) if !missing(raedyrs)
label var lancet_noedu "Lancet: No formal education (0 years)"

* --- 2. EDUCATION (less than secondary) ---
gen lancet_lessedu = (raedyrs < 10) if !missing(raedyrs)
label var lancet_lessedu "Lancet: Less than secondary education"

* --- 3. HEARING LOSS (PTA moderate+) ---
gen lancet_hearing_mod = (r2h_bptacat >= 2) if !missing(r2h_bptacat)
label var lancet_hearing_mod "Lancet: Hearing loss moderate+ (PTA)"

gen lancet_hearing_mild = (r2h_bptacat >= 1) if !missing(r2h_bptacat)
label var lancet_hearing_mild "Hearing loss mild+ (PTA)"

* --- 4. TBI ---
gen lancet_tbi = (r2headinje == 1) if !missing(r2headinje) & r2headinje <= 1
label var lancet_tbi "Lancet: TBI (ever head injury)"

* --- 5. HYPERTENSION ---
gen lancet_htn = 0 if !missing(r2hhibpe)
replace lancet_htn = 1 if r2hhibpe == 1
replace lancet_htn = 1 if r2hsysto >= 140 & !missing(r2hsysto)
replace lancet_htn = 1 if r2hdiasto >= 90 & !missing(r2hdiasto)
label var lancet_htn "Lancet: Hypertension (diagnosed or measured)"

* --- 6. ALCOHOL ---
gen lancet_alcohol = (r2evalcohl == 1) if !missing(r2evalcohl)
label var lancet_alcohol "Lancet: Ever consumed alcohol"

* --- 7. OBESITY ---
gen lancet_obese = (r2hmbmi >= 25) if !missing(r2hmbmi)
label var lancet_obese "Lancet: Obese (BMI >= 25, Asia cutoff)"

gen lancet_underweight = (r2hmbmi < 18.5) if !missing(r2hmbmi)
label var lancet_underweight "Underweight (BMI < 18.5)"

* --- 8. SMOKING ---
gen lancet_smoking = (r1smoken == 1) if !missing(r1smoken)
label var lancet_smoking "Lancet: Current smoker (Core W1)"

* --- 9. VISION LOSS ---
* r1dsighta: 1=excellent, 2=very good, 3=good, 4=fair, 5=poor
gen lancet_vision = (r1dsighta >= 4) if !missing(r1dsighta)
label var lancet_vision "Lancet: Vision poor/fair (Core W1 self-report)"

* --- 10. DEPRESSION ---
* r2hcesdl10: CESD-10 Likert, 0-30. Cutoff >= 10.
gen lancet_depression = (r2hcesdl10 >= 10) if !missing(r2hcesdl10)
label var lancet_depression "Lancet: Depression (CESD-10 >= 10)"

* --- 11. SOCIAL ISOLATION ---
* 12 social activity items from B.2
egen social_count = rowtotal(r2saeat r2sapark r2saigame r2saogame r2savstff r2sashow r2sarlgn r2sameet r2saread r2satv r2sacmptr r2savote), missing
label var social_count "Count of social activities (12 items)"
gen lancet_isolated = (social_count <= 1) if !missing(social_count)
label var lancet_isolated "Lancet: Social isolation (0-1 activities)"

* --- 12. PHYSICAL INACTIVITY ---
gen lancet_inactive = (r2walkdy == 0) if !missing(r2walkdy)
label var lancet_inactive "Lancet: Physically inactive (walks 0 days/wk)"

* --- 13. AIR POLLUTION ---
* hh2pm25: indoor PM2.5, UPAS measured. WHO guideline > 15 ug/m3.
gen lancet_airpoll = (hh2pm25 > 15) if !missing(hh2pm25)
label var lancet_airpoll "Lancet: Indoor PM2.5 > 15 ug/m3 (WHO)"

* --- 14. DIABETES ---
gen diabetes_selfrep = (r2hdiabe == 1) if !missing(r2hdiabe)
gen diabetes_either = 0
replace diabetes_either = 1 if r2hdiabe == 1
replace diabetes_either = 1 if r2diabetes == 1
replace diabetes_either = . if missing(r2hdiabe) & missing(r2diabetes)
gen lancet_diabetes = diabetes_either
label var lancet_diabetes "Lancet: Diabetes (self-report or HbA1c >= 6.5)"

* --- 15. HIGH LDL ---
gen lancet_ldl = (r2hpcholldl == 1) if !missing(r2hpcholldl)
label var lancet_ldl "Lancet: High LDL (>= 130 mg/dL)"

di _n "All 14 Lancet indicators generated."

* ==============================================================================
* SECTION 4: TAB EVERYTHING (no capture blocks)
* ==============================================================================

di _n "===== SECTION 4: TABULATIONS ====="

di _n "--- 1. Education (no formal) ---"
tab lancet_noedu, m

di _n "--- 2. Education (less than secondary) ---"
tab lancet_lessedu, m

di _n "--- 3. Hearing moderate+ ---"
tab lancet_hearing_mod, m

di _n "--- 3b. Hearing mild+ ---"
tab lancet_hearing_mild, m

di _n "--- 4. TBI ---"
tab lancet_tbi, m

di _n "--- 5. HYPERTENSION ---"
tab lancet_htn, m

di _n "--- 6. ALCOHOL ---"
tab lancet_alcohol, m

di _n "--- 7a. Obesity ---"
tab lancet_obese, m

di _n "--- 7b. Underweight ---"
tab lancet_underweight, m

di _n "--- 8. Smoking ---"
tab lancet_smoking, m

di _n "--- 9. Vision ---"
tab lancet_vision, m

di _n "--- 10. Depression ---"
tab lancet_depression, m

di _n "--- 11. Social isolation ---"
tab lancet_isolated, m

di _n "--- 12. Physical inactivity ---"
tab lancet_inactive, m

di _n "--- 13. Air pollution (indoor PM2.5) ---"
tab lancet_airpoll, m

di _n "--- 14. Diabetes ---"
tab lancet_diabetes, m

di _n "--- 15. High LDL ---"
tab lancet_ldl, m

di _n "--- Continuous distributions ---"
summ r2hmbmi r2hcesdl10 social_count hh2pm25 r2h_bpta r2hsysto r2hdiasto raedyrs r2hagey, detail

* ==============================================================================
* SECTION 5: SAVE .DTA TO ENCLAVE OUTPUT
* ==============================================================================

di _n "===== SECTION 5: SAVING .DTA ====="

* Save .dta directly to the Enclave output directory
save "$OUTDIR/Paper2_Lancet14_Full.dta", replace
di "Saved: $OUTDIR/Paper2_Lancet14_Full.dta"

* ==============================================================================
* SECTION 6: EXPORT PREVALENCE CSVs (batched export delimited)
* ==============================================================================

di _n "===== SECTION 6: EXPORTING PREVALENCE CSVs ====="

export delimited lancet_htn lancet_alcohol lancet_depression lancet_diabetes using "$OUTDIR/Lancet14_prevalence_1.csv", replace
export delimited lancet_hearing_mild lancet_hearing_mod lancet_inactive lancet_isolated using "$OUTDIR/Lancet14_prevalence_2.csv", replace
export delimited lancet_ldl lancet_lessedu lancet_noedu lancet_obese using "$OUTDIR/Lancet14_prevalence_3.csv", replace
export delimited lancet_smoking lancet_tbi lancet_underweight lancet_vision lancet_airpoll using "$OUTDIR/Lancet14_prevalence_4.csv", replace

di "Exported 4 prevalence CSVs to $OUTDIR"

* ==============================================================================
* SECTION 7: BUILD INCOME QUINTILES
* ==============================================================================

di _n "===== SECTION 7: INCOME QUINTILES ====="

di "r1iearn distribution:"
summ r1iearn, detail

di _n "r1ipen distribution:"
summ r1ipen, detail

gen income_total = r1iearn + r1ipen
label var income_total "Total income (earnings + pension, Core W1)"
summ income_total, detail

* Count non-missing
count if !missing(income_total) & income_total > 0
di "Non-missing positive income: " r(N)

count if !missing(income_total)
di "Non-missing income (incl zero): " r(N)

* Quintiles among non-missing
xtile income_quintile = income_total if !missing(income_total), nq(5)
label var income_quintile "Income quintile (1=lowest, 5=highest)"
tab income_quintile, m

* Cross-tab with education
di _n "Income quintile by education group:"
tab income_quintile lancet_noedu, row

* ==============================================================================
* SECTION 8: OLS MEDIATION MODELS
* ==============================================================================

di _n "===== SECTION 8: OLS MEDIATION ====="

* ---- 8A. Total effect: Education -> GCP ----
di _n "--- MODEL 1: Total effect (education -> r2sgcp) ---"
regress r2sgcp raedyrs r2hagey i.ragender i.rascst
estimates store m1_total

di _n "--- MODEL 1b: Total effect (education -> r2sgcp) with state FE ---"
regress r2sgcp raedyrs r2hagey i.ragender i.rascst i.r2stateid
estimates store m1_total_fe

* ---- 8B. A-paths: Education -> each mediator ----
di _n "--- A-PATHS: Education -> each Lancet mediator ---"

foreach med in lancet_htn lancet_diabetes lancet_obese lancet_depression lancet_hearing_mod lancet_tbi lancet_alcohol lancet_smoking lancet_inactive lancet_isolated lancet_vision lancet_airpoll lancet_ldl {
    di _n "A-path: raedyrs -> `med'"
    capture noisily logit `med' raedyrs r2hagey i.ragender i.rascst, or
    if _rc != 0 {
        di "  FAILED for `med' (rc=" _rc ")"
    }
}

* ---- 8C. Direct effect: Education + all mediators -> GCP ----
di _n "--- MODEL 2: Direct effect (education + mediators -> r2sgcp) ---"

* Start with mediators that have best coverage
regress r2sgcp raedyrs lancet_htn lancet_diabetes lancet_obese lancet_depression ///
    lancet_smoking lancet_alcohol lancet_tbi lancet_ldl ///
    r2hagey i.ragender i.rascst
estimates store m2_direct

di _n "--- Compare total vs direct ---"
estimates table m1_total m2_direct, b(%9.4f) se(%9.4f) stats(N r2_a)

* ---- 8D. Add hearing, vision, isolation, inactivity (smaller N) ----
di _n "--- MODEL 3: Full mediator set (smaller N due to missingness) ---"
regress r2sgcp raedyrs lancet_htn lancet_diabetes lancet_obese lancet_depression ///
    lancet_smoking lancet_alcohol lancet_tbi lancet_ldl ///
    lancet_hearing_mod lancet_vision lancet_isolated lancet_inactive ///
    r2hagey i.ragender i.rascst
estimates store m3_full

estimates table m1_total m2_direct m3_full, b(%9.4f) se(%9.4f) stats(N r2_a)

* ---- 8E. Gender-stratified ----
di _n "--- MODEL 4: Gender-stratified total effect ---"
di "Women (ragender == 2):"
regress r2sgcp raedyrs r2hagey i.rascst if ragender == 2
di _n "Men (ragender == 1):"
regress r2sgcp raedyrs r2hagey i.rascst if ragender == 1

* ---- 8F. Interaction model ----
di _n "--- MODEL 5: Education x Gender interaction ---"
gen educ_female = raedyrs * (ragender == 2)
label var educ_female "Education x Female interaction"
regress r2sgcp raedyrs educ_female i.ragender r2hagey i.rascst
capture drop educ_female

* ==============================================================================
* DONE
* ==============================================================================

di _n "============================================="
di "DONE. Files saved to working directory:"
di "  1. Lancet14_B2_operationalized.dta"
di "  2. Lancet14_prevalence.csv"
di "============================================="
di "N = " _N
di "Next: review tab output, check prevalence CSV,"
di "then refine mediation model specifications."
