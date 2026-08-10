/******************************************************************
* Project: 		AOK - Comorbidities
* DO_03: 		Create yearly total-expenditure variable for later merging
*               into the analysis df. Kept only as a presence "was insured
*               this year" signal used in 07_Analysis_DS.do's panel-cleaning
*               step 
* Note:			Only 2012 to 2023 is available on yearly basis 				 
* Startdate:	16.10.2025
* Last Change:	13.07.2026
* Input:		'02_AOK_costs.txt'
* Output:		'ana_grp_costs_yearly.dta'
*******************************************************************/

// 1: Import data  
import delimited "$data_raw\02_AOK_costs.txt", clear

// 2: Rename variables
rename jahr year
rename ausg_gesamt total_exp
label variable year "Year"
label variable total_exp "Total expenditures [€] reimbursed by the AOK"
* interestingly we record 84 observations of neg. expenditures
* -> reimbursement artefacts
keep ano year total_exp

// 3: Save data
save "$data_work\ana_grp_costs_yearly.dta", replace
clear all

/****************
* End of .do file
****************/