/*********************************************************
* 0) Define Projects Paths
*********************************************************/

global root			"C:\Users\weissenberg\Desktop\AOK_Revision"
global script		"$root\00_scripts"
global data_raw		"$root\data_26_ano\01_Data"
global data_work	"$root\01_data_work"
global log   		"$root\02_results\01_logs"
global graph	  	"$root\02_results\02_graphs"
global table		"$root\02_results\03_tables"
capture mkdir "$data_work"
capture mkdir "$root\02_results"
capture mkdir "$log"
capture mkdir "$graph"
capture mkdir "$table"

capture log close smcllog
capture log close txtlog
* Stata log (.smcl)
log using "$log\AOK_comorbidities_master_log.smcl", ///
    replace name(smcllog)

* Plain text log (.txt)
log using "$log\AOK_comorbidities_master_log.txt", ///
    text replace name(txtlog)
di "================================================================"
di "AOK - Comorbidities: Full Analysis Log"
di "Run date:     `c(current_date)' `c(current_time)'"
di "Stata:        `c(stata_version)' (`c(os)')"
di "User:         `c(username)'"
di "Processors:   `c(processors)'"
di "Memory:       `c(memory)'"
di "Do-file:      00_Master.do"
di "================================================================"

di "Hardware Information:"
about
shell powershell "Get-CimInstance Win32_Processor | Select-Object -ExpandProperty Name"
shell powershell "Get-CimInstance Win32_ComputerSystem | Select-Object Manufacturer,Model"
shell powershell "Get-CimInstance Win32_VideoController | Select-Object -ExpandProperty Name"
di "================================================================"

/**************************************************************
* Master-Do-File:	AOK - Comorbidities
* Journal:
* Author:			Lorenz Weißenberg & Dr. Steffen Otterbach
* Stata:			Version 19.5; MP-Parallel Edition
* Startdate:		01.10.2025
* Last Change:		20.07.2026
**************************************************************/

* Set seed for overall reproducibility. However, not needed as output 
* is deterministic 
set seed 12345   			
version 19.5				// define STATA version		 
set more off, permanently	// default setting 	 
set varabbrev off			// no auto variable abbrevation 
set rmsg on					// activate return message 	
clear all 			

* check and install user-written packages 
foreach pkg in distinct egenmore psmatch2 stddiff parmest {
      capture which `pkg'
      if _rc ssc install `pkg'
}

/*********************************************************
* 1) Create ANALYSIS-DF  
*********************************************************/


/**********************
*  Create Merge-Files
**********************/
* Note: Scripts retain only the variables used in this paper's reported
* analysis, keeping the code lean. A full overview over the underlying 
* data can be found on GitHub. All displayed results are aggregated
* across individuals (counts, means, proportions, or model estimates).
* The only exceptions are two short listings (09, 10) that print a few
* matched sets row by row to illustrate the data structure. Both are
* strictly limited and neither shows diagnoses together with the
* corresponding demographics, preserving anonymity.
*
* The raw data also contain a second, unmatched control group representing
* the overall insured population. This group is excluded from the analysis
* for two reasons: (1) it was obtained only during the peer-review process,
* after the paper's initial submission, and, more importantly, (2) it does 
* not meaningfully improve covariate balance. Dropping it therefore leaves 
* the results of this study unaffected.

// 1: Calculates total # of insured individuals per year (Q4 counts; 2024 reported)
* Input: 		'06_AOK_full_ins_pop.txt' 
* Output:		'None'
do "$script\01_num_insurees.do"
 
// 2: Prepare analysis groups and individual-level fixed demographics
* Input:		'01_AOK_trunk.txt'
* Output:		'ana_grp_fixed_demo.dta'
do "$script\02_ana_grps_AND_fixed_demo.do"

// 3. Rename and clean costs 
* Input:		'02_AOK_costs.txt' 
* Output:		'ana_grp_costs_yearly.dta'
do "$script\03_ana_grps_costs_yearly.do"

// 4. Prepare demographic characteristics for analysis groups (yearly)
* Input:   		'03_AOK_demo_erratum.txt'
* Output:  		'ana_grp_demo_yyyyq.dta'
do "$script\04_ana_grps_demo.do"

// 5. Prepare Treatment Indicators
* Input:		'05_AOK_hc_use.txt'
* Output:		'ana_grp_treat_yyyyq.dta'
do "$script\05_ana_grps_treat.do"

// 6. Create Diagnosis indicators based on the ICD-10-GM coding
* Input:		'04_AOK_ICD10_GM.txt'
* Output:		'ana_grp_diag_yyyyq.dta'
do "$script\06_ana_grps_ICD10_diag.do"

/********************************
*  Merge-Files 2-6 to analysis DF  
*********************************/

// 7. Prepare Quarterly and Yearly Analysis DF 
* Input:		'ana_grp_fixed_demo.dta'
*				'ana_grp_costs_yearly.dta'
*				'ana_grp_demo_yyyyq.dta'
*				'ana_grp_treat_yyyyq.dta'
*				'ana_grp_diag_yyyyq.dta'
* Output:		'analysis_df_y.dta'
*				'analysis_df_yyyyq.dta'
do "$script\07_Analysis_DS.do"

// 8. Assess DS Balance and get Study Size
* Input:		'analysis_df_y.dta'
* Output:		'analysis_df_y_case_mc_2.dta'
*				'psm_case_pool.dta'
*				'psm_mc_control_pool.dta'
do "$script\08_Study_Size.do"

// 9. PSM; Alignment of Time; Check Cov. Balance
* Input:		'psm_case_pool.dta'
* 				'psm_mc_control_pool.dta'
* 				'analysis_df_y_case_mc_2.dta'
* Output:		'event_case_mc.dta'
*				'used_controls_mcpool'
*				'event_case_mc_varsummary.xlsx'
do "$script\09_PSM.do"


/*********************************************************
* 2) Analysis
*********************************************************/
* Input:		'event_case_mc.dta'
* Output:		'prev_pooled.dta', 'cors_pooled.dta'
*				'prev_pooled.csv', 'cors_pooled.csv'
*				'panel_left.gph', 'panel_right.gph', 'g1.gph' - 'g15.gph'
*				'incident_cases_and_number_cc_sets.emf'
*				'combined_psych_corrs1.emf', 'combined_psych_corrs2.emf'
*				'average_number_psychiatric_diagnoses.emf'
do "$script\10_Analysis.do"

/*********************************************************
* End of Master-Do-File
*********************************************************/

di "================================================================"
di "AOK - Comorbidities: Full Analysis Log - COMPLETED"
di "End date:  `c(current_date)' `c(current_time)'"
di "================================================================"
display "All scripts executed successfully."
display "Logs saved to:"
display "  $log\AOK_comorbidities_master_log.smcl"
display "  $log\AOK_comorbidities_master_log.txt"

log close smcllog
log close txtlog
exit 0