clear
set more off
pause on
capture log close

********************************************************************************
* CHANGE PROJECT PATH HERE ⸜(ˆᗜˆ˵ )⸝
local path_econ80 "/Users/thomasli/Desktop/econ-80-paper"
********************************************************************************

* set up log file
log using "`path_econ80'/outputs/logs/03_graph.log", replace

* program to analyze merged data for econ 80
* author: Ganqi Li (ganqi.li.25@dartmouth.edu)
* updated: Nov 26, 2024 



/*
00. Datasets required

Data: 
1. merged data in "/data/merged": e80_merged.dta
*/

* open merged data
cd "`path_econ80'/data/merged"
use e80_merged, clear

* subset data to entire school year, or 36 weeks
keep if (event_time >= -5) & (event_time <= 36)

* check data availability by week
tab event_time if adult_covid_week_avg_100k != .

* shift event time by 5 so it can be controlled as indicator 
gen evttime_plus5 = event_time + 5

* keep data before end of year
// keep if week_sunday <= date("2020-12-31", "YMD")
summ week_sunday, format



/*
01. Explore correlations of multi shares
*/

preserve
collapse (mean) share_multigen_acs share_multigen_proxy, by(fips)
twoway scatter share_multigen_proxy share_multigen_acs, ///
	xtitle("Share of multigenerational households (ACS)") ///
	ytitle("Share of households with both ages 5-18 and 65+") ///
	xscale(range(0 0.13)) ///
	yscale(range(0 0.05)) ///
	xlabel(0(0.01)0.13) ///
	ylabel(0(0.01)0.05) ///

cd "`path_econ80'/outputs/graphs/graph_gph"
graph save acs_proxy_corr, replace
restore



/*
02. Explore hospitalization across different quartiles of multigen
*/

* plot trend of hospitalization for multigen quartiles (ACS)
preserve
collapse (mean) mean_covid = adult_covid_week_avg_100k (semean) ///
	se_covid = adult_covid_week_avg_100k, by(quartile_multigen_acs event_time)
drop if mean_covid == .

* calculate std error caps
gen upper = mean_covid + se_covid * 1.96
gen lower = mean_covid - se_covid * 1.96

local offset_inner 0.05
local offser_outer 0.1
gen evttime_offset = event_time - `offset_inner' - `offser_outer' ///
	if quartile_multigen_acs == 1
replace evttime_offset = event_time - `offset_inner' ///
	if quartile_multigen_acs == 2
replace evttime_offset = event_time + `offset_inner' ///
	if quartile_multigen_acs == 3
replace evttime_offset = event_time + `offset_inner' + `offser_outer' ///
	if quartile_multigen_acs == 4

twoway ///
    (line mean_covid evttime_offset if quartile_multigen_acs == 1, ///
        lcolor(blue) lpattern(shortdash)) ///
    (line mean_covid evttime_offset if quartile_multigen_acs == 2, ///
        lcolor(purple) lpattern(dash)) ///   
    (line mean_covid evttime_offset if quartile_multigen_acs == 3, ///
        lcolor(orange) lpattern(longdash)) ///  
    (line mean_covid evttime_offset if quartile_multigen_acs == 4, ///
        lcolor(red) lpattern(solid)), ///           
	xline(16.5, lwidth(6.5) lc(gs14) lpattern(solid)) ///
	text(1 16.5 "Winter break", place(center) size(small) color(black)) /// 
	xline(0, lwidth(3.25) lc(gs14) lpattern(solid)) ///
	text(1 0 "First week", place(center) size(small) color(black)) ///
    legend(order(1 "1st quartile" 2 "2nd quartile" 3 "3rd quartile" 4 "4th quartile") ///
           region(lstyle(none)) pos(6) col(4)) ///
    ytitle("Adult hospitalization per 100,000 residents") ///
    xtitle("Weeks from school opening") ///
    title("Hospitalization by Share of Multigenerational Households (ACS)") ///
	nodraw
	
cd "`path_econ80'/outputs/graphs/graph_gph"
graph save hospitalization_by_multigen_acs, replace
restore 

* plot trend of hospitalization for multigen quartiles (Proxy)
preserve
collapse (mean) mean_covid = adult_covid_week_avg_100k (semean) ///
	se_covid = adult_covid_week_avg_100k, by(quartile_multigen_proxy event_time)
drop if mean_covid == .

* calculate std error caps
gen upper = mean_covid + se_covid * 1.96
gen lower = mean_covid - se_covid * 1.96

local offset_inner 0.05
local offser_outer 0.1
gen evttime_offset = event_time - `offset_inner' - `offser_outer' ///
	if quartile_multigen_proxy == 1
replace evttime_offset = event_time - `offset_inner' ///
	if quartile_multigen_proxy == 2
replace evttime_offset = event_time + `offset_inner' ///
	if quartile_multigen_proxy == 3
replace evttime_offset = event_time + `offset_inner' + `offser_outer' ///
	if quartile_multigen_proxy == 4

twoway ///
    (line mean_covid evttime_offset if quartile_multigen_proxy == 1, ///
        lcolor(blue) lpattern(shortdash)) ///
    (line mean_covid evttime_offset if quartile_multigen_proxy == 2, ///
        lcolor(purple) lpattern(dash)) ///   
    (line mean_covid evttime_offset if quartile_multigen_proxy == 3, ///
        lcolor(orange) lpattern(longdash)) ///  
    (line mean_covid evttime_offset if quartile_multigen_proxy == 4, ///
        lcolor(red) lpattern(solid)), ///                
    legend(order(1 "1st quartile" 2 "2nd quartile" 3 "3rd quartile" 4 "4th quartile") ///
           region(lstyle(none)) pos(6) col(4)) ///
	xline(16.5, lwidth(6.5) lc(gs14) lpattern(solid)) ///
	text(1 16.5 "Winter break", place(center) size(small) color(black)) /// 
	xline(0, lwidth(3.25) lc(gs14) lpattern(solid)) ///
	text(1 0 "First week", place(center) size(small) color(black)) ///
    ytitle("Adult hospitalization per 100,000 residents") ///
    xtitle("Weeks from school opening") ///
    title("Hospitalization by Share of Households with Ages 5-18 and 65+") ///
	nodraw

cd "`path_econ80'/outputs/graphs/graph_gph"
graph save hospitalization_by_multigen_proxy, replace
restore 



/*
03. Explore hospitalization across different modes
*/

* graph hospitalization by weekly dominant mode
preserve
* collapse mean hospitalization on county dominant mode and event time
collapse (mean) mean_covid = adult_covid_week_avg_100k (semean) ///
	se_covid = adult_covid_week_avg_100k, by(weekly_dominant_mode event_time)
drop if mean_covid == .
sort weekly_dominant_mode event_time

* offset for better visualization
local offset 0.13
gen evttime_offset = event_time
replace evttime_offset = event_time + `offset' if weekly_dominant_mode == 2
replace evttime_offset = event_time - `offset' if weekly_dominant_mode == 0

* calculate std error caps
gen upper = mean_covid + se_covid * 1.96
gen lower = mean_covid - se_covid * 1.96

twoway ///
    (rcap lower upper evttime_offset if weekly_dominant_mode == 0, ///
        lcolor(gs10)) ///
    (line mean_covid evttime_offset if weekly_dominant_mode == 0, ///
        lcolor(gs10) lpattern(shortdash)) ///
    (rcap lower upper evttime_offset if weekly_dominant_mode == 1, ///
        lcolor(gs6)) ///
    (line mean_covid evttime_offset if weekly_dominant_mode == 1, ///
        lcolor(gs6) lpattern(dash)) ///
    (rcap lower upper evttime_offset if weekly_dominant_mode == 2, ///
        lcolor(gs2)) ///
    (line mean_covid evttime_offset if weekly_dominant_mode == 2, ///
        lcolor(gs2) lpattern(longdash)), ///
	xline(16.5, lwidth(6.5) lc(gs14) lpattern(solid)) ///
	text(1 16.5 "Winter break", place(center) size(small) color(black)) /// 
	xline(0, lwidth(3.25) lc(gs14) lpattern(solid)) ///
	text(1 0 "First week", place(center) size(small) color(black)) ///
    legend(order(2 "Virtual" 4 "Hybrid" 6 "In-person")) ///
    ytitle("Adult hospitalization per 100,000 residents") ///
    xtitle("Weeks from school opening") ///
    title("Mean Adult Hospitalization Level by Weekly Dominant School Mode") ///
    graphregion(color(white)) ///
    note("Note: Error bars represent 95% confidence intervals.") ///
    xlabel(-5(5)36) ///
    xscale(range(-5.5 36.5))

* save trend graph
cd "`path_econ80'/outputs/graphs/graph_gph"
graph save hospitalization_by_weekly_mode_rcap, replace
restore

* graph hospitalization by county dominant mode
preserve
* collapse mean hospitalization on county dominant mode and event time
collapse (mean) mean_covid = adult_covid_week_avg_100k (semean) ///
	se_covid = adult_covid_week_avg_100k, by(county_dominant_mode event_time)
drop if mean_covid == .
sort county_dominant_mode event_time

* offset for better visualization
local offset 0.13
gen evttime_offset = event_time
replace evttime_offset = event_time + `offset' if county_dominant_mode == 2
replace evttime_offset = event_time - `offset' if county_dominant_mode == 0

* calculate std error caps
gen upper = mean_covid + se_covid * 1.96
gen lower = mean_covid - se_covid * 1.96

* plot line graphs with 95% confidence intervals
twoway ///
    (rcap lower upper evttime_offset if county_dominant_mode == 0, ///
        lcolor(gs10)) ///
    (line mean_covid evttime_offset if county_dominant_mode == 0, ///
        lcolor(gs10) lpattern(shortdash)) ///
    (rcap lower upper evttime_offset if county_dominant_mode == 1, ///
        lcolor(gs6)) ///
    (line mean_covid evttime_offset if county_dominant_mode == 1, ///
        lcolor(gs6) lpattern(dash)) ///
    (rcap lower upper evttime_offset if county_dominant_mode == 2, ///
        lcolor(gs2)) ///
    (line mean_covid evttime_offset if county_dominant_mode == 2, ///
        lcolor(gs2) lpattern(longdash)), /// 
	xline(0, lwidth(3.25) lc(gs14) lpattern(solid)) ///
	text(1 0 "First week", place(center) size(small) color(black)) ///
	xline(16.5, lwidth(6.5) lc(gs14) lpattern(solid)) ///
	text(1 16.5 "Winter break", place(center) size(small) color(black)) /// 
    legend(order(2 "Virtual" 4 "Hybrid" 6 "In-person")) ///
    ytitle("Adult hospitalization per 100,000 residents") ///
    xtitle("Weeks from school opening") ///
    title("Mean Adult Hospitalization Level by County Dominant School Mode") ///
    graphregion(color(white)) ///
	note("Note: Error bars represent 95% confidence intervals.") ///
	xlabel(-5(5)36) /// 
    xscale(range(-5.5 36.5))

* save trend graph
cd "`path_econ80'/outputs/graphs/graph_gph"
graph save hospitalization_by_county_mode_rcap, replace
restore

* create only line graph and no rcaps
preserve
collapse (mean) adult_covid_week_avg_100k, by(county_dominant_mode event_time)
drop if adult_covid_week_avg_100k == .
sort county_dominant_mode event_time

* set as panel data structure for change in hospitalization 
tsset county_dominant_mode event_time
gen d_adult_covid_week_avg_100k = D.adult_covid_week_avg_100k

twoway (line adult_covid_week_avg_100k event_time if county_dominant_mode == 0, ///
		lcolor(blue) lpattern(shortdash)) ///
	(line adult_covid_week_avg_100k event_time if county_dominant_mode == 1, ///
		lcolor(orange) lpattern(dash)) ///
	(line adult_covid_week_avg_100k event_time if county_dominant_mode == 2, ///
		lcolor(red) lpattern(longdash)), ///
	legend(order(1 "Virtual" 2 "Hybrid" 3 "In-person")) ///
	ytitle("Adult hospitalization per 100,000 residents") ///
	xtitle("Weeks from school opening") ///
	title("Mean Adult Hospitalization Level by School Mode") ///
	graphregion(color(white)) ///
	nodraw

* save trend graph
cd "`path_econ80'/outputs/graphs/graph_gph"
graph save hospitalization_by_mode, replace
	
twoway (line d_adult_covid_week_avg_100k event_time if county_dominant_mode == 0, ///
		lcolor(blue) lpattern(shortdash)) ///
	(line d_adult_covid_week_avg_100k event_time if county_dominant_mode == 1, ///
		lcolor(orange) lpattern(dash)) ///
	(line d_adult_covid_week_avg_100k event_time if county_dominant_mode == 2, ///
		lcolor(red) lpattern(longdash)), ///
	legend(order(1 "Virtual" 2 "Hybrid" 3 "In-person")) ///
	ytitle("Change in adult hospitalization per 100,000 residents") ///
	xtitle("Weeks from school opening") ///
	title("Change in Mean Adult Hospitalization Level by School Mode") ///
	graphregion(color(white)) ///
	nodraw

graph save d_hospitalization_by_mode, replace
restore



/*
04. Explore relationship between household and school mode
*/

local vars share_5_to_18 share_50_above share_65_above ///
	urban_share share_inperson share_hybrid share_virtual

foreach var in `vars' {
    gen `var'_pp = `var' * 100
}

preserve
keep if event_time == 0
gen firstweek_virtual = (weekly_dominant_mode == 0)
corr share_multigen_acs_pp adult_covid_week_avg_100k firstweek_virtual ///
	share_virtual share_65_above_pp share_50_above_pp share_5_to_18_pp
corr share_multigen_acs_pp  share_50_above_pp share_5_to_18_pp ///
	adult_covid_week_avg_100k firstweek_virtual

* see effect of multigen on school mode
logit firstweek_virtual share_multigen_acs_pp
logit firstweek_virtual share_multigen_acs_pp ///
	share_50_above_pp share_5_to_18_pp urban_share_pp

codebook fips
su firstweek_virtual if share_multigen_acs_pp == .
su firstweek_virtual if share_multigen_acs_pp != .

* create summary statistics for the first week
su adult_covid_week_avg_100k urban_share_pp share_multigen_acs_pp ///
	share_50_above_pp share_5_to_18_pp /// 
	share_inperson_pp share_hybrid_pp share_virtual_pp
restore


* graph multigen shares by school mode
preserve
collapse (mean) share_multigen_acs share_multigen_proxy county_dominant_mode, by(fips)

collapse (mean) mean_acs = share_multigen_acs mean_proxy = share_multigen_proxy ///
	(semean) se_acs = share_multigen_acs se_proxy = share_multigen_proxy, ///
	by(county_dominant_mode)

* create high and low error bounds for 95% confidence interval
gen rcap_h_acs = mean_acs + 1.96 * se_acs
gen rcap_l_acs = mean_acs - 1.96 * se_acs 

gen rcap_h_proxy = mean_proxy + 1.96 * se_acs
gen rcap_l_proxy = mean_proxy - 1.96 * se_acs

* Create a combined plot with both variables (share_multigen_acs and share_multigen_proxy)
twoway (rcap rcap_l_acs rcap_h_acs county_dominant_mode, ///
	lcolor(blue) lwidth(medium)) ///
	(scatter mean_acs county_dominant_mode, mcolor(blue) msize(medium)), ///
	legend(order(1 "95% confidence interval (ACS)") position(6)) ///
		ytitle("Share of multigenerational households") ///
		xtitle("Dominant county school mode") ///
			xlabel(0 "Virtual" 1 "Hybrid" 2 "In-Person", nogrid) ///
			ylabel(0.041(0.001)0.047) ///
				xscale(range(-0.1 2.1)) ///
				yscale(range(0.041 0.047)) ///
					nodraw
	   
* save graph on household and school mode relationship
cd "`path_econ80'/outputs/graphs/graph_gph"
graph save multigen_mode_acs, replace
	   
twoway (rcap rcap_l_proxy rcap_h_proxy county_dominant_mode, ///
	lcolor(red) lwidth(medium) lpattern(dash)) ///
    (scatter mean_proxy county_dominant_mode, mcolor(red) msize(medium)), ///
	legend(order(1 "95% confidence interval (ages 5-18 and 65+)") position(6)) ///
		xtitle("Dominant county school mode") ///
		xlabel(0 "Virtual" 1 "Hybrid" 2 "In-Person", nogrid) ///
		ylabel(0.015(0.001)0.021) ///
			xscale(range(-0.1 2.1)) ///
			yscale(range(0.015 0.021)) ///
				nodraw 

graph save multigen_mode_proxy, replace

* save combined graph for acs and proxy
graph combine "`path_econ80'/outputs/graphs/graph_gph/multigen_mode_acs.gph" ///
	"`path_econ80'/outputs/graphs/graph_gph/multigen_mode_proxy.gph", ///
	row(1) col(2) ///
	title("Share of Multigenerational Households across Counties") ///
	ysize(6) xsize(8) ///
	nodraw

graph save combined_multigen_mode, replace
restore


* collapse multigen by fips and mode
preserve
collapse (mean) share_multigen_acs share_multigen_proxy, by(fips county_dominant_mode)
su share_multigen_acs share_multigen_proxy
bysort county_dominant_mode: gen obs_count = _N

* create jittered x-values
set seed 12345
gen jittered_mode = county_dominant_mode + (runiform() - 0.5) * 0.5

* scatter multigen acs ratios
twoway /// 
    (scatter share_multigen_acs jittered_mode if county_dominant_mode == 0, /// 
        msymbol(circle_hollow) /// 
        mcolor(blue) ///
        msize(medium)) ///  
    (scatter share_multigen_acs jittered_mode if county_dominant_mode == 1, /// 
        msymbol(circle_hollow) /// 
        mcolor(purple) ///
        msize(medium)) /// 
    (scatter share_multigen_acs jittered_mode if county_dominant_mode == 2, /// 
        msymbol(circle_hollow) /// 
        mcolor(red) ///
        msize(medium)), /// 
    ytitle("Share of multigenerational households") /// 
    xtitle("Dominant county school mode") /// 
    xlabel(0 "Virtual" 1 "Hybrid" 2 "In-Person", nogrid) /// 
    ylabel(0(0.02)0.14, format(%5.3f)) /// 
    xscale(range(-0.1 2.1)) ///
	yscale(range(0 0.14)) ///
    graphregion(color(white)) /// 
    title("Share of Multigenerational Households (ACS)") ///
	legend(off)
	
cd "`path_econ80'/outputs/graphs/graph_gph"
graph save acs_multigen_scatter, replace

* scatter multigen proxy ratios
twoway /// 
    (scatter share_multigen_proxy jittered_mode if county_dominant_mode == 0, /// 
        msymbol(circle_hollow) /// 
        mcolor(blue) ///
        msize(medium)) ///  
    (scatter share_multigen_proxy jittered_mode if county_dominant_mode == 1, /// 
        msymbol(circle_hollow) /// 
        mcolor(purple) ///
        msize(medium)) /// 
    (scatter share_multigen_proxy jittered_mode if county_dominant_mode == 2, /// 
        msymbol(circle_hollow) /// 
        mcolor(red) ///
        msize(medium)), /// 
    ytitle("Share of multigenerational households") /// 
    xtitle("Dominant county school mode") ///  
    xlabel(0 "Virtual" 1 "Hybrid" 2 "In-Person", nogrid) /// 
    ylabel(0(0.01)0.05, format(%5.3f)) /// // ylabel(0(0.02)0.14, format(%5.3f))
    xscale(range(-0.1 2.1)) /// 
	yscale(range(0 0.05)) /// // yscale(range(0 0.14)) 
    graphregion(color(white)) /// 
    title("Share of Households with Ages 5-18 and 65+") ///
	legend(off)

graph save proxy_multigen_scatter, replace
restore


