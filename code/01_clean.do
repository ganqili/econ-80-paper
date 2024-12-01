clear
set more off
pause on
capture log close

********************************************************************************
* CHANGE PROJECT PATH HERE ⸜(ˆᗜˆ˵ )⸝
local path_econ80 "/Users/thomasli/Desktop/econ-80-paper"
********************************************************************************

* set up log file
log using "`path_econ80'/outputs/logs/01_clean.log", replace

* program to clean raw files for econ 80 paper
* author: Ganqi Li (ganqi.li.25@dartmouth.edu)
* updated: Nov 26, 2024 



/*
00. Datasets required

Data: 
1. hospitalization in "/data/raw/hospitalization": hospitalization.csv
2. county population in "/data/raw/hospitalization": population.csv
3. acs 5-year household in "/data/raw/household": acs_household.dta
4. covid-19 school mode in "/data/raw/school_mode": csdh_school.csv
5. community mobility in "data/raw/mobility": mobility.csv
6. county urbanicity in "data/raw/urbanicity": geocorr_urbanicity.csv

Crosswalks:
1. FIPS to NCES District in "/data/raw/household": xwalk_fips_to_puma.csv
2. FIPS to PUMA in "/data/raw/school_mode": xwalk_fips_to_nces.csv
3. FIPS to State in "/data/raw/school_mode": xwalk_fips_to_state.csv

Note: See Table 1 in paper for more on data sources. 
*/

* prepare FIPS to PUMA crosswalk
cd "`path_econ80'/data/raw/household"
import delimited using xwalk_fips_to_puma.csv, clear

* retain fips-puma allocation factor 
rename v1 fips
rename v3 puma
rename v8 fips_puma_allocation
keep fips puma fips_puma_allocation
drop in 1/2

foreach var in fips puma fips_puma_allocation {
	destring `var', replace
	drop if `var' == .
}

* save crosswalk in temp folder
cd "`path_econ80'/data/temp"
save xwalk_fips_to_puma, replace


* prepare FIPS to NCES crosswalk
cd "`path_econ80'/data/raw/school_mode"
import delimited using xwalk_fips_to_nces.csv, clear

* retain fips-nces allocation factor
rename v1 fips
gen nces = v2 + v3 // combine nces id string
rename v8 fips_nces_allocation
keep fips nces fips_nces_allocation
drop in 1/2

foreach var in fips nces fips_nces_allocation {
	destring `var', replace
	drop if `var' == .
}

order fips nces
sort fips nces

* save crosswalk in temp folder
cd "`path_econ80'/data/temp"
save xwalk_fips_to_nces, replace


* prepare FIPS to State data
cd "`path_econ80'/data/raw/school_mode"
import delimited using xwalk_fips_to_state.csv, clear
rename v1 fips
rename v3 state

keep fips state
drop in 1/2
destring fips, replace

* save crosswalk in temp folder
cd "`path_econ80'/data/temp"
save xwalk_fips_to_state, replace



/*
01. Clean hopsitalization data
*/

* clean county population data
cd "`path_econ80'/data/raw/hospitalization"
import delimited using population.csv, clear
keep v1 v3
rename v1 fips
rename v3 population
drop in 1/2

destring fips, replace
drop if fips ==.

destring population, replace
drop if population ==.

* save population data in temp folder
cd "`path_econ80'/data/temp"
save population, replace

* import hospitalization data
cd "`path_econ80'/data/raw/hospitalization"
import delimited using hospitalization.csv, clear

* drop hospitals with missing fips
drop if fips_code ==.

* rename adult and pediatric covid hospitalization 
rename total_adult_patients_hospitalize adult_covid_week_avg
/* Average number of patients currently hospitalized in an adult inpatient bed
 who have confirmed or suspected for COVID-19. Includes those in observation 
 beds reported during the 7-day period" */

rename total_pediatric_patients_hospita pediatric_covid_week_avg
/* "Average number of patients currently hospitalized in a pediatric inpatient
bed who are suspected or confirmed for COVID-19. Includes those in observation 
beds reported in the 7-day period" */

* keep covid hospitalization outcomes
keep collection_week state fips_code hospital_pk ///
	adult_covid_week_avg pediatric_covid_week_avg

* drop territories
codebook state
foreach territory in AS GU MP PR VI {
	drop if state == "`territory'"
}

* assume missing as 0
foreach var in adult_covid_week_avg pediatric_covid_week_avg {
	replace `var' = 0 if (`var' < 0) | (`var' == .) 
}

* create start of each week on Sunday
gen week_sunday = date(collection_week, "YMD")
format week_sunday %td

gen week_sunday_day = dow(week_sunday) // check day of week
tab week_sunday_day // all dates are Sundays
drop week_sunday_day

* collapse sum of hospitalizations by county and date
collapse (sum) adult_covid_week_avg pediatric_covid_week_avg, ///
	by(fips_code week_sunday)
sort fips_code week_sunday
rename fips_code fips

* merge with population data
cd "`path_econ80'/data/temp"
merge m:1 fips using population
keep if _merge == 3
drop _merge

* save cleaned hospitalization data 
cd "`path_econ80'/data/clean"
save hospitalization_weekly_fips, replace



/*
02. Clean household data
*/

* import household data
cd "`path_econ80'/data/raw/household"
use acs_household, clear

* explore variables
fre race raced
fre multgen multgend

* keep variables of interest
keep serial hhwt puma multgen multgend hhincome sex age ///
	race racamind racasian racblk racpacis racwht racother perwt

* generate identifiers for multigen household
gen is_older_adult = age >= 65
gen is_school_child = (age >= 5) & (age <= 18)
gen is_multigen_acs = inlist(multgend, 23, 31, 32)


* save share of older adults 
preserve

gen share_65_above = age >= 65
gen share_50_above = age >= 50
gen share_5_to_18 = (age >= 5) & (age <= 18)

collapse (mean) share_65_above share_50_above share_5_to_18 ///
	[aw=perwt], by(puma)

* merge in crosswalk
cd "`path_econ80'/data/temp"
merge 1:m puma using xwalk_fips_to_puma
keep if _merge == 3
drop _merge

* weight older adult ratios by allocation factor 
sort fips 
gen share_65_above_weighted = share_65_above * fips_puma_allocation
gen share_50_above_weighted = share_50_above * fips_puma_allocation
gen share_5_to_18_weighted = share_5_to_18 * fips_puma_allocation

* collapse onto county level
collapse (sum) share_65_above_weighted share_50_above_weighted ///
	share_5_to_18_weighted fips_puma_allocation, by(fips)

* keep only if PUMA represents more than 50% of county
keep if fips_puma_allocation >= 0.5

* adjust older adult proportions by allocation factors
gen share_65_above = share_65_above_weighted / fips_puma_allocation
gen share_50_above = share_50_above_weighted / fips_puma_allocation
gen share_5_to_18 = share_5_to_18_weighted / fips_puma_allocation

cap drop fips_puma_allocation ///
	share_50_above_weighted share_65_above_weighted share_5_to_18_weighted 

* save cleaned older adult share dataset
cd "`path_econ80'/data/clean"
save older_adult_fips, replace

restore


* collpase on characteristics by household
collapse (mean) hhwt puma hhincome is_multigen_acs ///
	racamind racasian racblk racpacis racwht racother ///
	(max) has_older_adult = is_older_adult ///
	has_school_child = is_school_child, by(serial)

* generate household income percentiles
xtile hhincome_pctile = hhincome, n(100)
/* Note: Some household incomes have the value 9999999, since these 
household incomes exceed a high threshold and are censored. */	
	
* generate proxy for multigen families
gen is_multigen_proxy = has_older_adult * has_school_child

* check efficacy of multigen measure
su is_multigen_acs is_multigen_proxy
reg is_multigen_acs is_multigen_proxy
/* The proxy and ACS measures are highligh correlated. */

* investigate multigen and household characteristics
reg hhincome_pctile racamind racasian racblk racother
reg hhincome_pctile racamind racasian racblk racother

reg is_multigen_acs hhincome_pctile racamind racasian racblk racother
reg is_multigen_proxy hhincome_pctile racamind racasian racblk racother

* collapse multigen measures on puma
collapse (mean) is_multigen_acs is_multigen_proxy [aw=hhwt], by(puma)

* merge in crosswalk
cd "`path_econ80'/data/temp"
merge 1:m puma using xwalk_fips_to_puma
keep if _merge == 3
drop _merge

* weight multigen ratios by allocation factor 
sort fips 
gen is_multigen_acs_weighted = is_multigen_acs * fips_puma_allocation
gen is_multigen_proxy_weighted = is_multigen_proxy * fips_puma_allocation

* collapse onto county level
collapse (sum) is_multigen_acs_weighted is_multigen_proxy_weighted ///
	fips_puma_allocation, by(fips)

* keep only if PUMA represents more than 50% of county
keep if fips_puma_allocation >= 0.5

* adjust multigen proportions by allocation factors
gen is_multigen_acs = is_multigen_acs_weighted / fips_puma_allocation
label var is_multigen_acs "Share of multigen households in ACS"

gen is_multigen_proxy = is_multigen_proxy_weighted / fips_puma_allocation
label var is_multigen_proxy "Share of households with both 5-18 and 65+"

drop is_multigen_acs_weighted is_multigen_proxy_weighted fips_puma_allocation

* generate quartiles for multigen shares
xtile quartile_multigen_proxy = is_multigen_proxy, nq(4)
xtile quartile_multigen_acs = is_multigen_acs, nq(4)

* check quartiles
tabulate quartile_multigen_proxy
tabulate quartile_multigen_acs

gen diff = quartile_multigen_proxy - quartile_multigen_acs
su diff 
drop diff

* merge with older adult ratios
cd "`path_econ80'/data/clean"
merge 1:1 fips using older_adult_fips
drop if _merge != 3
drop _merge

* save cleaned household dataset
cd "`path_econ80'/data/clean"
save household_fips, replace



/*
03. Clean school mode data
*/

* import CSDH school mode data 
cd "`path_econ80'/data/raw/school_mode"
import delimited using csdh_school.csv, clear

* make new time variable for month
gen month_time = monthly(month, "YM")
format month_time %tm
drop month 

* rename variables
rename ncesdistrictid nces
rename stateabbrev state

order nces month_time
sort nces month_time

* check how many schools start within each month
egen first_month = min(month_time), by(nces)
format first_month %tm

preserve
collapse (mean) first_month, by(nces)
tab first_month
restore

/* About 52.35% of school districts started in August 2020, and 41.66% started 
in September, accounting for 94.01% of school districts. About 5.76% started 
in October. There are a total of 14,967 unique school districts. */

* keep schools that start in August and September
drop if first_month > tm(2020m9)
tab first_month

drop state districtname
rename month_time month

gen share_tot = share_inperson + share_hybrid + share_virtual
drop if share_tot == .

* merge in crosswalk
cd "`path_econ80'/data/temp"
merge m:m nces using xwalk_fips_to_nces
keep if _merge == 3
drop _merge

order fips month nces
sort fips month nces

* weight school mode shares by allocation factor 
foreach var in share_inperson share_hybrid share_virtual {
	gen `var'_weighted = `var' * fips_nces_allocation
}

* collapse by monthly county level
collapse (sum) share_inperson_weighted share_hybrid_weighted ///
	share_virtual_weighted fips_nces_allocation, by(fips month)

* keep counties where NCES district represents more than 50% of population
keep if fips_nces_allocation  >= 0.5

* adjust shares for allocation factors
gen share_inperson = share_inperson_weighted / fips_nces_allocation
gen share_hybrid = share_hybrid_weighted / fips_nces_allocation
gen share_virtual = share_virtual_weighted / fips_nces_allocation

drop share_inperson_weighted share_hybrid_weighted ///
	share_virtual_weighted fips_nces_allocation

* create openness index
gen openness_index = share_inperson + 0.5 * share_hybrid
label var openness_index "1*%inperson + 0.5*%hybrid"

* visualize openness index distribution 
hist openness_index, nodraw

* generate variable for dominant mode
gen dominant_mode = 2 if (share_inperson >= share_hybrid) ///
	& (share_inperson >= share_virtual)
replace dominant_mode = 1 if (share_hybrid > share_inperson) ///
	& (share_hybrid >= share_virtual)
replace dominant_mode = 0 if dominant_mode == .
label var dominant_mode "0=mostly virtual, 1=mostly hybrid, 2=mostly in-person"

* save cleaned school mode data
cd "`path_econ80'/data/clean"
save school_mode_monthly_fips, replace



/*
04. Clean community mobility data
*/

* import mobility data
cd "`path_econ80'/data/raw/mobility"
import delimited using mobility.csv, clear

rename census_fips_code fips
drop if fips == .

rename retail_and_recreation_percent_ch mobility_retail
rename grocery_and_pharmacy_percent_cha mobility_grocery
rename parks_percent_change_from_baseli mobility_parks
rename transit_stations_percent_change_ mobility_transit
rename workplaces_percent_change_from_b mobility_workplaces
rename residential_percent_change_from_ mobility_residential

keep fips date mobility_retail mobility_grocery mobility_parks ///
mobility_transit mobility_workplaces mobility_residential

* mark Sundays as start of week
gen date_time = date(date, "YMD")
format date_time %td

sort fips date_time
gen is_sunday = dow(date_time) == 0
gen week_sunday = date_time - dow(date_time)
format week_sunday %td

* collapse values by week and county
collapse (mean) mobility_retail mobility_grocery mobility_workplaces ///
mobility_residential, by(fips week_sunday)

/* Ertem et al. use retail and recreation, grocery and pharmacy, workplaces and
residential as controls, since parks and transit have many missung values. */ 

* save cleaned mobility data
cd "`path_econ80'/data/clean"
save mobility_weekly_fips, replace



/*
05. Clean urbanicity 
*/

* import urbanicity data
cd "`path_econ80'/data/raw/urbanicity"
import delimited using geocorr_urbanicity.csv, clear

* rename variables
rename v1 fips
rename v2 urban_or_rural
rename v5 urban_share
keep fips urban_or_rural urban_share

drop in 1/2
destring fips, replace
destring urban_share, replace

gen urban_share_v2 = urban_share if urban_or_rural == "U"
replace urban_share_v2 = 1 - urban_share if urban_or_rural == "R"

collapse (mean) urban_share_v2, by(fips)
rename urban_share_v2 urban_share
label var urban_share "Urbanicity"

* save cleaned urbanicity data
cd "`path_econ80'/data/clean"
save urbanicity_fips, replace


