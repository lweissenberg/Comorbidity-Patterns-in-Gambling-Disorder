/******************************************************************
* Project: 		AOK - Comorbidities 
* DO_09: 		Propensity Score Matching and Alignment of Time 
* Startdate:	01.11.2025
* Last Change:	13.07.2026
* Input:		'psm_case_pool.dta'
* 				'psm_mc_control_pool.dta'
* 				'analysis_df_y_case_mc_2.dta'
* Output:		'event_case_mc.dta'
				'used_controls_mcpool'
*				'event_case_mc_varsummary.xlsx' (name/label/min/max/missing)
*******************************************************************/

// 1. Import Data and merge
* NOTE: the row order produced here is load-bearing. psmatch2 with
* noreplacement matches treated units in the order they appear, so the
* cases-then-controls order of this append determines which case gets which
* control. Do not sort matchdata
use "$data_work\psm_case_pool.dta", clear
append using "$data_work\psm_mc_control_pool.dta"
tempfile matchdata
save `matchdata'
use "$data_work\analysis_df_y_case_mc_2.dta"
tempfile analysis
save `analysis'
distinct ano if ever_gd
distinct ano if ever_gd == 0 

// 2: Create fresh tracking files
clear
gen ano = .
gen year = .
save "$data_work\used_controls_mcpool.dta", replace

/*******************************
* 3: Propensity Score Matching
********************************/
use `matchdata', clear
levelsof year if ever_gd & inrange(year, 2014, 2024), local(years)
display "`years'"

* Bug present in the original submission, now corrected: the loop nesting
* order was: 
*	foreach y of local years { 
*	forvalues i = 1/2 { ... 
*		} 
*	} 
* so each year ran both matching rounds back-to-back before advancing to the next year,
* instead of completing one full 2014-2024 sweep before starting the
* second. Impact was negligible in practice -> the calendar-year t0
* covariate-balance checks below (stddiff by year) already showed good
* balance in every year -> but the corrected order now matches the
* two-full-sweep design described in the text. Correction gives cases, which
* are diagnosed in later years, fairer (not equal) access to the control pool.
forvalues i = 1/2 {
    foreach y of local years {
		di as text "=== Iteration `i' | Year `y' ==="
        // load year y
        use `matchdata', clear
        keep if year==`y'
        // exclude controls already used in previous iteration or year  
        merge m:1 ano using "$data_work\used_controls_mcpool.dta"
		isid ano
        drop if _merge==3 & gvar==0   // drop only previously used CONTROLS
        drop _merge
        // cov. need to be non-missing; exclude cases with different incident year
        keep if !missing(gvar, age, female, german, spatial_str)
        drop if gvar==0 & ever_gd==1
        // run PSM (logit; 1-NN; no replacement);  spatial str. treated as cont.
        psmatch2 gvar age female german spatial_str, neighbor(1) noreplacement logit
        // build id -> ano map once
        tempfile id2ano
        preserve
            keep ano _id
            save `id2ano'
        restore
        // extract treated rows and their matched control ids
        preserve
            keep if _treated== 1 & _n1 < .
            keep ano _id _n1
            rename ano treated_ano
            rename _id treated_id
            rename _n1 control_id
            // map control_id -> control_ano
            rename control_id _id
            merge m:1 _id using `id2ano'
            keep if _merge==3
            drop _merge
            // prepare rows to mark used controls for this year/iteration
            gen matched_treated_ano_`y'_`i' = treated_ano
            keep ano matched_treated_ano_`y'_`i'
            gen year = `y'
            // append to tracking file 
            append using "$data_work\used_controls_mcpool.dta"
            duplicates drop
            save "$data_work\used_controls_mcpool.dta", replace
        restore 
        cap label drop _treated
        cap label drop _support
    }
}
/*******************************
* 3: END
********************************/

// 4: Tidy DF for Control units -> could be replaced by a shorter reshape command 
use "$data_work\used_controls_mcpool.dta", clear
gen matched_treated_ano = .
forvalues i = 1/2 {
    foreach y of local years {
        local varname = "matched_treated_ano_`y'_`i'"
        capture confirm variable `varname'
        if _rc == 0 {
            replace matched_treated_ano = `varname' if missing(matched_treated_ano) & !missing(`varname')
        }
    }
}
drop matched_treated_ano_20*
label variable ano "ANO of matched control individual"
label variable year "Year in which control was matched to treated"
rename year match_year
gen year = match_year
gen byte control_t_0 = 1 
save "$data_work\used_controls_mcpool.dta", replace

// 5: Event Study Design 
* 5.1: Keep matched ind  
use `analysis'
merge m:1 ano year using "$data_work\used_controls_mcpool.dta", keep(master match) nogen
bysort ano: egen matched_treated_ano_max = max(matched_treated_ano)
drop matched_treated_ano
rename matched_treated_ano_max matched_treated_ano
drop if matched_treated_ano == . & ever_gd == 0 
preserve
	keep matched_treated_ano
	rename matched_treated_ano ano 
	drop if missing(ano)
	duplicates drop
	tempfile matched_ids
	save `matched_ids'
restore
merge m:1 ano using `matched_ids'
drop if _merge == 1 & ever_gd == 1 
drop _merge
label variable matched_treated_ano "ANO of matched treated individual"

* 5.2: Treated: relative time period to own diagnosis year
gen t_event = .
gen t_relative_treated = year - year_first_gd if ever_gd == 1
replace t_event = t_relative_treated if ever_gd == 1

* 5.3: Controls: relative time period to matched treated's diagnosis year
bysort ano: egen byte ever_control = max(control_t_0)
replace ever_control = 0 if ever_control == . 
bysort ano: egen match_year_1 = max(match_year)
drop match_year
rename match_year_1 match_year
bys ano: assert match_year[1] == match_year[_N] if ever_control == 1
gen t_relative_control = year - match_year if ever_control == 1
	replace t_event = t_relative_control if ever_control == 1
tab t_event ever_gd

* 5.4: Create Set variable
drop control_t_0  t_relative_treated t_relative_control 
label variable match_year "Year where individual was matched"
label variable t_event "t = 0 Year of Gambling Diag"
label variable ever_control "= 1 if individual was used as control"
gen base_id = ano if ever_gd == 1
replace base_id = matched_treated_ano if missing(base_id)
by ano: egen base_id_1 = max(base_id)
replace base_id = base_id_1 if base_id ==.
bysort base_id: replace base_id = base_id[1]
egen match_ID = group(base_id)
drop if match_ID == . 
label variable match_ID "Group of matched case and 2 controls"
drop base_id base_id_1 

* 5.5: remove sets where case is dropped and limit to -5 to +5
bysort match_ID t_event: egen drop_ind = max(year_first_gd)
drop if drop_ind == .
drop drop_ind
keep if inrange(t_event, -5, 5)

// 6: Summarize sociodemographic Information & get metrics to assess covariate balance 
gen byte male = 1 - female
assert inrange(male, 0, 1)
label var male "Gender: 0 = female, 1 = male"
summarize  age male german spatial_str if t_event == 0 & ever_gd == 1
summarize  age male german spatial_str if t_event == 0 & ever_gd == 0
tab age_grp if t_event == 0 & ever_gd == 1
tab age_grp if t_event == 0 & ever_gd == 0
tab spatial_str if t_event == 0 & ever_gd == 1
tab spatial_str if t_event == 0 & ever_gd == 0
sdtest age if t_event == 0, by(ever_gd)
sdtest spatial_str if t_event == 0, by(ever_gd)

stddiff age german male spatial_str i.spatial_str i.age_grp if t_event == 0, by(ever_gd)
/*********************************
* ADDITIONAL COV. BALANCE EVIDENCE
**********************************/

* interesting but not reported 
* across calendar yrs. in t_0

stddiff age german male spatial_str i.spatial_str i.age_grp if t_event == 0 &  year == 2014, by(ever_gd)
stddiff age german male spatial_str i.spatial_str i.age_grp if t_event == 0 &  year == 2015, by(ever_gd) 
stddiff age german male spatial_str i.spatial_str i.age_grp if t_event == 0 &  year == 2016, by(ever_gd) 
stddiff age german male spatial_str i.spatial_str i.age_grp if t_event == 0 &  year == 2017, by(ever_gd) 
stddiff age german male spatial_str i.spatial_str i.age_grp if t_event == 0 &  year == 2018, by(ever_gd) 
stddiff age german male spatial_str i.spatial_str i.age_grp if t_event == 0 &  year == 2019, by(ever_gd) 
stddiff age german male spatial_str i.spatial_str i.age_grp if t_event == 0 &  year == 2020, by(ever_gd) 
stddiff age german male spatial_str i.spatial_str i.age_grp if t_event == 0 &  year == 2021, by(ever_gd) 
stddiff age german male spatial_str i.spatial_str i.age_grp if t_event == 0 &  year == 2022, by(ever_gd) 
stddiff age german male spatial_str i.spatial_str i.age_grp if t_event == 0 &  year == 2023, by(ever_gd) 
stddiff age german male spatial_str i.spatial_str i.age_grp if t_event == 0 &  year == 2024, by(ever_gd) 

* across all relative yrs.
stddiff age german male spatial_str i.spatial_str i.age_grp if t_event == -5, by(ever_gd)
stddiff age german male spatial_str i.spatial_str i.age_grp if t_event == -4, by(ever_gd) 
stddiff age german male spatial_str i.spatial_str i.age_grp if t_event == -3, by(ever_gd) 
stddiff age german male spatial_str i.spatial_str i.age_grp if t_event == -2, by(ever_gd) 
stddiff age german male spatial_str i.spatial_str i.age_grp if t_event == -1, by(ever_gd)  
stddiff age german male spatial_str i.spatial_str i.age_grp if t_event == 0, by(ever_gd) 
stddiff age german male spatial_str i.spatial_str i.age_grp if t_event == 1, by(ever_gd)  
stddiff age german male spatial_str i.spatial_str i.age_grp if t_event == 2, by(ever_gd)  
stddiff age german male spatial_str i.spatial_str i.age_grp if t_event == 3, by(ever_gd)  
stddiff age german male spatial_str i.spatial_str i.age_grp if t_event == 4, by(ever_gd) 
stddiff age german male spatial_str i.spatial_str i.age_grp if t_event == 5, by(ever_gd) 
* not only balanced in matching year, but also balanced in all other yrs.,
* though restricted by the fact that missing values are possible in non t_0 yrs

* show data structure and matching examples; variable guide:
*	ano                 - anonymous individual ID
*	ever_gd             - 1 = case (ever diagnosed with GD), 0 = matched control
*	t_event             - year relative to the set's index year (0 = year of the case's first GD diag.)
*	year                - calendar year
*	age                 - age in years
*	female              - 1 = female, 0 = male
*	german              - 1 = German nationality, 0 = other
*	spatial_str         - urbanicity of residence (1 = highly rural ... 6 = highly urban)
*	match_year          - calendar year in which a control was matched (= case's index year; missing for cases)
*	matched_treated_ano - ano of the case a control was matched to (missing for cases)
* how to read: each sepby-block is one matched set (match_ID = 1 case + 2 controls).
* Within a set, rows with the same t_event refer to the same calendar year; at
* t_event == 0 the PSM covariates (age, female, german, spatial_str) should be
* near-identical between the case and its two controls, in other yrs. missings
* are possible for the case
preserve
    sort match_ID ano t_event
    list ano ever_gd t_event year age female german spatial_str match_year ///
        matched_treated_ano if inlist(match_ID, 1, 2, 3, 4, 5), sepby(match_ID) noobs
restore

// 7: Inspect & save
capture label define truefalse_lbl 0 "FALSE" 1 "TRUE"
* 7.1: Export a full variable summary (name, label, min, max, # missing) of
* the pre-keep dataset, so dropped variables stay documented too
preserve
	tempfile varsummary
	postfile handle str32 var_name str244 var_label double(var_min var_max) long n_missing ///
		using "`varsummary'"
	ds
	foreach v of varlist `r(varlist)' {
		local vlab : variable label `v'
		capture confirm numeric variable `v'
		if !_rc {
			quietly summarize `v'
			local vmin = r(min)
			local vmax = r(max)
		}
		else {
			local vmin = .
			local vmax = .
		}
		quietly count if missing(`v')
		post handle ("`v'") ("`vlab'") (`vmin') (`vmax') (`r(N)')
	}
	postclose handle
	use "`varsummary'", clear
	export excel using "$log\event_case_mc_varsummary.xlsx", firstrow(variables) replace
restore

foreach var of varlist ever_gd gvar F00_F99_nopg F10_F19 F10 F17 other_psych ///
    F30_F39 F32_F33 F40_F48 F40 F41 F42 F43 F50_F59 F60_F69_noPG F99 {
    label values `var' truefalse_lbl
}
save "$data_work\event_case_mc_full", replace

* remove unused vars 
keep ano match_ID ever_gd gvar year t_event num_pd ///
    F00_F99_nopg F10_F19 F10 F17 other_psych F30_F39 F32_F33 ///
    F40_F48 F40 F41 F42 F43 F50_F59 F60_F69_noPG F99

order ano match_ID ever_gd gvar year t_event num_pd ///
    F00_F99_nopg F10_F19 F10 F17 other_psych F30_F39 F32_F33 ///
    F40_F48 F40 F41 F42 F43 F50_F59 F60_F69_noPG F99


save "$data_work\event_case_mc", replace
clear all 

/****************
* End of .do file
****************/
