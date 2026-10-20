*==============================================================================
* Paper 2 - Weighted sensitivity analysis (reviewer supplement, Table S13)
* Question: does survey weighting materially change the education-cognition
* contrasts and the attenuation, versus the unweighted primary analysis?
*
* Design: cross-sectional at LASI-DAD Wave 2.
* Weight: r2hwtresp = harmonized person-level Wave 2 cross-sectional weight
*         (makes Wave 2 nationally representative). Lives in H_LASI_DAD_b2.dta,
*         not the analytic file, so it is merged in by prim_key below.
* Note:   The harmonized files do not publish clean PSU/strata variables.
*         Default svyset uses pweight only (linearized SEs). If PSU and strata
*         are available, set $PSU and $STRATA below and the svyset switches on.
* Run WHOLE (locals die between Enclave chunks). Nothing here is block-safe.
*==============================================================================

clear all
set more off
cd $OUTDIR
capture log close
log using paper2_20260925_weighted_sensitivity.log, replace

*--- model pieces (identical to the unweighted primary analysis) ---------------
global COVARS "age_c70 i.ragender i.r2hruralc i.r2hcastec wealth_quintile i.region5"
global COVARS_PLAIN "age_c70 ragender r2hruralc r2hcastec wealth_quintile region5"
global M9  "lancet_htn lancet_obese lancet_diabetes lancet_smoking lancet_vision hearing_mod lancet_depression lancet_isolated lancet_tbi"
global M11 "$M9 lancet_inactive fuel_unclean"
global WT  "r2hwtresp"

* Optional design variables. Leave empty to use pweight-only svyset.
global STRATA ""
global PSU    ""

*==============================================================================
* STEP 1. Load analytic file, rebuild age_c70 if absent, merge the Wave 2 weight
*==============================================================================
use Paper2_bmi4_analysis.dta, clear
di "N loaded: " _N

capture confirm variable age_c70
if _rc {
    capture confirm variable r2hagey
    if _rc {
        di as error "Neither age_c70 nor r2hagey present. Cannot build age term."
        exit 111
    }
    gen double age_c70 = r2hagey - 70
}

* prim_key is a long string key; protect it from float mangling before merge.
capture confirm string variable prim_key
if _rc {
    tostring prim_key, replace format(%15.0f)
}

* Merge in the Wave 2 cross-sectional weight from the harmonized DAD backbone.
* Adjust the path/filename only if it differs in your session.
preserve
    use prim_key r2hwtresp using "H_LASI_DAD_b2.dta", clear
    capture confirm string variable prim_key
    if _rc {
        tostring prim_key, replace format(%15.0f)
    }
    tempfile wtfile
    save `wtfile'
restore
merge 1:1 prim_key using `wtfile', keep(master match) nogen

capture confirm variable r2hwtresp
if _rc {
    di as error "r2hwtresp did not merge. Check the DAD file name and prim_key type."
    exit 111
}

*==============================================================================
* STEP 2. Fixed complete-case markers (base and full share one sample per spec).
* markout needs plain names, no i. prefixes; marker must be gen byte.
*==============================================================================
gen byte insamp9 = 1
markout insamp9 r2sgcp edu_3cat $COVARS_PLAIN $M9 $WT
gen byte insamp11 = 1
markout insamp11 r2sgcp edu_3cat $COVARS_PLAIN $M11 $WT

count if insamp9==1
di "Weighted nine-factor N: " r(N)
count if insamp11==1
di "Weighted eleven-factor N: " r(N)

*==============================================================================
* STEP 3. svyset. pweight-only by default; strata/psu switch on if provided.
*==============================================================================
if "$STRATA"!="" & "$PSU"!="" {
    svyset $PSU [pweight=$WT], strata($STRATA)
}
else {
    svyset [pweight=$WT]
}

*==============================================================================
* STEP 4. Weighted and unweighted base/full contrasts + attenuation.
* One postfile row per spec x contrast x weighting. Plain handle, capture first.
*==============================================================================
capture postclose pf_w
postfile pf_w str12 spec str10 contrast str10 weighting ///
    double base_b base_se full_b full_se atten_pct n ///
    using s13_weighted_sensitivity.csv, replace

* program to post one spec/contrast/weighting row from current base and full ests
* (done inline below since Enclave programs are fragile; repeat per block)

*------------------------------ NINE-FACTOR -----------------------------------*
* Weighted
svy, subpop(if insamp9==1): regress r2sgcp i.edu_3cat $COVARS
scalar b_b1 = _b[1.edu_3cat]
scalar s_b1 = _se[1.edu_3cat]
scalar b_b2 = _b[2.edu_3cat]
scalar s_b2 = _se[2.edu_3cat]
scalar nn   = e(N_sub)
svy, subpop(if insamp9==1): regress r2sgcp i.edu_3cat $COVARS $M9
scalar f_b1 = _b[1.edu_3cat]
scalar s_f1 = _se[1.edu_3cat]
scalar f_b2 = _b[2.edu_3cat]
scalar s_f2 = _se[2.edu_3cat]
post pf_w ("nine") ("Primary") ("weighted") (b_b1) (s_b1) (f_b1) (s_f1) (100*(b_b1-f_b1)/b_b1) (nn)
post pf_w ("nine") ("Sec+")    ("weighted") (b_b2) (s_b2) (f_b2) (s_f2) (100*(b_b2-f_b2)/b_b2) (nn)

* Unweighted (same fixed sample)
regress r2sgcp i.edu_3cat $COVARS if insamp9==1
scalar b_b1 = _b[1.edu_3cat]
scalar s_b1 = _se[1.edu_3cat]
scalar b_b2 = _b[2.edu_3cat]
scalar s_b2 = _se[2.edu_3cat]
scalar nn   = e(N)
regress r2sgcp i.edu_3cat $COVARS $M9 if insamp9==1
scalar f_b1 = _b[1.edu_3cat]
scalar s_f1 = _se[1.edu_3cat]
scalar f_b2 = _b[2.edu_3cat]
scalar s_f2 = _se[2.edu_3cat]
post pf_w ("nine") ("Primary") ("unweighted") (b_b1) (s_b1) (f_b1) (s_f1) (100*(b_b1-f_b1)/b_b1) (nn)
post pf_w ("nine") ("Sec+")    ("unweighted") (b_b2) (s_b2) (f_b2) (s_f2) (100*(b_b2-f_b2)/b_b2) (nn)

*----------------------------- ELEVEN-FACTOR ----------------------------------*
* Weighted
svy, subpop(if insamp11==1): regress r2sgcp i.edu_3cat $COVARS
scalar b_b1 = _b[1.edu_3cat]
scalar s_b1 = _se[1.edu_3cat]
scalar b_b2 = _b[2.edu_3cat]
scalar s_b2 = _se[2.edu_3cat]
scalar nn   = e(N_sub)
svy, subpop(if insamp11==1): regress r2sgcp i.edu_3cat $COVARS $M11
scalar f_b1 = _b[1.edu_3cat]
scalar s_f1 = _se[1.edu_3cat]
scalar f_b2 = _b[2.edu_3cat]
scalar s_f2 = _se[2.edu_3cat]
post pf_w ("eleven") ("Primary") ("weighted") (b_b1) (s_b1) (f_b1) (s_f1) (100*(b_b1-f_b1)/b_b1) (nn)
post pf_w ("eleven") ("Sec+")    ("weighted") (b_b2) (s_b2) (f_b2) (s_f2) (100*(b_b2-f_b2)/b_b2) (nn)

* Unweighted (same fixed sample)
regress r2sgcp i.edu_3cat $COVARS if insamp11==1
scalar b_b1 = _b[1.edu_3cat]
scalar s_b1 = _se[1.edu_3cat]
scalar b_b2 = _b[2.edu_3cat]
scalar s_b2 = _se[2.edu_3cat]
scalar nn   = e(N)
regress r2sgcp i.edu_3cat $COVARS $M11 if insamp11==1
scalar f_b1 = _b[1.edu_3cat]
scalar s_f1 = _se[1.edu_3cat]
scalar f_b2 = _b[2.edu_3cat]
scalar s_f2 = _se[2.edu_3cat]
post pf_w ("eleven") ("Primary") ("unweighted") (b_b1) (s_b1) (f_b1) (s_f1) (100*(b_b1-f_b1)/b_b1) (nn)
post pf_w ("eleven") ("Sec+")    ("unweighted") (b_b2) (s_b2) (f_b2) (s_f2) (100*(b_b2-f_b2)/b_b2) (nn)

postclose pf_w

*==============================================================================
* STEP 5. Weighted b-paths (mediator -> cognition) from the full models, so the
* mediator story can be checked under weighting. One row per mediator per spec.
*==============================================================================
capture postclose pf_b
postfile pf_b str12 spec str24 mediator double bpath se_b using s13_weighted_bpaths.csv, replace

svy, subpop(if insamp9==1): regress r2sgcp i.edu_3cat $COVARS $M9
foreach v of global M9 {
    post pf_b ("nine") ("`v'") (_b[`v']) (_se[`v'])
}
svy, subpop(if insamp11==1): regress r2sgcp i.edu_3cat $COVARS $M11
foreach v of global M11 {
    post pf_b ("eleven") ("`v'") (_b[`v']) (_se[`v'])
}
postclose pf_b

export delimited using s13_weighted_sensitivity_view.csv, replace   // convenience echo
log close

*==============================================================================
* OUTPUTS to export through the review pipeline:
*   s13_weighted_sensitivity.csv   - base/full/attenuation, weighted vs unweighted
*   s13_weighted_bpaths.csv        - weighted mediator b-paths, both specs
*   paper2_20260925_weighted_sensitivity.log
*==============================================================================
