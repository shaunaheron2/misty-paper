library(tidyverse)
library(janitor)
library(haven)

pre <- read_sav('data/HRI-Experiment-Pre_November+22,+2025_09.13.sav') |> clean_names()
post <- read_sav('data/HRI-Experiment-Post_November+22,+2025_09.13.sav') |> clean_names()
