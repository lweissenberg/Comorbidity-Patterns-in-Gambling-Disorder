* Independent re-verification #2 (2026-07-30): rebuild every variable and the
* exact row set of analysis_df_y from the raw extracts using idioms disjoint from
* the pipeline AND from verify_agg.do / verify_panel_form.do:
*   - key-union of source files instead of a balanced ano x quarter grid
*   - lookup-table join for the spatial-string mapping instead of replace chains
*   - numeric ICD ranges via real() instead of substring equality
*   - carry-forward within (ano, year) instead of egen-max keys for lastnm
*   - arithmetic age-group formula instead of chained replaces
* then compare row sets in both directions and every cell on matched rows
clear all
set more off
set rmsg on
global raw  "C:\Users\weissenberg\Desktop\AOK_Revision\data_26_ano\01_Data"
global work "C:\Users\weissenberg\Desktop\AOK_Revision\01_data_work"

di "===================== 0: raw source preparation ====================="
import delimited "$raw\01_AOK_trunk.txt", clear
isid ano
keep ano ana_grup geb geschlecht tod_j deutsch
tempfile trunk
save `trunk'

import delimited "$raw\02_AOK_costs.txt", clear
isid ano jahr
rename (jahr ausg_gesamt) (year te)
keep ano year te
expand 4
bysort ano year: gen q = _n
gen yyyyq = year * 10 + q
keep ano yyyyq te
tempfile costq
save `costq'

import delimited "$raw\05_AOK_hc_use.txt", clear
isid ano yyyyq
rename au_tage sick
keep ano yyyyq sick
tempfile sickq
save `sickq'

clear
input byte spv str60 rs
1 "Peripherraum sehr geringer Dichte"
2 "Peripherraum mit Verdichtungsansätzen"
3 "Zwischenraum geringer Dichte"
4 "Zwischenraum mit Verdichtungsansätzen"
5 "Äußerer Zentralraum"
6 "Innerer Zentralraum"
end
tempfile splookup
save `splookup'
import delimited "$raw\03_AOK_demo_erratum.txt", clear
isid ano yyyyq
rename (raumstruktur vart) (rs insur)
merge m:1 rs using `splookup', keep(master match)
count if _merge != 3 & trim(rs) != ""
di "  ^ demo rows with unmapped nonblank spatial string (must be 0)"
gen byte sp = spv
keep ano yyyyq sp insur
tempfile demoq
save `demoq'

import delimited "$raw\04_AOK_ICD10_GM.txt", clear
preserve
    keep ano yyyyq
    duplicates drop
    gen byte diagp = 1
    tempfile diagpres
    save `diagpres'
restore
keep if substr(icd, 1, 1) == "F"
count if strlen(icd) < 3
di "  ^ F records shorter than 3 characters (must be 0)"
gen year = floor(yyyyq / 10)
count if !inrange(year, 2011, 2024) | !inrange(mod(yyyyq, 10), 1, 4)
di "  ^ F records outside the 2011q1-2024q4 grid (must be 0)"
preserve
    keep if icd != "F630"
    gen icd3 = substr(icd, 1, 3)
    bysort ano year icd3: keep if _n == 1
    bysort ano year: gen npd_i = _N
    by ano year: keep if _n == 1
    keep ano year npd_i
    tempfile numpd
    save `numpd'
restore
gen d2 = real(substr(icd, 2, 2))
count if missing(d2)
di "  ^ F records with non-numeric 2-digit part (must be 0)"
count if d2 == 49
di "  ^ F49 records (would make F40_F48 wider than its label; expect 0)"
gen byte c_nopg    = icd != "F630"
gen byte c_gd      = icd == "F630"
gen byte c_F10_F19 = inrange(d2, 10, 19)
gen byte c_F10     = d2 == 10
gen byte c_F17     = d2 == 17
gen byte c_other   = inrange(d2, 11, 16) | inrange(d2, 18, 19)
gen byte c_F30_F39 = inrange(d2, 30, 39)
gen byte c_F32_F33 = inrange(d2, 32, 33)
gen byte c_F40_F48 = inrange(d2, 40, 49)
gen byte c_F40     = d2 == 40
gen byte c_F41     = d2 == 41
gen byte c_F42     = d2 == 42
gen byte c_F43     = d2 == 43
gen byte c_F50_F59 = inrange(d2, 50, 59)
gen byte c_F60nopg = inrange(d2, 60, 69) & icd != "F630"
gen byte c_F99     = d2 == 99
collapse (max) c_*, by(ano year)
tempfile flags
save `flags'

di "===================== 1: key-union rebuild of the person-year row set ====================="
use `costq', clear
append using `sickq'
append using `diagpres'
collapse (max) te sick diagp, by(ano yyyyq)
gen year = floor(yyyyq / 10)
count if !inrange(year, 2011, 2024) | !inrange(mod(yyyyq, 10), 1, 4)
di "  ^ presence quarters outside the grid (dropped, as the balanced grid drops them)"
drop if !inrange(year, 2011, 2024) | !inrange(mod(yyyyq, 10), 1, 4)
merge 1:1 ano yyyyq using `demoq', keep(master match) nogen
* 07 step 7 presence rules; rule 1 (te/sick/diagp all missing) cannot fire on
* union rows by construction, rule 2 applied verbatim
drop if te == 0 & insur == . & diagp == . & sick == .
merge m:1 ano using `trunk'
count if _merge == 1
di "  ^ presence quarters whose ano is missing from the trunk (must be 0)"
keep if _merge == 3
drop _merge
* 07 step 9 final adjustments
drop if missing(geb)
drop if year < geb
drop if year > tod_j
* lastnm via carry-forward: latest surviving quarter with a non-missing value
bysort ano year (yyyyq): gen spc = sp
by ano year: replace spc = spc[_n - 1] if missing(spc)
bysort ano year (yyyyq): gen insc = insur
by ano year: replace insc = insc[_n - 1] if missing(insc)
by ano year: keep if _n == _N
keep ano year spc insc ana_grup geb geschlecht tod_j deutsch
merge 1:1 ano year using `flags'
count if _merge == 2
di "  ^ F person-years excluded by the row rules (78 post-death rows expected)"
drop if _merge == 2
drop _merge
merge 1:1 ano year using `numpd', keep(master match) nogen
tempfile recon
save `recon'

di "===================== 2: cell-by-cell comparison vs analysis_df_y ====================="
use "$work\analysis_df_y.dta", clear
isid ano year
count
merge 1:1 ano year using `recon'
local NBAD = 0
quietly count if _merge == 1
local NBAD = `NBAD' + r(N)
di as text "panel rows the rebuild does not produce (must be 0) = " as result r(N)
quietly count if _merge == 2
local NBAD = `NBAD' + r(N)
di as text "rebuilt rows absent from the panel (must be 0) = " as result r(N)
keep if _merge == 3
foreach v in c_nopg c_gd c_F10_F19 c_F10 c_F17 c_other c_F30_F39 c_F32_F33 ///
    c_F40_F48 c_F40 c_F41 c_F42 c_F43 c_F50_F59 c_F60nopg c_F99 {
    quietly replace `v' = 0 if missing(`v')
}
quietly replace npd_i = 0 if missing(npd_i)
local P "F00_F99_nopg gambl_dis_diag F10_F19 F10 F17 other_psych F30_F39 F32_F33 F40_F48 F40 F41 F42 F43 F50_F59 F60_F69_noPG F99"
local C "c_nopg c_gd c_F10_F19 c_F10 c_F17 c_other c_F30_F39 c_F32_F33 c_F40_F48 c_F40 c_F41 c_F42 c_F43 c_F50_F59 c_F60nopg c_F99"
local n : word count `P'
forvalues k = 1/`n' {
    local a : word `k' of `P'
    local b : word `k' of `C'
    quietly count if `a' != `b'
    local NBAD = `NBAD' + r(N)
    di as text "`a'" _col(20) "mismatches = " as result r(N)
}
quietly count if num_pd != npd_i
local NBAD = `NBAD' + r(N)
di as text "num_pd" _col(20) "mismatches = " as result r(N)
quietly count if yob != geb
local NBAD = `NBAD' + r(N)
di as text "yob" _col(20) "mismatches = " as result r(N)
quietly count if !(yod == tod_j | (missing(yod) & missing(tod_j)))
local NBAD = `NBAD' + r(N)
di as text "yod" _col(20) "mismatches = " as result r(N)
quietly count if age != year - geb
local NBAD = `NBAD' + r(N)
di as text "age" _col(20) "mismatches = " as result r(N)
quietly count if female != (geschlecht == 1)
local NBAD = `NBAD' + r(N)
di as text "female" _col(20) "mismatches = " as result r(N)
quietly count if !(german == deutsch | (missing(german) & missing(deutsch)))
local NBAD = `NBAD' + r(N)
di as text "german" _col(20) "mismatches = " as result r(N)
quietly count if dead != (!missing(tod_j) & year >= tod_j)
local NBAD = `NBAD' + r(N)
di as text "dead" _col(20) "mismatches = " as result r(N)
quietly count if dead_end != (!missing(tod_j) & tod_j != 2025)
local NBAD = `NBAD' + r(N)
di as text "dead_end" _col(20) "mismatches = " as result r(N)
quietly count if ana_grp_gd != (ana_grup == 1)
local NBAD = `NBAD' + r(N)
di as text "ana_grp_gd" _col(20) "mismatches = " as result r(N)
quietly count if ana_grp_mc != (ana_grup == 0)
local NBAD = `NBAD' + r(N)
di as text "ana_grp_mc" _col(20) "mismatches = " as result r(N)
quietly count if ana_grp_uc != (ana_grup == 2)
local NBAD = `NBAD' + r(N)
di as text "ana_grp_uc" _col(20) "mismatches = " as result r(N)
quietly count if !(spatial_str == spc | (missing(spatial_str) & missing(spc)))
local NBAD = `NBAD' + r(N)
di as text "spatial_str" _col(20) "mismatches = " as result r(N)
quietly count if !(insur_type == insc | (missing(insur_type) & missing(insc)))
local NBAD = `NBAD' + r(N)
di as text "insur_type" _col(20) "mismatches = " as result r(N)
gen byte ag_i = 1 + (age >= 18) + (age >= 21) + (age >= 26) + (age >= 36) ///
    + (age >= 46) + (age >= 56) + (age > 70)
quietly count if age_grp != ag_i
local NBAD = `NBAD' + r(N)
di as text "age_grp" _col(20) "mismatches = " as result r(N)
di as text "TOTAL DISCREPANCIES (row set + all variables) = " as result `NBAD'
di "===================== DONE ====================="
exit
