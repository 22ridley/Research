
// 1: Creating a path

global path "/Users/sarahridley/Desktop/CSDH/Raw/Test Scores/Ohio"
global nces "/Users/sarahridley/Desktop/CSDH/Raw/NCES/NCESPrior"

// Just note that Ohio is a weird case where these files don't have school level data

clear
// 2: Importing data, one specific sheet, with case preserve

import excel "${path}/16-17_DISTRICT_ACHIEVEMENT.xls", sheet("Performance_Indicators") cellrange(a1) firstrow case(preserve)

rename DistrictIRN stateassigneddistrictid 
destring(stateassigneddistrictid ), replace force
destring , replace ignore("NC")

// ** don't do this in your file, this file just has a lot of completely blank rows **
drop if stateassigneddistrictid ==.


// We're just going to be focusing on ELA and math in my example!

egen prof_ELA = rowmean(Reading3rdGrade201617ato Reading4thGrade201617ato Reading5thGrade201617ato Reading6thGrade201617ato Reading7thGrade201617ato Reading8thGrade201617ato)
	
egen prof_Math = rowmean(Math3rdGrade201617atora Math4thGrade201617atora Math5thGrade201617atora Math6thGrade201617atora Math7thGrade201617atora Math8thGrade201617atora)

keep stateassigneddistrictid prof_ELA prof_Math

// ****** /*

// 3: We currently have wide data, but we want long data!

// To go from wide to long: reshape long variableNameStub, i(i) j(j, string * only if string! *)
// To go from long to wide: reshape wide variableNameStub, i(i) j(j, string * only if string! *)	Where j is the new variable name

reshape long prof_, i(stateassigneddistrictid) j(Subject, string)

// Renaming variables! Again, note that for my example, I only included a few variables for simplicity, but you should have a lot more!

rename stateassigneddistrictid StateAssignedDistID
rename prof_ ProficientOrAbove_percent

// 4: Save before merging

save "${path}/OH_AssmtData_2017.dta", replace

// 5: Merging with NCES!

// Remember to use the prior year NCES data! For this 2017 test data, we use the 2016 NCES data:
use "${nces}/NCES_2016_District.dta"

// Find the state_fips for your state, and drop any rows that don't have that fips!
drop if state_fips != 39
rename year year_int
gen year = string(year_int)
split state_leaid, p(-)
drop state_leaid state_leaid1
rename state_leaid2 state_leaid
destring (state_leaid), replace force
drop year_int year

save "${path}/OH_NCES_2016_District.dta", replace

//Reload test score data and merge
use "${path}/OH_AssmtData_2017.dta", clear

gen state_leaid = StateAssignedDistID
merge m:1 state_leaid using "${path}/OH_NCES_2016_District.dta"

rename state_name State
rename state_location StateAbbrev
rename state_fips StateFips
rename ncesdistrictid NCESDistrictID
rename state_leaid State_leaid
rename district_agency_type DistrictType
rename county_name CountyName
rename county_code CountyCode
rename lea_name DistName
gen SchYear = 2017

order State StateAbbrev StateFips NCESDistrictID State_leaid DistrictType CountyName CountyCode SchYear DistName StateAssignedDistID Subject ProficientOrAbove_percent

// ****** 
/*

// 6: How to select rows that did not merge

keep if _merge != 3

*/

// 7: Save again at the end!

save "${path}/OH_AssmtData_2017.csv", replace


// 8: How to run the review code!


// 9: Now make it a loop!

local years 18 19

foreach year of local years {
	clear

	local previousyear = `year' - 1
	import excel "${path}/`previousyear'-`year'_Achievement_District.xlsx", sheet("Performance_Indicators") cellrange(a1) firstrow case(preserve)

	rename DistrictIRN stateassigneddistrictid 
	destring(stateassigneddistrictid ), replace force
	destring , replace ignore("NC")

	drop if stateassigneddistrictid ==.

	if `year' == 18 {
		egen prof_ELA = rowmean(rdGradeReading201718ato thGradeReading201718ato AC AL AR AX)
	
		egen prof_Math = rowmean(rdGradeMath201718atora thGradeMath201718atora AF AO AU BA)
	}
	else if `year' == 19 {
		egen prof_ELA = rowmean(rdGradeReading201819ato thGradeReading201819ato Y AH AN AT)
	
		egen prof_Math = rowmean(rdGradeMath201819atora thGradeMath201819atora AB AK AQ AW)
	}

	keep stateassigneddistrictid prof_ELA prof_Math

	reshape long prof_, i(stateassigneddistrictid) j(Subject, string)

	rename stateassigneddistrictid StateAssignedDistID
	rename prof_ ProficientOrAbove_percent

	save "${path}/OH_AssmtData_20`year'.dta", replace

	
	use "${nces}/NCES_20`previousyear'_District.dta"

	drop if state_fips != 39
	rename year year_int
	gen year = string(year_int)
	split state_leaid, p(-)
	drop state_leaid state_leaid1
	rename state_leaid2 state_leaid
	destring (state_leaid), replace force
	drop year_int year
	save "${path}/OH_NCES_20`previousyear'_District.dta", replace

	use "${path}/OH_AssmtData_20`year'.dta", clear

	gen state_leaid = StateAssignedDistID
	merge m:1 state_leaid using "${path}/OH_NCES_20`previousyear'_District.dta"

	rename state_name State
	rename state_location StateAbbrev
	rename state_fips StateFips
	rename ncesdistrictid NCESDistrictID
	rename state_leaid State_leaid
	rename district_agency_type DistrictType
	rename county_name CountyName
	rename county_code CountyCode
	rename lea_name DistName
	gen SchYear = 20`year'

	order State StateAbbrev StateFips NCESDistrictID State_leaid DistrictType CountyName CountyCode SchYear DistName StateAssignedDistID Subject ProficientOrAbove_percent

	//keep if _merge != 3

	save "${path}/OH_AssmtData_20`year'.csv", replace

}
