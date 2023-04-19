clear

global raw "/Users/sarahridley/Desktop/CSDH/Participation/Idaho"
global output "/Users/sarahridley/Desktop/CSDH/Participation/Idaho"


// clean enrollment data
import excel "${raw}/Historical-GradeLevel_Enrollment-by-District-or-Charter.xlsx", cellrange(A5) firstrow clear

replace A = A[_n-1] if A == ""
replace B = B[_n-1] if B == ""
drop if C == ""

keep A B C I J K L M N

destring (A M), replace force
rename A DistrictId
rename B DistrictName
rename C SchYear
rename I Gr3
rename J Gr4
rename K Gr5
rename L Gr6
rename M Gr7
rename N Gr8

replace DistrictId = 492 if DistrictName == "ANSER CHARTER SCHOOL"
reshape long Gr, i(DistrictId DistrictName SchYear) j(Grade, string)
rename Gr Enrollment
replace Grade = "Grade "+Grade

save "${output}/ID-Enrollment-Cleaned.dta", replace

/*
local suppr_years 2017 2018
foreach yr of local suppr_years {
	
	local prev = `yr' - 1
	import excel "${raw}/`prev'-`yr'-ISAT-Results.xlsx", sheet("Districts") firstrow clear

	keep if PopulationName == "All Students"
	
	if (`yr' != 2017) {
		keep if Display == "All Grades"
	}
	else {
		keep if GradeLevel == "All Grades"
	}
	
	destring (Participation), replace force

	keep DistrictId DistrictName SubjectName Participation
	
	rename Participation Participation_`yr'
	
	if (`yr' != 2017) {
		merge 1:1 DistrictId SubjectName using "${output}/ID-Participation.xlsx"
		drop _merge
	}
	
	save "${output}/ID-Participation.xlsx", replace
}

*/

local non_suppr_years 2019 2021 2022
foreach yr of local non_suppr_years {
	// enrollment info
	clear
	use "${output}/ID-Enrollment-Cleaned.dta", clear
	
	local prev = `yr' - 1
	keep if SchYear == "`prev'-`yr'"
	
	save temp, replace
	
	// participation info
	if (`yr' == 2019) {
		import excel "${raw}/2019-ISAT-Assessment-Results.xlsx", sheet("Districts") firstrow clear
	}
	else if (`yr' == 2021) {
		import excel "${raw}/2021-ISAT-Assessment-Results.xlsx", sheet("Districts") cellrange(A3) firstrow clear
	}
	else {
		import excel "${raw}/2022-ISAT-Results.xlsx", sheet("Districts") cellrange(A3) firstrow clear
	}
	
	keep if Population == "All Students"
	drop if Grade == "High School"

	keep DistrictId DistrictName SubjectName Grade TestedRate

	destring (TestedRate DistrictId), replace force
	replace TestedRate = TestedRate / 100
	
	merge m:n DistrictId Grade using temp
	drop _merge
	
	drop if SubjectName == ""
	
	gen TestedCount = TestedRate * Enrollment
	
	sort DistrictId DistrictName SubjectName Grade
}
