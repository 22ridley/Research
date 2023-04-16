clear
set more off

global raw "/Users/sarahridley/Desktop/CSDH/Raw/Test Scores/Wisconsin"

import delimited "${raw}/WI_OriginalData_2016_all.csv", varnames(1) delimit(",") case(preserve)

// dropping variables we won't use, but be sure to document these
drop TEST_RESULT GRADE_GROUP CESA

// force this variable to numeric
destring TEST_RESULT_CODE, replace force

// drop if entry was string ('destring force' turns non-numeric-convertible entries to .)
drop if TEST_RESULT_CODE == .

// main test, not alternate
keep if TEST_GROUP == "Forward"

// only grades 3-8
keep if GRADE_LEVEL < 9

// reshape from long to wide
reshape wide STUDENT_COUNT PERCENT_OF_GROUP, i(DISTRICT_NAME SCHOOL_NAME TEST_SUBJECT GRADE_LEVEL GROUP_BY GROUP_BY_VALUE GROUP_COUNT FORWARD_AVERAGE_SCALE_SCORE) j(TEST_RESULT_CODE)

// generating state vars
gen State = "Wisconsin"
gen StateAbbrev = "WI"
gen AssmtType = "Regular"

// renaming variables
rename DISTRICT_NAME DistName
rename SCHOOL_NAME SchName
rename TEST_SUBJECT Subject
rename CHARTER_IND Charter
rename COUNTY CountyName
rename SCHOOL_YEAR SchYear
rename GRADE_LEVEL GradeLevel
rename GROUP_BY StudentGroup
rename GROUP_BY_VALUE StudentSubGroup
rename FORWARD_AVERAGE_SCALE_SCORE AvgScaleScore
rename GROUP_COUNT StudentGroup_TotalTested
rename DISTRICT_CODE StateAssignedDistID
rename SCHOOL_CODE StateAssignedSchID
rename TEST_GROUP AssmtName
rename AGENCY_TYPE DistrictType

// renaming groups of variables with *
rename STUDENT_COUNT* Lev*_count
rename PERCENT_OF_GROUP* Lev*_percent

// replacing subject variables
replace Subject = "ela" if Subject == "ELA"
replace Subject = "math" if Subject == "Mathematics"
replace Subject = "sci" if Subject == "Science"

// replacing grade level variable
tostring GradeLevel, replace
replace GradeLevel = "G0" + GradeLevel

// force numeric type
destring (StudentGroup_TotalTested Lev1_count Lev1_percent Lev2_count Lev2_percent Lev3_count Lev3_percent Lev4_count Lev4_percent AvgScaleScore), replace force

// make sure that proficiency percents are decimals and replace . counts with 0 before aggregating
local levels 1 2 3 4

foreach lvl of local levels {
	replace Lev`lvl'_percent = 0 if Lev`lvl'_percent == .
	replace Lev`lvl'_percent = Lev`lvl'_percent / 100
	replace Lev`lvl'_count = 0 if Lev`lvl'_count == .
}

// generate prof count, prof rate, and participation rate
gen ProficientOrAbove_percent = Lev3_percent + Lev4_percent
gen ProficientOrAbove_count = Lev3_count + Lev4_count
gen ParticipationRate = (Lev1_count + Lev2_count + Lev3_count + Lev4_count) / StudentGroup_TotalTested

// reordering
order State StateAbbrev DistrictType Charter CountyName SchYear AssmtName AssmtType DistName StateAssignedDistID SchName StateAssignedSchID Subject GradeLevel StudentGroup StudentGroup_TotalTested StudentSubGroup Lev1_count Lev1_percent Lev2_count Lev2_percent Lev3_count Lev3_percent Lev4_count Lev4_percent AvgScaleScore ProficientOrAbove_count ProficientOrAbove_percent ParticipationRate


// ProficientOrAbove_count
// ProficientOrAbove_percent */

