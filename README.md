# Education and later-life cognition in India (LASI-DAD Wave 2)

Replication code for a survey-weighted decomposition. Education and general
cognition, decomposed through Lancet Commission risk factors, in the
Harmonized LASI-DAD Wave 2 sample.

Weighted models are the main analysis. Unweighted models are the sensitivity
check. The survey weight is the Wave 2 cross-sectional respondent weight,
`r2hwtresp`.

## Data access

The data is not in this repository. LASI-DAD is restricted under a data use
agreement and is analyzed inside the Gateway to Global Aging secure Enclave.
Reviewers can read all code here. Anyone with the LASI-DAD agreement and
Enclave access can reproduce the results by running it.

Source files, obtained through the agreement:
- `H_LASI_DAD_b2.dta` (Harmonized LASI-DAD, Wave 2)
- `H_LASI_a3.dta` (Harmonized LASI Core, A.3)

## Software

Stata 17. The bootstrap uses `set seed 20260930`, so it reproduces exactly.

## Run order

Set `OUTDIR` at the top of `00_run_all.do` to your Enclave output folder, then
run that file. It calls the steps in order. Each step is standalone. Each one
clears memory, sets its own model globals, loads its data, and writes its own
log and CSV. The files are exactly the ones that produced the published tables.

### Main tables

| Step | File | Produces | Loads |
|---|---|---|---|
| 01a | `01a_operationalize_lancet14_B2.do` | `Lancet14_B2_operationalized.dta` (holds the weight) | H_LASI_DAD_b2 + Core A.3 |
| 01b | `01b_build_lancet14_full.do` | `Paper2_Lancet14_Full.dta` (holds BMI, `r2hmbmi`) | H_LASI_DAD_b2 + Core A.3 |
| 02 | `02_table1_characteristics.do` | Table 1 | `Paper2_analytic_v1.dta` |
| 03 | `03_table2_contrasts.do` | Table 2, weighted + unweighted, both specs, both contrasts | `Paper2_bmi4_analysis.dta` |
| 04 | `04_tables3_3S_mediation_bootstrap.do` | Tables 3 and 3S, 5,000-rep weighted bootstrap (and Table S15) | `Paper2_bmi4_analysis.dta` |
| 05 | `05_apaths_analytic_SE.do` | a-path analytic SEs reported in Tables 3 and 3S | `Paper2_bmi4_analysis.dta` |
| 06 | `06_table3b_bmi4_indian.do` | Table 3b, four-category BMI, Indian cutoffs | `Paper2_bmi4_analysis.dta` |

### Robustness (supplement tables S16-S20)

| Step | File | Produces | CSV written |
|---|---|---|---|
| 07 | `07_robustness_specFE_seq.do` | S16 Panel A (own-sample spec ladder), S18 (sequential ladder), and a state-FE cross-check of S20 | `robust_specFE_wtd_vs_unwtd.csv`, `seq_wtd_vs_unwtd.csv` |
| 08 | `08_robustness_fixed_grid_S17.do` | S17, nine/ten/eleven on one fixed sample (N = 2,365) | `s17_fixed_sample_grid.csv` |
| 09 | `09_robustness_hearing_S19.do` | S19, audiometry versus self-report hearing on a common sample (N = 1,845) | `s19_hearing_common_wtd_vs_unwtd.csv` |
| 10 | `10_robustness_stateFE_S20.do` | S20, geography ladder with state fixed effects (`r2stateid`), N = 3,355 | `state_fe_robust.csv` |

Step 07 and step 10 both report the geography ladder. Step 10 merges the real
state identifier `r2stateid` and is the published source of S20. Step 07 runs
the same geography arm as an internal check, and its output agrees. Keeping
both makes the state-FE result traceable to the exact file that produced it.

Figure 1 is the sample-flow diagram. Its counts come from the exclusion
cascade in steps 01-03, not from a separate script.

### File provenance

Each numbered file is a verbatim copy of the Enclave do-file that ran. Original
names, for cross-reference:

| Repo file | Enclave original |
|---|---|
| `07_robustness_specFE_seq.do` | `Paper2_robustness_all_wtd_vs_unwtd_20261014.do` |
| `08_robustness_fixed_grid_S17.do` | `Paper2_S17_fixed_sample_grid_20261016.do` |
| `09_robustness_hearing_S19.do` | `Paper2_S19_hearing_common_wtd_vs_unwtd_20261016.do` |
| `10_robustness_stateFE_S20.do` | `Paper2_state_FE_robust_20261014.do` |

## Model

- Outcome: `r2sgcp`, general cognitive performance, factor-score units.
- Education: `edu_3cat`, 0 = no education (reference), 1 = primary,
  2 = secondary or higher.
- Covariates: age centered at 70, sex, rural, caste, wealth quintile, region.
- Nine-factor sample N = 3,355. Eleven-factor sample N = 2,365, a strict
  nested subset that adds physical inactivity and unclean cooking fuel.
- Decomposition is product-of-coefficients. Indirect = a-path times b-path.
  Attenuation = (base minus full) divided by base.

## Two things to know before running

**The survey weight.** `r2hwtresp` is read from `Lancet14_B2_operationalized.dta`
in steps 04, 05, 06, 07, 08, and 10. Step 03 reads the same weight from
`H_LASI_DAD_b2.dta`. Both carry the identical weight. The files are left exactly
as they ran.

**Building the analytic file.** The analysis loads two prepared files,
`Paper2_bmi4_analysis.dta` (steps 03-10) and `Paper2_analytic_v1.dta` (step 02).
Both were assembled from the step 01 indicator files plus derived covariates
(`edu_3cat`, `wealth_quintile`, `region5`, `fuel_unclean`, `hearing_mod`) and an
mi-strip CSV round-trip. `Paper2_bmi4_analysis.dta` is the mi-stripped file; a
survey-weighted `regress` needs it, because an mi-set file throws r119. That
assembly was iterative and is not a single script. Steps 01a and 01b document
the indicator construction.

## Outputs

Each step writes a log and small aggregate CSVs to `OUTDIR`. Only aggregate
results leave the Enclave. No microdata is exported. Result files are
git-ignored.

## Citation

See `CITATION.cff`. If you use this code, please cite the archived release and
the paper.

## License

MIT. See `LICENSE`.
