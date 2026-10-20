*==============================================================================
* Paper 2 -- ROBUSTNESS: weighted vs unweighted, side by side. CONSOLIDATED.
*
* Runs each check BOTH ways on the SAME fixed samples, so the only thing that
* changes between the two columns is the weight. One upload covers S17, S18, S20.
*
* Blocks:
*   A. Specification ladder (S17) -- nine / ten / eleven factor, each on its own
*      complete-case sample, base and full, both contrasts, attenuation.
*   B. Fixed-effects ladder  (S20) -- nine-factor full model with no geography /
*      region5 / state fixed effects. State id (r2stateid) merged from the DAD
*      backbone, defensively; if it is absent the state arm skips, no crash.
*   C. Sequential ladder     (S18) -- eleven-factor sample (N=2,365), education
*      coefficient as mediators are added in blocks: vascular, lifestyle, mental,
*      sensory, cooking fuel. Both contrasts, both weightings, SE + 95% CI +
*      attenuation at each step.
*
* Setup (load, weight merge, mi-strip, markout) is verbatim from the weighted
* bootstrap, a-path, and state-FE do-files that ran clean. Nothing guessed.
*
* NOTE: S19 (hearing-measure robustness) is NOT in this file. It needs the
*       self-report hearing variable and the hearing_mod definition confirmed
*       first, and will be handled separately.
*
* Built 14 Oct 2026. Supersedes 07_robustness_wtd_vs_unwtd.do (its BLOCK B
* detected a state variable from the file and would have fallen back to isoa3,
* a country code; this version merges the real state id).
* Output: robust_specFE_wtd_vs_unwtd.csv , seq_wtd_vs_unwtd.csv  (+ the .log)
*==============================================================================
clear all
set more off
set linesize 200

* -- OUTDIR is NOT persistent between Enclave sessions; set it every time. -----
global OUTDIR "\\Skyhub\Resources\Project\GGAD00-0080\output"
cd "$OUTDIR"
capture log close
log using paper2_20261014_robust_all_wtd_vs_unwtd.log, replace

* ---- model pieces (verbatim from the mediation runs) ----
global OUTCOME      "r2sgcp"
global COVARS       "age_c70 i.ragender i.r2hruralc i.r2hcastec wealth_quintile i.region5"
global COVARS_NOGEO "age_c70 i.ragender i.r2hruralc i.r2hcastec wealth_quintile"
global COVARS_PLAIN "age_c70 ragender r2hruralc r2hcastec wealth_quintile region5"
global M9  "lancet_htn lancet_obese lancet_diabetes lancet_smoking lancet_vision hearing_mod lancet_depression lancet_isolated lancet_tbi"
global M10 "lancet_htn lancet_obese lancet_diabetes lancet_smoking lancet_vision hearing_mod lancet_depression lancet_isolated lancet_tbi lancet_inactive"
global M11 "lancet_htn lancet_obese lancet_diabetes lancet_smoking lancet_vision hearing_mod lancet_depression lancet_isolated lancet_tbi lancet_inactive fuel_unclean"
global WT  "r2hwtresp"
* state id source (change here only if it lives elsewhere)
global STATESRC "//Skyhub/Resources/Data/GGAD-LASI-Public/LASI-DAD/Harmonized Data/H_LASI_DAD_b2.dta"

*==============================================================================
* LOAD. Analytic file + Wave 2 weight + state id, then strip the stale mi marker
* ONCE after all merges (merging an mi-set using file re-stamps the marker, so
* the strip must come last or svyset/regress throw r(119)).
*==============================================================================
use Paper2_bmi4_analysis.dta, clear
di "N loaded (expect 6168): " _N

capture confirm variable age_c70
if _rc gen double age_c70 = r2hagey - 70

* prim_key is a 15-digit string key; protect it from float mangling before merge.
capture confirm string variable prim_key
if _rc tostring prim_key, replace format(%15.0f)

* weight (r2hwtresp lives in the operationalized file)
capture confirm variable r2hwtresp
if _rc merge 1:1 prim_key using Lancet14_B2_operationalized.dta, ///
        keepusing(r2hwtresp) keep(master match) nogen

* state id for the geography ladder (not on the lean analytic file), defensively
capture confirm variable r2stateid
if _rc {
    preserve
        capture use prim_key r2stateid using "$STATESRC", clear
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

* ---- strip the stale mi marker AFTER both merges ----
capture mi unset
capture drop _mi_*
local __chars : char _dta[]
foreach c of local __chars {
    char _dta[`c'] ""
}

* ---- fixed samples: each spec on its own complete-case set ----
capture drop insamp9 insamp10 insamp11
gen byte insamp9 = 1
markout insamp9  r2sgcp edu_3cat $COVARS_PLAIN $M9  $WT
gen byte insamp10 = 1
markout insamp10 r2sgcp edu_3cat $COVARS_PLAIN $M10 $WT
gen byte insamp11 = 1
markout insamp11 r2sgcp edu_3cat $COVARS_PLAIN $M11 $WT

count if insamp9==1
di as res "nine N (expect 3355): "  r(N)
assert r(N)==3355
count if insamp10==1
di as res "ten N (expect 2406): "   r(N)
count if insamp11==1
di as res "eleven N (expect 2365): " r(N)
assert r(N)==2365

global S9  "insamp9==1"
global S10 "insamp10==1"
global S11 "insamp11==1"

*==============================================================================
* OUTPUT postfile for BLOCKS A and B. One row per check x spec/arm x contrast
* x weighting. Plain handle, capture first.
*==============================================================================
capture postclose pf
postfile pf str10 block str10 spec str10 contrast str10 weighting ///
    double(base full atten n) using robust_specFE_wtd_vs_unwtd.dta, replace

*------------------------------------------------------------------------------
* BLOCK A (S17) -- specification ladder. Each spec on its own sample.
*------------------------------------------------------------------------------
capture program drop ladder
program define ladder
    args spec meds samp
    * ---- weighted ----
    quietly regress $OUTCOME i.edu_3cat $COVARS [pw=$WT] if `samp'
    scalar bP = _b[1.edu_3cat]
    scalar bS = _b[2.edu_3cat]
    scalar nn = e(N)
    quietly regress $OUTCOME i.edu_3cat `meds' $COVARS [pw=$WT] if `samp'
    scalar fP = _b[1.edu_3cat]
    scalar fS = _b[2.edu_3cat]
    post pf ("spec") ("`spec'") ("Primary") ("weighted")   (bP) (fP) (100*(bP-fP)/bP) (nn)
    post pf ("spec") ("`spec'") ("Sec+")    ("weighted")   (bS) (fS) (100*(bS-fS)/bS) (nn)
    * ---- unweighted (same fixed sample) ----
    quietly regress $OUTCOME i.edu_3cat $COVARS if `samp'
    scalar bP = _b[1.edu_3cat]
    scalar bS = _b[2.edu_3cat]
    scalar nn = e(N)
    quietly regress $OUTCOME i.edu_3cat `meds' $COVARS if `samp'
    scalar fP = _b[1.edu_3cat]
    scalar fS = _b[2.edu_3cat]
    post pf ("spec") ("`spec'") ("Primary") ("unweighted") (bP) (fP) (100*(bP-fP)/bP) (nn)
    post pf ("spec") ("`spec'") ("Sec+")    ("unweighted") (bS) (fS) (100*(bS-fS)/bS) (nn)
end

ladder nine   "$M9"  "$S9"
ladder ten    "$M10" "$S10"
ladder eleven "$M11" "$S11"

*------------------------------------------------------------------------------
* BLOCK B (S20) -- fixed-effects ladder on the nine-factor full model (insamp9).
* Geography arm: none / region5 / state. State var detected from the file AFTER
* the r2stateid merge above; falls back through a list only if r2stateid absent.
*------------------------------------------------------------------------------
local statevar ""
foreach cand in r2stateid stateid state statenum {
    capture confirm variable `cand'
    if _rc==0 & "`statevar'"=="" local statevar "`cand'"
}
di as res "state FE variable detected: `statevar'"
capture confirm string variable `statevar'
if _rc==0 {
    capture drop statenum
    encode `statevar', gen(statenum)
    local statevar "statenum"
}

capture program drop fearm
program define fearm
    args arm geo
    * weighted
    quietly regress $OUTCOME i.edu_3cat $M9 `geo' [pw=$WT] if insamp9==1
    post pf ("fe") ("`arm'") ("Primary") ("weighted")   (.) (_b[1.edu_3cat]) (.) (e(N))
    post pf ("fe") ("`arm'") ("Sec+")    ("weighted")   (.) (_b[2.edu_3cat]) (.) (e(N))
    * unweighted
    quietly regress $OUTCOME i.edu_3cat $M9 `geo' if insamp9==1
    post pf ("fe") ("`arm'") ("Primary") ("unweighted") (.) (_b[1.edu_3cat]) (.) (e(N))
    post pf ("fe") ("`arm'") ("Sec+")    ("unweighted") (.) (_b[2.edu_3cat]) (.) (e(N))
end

fearm noFE   "$COVARS_NOGEO"
fearm region "$COVARS"
if "`statevar'"!="" {
    fearm state "$COVARS_NOGEO i.`statevar'"
}
else {
    di as error ">>> r2stateid not found; state-FE arm skipped. Confirm $STATESRC."
}

postclose pf

* ---- CHECKPOINT: export BLOCKS A+B before the sequential block runs ----
* preserve/restore so the analytic data (and insamp markers) survive the export;
* loading the results .dta would otherwise clear the sample BLOCK C needs.
preserve
    use robust_specFE_wtd_vs_unwtd.dta, clear
    order block spec contrast weighting base full atten n
    sort block spec contrast weighting
    list, clean noobs
    export delimited using robust_specFE_wtd_vs_unwtd.csv, replace
    di as res "wrote robust_specFE_wtd_vs_unwtd.csv"
restore

*==============================================================================
* BLOCK C (S18) -- sequential ladder on the eleven-factor sample (insamp11).
* Mediators added in blocks, in the manuscript order: vascular, lifestyle,
* mental, sensory, cooking fuel. Base (step 0) = eleven-factor base; +Fuel
* (step 5) = eleven-factor full. Both must reconcile to the S13 eleven cells.
* Reload clean first so insamp11 and the mediators are untouched.
*==============================================================================
* mediator blocks (grouping from the production sequential build)
global SEQ_VASC   "lancet_htn lancet_diabetes lancet_smoking lancet_obese"
global SEQ_LIFE   "lancet_inactive"
global SEQ_MENTAL "lancet_depression lancet_isolated lancet_tbi"
global SEQ_SENS   "hearing_mod lancet_vision"
global SEQ_FUEL   "fuel_unclean"

* base education coefficients (attenuation denominators), both weightings
quietly regress $OUTCOME i.edu_3cat $COVARS [pw=$WT] if insamp11==1
scalar baseP_w = _b[1.edu_3cat]
scalar baseS_w = _b[2.edu_3cat]
quietly regress $OUTCOME i.edu_3cat $COVARS if insamp11==1
scalar baseP_u = _b[1.edu_3cat]
scalar baseS_u = _b[2.edu_3cat]

capture postclose pf_seq
postfile pf_seq str4 step str12 label str10 contrast str10 weighting ///
    double(coef sterr ll ul pval attn n) using seq_wtd_vs_unwtd.dta, replace

capture program drop seqstep
program define seqstep
    args stepnum label meds
    * ---- weighted ----
    quietly regress $OUTCOME i.edu_3cat `meds' $COVARS [pw=$WT] if insamp11==1
    scalar snw = e(N)
    scalar sdfw = e(df_r)
    forvalues cc = 1/2 {
        scalar scoef = _b[`cc'.edu_3cat]
        scalar sse   = _se[`cc'.edu_3cat]
        scalar sll   = scoef - 1.96*sse
        scalar sul   = scoef + 1.96*sse
        scalar spv   = 2*ttail(sdfw, abs(scoef/sse))
        if `cc'==1 {
            local ctr "Primary"
            scalar sden = baseP_w
        }
        else {
            local ctr "Sec+"
            scalar sden = baseS_w
        }
        post pf_seq ("`stepnum'") ("`label'") ("`ctr'") ("weighted") ///
            (scoef) (sse) (sll) (sul) (spv) (100*(sden-scoef)/sden) (snw)
    }
    * ---- unweighted (same fixed sample) ----
    quietly regress $OUTCOME i.edu_3cat `meds' $COVARS if insamp11==1
    scalar snu = e(N)
    scalar sdfu = e(df_r)
    forvalues cc = 1/2 {
        scalar scoef = _b[`cc'.edu_3cat]
        scalar sse   = _se[`cc'.edu_3cat]
        scalar sll   = scoef - 1.96*sse
        scalar sul   = scoef + 1.96*sse
        scalar spv   = 2*ttail(sdfu, abs(scoef/sse))
        if `cc'==1 {
            local ctr "Primary"
            scalar sden = baseP_u
        }
        else {
            local ctr "Sec+"
            scalar sden = baseS_u
        }
        post pf_seq ("`stepnum'") ("`label'") ("`ctr'") ("unweighted") ///
            (scoef) (sse) (sll) (sul) (spv) (100*(sden-scoef)/sden) (snu)
    }
end

seqstep 0 "Base"       ""
seqstep 1 "+Vascular"  "$SEQ_VASC"
seqstep 2 "+Lifestyle" "$SEQ_VASC $SEQ_LIFE"
seqstep 3 "+Mental"    "$SEQ_VASC $SEQ_LIFE $SEQ_MENTAL"
seqstep 4 "+Sensory"   "$SEQ_VASC $SEQ_LIFE $SEQ_MENTAL $SEQ_SENS"
seqstep 5 "+Fuel"      "$SEQ_VASC $SEQ_LIFE $SEQ_MENTAL $SEQ_SENS $SEQ_FUEL"

postclose pf_seq

use seq_wtd_vs_unwtd.dta, clear
order step label contrast weighting coef sterr ll ul pval attn n
sort weighting contrast step
list, clean noobs
export delimited using seq_wtd_vs_unwtd.csv, replace
di as res "wrote seq_wtd_vs_unwtd.csv"

*==============================================================================
* RECONCILIATION (soft; prints to log, does not abort). Sequential endpoints
* must equal the S13 eleven cells, since step 0 is the eleven base and step 5
* the eleven full. Expected (S13): weighted base 1.0852 / full 0.9741;
* unweighted base 1.0596 / full 0.9519 (Sec+).
*==============================================================================
preserve
    keep if contrast=="Sec+" & (step=="0" | step=="5")
    list weighting step coef, clean noobs
    di as res "Compare weighted step0->1.0852 step5->0.9741; unweighted step0->1.0596 step5->0.9519."
restore

log close
*==============================================================================
* SEND BACK: robust_specFE_wtd_vs_unwtd.csv , seq_wtd_vs_unwtd.csv ,
*            paper2_20261014_robust_all_wtd_vs_unwtd.log
*
* READ IT LIKE THIS
*  - specFE CSV, block=spec (S17): base, full, atten (%) for nine/ten/eleven,
*    weighted and unweighted, both contrasts. Compare the two weighting rows.
*  - specFE CSV, block=fe (S20): full-model education coefficient under
*    noFE / region / state, both weightings. base and atten blank on purpose.
*  - seq CSV (S18): per-step education coefficient, SE, 95% CI, p, attenuation,
*    both contrasts, both weightings.
*
* EXPECT (so you know it ran right)
*  - spec nine Sec+ weighted base ~ 1.073, full ~ 0.990, atten ~ 7.73%;
*    unweighted base ~ 1.085, full ~ 1.002, atten ~ 7.70%.
*  - spec eleven Sec+ weighted atten ~ 10.24%; unweighted ~ 10.16%.
*  - fe region Sec+ should match spec nine Sec+ full (same model, ~0.990);
*    fe state Sec+ weighted ~ 1.009 (matches the state-FE run).
*  - seq step 0 Sec+ == spec eleven base; seq step 5 Sec+ == spec eleven full.
*==============================================================================
