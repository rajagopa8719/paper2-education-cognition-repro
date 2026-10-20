*==============================================================================
* Paper2_weighted_indirect_boot_20261001.do
* Weighted a-paths + weighted indirect effects with bootstrap CIs.
* Main = nine-factor (N=3,355); Secondary = eleven-factor (N=2,365).
* Survey weight r2hwtresp applied as pweight in every regression.
*
* Model pieces copied verbatim from the S13 run
*   (paper2_20260925_weighted_sensitivity.log) so this matches S13/S14 exactly:
*   - COVARS include caste (r2hcastec).
*   - insamp9 / insamp11 are BUILT here with markout on the complete-case set
*     that includes the weight. The file's own insamp/insamp2 are NOT these.
* Answers Sijiu (2026-09-27): adds the weighted a-paths and indirects with CIs
*   (S13/S14 gave only weighted base/full and weighted b-paths).
* Case-resampling bootstrap; pweight-only (no clean PSU/strata in harmonized).
*==============================================================================

clear all
set more off
cd "\\Skyhub\Resources\Project\GGAD00-0080\output"
capture log close
log using paper2_20261001_wboot_5000.log, replace

*------------------------------------------------------------------------------
* Model pieces -- verbatim from the S13 log. Do not edit.
*------------------------------------------------------------------------------
global OUTCOME "r2sgcp"
global COVARS       "age_c70 i.ragender i.r2hruralc i.r2hcastec wealth_quintile i.region5"
global COVARS_PLAIN "age_c70 ragender r2hruralc r2hcastec wealth_quintile region5"
global M9  "lancet_htn lancet_obese lancet_diabetes lancet_smoking lancet_vision hearing_mod lancet_depression lancet_isolated lancet_tbi"
global M11 "lancet_htn lancet_obese lancet_diabetes lancet_smoking lancet_vision hearing_mod lancet_depression lancet_isolated lancet_tbi lancet_inactive fuel_unclean"
global WT  "r2hwtresp"
global NREPS 5000    // smoke-test value. Set to 5000 only after BOTH gates pass.
set seed 20260930

*------------------------------------------------------------------------------
* Load, bring in the weight, strip the stale mi marker.
* Both files are in the output folder we cd'd into, so load them bare.
* The whole merge is ONE physical line. Do not split the options onto a new line.
*------------------------------------------------------------------------------
use Paper2_bmi4_analysis.dta, clear
di "N loaded (expect 6168): " _N

capture confirm variable age_c70
if _rc {
    gen double age_c70 = r2hagey - 70
}

merge 1:1 prim_key using Lancet14_B2_operationalized.dta, keepusing(r2hwtresp) keep(master match) nogen
capture mi unset
capture drop _mi_*
local __chars : char _dta[]
foreach c of local __chars {
    char _dta[`c'] ""
}
count if missing(r2hwtresp)
di as txt "rows missing weight (S13 saw 1530): " r(N)

*------------------------------------------------------------------------------
* Build the SAME fixed complete-case samples S13 used (markout needs plain
* names, no i. prefixes; marker must be gen byte). These replace insamp/insamp2.
*------------------------------------------------------------------------------
gen byte insamp9 = 1
markout insamp9 r2sgcp edu_3cat $COVARS_PLAIN $M9 $WT
gen byte insamp11 = 1
markout insamp11 r2sgcp edu_3cat $COVARS_PLAIN $M11 $WT

count if insamp9==1
di as res "nine-factor N (expect 3355): " r(N)
assert r(N)==3355
count if insamp11==1
di as res "eleven-factor N (expect 2365): " r(N)
assert r(N)==2365

global SAMP9  "insamp9==1"
global SAMP11 "insamp11==1"

*==============================================================================
* run_spec: one specification, one call. arg 1 = 9 or 11.
* Observed a-paths, b-paths, indirects, base/full/attenuation for both contrasts
* (Sec+ and Primary); reconciliation gate; case-resampling bootstrap; one CSV.
* Nine exports before eleven touches the data (checkpoint), calls run in order.
*==============================================================================
capture program drop run_spec
program define run_spec
    args spec

    if `spec' == 9 {
        local meds "$M9"
        local samp "$SAMP9"
        local lab  "nine"
        local outcsv "s15_weighted_indirect_nine.csv"
    }
    else {
        local meds "$M11"
        local samp "$SAMP11"
        local lab  "eleven"
        local outcsv "s15_weighted_indirect_eleven.csv"
    }

    tempfile alldata specsample
    save "`alldata'", replace
    quietly keep if `samp'
    quietly count
    di as txt "[`lab'] fixed-sample N = " r(N)
    save "`specsample'", replace

    capture postclose pf
    postfile pf str8 spec str32 param double(rep value) using `lab'_boot.dta, replace

    forvalues r = 0/$NREPS {
        quietly use "`specsample'", clear
        if `r' > 0 bsample

        quietly regress $OUTCOME i.edu_3cat $COVARS [pw=$WT]
        scalar base_sec = _b[2.edu_3cat]
        scalar base_pri = _b[1.edu_3cat]

        quietly regress $OUTCOME i.edu_3cat `meds' $COVARS [pw=$WT]
        scalar full_sec = _b[2.edu_3cat]
        scalar full_pri = _b[1.edu_3cat]
        foreach m of local meds {
            scalar bb_`m' = _b[`m']
        }

        scalar tot_sec = 0
        scalar tot_pri = 0
        foreach m of local meds {
            quietly regress `m' i.edu_3cat $COVARS [pw=$WT]
            scalar aa_sec = _b[2.edu_3cat]
            scalar aa_pri = _b[1.edu_3cat]
            post pf ("`lab'") ("a_`m'_sec")   (`r') (aa_sec)
            post pf ("`lab'") ("a_`m'_pri")   (`r') (aa_pri)
            post pf ("`lab'") ("b_`m'")       (`r') (bb_`m')
            post pf ("`lab'") ("ind_`m'_sec") (`r') (aa_sec*bb_`m')
            post pf ("`lab'") ("ind_`m'_pri") (`r') (aa_pri*bb_`m')
            scalar tot_sec = tot_sec + aa_sec*bb_`m'
            scalar tot_pri = tot_pri + aa_pri*bb_`m'
        }

        post pf ("`lab'") ("base_sec")    (`r') (base_sec)
        post pf ("`lab'") ("full_sec")    (`r') (full_sec)
        post pf ("`lab'") ("tot_ind_sec") (`r') (tot_sec)
        post pf ("`lab'") ("atten_sec")   (`r') ((base_sec-full_sec)/base_sec)
        post pf ("`lab'") ("base_pri")    (`r') (base_pri)
        post pf ("`lab'") ("full_pri")    (`r') (full_pri)
        post pf ("`lab'") ("tot_ind_pri") (`r') (tot_pri)
        post pf ("`lab'") ("atten_pri")   (`r') ((base_pri-full_pri)/base_pri)

        if `r' == 0 {
            assert abs((base_sec-full_sec) - tot_sec) < 1e-6
            assert abs((base_pri-full_pri) - tot_pri) < 1e-6
            di as res "[`lab'] gate passed: sum(a*b) == base-full to 1e-6"
        }
    }
    postclose pf

    use `lab'_boot.dta, clear
    capture postclose sf
    postfile sf str8 spec str32 param double(point bse lo hi) using `lab'_summary.dta, replace
    levelsof param, local(params)
    foreach p of local params {
        quietly summarize value if param=="`p'" & rep==0, meanonly
        scalar pt = r(mean)
        quietly summarize value if param=="`p'" & rep>=1
        scalar bse = r(sd)
        quietly _pctile value if param=="`p'" & rep>=1, p(2.5 97.5)
        scalar lo = r(r1)
        scalar hi = r(r2)
        post sf ("`lab'") ("`p'") (pt) (bse) (lo) (hi)
    }
    postclose sf

    use `lab'_summary.dta, clear
    order spec param point bse lo hi
    export delimited using `outcsv', replace
    di as res "[`lab'] wrote `outcsv'"

    use "`alldata'", clear
end

run_spec 9
run_spec 11

*------------------------------------------------------------------------------
* Validation to eyeball:
*  1. b_* point values reproduce Table S14 (e.g. nine hearing_mod -0.168,
*     isolated -0.369, obese +0.212, depression -0.092).
*  2. eleven ind_lancet_inactive_sec CI should straddle zero.
*  3. eleven base_sec/full_sec ~ 1.085/0.974, atten_sec ~ 10.24% (S13 check).
* Only the small aggregate CSVs leave the enclave. No microdata is exported.
*------------------------------------------------------------------------------
log close
