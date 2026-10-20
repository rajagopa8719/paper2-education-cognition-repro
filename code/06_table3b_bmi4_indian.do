*==============================================================================
* Paper 2 -- Table 3b, FOUR-CATEGORY BMI, WEIGHTED, INDIAN (Asian) cutoffs
* Option B: weight the four-category model the manuscript already uses.
* Cutoffs match Methods para: <18 / 18 to <23 (ref) / 23 to <25 / >=25,
* as in Angrisani et al. (2024). This REPLACES the WHO-band run
* (paper2_20261009_bmi4_weighted.log), which re-cut BMI and does not match
* the manuscript table.
*
* Only change from the WHO version: the bmi4 recode and labels, plus a
* stronger Gate 3 (top band == binary lancet_obese, since both are BMI>=25).
* Weight, merges, sample, model, and export are unchanged.
*==============================================================================

clear all
set more off
set seed 20260930

* -- OUTDIR is NOT persistent between Enclave sessions; set it every time. -----
global OUTDIR "\\Skyhub\Resources\Project\GGAD00-0080\output"
cd "$OUTDIR"

capture log close
log using paper2_20261009_bmi4_INDIANcut_weighted.log, replace

*------------------------------------------------------------------------------
* Model pieces -- verbatim from the S13 / wboot logs. Do not edit.
*------------------------------------------------------------------------------
global OUTCOME "r2sgcp"
global COVARS       "age_c70 i.ragender i.r2hruralc i.r2hcastec wealth_quintile i.region5"
global COVARS_PLAIN "age_c70 ragender r2hruralc r2hcastec wealth_quintile region5"
global M9  "lancet_htn lancet_obese lancet_diabetes lancet_smoking lancet_vision hearing_mod lancet_depression lancet_isolated lancet_tbi"
* M8 = the nine-factor set with binary obesity removed; bmi4 replaces it.
global M8  "lancet_htn lancet_diabetes lancet_smoking lancet_depression lancet_isolated lancet_tbi hearing_mod lancet_vision"
global WT  "r2hwtresp"

*------------------------------------------------------------------------------
* Load analytic file. Bring in continuous BMI and the Wave 2 weight.
* r2hmbmi lives only in Paper2_Lancet14_Full.dta; r2hwtresp only in
* Lancet14_B2_operationalized.dta. Both merges are ONE physical line each.
*------------------------------------------------------------------------------
use Paper2_bmi4_analysis.dta, clear
di "N loaded (expect 6168): " _N
assert _N == 6168

capture confirm variable age_c70
if _rc {
    gen double age_c70 = r2hagey - 70
}

capture confirm variable r2hmbmi
if _rc {
    merge 1:1 prim_key using Paper2_Lancet14_Full.dta, keepusing(r2hmbmi) keep(master match) nogen
}

merge 1:1 prim_key using Lancet14_B2_operationalized.dta, keepusing(r2hwtresp) keep(master match) nogen

* -- Strip the stale mi marker stamped on by merging an mi-set using file. -----
capture mi unset
capture drop _mi_*
local __chars : char _dta[]
foreach c of local __chars {
    char _dta[`c'] ""
}

count if missing(r2hwtresp)
di as txt "rows missing weight (S13 saw 1530): " r(N)

*------------------------------------------------------------------------------
* Fixed nine-factor complete-case sample = the SAME 3,355 used everywhere.
* markout on M9 (incl. binary obesity) so the sample is identical to the main
* and bootstrap runs; bmi4 is derived below and is complete on this sample.
*------------------------------------------------------------------------------
gen byte insamp9 = 1
markout insamp9 r2sgcp edu_3cat $COVARS_PLAIN $M9 $WT

count if insamp9==1
di as res "nine-factor N (expect 3355): " r(N)
assert r(N)==3355

*------------------------------------------------------------------------------
* Four-category BMI -- INDIAN (Asian) cutoffs, matching the manuscript.
*   1 = Underweight       (< 18)
*   2 = Reference         (18 to < 23)   <-- ib2 below
*   3 = Overweight        (23 to < 25)
*   4 = Obesity           (>= 25)
*------------------------------------------------------------------------------
capture drop bmi4
gen byte bmi4 = .
replace bmi4 = 1 if r2hmbmi <  18
replace bmi4 = 2 if r2hmbmi >= 18 & r2hmbmi < 23
replace bmi4 = 3 if r2hmbmi >= 23 & r2hmbmi < 25
replace bmi4 = 4 if r2hmbmi >= 25 & r2hmbmi < .
label define bmi4L 1 "Underweight <18" 2 "Normal 18-22.9" 3 "Overweight 23-24.9" 4 "Obese >=25", replace
label values bmi4 bmi4L

* -- Gate 1: bmi4 complete on the sample (no obs dropped from the full model). -
count if insamp9==1 & missing(bmi4)
di as res "insamp9 with missing bmi4 (expect 0): " r(N)
assert r(N)==0

* -- Gate 2: category counts cross-checked by eye against the binary obese. ----
tab bmi4 lancet_obese if insamp9==1, missing

* -- Gate 3 (STRONG): the >=25 band must equal binary obese exactly. -----------
*    Both are defined at BMI >= 25, so disagreement means the recode is wrong.
count if insamp9==1 & ( (bmi4==4) != (lancet_obese==1) )
di as res "bmi4==4 vs lancet_obese mismatches (expect 0): " r(N)
assert r(N)==0

*==============================================================================
* Weighted models. Base (edu + covars) then Full (edu + bmi4 + M8 + covars).
* Gate 4 = reference category is enforced by ib2 and checked by eye.
*==============================================================================
capture postclose pf
postfile pf str8 model str24 term double(b se pval) using bmi4_table3b_weighted_indian.dta, replace

* -- BASE: education contrast before any factor adjustment ---------------------
regress $OUTCOME i.edu_3cat $COVARS [pw=$WT] if insamp9==1
foreach trm in 1.edu_3cat 2.edu_3cat {
    local b  = _b[`trm']
    local se = _se[`trm']
    local t  = `b'/`se'
    local p  = 2*ttail(e(df_r), abs(`t'))
    post pf ("base") ("`trm'") (`b') (`se') (`p')
    di as result "base `trm': b=`b'  se=`se'"
}

* -- FULL: four-category BMI (Indian cutoffs, normal reference) + other eight --
regress $OUTCOME i.edu_3cat ib2.bmi4 $M8 $COVARS [pw=$WT] if insamp9==1
foreach trm in 1.edu_3cat 2.edu_3cat 1.bmi4 3.bmi4 4.bmi4 {
    local b  = _b[`trm']
    local se = _se[`trm']
    local t  = `b'/`se'
    local p  = 2*ttail(e(df_r), abs(`t'))
    post pf ("full") ("`trm'") (`b') (`se') (`p')
    di as result "full `trm': b=`b'  se=`se'  p=`p'"
}
postclose pf

use bmi4_table3b_weighted_indian.dta, clear
list, clean noobs
export delimited using bmi4_table3b_weighted_indian.csv, replace
di as res "wrote bmi4_table3b_weighted_indian.csv"

*------------------------------------------------------------------------------
* Weighted mean cognition by BMI category -- reads the direction for para 66.
* Aggregate only. No microdata export.
*------------------------------------------------------------------------------
use Paper2_bmi4_analysis.dta, clear
* (re-derive weight, sample, bmi4 for the mean step)
capture confirm variable r2hmbmi
if _rc merge 1:1 prim_key using Paper2_Lancet14_Full.dta, keepusing(r2hmbmi) keep(master match) nogen
merge 1:1 prim_key using Lancet14_B2_operationalized.dta, keepusing(r2hwtresp) keep(master match) nogen
capture mi unset
capture drop _mi_*
local __chars2 : char _dta[]
foreach c of local __chars2 {
    char _dta[`c'] ""
}
gen byte insamp9 = 1
markout insamp9 r2sgcp edu_3cat $COVARS_PLAIN $M9 $WT
capture drop bmi4
gen byte bmi4 = .
replace bmi4 = 1 if r2hmbmi <  18
replace bmi4 = 2 if r2hmbmi >= 18 & r2hmbmi < 23
replace bmi4 = 3 if r2hmbmi >= 23 & r2hmbmi < 25
replace bmi4 = 4 if r2hmbmi >= 25 & r2hmbmi < .
label define bmi4L 1 "Underweight <18" 2 "Normal 18-22.9" 3 "Overweight 23-24.9" 4 "Obese >=25", replace
label values bmi4 bmi4L
mean $OUTCOME [pw=$WT] if insamp9==1, over(bmi4)

log close

*==============================================================================
* SEND BACK: paper2_20261009_bmi4_INDIANcut_weighted.log
*            and bmi4_table3b_weighted_indian.csv
*
* EXPECT:
*  - base 2.edu_3cat ~ 1.073 (matches S13 weighted base_sec; base has no BMI,
*    so this confirms the weight, NOT the BMI cut).
*  - Gate 3 mismatch count == 0 (this is what confirms the Indian >=25 cut).
*  - full: 1.bmi4 (underweight) negative; 3.bmi4 (overweight 23-24.9) and
*    4.bmi4 (obese >=25) positive relative to the 18-22.9 reference.
*  - full 2.edu_3cat near the unweighted Indian value 0.995; attenuation
*    = (base2 - full2)/base2, expected ~7-8%.
*
* LIKELY FAILURE POINTS:
*  1. assert N==3355 trips -> weight or a factor did not merge for all rows.
*  2. Gate 1 trips -> r2hmbmi missing for some sample members (check the
*     Paper2_Lancet14_Full merge and prim_key integrity).
*  3. Gate 3 trips -> bmi4 top band and binary obese disagree; the cutpoints
*     or r2hmbmi scaling are wrong. Reconcile BEFORE reporting.
*==============================================================================
