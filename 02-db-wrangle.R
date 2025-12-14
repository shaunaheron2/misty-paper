library(duckdb)
library(dplyr)
library(tidyverse)
library(janitor)
library(readr)
library(jsonlite)
# to start an in-memory database
# con <- dbConnect(duckdb())
# or
#con <- dbConnect(duckdb(), dbdir = ":memory:")
# to use a database file (not shared between processes)
#con <- dbConnect(duckdb(), dbdir = "experiment_data.duckdb", read_only = FALSE)
# to use a database file (shared between processes)
con <- dbConnect(duckdb(), dbdir = "data/experiment_data.duckdb")
#dbDisconnect(con)
dbListTables(con)


valid_ids <- c(
  "P12",
  "P14",
  "P17",
  "P27",
  "P28",
  "P29",
  "P30",
  "P31",
  "P32",
  "P33",
  "P35",
  "P36",
  "P37",
  "P38",
  "P40",
  "P41",
  "P42",
  "P45",
  "P46",
  "P47",
  "P48",
  "P50",
  "P51",
  "P52",
  "P56",
  "P57",
  "P58",
  "P59",
  "P60"
)

# write in correct group
sessions <- tbl(con, "sessions") |>
  select(-completed, -total_duration_seconds, -end_time) |>
  filter(start_time >= '2025-11-18') |>
  collect() |>
  filter(session_id %in% valid_ids) |>
  #filter(!grepl('P09|P10|P11|P20|P34|P49|P53|P54|P55', session_id)) |>
  mutate(
    group = ifelse(
      grepl('P14|P27|P29|P30|P36|P38|P46|P47|P50|P52|P56|P59|P60', session_id),
      'CONTROL',
      'EXPERIMENTAL'
    )
  ) |>
  mutate(
    native_english = ifelse(
      grepl(
        'P28|P31|P36|P37|P41|P45|P50|P51|P52|P57|P58|P59|P60',
        session_id
      ),
      "TRUE",
      "FALSE"
    )
  ) |>
  filter(!is.na(group)) |>
  select(-mode)
#valid_ids <- sessions |> pull(session_id)
#write_csv(sessions, 'sessions.csv')

# Load events (this contains emotion detection data, frustration counts and user actions)

events <- tbl(con, "events") |>
  filter(timestamp >= '2025-11-18') |>
  collect() |>
  filter(session_id %in% valid_ids)

# Load dialogue turns

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
  ) |>
  mutate(
    frust_flag = ifelse(grepl('frustrated', flags), 1, 0),
    silence_flag = ifelse(grepl('silence', flags), 1, 0),
    engaged_flag = ifelse(grepl('curious|engage', flags), 1, 0),
    neg_flag = ifelse(grepl('disap|anxious|irrit', flags), 1, 0)
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
    n_silence = sum(silence_flag),
    n_engaged = sum(engaged_flag),
    n_frust = sum(frust_flag),
    n_neg = sum(neg_flag),
    .groups = 'drop'
  )

stage_aggregates2 <- sessions |>
  left_join(stage_aggregates, by = 'session_id')

stage_aggs_wide <- stage_aggregates |>
  pivot_wider(
    names_from = 'stage',
    values_from = c(n_turns, duration_mins, avg_response_ms),
    values_fill = 0
  )

sessions2 <- sessions |>
  select(-start_time, -participant_name) |>
  left_join(stage_aggregates, by = 'session_id')

## Load task responses

task_responses <- tbl(con, "task_responses") |>
  filter(submitted_at >= '2025-11-18') |>
  collect()

# 1. Match task responses to sessions by time window (0–30 min after start)

sessions_time <- sessions |>
  select(session_id, start_time) |>
  mutate(start_time = as.POSIXct(start_time, tz = attr(start_time, "tzone")))

task_responses_time <- task_responses |>
  select(-session_id, -id, -time_spent_seconds) |>
  mutate(
    submitted_at = as.POSIXct(submitted_at, tz = attr(submitted_at, "tzone"))
  )

# Cartesian + filter window (OK for small n)
candidate_matches <- task_responses_time |>
  inner_join(sessions_time, by = character()) |>
  mutate(
    diff_mins = as.numeric(difftime(submitted_at, start_time, units = "mins"))
  ) |>
  filter(diff_mins >= 0, diff_mins <= 50) |>
  select(
    session_id,
    start_time,
    submitted_at,
    diff_mins,
    task_name,
    response_data
  )

# 3. Parse JSON response_data
# Remove wrapping quotes if present
task_responses_parsed <- candidate_matches |>
  mutate(response_clean = str_replace_all(response_data, '^"|"$', "")) |>
  mutate(
    parsed = map(
      response_clean,
      ~ {
        tryCatch(
          {
            fromJSON(.x)
          },
          error = function(e) {
            # Return empty list if malformed
            list()
          }
        )
      }
    )
  ) |>
  # Expand key-value pairs to columns
  unnest_wider(parsed, names_repair = "unique") |>
  # Keep only relevant extracted fields; ensure columns exist
  mutate(
    suspect_id = if_else(
      task_name == "task1_suspect",
      suspect_id,
      NA_character_
    ),
    status = if_else(task_name == "task2_location", status, NA_character_),
    building = if_else(task_name == "task2_location", building, NA_character_),
    floor = if_else(task_name == "task2_location", floor, NA_character_),
    zone = if_else(task_name == "task2_location", zone, NA_character_)
  ) |>
  select(-response_data, -response_clean, -task_name) |>
  group_by(session_id) |>
  summarise(across(everything(), ~ na.omit(.x)[1])) |>
  filter(session_id %in% valid_ids)


task_responses2 <- sessions |>
  left_join(task_responses_parsed, by = 'session_id') |>
  mutate(
    suspect_correct = ifelse(suspect_id == '16', 1, 0),
    status_correct = ifelse(!grepl('Not', status), 1, 0),
    building_correct = ifelse(building == 'Engineering Building', 1, 0),
    floor_correct = ifelse(floor == '2 West Wing', 1, 0),
    zone_correct = ifelse(zone == 'Loading bay', 1, 0)
  ) |>
  mutate(
    total_correct = suspect_correct +
      status_correct +
      building_correct +
      floor_correct +
      zone_correct
  ) |>
  select(
    -start_time.x,
    -suspect_id,
    -status,
    -building,
    -floor,
    -zone,
    -submitted_at,
    -start_time.y,
    -diff_mins
  ) |>
  mutate(prop_correct = total_correct / 5)

emotion_aggs_flat <- stage_aggregates2 |>
  group_by(group, session_id) |>
  summarise(
    n_turns = sum(n_turns),
    duration_mins = sum(duration_mins),
    avg_response_ms = mean(avg_response_ms),
    n_silence = sum(n_silence),
    n_engaged = sum(n_engaged),
    n_frust = sum(n_frust),
    n_neg = sum(n_neg)
  )

full_table <- task_responses2 |>
  left_join(emotion_aggs_flat, by = c('group', 'session_id'))


saveRDS(full_table, 'full_session_data.rds')
