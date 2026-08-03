/******************************************************************
* Project:      AOK - Comorbidities
* VERIFY_01:    Check every variable in event_case_mc_full.dta (the
*               dataset 09_PSM.do saves right before dropping down
*               to the final variable list) for the first 50 anos,
*               against values rebuilt independently from the raw
*               files. Ends with a spot-check
* Input:        01_AOK_trunk.txt, 02_AOK_costs.txt,
*               03_AOK_demo_erratum.txt, 04_AOK_ICD10_GM.txt,
*               05_AOK_hc_use.txt, event_case_mc_full.dta
* Output:       99_verification\02_results\01_check_first50_full_vars.log
*               99_verification\02_results\spotcheck_icd_and_diag.xlsx
* Not checked: match_ID, matched_treated_ano, match_year,
* ever_control, t_event, all_lags as they are checked in the main script 
*******************************************************************/

clear all
version 19.5
set varabbrev off
set more off, permanently

global root      "C:\Users\weissenberg\Desktop\AOK_Revision"
global data_raw  "$root\data_26_ano\01_Data"
global data_work "$root\01_data_work"
global verify    "$root\99_verification"
global vlog      "$verify\02_results"
capture mkdir "$verify"
capture mkdir "$vlog"

capture log close vlog2
log using "$vlog\01_check_first50_full_vars.log", replace text name(vlog2)

di "================================================================"
di "VERIFY 01: first 50 anos in event_case_mc_full.dta vs. raw files"
di "Run date: `c(current_date)' `c(current_time)'"
di "================================================================"

use "$data_work\event_case_mc_full.dta", clear
keep ano
duplicates drop
sort ano
keep in 1/50
tempfile ano_list_50
save `ano_list_50'
clear
set obs 3
gen ano = .
replace ano = 148 in 1
replace ano = 285 in 2
replace ano = 110 in 3
append using `ano_list_50'
duplicates drop
tempfile ano_list
save `ano_list'

import delimited "$data_raw\01_AOK_trunk.txt", clear
merge m:1 ano using `ano_list', keep(match) nogen
rename ana_grup ana_grp
gen byte ana_grp_gd = (ana_grp == 1)
gen byte ana_grp_mc = (ana_grp == 0)
rename geb yob
rename deutsch german
rename tod_j yod
gen byte dead_end = (yod != .)
replace dead_end = 0 if yod == 2025
gen byte female = (geschlecht == 1)
keep ano ana_grp_gd ana_grp_mc yob german yod dead_end female
tempfile fixed_demo
save `fixed_demo'

import delimited "$data_raw\02_AOK_costs.txt", clear
merge m:1 ano using `ano_list', keep(match) nogen
rename jahr year
rename ausg_gesamt total_exp
keep ano year total_exp
tempfile costs
save `costs'

import delimited "$data_raw\03_AOK_demo_erratum.txt", clear
merge m:1 ano using `ano_list', keep(match) nogen
rename raumstruktur spatial_str
gen byte spatial_num = .
replace spatial_num = 1 if spatial_str == "Peripherraum sehr geringer Dichte"
replace spatial_num = 2 if spatial_str == "Peripherraum mit Verdichtungsansätzen"
replace spatial_num = 3 if spatial_str == "Zwischenraum geringer Dichte"
replace spatial_num = 4 if spatial_str == "Zwischenraum mit Verdichtungsansätzen"
replace spatial_num = 5 if spatial_str == "Äußerer Zentralraum"
replace spatial_num = 6 if spatial_str == "Innerer Zentralraum"
drop spatial_str
rename spatial_num spatial_str
rename vart insur_type
keep ano yyyyq insur_type spatial_str
tempfile demo_yyyyq
save `demo_yyyyq'

import delimited "$data_raw\05_AOK_hc_use.txt", clear
merge m:1 ano using `ano_list', keep(match) nogen
rename au_tage sick_d_q
keep ano yyyyq sick_d_q
tempfile treat_yyyyq
save `treat_yyyyq'

import delimited "$data_raw\04_AOK_ICD10_GM.txt", clear
merge m:1 ano using `ano_list', keep(match) nogen

preserve
    gen year_tmp = floor(yyyyq / 10)
    keep if (ano==148 & year_tmp==2017) | (ano==285 & year_tmp==2019) | (ano==110 & year_tmp==2014)
    keep ano yyyyq icd sektor
    sort ano yyyyq icd
    tempfile spotcheck_icd
    save `spotcheck_icd'
restore

preserve
    keep ano yyyyq
    gen byte keep_ind = 1
    collapse (max) keep_ind, by(ano yyyyq)
    tempfile keep_ind_f
    save `keep_ind_f'
restore
gen year = floor(yyyyq / 10)
preserve
    keep if substr(icd,1,1) == "F"
    drop if icd == "F630"
    replace icd = substr(icd, 1, 3)
    duplicates drop ano year icd, force
    keep ano year
    gen num_pd = 1
    collapse (sum) num_pd, by(ano year)
    tempfile num_pd_f
    save `num_pd_f'
restore
keep if substr(icd,1,1)=="F"
gen byte F00_F99_nopg = 1
replace F00_F99_nopg = 0 if icd == "F630"
gen byte gambl_dis_diag = (icd == "F630")
gen byte F10_F19 = (substr(icd,2,1) == "1")
gen byte F10 = (substr(icd,1,3) == "F10")
gen byte F17 = (substr(icd,1,3) == "F17")
gen byte other_psych = inlist(substr(icd,1,3), "F11","F12","F13","F14","F15","F16","F18","F19")
gen byte F30_F39 = (substr(icd,2,1) == "3")
gen byte F32_F33 = inlist(substr(icd,1,3), "F32", "F33")
gen byte F40_F48 = (substr(icd,2,1) == "4")
gen byte F40 = (substr(icd,2,2) == "40")
gen byte F41 = (substr(icd,2,2) == "41")
gen byte F42 = (substr(icd,2,2) == "42")
gen byte F43 = (substr(icd,2,2) == "43")
gen byte F50_F59 = (substr(icd,2,1) == "5")
gen byte F60_F69_noPG = (substr(icd,2,1) == "6")
replace F60_F69_noPG = 0 if icd == "F630"
gen byte F99 = (substr(icd,1,3) == "F99")
merge m:1 ano yyyyq using `keep_ind_f', nogen
replace year = floor(yyyyq / 10)
merge m:1 ano year using `num_pd_f', nogen
drop icd year sektor
ds ano yyyyq, not
local vars `r(varlist)'
collapse (max) `vars', by(ano yyyyq)
foreach v of local vars {
    replace `v' = 0 if missing(`v')
}
tempfile diag_yyyyq
save `diag_yyyyq'

use `fixed_demo', clear
keep ano
tempfile ano_data
save `ano_data'
clear
set obs 56
gen year    = 2011 + floor((_n - 1) / 4)
gen quarter = mod((_n - 1), 4) + 1
gen yyyyq   = year * 10 + quarter
tempfile yyyyq_data
save `yyyyq_data'
use `ano_data', clear
cross using `yyyyq_data'

merge m:1 ano using `fixed_demo'
drop _merge
gen byte dead = !missing(yod) & year >= yod

merge m:1 ano year using `costs'
drop _merge
merge 1:1 ano yyyyq using `demo_yyyyq'
drop _merge
merge 1:1 ano yyyyq using `diag_yyyyq'
drop _merge
merge 1:1 ano yyyyq using `treat_yyyyq'
drop _merge

drop if total_exp == . & sick_d_q == . &  keep_ind == .
drop if total_exp == 0 & insur_type == . & keep_ind == . & sick_d_q == .

local vars F00_F99_nopg gambl_dis_diag F10_F19 F10 F17 other_psych F30_F39 F32_F33 F40_F48 F40 F41 F42 F43 F50_F59 F60_F69_noPG F99 keep_ind num_pd
foreach var of local vars {
    replace `var' = 0 if missing(`var')
}

drop if year > yod
drop if missing(yob)
drop if year < yob
gen age = year - yob

sort ano yyyyq
collapse (max) num_pd yob age female german dead_end dead yod ana_grp_gd ana_grp_mc F00_F99_nopg gambl_dis_diag F10_F19 F10 F17 other_psych F30_F39 F32_F33 F40_F48 F40 F41 F42 F43 F50_F59 F60_F69_noPG F99 (lastnm) spatial_str insur_type, by(ano year)

gen age_grp = .
replace age_grp = 1 if age <=17
replace age_grp = 2 if age >=18 & age <=20
replace age_grp = 3 if age >=21 & age <=25
replace age_grp = 4 if age >=26 & age <=35
replace age_grp = 5 if age >=36 & age <=45
replace age_grp = 6 if age >=46 & age <=55
replace age_grp = 7 if age >=56 & age <=70
replace age_grp = 8 if age > 70 & !missing(age)

bysort ano: egen byte ever_gd = max(gambl_dis_diag)
egen year_first_gd = min(cond(gambl_dis_diag == 1, year, .)), by(ano)
gen byte gvar = (year == year_first_gd)
replace gvar = 0 if missing(gvar)
gen age_diag_GD = year_first_gd - yob
gen byte male = 1 - female

foreach v of varlist num_pd yob age female german dead_end dead yod ///
    ana_grp_gd ana_grp_mc F00_F99_nopg gambl_dis_diag F10_F19 F10 F17 ///
    other_psych F30_F39 F32_F33 F40_F48 F40 F41 F42 F43 F50_F59 ///
    F60_F69_noPG F99 spatial_str insur_type age_grp ever_gd year_first_gd ///
    gvar age_diag_GD male {
    rename `v' `v'_raw
}
sort ano year
tempfile raw
save `raw'

use "$data_work\event_case_mc_full.dta", clear
merge m:1 ano using `ano_list', keep(match) nogen
merge m:1 ano year using `raw'
count if _merge == 1
drop if _merge != 3
drop _merge

count if num_pd         != num_pd_raw
count if yob             != yob_raw
count if age             != age_raw
count if female          != female_raw
count if german          != german_raw
count if dead_end        != dead_end_raw
count if dead            != dead_raw
count if yod             != yod_raw
count if ana_grp_gd      != ana_grp_gd_raw
count if ana_grp_mc      != ana_grp_mc_raw
count if F00_F99_nopg    != F00_F99_nopg_raw
count if gambl_dis_diag  != gambl_dis_diag_raw
count if F10_F19         != F10_F19_raw
count if F10             != F10_raw
count if F17             != F17_raw
count if other_psych     != other_psych_raw
count if F30_F39         != F30_F39_raw
count if F32_F33         != F32_F33_raw
count if F40_F48         != F40_F48_raw
count if F40             != F40_raw
count if F41             != F41_raw
count if F42             != F42_raw
count if F43             != F43_raw
count if F50_F59         != F50_F59_raw
count if F60_F69_noPG    != F60_F69_noPG_raw
count if F99             != F99_raw
count if spatial_str     != spatial_str_raw
count if insur_type      != insur_type_raw
count if age_grp         != age_grp_raw
count if ever_gd         != ever_gd_raw
count if year_first_gd   != year_first_gd_raw
count if gvar            != gvar_raw
count if age_diag_GD     != age_diag_GD_raw
count if male            != male_raw

di "================================================================"
di "SPOT-CHECK: true/false diagnosis flags vs. raw ICD codes"
di "================================================================"

use "$data_work\event_case_mc_full.dta", clear
di "--- pipeline diagnosis flags (event_case_mc_full.dta) ---"
list ano year num_pd gambl_dis_diag F00_F99_nopg F10_F19 F10 F17 other_psych ///
    F30_F39 F32_F33 F40_F48 F40 F41 F42 F43 F50_F59 F60_F69_noPG F99 ///
    if (ano==148 & year==2017) | (ano==285 & year==2019) | (ano==110 & year==2014), ///
    sepby(ano) noobs clean

keep if (ano==148 & year==2017) | (ano==285 & year==2019) | (ano==110 & year==2014)
export excel ano year num_pd gambl_dis_diag F00_F99_nopg F10_F19 F10 F17 ///
    other_psych F30_F39 F32_F33 F40_F48 F40 F41 F42 F43 F50_F59 F60_F69_noPG F99 ///
    using "$vlog\spotcheck_icd_and_diag.xlsx", sheet("diagnosis_flags") firstrow(variables) replace

di "--- raw ICD-10 codes, all quarters of that year ---"
use `spotcheck_icd', clear
list ano yyyyq icd sektor, sepby(ano) noobs clean
export excel using "$vlog\spotcheck_icd_and_diag.xlsx", sheet("raw_icd_codes") firstrow(variables) sheetreplace

log close vlog2
exit 0
