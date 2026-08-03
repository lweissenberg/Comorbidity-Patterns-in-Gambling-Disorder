# Comorbidity Patterns in Gambling Disorder [!!!unpublished!!!]

Stata code for a matched case-control study of psychiatric comorbidities
in Gambling Disorder (GD), based on AOK Baden-Württemberg statutory health
insurance claims data (2011–2024).

The published study can be found here: PLACEHOLDER 

> **Data availability.** The individual-level claims data cannot be shared.
> They are sensitive health data held by AOK Baden-Württemberg and were
> analyzed under a data protection agreement. Questions about the data, the
> code, or the results are always welcome
> (<lorenz.weissenberg@uni-hohenheim.de>).

## Scripts

Run `00_scripts/00_Master.do` end to end, or run the numbered
scripts in sequence. See the header of each `.do` file for its exact inputs and outputs.

- `01`-`06`: prepare the raw extracts (insured population, demographics,
  costs, sick leave, ICD-10-GM diagnoses) into merge files
- `07`: merge everything into an individual-year analysis panel
- `08`: apply eligibility criteria; build the case and control pools
- `09`: propensity score matching, event-time alignment, check covariate balance
- `10`: prevalence and COR estimation, figures, pooled results files

The last section of `10` verifies every claim the paper makes

## What is shared in this repository

Only code and aggregated results are included; all individual-level raw and derived data are excluded.

| Path | Content |
|---|---|
| `00_scripts/*.do` | full analysis code |
| `02_results/03_tables/cors_pooled.csv` | all CORs with 95% CIs and significance levels |
| `02_results/03_tables/prev_pooled.csv` | all prevalence estimates with 95% CIs |
| `02_results/01_logs/AOK_comorbidities_master_log.txt` | full run log, including the verification of every claim in the paper |
| `data_description_EN.xlsx` | description of the raw data and description of the post PSM analysis DF |

The log contains only results aggregated across individuals, apart from two
short anonymized listings that illustrate the matched-set data structure.

In the 99_verification Folder is a script that was used to verify the Aggregation by the authors.

## Analysis dataset (structure only, not shared)

The matching in `09` produces `event_case_mc.dta`, the dataset all analyses
in `10` run on. It is an individual-year panel with one row per person and
relative year. Each matched set (`match_ID`) consists of one case and two
controls, observed at the same `t_event`. The table below shows one
complete matched set across the full window t−5 to t+5 with illustrative
values, here a case first diagnosed in 2018. Rows are missing for years in which
a person is not observed.

| ano | match_ID | ever_gd | gvar | year | t_event | num_pd | F00_F99_nopg | F10_F19 | … | F99 |
|---:|---:|:---:|---:|---:|---:|---:|:---:|:---:|:---:|:---:|
| 1 | 1 | TRUE | 0 | 2013 | -5 | 0 | FALSE | FALSE | … | FALSE |
| 1 | 1 | TRUE | 0 | 2014 | -4 | 1 | TRUE | FALSE | … | FALSE |
| 1 | 1 | TRUE | 0 | 2015 | -3 | 1 | TRUE | FALSE | … | FALSE |
| 1 | 1 | TRUE | 0 | 2016 | -2 | 2 | TRUE | TRUE | … | FALSE |
| 1 | 1 | TRUE | 0 | 2017 | -1 | 2 | TRUE | TRUE | … | FALSE |
| 1 | 1 | TRUE | 1 | 2018 | 0 | 4 | TRUE | TRUE | … | FALSE |
| 1 | 1 | TRUE | 0 | 2019 | 1 | 3 | TRUE | TRUE | … | FALSE |
| 1 | 1 | TRUE | 0 | 2020 | 2 | 2 | TRUE | FALSE | … | FALSE |
| 1 | 1 | TRUE | 0 | 2021 | 3 | 2 | TRUE | TRUE | … | FALSE |
| 1 | 1 | TRUE | 0 | 2022 | 4 | 2 | TRUE | FALSE | … | FALSE |
| 1 | 1 | TRUE | 0 | 2023 | 5 | 2 | TRUE | TRUE | … | FALSE |
| 2 | 1 | FALSE | 0 | 2013 | -5 | 0 | FALSE | FALSE | … | FALSE |
| 2 | 1 | FALSE | 0 | 2014 | -4 | 0 | FALSE | FALSE | … | FALSE |
| 2 | 1 | FALSE | 0 | 2015 | -3 | 0 | FALSE | FALSE | … | FALSE |
| 2 | 1 | FALSE | 0 | 2016 | -2 | 0 | FALSE | FALSE | … | FALSE |
| 2 | 1 | FALSE | 0 | 2017 | -1 | 0 | FALSE | FALSE | … | FALSE |
| 2 | 1 | FALSE | 0 | 2018 | 0 | 0 | FALSE | FALSE | … | FALSE |
| 2 | 1 | FALSE | 0 | 2019 | 1 | 0 | FALSE | FALSE | … | FALSE |
| 2 | 1 | FALSE | 0 | 2020 | 2 | 0 | FALSE | FALSE | … | FALSE |
| 2 | 1 | FALSE | 0 | 2021 | 3 | 1 | TRUE | FALSE | … | FALSE |
| 2 | 1 | FALSE | 0 | 2022 | 4 | 0 | FALSE | FALSE | … | FALSE |
| 2 | 1 | FALSE | 0 | 2023 | 5 | 0 | FALSE | FALSE | … | FALSE |
| 3 | 1 | FALSE | 0 | 2013 | -5 | 0 | FALSE | FALSE | … | FALSE |
| 3 | 1 | FALSE | 0 | 2014 | -4 | 0 | FALSE | FALSE | … | FALSE |
| 3 | 1 | FALSE | 0 | 2015 | -3 | 1 | TRUE | FALSE | … | FALSE |
| 3 | 1 | FALSE | 0 | 2016 | -2 | 1 | TRUE | FALSE | … | FALSE |
| 3 | 1 | FALSE | 0 | 2017 | -1 | 1 | TRUE | FALSE | … | FALSE |
| 3 | 1 | FALSE | 0 | 2018 | 0 | 1 | TRUE | FALSE | … | FALSE |
| 3 | 1 | FALSE | 0 | 2019 | 1 | 1 | TRUE | FALSE | … | FALSE |
| 3 | 1 | FALSE | 0 | 2020 | 2 | 2 | TRUE | TRUE | … | FALSE |
| 3 | 1 | FALSE | 0 | 2021 | 3 | 1 | TRUE | FALSE | … | FALSE |
| 3 | 1 | FALSE | 0 | 2022 | 4 | 1 | TRUE | FALSE | … | FALSE |
| 3 | 1 | FALSE | 0 | 2023 | 5 | 1 | TRUE | FALSE | … | FALSE |

`ano` is the anonymized person ID. `ever_gd` separates cases (TRUE) from
matched controls (FALSE). `gvar` is 1 only in the case's index year, so for
cases `t_event` = 0 where `gvar` = 1. `num_pd` counts the unique psychiatric
diagnoses in that year (3-character ICD-10-GM codes, excluding F63.0). The
binary columns `F00_F99_nopg` to `F99` indicate at least one confirmed diagnosis in
the respective block or subcategory in that year.

## Requirements

We used Stata 19.5 (MP). The specific Hardware used is printed at the beginning of the log. file (We don't think that matters at all). The user-written packages (`distinct`, `egenmore`,
`psmatch2`, `stddiff`, `parmest`) are checked and installed automatically by the master script.

## License

MIT (see `LICENSE`).
