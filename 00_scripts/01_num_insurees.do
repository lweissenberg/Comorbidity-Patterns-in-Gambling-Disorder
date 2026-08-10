/******************************************************************
* Project: 		AOK - Comorbidities
* DO_01: 		Obtain the number of insurees of the AOK for the last 
*				Quarter of 2024  
* Startdate:	01.10.2025
* Last Change:	13.07.2026
* Input:		'06_AOK_full_ins_pop.txt'
* Output: 		'None'
*******************************************************************/

// 1: Import data
import delimited "$data_raw\06_AOK_full_ins_pop.txt", clear

// 2: Calculate # of insurees in the last quarter of each year
rename n_vers n_ins
gen year = floor(yyyyq / 10)
gen quarter = mod(yyyyq, 10)
drop if quarter != 4

collapse (sum) n_ins, by(year)
rename n_ins n_ins_year_q4
label var n_ins_year_q4 "Total insurees per year (based on Q4)"
format n_ins_year_q4 %15.0fc
list year n_ins_year_q4, clean noobs

clear all 

/****************
* End of .do file
****************/