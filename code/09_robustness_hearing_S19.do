*==============================================================
* Paper2_S19_hearing_common_wtd_vs_unwtd_20261016.do
* Priya Rajagopalan | Paper 2 | LASI-DAD
*
* PURPOSE: Supplement Table S19. Hearing-measure comparison on
*   ONE common sample, weighted and unweighted side by side.
*   Extends Block 5 of Paper2_v5_gapfill (unweighted only, N=1,845).
*   Same arms, now also with pweight r2hwtresp, same observations.
*
* OUTPUT: s19_hearing_common_wtd_vs_unwtd.csv
*   columns: arm weighting prim prim_se sec sec_se r2 n
*
* ENCLAVE RULES: globals only, capture drop before every gen,
*   gen byte for markers, bare filenames after cd, postfile not
*   estout, explicit commands. RUN BLOCK 0 FIRST and read it.
*==============================================================

* cd "<your Enclave Paper2 working folder>"

*==============================================================
* BLOCK 0. LOAD + VARIABLE CHECK. Stop here and read output.
*==============================================================
use Paper2_v5_work.dta, clear

* weight: merge defensively only if absent; strip mi AFTER merge.
capture confirm variable r2hwtresp
if _rc {
    merge 1:1 prim_key using H_LASI_DAD_b2.dta, ///
        keepusing(r2hwtresp) keep(master match) nogen
    capture mi unset
    capture drop _mi_*
}

confirm variable r2sgcp edu_3cat age_c70 ragender r2hruralc r2hcastec wealth_quintile region5
confirm variable lancet_htn lancet_obese lancet_diabetes lancet_smoking lancet_inactive lancet_vision lancet_depression lancet_isolated lancet_tbi
confirm variable r2h_bptacat r2h_imprmnt r2hwtresp

*==============================================================
* BLOCK 1. REBUILD the four hearing measures from raw.
*   PTA r2h_bptacat: 1 none, 2 mild, 3 moderate, 4 severe.
*   moderate+ = {3,4}; mild+ = {2,3,4}.
*==============================================================
capture drop hear_mod
gen byte hear_mod = .
replace hear_mod = 0 if inlist(r2h_bptacat, 1, 2)
replace hear_mod = 1 if inlist(r2h_bptacat, 3, 4)

capture drop hear_mild
gen byte hear_mild = .
replace hear_mild = 0 if r2h_bptacat == 1
replace hear_mild = 1 if inlist(r2h_bptacat, 2, 3, 4)

capture drop hear_self
gen byte hear_self = .
replace hear_self = 0 if r2h_imprmnt == 0
replace hear_self = 1 if r2h_imprmnt == 1

capture drop hear_self_b
gen byte hear_self_b = .
replace hear_self_b = 0 if r2h_imprmnt == 0
replace hear_self_b = 1 if r2h_imprmnt == 1
replace hear_self_b = 1 if r2h_imprmnt == 2

*==============================================================
* BLOCK 2. COMMON SAMPLE: base-9 + covariates + region5 + all
*   four hearing measures + the weight, all non-missing. Same
*   intersection for both weightings, so N matches across arms.
*==============================================================
global BASE10H "lancet_htn lancet_obese lancet_diabetes lancet_smoking lancet_inactive lancet_vision lancet_depression lancet_isolated lancet_tbi"
global COVARS  "age_c70 i.ragender i.r2hruralc i.r2hcastec wealth_quintile"

capture drop insamp_hear
gen byte insamp_hear = 1
markout insamp_hear r2sgcp edu_3cat age_c70 ragender r2hruralc r2hcastec wealth_quintile region5 lancet_htn lancet_obese lancet_diabetes lancet_smoking lancet_inactive lancet_vision lancet_depression lancet_isolated lancet_tbi hear_self hear_self_b hear_mod hear_mild r2hwtresp
tab insamp_hear

*==============================================================
* BLOCK 3. RUN. Each arm unweighted then weighted. postfile.
*==============================================================
capture postclose hp
postfile hp str12 arm str10 weighting double prim prim_se sec sec_se r2 long n using s19_hearing_common_wtd_vs_unwtd, replace

* ---- A_none ----
regress r2sgcp i.edu_3cat $BASE10H $COVARS i.region5 if insamp_hear==1
post hp ("A_none") ("unweighted") (_b[1.edu_3cat]) (_se[1.edu_3cat]) (_b[2.edu_3cat]) (_se[2.edu_3cat]) (e(r2)) (e(N))
regress r2sgcp i.edu_3cat $BASE10H $COVARS i.region5 [pw=r2hwtresp] if insamp_hear==1
post hp ("A_none") ("weighted") (_b[1.edu_3cat]) (_se[1.edu_3cat]) (_b[2.edu_3cat]) (_se[2.edu_3cat]) (e(r2)) (e(N))

* ---- B_self (self-report narrow) ----
regress r2sgcp i.edu_3cat $BASE10H hear_self $COVARS i.region5 if insamp_hear==1
post hp ("B_self") ("unweighted") (_b[1.edu_3cat]) (_se[1.edu_3cat]) (_b[2.edu_3cat]) (_se[2.edu_3cat]) (e(r2)) (e(N))
regress r2sgcp i.edu_3cat $BASE10H hear_self $COVARS i.region5 [pw=r2hwtresp] if insamp_hear==1
post hp ("B_self") ("weighted") (_b[1.edu_3cat]) (_se[1.edu_3cat]) (_b[2.edu_3cat]) (_se[2.edu_3cat]) (e(r2)) (e(N))

* ---- B_selfb (self-report broad) ----
regress r2sgcp i.edu_3cat $BASE10H hear_self_b $COVARS i.region5 if insamp_hear==1
post hp ("B_selfb") ("unweighted") (_b[1.edu_3cat]) (_se[1.edu_3cat]) (_b[2.edu_3cat]) (_se[2.edu_3cat]) (e(r2)) (e(N))
regress r2sgcp i.edu_3cat $BASE10H hear_self_b $COVARS i.region5 [pw=r2hwtresp] if insamp_hear==1
post hp ("B_selfb") ("weighted") (_b[1.edu_3cat]) (_se[1.edu_3cat]) (_b[2.edu_3cat]) (_se[2.edu_3cat]) (e(r2)) (e(N))

* ---- C_ptamod  (= hearing_mod, the main-analysis measure) ----
regress r2sgcp i.edu_3cat $BASE10H hear_mod $COVARS i.region5 if insamp_hear==1
post hp ("C_ptamod") ("unweighted") (_b[1.edu_3cat]) (_se[1.edu_3cat]) (_b[2.edu_3cat]) (_se[2.edu_3cat]) (e(r2)) (e(N))
regress r2sgcp i.edu_3cat $BASE10H hear_mod $COVARS i.region5 [pw=r2hwtresp] if insamp_hear==1
post hp ("C_ptamod") ("weighted") (_b[1.edu_3cat]) (_se[1.edu_3cat]) (_b[2.edu_3cat]) (_se[2.edu_3cat]) (e(r2)) (e(N))

* ---- D_ptamild ----
regress r2sgcp i.edu_3cat $BASE10H hear_mild $COVARS i.region5 if insamp_hear==1
post hp ("D_ptamild") ("unweighted") (_b[1.edu_3cat]) (_se[1.edu_3cat]) (_b[2.edu_3cat]) (_se[2.edu_3cat]) (e(r2)) (e(N))
regress r2sgcp i.edu_3cat $BASE10H hear_mild $COVARS i.region5 [pw=r2hwtresp] if insamp_hear==1
post hp ("D_ptamild") ("weighted") (_b[1.edu_3cat]) (_se[1.edu_3cat]) (_b[2.edu_3cat]) (_se[2.edu_3cat]) (e(r2)) (e(N))

postclose hp
use s19_hearing_common_wtd_vs_unwtd, clear
list, clean noobs
export delimited using s19_hearing_common_wtd_vs_unwtd.csv, replace

*==============================================================
* RECONCILIATION (soft). UNWEIGHTED arms should track the Aug-19
* common run (v5_hearing_common.csv), Sec+:
*   A_none 0.9511 | B_self 0.9513 | C_ptamod 0.9314 | D_ptamild 0.9550
* Small drift is expected IF adding the r2hwtresp markout changed
* N from 1,845. Report the Block 2 N. B_self == B_selfb here by
* construction: the common sample forces hear_self nonmissing,
* which drops r2h_imprmnt==2, so broad collapses to narrow.
*==============================================================

log close
