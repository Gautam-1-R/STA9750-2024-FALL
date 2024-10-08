if(!require("tidyverse")) install.packages("tidyverse")

# Load the tidyverse library
library(tidyverse)

# Let's start with Fare Revenue
if(!file.exists("2022_fare_revenue.xlsx")){
  # Using curl or default method
  download.file("http://www.transit.dot.gov/sites/fta.dot.gov/files/2024-04/2022%20Fare%20Revenue.xlsx", 
                destfile="2022_fare_revenue.xlsx", 
                quiet=FALSE)  # Removed method='wget'
}

# Proceed to read the data
FARES <- readxl::read_xlsx("2022_fare_revenue.xlsx") |>
  select(-`State/Parent NTD ID`, 
         -`Reporter Type`,
         -`Reporting Module`,
         -`TOS`,
         -`Passenger Paid Fares`,
         -`Organization Paid Fares`) |>
  filter(`Expense Type` == "Funds Earned During Period") |>
  select(-`Expense Type`)

FARES <- readxl::read_xlsx("2022_fare_revenue.xlsx") |>
  select(-`State/Parent NTD ID`, 
         -`Reporter Type`,
         -`Reporting Module`,
         -`TOS`,
         -`Passenger Paid Fares`,
         -`Organization Paid Fares`) |>
  filter(`Expense Type` == "Funds Earned During Period") |>
  select(-`Expense Type`)

# Next, expenses
if(!file.exists("2022_expenses.csv")){
  # This should work _in theory_ but in practice it's still a bit finicky
  # If it doesn't work for you, download this file 'by hand' in your
  # browser and save it as "2022_expenses.csv" in your project
  # directory.
  download.file("https://data.transportation.gov/api/views/dkxx-zjd6/rows.csv?date=20231102&accessType=DOWNLOAD&bom=true&format=true", 
                destfile="2022_expenses.csv", 
                quiet=FALSE)  # Removed method='wget'
}
EXPENSES <- read.csv("2022_expenses.csv") |>
  select(`NTD ID`, 
         `Agency`,
         `Total`, 
         `Mode`) |>
  mutate(`NTD ID` = as.integer(`NTD ID`)) |>
  rename(Expenses = Total) |>
  group_by(`NTD ID`, `Mode`) |>
  summarize(Expenses = sum(Expenses)) |>
  ungroup()

FINANCIALS <- inner_join(FARES, EXPENSES, join_by(`NTD ID`, `Mode`))
# Monthly Transit Numbers
library(tidyverse)
if(!file.exists("ridership.xlsx")){
  # This should work _in theory_ but in practice it's still a bit finicky
  # If it doesn't work for you, download this file 'by hand' in your
  # browser and save it as "ridership.xlsx" in your project
  # directory.
  download.file("https://www.transit.dot.gov/sites/fta.dot.gov/files/2024-09/July%202024%20Complete%20Monthly%20Ridership%20%28with%20adjustments%20and%20estimates%29_240903.xlsx", 
                destfile="ridership.xlsx", 
                quiet=FALSE, 
                method="wget")
}
TRIPS <- readxl::read_xlsx("ridership.xlsx", sheet="UPT") |>
  filter(`Mode/Type of Service Status` == "Active") |>
  select(-`Legacy NTD ID`, 
         -`Reporter Type`, 
         -`Mode/Type of Service Status`, 
         -`UACE CD`, 
         -`TOS`) |>
  pivot_longer(-c(`NTD ID`:`3 Mode`), 
               names_to="month", 
               values_to="UPT") |>
  drop_na() |>
  mutate(month=my(month)) # Parse _m_onth _y_ear date specs
MILES <- readxl::read_xlsx("ridership.xlsx", sheet="VRM") |>
  filter(`Mode/Type of Service Status` == "Active") |>
  select(-`Legacy NTD ID`, 
         -`Reporter Type`, 
         -`Mode/Type of Service Status`, 
         -`UACE CD`, 
         -`TOS`) |>
  pivot_longer(-c(`NTD ID`:`3 Mode`), 
               names_to="month", 
               values_to="VRM") |>
  drop_na() |>
  group_by(`NTD ID`, `Agency`, `UZA Name`, 
           `Mode`, `3 Mode`, month) |>
  summarize(VRM = sum(VRM)) |>
  ungroup() |>
  mutate(month=my(month)) # Parse _m_onth _y_ear date specs

if(!require("DT")) install.packages("DT")
library(DT)

sample_n(USAGE, 1000) |> 
  mutate(month=as.character(month)) |> 
  DT::datatable()
USAGE <- USAGE %>%
  rename(metro_area = `UZA Name`)
## This code needs to be modified
USAGE <- USAGE %>%
  mutate(Mode = case_when(
    Mode == "HR" ~ "Heavy Rail",
    Mode == "MB" ~ "Bus",
    Mode == "DR" ~ "Demand Response",
    Mode == "CB" ~ "Commuter Bus",
    Mode == "VP" ~ "Vanpool",
    TRUE ~ "Unknown"))
print(ls())  # This will list all objects in your environment
if (exists("USAGE")) {
  print("USAGE is created.")
} else {
  print("USAGE is not created.")
}
# 1. Transit agency with the most total VRM
most_total_VRM_agency <- USAGE %>%
  group_by(Agency) %>%
  summarize(total_VRM = sum(VRM, na.rm = TRUE)) %>%
  arrange(desc(total_VRM)) %>%
  slice(1)

# 2. Transit mode with the most total VRM
most_total_VRM_mode <- USAGE %>%
  group_by(Mode) %>%
  summarize(total_VRM = sum(VRM, na.rm = TRUE)) %>%
  arrange(desc(total_VRM)) %>%
  slice(1)

# 3. Trips taken on the NYC Subway in May 2024
nyc_subway_trips_may_2024 <- USAGE %>%
  filter(Mode == "Heavy Rail", month == as.Date("2024-05-01")) %>%
  summarize(total_UPT = sum(UPT, na.rm = TRUE))

# 4. Mode of transport with the longest average trip in May 2024
longest_avg_trip_may_2024 <-USAGE %>%
  filter(month == as.Date("2024-05-01")) %>%
  mutate(avg_trip_length = VRM / UPT) %>%
  group_by(Mode) %>%
  summarize(avg_trip_length = mean(avg_trip_length, na.rm = TRUE)) %>%
  arrange(desc(avg_trip_length)) %>%
  slice(1)

# 5. Fall in NYC subway ridership between April 2019 and April 2020
nyc_subway_ridership_fall <- USAGE %>%
  filter(Mode == "Heavy Rail", month %in% as.Date(c("2019-04-01", "2020-04-01"))) %>%
  group_by(month) %>%
  summarize(total_UPT = sum(UPT, na.rm = TRUE)) %>%
  arrange(month)

# Calculate average monthly ridership per agency
average_ridership_per_agency <- USAGE %>%
  group_by(Agency) %>%
  summarize(average_monthly_UPT = mean(UPT, na.rm = TRUE)) %>%
  arrange(desc(average_monthly_UPT))

print(average_ridership_per_agency)

USAGE_2022_ANNUAL <- USAGE %>%
  mutate(year = year(month)) %>%
  filter(year == 2022) %>%
  group_by(`NTD ID`, Agency, metro_area, Mode) %>%
  summarize(UPT = sum(UPT, na.rm = TRUE),
            VRM = sum(VRM, na.rm = TRUE)) %>%
  ungroup()
print(USAGE_2022_ANNUAL)

USAGE_AND_FINANCIALS <- left_join(USAGE_2022_ANNUAL, FINANCIALS, by = c("NTD ID", "Mode")) %>%
  drop_na()
print(USAGE_AND_FINANCIALS)
USAGE <- USAGE %>%
  mutate(month = ym(month)) 
USAGE_2022_ANNUAL <- USAGE %>%
  filter(year(month) == 2022) %>%  # Filter data for the year 2022
  group_by(`NTD ID`, Agency, metro_area, Mode) %>%
  summarize(UPT = sum(UPT, na.rm = TRUE),
            VRM = sum(VRM, na.rm = TRUE)) %>%
  ungroup() 
print(USAGE_2022_ANNUAL)
USAGE_AND_FINANCIALS <- left_join(USAGE_2022_ANNUAL, 
                                  FINANCIALS, 
                                  join_by(`NTD ID`, Mode)) |>
  drop_na()
# transit system (agency and mode) had the most UPT in 2022
most_upt <- USAGE_AND_FINANCIALS %>%
  arrange(desc(UPT)) %>%
  slice(1)

print(most_upt)
# farebox recovery ratio
USAGE_AND_FINANCIALS <- USAGE_AND_FINANCIALS %>%
  mutate(farebox_recovery_ratio = Total_Fares / Expenses)
# highest ratio of Total Fares to Expenses
highest_farebox_recovery <- USAGE_AND_FINANCIALS %>%
  arrange(desc(farebox_recovery_ratio)) %>%
  slice(1)

print(highest_farebox_recovery)
# transit system (agency and mode) has the lowest expenses per UPT
USAGE_AND_FINANCIALS <- USAGE_AND_FINANCIALS %>%
  mutate(expenses_per_upt = Expenses / UPT)
lowest_expenses_per_upt <- USAGE_AND_FINANCIALS %>%
  arrange(expenses_per_upt) %>%
  slice(1)

print(lowest_expenses_per_upt)
# transit system (agency and mode) has the highest total fares per UPT
USAGE_AND_FINANCIALS <- USAGE_AND_FINANCIALS %>%
  mutate(fares_per_upt = Total_Fares / UPT)
highest_fares_per_upt <- USAGE_AND_FINANCIALS %>%
  arrange(desc(fares_per_upt)) %>%
  slice(1)

print(highest_fares_per_upt)

# transit system (agency and mode) has the lowest expenses per VRM
USAGE_AND_FINANCIALS <- USAGE_AND_FINANCIALS %>%
  mutate(expenses_per_vrm = Expenses / VRM)
lowest_expenses_per_vrm <- USAGE_AND_FINANCIALS %>%
  arrange(expenses_per_vrm) %>%
  slice(1)

print(lowest_expenses_per_vrm)

# transit system (agency and mode) has the highest total fares per VRM
USAGE_AND_FINANCIALS <- USAGE_AND_FINANCIALS %>%
  mutate(fares_per_vrm = Total_Fares / VRM)
highest_fares_per_vrm <- USAGE_AND_FINANCIALS %>%
  arrange(desc(fares_per_vrm)) %>%
  slice(1)

print(highest_fares_per_vrm)
highest_fares_per_vrm <- USAGE_AND_FINANCIALS %>%
  filter(!is.na(Total_Fares), !is.na(Expenses), VRM > 0) %>%
  mutate(fares_per_vrm = Total_Fares / VRM) %>%
  group_by(Agency, Mode) %>%
  summarize(total_fares_per_vrm = sum(fares_per_vrm, na.rm = TRUE)) %>%
  arrange(desc(total_fares_per_vrm)) %>%
  slice(1)

USAGE_2022_ANNUAL <- USAGE %>%
  mutate(year = lubridate::year(month)) %>%
  filter(year == 2022) %>%
  group_by(`NTD ID`, Agency, metro_area, Mode) %>%
  summarize(UPT = sum(UPT, na.rm = TRUE),
            VRM = sum(VRM, na.rm = TRUE)) %>%
  ungroup()
FINANCIALS <- inner_join(FARES, EXPENSES, by = c("NTD ID", "Mode"))
USAGE_AND_FINANCIALS <- left_join(USAGE_2022_ANNUAL, FINANCIALS, by = c("NTD ID", "Mode")) %>%
  drop_na()
# List all objects in your R environment
ls()

# Check if the object is created
if ("USAGE_AND_FINANCIALS" %in% ls()) {
  print("USAGE_AND_FINANCIALS is created.")} 
else
  {print("USAGE_AND_FINANCIALS is not created.")}

if (exists("USAGE_AND_FINANCIALS"))
  {head(USAGE_AND_FINANCIALS)}