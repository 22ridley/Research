clear
set more off

local raw "/Users/sarahridley/Desktop/CSDH/Raw/Test Scores/Mississippi"
local output "/Users/sarahridley/Desktop/CSDH/Raw/Test Scores/Mississippi"

local ms_save_name "MS_AssmtData_20"

local subjects ELA MATH
local grades 3 4 5 6 7 8

// Method 1 
/*

foreach sb of local subjects {
	foreach gr of local grades {
		clear
		import excel "${raw}/MS_OriginalData_2022_all.xlsx", sheet("G`gr' `sb'") firstrow clear
		
		rename *DistrictSchool SchoolName
		
		sort SchoolName
        quietly by SchoolName:  gen dup = cond(_N==1,0,_n)
		drop if dup>0
		drop dup
		
		gen GradeLevel = "G0`gr'"
		gen Subject = "`sb'"		
		
		if (`gr' != 3) | ("`sb'" != "ELA") {
			append using "${output}/`ms_save_name'22.dta"
		}
		save "${output}/`ms_save_name'22.dta", replace
	}
}


sort SchoolName

order SchoolName GradeLevel Subject

*/

// ---------------------------------


// Method 2 /*

foreach gr of local grades {
	clear
	import excel "${raw}/MS_OriginalData_2022_all.xlsx", sheet("G`gr' ELA") firstrow clear
	
	rename * ELA*
	rename *DistrictSchool SchoolName
	rename ELA* *ELA
	
	sort SchoolName
	quietly by SchoolName:  gen dup = cond(_N==1,0,_n)
	drop if dup>0
	drop dup

	keep SchoolName AverageScaleScoreELA Level1PCTELA Level2PCTELA Level3PCTELA Level4PCTELA Level5PCTELA TestTakersELA
	
	save tmp, replace
	
	clear
	import excel "${raw}/MS_OriginalData_2022_all.xlsx", sheet("G`gr' MATH") firstrow clear
	
	rename * MATH*
	rename *DistrictSchool SchoolName 
	rename MATH* *MATH
	
	sort SchoolName
	quietly by SchoolName:  gen dup = cond(_N==1,0,_n)
	drop if dup>0
	drop dup

	keep SchoolName AverageScaleScoreMATH Level1PCTMATH Level2PCTMATH Level3PCTMATH Level4PCTMATH Level5PCTMATH TestTakersMATH
	
	merge 1:1 SchoolName using tmp
	drop _merge
	
	reshape long AverageScaleScore Level1PCT Level2PCT Level3PCT Level4PCT Level5PCT TestTakers, i(SchoolName) j(Subject, string)
	gen GradeLevel = "G0`gr'"
	
	
	if (`gr' != 3) {
		append using "${output}/`ms_save_name'22.dta"
	}
	save "${output}/`ms_save_name'22.dta", replace
}


sort SchoolName GradeLevel Subject

order SchoolName GradeLevel Subject

// --------------------------------- */

replace Subject = strlower(Subject)
// 
replace SchoolName = strupper(SchoolName)
//
replace SchoolName = strproper(SchoolName)
// 
replace SchoolName = stritrim(SchoolName)

destring Level1PCT Level2PCT Level3PCT Level4PCT Level5PCT, replace force

gen ProficientOrAbove_percent = Level4PCT + Level5PCT


save "${output}/`ms_save_name'22.dta", replace

