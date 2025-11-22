library(duckdb)
library(dplyr)
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
  filter(start_time >= '2025-11-18') |>
  collect()|>
  filter(!grepl('P09|P10|P11|P20|P34', session_id))

#write_csv(sessions, 'sessions.csv')

turns <- tbl(con, "dialogue_turns") |>
  filter(timestamp >= '2025-11-18') |>
  collect() |>
  filter(!grepl('P09|P10|P11|P20|P34', session_id)) # exclude problematic participant

turns |> group_by(session_id, expression) |>
  summarise(n = n()) |>
  arrange(session_id, expression) |>
  ungroup() |>
  group_by(session_id) |>
  pull(max(n))

turns |> 
  group_by(expression) |>
  summarise(n = n()) |>
  arrange(desc(n))

turns2 <- turns |> 
  group_by(session_id) |> mutate(start_time = min(as.Date(timestamp)), end_time = max(as.Date(timestamp)), total_duration = as.numeric(difftime(max(timestamp), min(timestamp), units = "mins"))) |>
  select(session_id, start_time, end_time, total_duration) |>
  distinct() |>
  filter(total_duration > 4)
  
turns2|>
  arrange(session_id) |>
  ungroup() |>
  summarise(mean_duration = mean(total_duration), median_duration = median(total_duration), sd_duration = sd(total_duration))


