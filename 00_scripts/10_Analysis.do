/*******************************************************************
* DO_10: Analysis  
* Project: AOK - Comorbidities
* Startdate:	01.12.2025
* Last Change:	16.07.2026
********************************************************************/

// 1: Import data 
use "$data_work\event_case_mc.dta", clear 
tab year t_event, col
* show data structure and diagnosis example; uses different match_IDs than the
* listing in 09, so no individual appears in both listings (09 shows
* demographics, 10 shows diagnoses -> never both for the same person);
* variable guide:
*	ano          - anonymous individual ID
*	match_ID     - matched set (1 case + 2 controls)
*	ever_gd      - 1 = case (ever diagnosed with GD), 0 = matched control
*	gvar         - 1 only in the case's index year (first GD diagnosis), else 0
*	year         - calendar year
*	t_event      - year relative to the index year (for cases: gvar == 1 at t_event == 0)
*	num_pd       - # of unique psychiatric diagnoses in that year (3-character ICD-10-GM codes, excl. F63.0)
*	F00_F99_nopg ... F99 - binary: 1 = at least one diagnosis in the respective
*	                       ICD-10-GM block/subcategory in that year (Table 1), 0 = none
* how to read: each sepby-block is one matched set; per relative year a set
* contributes 3 rows (case + 2 controls) as long as the case is observed.
* Comparing the case row's F-indicators with its two control rows at the same
* t_event is the within-set comparison the clogit models estimate

sort match_ID ano t_event
list if inlist(match_ID, 10, 11, 12, 13, 14), sepby(match_ID) noobs

// 2: create incident cases + sample size plot 
*2.1 # of incident cases
preserve
    collapse (sum) n_cases = gvar, by(year)
    drop if year < 2014 
	list year n_cases, clean 
    twoway ///
        (bar n_cases year, barwidth(0.5) color(gs10)) ///
        , ///
        xtitle("Year", size(medium) margin(medsmall)) ///
        ytitle("Number of incident GD cases", size(medium) margin(medsmall)) ///
        xlabel(2014(1)2024, labsize(small)) ///
        ylabel(0(100)900, labsize(small) angle(horizontal)) ///
        yscale(range(0 900)) ///
        xscale(range(2013.5 2024.5)) ///
        yline(0(100)900, lcolor(gs14) lpattern(shortdash)) ///
        legend(off) ///
        xsize(4) ysize(4) ///
        graphregion(color(white) margin(2 2 2 2)) ///
        plotregion(margin(zero) lstyle(none)) ///
        scheme(s1mono)
    graph save "$graph\panel_left.gph", replace
restore

*2.2 sample size in rel. years 
preserve
    bysort t_event match_ID: gen tag = _n == 1
    collapse (sum) match_count = tag, by(t_event)
    twoway ///
        (line match_count t_event, lcolor(black) lwidth(thin)) ///
        (scatter match_count t_event, msymbol(circle) mcolor(black) msize(small)) ///
        , ///
        xtitle("Relative time period", size(medium) margin(medsmall)) ///
        ytitle("Number of retained matched case-control sets", size(medium) margin(medsmall)) ///
        xlabel( ///
            -5 "{it:t}{sub:-5}" ///
            -4 "{it:t}{sub:-4}" ///
            -3 "{it:t}{sub:-3}" ///
            -2 "{it:t}{sub:-2}" ///
            -1 "{it:t}{sub:-1}" ///
             0 "{it:t}{sub:0}" ///
             1 "{it:t}{sub:+1}" ///
             2 "{it:t}{sub:+2}" ///
             3 "{it:t}{sub:+3}" ///
             4 "{it:t}{sub:+4}" ///
             5 "{it:t}{sub:+5}", labsize(small)) ///
        ylabel(0(1000)9000, labsize(small) angle(horizontal)) ///
        yscale(range(0 9000)) ///
        xscale(range(-5.5 5.5)) ///
        yline(0(1000)9000, lcolor(gs14) lpattern(shortdash)) ///
        legend(off) ///
        xsize(4) ysize(4) ///
        graphregion(color(white) margin(2 2 2 2)) ///
        plotregion(margin(zero) lstyle(none)) ///
        scheme(s1mono)
    graph save "$graph\panel_right.gph", replace
restore

*2.3 Combine plots
graph combine ///
    "$graph\panel_left.gph" ///
    "$graph\panel_right.gph", ///
    col(2) ///
    imargin(2 2 2 2) ///
    graphregion(color(white))
graph export "$graph\incident_cases_and_number_cc_sets.emf", replace

/*******************************************************************
* 3: COMORBIDITIES 
********************************************************************/

* 3.0: initialize pooled collector files; each disorder section below
* appends its prevalence estimates (mean lb ub) and CORs
* (COR SE z p stars lb ub), tagged by block, for later range queries
clear
save "$data_work\prev_pooled.dta", replace emptyok
save "$data_work\cors_pooled.dta", replace emptyok

*3.1: Mental and behavioural disorders (ICD-10-GM: F00_F99_nopg)
use "$data_work\event_case_mc.dta", clear 
count if F00_F99_nopg == .
sort ever_gd t_event
statsby mean = (100 * r(proportion)) lb = (100 * r(lb)) ub = (100 * r(ub)), ///
	by(ever_gd t_event) clear: ///
	ci proportions F00_F99_nopg, level(95) agresti
format mean lb ub %5.2f
list ever_gd t_event mean lb ub, sepby(ever_gd)
preserve
	gen str16 block = "F00_F99_nopg"
	append using "$data_work\prev_pooled.dta"
	save "$data_work\prev_pooled.dta", replace
restore
use "$data_work\event_case_mc.dta", clear 
statsby ///
	COR_log = (_b[F00_F99_nopg]) ///
	SE_log  = (_se[F00_F99_nopg]) ///
	z       = (_b[F00_F99_nopg] / _se[F00_F99_nopg]) ///
	p       = (2*normal(-abs(_b[F00_F99_nopg] / _se[F00_F99_nopg]))) ///
	lb_log  = (_b[F00_F99_nopg] - invnormal(0.975)*_se[F00_F99_nopg]) ///
	ub_log  = (_b[F00_F99_nopg] + invnormal(0.975)*_se[F00_F99_nopg]) ///
	, by(t_event) clear: ///
	clogit ever_gd F00_F99_nopg, group(match_ID) vce(cluster match_ID) or
gen COR = exp(COR_log)
gen lb  = exp(lb_log)
gen ub  = exp(ub_log)
gen SE  = COR * SE_log
gen str3 stars = ""
replace stars = "*"   if p < 0.05
replace stars = "**"  if p < 0.01
replace stars = "***" if p < 0.001
label var stars "* p < 0.05; ** p < 0.01; *** p < 0.001"
keep t_event COR SE z p stars lb ub
sort t_event
format COR SE lb ub %6.2f
format z %6.2f
format p %6.4f
list t_event COR SE z p stars lb ub, sep(1) noobs
preserve
	gen str16 block = "F00_F99_nopg"
	append using "$data_work\cors_pooled.dta"
	save "$data_work\cors_pooled.dta", replace
restore
twoway ///
    (rcap lb ub t_event, lcolor(black) lwidth(thin)) ///
    (line COR t_event, lcolor(black) lwidth(thin) lpattern(solid)) ///
    (scatter COR t_event, msymbol(circle) mcolor(black) msize(small)) ///
    , ///
	title("{bf:Mental and behavioural disorders;}" ///
      "{bf:excluding Pathological gambling}", ///
      size(medsmall) position(11)) ///
    subtitle("ICD-10-GM: F00–F99; excluding F63.0", size(small) position(11)) ///
    xtitle("{bf:Relative time period}", size(small) margin(small)) ///
    ytitle("{bf:COR (95% CI)}", size(small) margin(zero)) ///
    xlabel(-5 "{it:t}{sub:-5}" -4 "{it:t}{sub:-4}" -3 "{it:t}{sub:-3}" -2 "{it:t}{sub:-2}" -1 "{it:t}{sub:-1}" 0 "{it:t}{sub:0}" 1 "{it:t}{sub:+1}" 2 "{it:t}{sub:+2}" 3 "{it:t}{sub:+3}" 4 "{it:t}{sub:+4}" 5 "{it:t}{sub:+5}", labsize(small)) ///
    ylabel(1 0(2)18, labsize(small) angle(horizontal) format(%4.0f)) ///
    yscale(range(0 18)) ///
    yline(1, lcolor(red) lpattern(shortdash)) ///
    yline(0(2)18, lcolor(gs14) lpattern(shortdash)) ///
    legend(off) ///
    graphregion(color(white) margin(0 0 0 0)) ///
    plotregion(margin(2 2 2 2)) plotregion(lstyle(none)) ///
    scheme(s1mono)
graph save "$graph/g1.gph", replace
** IF YOU WANT TO DO IT WITH FULL OUTPUT USE THIS COMMAND: 
* --> Results are exactly the same 
* if option r or vce(cluster match_ID) for se does not matter, always applies robust clustered se conditional 
* on matching var. 
use "$data_work\event_case_mc.dta", clear 
bysort t_event: clogit ever_gd F00_F99_nopg, group(match_ID) vce(cluster match_ID) or  

*3.2: Mental and behavioural disorders due to psychoactive substance use (ICD-10-GM: F10-F19)
use "$data_work\event_case_mc.dta", clear
count if F10_F19 == .
sort ever_gd t_event
statsby mean = (100 * r(proportion)) lb = (100 * r(lb)) ub = (100 * r(ub)), ///
    by(ever_gd t_event) clear: ///
    ci proportions F10_F19, level(95) agresti
format mean lb ub %5.2f
list ever_gd t_event mean lb ub, sepby(ever_gd)
preserve
	gen str16 block = "F10_F19"
	append using "$data_work\prev_pooled.dta"
	save "$data_work\prev_pooled.dta", replace
restore
use "$data_work\event_case_mc.dta", clear 
statsby ///
	COR_log = (_b[F10_F19]) ///
	SE_log  = (_se[F10_F19]) ///
	z       = (_b[F10_F19] / _se[F10_F19]) ///
	p       = (2*normal(-abs(_b[F10_F19] / _se[F10_F19]))) ///
	lb_log  = (_b[F10_F19] - invnormal(0.975)*_se[F10_F19]) ///
	ub_log  = (_b[F10_F19] + invnormal(0.975)*_se[F10_F19]) ///
	, by(t_event) clear: ///
	clogit ever_gd F10_F19, group(match_ID) vce(cluster match_ID)
gen COR = exp(COR_log)
gen lb  = exp(lb_log)
gen ub  = exp(ub_log)
gen SE  = COR * SE_log
gen str3 stars = ""
replace stars = "*"   if p < 0.05
replace stars = "**"  if p < 0.01
replace stars = "***" if p < 0.001
label var stars "* p < 0.05; ** p < 0.01; *** p < 0.001"
keep t_event COR SE z p stars lb ub
sort t_event
format COR SE lb ub z %6.2f
format p %6.4f
list t_event COR SE z p stars lb ub, sep(1) noobs
preserve
	gen str16 block = "F10_F19"
	append using "$data_work\cors_pooled.dta"
	save "$data_work\cors_pooled.dta", replace
restore
twoway ///
    (rcap lb ub t_event, lcolor(black) lwidth(thin)) ///
    (line COR t_event, lcolor(black) lwidth(thin) lpattern(solid)) ///
    (scatter COR t_event, msymbol(circle) mcolor(black) msize(small)) ///
    , ///
	title("{bf:Mental and behavioural disorders due to}" ///
      "{bf:psychoactive substance use}", ///
      size(medsmall) position(11)) ///
    subtitle("ICD-10-GM: F10–F19", size(small) position(11)) ///
    xtitle("{bf:Relative time period}", size(small) margin(small)) ///
    ytitle("{bf:COR (95% CI)}", size(small) margin(zero)) ///
    xlabel(-5 "{it:t}{sub:-5}" -4 "{it:t}{sub:-4}" -3 "{it:t}{sub:-3}" -2 "{it:t}{sub:-2}" -1 "{it:t}{sub:-1}" 0 "{it:t}{sub:0}" 1 "{it:t}{sub:+1}" 2 "{it:t}{sub:+2}" 3 "{it:t}{sub:+3}" 4 "{it:t}{sub:+4}" 5 "{it:t}{sub:+5}", labsize(small)) ///
    ylabel(1 0(2)18, labsize(small) angle(horizontal) format(%4.0f)) ///
    yscale(range(0 18)) ///
    yline(1, lcolor(red) lpattern(shortdash)) ///
    yline(0(2)18, lcolor(gs14) lpattern(shortdash)) ///
    legend(off) ///
    graphregion(color(white) margin(0 0 0 0)) ///
    plotregion(margin(2 2 2 2)) plotregion(lstyle(none)) ///
    scheme(s1mono)
graph save "$graph/g2.gph", replace

* 3.3: Mental and behavioural disorders due to use of alcohol (ICD-10-GM: F10)
use "$data_work\event_case_mc.dta", clear
count if F10 == .
sort ever_gd t_event
statsby mean = (100 * r(proportion)) lb = (100 * r(lb)) ub = (100 * r(ub)), ///
    by(ever_gd t_event) clear: ///
    ci proportions F10, level(95) agresti
format mean lb ub %5.2f
list ever_gd t_event mean lb ub, sepby(ever_gd)
preserve
	gen str16 block = "F10"
	append using "$data_work\prev_pooled.dta"
	save "$data_work\prev_pooled.dta", replace
restore
use "$data_work\event_case_mc.dta", clear 
statsby ///
	COR_log = (_b[F10]) ///
	SE_log  = (_se[F10]) ///
	z       = (_b[F10] / _se[F10]) ///
	p       = (2*normal(-abs(_b[F10] / _se[F10]))) ///
	lb_log  = (_b[F10] - invnormal(0.975)*_se[F10]) ///
	ub_log  = (_b[F10] + invnormal(0.975)*_se[F10]) ///
	, by(t_event) clear: ///
	clogit ever_gd F10, group(match_ID) vce(cluster match_ID)
gen COR = exp(COR_log)
gen lb  = exp(lb_log)
gen ub  = exp(ub_log)
gen SE  = COR * SE_log
gen str3 stars = ""
replace stars = "*"   if p < 0.05
replace stars = "**"  if p < 0.01
replace stars = "***" if p < 0.001
label var stars "* p < 0.05; ** p < 0.01; *** p < 0.001"
keep t_event COR SE z p stars lb ub
sort t_event
format COR SE lb ub z %6.2f
format p %6.4f
list t_event COR SE z p stars lb ub, sep(1) noobs
preserve
	gen str16 block = "F10"
	append using "$data_work\cors_pooled.dta"
	save "$data_work\cors_pooled.dta", replace
restore
twoway ///
    (rcap lb ub t_event, lcolor(black) lwidth(thin)) ///
    (line COR t_event, lcolor(black) lwidth(thin) lpattern(solid)) ///
    (scatter COR t_event, msymbol(circle) mcolor(black) msize(small)) ///
    , ///
    title("{bf:Mental and behavioural disorders due to use of alcohol}", ///
      size(medsmall) position(11)) ///
    subtitle("ICD-10-GM: F10", size(small) position(11)) ///
    xtitle("{bf:Relative time period}", size(small) margin(small)) ///
    ytitle("{bf:COR (95% CI)}", size(small) margin(zero)) ///
    xlabel(-5 "{it:t}{sub:-5}" -4 "{it:t}{sub:-4}" -3 "{it:t}{sub:-3}" -2 "{it:t}{sub:-2}" -1 "{it:t}{sub:-1}" 0 "{it:t}{sub:0}" 1 "{it:t}{sub:+1}" 2 "{it:t}{sub:+2}" 3 "{it:t}{sub:+3}" 4 "{it:t}{sub:+4}" 5 "{it:t}{sub:+5}", labsize(small)) ///
    ylabel(1 0(2)18, labsize(small) angle(horizontal) format(%4.0f)) ///
    yscale(range(0 18)) ///
    yline(1, lcolor(red) lpattern(shortdash)) ///
    yline(0(2)18, lcolor(gs14) lpattern(shortdash)) ///
    legend(off) ///
    graphregion(color(white) margin(0 0 0 0)) ///
    plotregion(margin(2 2 2 2)) plotregion(lstyle(none)) ///
    scheme(s1mono)
graph save "$graph/g3.gph", replace

* 3.4: Mental and behavioural disorders due to use of tobacco (ICD-10-GM: F17)
use "$data_work\event_case_mc.dta", clear 
sort ever_gd t_event
count if F17 == .
statsby mean = (100 * r(proportion)) lb = (100 * r(lb)) ub = (100 * r(ub)), ///
    by(ever_gd t_event) clear: ///
    ci proportions F17, level(95) agresti
format mean lb ub %5.2f
list ever_gd t_event mean lb ub, sepby(ever_gd)
preserve
	gen str16 block = "F17"
	append using "$data_work\prev_pooled.dta"
	save "$data_work\prev_pooled.dta", replace
restore
use "$data_work\event_case_mc.dta", clear 
statsby ///
	COR_log = (_b[F17]) ///
	SE_log  = (_se[F17]) ///
	z       = (_b[F17] / _se[F17]) ///
	p       = (2*normal(-abs(_b[F17] / _se[F17]))) ///
	lb_log  = (_b[F17] - invnormal(0.975)*_se[F17]) ///
	ub_log  = (_b[F17] + invnormal(0.975)*_se[F17]) ///
	, by(t_event) clear: ///
	clogit ever_gd F17, group(match_ID) vce(cluster match_ID)
gen COR = exp(COR_log)
gen lb  = exp(lb_log)
gen ub  = exp(ub_log)
gen SE  = COR * SE_log
gen str3 stars = ""
replace stars = "*"   if p < 0.05
replace stars = "**"  if p < 0.01
replace stars = "***" if p < 0.001
label var stars "* p < 0.05; ** p < 0.01; *** p < 0.001"
keep t_event COR SE z p stars lb ub
sort t_event
format COR SE lb ub z %6.2f
format p %6.4f
list t_event COR SE z p stars lb ub, sep(1) noobs
preserve
	gen str16 block = "F17"
	append using "$data_work\cors_pooled.dta"
	save "$data_work\cors_pooled.dta", replace
restore
twoway ///
    (rcap lb ub t_event, lcolor(black) lwidth(thin)) ///
    (line COR t_event, lcolor(black) lwidth(thin) lpattern(solid)) ///
    (scatter COR t_event, msymbol(circle) mcolor(black) msize(small)) ///
    , ///
    title("{bf:Mental and behavioural disorders due to use of tobacco}", ///
      size(medsmall) position(11)) ///
    subtitle("ICD-10-GM: F17", size(small) position(11)) ///
    xtitle("{bf:Relative time period}", size(small) margin(small)) ///
    ytitle("{bf:COR (95% CI)}", size(small) margin(zero)) ///
    xlabel(-5 "{it:t}{sub:-5}" -4 "{it:t}{sub:-4}" -3 "{it:t}{sub:-3}" -2 "{it:t}{sub:-2}" -1 "{it:t}{sub:-1}" 0 "{it:t}{sub:0}" 1 "{it:t}{sub:+1}" 2 "{it:t}{sub:+2}" 3 "{it:t}{sub:+3}" 4 "{it:t}{sub:+4}" 5 "{it:t}{sub:+5}", labsize(small)) ///
    ylabel(1 0(2)18, labsize(small) angle(horizontal) format(%4.0f)) ///
    yscale(range(0 18)) ///
    yline(1, lcolor(red) lpattern(shortdash)) ///
    yline(0(2)18, lcolor(gs14) lpattern(shortdash)) ///
    legend(off) ///
    graphregion(color(white) margin(0 0 0 0)) ///
    plotregion(margin(2 2 2 2)) plotregion(lstyle(none)) ///
    scheme(s1mono)
graph save "$graph/g4.gph", replace

* 3.5: Mental and behavioural disorders due to use of other psychoactive substances (ICD-10-GM: F11–F16, F18–F19)
use "$data_work\event_case_mc.dta", clear 
count if other_psych == .
sort ever_gd t_event
statsby mean = (100 * r(proportion)) lb = (100 * r(lb)) ub = (100 * r(ub)), ///
    by(ever_gd t_event) clear: ///
    ci proportions other_psych, level(95) agresti
format mean lb ub %5.2f
list ever_gd t_event mean lb ub, sepby(ever_gd)
preserve
	gen str16 block = "other_psych"
	append using "$data_work\prev_pooled.dta"
	save "$data_work\prev_pooled.dta", replace
restore
use "$data_work\event_case_mc.dta", clear 
statsby ///
	COR_log = (_b[other_psych]) ///
	SE_log  = (_se[other_psych]) ///
	z       = (_b[other_psych] / _se[other_psych]) ///
	p       = (2*normal(-abs(_b[other_psych] / _se[other_psych]))) ///
	lb_log  = (_b[other_psych] - invnormal(0.975)*_se[other_psych]) ///
	ub_log  = (_b[other_psych] + invnormal(0.975)*_se[other_psych]) ///
	, by(t_event) clear: ///
	clogit ever_gd other_psych, group(match_ID) vce(cluster match_ID)
gen COR = exp(COR_log)
gen lb  = exp(lb_log)
gen ub  = exp(ub_log)
gen SE  = COR * SE_log
gen str3 stars = ""
replace stars = "*"   if p < 0.05
replace stars = "**"  if p < 0.01
replace stars = "***" if p < 0.001
label var stars "* p < 0.05; ** p < 0.01; *** p < 0.001"
keep t_event COR SE z p stars lb ub
sort t_event
format COR SE lb ub z %6.2f
format p %6.4f
list t_event COR SE z p stars lb ub, sep(1) noobs
preserve
	gen str16 block = "other_psych"
	append using "$data_work\cors_pooled.dta"
	save "$data_work\cors_pooled.dta", replace
restore
twoway ///
    (rcap lb ub t_event, lcolor(black) lwidth(thin)) ///
    (line COR t_event, lcolor(black) lwidth(thin) lpattern(solid)) ///
    (scatter COR t_event, msymbol(circle) mcolor(black) msize(small)) ///
    , ///
    title("{bf:Mental and behavioural disorders due to use of}" ///
      "{bf:other psychoactive substances}", ///
      size(medsmall) position(11)) ///
    subtitle("ICD-10-GM: F11–F16, F18–F19", size(small) position(11)) ///
    xtitle("{bf:Relative time period}", size(small) margin(small)) ///
    ytitle("{bf:COR (95% CI)}", size(small) margin(zero)) ///
    xlabel(-5 "{it:t}{sub:-5}" -4 "{it:t}{sub:-4}" -3 "{it:t}{sub:-3}" -2 "{it:t}{sub:-2}" -1 "{it:t}{sub:-1}" 0 "{it:t}{sub:0}" 1 "{it:t}{sub:+1}" 2 "{it:t}{sub:+2}" 3 "{it:t}{sub:+3}" 4 "{it:t}{sub:+4}" 5 "{it:t}{sub:+5}", labsize(small)) ///
    ylabel(1 0(2)18, labsize(small) angle(horizontal) format(%4.0f)) ///
    yscale(range(0 18)) ///
    yline(1, lcolor(red) lpattern(shortdash)) ///
    yline(0(2)18, lcolor(gs14) lpattern(shortdash)) ///
    legend(off) ///
    graphregion(color(white) margin(0 0 0 0)) ///
    plotregion(margin(2 2 2 2)) plotregion(lstyle(none)) ///
    scheme(s1mono)
graph save "$graph/g5.gph", replace

* 3.6: Mood [affective] disorders (ICD-10-GM: F30-F39)
use "$data_work\event_case_mc.dta", clear
count if F30_F39 == .
sort ever_gd t_event
statsby mean = (100 * r(proportion)) lb = (100 * r(lb)) ub = (100 * r(ub)), ///
    by(ever_gd t_event) clear: ///
    ci proportions F30_F39, level(95) agresti
format mean lb ub %5.2f
list ever_gd t_event mean lb ub, sepby(ever_gd)
preserve
	gen str16 block = "F30_F39"
	append using "$data_work\prev_pooled.dta"
	save "$data_work\prev_pooled.dta", replace
restore
use "$data_work\event_case_mc.dta", clear 
statsby ///
	COR_log = (_b[F30_F39]) ///
	SE_log  = (_se[F30_F39]) ///
	z       = (_b[F30_F39] / _se[F30_F39]) ///
	p       = (2*normal(-abs(_b[F30_F39] / _se[F30_F39]))) ///
	lb_log  = (_b[F30_F39] - invnormal(0.975)*_se[F30_F39]) ///
	ub_log  = (_b[F30_F39] + invnormal(0.975)*_se[F30_F39]) ///
	, by(t_event) clear: ///
	clogit ever_gd F30_F39, group(match_ID) vce(cluster match_ID)
gen COR = exp(COR_log)
gen lb  = exp(lb_log)
gen ub  = exp(ub_log)
gen SE  = COR * SE_log
gen str3 stars = ""
replace stars = "*"   if p < 0.05
replace stars = "**"  if p < 0.01
replace stars = "***" if p < 0.001
label var stars "* p < 0.05; ** p < 0.01; *** p < 0.001"
keep t_event COR SE z p stars lb ub
sort t_event
format COR SE lb ub z %6.2f
format p %6.4f
list t_event COR SE z p stars lb ub, sep(1) noobs
preserve
	gen str16 block = "F30_F39"
	append using "$data_work\cors_pooled.dta"
	save "$data_work\cors_pooled.dta", replace
restore
twoway ///
    (rcap lb ub t_event, lcolor(black) lwidth(thin)) ///
    (line COR t_event, lcolor(black) lwidth(thin) lpattern(solid)) ///
    (scatter COR t_event, msymbol(circle) mcolor(black) msize(small)) ///
    , ///
    title("{bf:}" ///
      "{bf:Mood [affective] disorders}", ///
      size(medsmall) position(11)) ///
    subtitle("ICD-10-GM: F30–F39", size(small) position(11)) ///
    xtitle("{bf:Relative time period}", size(small) margin(small)) ///
    ytitle("{bf:COR (95% CI)}", size(small) margin(zero)) ///
    xlabel(-5 "{it:t}{sub:-5}" -4 "{it:t}{sub:-4}" -3 "{it:t}{sub:-3}" -2 "{it:t}{sub:-2}" -1 "{it:t}{sub:-1}" 0 "{it:t}{sub:0}" 1 "{it:t}{sub:+1}" 2 "{it:t}{sub:+2}" 3 "{it:t}{sub:+3}" 4 "{it:t}{sub:+4}" 5 "{it:t}{sub:+5}", labsize(small)) ///
    ylabel(1 0(2)18, labsize(small) angle(horizontal) format(%4.0f)) ///
    yscale(range(0 18)) ///
    yline(1, lcolor(red) lpattern(shortdash)) ///
    yline(0(2)18, lcolor(gs14) lpattern(shortdash)) ///
    legend(off) ///
    graphregion(color(white) margin(0 0 0 0)) ///
    plotregion(margin(2 2 2 2)) plotregion(lstyle(none)) ///
    scheme(s1mono)
graph save "$graph/g6.gph", replace

* 3.7: Depressive disorders (ICD-10-GM: F32-F33)
use "$data_work\event_case_mc.dta", clear 
count if F32_F33 == .
sort ever_gd t_event
statsby mean = (100 * r(proportion)) lb = (100 * r(lb)) ub = (100 * r(ub)), ///
    by(ever_gd t_event) clear: ///
    ci proportions F32_F33, level(95) agresti
format mean lb ub %5.2f
list ever_gd t_event mean lb ub, sepby(ever_gd)
preserve
	gen str16 block = "F32_F33"
	append using "$data_work\prev_pooled.dta"
	save "$data_work\prev_pooled.dta", replace
restore
use "$data_work\event_case_mc.dta", clear 
statsby ///
	COR_log = (_b[F32_F33]) ///
	SE_log  = (_se[F32_F33]) ///
	z       = (_b[F32_F33] / _se[F32_F33]) ///
	p       = (2*normal(-abs(_b[F32_F33] / _se[F32_F33]))) ///
	lb_log  = (_b[F32_F33] - invnormal(0.975)*_se[F32_F33]) ///
	ub_log  = (_b[F32_F33] + invnormal(0.975)*_se[F32_F33]) ///
	, by(t_event) clear: ///
	clogit ever_gd F32_F33, group(match_ID) vce(cluster match_ID)
gen COR = exp(COR_log)
gen lb  = exp(lb_log)
gen ub  = exp(ub_log)
gen SE  = COR * SE_log
gen str3 stars = ""
replace stars = "*"   if p < 0.05
replace stars = "**"  if p < 0.01
replace stars = "***" if p < 0.001
label var stars "* p < 0.05; ** p < 0.01; *** p < 0.001"
keep t_event COR SE z p stars lb ub
sort t_event
format COR SE lb ub z %6.2f
format p %6.4f
list t_event COR SE z p stars lb ub, sep(1) noobs
preserve
	gen str16 block = "F32_F33"
	append using "$data_work\cors_pooled.dta"
	save "$data_work\cors_pooled.dta", replace
restore
twoway ///
    (rcap lb ub t_event, lcolor(black) lwidth(thin)) ///
    (line COR t_event, lcolor(black) lwidth(thin) lpattern(solid)) ///
    (scatter COR t_event, msymbol(circle) mcolor(black) msize(small)) ///
    , ///
    title("{bf:Depressive disorders}", ///
      size(medsmall) position(11)) ///
    subtitle("ICD-10-GM: F32–F33", size(small) position(11)) ///
    xtitle("{bf:Relative time period}", size(small) margin(small)) ///
    ytitle("{bf:COR (95% CI)}", size(small) margin(zero)) ///
    xlabel(-5 "{it:t}{sub:-5}" -4 "{it:t}{sub:-4}" -3 "{it:t}{sub:-3}" -2 "{it:t}{sub:-2}" -1 "{it:t}{sub:-1}" 0 "{it:t}{sub:0}" 1 "{it:t}{sub:+1}" 2 "{it:t}{sub:+2}" 3 "{it:t}{sub:+3}" 4 "{it:t}{sub:+4}" 5 "{it:t}{sub:+5}", labsize(small)) ///
    ylabel(1 0(2)18, labsize(small) angle(horizontal) format(%4.0f)) ///
    yscale(range(0 18)) ///
    yline(1, lcolor(red) lpattern(shortdash)) ///
    yline(0(2)18, lcolor(gs14) lpattern(shortdash)) ///
    legend(off) ///
    graphregion(color(white) margin(0 0 0 0)) ///
    plotregion(margin(2 2 2 2)) plotregion(lstyle(none)) ///
    scheme(s1mono)
graph save "$graph/g7.gph", replace

* 3.8: Neurotic, stress-related and somatoform disorders (ICD-10-GM: F40-F48)
use "$data_work\event_case_mc.dta", clear 
count if F40_F48 == .
sort ever_gd t_event
statsby mean = (100 * r(proportion)) lb = (100 * r(lb)) ub = (100 * r(ub)), ///
    by(ever_gd t_event) clear: ///
    ci proportions F40_F48, level(95) agresti
format mean lb ub %5.2f
list ever_gd t_event mean lb ub, sepby(ever_gd)
preserve
	gen str16 block = "F40_F48"
	append using "$data_work\prev_pooled.dta"
	save "$data_work\prev_pooled.dta", replace
restore
use "$data_work\event_case_mc.dta", clear 
statsby ///
	COR_log = (_b[F40_F48]) ///
	SE_log  = (_se[F40_F48]) ///
	z       = (_b[F40_F48] / _se[F40_F48]) ///
	p       = (2*normal(-abs(_b[F40_F48] / _se[F40_F48]))) ///
	lb_log  = (_b[F40_F48] - invnormal(0.975)*_se[F40_F48]) ///
	ub_log  = (_b[F40_F48] + invnormal(0.975)*_se[F40_F48]) ///
	, by(t_event) clear: ///
	clogit ever_gd F40_F48, group(match_ID) vce(cluster match_ID)
gen COR = exp(COR_log)
gen lb  = exp(lb_log)
gen ub  = exp(ub_log)
gen SE  = COR * SE_log
gen str3 stars = ""
replace stars = "*"   if p < 0.05
replace stars = "**"  if p < 0.01
replace stars = "***" if p < 0.001
label var stars "* p < 0.05; ** p < 0.01; *** p < 0.001"
keep t_event COR SE z p stars lb ub
sort t_event
format COR SE lb ub z %6.2f
format p %6.4f
list t_event COR SE z p stars lb ub, sep(1) noobs
preserve
	gen str16 block = "F40_F48"
	append using "$data_work\cors_pooled.dta"
	save "$data_work\cors_pooled.dta", replace
restore
twoway ///
    (rcap lb ub t_event, lcolor(black) lwidth(thin)) ///
    (line COR t_event, lcolor(black) lwidth(thin) lpattern(solid)) ///
    (scatter COR t_event, msymbol(circle) mcolor(black) msize(small)) ///
    , ///
    title("{bf:Neurotic, stress-related and somatoform disorders}", ///
      size(medsmall) position(11)) ///
    subtitle("ICD-10-GM: F40–F48", size(small) position(11)) ///
    xtitle("{bf:Relative time period}", size(small) margin(small)) ///
    ytitle("{bf:COR (95% CI)}", size(small) margin(zero)) ///
    xlabel(-5 "{it:t}{sub:-5}" -4 "{it:t}{sub:-4}" -3 "{it:t}{sub:-3}" -2 "{it:t}{sub:-2}" -1 "{it:t}{sub:-1}" 0 "{it:t}{sub:0}" 1 "{it:t}{sub:+1}" 2 "{it:t}{sub:+2}" 3 "{it:t}{sub:+3}" 4 "{it:t}{sub:+4}" 5 "{it:t}{sub:+5}", labsize(small)) ///
    ylabel(1 0(2)18, labsize(small) angle(horizontal) format(%4.0f)) ///
    yscale(range(0 18)) ///
    yline(1, lcolor(red) lpattern(shortdash)) ///
    yline(0(2)18, lcolor(gs14) lpattern(shortdash)) ///
    legend(off) ///
    graphregion(color(white) margin(0 0 0 0)) ///
    plotregion(margin(2 2 2 2)) plotregion(lstyle(none)) ///
    scheme(s1mono)
graph save "$graph/g8.gph", replace

* 3.9: Phobic Anxiety Disorders (ICD-10-GM: F40)
use "$data_work\event_case_mc.dta", clear
count if F40 == .
sort ever_gd t_event
statsby mean = (100 * r(proportion)) lb = (100 * r(lb)) ub = (100 * r(ub)), ///
    by(ever_gd t_event) clear: ///
    ci proportions F40, level(95) agresti
format mean lb ub %5.2f
list ever_gd t_event mean lb ub, sepby(ever_gd)
preserve
	gen str16 block = "F40"
	append using "$data_work\prev_pooled.dta"
	save "$data_work\prev_pooled.dta", replace
restore
use "$data_work\event_case_mc.dta", clear 
statsby ///
	COR_log = (_b[F40]) ///
	SE_log  = (_se[F40]) ///
	z       = (_b[F40] / _se[F40]) ///
	p       = (2*normal(-abs(_b[F40] / _se[F40]))) ///
	lb_log  = (_b[F40] - invnormal(0.975)*_se[F40]) ///
	ub_log  = (_b[F40] + invnormal(0.975)*_se[F40]) ///
	, by(t_event) clear: ///
	clogit ever_gd F40, group(match_ID) vce(cluster match_ID)
gen COR = exp(COR_log)
gen lb  = exp(lb_log)
gen ub  = exp(ub_log)
gen SE  = COR * SE_log
gen str3 stars = ""
replace stars = "*"   if p < 0.05
replace stars = "**"  if p < 0.01
replace stars = "***" if p < 0.001
label var stars "* p < 0.05; ** p < 0.01; *** p < 0.001"
keep t_event COR SE z p stars lb ub
sort t_event
format COR SE lb ub z %6.2f
format p %6.4f
list t_event COR SE z p stars lb ub, sep(1) noobs
preserve
	gen str16 block = "F40"
	append using "$data_work\cors_pooled.dta"
	save "$data_work\cors_pooled.dta", replace
restore
twoway ///
    (rcap lb ub t_event, lcolor(black) lwidth(thin)) ///
    (line COR t_event, lcolor(black) lwidth(thin) lpattern(solid)) ///
    (scatter COR t_event, msymbol(circle) mcolor(black) msize(small)) ///
    , ///
    title("{bf:Phobic anxiety disorders}", ///
      size(medsmall) position(11)) ///
    subtitle("ICD-10-GM: F40", size(small) position(11)) ///
    xtitle("{bf:Relative time period}", size(small) margin(small)) ///
    ytitle("{bf:COR (95% CI)}", size(small) margin(zero)) ///
    xlabel(-5 "{it:t}{sub:-5}" -4 "{it:t}{sub:-4}" -3 "{it:t}{sub:-3}" -2 "{it:t}{sub:-2}" -1 "{it:t}{sub:-1}" 0 "{it:t}{sub:0}" 1 "{it:t}{sub:+1}" 2 "{it:t}{sub:+2}" 3 "{it:t}{sub:+3}" 4 "{it:t}{sub:+4}" 5 "{it:t}{sub:+5}", labsize(small)) ///
    ylabel(1 0(2)18, labsize(small) angle(horizontal) format(%4.0f)) ///
    yscale(range(0 18)) ///
    yline(1, lcolor(red) lpattern(shortdash)) ///
    yline(0(2)18, lcolor(gs14) lpattern(shortdash)) ///
    legend(off) ///
    graphregion(color(white) margin(0 0 0 0)) ///
    plotregion(margin(2 2 2 2)) plotregion(lstyle(none)) ///
    scheme(s1mono)
graph save "$graph/g9.gph", replace

* 3.10: Other anxiety disorders (ICD-10-GM: F41)
use "$data_work\event_case_mc.dta", clear
count if F41 == .
sort ever_gd t_event
statsby mean = (100 * r(proportion)) lb = (100 * r(lb)) ub = (100 * r(ub)), ///
    by(ever_gd t_event) clear: ///
    ci proportions F41, level(95) agresti
format mean lb ub %5.2f
list ever_gd t_event mean lb ub, sepby(ever_gd)
preserve
	gen str16 block = "F41"
	append using "$data_work\prev_pooled.dta"
	save "$data_work\prev_pooled.dta", replace
restore
use "$data_work\event_case_mc.dta", clear 
statsby ///
	COR_log = (_b[F41]) ///
	SE_log  = (_se[F41]) ///
	z       = (_b[F41] / _se[F41]) ///
	p       = (2*normal(-abs(_b[F41] / _se[F41]))) ///
	lb_log  = (_b[F41] - invnormal(0.975)*_se[F41]) ///
	ub_log  = (_b[F41] + invnormal(0.975)*_se[F41]) ///
	, by(t_event) clear: ///
	clogit ever_gd F41, group(match_ID) vce(cluster match_ID)
gen COR = exp(COR_log)
gen lb  = exp(lb_log)
gen ub  = exp(ub_log)
gen SE  = COR * SE_log
gen str3 stars = ""
replace stars = "*"   if p < 0.05
replace stars = "**"  if p < 0.01
replace stars = "***" if p < 0.001
label var stars "* p < 0.05; ** p < 0.01; *** p < 0.001"
keep t_event COR SE z p stars lb ub
sort t_event
format COR SE lb ub z %6.2f
format p %6.4f
list t_event COR SE z p stars lb ub, sep(1) noobs
preserve
	gen str16 block = "F41"
	append using "$data_work\cors_pooled.dta"
	save "$data_work\cors_pooled.dta", replace
restore
twoway ///
    (rcap lb ub t_event, lcolor(black) lwidth(thin)) ///
    (line COR t_event, lcolor(black) lwidth(thin) lpattern(solid)) ///
    (scatter COR t_event, msymbol(circle) mcolor(black) msize(small)) ///
    , ///
    title("{bf:Other anxiety disorders}", ///
      size(medsmall) position(11)) ///
    subtitle("ICD-10-GM: F41", size(small) position(11)) ///
    xtitle("{bf:Relative time period}", size(small) margin(small)) ///
    ytitle("{bf:COR (95% CI)}", size(small) margin(zero)) ///
    xlabel(-5 "{it:t}{sub:-5}" -4 "{it:t}{sub:-4}" -3 "{it:t}{sub:-3}" -2 "{it:t}{sub:-2}" -1 "{it:t}{sub:-1}" 0 "{it:t}{sub:0}" 1 "{it:t}{sub:+1}" 2 "{it:t}{sub:+2}" 3 "{it:t}{sub:+3}" 4 "{it:t}{sub:+4}" 5 "{it:t}{sub:+5}", labsize(small)) ///
    ylabel(1 0(2)18, labsize(small) angle(horizontal) format(%4.0f)) ///
    yscale(range(0 18)) ///
    yline(1, lcolor(red) lpattern(shortdash)) ///
    yline(0(2)18, lcolor(gs14) lpattern(shortdash)) ///
    legend(off) ///
    graphregion(color(white) margin(0 0 0 0)) ///
    plotregion(margin(2 2 2 2)) plotregion(lstyle(none)) ///
    scheme(s1mono)
graph save "$graph/g10.gph", replace

*3.11: Obsessive-compulsive disorder (ICD-10-GM: F42)
use "$data_work\event_case_mc.dta", clear
count if F42 == .
sort ever_gd t_event
statsby mean = (100 * r(proportion)) lb = (100 * r(lb)) ub = (100 * r(ub)), ///
    by(ever_gd t_event) clear: ///
    ci proportions F42, level(95) agresti
format mean lb ub %5.2f
list ever_gd t_event mean lb ub, sepby(ever_gd)
preserve
	gen str16 block = "F42"
	append using "$data_work\prev_pooled.dta"
	save "$data_work\prev_pooled.dta", replace
restore
use "$data_work\event_case_mc.dta", clear 
statsby ///
	COR_log = (_b[F42]) ///
	SE_log  = (_se[F42]) ///
	z       = (_b[F42] / _se[F42]) ///
	p       = (2*normal(-abs(_b[F42] / _se[F42]))) ///
	lb_log  = (_b[F42] - invnormal(0.975)*_se[F42]) ///
	ub_log  = (_b[F42] + invnormal(0.975)*_se[F42]) ///
	, by(t_event) clear: ///
	clogit ever_gd F42, group(match_ID) vce(cluster match_ID)
gen COR = exp(COR_log)
gen lb  = exp(lb_log)
gen ub  = exp(ub_log)
gen SE  = COR * SE_log
gen str3 stars = ""
replace stars = "*"   if p < 0.05
replace stars = "**"  if p < 0.01
replace stars = "***" if p < 0.001
label var stars "* p < 0.05; ** p < 0.01; *** p < 0.001"
keep t_event COR SE z p stars lb ub
sort t_event
format COR SE lb ub z %6.2f
format p %6.4f
list t_event COR SE z p stars lb ub, sep(1) noobs
preserve
	gen str16 block = "F42"
	append using "$data_work\cors_pooled.dta"
	save "$data_work\cors_pooled.dta", replace
restore
twoway ///
    (rcap lb ub t_event, lcolor(black) lwidth(thin)) ///
    (line COR t_event, lcolor(black) lwidth(thin) lpattern(solid)) ///
    (scatter COR t_event, msymbol(circle) mcolor(black) msize(small)) ///
    , ///
    title("{bf:Obsessive-compulsive disorder}", ///
      size(medsmall) position(11)) ///
    subtitle("ICD-10-GM: F42", size(small) position(11)) ///
    xtitle("{bf:Relative time period}", size(small) margin(small)) ///
    ytitle("{bf:COR (95% CI)}", size(small) margin(zero)) ///
    xlabel(-5 "{it:t}{sub:-5}" -4 "{it:t}{sub:-4}" -3 "{it:t}{sub:-3}" -2 "{it:t}{sub:-2}" -1 "{it:t}{sub:-1}" 0 "{it:t}{sub:0}" 1 "{it:t}{sub:+1}" 2 "{it:t}{sub:+2}" 3 "{it:t}{sub:+3}" 4 "{it:t}{sub:+4}" 5 "{it:t}{sub:+5}", labsize(small)) ///
    ylabel(1 0(2)18, labsize(small) angle(horizontal) format(%4.0f)) ///
    yscale(range(0 18)) ///
    yline(1, lcolor(red) lpattern(shortdash)) ///
    yline(0(2)18, lcolor(gs14) lpattern(shortdash)) ///
    legend(off) ///
    graphregion(color(white) margin(0 0 0 0)) ///
    plotregion(margin(2 2 2 2)) plotregion(lstyle(none)) ///
    scheme(s1mono)
graph save "$graph/g11.gph", replace

*3.12: Reaction to severe stress, and adjustment disorders (ICD-10-GM: F43)
use "$data_work\event_case_mc.dta", clear
count if F43 == .
sort ever_gd t_event
statsby mean = (100 * r(proportion)) lb = (100 * r(lb)) ub = (100 * r(ub)), ///
    by(ever_gd t_event) clear: ///
    ci proportions F43, level(95) agresti
format mean lb ub %5.2f
list ever_gd t_event mean lb ub, sepby(ever_gd)
preserve
	gen str16 block = "F43"
	append using "$data_work\prev_pooled.dta"
	save "$data_work\prev_pooled.dta", replace
restore
use "$data_work\event_case_mc.dta", clear 
statsby ///
	COR_log = (_b[F43]) ///
	SE_log  = (_se[F43]) ///
	z       = (_b[F43] / _se[F43]) ///
	p       = (2*normal(-abs(_b[F43] / _se[F43]))) ///
	lb_log  = (_b[F43] - invnormal(0.975)*_se[F43]) ///
	ub_log  = (_b[F43] + invnormal(0.975)*_se[F43]) ///
	, by(t_event) clear: ///
	clogit ever_gd F43, group(match_ID) vce(cluster match_ID)
gen COR = exp(COR_log)
gen lb  = exp(lb_log)
gen ub  = exp(ub_log)
gen SE  = COR * SE_log
gen str3 stars = ""
replace stars = "*"   if p < 0.05
replace stars = "**"  if p < 0.01
replace stars = "***" if p < 0.001
label var stars "* p < 0.05; ** p < 0.01; *** p < 0.001"
keep t_event COR SE z p stars lb ub
sort t_event
format COR SE lb ub z %6.2f
format p %6.4f
list t_event COR SE z p stars lb ub, sep(1) noobs
preserve
	gen str16 block = "F43"
	append using "$data_work\cors_pooled.dta"
	save "$data_work\cors_pooled.dta", replace
restore
twoway ///
    (rcap lb ub t_event, lcolor(black) lwidth(thin)) ///
    (line COR t_event, lcolor(black) lwidth(thin) lpattern(solid)) ///
    (scatter COR t_event, msymbol(circle) mcolor(black) msize(small)) ///
    , ///
    title("{bf:Reaction to severe stress, and adjustment disorders}", ///
      size(medsmall) position(11)) ///
    subtitle("ICD-10-GM: F43", size(small) position(11)) ///
    xtitle("{bf:Relative time period}", size(small) margin(small)) ///
    ytitle("{bf:COR (95% CI)}", size(small) margin(zero)) ///
    xlabel(-5 "{it:t}{sub:-5}" -4 "{it:t}{sub:-4}" -3 "{it:t}{sub:-3}" -2 "{it:t}{sub:-2}" -1 "{it:t}{sub:-1}" 0 "{it:t}{sub:0}" 1 "{it:t}{sub:+1}" 2 "{it:t}{sub:+2}" 3 "{it:t}{sub:+3}" 4 "{it:t}{sub:+4}" 5 "{it:t}{sub:+5}", labsize(small)) ///
    ylabel(1 0(2)18, labsize(small) angle(horizontal) format(%4.0f)) ///
    yscale(range(0 18)) ///
    yline(1, lcolor(red) lpattern(shortdash)) ///
    yline(0(2)18, lcolor(gs14) lpattern(shortdash)) ///
    legend(off) ///
    graphregion(color(white) margin(0 0 0 0)) ///
    plotregion(margin(2 2 2 2)) plotregion(lstyle(none)) ///
    scheme(s1mono)
graph save "$graph/g12.gph", replace


*3.13: Behavioural syndromes associated with physiological disturbances and physical factors (ICD-10-GM: F50_F59)
use "$data_work\event_case_mc.dta", clear
count if F50_F59 == .
sort ever_gd t_event
statsby mean = (100 * r(proportion)) lb = (100 * r(lb)) ub = (100 * r(ub)), ///
    by(ever_gd t_event) clear: ///
    ci proportions F50_F59, level(95) agresti
format mean lb ub %5.2f
list ever_gd t_event mean lb ub, sepby(ever_gd)
preserve
	gen str16 block = "F50_F59"
	append using "$data_work\prev_pooled.dta"
	save "$data_work\prev_pooled.dta", replace
restore
use "$data_work\event_case_mc.dta", clear
statsby ///
	COR_log = (_b[F50_F59]) ///
	SE_log  = (_se[F50_F59]) ///
	z       = (_b[F50_F59] / _se[F50_F59]) ///
	p       = (2*normal(-abs(_b[F50_F59] / _se[F50_F59]))) ///
	lb_log  = (_b[F50_F59] - invnormal(0.975)*_se[F50_F59]) ///
	ub_log  = (_b[F50_F59] + invnormal(0.975)*_se[F50_F59]) ///
	, by(t_event) clear: ///
	clogit ever_gd F50_F59, group(match_ID) vce(cluster match_ID)
gen COR = exp(COR_log)
gen lb  = exp(lb_log)
gen ub  = exp(ub_log)
gen SE  = COR * SE_log
gen str3 stars = ""
replace stars = "*"   if p < 0.05
replace stars = "**"  if p < 0.01
replace stars = "***" if p < 0.001
label var stars "* p < 0.05; ** p < 0.01; *** p < 0.001"
keep t_event COR SE z p stars lb ub
sort t_event
format COR SE lb ub z %6.2f
format p %6.4f
list t_event COR SE z p stars lb ub, sep(1) noobs
preserve
	gen str16 block = "F50_F59"
	append using "$data_work\cors_pooled.dta"
	save "$data_work\cors_pooled.dta", replace
restore
twoway ///
    (rcap lb ub t_event, lcolor(black) lwidth(thin)) ///
    (line COR t_event, lcolor(black) lwidth(thin) lpattern(solid)) ///
    (scatter COR t_event, msymbol(circle) mcolor(black) msize(small)) ///
    , ///
	title("{bf:Behavioural syndromes associated with}" ///
      "{bf:physiological disturbances and physical factors}", ///
      size(medsmall) position(11)) ///
    subtitle("ICD-10-GM: F50–F59", size(small) position(11)) ///
    xtitle("{bf:Relative time period}", size(small) margin(small)) ///
    ytitle("{bf:COR (95% CI)}", size(small) margin(zero)) ///
    xlabel(-5 "{it:t}{sub:-5}" -4 "{it:t}{sub:-4}" -3 "{it:t}{sub:-3}" -2 "{it:t}{sub:-2}" -1 "{it:t}{sub:-1}" 0 "{it:t}{sub:0}" 1 "{it:t}{sub:+1}" 2 "{it:t}{sub:+2}" 3 "{it:t}{sub:+3}" 4 "{it:t}{sub:+4}" 5 "{it:t}{sub:+5}", labsize(small)) ///
    ylabel(1 0(2)18, labsize(small) angle(horizontal) format(%4.0f)) ///
    yscale(range(0 18)) ///
    yline(1, lcolor(red) lpattern(shortdash)) ///
    yline(0(2)18, lcolor(gs14) lpattern(shortdash)) ///
    legend(off) ///
    graphregion(color(white) margin(0 0 0 0)) ///
    plotregion(margin(2 2 2 2)) plotregion(lstyle(none)) ///
    scheme(s1mono)
graph save "$graph/g13.gph", replace

*3.14: Disorders of adult personality and behaviour; excluding F63.0 (ICD-10-GM: F60-F69; excluding F63.0)
use "$data_work\event_case_mc.dta", clear
count if F60_F69_noPG == .
sort ever_gd t_event
statsby mean = (100 * r(proportion)) lb = (100 * r(lb)) ub = (100 * r(ub)), ///
    by(ever_gd t_event) clear: ///
    ci proportions F60_F69_noPG, level(95) agresti
format mean lb ub %5.2f
list ever_gd t_event mean lb ub, sepby(ever_gd)
preserve
	gen str16 block = "F60_F69_noPG"
	append using "$data_work\prev_pooled.dta"
	save "$data_work\prev_pooled.dta", replace
restore
use "$data_work\event_case_mc.dta", clear 
statsby ///
	COR_log = (_b[F60_F69_noPG]) ///
	SE_log  = (_se[F60_F69_noPG]) ///
	z       = (_b[F60_F69_noPG] / _se[F60_F69_noPG]) ///
	p       = (2*normal(-abs(_b[F60_F69_noPG] / _se[F60_F69_noPG]))) ///
	lb_log  = (_b[F60_F69_noPG] - invnormal(0.975)*_se[F60_F69_noPG]) ///
	ub_log  = (_b[F60_F69_noPG] + invnormal(0.975)*_se[F60_F69_noPG]) ///
	, by(t_event) clear: ///
	clogit ever_gd F60_F69_noPG, group(match_ID) vce(cluster match_ID)
gen COR = exp(COR_log)
gen lb  = exp(lb_log)
gen ub  = exp(ub_log)
gen SE  = COR * SE_log
gen str3 stars = ""
replace stars = "*"   if p < 0.05
replace stars = "**"  if p < 0.01
replace stars = "***" if p < 0.001
label var stars "* p < 0.05; ** p < 0.01; *** p < 0.001"
keep t_event COR SE z p stars lb ub
sort t_event
format COR SE lb ub z %6.2f
format p %6.4f
list t_event COR SE z p stars lb ub, sep(1) noobs
preserve
	gen str16 block = "F60_F69_noPG"
	append using "$data_work\cors_pooled.dta"
	save "$data_work\cors_pooled.dta", replace
restore
twoway ///
    (rcap lb ub t_event, lcolor(black) lwidth(thin)) ///
    (line COR t_event, lcolor(black) lwidth(thin) lpattern(solid)) ///
    (scatter COR t_event, msymbol(circle) mcolor(black) msize(small)) ///
    , ///
	title("{bf:Disorders of adult personality and behaviour;  }" ///
      "{bf:excluding Pathological gambling}", ///
      size(medsmall) position(11)) ///
    subtitle("ICD-10-GM: F60-F69; excluding F63.0", size(small) position(11)) ///
    xtitle("{bf:Relative time period}", size(small) margin(small)) ///
    ytitle("{bf:COR (95% CI)}", size(small) margin(zero)) ///
    xlabel(-5 "{it:t}{sub:-5}" -4 "{it:t}{sub:-4}" -3 "{it:t}{sub:-3}" -2 "{it:t}{sub:-2}" -1 "{it:t}{sub:-1}" 0 "{it:t}{sub:0}" 1 "{it:t}{sub:+1}" 2 "{it:t}{sub:+2}" 3 "{it:t}{sub:+3}" 4 "{it:t}{sub:+4}" 5 "{it:t}{sub:+5}", labsize(small)) ///
    ylabel(1 0(2)18, labsize(small) angle(horizontal) format(%4.0f)) ///
    yscale(range(0 18)) ///
    yline(1, lcolor(red) lpattern(shortdash)) ///
    yline(0(2)18, lcolor(gs14) lpattern(shortdash)) ///
    legend(off) ///
    graphregion(color(white) margin(0 0 0 0)) ///
    plotregion(margin(2 2 2 2)) plotregion(lstyle(none)) ///
    scheme(s1mono)
graph save "$graph/g14.gph", replace

*3.15: Unspecified mental disorder (ICD-10-GM: F99)
use "$data_work\event_case_mc.dta", clear
count if F99 == .
sort ever_gd t_event
statsby mean = (100 * r(proportion)) lb = (100 * r(lb)) ub = (100 * r(ub)), ///
    by(ever_gd t_event) clear: ///
    ci proportions F99, level(95) agresti
format mean lb ub %5.2f
list ever_gd t_event mean lb ub, sepby(ever_gd)
preserve
	gen str16 block = "F99"
	append using "$data_work\prev_pooled.dta"
	save "$data_work\prev_pooled.dta", replace
restore
use "$data_work\event_case_mc.dta", clear 
statsby ///
	COR_log = (_b[F99]) ///
	SE_log  = (_se[F99]) ///
	z       = (_b[F99] / _se[F99]) ///
	p       = (2*normal(-abs(_b[F99] / _se[F99]))) ///
	lb_log  = (_b[F99] - invnormal(0.975)*_se[F99]) ///
	ub_log  = (_b[F99] + invnormal(0.975)*_se[F99]) ///
	, by(t_event) clear: ///
	clogit ever_gd F99, group(match_ID) vce(cluster match_ID)
gen COR = exp(COR_log)
gen lb  = exp(lb_log)
gen ub  = exp(ub_log)
gen SE  = COR * SE_log
gen str3 stars = ""
replace stars = "*"   if p < 0.05
replace stars = "**"  if p < 0.01
replace stars = "***" if p < 0.001
label var stars "* p < 0.05; ** p < 0.01; *** p < 0.001"
keep t_event COR SE z p stars lb ub
sort t_event
format COR SE lb ub z %6.2f
format p %6.4f
list t_event COR SE z p stars lb ub, sep(1) noobs 
preserve
	gen str16 block = "F99"
	append using "$data_work\cors_pooled.dta"
	save "$data_work\cors_pooled.dta", replace
restore
twoway ///
    (rcap lb ub t_event, lcolor(black) lwidth(thin)) ///
    (line COR t_event, lcolor(black) lwidth(thin) lpattern(solid)) ///
    (scatter COR t_event, msymbol(circle) mcolor(black) msize(small)) ///
    , ///
	title("{bf:Unspecified mental disorder}", ///
      size(medsmall) position(11)) ///
    subtitle("ICD-10-GM: F99", size(small) position(11)) ///
    xtitle("{bf:Relative time period}", size(small) margin(small)) ///
    ytitle("{bf:COR (95% CI)}", size(small) margin(zero)) ///
    xlabel(-5 "{it:t}{sub:-5}" -4 "{it:t}{sub:-4}" -3 "{it:t}{sub:-3}" -2 "{it:t}{sub:-2}" -1 "{it:t}{sub:-1}" 0 "{it:t}{sub:0}" 1 "{it:t}{sub:+1}" 2 "{it:t}{sub:+2}" 3 "{it:t}{sub:+3}" 4 "{it:t}{sub:+4}" 5 "{it:t}{sub:+5}", labsize(small)) ///
    ylabel(1 0(2)18, labsize(small) angle(horizontal) format(%4.0f)) ///
    yscale(range(0 18)) ///
    yline(1, lcolor(red) lpattern(shortdash)) ///
    yline(0(2)18, lcolor(gs14) lpattern(shortdash)) ///
    legend(off) ///
    graphregion(color(white) margin(0 0 0 0)) ///
    plotregion(margin(2 2 2 2)) plotregion(lstyle(none)) ///
    scheme(s1mono)
graph save "$graph/g15.gph", replace

/*******************************************************************
* 4: Graph combine
********************************************************************/
 
graph combine ///
    "$graph/g1.gph" ///
    "$graph/g2.gph" ///
    "$graph/g3.gph" ///
    "$graph/g4.gph" ///
    "$graph/g5.gph" ///
    "$graph/g6.gph" ///
    "$graph/g7.gph" ///
    "$graph/g8.gph", ///
    col(2) ///
    imargin(0 0 0 0) ///
    iscale(0.4) ///
    xsize(30) ///
    ysize(42) /// 
	ycommon xcommon
graph export "$graph/combined_psych_corrs1.emf", replace

graph combine ///
    "$graph/g9.gph" ///
    "$graph/g10.gph" ///
    "$graph/g11.gph" ///
    "$graph/g12.gph" ///
    "$graph/g13.gph" ///
    "$graph/g14.gph" ///
    "$graph/g15.gph", ///
    col(2) ///
    imargin(0 0 0 0) ///
    iscale(0.4) ///
    xsize(30) ///
    ysize(42) /// 
	ycommon xcommon
graph export "$graph/combined_psych_corrs2.emf", replace

/*******************************************************************
* 5: Num of unique PD over time (3 Digit ICD-10-GM code)
********************************************************************/

use "$data_work\event_case_mc.dta", clear
* shift t_event to 0-10 as factor-variable levels must be nonnegative; 5 = t0
replace t_event = t_event + 5

bysort ever_gd: sum num_pd if t_event == 5
nbreg num_pd i.t_event##i.ever_gd, vce(cluster match_ID)
margins i.t_event#i.ever_gd, level(95) post
* norestore: parmest replaces the data in memory with the estimates,
* avoiding the save/reload round-trip via a results file
parmest, norestore

gen ever_gd = .
replace ever_gd = real(regexs(1)) if regexm(parm, "#(\d+)\.ever_gd")
gen t_event = .
replace t_event = real(regexs(1)) if regexm(parm, "(\d+)\.t_event#")
rename estimate mean_pred
rename min95 lb
rename max95 ub
keep ever_gd t_event mean_pred lb ub
sort t_event ever_gd
replace t_event = t_event - 5

* print results 
format mean_pred lb ub %6.2f
sort ever_gd t_event 
list t_event ever_gd mean_pred lb ub, sepby(ever_gd) noobs

* for text; Manuscript (Figure 3 paragraph): "cases at t-5 to t-1:
* 1.31-1.87; controls: 0.56-0.64", "peaking in the index year (cases: 3.28;
* controls: 0.68)", post-index "2.29-2.58; controls: 0.71-0.79"
by ever_gd: tabstat mean_pred if inrange(t_event, -5, -1), stat(min max) format(%9.2f)
by ever_gd: tabstat mean_pred if t_event == 0, format(%9.2f)
by ever_gd: tabstat mean_pred if inrange(t_event, 1, 5), stat(min max) format(%9.2f)
by ever_gd: tabstat mean_pred, stat(min max) format(%9.2f)

twoway ///
    (rarea ub lb t_event if ever_gd==0, color(gs12%50) lcolor(gs12) lwidth(vthin)) ///
    (line mean_pred t_event if ever_gd==0, lcolor(stc1) lpattern(solid) lwidth(thin)) ///
    (scatter mean_pred t_event if ever_gd==0, msymbol(circle) mcolor(stc1) msize(small)) ///
    (rarea ub lb t_event if ever_gd==1, color(gs12%50) lcolor(gs12) lwidth(vthin)) ///
    (line mean_pred t_event if ever_gd==1, lcolor(stc2) lpattern(dash) lwidth(thin)) ///
    (scatter mean_pred t_event if ever_gd==1, msymbol(circle) mcolor(stc2) msize(small)), ///
    title("{bf:Average number of psychiatric diagnoses per person}", size(medsmall) position(11)) ///
    subtitle("ICD-10-GM: F00–F99 (excluding F63.0); diagnoses grouped at the 3-character category level", size(small) position(11)) ///
    xtitle("{bf:Relative time period}", size(small) margin(medsmall)) ///
    ytitle("{bf:Average number of diagnoses (95% CI)}", size(small) margin(medsmall)) ///
    xlabel(-5 "{it:t}{sub:-5}" -4 "{it:t}{sub:-4}" -3 "{it:t}{sub:-3}" -2 "{it:t}{sub:-2}" -1 "{it:t}{sub:-1}" 0 "{it:t}{sub:0}" 1 "{it:t}{sub:+1}" 2 "{it:t}{sub:+2}" 3 "{it:t}{sub:+3}" 4 "{it:t}{sub:+4}" 5 "{it:t}{sub:+5}", labsize(small)) ///
    ylabel(0.5 (0.5)3.5, labsize(small) angle(horizontal) format(%3.1f)) ///
    yscale(range(0.5 3.5)) ///
    yline(0.5(0.5)3.5, lcolor(gs14) lpattern(shortdash)) ///
    legend(order(2 "Controls" 5 "Cases") position(1) ring(0) cols(1)) ///
    graphregion(color(white) margin(0 0 0 0)) ///
    plotregion(margin(2 2 2 2)) plotregion(lstyle(none)) ///
    scheme(s1mono)
graph export "$graph/average_number_psychiatric_diagnoses.emf", replace

/*******************************************************************
* 6: Pooled results -> verify every claim the paper makes by command and
* document how the authors arrived at each interpretation
********************************************************************/

* CORs: one row per diagnostic block x relative year
use "$data_work\cors_pooled.dta", clear
order block t_event COR SE z p stars lb ub
sort block t_event
format COR SE lb ub %9.2f
format p %6.4f
save "$data_work\cors_pooled.dta", replace
* open-format copy for sharing (whitelisted in .gitignore)
export delimited using "$table\cors_pooled.csv", replace datafmt

* During the pre-index period, CORs ranged from 1.67 to 5.61, 
tabstat COR if t_event == -5, stat(min max) format(%9.2f)
tabstat COR if t_event == -1, stat(min max) format(%9.2f)
tabstat COR if inrange(t_event, -5, -1), stat(min max) format(%9.2f)
*  -> t-5: 1.82 (F50_F59) to 3.80 (other_psych); t-1: 1.86 (F50_F59) to
*     5.61 (other_psych); pre-index overall 1.67 to 5.61, as quoted.
*     "rising" holds for both range endpoints, though barely for the lower
*     one (1.82 -> 1.86); at block level F99 is the one series that falls
*     from t-5 (2.52) to t-1 (2.34)

* Manuscript: "increasing as t0 approached and peaking across all categories in the index year (range: 3.14–16.03)."
* the range is checked here, "peaking" in the profile below
tabstat COR if t_event == 0, stat(min max) format(%9.2f)
*  -> 3.14 (F50_F59) to 16.03 (F10), as quoted

* Manuscript: "declined over the post-index period, ranging from 1.90 to 10.80, with the highest values generally following t0 and gradually declining over subsequent years."
tabstat COR if t_event == 1, stat(min max) format(%9.2f)
tabstat COR if t_event == 5, stat(min max) format(%9.2f)
tabstat COR if inrange(t_event, 1, 5), stat(min max) format(%9.2f)
*  -> t+1: 2.49 (F50_F59) to 10.80 (other_psych); t+5: 1.90 (F50_F59) to
*     8.10 (other_psych); post-index overall 1.90 to 10.80, as quoted.
*     Both range endpoints decline from t+1 to t+5; the single block-level
*     exception is F40, marginally higher at t+5 (4.14) than at t+1 (4.06)

* Manuscript: "All reported CORs were greater than 1 and statistically significant at the 1% level"
* two conditions: no estimate weaker than **, and no CI reaching down to 1
tab stars
tabstat lb, stat(min) format(%9.2f)
*  -> 164 *** and one ** (F99 at t+4, p = 0.0037), nothing weaker, and the
*     smallest lower bound is 1.28.

* Manuscript: "Estimates peaked across all defined categories ... in the
* index year, before declining in the post-index period"
* peaks_at_t0: the block's highest COR of all 11 years falls in t0.
* post_above_pre: even the weakest post-index year beats the strongest
* pre-index year, i.e. the strictest reading of "stayed elevated", year by
* year instead of period averages
preserve
	bysort block: egen pre_min  = min(cond(inrange(t_event, -5, -1), COR, .))
	bysort block: egen pre_max  = max(cond(inrange(t_event, -5, -1), COR, .))
	bysort block: egen post_min = min(cond(inrange(t_event,  1,  5), COR, .))
	bysort block: egen post_max = max(cond(inrange(t_event,  1,  5), COR, .))
	gen c0 = COR if t_event == 0
	bysort block: egen cor_t0 = max(c0)
	keep block pre_min pre_max cor_t0 post_min post_max
	duplicates drop
	gen byte peaks_at_t0 = cor_t0 > pre_max & cor_t0 > post_max
	gen byte post_above_pre = post_min > pre_max
	format pre_min pre_max cor_t0 post_min post_max %9.2f
	list block pre_min pre_max cor_t0 post_min post_max peaks_at_t0 post_above_pre, noobs sep(0) abbreviate(14)
restore
*  -> peaks_at_t0 = 1 for all 15 blocks, so "peaking across all defined
*     categories" holds without exception. post_above_pre fails for F40_F48,
*     F41, F42, F43 and F99, whose CORs return to pre-index magnitude within
*     1-3 years after t0

* post_above_pre above is the strict reading. A more lenient one compares the
* period averages: the five post-index years against the five pre-index
* years, so a block may dip in single years and still stay elevated overall.
* ratio = post_avg / pre_avg says by how much (t0 is in neither average)
preserve
	bysort block: egen pre_avg  = mean(cond(inrange(t_event, -5, -1), COR, .))
	bysort block: egen post_avg = mean(cond(inrange(t_event,  1,  5), COR, .))
	keep block pre_avg post_avg
	duplicates drop
	gen byte post_avg_above_pre = post_avg > pre_avg
	gen ratio = post_avg / pre_avg
	sort ratio
	format pre_avg post_avg ratio %9.2f
	list block pre_avg post_avg ratio post_avg_above_pre, noobs sep(0) abbreviate(18)
restore
*  -> post_avg_above_pre = 1 for all 15 blocks: on period averages the CORs
*     do stay above pre-index level everywhere, including the five that fail
*     the strict test.

* Manuscript: "alcohol-related disorders, other psychoactive substance use
* disorders, and personality disorders showed the highest pre-index CORs
* (3.46 to 5.61 between t–5 and t–1) 
* Highest is about rank so we rank the blocks within each pre-index year:
* the three named ones must hold ranks 1-3 in every single year. Rank 4
* shows the gap to the next block; the tabstat gives the quoted range
preserve
	keep if inrange(t_event, -5, -1)
	gsort t_event -COR
	by t_event: gen byte rank = _n
	list t_event rank block COR if rank <= 4, sepby(t_event) noobs abbreviate(14)
	tabstat COR if inlist(block, "F10", "other_psych", "F60_F69_noPG"), stat(min max) format(%9.2f)
restore
*  -> the three named blocks hold ranks 1-3 in all five pre-index years,
*	  so they are clearly set apart. Their combined range is 3.46-5.61

* Manuscript: "Obsessive-compulsive disorder is the clearest exception,
* with CORs ranging from 2.20 to 2.94 across both the pre- and post-index
* periods, a pattern more consistent with stable co-occurrence than with a
* disorder that escalates alongside GD."
* The quoted range leaves out t0
tabstat COR if block == "F42" & t_event != 0, stat(min max) format(%9.2f)
*  -> 2.20 to 2.94, as quoted

* For "stable co-occurrence": each block's t0 COR against its own strongest
* pre-index COR. Ratio, not difference, as the blocks sit at very different
* base levels, so only the relative jump makes sense to compare. A disorder
* escalating with GD spikes far above its pre-index level; a stable
* co-occurring one barely moves. F42 has to come out smallest of the 15 for
* "clearest" to hold
preserve
	bysort block: egen pre_max = max(cond(inrange(t_event, -5, -1), COR, .))
	gen c0 = COR if t_event == 0
	bysort block: egen cor_t0 = max(c0)
	keep block pre_max cor_t0
	duplicates drop
	gen t0_vs_pre = cor_t0 / pre_max
	sort t0_vs_pre
	format pre_max cor_t0 t0_vs_pre %9.2f
	list block pre_max cor_t0 t0_vs_pre, noobs sep(0) abbreviate(14)
restore
*  -> F42 is smallest at 1.42, ahead of F99 and F40 (1.48), while the
*     escalating blocks reach 2.4-4.1. Together with ratio 1.00 in the
*     average test above, OCD is the one category whose association with GD
*     is essentially the same before and after the index year.

* Prevalences: one row per diagnostic block x group x relative year
use "$data_work\prev_pooled.dta", clear
order block ever_gd t_event mean lb ub
sort block ever_gd t_event
format mean lb ub %9.2f
save "$data_work\prev_pooled.dta", replace
* open-format copy for sharing (whitelisted in .gitignore)
export delimited using "$table\prev_pooled.csv", replace datafmt

* Manuscript, all t0 prevalences quoted in the Results (cases; controls):
* overall 87.53; 32.89 - mood 58.41; 12.50 - neurotic etc. 52.23; 18.75 -
* substance use 50.71; 10.33 - personality 19.73; 2.11 - behavioural
* syndromes 9.80; 3.38 - unspecified 1.33; 0.29 - tobacco 31.81; 8.06 -
* alcohol 23.88; 2.06 - other psychoactive 22.23; 1.86 - stress/adjustment
* 27.95; 6.44 - other anxiety 17.78; 4.89 - phobic anxiety 5.98; 1.23 -
* OCD 2.13; 0.51 - depressive 55.99; 11.66
preserve
	keep if t_event == 0
	keep block ever_gd mean
	reshape wide mean, i(block) j(ever_gd)
	rename (mean0 mean1) (ctrl_t0 case_t0)
	gsort -case_t0
	format ctrl_t0 case_t0 %9.2f
	list block case_t0 ctrl_t0, noobs sep(0) abbreviate(14)
restore

* Manuscript: "Cases showed a marked pre-index upward trend as the index 
* year approached (e.g., overall psychiatric prevalence: 49.49% at the 
* pre-index minimum in t–5, rising to 62.29% at the pre-index maximum in t–1)," 
list t_event mean if block == "F00_F99_nopg" & ever_gd == 1 & inrange(t_event, -5, -1), noobs
*  -> rises monotonically from 49.49 at t-5 to 62.29 at t-1, so t-5 is
*     indeed the pre-index minimum and t-1 the maximum, as quoted

* Manuscript: "peaked at t0 in every diagnostic category (87.53% for any Chapter
* V disorder except GD), then declined in the post-index period but remained
* above both the control group and the case group's own pre-index levels in 14 of 15 categories.
* Cases only; the control half is the 165-cell check below. prev_t0 above
* pre_max and post_max gives "peaked at t0", post_above_pre gives "remained
* above ... pre-index levels" in its strictest form - lowest post-index year
* still above the highest pre-index year
preserve
	keep if ever_gd == 1
	bysort block: egen pre_min  = min(cond(inrange(t_event, -5, -1), mean, .))
	bysort block: egen pre_max  = max(cond(inrange(t_event, -5, -1), mean, .))
	bysort block: egen post_min = min(cond(inrange(t_event,  1,  5), mean, .))
	bysort block: egen post_max = max(cond(inrange(t_event,  1,  5), mean, .))
	gen m0 = mean if t_event == 0
	bysort block: egen prev_t0 = max(m0)
	keep block pre_min pre_max prev_t0 post_min post_max
	duplicates drop
	gen byte post_above_pre = post_min > pre_max
	format pre_min pre_max prev_t0 post_min post_max %9.2f
	list block pre_min pre_max prev_t0 post_min post_max post_above_pre, noobs sep(0) abbreviate(14)
restore
*  -> prev_t0 lies above pre_max and post_max in all 15 blocks, so "peaked
*     at t0" holds everywhere. post_above_pre = 1 for 14; only F99 dips back
*     below its own pre-index maximum (0.65 at t+4 vs 0.94 at t-2), which
*     the exception sentence covers

* Manuscript: "The exception was unspecified mental disorders, whose case prevalence 
* fluctuated throughout and fell below its own pre-index maximum post-index,
* unlike every other category.
 

list t_event mean if block == "F99" & ever_gd == 1, noobs 
*  -> as quoted: pre-index maximum 0.94 at t-2, drop to 0.74 at t-1, peak
*     1.33 at t0, post-index minimum 0.65 at t+4 and maximum 0.91 at t+1,
*     so the entire post-index range stays below the pre-index maximum

* same lenient reading as for the CORs: post-index vs pre-index period
* average of case prevalence, t0 in neither
preserve
	keep if ever_gd == 1
	bysort block: egen pre_avg  = mean(cond(inrange(t_event, -5, -1), mean, .))
	bysort block: egen post_avg = mean(cond(inrange(t_event,  1,  5), mean, .))
	keep block pre_avg post_avg
	duplicates drop
	gen byte post_avg_above_pre = post_avg > pre_avg
	gen ratio = post_avg / pre_avg
	sort ratio
	format pre_avg post_avg ratio %9.2f
	list block pre_avg post_avg ratio post_avg_above_pre, noobs sep(0) abbreviate(18)
restore
*  -> unlike the CORs, prevalence fails the lenient test too, and only for
*     F99 (0.79 -> 0.77). The other 14 blocks rise by 1.31x to 2.05x, so the statement is
*     correct for them.

* Manuscript: "The temporal trends in diagnosed prevalence and the CORs were
* homogeneous across all diagnostic categories and comorbidities except for
* unspecified mental disorders (for which the trend was more mixed
* throughout the entire observation period)."
* no separate command, this follows from the results above: 
*  -> F99 is the only block whose case prevalence dips back below its own
*     pre-index maximum (0.65 at t+4 vs 0.94 at t-2), and the only one whose
*     pre-index CORs fall instead of rising toward t0 (2.52 at t-5 vs 2.34
*     at t-1). It is rare (t0: 1.33% of cases, ~0.3% of controls), so few
*     events and quite noisy estimates. It still
*     peaks at t0 (COR 4.58) and cases stay above controls in every year

* Manuscript: "Across all comorbidities and relative years, the prevalence
* was consistently higher in cases than in controls."
* Reshaping puts both group means in one row, so all 165 cells can be tested
* at once: count must be 0
preserve
	keep block ever_gd t_event mean
	reshape wide mean, i(block t_event) j(ever_gd)
	rename (mean0 mean1) (mean_ctrl mean_case)
	count if mean_case <= mean_ctrl
restore
*  -> 0, so cases are above controls in every one of the 165 block x year
*     cells, without a single tie

* Manuscript: "In controls, prevalence at t+5 exceeded that at t–5 for all diagnostic
* categories except unspecified mental disorders, which declined slightly (0.87-fold).
* Among those that increased, the increase ranged from 1.17-fold (personality disorders)
* to 1.92-fold (behavioral syndromes associated with physiological disturbances). 
* growth = t+5 over t-5 per block, as a ratio (t+5/t-5): control prevalence
* runs from 0.2% to 37%, so percentage points would not compare across
* blocks. Around 1 means flat. The sorted list gives every fold change
* quoted in the sentence, smallest and largest alike
preserve
	keep if ever_gd == 0
	bysort block (t_event): gen double growth = mean[_N] / mean[1]
	bysort block: egen ctrl_min = min(mean)
	bysort block: egen ctrl_max = max(mean)
	keep block ctrl_min ctrl_max growth
	duplicates drop
	gsort -growth
	format ctrl_min ctrl_max growth %9.2f
	list block ctrl_min ctrl_max growth, noobs sep(0) abbreviate(14)
restore
*  -> F99 is the only block below 1 (0.87), so "higher at t+5 than at t-5
*     for all categories except unspecified mental disorders" holds. The
*     smallest increases are F60_F69_noPG 1.17, other_psych 1.20 and F40
*     1.21; the largest are F50_F59 1.92, F17 1.69 and F43 1.64. All
*     remaining blocks lie between these (1.34-1.63), so every fold change
*     quoted in the sentence is reproduced

/****************
* End of .do file
****************/
