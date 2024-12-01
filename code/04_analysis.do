clear
set more off
pause on
capture log close

********************************************************************************
* CHANGE PROJECT PATH HERE ⸜(ˆᗜˆ˵ )⸝
local path_econ80 "/Users/thomasli/Desktop/econ-80-paper"
********************************************************************************

* set up log file
log using "`path_econ80'/outputs/logs/04_analysis.log", replace

* program to analyze merged data for econ 80 w/ regressions
* author: Ganqi Li (ganqi.li.25@dartmouth.edu)
* updated: Nov 27, 2024 



/*
00. Datasets required

Data: 
1. merged data in "/data/merged": e80_merged.dta
*/

* open merged data
cd "`path_econ80'/data/merged"
use e80_merged, clear

* follow Ertem et al. in using -5 to 13 weeks from start of school
keep if (event_time >= -5) & (event_time <= 13)

* shift event time by 5 so it can be controlled as indicator 
gen evttime_plus5 = event_time + 5

* keep data before end of year
keep if week_sunday <= date("2020-12-31", "YMD")
summ week_sunday, format

* create interaction between dominant mode and week
gen county_dominant_hybrid = 0
replace county_dominant_hybrid = 1 if county_dominant_mode == 1
gen county_hybridXevt_plus5 = county_dominant_hybrid * evttime_plus5 

gen county_dominant_inperson = 0
replace county_dominant_inperson = 1 if county_dominant_mode == 2
gen county_inpersonXevt_plus5 = county_dominant_inperson * evttime_plus5 

* create unique state numbers
encode state, gen(state_num)

* compare data availability across regions
sort region
by region: summarize adult_covid_week_avg_100k

forvalues value = 0/3 {
    codebook fips if region == `value'
}



/*
01. Graph marginal effect on school mode w/o interaction
*/

poisson adult_covid_week_avg_100k i.county_dominant_mode i.evttime_plus5 ///
	mobility_retail mobility_grocery mobility_workplaces mobility_residential urban_share ///
	i.state_num#i.evttime_plus5 i.fips ///
	i.county_hybridXevt_plus5 i.county_inpersonXevt_plus5 ///
	, vce(robust)

margins, eydx(county_hybridXevt_plus5) post
estimates store hybrid_all

poisson adult_covid_week_avg_100k i.county_dominant_mode i.evttime_plus5 ///
	mobility_retail mobility_grocery mobility_workplaces mobility_residential urban_share ///
	i.state_num#i.evttime_plus5 i.fips ///
	i.county_hybridXevt_plus5 i.county_inpersonXevt_plus5 ///
	, vce(robust)

margins, eydx(county_inpersonXevt_plus5) post
estimates store trad_all	

coefplot (hybrid_all, label("Hybrid") mlcolor(black) mcolor(gs12) ///
    ciopts(recast(rcap) color(gs10))) ///
    (trad_all, label("In-person") mlcolor(black) mcolor(gs2) ///
    ciopts(recast(rcap) color(gs2))), ///
	drop(18.county_hybridXevt_plus5 18.county_inpersonXevt_plus5) ///
    yline(0, lcolor(black) lpattern(dash)) vertical ///
    rename(1.county_hybridXevt_plus5 = 1.county_inpersonXevt_plus5 ///
           2.county_hybridXevt_plus5 = 2.county_inpersonXevt_plus5 ///
           3.county_hybridXevt_plus5 = 3.county_inpersonXevt_plus5 ///
           4.county_hybridXevt_plus5 = 4.county_inpersonXevt_plus5 ///
           5.county_hybridXevt_plus5 = 5.county_inpersonXevt_plus5 ///
           6.county_hybridXevt_plus5 = 6.county_inpersonXevt_plus5 ///
           7.county_hybridXevt_plus5 = 7.county_inpersonXevt_plus5 ///
           8.county_hybridXevt_plus5 = 8.county_inpersonXevt_plus5 ///
           9.county_hybridXevt_plus5 = 9.county_inpersonXevt_plus5 ///
           10.county_hybridXevt_plus5 = 10.county_inpersonXevt_plus5 ///
           11.county_hybridXevt_plus5 = 11.county_inpersonXevt_plus5 ///
           12.county_hybridXevt_plus5 = 12.county_inpersonXevt_plus5 ///
           13.county_hybridXevt_plus5 = 13.county_inpersonXevt_plus5 ///
           14.county_hybridXevt_plus5 = 14.county_inpersonXevt_plus5 ///
           15.county_hybridXevt_plus5 = 15.county_inpersonXevt_plus5 ///
           16.county_hybridXevt_plus5 = 16.county_inpersonXevt_plus5 ///
           17.county_hybridXevt_plus5 = 17.county_inpersonXevt_plus5) ///
    coeflabels(1.county_inpersonXevt_plus5 = "-4" ///
               2.county_inpersonXevt_plus5 = "-3" ///
               3.county_inpersonXevt_plus5 = "-2" ///
               4.county_inpersonXevt_plus5 = "-1" ///
               5.county_inpersonXevt_plus5 = "0" ///
               6.county_inpersonXevt_plus5 = "1" ///
               7.county_inpersonXevt_plus5 = "2" ///
               8.county_inpersonXevt_plus5 = "3" ///
               9.county_inpersonXevt_plus5 = "4" ///
               10.county_inpersonXevt_plus5 = "5" ///
               11.county_inpersonXevt_plus5 = "6" ///
               12.county_inpersonXevt_plus5 = "7" ///
               13.county_inpersonXevt_plus5 = "8" ///
               14.county_inpersonXevt_plus5 = "9" ///
               15.county_inpersonXevt_plus5 = "10" ///
               16.county_inpersonXevt_plus5 = "11" ///
               17.county_inpersonXevt_plus5 = "12") ///
    graphregion(fcolor(white)) ///
	title("The Effect of School Mode on COVID Hospitalization") ///
    xtitle("Weeks from school opening") ///
    ytitle("Average marginal effect w/o interaction") ///
    msymbol(d)
	
/* An effect of 0.05 represents a 5% higher hospitalization count on average 
to the counties with online as the dominant school mode. */

* save graph for school mode effect
cd "`path_econ80'/outputs/graphs/analysis_gph"
graph save mode_effect_nointeraction, replace



/*
02. Graph marginal effect on school mode w/ interaction
*/

* visualize the marginal effect of school mode
poisson adult_covid_week_avg_100k i.county_dominant_mode i.evttime_plus5 ///
	mobility_retail mobility_grocery mobility_workplaces mobility_residential urban_share ///
	i.state_num#i.evttime_plus5 i.fips ///
	i.county_hybridXevt_plus5 i.county_inpersonXevt_plus5 ///
	i.county_hybridXevt_plus5#c.share_multigen_acs_pp ///
	i.county_inpersonXevt_plus5#c.share_multigen_acs_pp ///
	, vce(robust)

margins, eydx(i.county_hybridXevt_plus5) post
estimates store hybrid_all	

poisson adult_covid_week_avg_100k i.county_dominant_mode i.evttime_plus5 ///
	mobility_retail mobility_grocery mobility_workplaces mobility_residential urban_share ///
	i.state_num#i.evttime_plus5 i.fips ///
	i.county_hybridXevt_plus5 i.county_inpersonXevt_plus5 ///
	i.county_hybridXevt_plus5#c.share_multigen_acs_pp ///
	i.county_inpersonXevt_plus5#c.share_multigen_acs_pp ///
	, vce(robust)
	
margins, eydx(i.county_inpersonXevt_plus5) post
estimates store trad_all	

coefplot (hybrid_all, label("Hybrid") mlcolor(black) mcolor(gs12) ///
    ciopts(recast(rcap) color(gs10))) ///
    (trad_all, label("In-person") mlcolor(black) mcolor(gs2) ///
    ciopts(recast(rcap) color(gs2))), ///
	drop(18.county_hybridXevt_plus5 18.county_inpersonXevt_plus5) ///
    yline(0, lcolor(black) lpattern(dash)) vertical ///
    rename(1.county_hybridXevt_plus5 = 1.county_inpersonXevt_plus5 ///
           2.county_hybridXevt_plus5 = 2.county_inpersonXevt_plus5 ///
           3.county_hybridXevt_plus5 = 3.county_inpersonXevt_plus5 ///
           4.county_hybridXevt_plus5 = 4.county_inpersonXevt_plus5 ///
           5.county_hybridXevt_plus5 = 5.county_inpersonXevt_plus5 ///
           6.county_hybridXevt_plus5 = 6.county_inpersonXevt_plus5 ///
           7.county_hybridXevt_plus5 = 7.county_inpersonXevt_plus5 ///
           8.county_hybridXevt_plus5 = 8.county_inpersonXevt_plus5 ///
           9.county_hybridXevt_plus5 = 9.county_inpersonXevt_plus5 ///
           10.county_hybridXevt_plus5 = 10.county_inpersonXevt_plus5 ///
           11.county_hybridXevt_plus5 = 11.county_inpersonXevt_plus5 ///
           12.county_hybridXevt_plus5 = 12.county_inpersonXevt_plus5 ///
           13.county_hybridXevt_plus5 = 13.county_inpersonXevt_plus5 ///
           14.county_hybridXevt_plus5 = 14.county_inpersonXevt_plus5 ///
           15.county_hybridXevt_plus5 = 15.county_inpersonXevt_plus5 ///
           16.county_hybridXevt_plus5 = 16.county_inpersonXevt_plus5 ///
           17.county_hybridXevt_plus5 = 17.county_inpersonXevt_plus5) ///
    coeflabels(1.county_inpersonXevt_plus5 = "-4" ///
               2.county_inpersonXevt_plus5 = "-3" ///
               3.county_inpersonXevt_plus5 = "-2" ///
               4.county_inpersonXevt_plus5 = "-1" ///
               5.county_inpersonXevt_plus5 = "0" ///
               6.county_inpersonXevt_plus5 = "1" ///
               7.county_inpersonXevt_plus5 = "2" ///
               8.county_inpersonXevt_plus5 = "3" ///
               9.county_inpersonXevt_plus5 = "4" ///
               10.county_inpersonXevt_plus5 = "5" ///
               11.county_inpersonXevt_plus5 = "6" ///
               12.county_inpersonXevt_plus5 = "7" ///
               13.county_inpersonXevt_plus5 = "8" ///
               14.county_inpersonXevt_plus5 = "9" ///
               15.county_inpersonXevt_plus5 = "10" ///
               16.county_inpersonXevt_plus5 = "11" ///
               17.county_inpersonXevt_plus5 = "12") ///
    graphregion(fcolor(white)) ///
	title("The Effect of School Mode on COVID Hospitalization") ///
    xtitle("Weeks from school opening") ///
    ytitle("Average marginal effect w/ interaction") ///
    msymbol(d) ///

/* An effect of 0.05 represents a 5% higher hospitalization count on average 
relative to the counties with online as the dominant school mode. */

* save graph for school mode effect
cd "`path_econ80'/outputs/graphs/analysis_gph"
graph save mode_effect_interaction, replace


* visualize the marginal effect of multigenerational households cond. on mode
poisson adult_covid_week_avg_100k i.county_dominant_mode i.evttime_plus5 ///
	mobility_retail mobility_grocery mobility_workplaces mobility_residential urban_share ///
	i.state_num#i.evttime_plus5 i.fips ///
	i.county_hybridXevt_plus5 i.county_inpersonXevt_plus5 ///
	ib0.county_hybridXevt_plus5#c.share_multigen_acs_pp ///
	ib0.county_inpersonXevt_plus5#c.share_multigen_acs_pp ///
	, vce(robust)

margins county_hybridXevt_plus5, eydx(share_multigen_acs_pp) post 
estimates store hybrid_all

poisson adult_covid_week_avg_100k i.county_dominant_mode i.evttime_plus5 ///
	mobility_retail mobility_grocery mobility_workplaces mobility_residential urban_share ///
	i.state_num#i.evttime_plus5 i.fips ///
	i.county_hybridXevt_plus5 i.county_inpersonXevt_plus5 ///
	i.county_hybridXevt_plus5#c.share_multigen_acs_pp ///
	i.county_inpersonXevt_plus5#c.share_multigen_acs_pp ///
	, vce(robust)

margins county_inpersonXevt_plus5, eydx(share_multigen_acs_pp) post 
estimates store trad_all

coefplot (hybrid_all, label("Hybrid") mlcolor(black) mcolor(gs12) ///
    ciopts(recast(rcap) color(gs10))) ///
    (trad_all, label("In-person") mlcolor(black) mcolor(gs2) ///
    ciopts(recast(rcap) color(gs2))), ///
	drop(0.county_hybridXevt_plus5 0.county_inpersonXevt_plus5 ///
		 18.county_hybridXevt_plus5 18.county_inpersonXevt_plus5) ///
    yline(0, lcolor(black) lpattern(dash)) vertical ///
    rename(1.county_hybridXevt_plus5 = 1.county_inpersonXevt_plus5 ///
           2.county_hybridXevt_plus5 = 2.county_inpersonXevt_plus5 ///
           3.county_hybridXevt_plus5 = 3.county_inpersonXevt_plus5 ///
           4.county_hybridXevt_plus5 = 4.county_inpersonXevt_plus5 ///
           5.county_hybridXevt_plus5 = 5.county_inpersonXevt_plus5 ///
           6.county_hybridXevt_plus5 = 6.county_inpersonXevt_plus5 ///
           7.county_hybridXevt_plus5 = 7.county_inpersonXevt_plus5 ///
           8.county_hybridXevt_plus5 = 8.county_inpersonXevt_plus5 ///
           9.county_hybridXevt_plus5 = 9.county_inpersonXevt_plus5 ///
           10.county_hybridXevt_plus5 = 10.county_inpersonXevt_plus5 ///
           11.county_hybridXevt_plus5 = 11.county_inpersonXevt_plus5 ///
           12.county_hybridXevt_plus5 = 12.county_inpersonXevt_plus5 ///
           13.county_hybridXevt_plus5 = 13.county_inpersonXevt_plus5 ///
           14.county_hybridXevt_plus5 = 14.county_inpersonXevt_plus5 ///
           15.county_hybridXevt_plus5 = 15.county_inpersonXevt_plus5 ///
           16.county_hybridXevt_plus5 = 16.county_inpersonXevt_plus5 ///
           17.county_hybridXevt_plus5 = 17.county_inpersonXevt_plus5) ///
    coeflabels(1.county_inpersonXevt_plus5 = "-4" ///
               2.county_inpersonXevt_plus5 = "-3" ///
               3.county_inpersonXevt_plus5 = "-2" ///
               4.county_inpersonXevt_plus5 = "-1" ///
               5.county_inpersonXevt_plus5 = "0" ///
               6.county_inpersonXevt_plus5 = "1" ///
               7.county_inpersonXevt_plus5 = "2" ///
               8.county_inpersonXevt_plus5 = "3" ///
               9.county_inpersonXevt_plus5 = "4" ///
               10.county_inpersonXevt_plus5 = "5" ///
               11.county_inpersonXevt_plus5 = "6" ///
               12.county_inpersonXevt_plus5 = "7" ///
               13.county_inpersonXevt_plus5 = "8" ///
               14.county_inpersonXevt_plus5 = "9" ///
               15.county_inpersonXevt_plus5 = "10" ///
               16.county_inpersonXevt_plus5 = "11" ///
               17.county_inpersonXevt_plus5 = "12") ///
    graphregion(fcolor(white)) ///
	title("The Effect of Muligen Households and School Mode on Hospitalization") ///
    xtitle("Weeks from school opening") ///
    ytitle("Average marginal effect w/ interaction") ///
    msymbol(d) ///

/* An effect of 0.05 represents a 1 p.p. increase in the share of 
multigenerational households is associated with a 5% increase in the share 
hospitalized on average for given dominant school mode. */

* save graph for interaction effect
cd "`path_econ80'/outputs/graphs/analysis_gph"
graph save multigen_interaction_effect, replace


