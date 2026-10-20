*==============================================================================
* Paper 2 -- STATE fixed-effects robustness, weighted vs unweighted.
*
* The lean analytic file carries region5 (five zones) but no state id, so the
* main robustness run skipped the state arm. This merges the state identifier
* (isoa3, kept in Lancet14_B2_operationalized.dta) and runs the geography
* ladder with STATE fixed effects added: no geography / region / state.
*
* Reports the full-model education coefficient (Primary and Sec+) under each,
* weighted and unweighted, on the nine-factor sample (N = 3,355).
*
* FIX 14 Oct 2026: STATEVAR was "isoa3", which is a COUNTRY code (one level on
* an India-only sample), so the state arm always skipped. The Indian state id is
* r2stateid (17-18 named states; Lancet14_Full uses i.r2stateid). STATEVAR now
* points to r2stateid, pulled from H_LASI_DAD_b2.dta. The merge is defensive:
* if r2stateid is not found there, the state arm skips cleanly instead of
* crashing, and the log says so. Output: state_fe_robust.csv (+ the .log)
*==============================================================================
clear all
set more off

global OUTDIR "\\Skyhub\Resources\Project\GGAD00-0080\output"
cd "$OUTDIR"
capture log close
log using paper2_20261014_state_fe_robust.log, replace

* ---- the state variable to use. Change here only. ----
global STATEVAR "r2stateid"
* source file for the state id (change here only if it lives elsewhere)
global STATESRC "//Skyhub/Resources/Data/GGAD-LASI-Public/LASI-DAD/Harmonized Data/H_LASI_DAD_b2.dta"

* ---- model pieces (verbatim from the mediation runs) ----
global OUTCOME      "r2sgcp"
global COVARS       "age_c70 i.ragender i.r2hruralc i.r2hcastec wealth_quintile i.region5"
global COVARS_NOGEO "age_c70 i.ragender i.r2hruralc i.r2hcastec wealth_quintile"
global COVARS_PLAIN "age_c70 ragender r2hruralc r2hcastec wealth_quintile region5"
global M9  "lancet_htn lancet_obese lancet_diabetes lancet_smoking lancet_vision hearing_mod lancet_depression lancet_isolated lancet_tbi"
global WT  "r2hwtresp"

* ---- load; bring in the weight AND the state id; strip the stale mi marker ----
use Paper2_bmi4_analysis.dta, clear
di "N loaded (expect 6168): " _N

capture confirm variable age_c70
if _rc gen double age_c70 = r2hagey - 70

* prim_key is a 15-digit string key; protect it from float mangling before merge.
capture confirm string variable prim_key
if _rc tostring prim_key, replace format(%15.0f)

* ---- weight from the operationalized file (r2hwtresp lives there) ----
merge 1:1 prim_key using Lancet14_B2_operationalized.dta, ///
        keepusing(r2hwtresp) keep(master match) nogen

* ---- state id from the harmonized DAD backbone, defensively ----------------
* r2stateid is not on the lean analytic file. Pull it from H_LASI_DAD_b2.dta.
* If it is not found there, skip the state arm rather than crash. have_state
* records whether the merge brought a usable state id.
local have_state = 0
capture confirm variable $STATEVAR
if _rc {
    preserve
        capture use prim_key $STATEVAR using "$STATESRC", clear
        if _rc==0 {
            capture confirm string variable prim_key
            if _rc tostring prim_key, replace format(%15.0f)
            tempfile stfile
            save `stfile'
        }
    restore
    capture confirm file "`stfile'"
    if _rc==0 merge 1:1 prim_key using "`stfile'", keep(master match) nogen
}
capture confirm variable $STATEVAR
if _rc==0 local have_state = 1
if `have_state'==0 {
    di as error ">>> $STATEVAR not found in the analytic file or $STATESRC."
    di as error ">>> State arm skipped. Confirm the state variable/source and rerun."
}

* ---- strip the stale mi marker AFTER both merges (they re-stamp it) ----
capture mi unset
capture drop _mi_*
local __chars : char _dta[]
foreach c of local __chars {
    char _dta[`c'] ""
}

* ---- nine-factor sample, same 3,355 as everywhere ----
gen byte insamp9 = 1
markout insamp9 r2sgcp edu_3cat $COVARS_PLAIN $M9 $WT
count if insamp9==1
di as res "nine-factor N (expect 3355): " r(N)
assert r(N)==3355

* ---- make a numeric state variable; confirm it varies ----
local nst = 0
if `have_state'==1 {
    capture confirm numeric variable $STATEVAR
    if _rc {
        capture drop state_num
        encode $STATEVAR, gen(state_num)
    }
    else {
        capture drop state_num
        gen state_num = $STATEVAR
    }
    quietly levelsof state_num if insamp9==1, local(stlvls)
    local nst : word count `stlvls'
    di as res "distinct `=upper("$STATEVAR")' levels on the sample: `nst'"
    if `nst' <= 1 {
        di as error ">>> $STATEVAR has <=1 level on the sample -- NOT a state id."
        di as error ">>> It is likely a country code. Set STATEVAR to the true"
        di as error ">>> state variable and rerun. State arm skipped."
    }
}

*==============================================================================
* Geography ladder on the nine-factor full model. Full education coefficient
* under no geography / region / state, weighted and unweighted.
*==============================================================================
capture postclose pf
postfile pf str10 arm str10 contrast str10 weighting double(full n) ///
    using state_fe_robust.dta, replace

capture program drop garm
program define garm
    args arm geo
    quietly regress $OUTCOME i.edu_3cat $M9 `geo' [pw=$WT] if insamp9==1
    post pf ("`arm'") ("Primary") ("weighted")   (_b[1.edu_3cat]) (e(N))
    post pf ("`arm'") ("Sec+")    ("weighted")   (_b[2.edu_3cat]) (e(N))
    quietly regress $OUTCOME i.edu_3cat $M9 `geo' if insamp9==1
    post pf ("`arm'") ("Primary") ("unweighted") (_b[1.edu_3cat]) (e(N))
    post pf ("`arm'") ("Sec+")    ("unweighted") (_b[2.edu_3cat]) (e(N))
end

garm noFE   "$COVARS_NOGEO"
garm region "$COVARS"
if `nst' > 1 {
    garm state "$COVARS_NOGEO i.state_num"
}

postclose pf

use state_fe_robust.dta, clear
order arm contrast weighting full n
sort arm contrast weighting
list, clean noobs
export delimited using state_fe_robust.csv, replace
di as res "wrote state_fe_robust.csv"

log close
*==============================================================================
* SEND BACK: state_fe_robust.csv  and  paper2_20261014_state_fe_robust.log
* READ: full Sec+/Primary coefficient under noFE / region / state, each
*       weighted and unweighted. region should match the main nine-factor full
*       (Sec+ weighted ~ 0.990). If state ~= region, geography is not driving
*       the result -- the same conclusion as the region check, at finer grain.
* FIRST check the log line "distinct R2STATEID levels": expect ~17-18 named
* states. If it says the state arm was skipped, r2stateid did not merge from
* $STATESRC; confirm the source file and variable name, then rerun.
*==============================================================================
