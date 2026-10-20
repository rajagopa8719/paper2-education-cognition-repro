*==============================================================================
* 00_run_all.do -- master runner for Paper 2
* Education and later-life cognition in India (LASI-DAD Wave 2)
* A survey-weighted decomposition through Lancet Commission risk factors.
*
* HOW TO RUN
*   1. Set OUTDIR below to your Enclave output folder (where the analytic
*      .dta files live and where results are written).
*   2. do 00_run_all.do
*
* Each step is a standalone do-file. Each one clears memory, sets its own
* model globals, loads its data, and writes its own log and CSV. They are the
* exact files that produced the published tables. Nothing here is edited.
*
* DATA IS NOT IN THIS REPO. LASI-DAD is restricted under a data use agreement.
* See README.md for what each step needs and which table it produces.
*==============================================================================

clear all
set more off

* ---- set this to your Enclave output folder ----
global OUTDIR "\\Skyhub\Resources\Project\GGAD00-0080\output"
cd "$OUTDIR"

*------------------------------------------------------------------------------
* UPSTREAM BUILD (run once to create the indicator files).
* 01a writes Lancet14_B2_operationalized.dta (carries the survey weight).
* 01b writes Paper2_Lancet14_Full.dta        (carries continuous BMI, r2hmbmi).
* The analytic files the analysis loads, Paper2_bmi4_analysis.dta and
* Paper2_analytic_v1.dta, were assembled from these plus derived covariates
* (edu_3cat, wealth_quintile, region5, fuel_unclean, hearing_mod) and an
* mi-strip CSV round-trip. See README.md, "Building the analytic file."
*------------------------------------------------------------------------------
* do code/01a_operationalize_lancet14_B2.do
* do code/01b_build_lancet14_full.do

*------------------------------------------------------------------------------
* MAIN TABLES (given the analytic files, these reproduce every main table).
*------------------------------------------------------------------------------
do code/02_table1_characteristics.do          // Table 1
do code/03_table2_contrasts.do                // Table 2  (+ weighted b-paths)
do code/04_tables3_3S_mediation_bootstrap.do  // Tables 3 and 3S (+ Table S15)
do code/05_apaths_analytic_SE.do              // a-path analytic SEs (Tables 3, 3S)
do code/06_table3b_bmi4_indian.do             // Table 3b

*------------------------------------------------------------------------------
* ROBUSTNESS / SUPPLEMENT (Tables S16-S20).
* 07 is one run that yields three CSVs: the own-sample ladder (S16 Panel A),
* the sequential ladder (S18), and a state-FE cross-check of S20.
* 08-10 are the fixed-sample grid (S17), the hearing comparison (S19), and
* the geography/state-FE ladder that is the published source of S20.
*------------------------------------------------------------------------------
do code/07_robustness_specFE_seq.do           // S16 Panel A, S18, S20 (cross-check)
do code/08_robustness_fixed_grid_S17.do       // S17
do code/09_robustness_hearing_S19.do          // S19
do code/10_robustness_stateFE_S20.do          // S20

di as result "== all steps done =="
