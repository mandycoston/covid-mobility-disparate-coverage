
library(tigris)
library(censusapi)

# This function reads in the csv that contains
# the mapping from precinct-polling location to
# safegraph place id
# Returns: list() containing the processed csv, election date, and state
import_sg_poll_map <- function(file_name) {
  read_csv(file_name) %>%
    select(-one_of(c("customer_street_address", "customer_latitude", "customer_longitude", "customer_postal_code", "customer_city"))) %>%
    rename_at(vars(starts_with("customer_")), function(x) {
      str_remove(x, "customer_")
    }) %>%
    filter(number_of_candidate_matches == 1) %>%
    select(-is_closed, -number_of_candidate_matches, -warnings, -other_match_candidates) %>%
    mutate(election_date = lubridate::mdy(election_date)) -> df
  election_date <- first(df$election_date)
  state <- first(df$State)
  return(list(
    "df" = df,
    "election_date" = election_date,
    "state" = state
  ))
}



# This function formats the L2 variables into predictors
# Returns: a list containing the dataframe with the new predictors added
# and a list of the predictors
format_x <- function(df) {
  df %>%
    select(
      LALVOTERID,
      Voters_Gender,
      Voters_Age,
      Parties_Description,
      EthnicGroups_EthnicGroup1Desc,
      Precinct,
      County
    ) -> df


  # expand ethnicity, gender, party out into dummies
  dummy_cols(df, select_columns = c("EthnicGroups_EthnicGroup1Desc", "Voters_Gender", "Parties_Description")) %>%
    mutate_at(vars(starts_with("EthnicGroups_EthnicGroup1Desc_")), replace_na, 0) %>%
    mutate_at(vars(starts_with("Voters_Gender_")), replace_na, 0) %>%
    rename_at(vars(starts_with("EthnicGroups_EthnicGroup1Desc_")), function(x) {
      str_remove(x, "EthnicGroups_EthnicGroup1Desc_")
    }) %>%
    rename(
      race_unknown = `NA`,
      black = `Likely African-American`,
      asian = `East and South Asian`,
      hispanic = `Hispanic and Portuguese`,
      white = European,
      other_race = Other
    ) -> df

  # specify list of predictors that you just created
  df %>%
    select(
      Voters_Age,
      starts_with("Voters_Gender_"),
      starts_with("Parties_Description_"),
      race_unknown,
      black,
      asian,
      hispanic,
      white,
      other_race
    ) %>%
    colnames() -> predictors
  return(list("df" = df, "predictors" = predictors))
}

# this function reads in the l2 voter and demographic data,
# combines them, filters to in-person votes for the desired election
# and formats the output according to desired predictors
# dependency: format_x function
# outputs: a list containing the dataframe with the new predictors added
# and a list of the predictors
# votespec <- spec_tsv(l2_vote_path)
get_l2 <- function(l2_vote_path,
                   l2_dem_path,
                   vote_spec,
                   dem_spec,
                   election,
                   check_ballot = TRUE,
                   ballot,
                   check_early = TRUE,
                   early,
                   DEBUG = FALSE) {
  votes <- read_tsv(l2_vote_path, col_types = vote_spec)
  dem <- read_tsv(l2_dem_path, col_types = dem_spec)
  votes %>%
    left_join(dem,
      by = c("LALVOTERID")
    ) -> votes
  
  votes_raw <- votes ## DEBUGGING
  
  # filter out rows with missing election (didn't vote in this election)
  votes %>%
    filter(
      !is.na( {{election}}),
      !is.na(Precinct)
    ) -> votes

  if (check_ballot) {
    votes %>%
      filter(
        {{ballot}} == "Poll Vote",
      ) -> votes
  }

  if (check_early) {
    votes %>%
      filter(
        is.na({{early}}),
      ) -> votes
  }

  if(DEBUG) {
  return(list("orig" = format_x(df = votes), "raw" = votes_raw))
  }
  else(return(format_x(df = votes)))
}


# This function takes in the L2 voter data and SafeGraph places
# data for polling locations
# and returns a list of unique precinct-county pairs

get_unique_precincts <- function(votes, sg) {
  votes %>%
    select(Precinct, County) %>%
    unique() -> precincts

  # merge with safegraph place id
  precincts %>%
    stringdist_join(sg, by = c("Precinct", "County"), max_dist = 4, ignore_case = TRUE, distance_col = "precinct_match_distance") %>%
    mutate(precinct_match_distance = Precinct.precinct_match_distance + County.precinct_match_distance) %>% 
    group_by(Precinct.x, County.x) %>%
    mutate(rank = row_number(precinct_match_distance)) %>%
    filter(rank == 1) -> precinct_matched
  
  return(precinct_matched)
}


# This function returns all daily traffic for state on target_date
get_daily_traffic_from_monthly_by_state <- function(patterns, state, target_date) {
  patterns1 <- read_csv(paste0(patterns, "patterns-part1.csv")) %>% filter(region == state)
  patterns2 <- read_csv(paste0(patterns, "patterns-part2.csv")) %>% filter(region == state)
  patterns3 <- read_csv(paste0(patterns, "patterns-part3.csv")) %>% filter(region == state)
  patterns4 <- read_csv(paste0(patterns, "patterns-part4.csv")) %>% filter(region == state)
  patterns <- rbind(patterns1, patterns2, patterns3, patterns4)
  
  rm(patterns1, patterns2, patterns3, patterns4)
  
  # parse out daily traffic
  daily <- process_monthly_patterns_daily(patterns)
  return(filter(daily, date == target_date)) 
}

# This function gets the SafeGraph traffic to voting locations on the election day
# USE_MONTHLY flag should be set to true for dates before 2019.
# SAVE_STATE_PATTERNS will save the intermediate patterns filtered to state from
# file patterns_file_save
# USE_SAVED_STATE_PATTERNS will read from the intermediate patterns
get_election <- function(precincts,
                         patterns,
                         election,
                         election_hour_start = 7,
                         election_hour_end = 7,
                         state,
                         days_in_month = 30,
                         INCLUDE_WEEKLY_TRAFFIC = TRUE,
                         USE_MONTHLY = FALSE,
                         SAVE_STATE_PATTERNS = TRUE,
                         USE_SAVED_STATE_PATTERNS = FALSE,
                         patterns_file_save = "",
                         DEBUG = FALSE) {
  if (USE_SAVED_STATE_PATTERNS) {
    daily <- read_csv(patterns_file_save)
  }

  else if (USE_MONTHLY) {
    if (DEBUG) {
      patterns <- read_csv(paste0(patterns, "patterns-part1.csv")) %>% filter(region == state) %>% sample_frac(0.1)
    } else {
    patterns1 <- read_csv(paste0(patterns, "patterns-part1.csv")) %>% filter(region == state)
    patterns2 <- read_csv(paste0(patterns, "patterns-part2.csv")) %>% filter(region == state)
    patterns3 <- read_csv(paste0(patterns, "patterns-part3.csv")) %>% filter(region == state)
    patterns4 <- read_csv(paste0(patterns, "patterns-part4.csv")) %>% filter(region == state)
    patterns <- rbind(patterns1, patterns2, patterns3, patterns4)

    rm(patterns1, patterns2, patterns3, patterns4)
    }   

    # parse out daily traffic
    daily <- process_monthly_patterns_daily(patterns, n_days = days_in_month)
    # merge to precincts
    precincts %>%
      inner_join(daily, by = c("safegraph_place_id")) %>%
      select(-date_range_start) %>%
      rename(County = County.x, 
             Precinct = Precinct.x, 
             Poll_location = polling_place_name) -> daily
    
    
  }

  else {
    patterns <- read_csv(patterns)
    patterns %>%
      filter(region == state) -> patterns

    if (DEBUG) {
      patterns %>%
        sample_frac(0.1) -> patterns
    }

    # explode hours and days
    patterns_exp <- process_patterns_origins_hourly(patterns = patterns)

    patterns_exp %>%
      #filter(date == lubridate::ymd(election)) %>%
      filter(
        hour >= election_hour_start,
        hour <= (12 + election_hour_end)
      ) %>%
      group_by(safegraph_place_id, date, raw_visit_counts, location_name) %>%
      summarise(daily_visits = sum(hourly_visits)) -> daily

    precincts %>%
      inner_join(daily, by = c("safegraph_place_id")) %>%
      rename(
        County = County.x,
        Precinct = Precinct.x,
        Poll_location = polling_place_name
      ) %>%
      select(Poll_location, County, Precinct, one_of(c("latitude", "longitude")), one_of(colnames(daily))) -> daily 
  }

  if(!INCLUDE_WEEKLY_TRAFFIC) {
    daily %>%
      filter(date == election) -> daily
  }
  
  if (SAVE_STATE_PATTERNS) {
    daily %>%
      write_csv(patterns_file_save)
  }
  return(daily)
}


# This function returns a dataframe with the features
# formatted for regression and visualization analyses
aggregate_voters_and_create_outcomes <- function(votes) {
  votes %>%
    group_by(safegraph_place_id) %>%
    summarise(
      voters = n(),
      sg_count = mean(daily_visits),
      age_quant = quantile(Voters_Age, 0.75, na.rm = TRUE),
      perc_over_65 = sum(Voters_Age >= 65, na.rm = TRUE) / sum(!is.na(Voters_Age)),
      perc_over_70 = sum(Voters_Age >= 70, na.rm = TRUE) / sum(!is.na(Voters_Age)),
      black_perc = mean(black, na.rm = TRUE),
      white_perc = mean(white, na.rm = TRUE),
      hispanic_perc = mean(hispanic, na.rm = TRUE),
      asian_perc = mean(asian, na.rm = TRUE),
      latitude = first(latitude),
      longitude = first(longitude)
    ) %>%
    mutate(
      rate = sg_count / voters,
      log_rate = log(sg_count / voters)
    )
}

# This function returns a dataframe with the sg counts 
# over the month (if before 2018) or over the week (if after 2018)
# around the election
aggregate_sg_traffic <- function(df) {
  df %>%
    group_by(safegraph_place_id, date) %>%
    summarise(
      sg_count = mean(daily_visits),
      sg_location = first(location_name),
      poll_location = first(Poll_location), 
      latitude = first(latitude),
      longitude = first(longitude)) -> df
  return(df)
}


# This function uses the 2018 ACS for dates after 2018
# but this should be updated to the 2020 census
get_norm_factor <- function(state,
                            election_date,
                            hps_path) {
  hps <- read_csv(hps_path)
  state_lc <- tolower(state)
  hps %>%
    filter(state == state_lc) %>%
    pull(number_devices_residing) %>%
    sum() -> total_devices

  election_year <- lubridate::year(election_date)
  acs_year <- if_else(election_year > 2018, 2018, election_year)
  # Add key to .Renviron
  Sys.setenv(CENSUS_KEY = "7e4456ef97414257126d29ff20dc1437a8678644")
  # Reload .Renviron
  readRenviron("~/.Renviron")
  # Check to see that the expected key is output in your R console
  Sys.getenv("CENSUS_KEY")

  data("fips_codes")

  fips_codes %>%
    rename(state_col = state) %>%
    filter(state_col == state) %>%
    pull(state_code) %>%
    first() -> state_fips

  getCensus(
    name = "acs/acs1", # name of census apiL 1-year ACS
    vintage = acs_year, # dataset year
    region = paste0("state:", state_fips),
    vars = "B01003_001E" # variable to retrieve: total population
  ) %>%
    pull(B01003_001E) %>% # is the total population for the CBG
    sum() -> total_population

  return(total_population / total_devices)
}

get_categories <- function(places_dir, place_ids, state) {
    place1 <- read_csv(paste0(places_dir, "core_poi-part1.csv.gz")) %>% filter(region == state)
    place2 <- read_csv(paste0(places_dir, "core_poi-part2.csv.gz")) %>% filter(region == state)
    place3 <- read_csv(paste0(places_dir, "core_poi-part3.csv.gz")) %>% filter(region == state)
    place4 <- read_csv(paste0(places_dir, "core_poi-part4.csv.gz")) %>% filter(region == state)
    place5 <- read_csv(paste0(places_dir, "core_poi-part5.csv.gz")) %>% filter(region == state)
    places <- rbind(place1, place2, place3, place4, place5)
    places %>% 
      filter(safegraph_place_id %in% place_ids) -> poll_places
    return(poll_places)
}
