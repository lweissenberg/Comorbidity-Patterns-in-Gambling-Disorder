* Independent verification: recompute aggregates from raw extracts with
* different idioms than the pipeline, compare against stored .dta outputs
clear all
set more off
set rmsg on
global raw  "C:\Users\weissenberg\Desktop\AOK_Revision\data_26_ano\01_Data"
global work "C:\Users\weissenberg\Desktop\AOK_Revision\01_data_work"

di "===================== A: insurees per year Q4 (independent) ====================="
import delimited "$raw\06_AOK_full_ins_pop.txt", clear
keep if mod(yyyyq, 10) == 4
gen year = floor(yyyyq / 10)
bysort year: egen double tot = total(n_vers)
egen byte t1 = tag(year)
format tot %15.0fc
list year tot if t1, clean noobs

di "===================== B: trunk vs ana_grp_fixed_demo ====================="
import delimited "$raw\01_AOK_trunk.txt", clear
duplicates report ano
count
tab ana_grup, missing
tab geschlecht ana_grup, missing
count if !missing(tod_j)
count if tod_j == 2025
use "$work\ana_grp_fixed_demo.dta", clear
count
tab ana_grp_gd
tab ana_grp_mc
tab ana_grp_uc
tab female
tab dead_end
count if !missing(yod)

di "===================== C: raw ICD overview ====================="
import delimited "$raw\04_AOK_ICD10_GM.txt", clear
count
gen byte isF = substr(icd, 1, 1) == "F"
count if isF
distinct ano if icd == "F630"
tab sektor if icd == "F630"

di "===================== D/E: independent ano-year flags + num_pd ====================="
keep if isF
gen year = floor(yyyyq / 10)
gen icd3 = substr(icd, 1, 3)
gen byte pd_ok = icd != "F630"
egen byte tag3 = tag(ano year icd3) if pd_ok
bysort ano year: egen num_pd_i = total(tag3)
gen byte i_nopg     = icd != "F630"
gen byte i_gd       = icd == "F630"
gen byte i_F10_F19  = substr(icd, 2, 1) == "1"
gen byte i_F10      = substr(icd, 1, 3) == "F10"
gen byte i_F17      = substr(icd, 1, 3) == "F17"
gen byte i_other    = inlist(substr(icd, 1, 3), "F11", "F12", "F13", "F14", "F15", "F16", "F18", "F19")
gen byte i_F30_F39  = substr(icd, 2, 1) == "3"
gen byte i_F32_F33  = inlist(substr(icd, 1, 3), "F32", "F33")
gen byte i_F40_F48  = substr(icd, 2, 1) == "4"
gen byte i_F40      = substr(icd, 1, 3) == "F40"
gen byte i_F41      = substr(icd, 1, 3) == "F41"
gen byte i_F42      = substr(icd, 1, 3) == "F42"
gen byte i_F43      = substr(icd, 1, 3) == "F43"
gen byte i_F50_F59  = substr(icd, 2, 1) == "5"
gen byte i_F60nopg  = substr(icd, 2, 1) == "6" & icd != "F630"
gen byte i_F99      = substr(icd, 1, 3) == "F99"
collapse (max) i_* num_pd_i, by(ano year)
tempfile indep
save `indep'

use "$work\analysis_df_y.dta", clear
keep ano year num_pd gambl_dis_diag F00_F99_nopg F10_F19 F10 F17 other_psych ///
    F30_F39 F32_F33 F40_F48 F40 F41 F42 F43 F50_F59 F60_F69_noPG F99
merge 1:1 ano year using `indep'
di "--- panel person-years without any F record (expect flags/num_pd all 0) ---"
local A "F00_F99_nopg gambl_dis_diag F10_F19 F10 F17 other_psych F30_F39 F32_F33 F40_F48 F40 F41 F42 F43 F50_F59 F60_F69_noPG F99"
local B "i_nopg i_gd i_F10_F19 i_F10 i_F17 i_other i_F30_F39 i_F32_F33 i_F40_F48 i_F40 i_F41 i_F42 i_F43 i_F50_F59 i_F60nopg i_F99"
local nbad = 0
local n : word count `A'
forvalues k = 1/`n' {
    local a : word `k' of `A'
    local b : word `k' of `B'
    quietly count if _merge == 3 & `a' != `b'
    local m3 = r(N)
    quietly count if _merge == 1 & `a' != 0
    local m1 = r(N)
    di as text "`a' : mismatches on matched rows = " as result `m3' ///
        as text " ; nonzero without F record = " as result `m1'
    local nbad = `nbad' + `m3' + `m1'
}
quietly count if _merge == 3 & num_pd != num_pd_i
di as text "num_pd : mismatches on matched rows = " as result r(N)
local nbad = `nbad' + r(N)
quietly count if _merge == 1 & num_pd != 0
di as text "num_pd : nonzero without F record = " as result r(N)
local nbad = `nbad' + r(N)
di as text "TOTAL FLAG/NUM_PD DISCREPANCIES = " as result `nbad'

di "--- F person-years missing from panel (_merge==2): why ---"
count if _merge == 2
preserve
    keep if _merge == 2
    keep ano year
    merge m:1 ano using "$work\ana_grp_fixed_demo.dta", keep(master match)
    count if _merge == 1
    count if _merge == 3 & missing(yob)
    count if _merge == 3 & year < yob
    count if _merge == 3 & year > yod & !missing(yod)
    count if _merge == 3 & !missing(yob) & year >= yob & (year <= yod | missing(yod))
restore

di "===================== F: event_case_mc vs analysis_df_y ====================="
use "$work\analysis_df_y.dta", clear
keep ano year num_pd gambl_dis_diag F00_F99_nopg F10_F19 F10 F17 other_psych ///
    F30_F39 F32_F33 F40_F48 F40 F41 F42 F43 F50_F59 F60_F69_noPG F99
foreach v of varlist num_pd gambl_dis_diag F00_F99_nopg F10_F19 F10 F17 other_psych ///
    F30_F39 F32_F33 F40_F48 F40 F41 F42 F43 F50_F59 F60_F69_noPG F99 {
    rename `v' p_`v'
}
tempfile panelvals
save `panelvals'
use "$work\event_case_mc.dta", clear
distinct ano if ever_gd == 1
distinct ano if ever_gd == 0
count if gvar == 1 & t_event != 0
count if ever_gd == 1 & t_event == 0 & gvar != 1
egen ncase_sy = total(ever_gd), by(match_ID t_event)
count if ncase_sy != 1
drop ncase_sy
preserve
    keep if t_event == 0
    bysort match_ID: gen mem = _N
    egen nc = total(ever_gd), by(match_ID)
    egen byte tset = tag(match_ID)
    tab mem if tset
    tab nc if tset
restore
merge 1:1 ano year using `panelvals', keep(master match)
count if _merge == 1
local nbad2 = 0
foreach v in num_pd F00_F99_nopg F10_F19 F10 F17 other_psych F30_F39 F32_F33 ///
    F40_F48 F40 F41 F42 F43 F50_F59 F60_F69_noPG F99 {
    quietly count if _merge == 3 & `v' != p_`v'
    di as text "`v' : event vs panel mismatches = " as result r(N)
    local nbad2 = `nbad2' + r(N)
}
quietly count if gvar == 1 & p_gambl_dis_diag != 1
di as text "gvar==1 without GD diag in panel that year = " as result r(N)
local nbad2 = `nbad2' + r(N)
di as text "TOTAL EVENT-VS-PANEL DISCREPANCIES = " as result `nbad2'

di "===================== G: t0 prevalences recomputed ====================="
use "$work\event_case_mc.dta", clear
keep if t_event == 0
foreach v in F00_F99_nopg F30_F39 F40_F48 F10_F19 F60_F69_noPG F50_F59 F99 ///
    F17 F10 other_psych F43 F41 F40 F42 F32_F33 {
    quietly summarize `v' if ever_gd == 1
    local case = string(100 * r(mean), "%6.2f")
    quietly summarize `v' if ever_gd == 0
    local ctrl = string(100 * r(mean), "%6.2f")
    di as text "`v'" _col(16) " cases: " as result "`case'" as text "   controls: " as result "`ctrl'"
}
di "===================== DONE ====================="
exit
