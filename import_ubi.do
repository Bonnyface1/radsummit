* import_ubi.do
*
* 	Imports and aggregates "Markets" (ID: ubi) data.
*
*	Inputs:  "C:/Users/BMwangi/Downloads/Markets_WIDE.csv"
*	Outputs: "C:/Users/BMwangi/Downloads/Markets.dta"
*
*	Output by SurveyCTO March 2, 2020 2:27 PM.

* initialize Stata
clear all
set more off
set mem 100m

* initialize workflow-specific parameters
*	Set overwrite_old_data to 1 if you use the review and correction
*	workflow and allow un-approving of submissions. If you do this,
*	incoming data will overwrite old data, so you won't want to make
*	changes to data in your local .dta file (such changes can be
*	overwritten with each new import).
local overwrite_old_data 0

* initialize form-specific parameters
local csvfile "C:/Users/BMwangi/Downloads/Markets_WIDE.csv"
local dtafile "C:/Users/BMwangi/Downloads/Markets.dta"
local corrfile "C:/Users/BMwangi/Downloads/Markets_corrections.csv"
local note_fields1 ""
local text_fields1 "deviceid subscriberid simid devicephonenum username duration caseid a1b_market_nam a2_sublocation a3_location a7a_fo1_nam a7b_fo2_nam a7c_fo3_nam a7d_fo4_nam a7d_fo5_nam active_mon active_tue"
local text_fields2 "active_wed active_thur active_fri active_sat active_sun grp_vr_count v_index_* village_* gen_observe grains_count grain_index_* grains_nam_* grain_sellers_count_* seller_index_* unit_filter_*"
local text_fields3 "grain_altunit_* veges_count veg_index_* veg_nam_* veg_sellers_count_* veg_sllr_index_* veg_unit_filter_* veg_altunit_* meats_count meat_index_* meat_nam_* meat_sellers_count_* meat_sllr_index_*"
local text_fields4 "meat_unit_filter_* meat_altunit_* fruits_count fruit_index_* fruit_nam_* fruit_sellers_count_* fruit_sllr_index_* fruit_unit_filter_* fruit_altunit_* livestock_count lvstk_index_* lvstk_nam_*"
local text_fields5 "lvstk_sellers_count_* lvstk_sllr_index_* lvstk_var_* lvstk_varieties_count_* lvstk_varindex_* lvstk_varnam_* lvstk_unit_filter_* hardware_count hrdwr_index_* hrdwr_nam_* hrdwr_sellers_count_*"
local text_fields6 "hrdwr_sllr_index_* hrdwr_unit_filter_* hrdwr_altunit_* duka_var duka_products_count duka_index_* duka_nam_* duka_sellers_count_* duka_sllr_index_* duka_unit_filter_* duka_altunit_* food_var"
local text_fields7 "food_products_count food_index_* food_nam_* food_sellers_count_* food_sllr_index_* food_unit_filter_* food_altunit_* fuel_products_count fuel_index_* fuel_nam_* fuel_sellers_count_* fuel_sllr_index_*"
local text_fields8 "fuel_altunit_* health_products_count health_index_* health_nam_* health_sellers_count_* health_sllr_index_* health_unit_filter_* health_altunit_* hh_products_count hh_index_* hh_nam_*"
local text_fields9 "hh_sellers_count_* hh_sllr_index_* hh_unit_filter_* hh_altunit_* farm_products_count farm_index_* farm_nam_* farm_sellers_count_* farm_sllr_index_* farm_altunit_* other_products_count other_index_*"
local text_fields10 "other_nam_* other_sellers_count_* other_sllr_index_* other_unit_filter_* other_altunit_* instanceid"
local date_fields1 "a6_date"
local datetime_fields1 "submissiondate starttime endtime"

disp
disp "Starting import of: `csvfile'"
disp

* import data from primary .csv file
insheet using "`csvfile'", names clear

foreach x of varlist * {
   capture confirm string variable `x'
   if !_rc {
qui destring `x', replace
}
}


* drop extra table-list columns
cap drop reserved_name_for_field_*
cap drop generated_table_list_lab*

* continue only if there's at least one row of data to import
if _N>0 {
	* drop note fields (since they don't contain any real data)
	forvalues i = 1/100 {
		if "`note_fields`i''" ~= "" {
			drop `note_fields`i''
		}
	}
	
	* format date and date/time fields
	forvalues i = 1/100 {
		if "`datetime_fields`i''" ~= "" {
			foreach dtvarlist in `datetime_fields`i'' {
				cap unab dtvarlist : `dtvarlist'
				if _rc==0 {
					foreach dtvar in `dtvarlist' {
						tempvar tempdtvar
						rename `dtvar' `tempdtvar'
						gen double `dtvar'=.
						cap replace `dtvar'=clock(`tempdtvar',"MDYhms",2025)
						* automatically try without seconds, just in case
						cap replace `dtvar'=clock(`tempdtvar',"MDYhm",2025) if `dtvar'==. & `tempdtvar'~=""
						format %tc `dtvar'
						drop `tempdtvar'
					}
				}
			}
		}
		if "`date_fields`i''" ~= "" {
			foreach dtvarlist in `date_fields`i'' {
				cap unab dtvarlist : `dtvarlist'
				if _rc==0 {
					foreach dtvar in `dtvarlist' {
						tempvar tempdtvar
						rename `dtvar' `tempdtvar'
						gen double `dtvar'=.
						cap replace `dtvar'=date(`tempdtvar',"MDY",2025)
						format %td `dtvar'
						drop `tempdtvar'
					}
				}
			}
		}
	}

	* ensure that text fields are always imported as strings (with "" for missing values)
	* (note that we treat "calculate" fields as text; you can destring later if you wish)
	tempvar ismissingvar
	quietly: gen `ismissingvar'=.
	forvalues i = 1/100 {
		if "`text_fields`i''" ~= "" {
			foreach svarlist in `text_fields`i'' {
				cap unab svarlist : `svarlist'
				if _rc==0 {
					foreach stringvar in `svarlist' {
						quietly: replace `ismissingvar'=.
						quietly: cap replace `ismissingvar'=1 if `stringvar'==.
						cap tostring `stringvar', format(%100.0g) replace
						cap replace `stringvar'="" if `ismissingvar'==1
					}
				}
			}
		}
	}
	quietly: drop `ismissingvar'


	* consolidate unique ID into "key" variable
	replace key=instanceid if key==""
	drop instanceid


	* label variables
	label variable key "Unique submission ID"
	cap label variable submissiondate "Date/time submitted"
	cap label variable formdef_version "Form version used on device"
	cap label variable review_status "Review status"
	cap label variable review_comments "Comments made during review"
	cap label variable review_corrections "Corrections made during review"


	label variable entry "Is this first or second entry?"
	note entry: "Is this first or second entry?"
	label define entry 1 "Entry One (1)" 2 "Entry Two (2)"
	label values entry entry

	label variable clerk "Name of data entry clerk"
	note clerk: "Name of data entry clerk"
	label define clerk 1 "Kigen" 2 "Anjeline" 3 "Sacramenta" 91176 "Emmanuel Steve Olela" 91988 "Josephine Otieno" 91687 "Vincent Koima Kandagor" 90116 "Mildred Atamba Maluti" 92026 "Kipchilis Janet Jesang" 90848 "Margret Akumu Aketch" 92028 "Lorna Chepngetich Mungot" 92034 "Onesmus Kiprotich Cheruiyot" 92030 "Melvin Kipkurui Langat" 90893 "Grace Mumbua Willy" 91751 "Wechuli Dinah Ayoma" 92008 "Benard Langat" 92009 "Felista Tanui"
	label values clerk clerk

	label variable a1a_market_id "Market ID:"
	note a1a_market_id: "Market ID:"

	label variable a1b_market_nam "Market Name:"
	note a1b_market_nam: "Market Name:"

	label variable a2_sublocation "Sublocation:"
	note a2_sublocation: "Sublocation:"

	label variable a3_location "Location:"
	note a3_location: "Location:"

	label variable a5_county "County:"
	note a5_county: "County:"
	label define a5_county 1 "Siaya" 2 "Bomet"
	label values a5_county a5_county

	label variable a4_subcounty "Subcounty:"
	note a4_subcounty: "Subcounty:"
	label define a4_subcounty 1 "Gem" 2 "Bondo" 3 "Bomet East" 4 "Sotik"
	label values a4_subcounty a4_subcounty

	label variable gps_long "Longitude"
	note gps_long: "Longitude"

	label variable gps_lat "Latitude"
	note gps_lat: "Latitude"

	label variable gps_acc "Accuracy (metres)"
	note gps_acc: "Accuracy (metres)"

	label variable gps_alt "Altitude"
	note gps_alt: "Altitude"

	label variable a6_date "Date of Survey:"
	note a6_date: "Date of Survey:"

	label variable a7a_fo1_nam "Field Officer Name 1:"
	note a7a_fo1_nam: "Field Officer Name 1:"

	label variable a8a_fo1_id "Field Officer ID 1:"
	note a8a_fo1_id: "Field Officer ID 1:"

	label variable a7b_fo2_nam "Field Officer Name 2:"
	note a7b_fo2_nam: "Field Officer Name 2:"

	label variable a8b_fo2_id "Field Officer ID 2:"
	note a8b_fo2_id: "Field Officer ID 2:"

	label variable a7c_fo3_nam "Field Officer Name 3:"
	note a7c_fo3_nam: "Field Officer Name 3:"

	label variable a8c_fo3_id "Field Officer ID 3:"
	note a8c_fo3_id: "Field Officer ID 3:"

	label variable a7d_fo4_nam "Field Officer Name 4:"
	note a7d_fo4_nam: "Field Officer Name 4:"

	label variable a8d_fo4_id "Field Officer ID 4:"
	note a8d_fo4_id: "Field Officer ID 4:"

	label variable a7d_fo5_nam "Field Officer Name 5:"
	note a7d_fo5_nam: "Field Officer Name 5:"

	label variable a8d_fo5_id "Field Officer ID 5:"
	note a8d_fo5_id: "Field Officer ID 5:"

	label variable active_mon "Monday"
	note active_mon: "Monday"

	label variable active_tue "Tuesday"
	note active_tue: "Tuesday"

	label variable active_wed "Wednesday"
	note active_wed: "Wednesday"

	label variable active_thur "Thursday"
	note active_thur: "Thursday"

	label variable active_fri "Friday"
	note active_fri: "Friday"

	label variable active_sat "Saturday"
	note active_sat: "Saturday"

	label variable active_sun "Sunday"
	note active_sun: "Sunday"

	label variable village_count "How many villages are served by this market?"
	note village_count: "How many villages are served by this market?"

	label variable gen_observe "General observation"
	note gen_observe: "General observation"

	label variable airtime_nbr "11c. What is the phone number of the market head or his/her representative?"
	note airtime_nbr: "11c. What is the phone number of the market head or his/her representative?"

	label variable airtime_nbr_confirm "Please re-enter the phone number"
	note airtime_nbr_confirm: "Please re-enter the phone number"

	label variable b32a_pointvend "B32a. What is the total number of vendors selling dry maize at the market point?"
	note b32a_pointvend: "B32a. What is the total number of vendors selling dry maize at the market point?"

	label variable b32b_vistvend "B32b. What is the total number of vendors selling dry maize operating at the mar"
	note b32b_vistvend: "B32b. What is the total number of vendors selling dry maize operating at the market point on the visit day?"

	label variable b32c_lorryvend "B32c. How many of these vendors have lorries?"
	note b32c_lorryvend: "B32c. How many of these vendors have lorries?"

	label variable b32d_storevend "B32d. How many of these vendors have stores?"
	note b32d_storevend: "B32d. How many of these vendors have stores?"

	label variable b32e_stallvend "B32e. How many of these vendors with small stalls/mamas selling from sacks?"
	note b32e_stallvend: "B32e. How many of these vendors with small stalls/mamas selling from sacks?"

	label variable lvstk_avail "Does the market have livestocks?"
	note lvstk_avail: "Does the market have livestocks?"
	label define lvstk_avail 1 "Yes" 2 "Livestock not sold in the market" 3 "Yes, but there was an outbreak of disease" 4 "Yes, but on a different day other than visit day"
	label values lvstk_avail lvstk_avail

	label variable d7a_pointcarpent "D7a. What is the total number of carpenters at the market point?"
	note d7a_pointcarpent: "D7a. What is the total number of carpenters at the market point?"

	label variable d7b_vistcarpent "D7b. What is the total number of carpenters operating at the market point on the"
	note d7b_vistcarpent: "D7b. What is the total number of carpenters operating at the market point on the visit day?"

	label variable d7c_pointfurnit "D7c. What is the total number of furniture vendors at the market point? (NOTE: E"
	note d7c_pointfurnit: "D7c. What is the total number of furniture vendors at the market point? (NOTE: Exclude carpenters)"

	label variable d7d_vistfurnit "D7d. What is the total number of furniture vendors operating at the market point"
	note d7d_vistfurnit: "D7d. What is the total number of furniture vendors operating at the market point on the visit day? (NOTE: Exclude carpenters)"

	label variable d7e_pointhware "D7e. What is the total number of hardware shops at the market point?"
	note d7e_pointhware: "D7e. What is the total number of hardware shops at the market point?"

	label variable d7f_visthware "D7f. What is the total number of hardware shops operating at the market point on"
	note d7f_visthware: "D7f. What is the total number of hardware shops operating at the market point on the visit day?"

	label variable d7g_pointconstruct "D7g. What is the total number of hardware/construction material vendors at the m"
	note d7g_pointconstruct: "D7g. What is the total number of hardware/construction material vendors at the market point? (NOTE: Exclude hardware shops)"

	label variable d7h_vistconstruct "D7h. What is the total number of hardware/construction material vendors operatin"
	note d7h_vistconstruct: "D7h. What is the total number of hardware/construction material vendors operating at the market point on the visit day? (NOTE: Exclude hardware shops)"

	label variable duka_var "Duka items"
	note duka_var: "Duka items"

	label variable food_var "Food variety"
	note food_var: "Food variety"



	capture {
		foreach rgvar of varlist village_* {
			label variable `rgvar' "What is the name of village \${v_index} that is served by this market?"
			note `rgvar': "What is the name of village \${v_index} that is served by this market?"
		}
	}

	capture {
		foreach rgvar of varlist grain_type_* {
			label variable `rgvar' "Seller type \${seller_index} of \${grains_nam}"
			note `rgvar': "Seller type \${seller_index} of \${grains_nam}"
			label define `rgvar' 1 "Market vendor" 2 "Street stall" 3 "Cart vendor" 4 "Small shop" 5 "Supermarket" 6 "Other" 8 "Item not sold in the market" 9 "No vendor of this item consented to the interview" 10 "No other seller"
			label values `rgvar' `rgvar'
		}
	}

	capture {
		foreach rgvar of varlist grain_unit_* {
			label variable `rgvar' "Unit of \${grains_nam}"
			note `rgvar': "Unit of \${grains_nam}"
			label define `rgvar' 1 "1 KG" 2 "2 KG" -222 "Alternative Unit"
			label values `rgvar' `rgvar'
		}
	}

	capture {
		foreach rgvar of varlist grain_altunit_* {
			label variable `rgvar' "Alternative Unit of \${grains_nam}"
			note `rgvar': "Alternative Unit of \${grains_nam}"
		}
	}

	capture {
		foreach rgvar of varlist grain_price_* {
			label variable `rgvar' "Price of \${grains_nam}"
			note `rgvar': "Price of \${grains_nam}"
		}
	}

	capture {
		foreach rgvar of varlist grain_wtg_* {
			label variable `rgvar' "Exact Weight (KG) of \${grains_nam}"
			note `rgvar': "Exact Weight (KG) of \${grains_nam}"
		}
	}

	capture {
		foreach rgvar of varlist veg_type_* {
			label variable `rgvar' "Seller type #\${veg_sllr_index} of \${veg_nam}"
			note `rgvar': "Seller type #\${veg_sllr_index} of \${veg_nam}"
			label define `rgvar' 1 "Market vendor" 2 "Street stall" 3 "Cart vendor" 4 "Small shop" 5 "Supermarket" 6 "Other" 8 "Item not sold in the market" 9 "No vendor of this item consented to the interview" 10 "No other seller"
			label values `rgvar' `rgvar'
		}
	}

	capture {
		foreach rgvar of varlist veg_unit_* {
			label variable `rgvar' "Unit of \${veg_nam}"
			note `rgvar': "Unit of \${veg_nam}"
			label define `rgvar' 1 "Target: Bag" 2 "Target: Four" 3 "Target: Four" 4 "Target: Small bunch" 5 "Target: Five" 6 "Target: Five" 7 "Target: Six" 8 "Target: Head" 9 "Target: Small bunch" -222 "Alternative Unit"
			label values `rgvar' `rgvar'
		}
	}

	capture {
		foreach rgvar of varlist veg_altunit_* {
			label variable `rgvar' "Alternative Unit of \${veg_nam}"
			note `rgvar': "Alternative Unit of \${veg_nam}"
		}
	}

	capture {
		foreach rgvar of varlist veg_price_* {
			label variable `rgvar' "Price of \${veg_nam}"
			note `rgvar': "Price of \${veg_nam}"
		}
	}

	capture {
		foreach rgvar of varlist veg_wtg_* {
			label variable `rgvar' "Exact Weight (KG) of \${veg_nam}"
			note `rgvar': "Exact Weight (KG) of \${veg_nam}"
		}
	}

	capture {
		foreach rgvar of varlist meat_type_* {
			label variable `rgvar' "Seller type \${meat_sllr_index} of \${meat_nam}"
			note `rgvar': "Seller type \${meat_sllr_index} of \${meat_nam}"
			label define `rgvar' 1 "Market vendor" 2 "Street stall" 3 "Cart vendor" 4 "Small shop" 5 "Supermarket" 6 "Other" 8 "Item not sold in the market" 9 "No vendor of this item consented to the interview" 10 "No other seller"
			label values `rgvar' `rgvar'
		}
	}

	capture {
		foreach rgvar of varlist meat_unit_* {
			label variable `rgvar' "Unit of \${meat_nam}"
			note `rgvar': "Unit of \${meat_nam}"
			label define `rgvar' 1 "Target: Whole" 2 "Target: 1kg" -222 "Alternative Unit"
			label values `rgvar' `rgvar'
		}
	}

	capture {
		foreach rgvar of varlist meat_altunit_* {
			label variable `rgvar' "Alternative Unit of \${meat_nam}"
			note `rgvar': "Alternative Unit of \${meat_nam}"
		}
	}

	capture {
		foreach rgvar of varlist meat_price_* {
			label variable `rgvar' "Price of \${meat_nam}"
			note `rgvar': "Price of \${meat_nam}"
		}
	}

	capture {
		foreach rgvar of varlist meat_wtg_* {
			label variable `rgvar' "Exact Weight (KG) of \${meat_nam}"
			note `rgvar': "Exact Weight (KG) of \${meat_nam}"
		}
	}

	capture {
		foreach rgvar of varlist fruit_type_* {
			label variable `rgvar' "Seller type \${fruit_sllr_index} of \${fruit_nam}"
			note `rgvar': "Seller type \${fruit_sllr_index} of \${fruit_nam}"
			label define `rgvar' 1 "Market vendor" 2 "Street stall" 3 "Cart vendor" 4 "Small shop" 5 "Supermarket" 6 "Other" 8 "Item not sold in the market" 9 "No vendor of this item consented to the interview" 10 "No other seller"
			label values `rgvar' `rgvar'
		}
	}

	capture {
		foreach rgvar of varlist fruit_unit_* {
			label variable `rgvar' "Unit of \${fruit_nam}"
			note `rgvar': "Unit of \${fruit_nam}"
			label define `rgvar' 1 "Target: One" 2 "Target: Bunch" 3 "Target: Six" 4 "Target: Ten" 5 "Target: Four" -222 "Alternative Unit"
			label values `rgvar' `rgvar'
		}
	}

	capture {
		foreach rgvar of varlist fruit_altunit_* {
			label variable `rgvar' "Alternative Unit for \${fruit_nam}"
			note `rgvar': "Alternative Unit for \${fruit_nam}"
		}
	}

	capture {
		foreach rgvar of varlist fruit_price_* {
			label variable `rgvar' "Price of \${fruit_nam}"
			note `rgvar': "Price of \${fruit_nam}"
		}
	}

	capture {
		foreach rgvar of varlist fruit_wtg_* {
			label variable `rgvar' "Exact Weight (KG) of \${fruit_nam}"
			note `rgvar': "Exact Weight (KG) of \${fruit_nam}"
		}
	}

	capture {
		foreach rgvar of varlist lvstk_type_* {
			label variable `rgvar' "Seller type \${lvstk_sllr_index} of \${lvstk_nam}"
			note `rgvar': "Seller type \${lvstk_sllr_index} of \${lvstk_nam}"
			label define `rgvar' 1 "Market vendor" 2 "Street stall" 3 "Cart vendor" 4 "Small shop" 5 "Supermarket" 6 "Other" 8 "Item not sold in the market" 9 "No vendor of this item consented to the interview" 10 "No other seller"
			label values `rgvar' `rgvar'
		}
	}

	capture {
		foreach rgvar of varlist lvstk_var_* {
			label variable `rgvar' "Livestock variety of \${lvstk_nam}"
			note `rgvar': "Livestock variety of \${lvstk_nam}"
		}
	}

	capture {
		foreach rgvar of varlist lvstk_price_* {
			label variable `rgvar' "Price of \${lvstk_varnam} for \${lvstk_nam}"
			note `rgvar': "Price of \${lvstk_varnam} for \${lvstk_nam}"
		}
	}

	capture {
		foreach rgvar of varlist hrdwr_type_* {
			label variable `rgvar' "Seller type \${hrdwr_sllr_index} of \${hrdwr_nam}"
			note `rgvar': "Seller type \${hrdwr_sllr_index} of \${hrdwr_nam}"
			label define `rgvar' 1 "Market vendor" 2 "Street stall" 3 "Cart vendor" 4 "Small shop" 5 "Supermarket" 6 "Other" 8 "Item not sold in the market" 9 "No vendor of this item consented to the interview" 10 "No other seller"
			label values `rgvar' `rgvar'
		}
	}

	capture {
		foreach rgvar of varlist hrdwr_unit_* {
			label variable `rgvar' "Unit of \${hrdwr_nam}"
			note `rgvar': "Unit of \${hrdwr_nam}"
			label define `rgvar' 1 "Target: 10 feet" 2 "Target: 0.5kg" 3 "Target: 1 foot" 4 "Target: 4 litres" 5 "Target: 50kg" 6 "Target: 1 piece" -222 "Alternative Unit"
			label values `rgvar' `rgvar'
		}
	}

	capture {
		foreach rgvar of varlist hrdwr_altunit_* {
			label variable `rgvar' "Alternative Unit for \${hrdwr_nam}"
			note `rgvar': "Alternative Unit for \${hrdwr_nam}"
		}
	}

	capture {
		foreach rgvar of varlist hrdwr_price_* {
			label variable `rgvar' "Price of \${hrdwr_nam}"
			note `rgvar': "Price of \${hrdwr_nam}"
		}
	}

	capture {
		foreach rgvar of varlist duka_type_* {
			label variable `rgvar' "Seller type \${duka_sllr_index} of \${duka_nam}"
			note `rgvar': "Seller type \${duka_sllr_index} of \${duka_nam}"
			label define `rgvar' 1 "Market vendor" 2 "Street stall" 3 "Cart vendor" 4 "Small shop" 5 "Supermarket" 6 "Other" 8 "Item not sold in the market" 9 "No vendor of this item consented to the interview" 10 "No other seller"
			label values `rgvar' `rgvar'
		}
	}

	capture {
		foreach rgvar of varlist duka_unit_* {
			label variable `rgvar' "Unit for \${duka_nam}"
			note `rgvar': "Unit for \${duka_nam}"
			label define `rgvar' 1 "Target: Whole" 2 "Target: 500g" 3 "Target: 200ml" 4 "Target: One stick" 5 "Target: 25g" 6 "Target: 25g" 7 "Target: 50g" 8 "Target: 100g" 9 "Target: Pair" 10 "Target: 150ml" -222 "Alternative Unit"
			label values `rgvar' `rgvar'
		}
	}

	capture {
		foreach rgvar of varlist duka_altunit_* {
			label variable `rgvar' "Alternative Unit for \${duka_nam}"
			note `rgvar': "Alternative Unit for \${duka_nam}"
		}
	}

	capture {
		foreach rgvar of varlist duka_price_* {
			label variable `rgvar' "Price of \${duka_nam}"
			note `rgvar': "Price of \${duka_nam}"
		}
	}

	capture {
		foreach rgvar of varlist duka_wtg_* {
			label variable `rgvar' "Exact Weight (KG) of \${duka_nam}"
			note `rgvar': "Exact Weight (KG) of \${duka_nam}"
		}
	}

	capture {
		foreach rgvar of varlist food_type_* {
			label variable `rgvar' "Seller type #\${food_sllr_index} of \${food_nam}"
			note `rgvar': "Seller type #\${food_sllr_index} of \${food_nam}"
			label define `rgvar' 1 "Market vendor" 2 "Street stall" 3 "Cart vendor" 4 "Small shop" 5 "Supermarket" 6 "Other" 8 "Item not sold in the market" 9 "No vendor of this item consented to the interview" 10 "No other seller"
			label values `rgvar' `rgvar'
		}
	}

	capture {
		foreach rgvar of varlist food_unit_* {
			label variable `rgvar' "Unit for \${food_nam}"
			note `rgvar': "Unit for \${food_nam}"
			label define `rgvar' 1 "Target: 2kg" 2 "Target: Whole" 3 "Target: 500ml" 4 "Target: 500g" 5 "Target: 1kg" 6 "Target: 50g" 7 "Target: Loaf" 8 "Target: Pack" 9 "Target: One" 10 "Target: 300ml" -222 "Alternative Unit"
			label values `rgvar' `rgvar'
		}
	}

	capture {
		foreach rgvar of varlist food_altunit_* {
			label variable `rgvar' "Alternative Unit for \${food_nam}"
			note `rgvar': "Alternative Unit for \${food_nam}"
		}
	}

	capture {
		foreach rgvar of varlist food_price_* {
			label variable `rgvar' "Price of \${food_nam}"
			note `rgvar': "Price of \${food_nam}"
		}
	}

	capture {
		foreach rgvar of varlist food_wtg_* {
			label variable `rgvar' "Exact Weight (KG) of \${food_nam}"
			note `rgvar': "Exact Weight (KG) of \${food_nam}"
		}
	}

	capture {
		foreach rgvar of varlist fuel_type_* {
			label variable `rgvar' "Seller type #\${fuel_sllr_index} of \${fuel_nam}"
			note `rgvar': "Seller type #\${fuel_sllr_index} of \${fuel_nam}"
			label define `rgvar' 1 "Market vendor" 2 "Street stall" 3 "Cart vendor" 4 "Small shop" 5 "Supermarket" 6 "Other" 8 "Item not sold in the market" 9 "No vendor of this item consented to the interview" 10 "No other seller"
			label values `rgvar' `rgvar'
		}
	}

	capture {
		foreach rgvar of varlist fuel_unit_* {
			label variable `rgvar' "Unit for \${fuel_nam}"
			note `rgvar': "Unit for \${fuel_nam}"
			label define `rgvar' 1 "Target: Bunch" 2 "Target: 2kg" 3 "Target: 1 litre" -222 "Alternative Unit"
			label values `rgvar' `rgvar'
		}
	}

	capture {
		foreach rgvar of varlist fuel_altunit_* {
			label variable `rgvar' "Alternative Unit for \${fuel_nam}"
			note `rgvar': "Alternative Unit for \${fuel_nam}"
		}
	}

	capture {
		foreach rgvar of varlist fuel_price_* {
			label variable `rgvar' "Price of \${fuel_nam}"
			note `rgvar': "Price of \${fuel_nam}"
		}
	}

	capture {
		foreach rgvar of varlist fuel_wtg_* {
			label variable `rgvar' "Exact Weight (KG) of \${fuel_nam}"
			note `rgvar': "Exact Weight (KG) of \${fuel_nam}"
		}
	}

	capture {
		foreach rgvar of varlist health_type_* {
			label variable `rgvar' "Seller type #\${health_sllr_index} of \${health_nam}"
			note `rgvar': "Seller type #\${health_sllr_index} of \${health_nam}"
			label define `rgvar' 1 "Market vendor" 2 "Street stall" 3 "Cart vendor" 4 "Small shop" 5 "Supermarket" 6 "Other" 8 "Item not sold in the market" 9 "No vendor of this item consented to the interview" 10 "No other seller"
			label values `rgvar' `rgvar'
		}
	}

	capture {
		foreach rgvar of varlist health_unit_* {
			label variable `rgvar' "Unit of \${health_nam}"
			note `rgvar': "Unit of \${health_nam}"
			label define `rgvar' 1 "Target: Pair" 2 "Target: One" -222 "Alternative Unit"
			label values `rgvar' `rgvar'
		}
	}

	capture {
		foreach rgvar of varlist health_altunit_* {
			label variable `rgvar' "Alternative Unit of \${health_nam}"
			note `rgvar': "Alternative Unit of \${health_nam}"
		}
	}

	capture {
		foreach rgvar of varlist health_price_* {
			label variable `rgvar' "Price of \${health_nam}"
			note `rgvar': "Price of \${health_nam}"
		}
	}

	capture {
		foreach rgvar of varlist health_wtg_* {
			label variable `rgvar' "Exact Weight (KG) for \${health_nam}"
			note `rgvar': "Exact Weight (KG) for \${health_nam}"
		}
	}

	capture {
		foreach rgvar of varlist hh_type_* {
			label variable `rgvar' "Seller type \${hh_sllr_index} of \${hh_nam}"
			note `rgvar': "Seller type \${hh_sllr_index} of \${hh_nam}"
			label define `rgvar' 1 "Market vendor" 2 "Street stall" 3 "Cart vendor" 4 "Small shop" 5 "Supermarket" 6 "Other" 8 "Item not sold in the market" 9 "No vendor of this item consented to the interview" 10 "No other seller"
			label values `rgvar' `rgvar'
		}
	}

	capture {
		foreach rgvar of varlist hh_unit_* {
			label variable `rgvar' "Unit for \${hh_nam}"
			note `rgvar': "Unit for \${hh_nam}"
			label define `rgvar' 1 "Target: One" 2 "Target: 1.8 litre" -222 "Alternative Unit"
			label values `rgvar' `rgvar'
		}
	}

	capture {
		foreach rgvar of varlist hh_altunit_* {
			label variable `rgvar' "Alternative Unit for \${hh_nam}"
			note `rgvar': "Alternative Unit for \${hh_nam}"
		}
	}

	capture {
		foreach rgvar of varlist hh_price_* {
			label variable `rgvar' "Price of of \${hh_nam}"
			note `rgvar': "Price of of \${hh_nam}"
		}
	}

	capture {
		foreach rgvar of varlist hh_wtg_* {
			label variable `rgvar' "Exact Weight (KG) of \${hh_nam}"
			note `rgvar': "Exact Weight (KG) of \${hh_nam}"
		}
	}

	capture {
		foreach rgvar of varlist farm_type_* {
			label variable `rgvar' "Seller type #\${farm_sllr_index} of \${farm_nam}"
			note `rgvar': "Seller type #\${farm_sllr_index} of \${farm_nam}"
			label define `rgvar' 1 "Market vendor" 2 "Street stall" 3 "Cart vendor" 4 "Small shop" 5 "Supermarket" 6 "Other" 8 "Item not sold in the market" 9 "No vendor of this item consented to the interview" 10 "No other seller"
			label values `rgvar' `rgvar'
		}
	}

	capture {
		foreach rgvar of varlist farm_unit_* {
			label variable `rgvar' "Unit for \${farm_nam}"
			note `rgvar': "Unit for \${farm_nam}"
			label define `rgvar' 1 "Target: 2kg" -222 "Alternative Unit"
			label values `rgvar' `rgvar'
		}
	}

	capture {
		foreach rgvar of varlist farm_altunit_* {
			label variable `rgvar' "Alternative Unit for \${farm_nam}"
			note `rgvar': "Alternative Unit for \${farm_nam}"
		}
	}

	capture {
		foreach rgvar of varlist farm_price_* {
			label variable `rgvar' "Price of \${farm_nam}"
			note `rgvar': "Price of \${farm_nam}"
		}
	}

	capture {
		foreach rgvar of varlist farm_wtg_* {
			label variable `rgvar' "Exact Weight (KG) of \${farm_nam}"
			note `rgvar': "Exact Weight (KG) of \${farm_nam}"
		}
	}

	capture {
		foreach rgvar of varlist other_type_* {
			label variable `rgvar' "Seller type #\${other_sllr_index} of \${other_nam}"
			note `rgvar': "Seller type #\${other_sllr_index} of \${other_nam}"
			label define `rgvar' 1 "Market vendor" 2 "Street stall" 3 "Cart vendor" 4 "Small shop" 5 "Supermarket" 6 "Other" 8 "Item not sold in the market" 9 "No vendor of this item consented to the interview" 10 "No other seller"
			label values `rgvar' `rgvar'
		}
	}

	capture {
		foreach rgvar of varlist other_unit_* {
			label variable `rgvar' "Unit of \${other_nam}"
			note `rgvar': "Unit of \${other_nam}"
			label define `rgvar' 1 "Target: Pair" 2 "Target: One" -222 "Alternative Unit"
			label values `rgvar' `rgvar'
		}
	}

	capture {
		foreach rgvar of varlist other_altunit_* {
			label variable `rgvar' "Alternative Unit of \${other_nam}"
			note `rgvar': "Alternative Unit of \${other_nam}"
		}
	}

	capture {
		foreach rgvar of varlist other_price_* {
			label variable `rgvar' "Price of \${other_nam}"
			note `rgvar': "Price of \${other_nam}"
		}
	}

	capture {
		foreach rgvar of varlist other_wtg_* {
			label variable `rgvar' "Exact Weight (KG) for \${other_nam}"
			note `rgvar': "Exact Weight (KG) for \${other_nam}"
		}
	}




	* append old, previously-imported data (if any)
	cap confirm file "`dtafile'"
	if _rc == 0 {
		* mark all new data before merging with old data
		gen new_data_row=1
		
		* pull in old data
		append using "`dtafile'", force
		
		* drop duplicates in favor of old, previously-imported data if overwrite_old_data is 0
		* (alternatively drop in favor of new data if overwrite_old_data is 1)
		sort key
		by key: gen num_for_key = _N
		drop if num_for_key > 1 & ((`overwrite_old_data' == 0 & new_data_row == 1) | (`overwrite_old_data' == 1 & new_data_row ~= 1))
		drop num_for_key

		* drop new-data flag
		drop new_data_row
	}
	
	* save data to Stata format
	save "`dtafile'", replace

	* show codebook and notes
	*codebook
	*notes list
}

disp
disp "Finished import of: `csvfile'"
disp

* OPTIONAL: LOCALLY-APPLIED STATA CORRECTIONS
*
* Rather than using SurveyCTO's review and correction workflow, the code below can apply a list of corrections
* listed in a local .csv file. Feel free to use, ignore, or delete this code.
*
*   Corrections file path and filename:  C:/Users/BMwangi/Downloads/Markets_corrections.csv
*
*   Corrections file columns (in order): key, fieldname, value, notes

capture confirm file "`corrfile'"
if _rc==0 {
	disp
	disp "Starting application of corrections in: `corrfile'"
	disp

	* save primary data in memory
	preserve

	* load corrections
	insheet using "`corrfile'", names clear
	
	if _N>0 {
		* number all rows (with +1 offset so that it matches row numbers in Excel)
		gen rownum=_n+1
		
		* drop notes field (for information only)
		drop notes
		
		* make sure that all values are in string format to start
		gen origvalue=value
		tostring value, format(%100.0g) replace
		cap replace value="" if origvalue==.
		drop origvalue
		replace value=trim(value)
		
		* correct field names to match Stata field names (lowercase, drop -'s and .'s)
		replace fieldname=lower(subinstr(subinstr(fieldname,"-","",.),".","",.))
		
		* format date and date/time fields (taking account of possible wildcards for repeat groups)
		forvalues i = 1/100 {
			if "`datetime_fields`i''" ~= "" {
				foreach dtvar in `datetime_fields`i'' {
					* skip fields that aren't yet in the data
					cap unab dtvarignore : `dtvar'
					if _rc==0 {
						gen origvalue=value
						replace value=string(clock(value,"MDYhms",2025),"%25.0g") if strmatch(fieldname,"`dtvar'")
						* allow for cases where seconds haven't been specified
						replace value=string(clock(origvalue,"MDYhm",2025),"%25.0g") if strmatch(fieldname,"`dtvar'") & value=="." & origvalue~="."
						drop origvalue
					}
				}
			}
			if "`date_fields`i''" ~= "" {
				foreach dtvar in `date_fields`i'' {
					* skip fields that aren't yet in the data
					cap unab dtvarignore : `dtvar'
					if _rc==0 {
						replace value=string(clock(value,"MDY",2025),"%25.0g") if strmatch(fieldname,"`dtvar'")
					}
				}
			}
		}

		* write out a temp file with the commands necessary to apply each correction
		tempfile tempdo
		file open dofile using "`tempdo'", write replace
		local N = _N
		forvalues i = 1/`N' {
			local fieldnameval=fieldname[`i']
			local valueval=value[`i']
			local keyval=key[`i']
			local rownumval=rownum[`i']
			file write dofile `"cap replace `fieldnameval'="`valueval'" if key=="`keyval'""' _n
			file write dofile `"if _rc ~= 0 {"' _n
			if "`valueval'" == "" {
				file write dofile _tab `"cap replace `fieldnameval'=. if key=="`keyval'""' _n
			}
			else {
				file write dofile _tab `"cap replace `fieldnameval'=`valueval' if key=="`keyval'""' _n
			}
			file write dofile _tab `"if _rc ~= 0 {"' _n
			file write dofile _tab _tab `"disp"' _n
			file write dofile _tab _tab `"disp "CAN'T APPLY CORRECTION IN ROW #`rownumval'""' _n
			file write dofile _tab _tab `"disp"' _n
			file write dofile _tab `"}"' _n
			file write dofile `"}"' _n
		}
		file close dofile
	
		* restore primary data
		restore
		
		* execute the .do file to actually apply all corrections
		do "`tempdo'"

		* re-save data
		save "`dtafile'", replace
	}
	else {
		* restore primary data		
		restore
	}

	disp
	disp "Finished applying corrections in: `corrfile'"
	disp
}

////Converting string variables into numeric
foreach x of varlist * {
   capture confirm string variable `x'
   if !_rc {
qui destring `x', replace
}
}

save, replace

preserve
keep if entry==1
duplicates report a1a_market_id
duplicates drop a1a_market_id, force
save Markets_first_entry, replace

restore

keep if entry==2

duplicates drop a1a_market_id, force

cfout _all using Markets_first_entry, id(a1a_market_id) lower saving(cfout_diff,replace)

****making a randon change here!!!

