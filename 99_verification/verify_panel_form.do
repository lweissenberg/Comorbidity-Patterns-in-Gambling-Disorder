* Independent verification of the pipeline that shapes the analysis DF (07-09):
* rebuild the analysis_df_y row set from the raw extracts with independent idioms,
* recompute the lastnm spatial/insurance values, compare all demographics
* against the raw trunk, then test the eligibility and alignment invariants
* of event_case_mc (incl. first-GD year from raw and never-GD controls)
clear all
set more off
set rmsg on
global raw  "C:\Users\weissenberg\Desktop\AOK_Revision\data_26_ano\01_Data"
global work "C:\Users\weissenberg\Desktop\AOK_Revision\01_data_work"

di "===================== 0: prepare raw source files ====================="
* diagnoses -> quarter presence + first GD year per person
import delimited "$raw\04_AOK_ICD10_GM.txt", clear
preserve
    keep if icd == "F630"
    bysort ano: egen gd1st_raw = min(floor(yyyyq / 10))
    bysort ano: keep if _n == 1
    keep ano gd1st_raw
    tempfile gdfirst
    save `gdfirst'
restore
keep ano yyyyq
duplicates drop
gen byte diagp = 1
tempfile diagpres
save `diagpres'

* demographics -> quarterly spatial (umlaut-free mapping) + insurance type
import delimited "$raw\03_AOK_demo_erratum.txt", clear
keep ano yyyyq raumstruktur vart
duplicates report ano yyyyq
gen byte sp = .
replace sp = 1 if strpos(raumstruktur, "Peripherraum") & strpos(raumstruktur, "sehr geringer")
replace sp = 2 if strpos(raumstruktur, "Peripherraum") & strpos(raumstruktur, "Verdichtung")
replace sp = 3 if strpos(raumstruktur, "Zwischenraum") & strpos(raumstruktur, "geringer")
replace sp = 4 if strpos(raumstruktur, "Zwischenraum") & strpos(raumstruktur, "Verdichtung")
replace sp = 5 if strpos(raumstruktur, "Zentralraum") & !strpos(raumstruktur, "Innerer")
replace sp = 6 if strpos(raumstruktur, "Innerer Zentralraum")
count if missing(sp) & trim(raumstruktur) != ""
rename vart insur
keep ano yyyyq sp insur
tempfile demoq
save `demoq'

* sick leave (quarterly) and costs (yearly)
import delimited "$raw\05_AOK_hc_use.txt", clear
keep ano yyyyq au_tage
rename au_tage sick
duplicates report ano yyyyq
tempfile sickq
save `sickq'
import delimited "$raw\02_AOK_costs.txt", clear
keep ano jahr ausg_gesamt
rename (jahr ausg_gesamt) (year te)
duplicates report ano year
tempfile costy
save `costy'

di "===================== 1: rebuild the ano x quarter grid and apply 07's rules ====================="
import delimited "$raw\01_AOK_trunk.txt", clear
keep ano ana_grup geb geschlecht tod_j deutsch
expand 56
bysort ano: gen k = _n - 1
gen year    = 2011 + floor(k / 4)
gen quarter = mod(k, 4) + 1
gen yyyyq   = year * 10 + quarter
drop k
merge m:1 ano year using `costy',    keep(master match) nogen
merge 1:1 ano yyyyq using `sickq',   keep(master match) nogen
merge 1:1 ano yyyyq using `diagpres', keep(master match) nogen
merge 1:1 ano yyyyq using `demoq',   keep(master match) nogen
* 07 step 7: presence rules
drop if te == . & sick == . & diagp == .
drop if te == 0 & insur == . & diagp == . & sick == .
* 07 step 9: final adjustments
drop if year > tod_j
drop if missing(geb)
drop if year < geb
* 07 step 11: lastnm within surviving quarters -> latest quarter with data
gen double spkey = cond(!missing(sp), yyyyq, .)
egen double spq = max(spkey), by(ano year)
gen byte sp_pick = sp if yyyyq == spq
egen byte sp_last = max(sp_pick), by(ano year)
gen double inkey = cond(!missing(insur), yyyyq, .)
egen double inq = max(inkey), by(ano year)
gen in_pick = insur if yyyyq == inq
egen in_last = max(in_pick), by(ano year)
collapse (max) sp_last in_last ana_grup geb geschlecht tod_j deutsch, by(ano year)
tempfile recon
save `recon'

di "===================== 2: compare rebuilt panel vs analysis_df_y ====================="
use "$work\analysis_df_y.dta", clear
isid ano year
count if missing(year)
keep ano year age female german yob yod dead dead_end spatial_str insur_type ///
    ana_grp_gd ana_grp_mc ana_grp_uc
merge 1:1 ano year using `recon'
di "-- row set: rows only in analysis_df_y (must be 0) --"
count if _merge == 1
di "-- row set: rows only in independent rebuild (must be 0) --"
count if _merge == 2
keep if _merge == 3
di "-- variable-level mismatches (each must be 0) --"
count if !(spatial_str == sp_last | (missing(spatial_str) & missing(sp_last)))
di "  ^ spatial_str vs independent lastnm rebuild"
count if !(insur_type == in_last | (missing(insur_type) & missing(in_last)))
di "  ^ insur_type vs independent lastnm rebuild"
count if age != year - geb
di "  ^ age"
count if female != (geschlecht == 1)
di "  ^ female"
count if !(german == deutsch | (missing(german) & missing(deutsch)))
di "  ^ german"
count if yob != geb
di "  ^ yob"
count if !(yod == tod_j | (missing(yod) & missing(tod_j)))
di "  ^ yod"
count if dead != (!missing(tod_j) & year >= tod_j)
di "  ^ dead"
count if dead_end != (!missing(tod_j) & tod_j != 2025)
di "  ^ dead_end"
count if ana_grp_gd != (ana_grup == 1) | ana_grp_mc != (ana_grup == 0) | ana_grp_uc != (ana_grup == 2)
di "  ^ analysis-group flags"

di "===================== 3: event_case_mc eligibility & alignment invariants ====================="
* panel years per person (for the controls-in-all-14-years rule)
use "$work\analysis_df_y.dta", clear
bysort ano: gen ny = _N
bysort ano: keep if _n == 1
keep ano ny
tempfile panyears
save `panyears'
* covariates per person-year (for index-year checks)
use "$work\analysis_df_y.dta", clear
keep ano year age female german spatial_str
tempfile pancov
save `pancov'

use "$work\event_case_mc.dta", clear
di "-- t_event outside [-5,5] (must be 0) --"
count if !inrange(t_event, -5, 5)
di "-- rows where a set's members sit in different calendar years at the same t_event (must be 0) --"
egen ymin = min(year), by(match_ID t_event)
egen ymax = max(year), by(match_ID t_event)
count if ymin != ymax

di "-- CASES: index year vs first F63.0 year in RAW data --"
preserve
    keep if gvar == 1
    keep ano year
    rename year y0
    merge 1:1 ano using `gdfirst', keep(master match)
    count if _merge == 1
    di "  ^ cases with no F63.0 record in raw data (must be 0)"
    count if y0 != gd1st_raw
    di "  ^ cases whose index year differs from raw first-GD year (must be 0)"
    count if !inrange(y0, 2014, 2024)
    di "  ^ index year outside 2014-2024 (must be 0)"
    drop _merge
    rename y0 year
    merge 1:1 ano year using `pancov', keep(master match)
    count if _merge == 1
    di "  ^ case index rows missing from panel (must be 0)"
    count if age < 18
    di "  ^ cases younger than 18 at index year (must be 0)"
    count if missing(age) | missing(female) | missing(german) | missing(spatial_str)
    di "  ^ cases with incomplete PSM covariates at index year (must be 0)"
restore

di "-- CASES: presence of the required lag rows t-1..t-3 --"
preserve
    keep if ever_gd == 1
    bysort ano: egen byte h1 = max(t_event == -1)
    bysort ano: egen byte h2 = max(t_event == -2)
    bysort ano: egen byte h3 = max(t_event == -3)
    bysort ano: keep if _n == 1
    count if !(h1 & h2 & h3)
    di "  ^ cases missing any of the t-1/t-2/t-3 rows (must be 0)"
restore

di "-- CONTROLS: never GD-diagnosed, full 14-year coverage, valid at index year --"
preserve
    keep if ever_gd == 0
    bysort ano: keep if _n == 1
    keep ano
    merge 1:1 ano using `gdfirst', keep(master match)
    count if _merge == 3
    di "  ^ controls with ANY F63.0 record in raw data (expect 0)"
    list ano gd1st_raw if _merge == 3, noobs
    drop _merge gd1st_raw
    merge 1:1 ano using `panyears', keep(master match)
    count if ny != 14
    di "  ^ controls not observed in all 14 panel years (must be 0)"
restore
preserve
    keep if ever_gd == 0 & t_event == 0
    keep ano year
    merge 1:1 ano year using `pancov', keep(master match)
    count if _merge == 1
    di "  ^ control index rows missing from panel (must be 0)"
    count if age < 18
    di "  ^ controls younger than 18 at index year (must be 0)"
    count if missing(age) | missing(female) | missing(german) | missing(spatial_str)
    di "  ^ controls with incomplete PSM covariates at index year (must be 0)"
restore
di "===================== DONE ====================="
exit
