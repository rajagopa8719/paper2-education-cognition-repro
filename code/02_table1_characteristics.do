*==============================================================================
* Paper 2 -- Block B, standalone rerun
* Purpose: rebuild Table 1 on the nine-factor primary sample (insamp9, N=3,355)
*          and fill the four outstanding characteristics rows.
* Output:  one CSV in final table layout + one CSV of raw cell counts.
* Written 2 Aug 2026. Supersedes lines 90-109 of Paper2_v6_primary_respec.do.
* Run inside the Enclave.
*
* INPUT REQUIREMENT
*   The input file must hold every Wave 2 respondent with complete outcome
*   and covariates, not just the 2,406 core. insamp9 is built by markout, so
*   it can only recover the 3,355 if the 949 inactive-only exclusions are
*   present in the loaded data. STEP 2 now asserts r(N)==3355 and aborts if
*   they are not. See LIKELY FAILURE POINTS at the foot of the file.
*
* EDITS 2 Aug 2026 (v7 fixed):
*   1. STEP 2 asserts insamp9==3,355 instead of only printing it.
*   2. cd $OUTDIR replaces a hardcoded path with unverified casing.
*   3. STEP 3 reconstructs r2hagey from age_c70 + 70 when it is absent.
*==============================================================================

version 17
clear all
set more off
set linesize 200

* Use $OUTDIR, which is writable. The old hardcoded path used lowercase
* "project", whose casing was never confirmed on this share, and pointed
* outside $OUTDIR. If $OUTDIR is not set in your profile, set it before
* running. Confirm from the log that the cd landed before trusting output.
cd $OUTDIR
capture log close
log using "Paper2_20260802_blockB.log", replace text

use "Paper2_analytic_v1.dta", clear

*------------------------------------------------------------------------------
* STEP 0. Verify codings before anything is computed.
* Read this output before trusting the CSV. Three things must hold:
*   (a) edu_3cat is 0/1/2 with 0 = no education
*   (b) every lancet_* factor and hearing_mod is 0/1, not 1/2
*   (c) ragender and r2hruralc levels are what STEP 1 assumes
*------------------------------------------------------------------------------
codebook edu_3cat ragender r2hruralc, compact
fvset base 0 edu_3cat

foreach v in lancet_htn lancet_obese lancet_diabetes lancet_smoking ///
             lancet_vision hearing_mod lancet_depression lancet_isolated ///
             lancet_tbi fuel_unclean {
    quietly summarize `v'
    display as text "`v': min=" r(min) "  max=" r(max) "  n=" r(N)
    capture assert inlist(`v', 0, 1) if !missing(`v')
    if _rc {
        display as error ">>> `v' IS NOT CODED 0/1 -- STOP AND RECODE <<<"
    }
}

*------------------------------------------------------------------------------
* STEP 1. Derived indicators for the characteristics block.
* ragender in Gateway harmonised files is 1 = man, 2 = woman.
* If the codebook above disagrees, edit these two lines and rerun.
*------------------------------------------------------------------------------
capture drop female rural
gen byte female = (ragender == 2) if !missing(ragender)
gen byte rural  = (r2hruralc == 1) if !missing(r2hruralc)
label variable female "Female"
label variable rural  "Rural residence"
tab ragender female, missing
tab r2hruralc rural, missing

*------------------------------------------------------------------------------
* STEP 2. Samples.
*------------------------------------------------------------------------------
global COVARS "age_c70 i.ragender i.r2hruralc i.r2hcastec wealth_quintile"
global VASC   "lancet_htn lancet_obese lancet_diabetes lancet_smoking"
global SENS   "hearing_mod lancet_vision"
global MENT   "lancet_depression lancet_isolated lancet_tbi"
global M9     "$VASC $SENS $MENT"

capture drop insamp9
gen byte insamp9 = 1
markout insamp9 r2sgcp edu_3cat age_c70 ragender r2hruralc r2hcastec ///
        wealth_quintile region5 $M9
tab insamp9                                        // expect 3,355

* HARD CHECK. insamp9 must land on the nine-factor primary sample.
* If this trips, the input file does not hold every covariate-complete
* respondent (it was likely trimmed to the 2,406 core), so the 949
* inactive-only exclusions are absent and every percentage below would
* be computed on the wrong sample. STOP. Reload from the untrimmed save
* and confirm it still carries fuel_unclean, r2hmbmi and r2hagey.
count if insamp9==1
assert r(N)==3355

capture drop insamp9f
gen byte insamp9f = (insamp9==1 & !missing(fuel_unclean))
tab insamp9f                                       // fuel coverage on the primary sample

* stratum denominators, which every percentage below must divide
tab edu_3cat if insamp9==1
tab edu_3cat if insamp9f==1

*------------------------------------------------------------------------------
* STEP 3. Table 1 written straight to CSV.
* Binary factors: column percentage within education stratum + Pearson chi2 p.
* Continuous rows: mean (SD) + p from a one-way test across the three strata.
*------------------------------------------------------------------------------
tempname T C
file open `T' using "v7_table1_insamp9.csv", write replace text
file open `C' using "v7_table1_cellcounts.csv", write replace text
file write `T' "row,type,no_education,primary,secondary_plus,overall,p,source_sample" _n
file write `C' "row,stratum,n_present,n_stratum" _n

* ---- denominators for the header line
foreach s in 9 9f {
    quietly count if insamp`s'==1
    local Ntot`s' = r(N)
    forvalues k = 0/2 {
        quietly count if insamp`s'==1 & edu_3cat==`k'
        local N`s'_`k' = r(N)
    }
}
file write `T' "DENOMINATOR (nine-factor),n,`N9_0',`N9_1',`N9_2',`Ntot9',," _n
file write `T' "DENOMINATOR (fuel subsample),n,`N9f_0',`N9f_1',`N9f_2',`Ntot9f',," _n

* ---- binary risk factors on insamp9
foreach v in lancet_htn lancet_diabetes lancet_obese lancet_smoking ///
             lancet_depression lancet_isolated lancet_tbi ///
             hearing_mod lancet_vision {

    quietly tab `v' edu_3cat if insamp9==1, chi2
    local p = r(p)

    forvalues k = 0/2 {
        quietly summarize `v' if insamp9==1 & edu_3cat==`k'
        local pct`k' = 100*r(mean)
        quietly count if insamp9==1 & edu_3cat==`k' & `v'==1
        local cnt`k' = r(N)
        file write `C' "`v',`k',`cnt`k'',`N9_`k''" _n
    }
    quietly summarize `v' if insamp9==1
    local pcto = 100*r(mean)
    quietly count if insamp9==1 & `v'==1
    file write `C' "`v',overall,`r(N)',`Ntot9'" _n

    file write `T' "`v',binary," ///
        %5.1f (`pct0') "," %5.1f (`pct1') "," %5.1f (`pct2') "," ///
        %5.1f (`pcto') "," %6.4f (`p') ",insamp9" _n

    * printed as well, so the log can be checked against the CSV
    display as result _newline "=== `v' (insamp9) ==="
    tab `v' edu_3cat if insamp9==1, col chi2
}

* ---- cooking fuel, on its own subsample, flagged as such
quietly tab fuel_unclean edu_3cat if insamp9f==1, chi2
local p = r(p)
forvalues k = 0/2 {
    quietly summarize fuel_unclean if insamp9f==1 & edu_3cat==`k'
    local pct`k' = 100*r(mean)
    quietly count if insamp9f==1 & edu_3cat==`k' & fuel_unclean==1
    file write `C' "fuel_unclean,`k',`r(N)',`N9f_`k''" _n
}
quietly summarize fuel_unclean if insamp9f==1
local pcto = 100*r(mean)
file write `T' "fuel_unclean,binary," ///
    %5.1f (`pct0') "," %5.1f (`pct1') "," %5.1f (`pct2') "," ///
    %5.1f (`pcto') "," %6.4f (`p') ",insamp9f" _n
display as result _newline "=== fuel_unclean (insamp9f) ==="
tab fuel_unclean edu_3cat if insamp9f==1, col chi2

* ---- age fallback: reconstruct r2hagey when it is not in the file.
* age_c70 is age centred at 70, so age = age_c70 + 70 exactly. The
* reconstructed variable has the same SD as age_c70 and a mean of 70
* plus the centred mean. Flag it in the table note when this path runs.
capture confirm variable r2hagey
if _rc {
    display as error ">>> r2hagey absent -- reconstructing as age_c70 + 70 <<<"
    gen double r2hagey = age_c70 + 70
    label variable r2hagey "Age, years (reconstructed from age_c70 + 70)"
}

* ---- continuous characteristics: age, cognition, BMI, wealth
foreach v in r2hagey r2sgcp r2hmbmi wealth_quintile {
    capture confirm variable `v'
    if _rc {
        display as error ">>> `v' NOT IN FILE -- merge it from the core file <<<"
        file write `T' "`v',MISSING FROM FILE,,,,,," _n
        continue
    }
    quietly regress `v' i.edu_3cat if insamp9==1
    quietly testparm i.edu_3cat
    local p = r(p)
    forvalues k = 0/2 {
        quietly summarize `v' if insamp9==1 & edu_3cat==`k'
        local m`k' = r(mean)
        local s`k' = r(sd)
    }
    quietly summarize `v' if insamp9==1
    local mo = r(mean)
    local so = r(sd)
    file write `T' "`v',mean (SD)," ///
        %5.1f (`m0') " (" %4.1f (`s0') ")," ///
        %5.1f (`m1') " (" %4.1f (`s1') ")," ///
        %5.1f (`m2') " (" %4.1f (`s2') ")," ///
        %5.1f (`mo') " (" %4.1f (`so') ")," %6.4f (`p') ",insamp9" _n
    display as result _newline "=== `v' (insamp9) ==="
    tabstat `v' if insamp9==1, by(edu_3cat) stats(n mean sd min max) columns(statistics)
}

* ---- binary characteristics: female, rural
foreach v in female rural {
    quietly tab `v' edu_3cat if insamp9==1, chi2
    local p = r(p)
    forvalues k = 0/2 {
        quietly summarize `v' if insamp9==1 & edu_3cat==`k'
        local pct`k' = 100*r(mean)
    }
    quietly summarize `v' if insamp9==1
    local pcto = 100*r(mean)
    file write `T' "`v',binary," ///
        %5.1f (`pct0') "," %5.1f (`pct1') "," %5.1f (`pct2') "," ///
        %5.1f (`pcto') "," %6.4f (`p') ",insamp9" _n
    display as result _newline "=== `v' (insamp9) ==="
    tab `v' edu_3cat if insamp9==1, col chi2
}

file close `T'
file close `C'
type "v7_table1_insamp9.csv"

*------------------------------------------------------------------------------
* STEP 4. Table 1b: BMI in four categories on the primary sample.
* Fixes the reference-group problem in the binary High BMI factor.
*------------------------------------------------------------------------------
capture confirm variable r2hmbmi
if !_rc {
    capture drop bmi4
    gen byte bmi4 = .
    replace bmi4 = 1 if r2hmbmi <  18.5 & !missing(r2hmbmi)
    replace bmi4 = 2 if inrange(r2hmbmi, 18.5, 24.9999)
    replace bmi4 = 3 if inrange(r2hmbmi, 25.0, 29.9999)
    replace bmi4 = 4 if r2hmbmi >= 30.0 & !missing(r2hmbmi)
    label define bmi4l 1 "Underweight <18.5" 2 "Normal 18.5-24.9" ///
                       3 "Overweight 25-29.9" 4 "Obese >=30", replace
    label values bmi4 bmi4l

    * consistency with the binary factor: bmi4 in {3,4} must equal lancet_obese
    tab bmi4 lancet_obese if insamp9==1, missing
    count if insamp9==1 & missing(bmi4)

    tab bmi4 if insamp9==1
    tab bmi4 edu_3cat if insamp9==1, col chi2
}

*------------------------------------------------------------------------------
* STEP 5. Covariate distribution by education, for the Table 1 header block.
*------------------------------------------------------------------------------
foreach v in r2hcastec wealth_quintile region5 {
    display as result _newline "=== `v' (insamp9) ==="
    tab `v' edu_3cat if insamp9==1, col chi2
}

* where do the North Eastern states sit? five groupings imply the standard
* Zonal Councils, which exclude the separately constituted North Eastern Council
label list region5
tab region5 if insamp9==1

log close

*==============================================================================
* WHAT TO SEND BACK
*   Paper2_20260802_blockB.log   -- full output, including the STEP 0 checks
*   v7_table1_insamp9.csv        -- Table 1 in final layout
*   v7_table1_cellcounts.csv     -- numerators and denominators, for arithmetic checks
*
* LIKELY FAILURE POINTS
*   0. STEP 2 assert r(N)==3355 trips. The input file does not hold the 949
*      inactive-only respondents, so it was trimmed to the 2,406 core (or the
*      2,365 primary). Reload from the untrimmed save and confirm it still
*      carries fuel_unclean, r2hmbmi and r2hagey before rerunning. This is the
*      most likely stop and it is deliberate: a short sample would otherwise
*      print a Table 1 on the wrong denominators.
*   1. r2hagey absent. STEP 3 now reconstructs it as age_c70 + 70 and flags the
*      row, so the age line fills either way. If the reconstruction path runs,
*      add the footnote and note that the SD equals age_c70's.
*   2. ragender coded other than 1/2, which would invert the female row. STEP 1
*      cross-tabulates the derived indicator against the source variable; check it.
*   3. r2hruralc coded 2 = rural rather than 1. Same check applies.
*   4. fuel_unclean produced r(111) in the 28 July run when a work file was loaded
*      instead of the intended analytic file. If insamp9f is 0, that is the cause.
*   5. If any factor fails the 0/1 assert in STEP 0, every percentage for that row
*      is meaningless because summarize is averaging the codes, not the indicator.
*   6. cd $OUTDIR fails. If $OUTDIR is unset the log and CSVs never write. Set it
*      in your profile first, and confirm from the log that the cd landed.
*==============================================================================
