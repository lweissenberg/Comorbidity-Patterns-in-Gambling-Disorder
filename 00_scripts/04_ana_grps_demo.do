/******************************************************************
* Project: 		AOK - Comorbidities
* DO_04: 		Generate demographic characteristics for the analysis groups 
				for later merging into the Analysis DF
* Startdate:	16.10.2025
* Last Change:	13.07.2026
* Input:		'03_AOK_demo_erratum.txt'
* Output:		'ana_grp_demo_yyyyq.dta'
*******************************************************************/

// 1: Import data
import delimited "$data_raw\03_AOK_demo_erratum.txt", clear 
 
// 2: Generate 'raumstruktur' levels 1-6
rename raumstruktur spatial_str
gen byte spatial_num = .
label var spatial_num "Spatial Structure (categorical): 1 = highly rural; 6 = highly urban"
* recode German strings 
replace spatial_num = 1 if spatial_str == "Peripherraum sehr geringer Dichte"
replace spatial_num = 2 if spatial_str == "Peripherraum mit Verdichtungsansätzen"
replace spatial_num = 3 if spatial_str == "Zwischenraum geringer Dichte"
replace spatial_num = 4 if spatial_str == "Zwischenraum mit Verdichtungsansätzen"
replace spatial_num = 5 if spatial_str == "Äußerer Zentralraum"
replace spatial_num = 6 if spatial_str == "Innerer Zentralraum"
label define spatial_lbl ///
    1 "Peripheral very low density" ///
    2 "Peripheral densification" ///
    3 "Intermediate low density" ///
    4 "Intermediate densification" ///
    5 "Outer central area" ///
    6 "Inner central area"
label values spatial_num spatial_lbl
drop spatial_str
rename spatial_num spatial_str

// 3: Create dummies for descriptive groups of 'vart' = type of insurance coverage
rename vart insur_type
recast float insur_type
label variable insur_type "Type of health insurance / beneficiary group"
capture label define insur_type_lbl ///
    1 "Obligatory insured (KV-Pflichtige)" ///
    2 "Pension applicants (Rentenantragsteller)" ///
    3 "Pension recipients (Rentenbezieher)" ///
    4 "Insured under Para. 155 AFG (§155 AFG)" ///
    5 "Voluntarily insured (Freiwillig Versicherte)" ///
    6 "Rehabilitants (Rehabilitanden)" ///
    9 "Family members (Familienangehörige)"
label values insur_type insur_type_lbl

// 4: Save data
keep ano yyyyq insur_type spatial_str
save "$data_work\ana_grp_demo_yyyyq.dta", replace
clear all

/****************
* End of .do file
****************/