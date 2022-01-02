# This file contains processing functions based on 
# https://github.com/stanfordfuturebay/stanfordfuturebay.github.io/blob/master/covid19/safegraph_process_patterns_functions.R
# The functions in this file currently do not support normalization.

# This function processes the monthly patterns
# Argument patterns specifies the Safegraph weekly patterns dataset. 
# Argument n_days specifies how many days are in the month
process_monthly_patterns_daily <- function (patterns, n_days = 30){
  patterns %>%
    mutate(
      date_range_start = date_range_start %>%  substr(1,10) %>% as.Date(),
      date_range_end = date_range_end %>%  substr(1,10) %>% as.Date()
    ) -> patterns
  
  exploded <- 
    1:nrow(patterns) %>% 
    map_dfr(function(i){
      daily_visits <-
        substr(patterns$visits_by_day[i],2,nchar(patterns$visits_by_day[i])-1) %>% 
        strsplit(',') %>% 
        .[[1]] %>% 
        as.numeric() %>% 
        as.data.frame() %>% 
        rename(daily_visits = ".")   %>%
        mutate(
          safegraph_place_id = patterns$safegraph_place_id[i],
          date_range_start = patterns$date_range_start[i],
          date = rep(date_range_start+0:(n_days-1)),
          #County = patterns$County.x[i],
          #Precinct = patterns$Precinct.x[i],
          #Poll_location = patterns$polling_place_name[i]
        )
    })
}

# This function processes weekly patterns such that you have individual hourly visits for each POI, but also broken out by origin.
# Argument patterns specifies the Safegraph weekly patterns dataset. 
# Argument normalization must be FALSE (TODO: support normalization = TRUE to normalize by CBG). 
# Argument sparsifier: int. If sparsifier = -1, then hours with 0 visits are counted. If set to 0, then all 0s are removed.
# Returns patterns dataset with individual rows for individual hours and origins by POI, and upper and lower bounds for visit counts.
process_patterns_origins_hourly <- function(patterns, 
                                            normalization = FALSE, sparsifier = -1){
  
  #Load the SafeGraph patterns dataset.
  sg <- 
    patterns %>% 
    dplyr::select(
      safegraph_place_id,
      location_name,
      street_address,
      city,
      region,
      postal_code,
      date_range_start,
      date_range_end,
      raw_visit_counts,
      raw_visitor_counts,
      visits_by_each_hour,
      visitor_home_cbgs
    )
  
  #Load the SafeGraph home panel summary.
  # hps <- home_panel_summary
  
  # print("Normalize data")
  # TODO: add normalization
  # sg_norm <- normBG(sg, hps) 
  # 
  # sum <- 
  #   sg_norm %>% 
  #   mutate(
  #     date_range_start = date_range_start %>%  substr(1,10) %>% as.Date(),
  #     date_range_end = date_range_end %>%  substr(1,10) %>% as.Date()
  #   ) 
  # 
  
  # cut off the hours from the dates
  # (it's always a 24-hour period; the hours information is in a separate column)
  sg %>%
    mutate(
    date_range_start = date_range_start %>%  substr(1,10) %>% as.Date(),
    date_range_end = date_range_end %>%  substr(1,10) %>% as.Date()
  ) -> sg
  
  # print("Expand daily visits")
  
  hour_exploded <- 
    1:nrow(sg) %>% 
    map_dfr(function(i){
      
      # if(i%%100 == 0) print(i)
      
      hourly_visits <-
        substr(sg$visits_by_each_hour[i],2,nchar(sg$visits_by_each_hour[i])-1) %>% 
        strsplit(',') %>% 
        .[[1]] %>% 
        as.numeric() %>% 
        as.data.frame() %>% 
        rename(hourly_visits = ".") %>% 
        mutate(
          date = rep(sg$date_range_start[i]+0:6,each=24),
          hour = rep(1:24,7)) %>%
        filter(hourly_visits > sparsifier) %>%
        mutate(
          safegraph_place_id = sg$safegraph_place_id[i],
          date_range_start = sg$date_range_start[i]
        )
    })
  
  hour_final <-
    hour_exploded %>%
    left_join(
      sg %>% 
        dplyr::select(
          -date_range_end,
          -visits_by_each_hour,
          -visitor_home_cbgs
        ), 
      by = c("safegraph_place_id","date_range_start")
    )
  
  return(hour_final)
}