/******************************************************************
* Project: 		AOK - Comorbidities
* DO_02: 		Clean and prepare individual-level fixed demographic data
*				and analysis group data for later merging into the 
*				Analysis DF
* Startdate:	01.10.2025
* Last Change:	13.07.2026
* Input:		'01_AOK_trunk.txt'
* Output:		'ana_grp_fixed_demo.dta'				
*******************************************************************/

// 1: Import data  
import delimited "$data_raw\01_AOK_trunk.txt", clear

// 2: Rename variables
capture label define truefalse_lbl 0 "FALSE" 1 "TRUE"

	*2.1 Create ana_grps 
	rename ana_grup ana_grp
	gen byte ana_grp_gd = (ana_grp == 1)
	label values ana_grp_gd truefalse_lbl
	label variable ana_grp_gd "GD Analysis Grp."
	gen byte ana_grp_mc = (ana_grp == 0)
	label values ana_grp_mc truefalse_lbl
	label variable ana_grp_mc "Age & Sex Matched Controls Analysis Grp."

	* the following group is later dropped for the reasons specified in  
	* the master do-file (see 00_Master.do)
	gen byte ana_grp_uc = (ana_grp == 2)
	label variable ana_grp_uc "Unmatched Controls Analysis Grp."
	label values ana_grp_uc truefalse_lbl

	*2.2 Year of Birth (YYYY)
	rename geb yob
	label variable yob "Year of Birth"

	*2.3 German Nationality
	rename deutsch german
	assert inlist(german, 0, 1, .)
	recast byte german
	label values german truefalse_lbl
	label variable german "German Nationality"

	*2.4 Year of Death (YYYY)
	rename tod_j yod
	label variable yod "Year of Death (if applicable)"

	*2.5 dead
	gen byte dead_end = (yod != .)
	* our observation period ends in 2024, so a death recorded for 2025 lies 
	* outside the window and we let the person count as alive at the end of it
	* --> Reasoning: We do not want to incorporate future information
	* Note: Does not matter for the present work 
	replace dead_end = 0 if yod == 2025
	label variable dead_end "Mortality status at end of observation period (1 = dead, 0 = alive)"
	label values dead_end truefalse_lbl
	
	*2.6 sex indicator
	gen byte female = (geschlecht == 1) // 0 = male, 1 = female
	drop geschlecht
	capture label define gender_lbl 0 "Male" 1 "Female"
	label values female gender_lbl
	label variable female "Gender: 0 = male, 1 = female"
	
// 3: Save data 
save "$data_work\ana_grp_fixed_demo.dta", replace
clear all

/****************
* End of .do file
****************/