library(duckdb)
library(dplyr)
library(tidyverse)
library(janitor)
library(readr)

# to start an in-memory database
# con <- dbConnect(duckdb())
# or
#con <- dbConnect(duckdb(), dbdir = ":memory:")
# to use a database file (not shared between processes)
#con <- dbConnect(duckdb(), dbdir = "experiment_data.duckdb", read_only = FALSE)
# to use a database file (shared between processes)
con <- dbConnect(duckdb(), dbdir = "experiment_data.duckdb")
#dbDisconnect(con)
dbListTables(con)


# write in correct group
sessions <- tbl(con, "sessions") |>
  select(-completed, -total_duration_seconds, -end_time) |>
  filter(start_time >= '2025-11-18') |>
  collect() |>
  filter(!grepl('P09|P10|P11|P20|P34', session_id)) |>
  mutate(
    group = case_when(
      grepl('P14|P27|P29|P30|P36|P38|P46|P47', session_id) ~ 'CONTROL',
      grepl(
        'P12|P17|P28|P31|P32|P33|P35|P37|P40|P41|P42|P45|P48',
        session_id
      ) ~ 'EXPERIMENTAL',
      TRUE ~ NA_character_
    )
  ) |>
  mutate(
    native_english = case_when(
      grepl(
        'P12|P14|P17|P27|P29|P30|P32|P33|P35|P38|P40|P42|P46|P47|P48',
        session_id
      ) ~ 'FALSE',
      grepl('P28|P31|P36|P37|P41|P45', session_id) ~ 'TRUE',
      TRUE ~ NA_character_
    )
  ) |>
  filter(!is.na(group))

valid_ids <- sessions |> pull(session_id)
#write_csv(sessions, 'sessions.csv')

turns <- tbl(con, "dialogue_turns") |>
  filter(timestamp >= '2025-11-18') |>
  collect() |>
  filter(session_id %in% valid_ids)

turns |>
  group_by(session_id, expression) |>
  summarise(n = n()) |>
  arrange(session_id, expression) |>
  ungroup() |>
  group_by(session_id) |>
  pull(max(n))

turns |>
  group_by(expression) |>
  summarise(n = n()) |>
  arrange(desc(n))

session_aggregates <- turns |>
  group_by(session_id) |>
  mutate(
    start_time = min(timestamp),
    end_time = max(timestamp),
    turns = n_distinct(turn_number),
    total_duration = as.numeric(difftime(
      max(timestamp),
      min(timestamp),
      units = "mins"
    ))
  )

stage_aggregates <- session_aggregates |>
  group_by(session_id, stage) |>
  summarise(
    n_turns = n_distinct(turn_number),
    duration_mins = as.numeric(difftime(
      max(timestamp),
      min(timestamp),
      units = "mins"
    )),
    avg_response_ms = mean(response_time_ms / 60),
  )

stage_aggs_wide <- stage_aggregates |>
  pivot_wider(
    names_from = 'stage',
    values_from = c(n_turns, duration_mins, avg_response_ms),
    values_fill = 0
  )

sessions2 <- sessions |>
  select(-start_time, -participant_name) |>
  left_join(stage_aggregates, by = 'session_id')
