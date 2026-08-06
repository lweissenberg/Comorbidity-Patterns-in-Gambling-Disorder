/******************************************************************
* Project: 		AOK - Comorbidities
* DO_06: 		Create Diagnosis indicators based on the ICD-10-GM 
*				for later merging into the Analysis DF
* Startdate:	25.10.2025
* Last Change:	13.07.2026
* Input:		'04_AOK_ICD10_GM.txt'
* Output:		'ana_grp_diag_yyyyq.dta'
*******************************************************************/

// 1: Import data
import delimited "$data_raw\04_AOK_ICD10_GM.txt", clear
capture label define truefalse_lbl 0 "FALSE" 1 "TRUE"

// 2: Create keep ind. for later determining if someone was insured during the 
* respective year 
preserve 
	keep ano yyyyq 
	gen byte keep_ind = 1 
	collapse (max) keep_ind, by(ano yyyyq)
	label var keep_ind "Has Observation in the quarter: 1 = True; 0 = False"
	label values keep_ind truefalse_lbl
	tempfile keep_ind 
	save `keep_ind'
restore

// 3: Create # of unique psychiatric diag. excl. GD
gen year = floor(yyyyq / 10)
preserve
		// Bugs (both were connected) present in the original submission, now 
		// corrected:
		// 1) Deduplication was performed at (ano, yyyyq, icd) instead of (ano, year,
		//    icd), inflating num_pd by counting the same diagnosis code once per
		//    quarter instead of once per year. It is still on ICD-10-GM 3 Digit Level
		//	  given rare diag. are censored for privacy reasons to 3 digits
		// 2) Filter mistakenly kept 5 rare somatic codes (E10, M05, M06, C43, C44),
		//    inflating F00_F99, F00_F99_nopg, F10_F19, F40_F48, and F43. Impact
		//    was small (e.g., cases t0: 87.65% -> 87.53%). Numbers needed to be
		//	  recalculated
	keep if substr(icd,1,1) == "F" 
	drop if icd == "F630" // exclude GD 
	replace icd = substr(icd, 1, 3) // based on 3 character code due to censoring
	// really rare diagnoses (less than 100 cases among all insurees)
	duplicates drop ano year icd, force
	tab icd 
	keep ano year
	gen num_pd = 1
	collapse (sum) num_pd, by(ano year)
	label var num_pd "Received # unique psychiatric diag. (ICD-10-GM 3 character code; excl. GD)"
	tempfile num_pd
	save `num_pd'
restore

/*********************************************
* 4: Create dummy variables for all diagnostic
* categories outlined in Table 1
**********************************************/

keep if substr(icd,1,1)=="F" // only ICD-10 Chapter 5 diagnoses 
 
*4.1 Create Any Mental and behavioural disorders; excluding F63.0 (ICD-10-GM: F00-F99; excluding F63.0)
gen byte F00_F99 = 1 
label var F00_F99 "Any Mental and behavioural disorders(ICD-10-GM: F00-F99)"
label values F00_F99 truefalse_lbl
gen byte F00_F99_nopg = 1
replace F00_F99_nopg = 0 if icd == "F630"
label var F00_F99_nopg "Any Mental and behavioural disorders; excluding F63.0 (ICD-10-GM: F00-F99; excluding F63.0)"
label values F00_F99_nopg truefalse_lbl
drop F00_F99


*4.2 Create Pathological gambling (ICD-10-GM: F63.0)
gen byte gambl_dis_diag = (icd == "F630")
label var gambl_dis_diag "Pathological gambling (ICD-10-GM: F63.0)"
label values gambl_dis_diag truefalse_lbl
tab icd if gambl_dis_diag == 1 

	*4.2.1 Create Type of GD Diag.
	preserve
		keep if gambl_dis_diag
		rename sektor sector
		gen byte inpat_GD_diag_main = (sector == "stat_HD" & icd == "F630")
		label var inpat_GD_diag_main "Inpatient GD diagnosis: MAIN"
		label values inpat_GD_diag_main truefalse_lbl
		assert inlist(inpat_GD_diag_main, 1, 0)

		gen byte inpat_GD_diag_sec = (sector == "stat_ND" & icd == "F630")
		label var inpat_GD_diag_sec "Inpatient GD diagnosis: SECONDARY"
		label values inpat_GD_diag_sec truefalse_lbl
		assert inlist(inpat_GD_diag_sec, 1, 0)

		gen byte outpat_GD_diag = (sector == "amb" & icd == "F630")
		label var outpat_GD_diag "Outpatient GD diagnosis"
		label values outpat_GD_diag truefalse_lbl
		label var icd "ICD-10-GM code"
		assert inlist(outpat_GD_diag, 1, 0)	 
		drop sector
		
		* Provides information on how GD diagnoses were made: inpatient vs.
		* outpatient, and, for inpatients, whether the diagnosis was primary or
		* secondary. Interpret with caution: this tabulates every diagnosis
		* record across the full observation period, not just each patient's
		* first (index) diagnosis, so temporal ordering within a year or quarter
		* cannot be established, and one patient can contribute records to
		* multiple categories across multiple years
		tab inpat_GD_diag_main
		tab inpat_GD_diag_sec
		tab outpat_GD_diag
	restore 
	drop sektor
	
*4.3 Create Mental and behavioural disorders due to psychoactive substance use and subcategories (ICD-10-GM: F10-F19)
* F10_F19 Mental and behavioural disorders due to psychoactive substance use
gen byte F10_F19 = (substr(icd,2,1) == "1")
label var F10_F19 "Mental and behavioural disorders due to psychoactive substance use (ICD-10-GM: F10-F19)"
label values F10_F19 truefalse_lbl
 
	*F10: Alcohol
	gen byte F10 = (substr(icd, 1, 3) == "F10")
	label var F10 "Mental and behavioural disorders due to use of alcohol (ICD-10-GM: F10)"
	label values F10 truefalse_lbl

	*F17: Tobacco
	gen byte F17 = (substr(icd, 1, 3) == "F17")
	label var F17 "Mental and behavioural disorders due to use of tobacco (ICD-10-GM: F17)"
	label values F17 truefalse_lbl

	*F11–F16, F18–F19: Other psychoactive substances
	gen byte other_psych = inlist(substr(icd,1,3), ///
		"F11","F12","F13","F14","F15","F16","F18","F19")
	label var other_psych "Mental and behavioural disorders due to other psychoactive substances (ICD-10-GM: F11–F16, F18–F19)"
	label values other_psych truefalse_lbl

*4.4 Create Mood [affective] disorders and subcategory (ICD-10-GM: F30-F39)
gen byte F30_F39 = (substr(icd,2,1) == "3")
label var F30_F39  "Mood [affective] disorders (ICD-10-GM: F30-F39)"
label values F30_F39  truefalse_lbl

	*F32-F33: Depression
	gen byte F32_F33 = inlist(substr(icd,1,3), "F32", "F33")
	label var F32_F33 "Depressive disorders (ICD-10-GM:F32–F33)"
	label values F32_F33 truefalse_lbl
	
*4.5: Create Neurotic, stress-related and somatoform disorders and subcategories (ICD-10-GM: F40-F48)
gen byte F40_F48 = (substr(icd,2,1) == "4")
label var F40_F48  "Neurotic, stress-related and somatoform disorders (ICD-10-GM: F40-F48)"
label values F40_F48  truefalse_lbl

	*F40: Phobic anxiety disorders
	gen byte F40 = (substr(icd,2,2) == "40")
	label var F40  "Phobic anxiety disorders (ICD-10-GM: F40)"
	label values F40  truefalse_lbl

	*F41: Other anxiety disorders
	gen byte F41 = (substr(icd,2,2) == "41")
	label var F41  "Other anxiety disorders (ICD-10-GM: F41)"
	label values F41  truefalse_lbl

	*F42: Obsessive-compulsive disorder
	gen byte F42 = (substr(icd,2,2) == "42")
	label var F42  "Obsessive-compulsive disorder (ICD-10-GM: F42)"
	label values F42  truefalse_lbl
	
	*F43: Reaction to severe stress, and adjustment disorders
	gen byte F43 = (substr(icd,2,2) == "43")
	label var F43  "Reaction to severe stress, and adjustment disorders (ICD-10-GM: F43)"
	label values F43  truefalse_lbl
	
*4.6 Create Behavioural syndromes associated with physiological disturbances and physical factors (ICD-10-GM: F50-F59)
gen byte F50_F59 = (substr(icd,2,1) == "5")
label var F50_F59  "Behavioural syndromes associated with physiological disturbances and physical factors (ICD-10-GM: F50-F59)"
label values F50_F59  truefalse_lbl

*4.7 Create Disorders of adult personality and behaviour; excluding F63.0 (ICD-10-GM: F60-F69; excluding F63.0)
gen byte F60_F69_noPG = (substr(icd,2,1) == "6")
replace F60_F69_noPG = 0 if icd == "F630"
label var F60_F69_noPG  "Disorders of adult personality and behaviour; excluding F63.0 (ICD-10-GM: F60-F69; excluding F63.0)"
label values F60_F69_noPG truefalse_lbl

*4.8 Create Unspecified mental disorder (ICD-10-GM: F99)
gen byte F99 = (substr(icd,1,3) == "F99")
label var F99   "Unspecified mental disorder (ICD-10-GM: F99)"
label values F99  truefalse_lbl

/*********************************************************
* 4: END
*********************************************************/

// 5: merge with temp files
merge m:1 ano yyyyq using `keep_ind', nogen
* the keep_ind merge adds back person-quarters that had only non-F diagnoses;
replace year = floor(yyyyq / 10) // not really needed but otherwise at this step
* year will be bugged 
merge m:1 ano year using `num_pd', nogen

// 6: Collapse to one row per individual-quarter
drop icd
ds ano yyyyq, not
local vars `r(varlist)'

foreach v of local vars {
    local lab_`v' : variable label `v'
}

collapse (max) `vars', by(ano yyyyq)

foreach v of local vars {
    label variable `v' "`lab_`v''"
    if "`v'" != "num_pd" label values `v' truefalse_lbl
    replace `v' = 0 if missing(`v')
}
label var num_pd "Received # unique psychiatric diag. (ICD-10-GM 3 character code; excl. GD)"

// 7: Save data
drop year // not needed anymore we merge on yyyyq 
save "$data_work\ana_grp_diag_yyyyq.dta", replace
clear all

/****************
* End of .do file
****************/





