library(tidyverse)
library(janitor)
library(haven)

pre <- read_sav('data/HRI-Experiment-Pre_November+22,+2025_09.13.sav') |> 
  clean_names() |>
  select(login_id, recorded_date, email = q19, group, q1:q37_22)

post <- read_sav('data/HRI-Experiment-Post_November+22,+2025_09.13.sav') |> 
  clean_names() |>
  select(response_id, recorded_date, email = recipient_email, q2_1:q4_7)
