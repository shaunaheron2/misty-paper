library(duckdb)
library(dplyr)
library(tidyverse)
library(janitor)
library(readr)
library(jsonlite)


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

turns <- read_csv('data/analysis_output/dialogue_turns_20251212_153544.csv') |>
  filter(session_id %in% valid_ids)
