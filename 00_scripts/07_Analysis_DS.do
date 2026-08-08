/******************************************************************
* Project: 		AOK - Comorbidities
* DO_07: 		Create analysis DS from previously created DS
* Startdate:	26.10.2025
* Last Change:	13.07.2026
* Input:		'ana_grp_fixed_demo.dta'
*				'ana_grp_costs_yearly.dta'
*				'ana_grp_demo_yyyyq.dta'
*				'ana_grp_treat_yyyyq.dta'
*				'ana_grp_diag_yyyyq.dta'
* Output:		'analysis_df_y.dta' 	--> aggregated to years 
*				'analysis_df_yyyyq.dta'	--> would not recommend to use this 
*******************************************************************/

// 1: Create fully balanced DS to merge into: EACH ANO x YYYYQ
use "$data_work\ana_grp_fixed_demo.dta", replace
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
label var ano     "Anonymous ID"
label var year    "Year"
label var quarter "Quarter"
label var yyyyq   "YearxQuarter"
list if ano == 1, noobs clean 

// 2: Merge with 'ana_grp_fixed_demo.dta'
merge m:1 ano using "$data_work\ana_grp_fixed_demo.dta"
drop _merge
gen byte dead = !missing(yod) & year >= yod
label var dead "Dead (year >= year of death)"

// 3: Merge with 'ana_grp_costs_yearly.dta'
merge m:1 ano year using "$data_work\ana_grp_costs_yearly.dta"
drop _merge

// 4: Merge with 'ana_grp_demo_yyyyq.dta'
merge 1:1 ano yyyyq using "$data_work\ana_grp_demo_yyyyq.dta"
drop _merge

// 5: Merge with 'ana_grp_diag_yyyyq.dta'
merge 1:1 ano yyyyq using "$data_work\ana_grp_diag_yyyyq.dta"
drop _merge

// 6: Merge with 'ana_grp_treat_yyyyq.dta'
merge 1:1 ano yyyyq using "$data_work\ana_grp_treat_yyyyq.dta"
drop _merge

* We drop at this stage the unmatched control group representing the overall insured
* population, obtained during the review process after the paper's initial
* submission; not part of the original analysis group used in the present
* study
drop if ana_grp_uc == 1
drop ana_grp_uc

// 7: Drop obs. where we don't have information -> they are just there
* because we created in Step 1 (above) a fully balanced df -> exp = 0 in some years where ind. is not insured 
* -> insur type & sick_d_q == . most important indicators, if exp > 0 we assume he was insured 
count 
drop if (missing(total_exp) & missing(sick_d_q) & missing(keep_ind) & missing(insur_type)) ///
    | (total_exp == 0 & missing(insur_type) & missing(keep_ind) & missing(sick_d_q))
count 

// 8: replace missing obs with 0 for diag -> No diag. is == 0 
local vars F00_F99_nopg gambl_dis_diag F10_F19 F10 F17 other_psych F30_F39 F32_F33 F40_F48 F40 F41 F42 F43 F50_F59 F60_F69_noPG F99 keep_ind num_pd 
foreach var of local vars {
    replace `var' = 0 if missing(`var')
}

// 9: Final adjustments
drop if year > yod
drop if missing(yob)
drop if year < yob 
gen age = year - yob
label variable age "Age in Years"

// 10: Save
save "$data_work\analysis_df_yyyyq.dta", replace

// 11: Create Yearly Analysis DF

*11.1: save labels
ds ano yyyyq, not
local vars `r(varlist)' 
local labels

foreach v of var * {
 	local l`v' : variable label `v'
		if `"`l`v''"' == "" {
			local l`v' "`v'"
		}
 }
 
*11.2 collapse
* this sort is load-bearing and really important to keep: (lastnm) reads the row order, so it takes each
* person-year's value from the latest quarter with data. Do not change it,
* spatial_str feeds the matching in 09
sort ano yyyyq
collapse (max) num_pd  yob age female german dead_end dead yod ana_grp_gd ana_grp_mc  F00_F99_nopg gambl_dis_diag F10_F19 F10 F17 other_psych F30_F39 F32_F33 F40_F48 F40 F41 F42 F43 F50_F59 F60_F69_noPG F99 (lastnm) spatial_str insur_type, by(ano year)

*11.3 reapply label 
foreach v of var * {
	label var `v' `"`l`v''"'
}

// 12: gen age groups; age groups of Gambling Survey (Buth, 2025) used 
gen age_grp = .
replace age_grp = 1 if age <=17
replace age_grp = 2 if age >=18 & age <=20
replace age_grp = 3 if age >=21 & age <=25
replace age_grp = 4 if age >=26 & age <=35
replace age_grp = 5 if age >=36 & age <=45
replace age_grp = 6 if age >=46 & age <=55
replace age_grp = 7 if age >=56 & age <=70
replace age_grp = 8 if age > 70 & !missing(age)
label define age_lbl 1 "Under 18 Y." ///
                    2 "18-20 Y." ///
                    3 "21-25 Y." ///
                    4 "26-35 Y." ///
                    5 "36-45 Y." ///
                    6 "46-55 Y." ///
                    7 "56-70 Y." ///
                    8 "Over 70 Y."
label values age_grp age_lbl
label variable age_grp "Age Group (Years)"


// 13: Save Data
save "$data_work\analysis_df_y.dta", replace
clear all 

/****************
* End of .do file
****************/

