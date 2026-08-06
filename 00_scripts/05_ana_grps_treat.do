/******************************************************************
* Project: 		AOK - Comorbidities
* DO_05: 		Generate quarterly sick-leave-day variable for later
*               merging into the Analysis DF. Kept only as a presence/
*               "was insured this quarter" signal used in 07_Analysis_DS.do's
*               panel-cleaning step
* Startdate:	25.10.2025
* Last Change:	13.07.2026
* Input:		'05_AOK_hc_use.txt'
* Output:		'ana_grp_treat_yyyyq.dta'
*******************************************************************/

// 1: Import data
import delimited "$data_raw\05_AOK_hc_use.txt", clear

// 2: Rename variables
rename au_tage sick_d_q
label variable sick_d_q "Total number of sick leave days (quarterly)"
count if sick_d_q == . 
count if sick_d_q == 0 // is zero if someone was insured but never 
* 'officially' ill during the respective year 
keep ano yyyyq sick_d_q

// 3: Save data 
save "$data_work\ana_grp_treat_yyyyq.dta", replace
clear all

/****************
* End of .do file
****************/


