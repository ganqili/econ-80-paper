clear
set more off
pause on
capture log close

********************************************************************************
* CHANGE PROJECT PATH HERE ⸜(ˆᗜˆ˵ )⸝
local path_econ80 "/Users/thomasli/Desktop/econ-80-paper"
********************************************************************************

* set up log file
log using "`path_econ80'/outputs/logs/02_merge.log", replace

* program to merge clean date files for econ 80 paper
* author: Ganqi Li (ganqi.li.25@dartmouth.edu)
* updated: Nov 26, 2024 



/*
00. Datasets required

Data: 
1. hospitalization in "/data/clean": hospitalization_weekly_fips.dta
2. mutligen proportions in "/data/clean": household_fips.dta
3. covid-19 school mode in "/data/clean": school_mode_monthly_fips.dta
4. county mobility in "/data/clean": mobility_weekly_fips.dta
5. county urbanicity in "/data/clean": urbanicity_fips.dta
*/



/*
01. Merge clean data
*/

* open hospitalization data
cd "`path_econ80'/data/clean"
use hospitalization_weekly_fips, clear

* generate hospitalization per 100k population
gen adult_covid_week_avg_100k = adult_covid_week_avg * ///
	100000 / population
gen pediatric_covid_week_avg_100k = pediatric_covid_week_avg * ///
	100000 / population
drop adult_covid_week_avg pediatric_covid_week_avg

* merge with multigen data
merge m:1 fips using household_fips 
keep if _merge == 3
drop _merge

* merge with weekly mobility data
merge 1:1 fips week_sunday using mobility_weekly_fips
drop if _merge == 2
drop _merge

* merge with school mode data
drop if week_sunday == .
gen month = mofd(week_sunday)
format month %tm 
drop if month < tm(2020m6)
drop if month > tm(2021m6)

merge m:1 fips month using school_mode_monthly_fips

* fill in zeros for instruction style during pre-school-year
foreach var in share_inperson share_hybrid share_virtual openness_index {
	replace `var' = 0 if (`var' == .) & (month < tm(2020m12))
}

* drop periods in school year without school mode
drop if openness_index == .

* classify county by overall school mode
egen county_dominant_mode = median(dominant_mode), by(fips)
tab county_dominant_mode, m

* re-classify counties even-split on weekly dominant instructional modes
********************************************************************************
replace county_dominant_mode = 0 if county_dominant_mode == 0.5
replace county_dominant_mode = 1 if county_dominant_mode == 1.5
// replace county_dominant_mode = 1 if county_dominant_mode == 0.5
// replace county_dominant_mode = 2 if county_dominant_mode == 1.5
********************************************************************************
sort fips week_sunday

* generate weeks from school opening
by fips (week_sunday), sort: gen seq = _n // create sequence within fips
by fips: egen first_event_row = min(cond(dominant_mode != ., _n, .))
/* This flags first row where school mode is non-missing withine each fips. */

by fips: gen event_time = _n - first_event_row 
/* First week of school opening set as 0. */

cap drop seq first_event_row _merge

rename dominant_mode weekly_dominant_mode
rename is_multigen_acs share_multigen_acs 
rename is_multigen_proxy share_multigen_proxy

* merge in states
cd "`path_econ80'/data/temp"
merge m:1 fips using xwalk_fips_to_state
keep if _merge == 3
drop _merge

* generate regions from Ertem et al. (2021)
gen region = 0 if inlist(state, "PA", "NY", "VT", "NH", "NJ", "MA", "CT", "RI", "ME")
replace region = 1 if inlist(state, "AK", "WA", "OR", "CA", "ID")
replace region = 1 if inlist(state,"NV", "MT", "WY", "UT", "AZ", "CO", "NM")
replace region = 2 if inlist(state, "ND", "SD", "NE", "KS", "MN", "IA")
replace region = 2 if inlist(state,"MO", "WI", "IL", "IN", "MI", "OH")
replace region = 3 if inlist(state, "OK", "TX", "AR", "LA", "KY", "TN","NC", "SC") 
replace region = 3 if inlist(state,"MS", "AL", "GA", "FL", "WV", "MD", "DC", "VA") 
/* Here, 0 for Northeast, 1 for West, 2 for Midwest, 3 for South. */

* fill in missing regions from pre-school-year period
egen region_new = mean(region), by(fips)
tab region_new 
drop if region_new == .

drop region 
rename region_new region
label var region "0=northeast, 1=west, 2=midwest, 3=south

* make multigen ratios in percentage points
gen share_multigen_acs_pp = share_multigen_acs * 100
gen share_multigen_proxy_pp = share_multigen_proxy * 100

* merge in urbanicity
codebook fips

cd "`path_econ80'/data/clean"
merge m:1 fips using urbanicity_fips
drop if _merge == 2
drop _merge 

* save clean data without subsetting event-time to between -4 and 12
cd "`path_econ80'/data/merged"
save e80_merged, replace


