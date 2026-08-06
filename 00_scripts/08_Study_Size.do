/******************************************************************
* Project: 		AOK - Comorbidities 
* DO_08: 		Get Study size | Important for Figure 1 
* Startdate:	27.10.2025
* Last Change:	13.07.2026
* Input:		'analysis_df_y.dta'
* Output:		'analysis_df_y_case_mc_2.dta'
*				'psm_case_pool.dta'
*				'psm_mc_control_pool.dta'
*******************************************************************/

// 1: Import data 
use "$data_work\analysis_df_y.dta", clear

* We drop at this stage the unmatched control group representing the overall insured
* population, obtained during the review process after the paper's initial
* submission; not part of the original analysis group used in the present
* study
drop if ana_grp_uc == 1
drop ana_grp_uc

// 2: create diagnostic flags 
bysort ano: egen byte ever_gd = max(gambl_dis_diag)
label variable ever_gd "Individual has at least once been diagnosed with GD"
tab ever_gd, missing 
capture label define truefalse_lbl 0 "FALSE" 1 "TRUE"
label values ever_gd truefalse_lbl
egen year_first_gd = min(cond(gambl_dis_diag == 1, year, .)), by(ano)
label var year_first_gd "Year of first GD diagnosis (. = never diagnosed)"
distinct ano if ever_gd == 0 
distinct ano if ever_gd == 1 
gen byte gvar = (year == year_first_gd)
replace gvar = 0 if missing(gvar)
label variable gvar "1 if first GD diag"

*2.1 check for issues and fix group definition for 2 cases 
tab ever_gd if ana_grp_gd == 1 
distinct ano if ana_grp_gd == 1 & ever_gd == 0
replace ana_grp_mc = 1  if ana_grp_gd == 1 & ever_gd == 0
replace ana_grp_gd = 0 if ever_gd == 0
tab ever_gd if ana_grp_mc == 1
* ever_gd is the dependent variable of every clogit in 10, so a control that is
* ever GD-diagnosed has to fail here rather than quietly bias the models
* -> 2 got reclassified in the correct grp. 
assert !(ana_grp_mc == 1 & ever_gd == 1)
assert !(ana_grp_gd == 1 & ana_grp_mc == 1)

// 3: Create all lag indicator (t-3, t-2, t-1)
gen lag1 = year_first_gd - 1
gen lag2 = year_first_gd - 2
gen lag3 = year_first_gd - 3
gen byte has_lag1 = (year == lag1)
gen byte has_lag2 = (year == lag2)
gen byte has_lag3 = (year == lag3)
bysort ano: egen all_lags = total(has_lag1 + has_lag2 + has_lag3)
gen byte lag_status = .
replace lag_status = 1 if all_lags == 3
replace lag_status = 0 if inlist(all_lags,0,1,2)
drop all_lags lag1 lag2 lag3 has_lag1 has_lag2 has_lag3
rename lag_status all_lags
label var all_lags "Ind. with GD has all 3 lags (t-3, t-2, t-1)"
gen age_diag_GD = year_first_gd - yob 
label var age_diag_GD "Age at first GD diagnosis"

/********************************************************
* 4: Assess DS Balance 
*********************************************************/

*4.1 full dataset
distinct ano					
distinct ano if ever_gd == 0	
distinct ano if ever_gd == 1	
distinct ano if ana_grp_gd == 1 
distinct ano if ana_grp_mc == 1 

xtset ano year
xtdescribe 						
bys ano: gen Tpanel = _N
egen byte tag = tag(ano)
summ Tpanel if tag				
drop Tpanel tag

/********************************************************
* 5. Get Study Size 
*********************************************************/

* 5.1: CASES [ever_gd = ana_grp_gd = 1]
preserve
	keep if gvar == 1 
	count							
	drop if year_first_gd < 2014
	count 							
restore 

preserve
	keep if gvar == 1  
	drop if age_diag_GD < 18 
	count							
restore 

preserve
	keep if gvar == 1 
	keep if !missing(age, female, german, spatial_str) 
	count 							
restore

preserve
	keep if gvar == 1 
	keep if all_lags == 1 
	count							
restore

preserve
	keep if gvar == 1
	count
	drop if all_lags == 0   // implies year_first_gd >= 2014: 2013 would need a 2010 lag row
	count
	drop if age_diag_GD < 18
	count													
	keep if !missing(age, female, german, spatial_str)
	count													
	keep ano year age female german spatial_str ever_gd gvar
	save "$data_work\psm_case_pool.dta", replace
restore

*5.2: Potential Pre-Matched CONTROLS
* Controls must be observed in all 14 years (2011-2024) so that a control is
* eligible at any index year with the full window available, whereas cases only
* need t-1 to t-3. This is deliberate but asymmetric: it selects controls on
* continuous AOK coverage (long-term stayers), not on health. Within a set the
* asymmetry is absorbed in 09, which drops control rows in relative years where
* the case is not observed
preserve
	drop if ana_grp_gd == 1
	distinct ano
restore

preserve
	drop if ana_grp_gd == 1 	
	drop if age < 18 
	distinct ano					
restore 

preserve 
	drop if ana_grp_gd == 1 	
	gen inrange_yr = inrange(year, 2011, 2024)
	bysort ano: egen n_years_1124 = total(inrange_yr)
	keep if n_years_1124 == 14
	distinct ano					
restore

preserve 
	drop if ana_grp_gd == 1
	gen byte cov_complete = !missing(age, female, german, spatial_str)
	bysort ano: egen has_complete_cov = max(cov_complete)
	keep if has_complete_cov == 1
	distinct ano					
restore

preserve 
	drop if ana_grp_gd == 1 	
	distinct ano					
	gen inrange_yr = inrange(year, 2011, 2024)
	bysort ano: egen n_years_1124 = total(inrange_yr)
	keep if n_years_1124 == 14		
	distinct ano					
	drop if age < 18
	distinct ano					
	gen byte cov_complete = !missing(age, female, german, spatial_str)
	bysort ano: egen has_complete_cov = max(cov_complete)
	keep if has_complete_cov == 1
	distinct ano					
	keep ano year age female german spatial_str ever_gd gvar
	save "$data_work\psm_mc_control_pool.dta", replace
restore

// 6. Save data 
save "$data_work\analysis_df_y_case_mc_2.dta", replace
clear all

/****************
* End of .do file
****************/