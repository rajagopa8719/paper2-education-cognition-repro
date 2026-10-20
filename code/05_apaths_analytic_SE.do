*==============================================================================
* Paper 2 -- WEIGHTED ANALYTIC A-PATHS (education -> each factor), both specs.
*
* Weighted analogue of apaths_se.csv. For every mediator it returns the
* survey-weighted coefficient and robust SE of the Primary and Secondary-or-
* higher education contrasts, on the SAME fixed samples as the mediation runs
* (nine-factor N = 3,355; eleven-factor N = 2,365).
*
* a-path = coefficient on i.edu_3cat in:  regress factor i.edu_3cat COVARS [pw]
* Binary factors use a linear probability model (regress), as in the manuscript.
* pweight returns robust (analytic) SEs -- the same basis as apaths_se.csv.
* Output: weighted_apaths_se.csv   (mediator, spec, contrast, a, se)
*         -- same columns as apaths_se.csv, so it drops in beside it.
*==============================================================================
clear all
set more off

* -- OUTDIR is NOT persistent between Enclave sessions; set it every time. -----
global OUTDIR "\\Skyhub\Resources\Project\GGAD00-0080\output"
cd "$OUTDIR"

capture log close
log using paper2_20261012_weighted_apaths.log, replace

* ---- model pieces (verbatim from the mediation runs) ----
global COVARS       "age_c70 i.ragender i.r2hruralc i.r2hcastec wealth_quintile i.region5"
global COVARS_PLAIN "age_c70 ragender r2hruralc r2hcastec wealth_quintile region5"
global M9  "lancet_htn lancet_obese lancet_diabetes lancet_smoking lancet_vision hearing_mod lancet_depression lancet_isolated lancet_tbi"
global M11 "lancet_htn lancet_obese lancet_diabetes lancet_smoking lancet_vision hearing_mod lancet_depression lancet_isolated lancet_tbi lancet_inactive fuel_unclean"
global WT  "r2hwtresp"

* ---- load analytic file; bring in the Wave 2 weight if not already present ----
use Paper2_bmi4_analysis.dta, clear
capture confirm variable age_c70
if _rc gen double age_c70 = r2hagey - 70

capture confirm variable r2hwtresp
if _rc merge 1:1 prim_key using Lancet14_B2_operationalized.dta, ///
        keepusing(r2hwtresp) keep(master match) nogen

* strip the stale mi marker stamped on by merging an mi-set using file
capture mi unset
capture drop _mi_*
local __chars : char _dta[]
foreach c of local __chars {
    char _dta[`c'] ""
}

* ---- fixed samples, identical to the mediation and bootstrap runs ----
capture drop insamp9 insamp11
gen byte insamp9 = 1
markout insamp9 r2sgcp edu_3cat $COVARS_PLAIN $M9 $WT
count if insamp9==1
di as res "nine-factor N (expect 3355): " r(N)
assert r(N)==3355

gen byte insamp11 = 1
markout insamp11 r2sgcp edu_3cat $COVARS_PLAIN $M11 $WT
count if insamp11==1
di as res "eleven-factor N (expect 2365): " r(N)
assert r(N)==2365

* ---- a-path export (postfile writes a .dta; export a real CSV after) ----
* Column order matches apaths_se.csv exactly: mediator, spec, contrast, a, se.
capture postclose pf_a
postfile pf_a str24 mediator str8 spec str10 contrast double(a se) ///
    using weighted_apaths_se.dta, replace

foreach spec in nine eleven {

    if "`spec'"=="nine" {
        local fac  "$M9"
        local samp "insamp9==1"
    }
    if "`spec'"=="eleven" {
        local fac  "$M11"
        local samp "insamp11==1"
    }

    foreach k of local fac {
        * linear probability model: factor on education + covariates, weighted
        regress `k' i.edu_3cat $COVARS [pw=$WT] if `samp'
        * Primary = 1.edu_3cat, Secondary-or-higher = 2.edu_3cat
        post pf_a ("`k'") ("`spec'") ("Primary")   (_b[1.edu_3cat]) (_se[1.edu_3cat])
        post pf_a ("`k'") ("`spec'") ("Secondary") (_b[2.edu_3cat]) (_se[2.edu_3cat])
        di as txt "`spec' `k': Pri " %7.4f _b[1.edu_3cat] " (" %6.4f _se[1.edu_3cat] ")  Sec " %7.4f _b[2.edu_3cat] " (" %6.4f _se[2.edu_3cat] ")"
    }
}
postclose pf_a

use weighted_apaths_se.dta, clear
list, clean noobs
export delimited using weighted_apaths_se.csv, replace
di as res "wrote weighted_apaths_se.csv"

log close
*==============================================================================
* SEND BACK: weighted_apaths_se.csv  and  paper2_20261012_weighted_apaths.log
*
* EXPECT (a-path POINTS must match the bootstrap points already in s15, and
* must DIFFER from the unweighted apaths_se.csv; only the SE changes basis):
*   nine   lancet_obese    Secondary a ~  0.100   (unweighted was 0.117)
*   nine   lancet_isolated Secondary a ~ -0.040   (unweighted was -0.047)
*   eleven fuel_unclean    Secondary a ~ -0.194   (unweighted was -0.184)
* FAILURE POINTS:
*   1. assert N trips  -> weight or a factor did not merge for all rows.
*   2. "3.edu_3cat not found" -> edu_3cat is 0/1/2; Primary=1, Sec+=2.
*==============================================================================
