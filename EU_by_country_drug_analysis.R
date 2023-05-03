library(berryFunctions)
library(readr)
library(dplyr)
library(tidyr)
library(rio)
library(stringi)
library(reshape2)
library(ggplot2)
library(janitor)

# set constants
change <- c(1, 1, 1, 1, (((1+(0.2/0.11))^0.25)-1), (((1+(0.2/0.11))^0.25)-1), (((1+(0.2/0.11))^0.25)-1), (((1+(0.2/0.11))^0.25)-1), 
            (((1+(0.27/0.31))^0.25)-1), (((1+(0.27/0.31))^0.25)-1), (((1+(0.27/0.31))^0.25)-1), (((1+(0.27/0.31))^0.25)-1), 
            (((1+(0.18/0.58))^0.25)-1), (((1+(0.18/0.58))^0.25)-1), (((1+(0.18/0.58))^0.25)-1), (((1+(0.18/0.58))^0.25)-1), 
            (((1+(0.13/0.76))^0.25)-1), (((1+(0.13/0.76))^0.25)-1), (((1+(0.13/0.76))^0.25)-1), (((1+(0.13/0.76))^0.25)-1), 
            (((1+(0.11/0.89))^0.25)-1), (((1+(0.11/0.89))^0.25)-1), (((1+(0.11/0.89))^0.25)-1), (((1+(0.11/0.89))^0.25)-1), 
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 
            -1, -1, -1, -1)
tax <- 0.21
COGS <- 0.2
quarterlyRate <- 1.105^0.25-1
timeSubmit <- 4

fastQuartUS <- 2
standQuartUS <- 4*(10/12)

fastQuartEU <- (145+43+43)/91
standQuartEU <- (194+159+60)/91
fastQuartEUNoClock <- (145+43)/91
standQuartEUNoClock <- (194+60)/91

comp <- 0.12
# varstocalc <- c("ActualSales", "ProjectedSales", "ProjectedNetSales", "NPVStandNo", "NPVPriNo", "NPVNoClockNo", "NPVStandStand", 
#                 "NPVPri120", "NPVNoClock120", "NPVPri30", "NPVNoClock30")
varstocalc <- c("ActualSales", "ProjectedSales", "ProjectedNetSales", "NPVStandStand", "NPVFastStand", "NPVFast120", "NPVFast30", 
                "NPVStandNoStand", "NPVFastNoStand", "NPVFastNo120", "NPVFastNo30", "vouchFastStand", "vouchFast120", "vouchFast30", 
                "vouchFastNoStand", "vouchFastNo120", "vouchFastNo30")

# import sales data
excel_MIDAS <- import("MIDAS-2022.xlsx", sheet = "Flat Data")
export(excel_MIDAS, "MIDAS-2022.csv")
csv_MIDAS <- read_csv("MIDAS-2022.csv")
names(csv_MIDAS) <- gsub(" ", "_", names(csv_MIDAS))

# import EU status data
excel_EU_status <- import("analysis-plan-Excel.xlsx", sheet = "Country")
export(excel_EU_status, "EU-status.csv")
csv_EU_status <- read_csv("EU-status.csv")
csv_EU_status$Country <- toupper(csv_EU_status$Country)

# import reimbursement data
excel_reimb <- import("DataReimburseTimes.xlsx", sheet = "Sheet1")
export(excel_reimb, "DataReimburseTimes.csv")
csv_reimb <- read_csv("DataReimburseTimes.csv")
colnames(csv_reimb) <- c("Country", "MedianDays", "MeanDays")
csv_reimb$Country <- toupper(csv_reimb$Country)

#IQVIA countries
csv_MIDAS$EU_status <- csv_EU_status$EUMember[match(csv_MIDAS$Country,csv_EU_status$Country)]
csv_MIDAS <- filter(csv_MIDAS, EU_status == 1)
csv_MIDAS <- select(csv_MIDAS, -"EU_status")

#convert to Euros
csv_MIDAS[4:32] = lapply(csv_MIDAS[4:32], "*", 0.9)

# make vector of all unique brand names and corresponding generic names
unique_brand_names <- csv_MIDAS[!duplicated(csv_MIDAS$International_Product), ]
brand_names_vector <- unique_brand_names$International_Product
generic_names_vector <- unique_brand_names$Molecule_List

# make vector of all EU country names
EU_countries <- csv_MIDAS[!duplicated(csv_MIDAS$Country), ]
EU_countries_vector <- EU_countries$Country

# projected sales function
project_sales <- function(Q) {
  return(change[Q] + 1)
}

# function to calculate npv variables
npv <- function(timeReg, timePrice, ProjectedNetSales, Q) {
  return(as.numeric(ProjectedNetSales)/((1+quarterlyRate)^(Q+timeSubmit+timeReg+timePrice)))
}

# function to calculate value of voucher for one drug
analyze_drug <- function(EU_country_data, c, drug) {
  # find this country's standard reimbursement
  standMedReimburse <- as.numeric(csv_reimb[c, 2])
  QuartMedian20172020 <- standMedReimburse/91

  drug_data <- filter(EU_country_data, International_Product == drug)
  data_columns <- select(drug_data, -"Country", -"Molecule_List", -"International_Product")
  
  # transform left and transpose, add empty rows
  rest_data <- t(data_columns)
  rest_data <- rest_data[!is.na(rest_data)]
  rest_frame <- rest_data %>% data.frame() %>% rename_with(~ gsub('.', 'ActualSales', .x))
  rows <- nrow(rest_frame)
  rest_frame <- addRows(rest_frame, 56-rows, values = NA) # was 60

  # make column with row numbers and move to be first column
  rest_frame <- rest_frame %>% transform(Q = seq.int(nrow(rest_frame)))
  rest_frame <- rest_frame[,c(2, 1)]
  
  # project sales
  projected_frame <- rest_frame %>% 
    transform(ProjectedSales = ifelse(is.na(ActualSales), project_sales(Q), ActualSales))
  
  # rows + 1
  for(i in (rows+1):56) { # was 60
    projected_frame[i,3] <- as.numeric(projected_frame[i-1, 3]) * (1 + change[i])
  }

  # add column for projected net sales
  frame_with_net <- projected_frame %>%
    transform(ProjectedNetSales = as.numeric(ProjectedSales)*(1-tax-COGS))
  
  # NPV vars from here on --->
  min_t <- min(c((4/3), QuartMedian20172020))
  
  values_frame <- frame_with_net %>% transform(NPVStandStand = npv(standQuartEU,QuartMedian20172020, ProjectedNetSales, Q))
  values_frame <- values_frame %>% transform(NPVFastStand = (1+comp)*npv(fastQuartEU,QuartMedian20172020, ProjectedNetSales, Q))
  values_frame <- values_frame %>% transform(NPVFast120 = (1+comp)*npv(fastQuartEU, min_t, ProjectedNetSales, Q))
  values_frame <- values_frame %>% transform(NPVFast30 = (1+comp)*npv(fastQuartEU,(1/3), ProjectedNetSales, Q))
  
  values_frame <- values_frame %>% transform(NPVStandNoStand = npv(standQuartEUNoClock,QuartMedian20172020, ProjectedNetSales, Q))
  values_frame <- values_frame %>% transform(NPVFastNoStand = (1+comp)*npv(fastQuartEUNoClock,QuartMedian20172020, ProjectedNetSales, Q))
  values_frame <- values_frame %>% transform(NPVFastNo120 = (1+comp)*npv(fastQuartEUNoClock, min_t, ProjectedNetSales, Q))
  values_frame <- values_frame %>% transform(NPVFastNo30 = (1+comp)*npv(fastQuartEUNoClock,(1/3), ProjectedNetSales, Q))
  
  values_frame <- values_frame %>% transform(vouchFastStand = NPVFastStand-NPVStandStand)
  values_frame <- values_frame %>% transform(vouchFast120 = NPVFast120-NPVStandStand)
  values_frame <- values_frame %>% transform(vouchFast30 = NPVFast30-NPVStandStand)
  
  values_frame <- values_frame %>% transform(vouchFastNoStand = NPVFastNoStand-NPVStandNoStand)
  values_frame <- values_frame %>% transform(vouchFastNo120 = NPVFastNo120-NPVStandNoStand)
  values_frame <- values_frame %>% transform(vouchFastNo30 = NPVFastNo30-NPVStandNoStand)
  
  
  # replace all NA with 0 for summing
  values_frame[is.na(values_frame)] <- 0
  
  # return a vector containing the sum of each variable
  return_values <- c()
  for(v in 1:length(varstocalc)) {
    var_sum <- sum(values_frame[, v + 1])
    return_values <- append(return_values, var_sum)
  }
  return(return_values)
}

# create data frame for value by drug (aggregated countries)
value_by_drug_agg_co <- data.frame(matrix(0, nrow=length(brand_names_vector), ncol=length(varstocalc)))
colnames(value_by_drug_agg_co) <- varstocalc

# create data frame for value by country (aggregated drugs)
value_by_country_agg_d <- data.frame(matrix(0, nrow=0, ncol=length(varstocalc)))

# for each country, make a frame that is only that country
for(c in 1:length(EU_countries_vector)) {
  single_country_df <- filter(csv_MIDAS, Country == EU_countries_vector[c])
  
  # create empty frame for this country's values by drugs
  single_country_drug_values <- data.frame(matrix(0, nrow=0, ncol=length(varstocalc)))
  
  # list of drugs with sales this country
  this_country_brand_names_vector <- single_country_df$International_Product
  
  # for each drug, calculate values
  for(d in 1:length(brand_names_vector)) {
    if(brand_names_vector[d] %in% this_country_brand_names_vector){
      single_country_drug_vector <- analyze_drug(single_country_df, c, brand_names_vector[d])
    }
    else {
      single_country_drug_vector <- c(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
    }
    single_country_drug_row <- matrix(single_country_drug_vector) %>% t %>% data.frame()
    single_country_drug_values <- rbind(single_country_drug_values, single_country_drug_row)
  }

  # add column names
  colnames(single_country_drug_values) <- varstocalc
  
  brand_names_col <- brand_names_vector %>% data.frame()
  country_col <- rep(c(EU_countries_vector[c]),each=nrow(single_country_drug_values)) %>% data.frame() %>% rename_with(~ gsub('.', 'Country', .x))
  single_country_drug_values <- cbind(country_col, BrandName = brand_names_vector, single_country_drug_values)
  path <- paste("Voucher Value by Country (by Drug)/", EU_countries_vector[c], "_value_by_drug.xlsx", sep="")
  export(single_country_drug_values, path)
  
  # add to value by drug
  for(v in 1:length(varstocalc)) {
    agg_col <- value_by_drug_agg_co[, v]
    to_add_col <- single_country_drug_values[, v+2]
    new_col <- as.numeric(agg_col) + as.numeric(to_add_col)
    value_by_drug_agg_co[, v] <- new_col %>% data.frame()
  }
  
  new_row = c()
  # add to value by country
  for(v in 1:length(varstocalc)) {
    single_country_drug_values_no_gaps <- single_country_drug_values[, v+2]
    single_country_drug_values_no_gaps <- single_country_drug_values_no_gaps[single_country_drug_values_no_gaps != 0]
    new_row <- append(new_row, median(single_country_drug_values_no_gaps))
  }
  new_row <- matrix(new_row) %>% t %>% data.frame()
  value_by_country_agg_d <- rbind(value_by_country_agg_d, new_row)
}

# assemble final aggregate dataset by drug
region_col <- rep(c("EU"),each=nrow(value_by_drug_agg_co)) %>% data.frame() %>% rename_with(~ gsub('.', 'Region', .x))
value_by_drug_agg_co <- cbind(region_col, brand_names_col, value_by_drug_agg_co)
names(value_by_drug_agg_co)[names(value_by_drug_agg_co) == "."] <- "BrandName"

export(value_by_drug_agg_co, "Voucher Value by Country (by Drug)/Voucher_value_by_drug_aggregated_countries.xlsx")

# Table A3
tableA3 <- select(value_by_drug_agg_co, "BrandName", "NPVStandStand", "NPVFastStand", "NPVFast120", "NPVFast30")
generic_names_col <- generic_names_vector %>% data.frame()
tableA3 <- cbind(BrandName = tableA3$BrandName, generic_names_col, select(tableA3, -"BrandName"))
names(tableA3)[names(tableA3) == "."] <- "GenericName"
tableA3[order(tableA3$GenericName), ]

tableA3 <- tableA3 %>% ungroup %>% summarise(BrandName = c(BrandName, 'Mean'), GenericName = c(GenericName, ''),
            across(where(is.numeric), ~ c(., mean(.))))
tableA3 <- tableA3 %>% summarise(BrandName = c(BrandName, 'Median'), GenericName = c(GenericName, ''),
                                             across(where(is.numeric), ~ c(., median(.))))
tableA3 <- tableA3 %>% summarise(BrandName = c(BrandName, '25th Percentile'), GenericName = c(GenericName, ''),
                                 across(where(is.numeric), ~ c(., quantile(., probs=0.25))))

export(tableA3, "tableA3_NPV_of_drugs.xlsx")

# Table A5
tableA5 <- select(value_by_drug_agg_co, "BrandName", "NPVStandNoStand", "NPVFastNoStand", "NPVFastNo120", "NPVFastNo30")
tableA5 <- cbind(BrandName = tableA5$BrandName, generic_names_col, select(tableA5, -"BrandName"))
names(tableA5)[names(tableA5) == "."] <- "GenericName"
tableA5[order(tableA5$GenericName), ]

tableA5 <- tableA5 %>% ungroup %>% summarise(BrandName = c(BrandName, 'Mean'), GenericName = c(GenericName, ''),
                                             across(where(is.numeric), ~ c(., mean(.))))
tableA5 <- tableA5 %>% summarise(BrandName = c(BrandName, 'Median'), GenericName = c(GenericName, ''),
                                 across(where(is.numeric), ~ c(., median(.))))
tableA5 <- tableA5 %>% summarise(BrandName = c(BrandName, '25th Percentile'), GenericName = c(GenericName, ''),
                                 across(where(is.numeric), ~ c(., quantile(., probs=0.25))))

export(tableA5, "tableA5_NPV_of_drugs_no_clockstop.xlsx")

# Table 3
table3 <- select(value_by_drug_agg_co, "BrandName", "vouchFastStand", "vouchFast120", "vouchFast30")
table3 <- cbind(BrandName = table3$BrandName, generic_names_col, select(table3, -"BrandName"))
names(table3)[names(table3) == "."] <- "GenericName"
table3[order(table3$GenericName), ]

table3 <- table3 %>% ungroup %>% summarise(BrandName = c(BrandName, 'Mean'), GenericName = c(GenericName, ''),
                                             across(where(is.numeric), ~ c(., mean(.))))
table3 <- table3 %>% summarise(BrandName = c(BrandName, 'Median'), GenericName = c(GenericName, ''),
                                 across(where(is.numeric), ~ c(., median(.))))
table3 <- table3 %>% summarise(BrandName = c(BrandName, '25th Percentile'), GenericName = c(GenericName, ''),
                                 across(where(is.numeric), ~ c(., quantile(., probs=0.25))))

export(table3, "table3_NPV_of_voucher.xlsx")

# assemble final aggregate dataset by country
colnames(value_by_country_agg_d) <- varstocalc
value_by_country_agg_d <- cbind(Country = EU_countries_vector, value_by_country_agg_d)

export(value_by_country_agg_d, "Voucher Value by Country (by Drug)/Voucher_value_by_country_aggregated_drugs.xlsx")

# Table A4
tableA4 <- select(value_by_country_agg_d, "Country", "vouchFastStand", "vouchFast120", "vouchFast30")
tableA4[order(tableA4$Country), ]

tableA4 <- rbind(tableA4, data.frame(Country='Total', t(colSums(tableA4[, -1]))))
export(tableA4, "tableA4_median_NPV_of_voucher.xlsx")

# Table 5
tableA6 <- select(value_by_country_agg_d, "Country", "vouchFastNoStand", "vouchFastNo120", "vouchFastNo30")
tableA6[order(tableA6$Country), ]

tableA6 <- rbind(tableA6, data.frame(Country='Total', t(colSums(tableA6[, -1]))))
export(tableA6, "tableA6_median_NPV_of_voucher_no_clockstop.xlsx")


# create reimbursement times by country
csv_reimb_with_savings <- csv_reimb %>% transform(SavingsFromMedIf120=MedianDays-120)
csv_reimb_with_savings[csv_reimb_with_savings < 0] <- 0
csv_reimb_with_savings <- csv_reimb_with_savings %>% transform(SavingsFromMedIf30=MedianDays-30)

export(csv_reimb_with_savings, "table2_reimbursement_times_and_savings.xlsx")
