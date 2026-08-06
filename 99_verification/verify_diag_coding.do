* Diagnosis-coding audit: (1) validate every distinct ICD code in every year
* against the block definitions of 06 (spec: numeric code ranges vs the
* implemented substring rules), incl. malformed codes, censored 3-character
* codes and all F63.x variants; (2) re-verify the quarterly diagnosis file
* ana_grp_diag_yyyyq.dta flag-by-flag from raw
clear all
set more off
set rmsg on
global raw  "C:\Users\weissenberg\Desktop\AOK_Revision\data_26_ano\01_Data"
global work "C:\Users\weissenberg\Desktop\AOK_Revision\01_data_work"

import delimited "$raw\04_AOK_ICD10_GM.txt", clear

di "===================== 1: raw validity, all records ====================="
count if !inrange(floor(yyyyq/10), 2011, 2024) | !inrange(mod(yyyyq,10), 1, 4)
di "  ^ records with yyyyq outside 2011Q1-2024Q4 (must be 0)"
count if icd != trim(icd) | icd != upper(icd)
di "  ^ codes with whitespace or lowercase (must be 0)"
count if !regexm(icd, "^[A-Z][0-9][0-9]")
di "  ^ codes not starting letter+2digits (must be 0)"
gen byte len = strlen(icd)
tab len
gen year = floor(yyyyq/10)
tab year if substr(icd,1,1) == "F"

* quarter row set (all chapters) for part 3
preserve
    keep ano yyyyq
    duplicates drop
    tempfile allq
    save `allq'
restore

keep if substr(icd,1,1) == "F"

di "===================== 2: audit of every distinct F code ====================="
preserve
    contract icd, freq(freq)
    gen byte len  = strlen(icd)
    gen num2 = real(substr(icd,2,2))
    di "-- all F63.x variants incl. censored bare F63 (F630 must be the GD code; a bare F63 would be ambiguous) --"
    list icd freq if substr(icd,1,3) == "F63", noobs sep(0)
    di "-- 3-character (censored) codes present --"
    list icd freq if len == 3, noobs sep(0)
    * implemented rules from 06
    gen byte r_F10_F19 = substr(icd,2,1) == "1"
    gen byte r_F10     = substr(icd,1,3) == "F10"
    gen byte r_F17     = substr(icd,1,3) == "F17"
    gen byte r_other   = inlist(substr(icd,1,3), "F11","F12","F13","F14","F15","F16","F18","F19")
    gen byte r_F30_F39 = substr(icd,2,1) == "3"
    gen byte r_F32_F33 = inlist(substr(icd,1,3), "F32","F33")
    gen byte r_F40_F48 = substr(icd,2,1) == "4"
    gen byte r_F40     = substr(icd,2,2) == "40"
    gen byte r_F41     = substr(icd,2,2) == "41"
    gen byte r_F42     = substr(icd,2,2) == "42"
    gen byte r_F43     = substr(icd,2,2) == "43"
    gen byte r_F50_F59 = substr(icd,2,1) == "5"
    gen byte r_F60noPG = substr(icd,2,1) == "6" & icd != "F630"
    gen byte r_F99     = substr(icd,1,3) == "F99"
    * spec: intended ICD-10-GM ranges via the numeric code
    gen byte s_F10_F19 = inrange(num2,10,19)
    gen byte s_F10     = num2 == 10
    gen byte s_F17     = num2 == 17
    gen byte s_other   = inlist(num2,11,12,13,14,15,16,18,19)
    gen byte s_F30_F39 = inrange(num2,30,39)
    gen byte s_F32_F33 = inlist(num2,32,33)
    gen byte s_F40_F48 = inrange(num2,40,48)
    gen byte s_F40     = num2 == 40
    gen byte s_F41     = num2 == 41
    gen byte s_F42     = num2 == 42
    gen byte s_F43     = num2 == 43
    gen byte s_F50_F59 = inrange(num2,50,59)
    gen byte s_F60noPG = inrange(num2,60,69) & icd != "F630"
    gen byte s_F99     = num2 == 99
    di "-- codes where implemented rule and intended range disagree (each list must be empty) --"
    foreach b in F10_F19 F10 F17 other F30_F39 F32_F33 F40_F48 F40 F41 F42 F43 F50_F59 F60noPG F99 {
        quietly count if r_`b' != s_`b'
        di as text "block `b' : " as result r(N) as text " deviating codes"
        list icd freq if r_`b' != s_`b', noobs
    }
    di "-- full mapping table: every distinct F code, its frequency, and block membership --"
    sort icd
    list icd freq len r_F10_F19 r_F30_F39 r_F40_F48 r_F50_F59 r_F60noPG r_F99, noobs sep(0)
restore

di "===================== 3: quarterly file ana_grp_diag_yyyyq from raw ====================="
* independent quarterly flags
gen byte i_nopg     = icd != "F630"
gen byte i_gd       = icd == "F630"
gen byte i_F10_F19  = substr(icd,2,1) == "1"
gen byte i_F10      = substr(icd,1,3) == "F10"
gen byte i_F17      = substr(icd,1,3) == "F17"
gen byte i_other    = inlist(substr(icd,1,3), "F11","F12","F13","F14","F15","F16","F18","F19")
gen byte i_F30_F39  = substr(icd,2,1) == "3"
gen byte i_F32_F33  = inlist(substr(icd,1,3), "F32","F33")
gen byte i_F40_F48  = substr(icd,2,1) == "4"
gen byte i_F40      = substr(icd,1,3) == "F40"
gen byte i_F41      = substr(icd,1,3) == "F41"
gen byte i_F42      = substr(icd,1,3) == "F42"
gen byte i_F43      = substr(icd,1,3) == "F43"
gen byte i_F50_F59  = substr(icd,2,1) == "5"
gen byte i_F60noPG  = substr(icd,2,1) == "6" & icd != "F630"
gen byte i_F99      = substr(icd,1,3) == "F99"
* yearly num_pd (distinct 3-char codes excl. F630)
gen icd3 = substr(icd,1,3)
egen byte tag3 = tag(ano year icd3) if icd != "F630"
preserve
    bysort ano year: egen npd = total(tag3)
    bysort ano year: keep if _n == 1
    keep ano year npd
    tempfile numpdy
    save `numpdy'
restore
collapse (max) i_*, by(ano yyyyq)
tempfile fflags
save `fflags'

use `allq', clear
merge 1:1 ano yyyyq using `fflags', nogen
gen year = floor(yyyyq/10)
merge m:1 ano year using `numpdy', keep(master match) nogen
foreach v of varlist i_* npd {
    replace `v' = 0 if missing(`v')
}
merge 1:1 ano yyyyq using "$work\ana_grp_diag_yyyyq.dta"
di "-- quarter row set: only in independent rebuild / only in stored file (both must be 0) --"
count if _merge == 1
count if _merge == 2
keep if _merge == 3
count if keep_ind != 1
di "  ^ stored keep_ind not 1 (must be 0)"
di "-- quarterly flag mismatches (each must be 0) --"
local A "F00_F99_nopg gambl_dis_diag F10_F19 F10 F17 other_psych F30_F39 F32_F33 F40_F48 F40 F41 F42 F43 F50_F59 F60_F69_noPG F99"
local B "i_nopg i_gd i_F10_F19 i_F10 i_F17 i_other i_F30_F39 i_F32_F33 i_F40_F48 i_F40 i_F41 i_F42 i_F43 i_F50_F59 i_F60noPG i_F99"
local n : word count `A'
local bad = 0
forvalues k = 1/`n' {
    local a : word `k' of `A'
    local b : word `k' of `B'
    quietly count if `a' != `b'
    di as text "`a' : " as result r(N)
    local bad = `bad' + r(N)
}
di as text "TOTAL QUARTERLY FLAG MISMATCHES = " as result `bad'
di "-- quarterly num_pd: stored vs yearly-attached (current 06 code) --"
count if num_pd != npd
di "-- quarterly num_pd: stored vs old pre-fix semantics (yearly value only in quarters with an F record, else 0) --"
gen byte anyF = (i_nopg | i_gd)
count if num_pd != npd * anyF
di "  ^ whichever of the two counts is 0 tells which 06 version produced the stored file"
di "-- GD inpatient/outpatient split vs run log (log: amb 100,929 / stat_HD 794 / stat_ND 5,946) --"
di "===================== DONE ====================="
exit
