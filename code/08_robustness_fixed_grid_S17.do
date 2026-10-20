*==============================================================
* Paper2_S17_fixed_sample_grid_20261016.do
* Priya Rajagopalan | Paper 2 | LASI-DAD
*
* PURPOSE: Supplement Table S17. Specification grid on ONE fixed
*   sample. Nine / ten / eleven factors all estimated on the
*   eleven-factor complete-case sample (N = 2,365), so the spec
*   comparison is not confounded by changing N. Complements S16
*   Panel A (each spec on its own sample). Both contrasts, both
*   weightings.
*
* Setup copied from Paper2_robustness_all_wtd_vs_unwtd_20261014.do
* (cd OUTDIR, bare load, weight from Lancet14_B2_operationalized,
* strip mi AFTER merge, rebuild the sample with markout).
*
* OUTPUT: s17_fixed_sample_grid.csv
*   columns: spec contrast weighting base full atten n
*==============================================================
clear all
set more off
global OUTDIR "\\Skyhub\Resources\Project\GGAD00-0080\output"
cd "$OUTDIR"
capture log close
log using paper2_20261016_s17_fixedgrid.log, replace

*==============================================================
* BLOCK 0. LOAD + weight + mi-strip + sample.
*==============================================================
global COVARS       "age_c70 i.ragender i.r2hruralc i.r2hcastec wealth_quintile i.region5"
global COVARS_PLAIN "age_c70 ragender r2hruralc r2hcastec wealth_quintile region5"
global M9  "lancet_htn lancet_obese lancet_diabetes lancet_smoking lancet_vision hearing_mod lancet_depression lancet_isolated lancet_tbi"
global M10 "lancet_htn lancet_obese lancet_diabetes lancet_smoking lancet_vision hearing_mod lancet_depression lancet_isolated lancet_tbi lancet_inactive"
global M11 "lancet_htn lancet_obese lancet_diabetes lancet_smoking lancet_vision hearing_mod lancet_depression lancet_isolated lancet_tbi lancet_inactive fuel_unclean"
global WT  "r2hwtresp"

use Paper2_bmi4_analysis.dta, clear

* weight (r2hwtresp lives in the operationalized file); merge only if absent
capture confirm variable r2hwtresp
if _rc merge 1:1 prim_key using Lancet14_B2_operationalized.dta, ///
        keepusing(r2hwtresp) keep(master match) nogen

* strip the (stale) mi marker AFTER any merge, before estimation
capture drop _mi_*
local __chars : char _dta[]
foreach c of local __chars {
    char _dta[`c'] ""
}

confirm variable r2sgcp edu_3cat r2hwtresp
confirm variable lancet_htn lancet_obese lancet_diabetes lancet_smoking lancet_vision hearing_mod lancet_depression lancet_isolated lancet_tbi lancet_inactive fuel_unclean

* fixed sample = eleven-factor complete case incl. weight (expect N=2,365)
capture drop fixed11
gen byte fixed11 = 1
markout fixed11 r2sgcp edu_3cat $COVARS_PLAIN $M11 $WT
count if fixed11==1

*==============================================================
* BLOCK 1. Common base (no mediators) on the fixed sample.
*==============================================================
capture postclose s17
postfile s17 str8 spec str10 contrast str10 weighting double base full atten long n using s17_fixed_sample_grid, replace

regress r2sgcp i.edu_3cat $COVARS if fixed11==1
scalar baseP_u = _b[1.edu_3cat]
scalar baseS_u = _b[2.edu_3cat]
regress r2sgcp i.edu_3cat $COVARS [pw=$WT] if fixed11==1
scalar baseP_w = _b[1.edu_3cat]
scalar baseS_w = _b[2.edu_3cat]

*==============================================================
* BLOCK 2. Each spec FULL on the fixed sample. base/full/atten.
*==============================================================
* --- NINE ---
regress r2sgcp i.edu_3cat $M9 $COVARS if fixed11==1
post s17 ("Nine") ("Primary") ("Unweighted") (baseP_u) (_b[1.edu_3cat]) (100*(baseP_u-_b[1.edu_3cat])/baseP_u) (e(N))
post s17 ("Nine") ("Sec+")    ("Unweighted") (baseS_u) (_b[2.edu_3cat]) (100*(baseS_u-_b[2.edu_3cat])/baseS_u) (e(N))
regress r2sgcp i.edu_3cat $M9 $COVARS [pw=$WT] if fixed11==1
post s17 ("Nine") ("Primary") ("Weighted") (baseP_w) (_b[1.edu_3cat]) (100*(baseP_w-_b[1.edu_3cat])/baseP_w) (e(N))
post s17 ("Nine") ("Sec+")    ("Weighted") (baseS_w) (_b[2.edu_3cat]) (100*(baseS_w-_b[2.edu_3cat])/baseS_w) (e(N))

* --- TEN ---
regress r2sgcp i.edu_3cat $M10 $COVARS if fixed11==1
post s17 ("Ten") ("Primary") ("Unweighted") (baseP_u) (_b[1.edu_3cat]) (100*(baseP_u-_b[1.edu_3cat])/baseP_u) (e(N))
post s17 ("Ten") ("Sec+")    ("Unweighted") (baseS_u) (_b[2.edu_3cat]) (100*(baseS_u-_b[2.edu_3cat])/baseS_u) (e(N))
regress r2sgcp i.edu_3cat $M10 $COVARS [pw=$WT] if fixed11==1
post s17 ("Ten") ("Primary") ("Weighted") (baseP_w) (_b[1.edu_3cat]) (100*(baseP_w-_b[1.edu_3cat])/baseP_w) (e(N))
post s17 ("Ten") ("Sec+")    ("Weighted") (baseS_w) (_b[2.edu_3cat]) (100*(baseS_w-_b[2.edu_3cat])/baseS_w) (e(N))

* --- ELEVEN (full-11 must reproduce the eleven-factor full) ---
regress r2sgcp i.edu_3cat $M11 $COVARS if fixed11==1
post s17 ("Eleven") ("Primary") ("Unweighted") (baseP_u) (_b[1.edu_3cat]) (100*(baseP_u-_b[1.edu_3cat])/baseP_u) (e(N))
post s17 ("Eleven") ("Sec+")    ("Unweighted") (baseS_u) (_b[2.edu_3cat]) (100*(baseS_u-_b[2.edu_3cat])/baseS_u) (e(N))
regress r2sgcp i.edu_3cat $M11 $COVARS [pw=$WT] if fixed11==1
post s17 ("Eleven") ("Primary") ("Weighted") (baseP_w) (_b[1.edu_3cat]) (100*(baseP_w-_b[1.edu_3cat])/baseP_w) (e(N))
post s17 ("Eleven") ("Sec+")    ("Weighted") (baseS_w) (_b[2.edu_3cat]) (100*(baseS_w-_b[2.edu_3cat])/baseS_w) (e(N))

postclose s17
use s17_fixed_sample_grid, clear
list, clean noobs
export delimited using s17_fixed_sample_grid.csv, replace

*==============================================================
* RECONCILIATION (soft). On the fixed sample (expect N=2,365):
*   base Sec+ = 1.085 weighted / 1.060 unweighted,
*   ELEVEN full Sec+ = 0.974 weighted / 0.952 unweighted.
* Nine and Ten fulls are the new fixed-sample numbers; the
* nine->eleven gap isolates the added factors (inactivity, fuel)
* from the sample change.
*==============================================================
log close
