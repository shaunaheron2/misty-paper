library(tidyverse)
library(janitor)
library(scales)
library(corrplot)
library(sjPlot)
library(ggstatsplot)
library(psych)
library(performance)
library(gt)
library(Hmisc)
library(haven)
library(gtsummary)
library(lme4)
library(lmerTest)
library(ggeffects)

session_df <- readRDS("full_session_data.rds")
survey_df <- readRDS("survey_data.rds") |>
  arrange(post_date)

set_gtsummary_theme(theme_gtsummary_journal("jama"))
set_gtsummary_theme(theme_gtsummary_compact())

dialogue_session_summary <- read_csv(
  'data/analysis_output/final_dialogue_summary.csv'
) |>
  mutate(
    exclusions = if_else(
      mean_comm_breakdown > .6,
      'exclude',
      'include'
    )
  ) |>
  select(
    session_id,
    -n_turns,
    contains('prop'),
    n_stage_skipped,
    n_task_turns,
    contains('burden'),
    contains('viability'),
    exclusions
  )

df_flat_scores_final <- readRDS("full_dataset_with_items.rds") |>
  left_join(dialogue_session_summary, by = join_by(session_id)) |>
  mutate(
    post_trust = scales::rescale(
      post_trust,
      to = c(0, 100),
      min_old = 1,
      max_old = 5
    )
  )

df_long_scores_final <- readRDS("full_dataset_long_trust_post.csv") |>
  left_join(dialogue_session_summary, by = join_by(session_id))


# mixed models

scores_df_full <- df_long_scores_final |>
  mutate(nars_pre_c = scale(nars_pre, center = TRUE, scale = TRUE)) |>
  mutate(robot_trust_c = scale(robot_trust_pre, center = TRUE, scale = TRUE)) |>
  mutate(human_trust_c = scale(human_trust_pre, center = TRUE, scale = TRUE)) |>
  mutate(ai_trust_c = scale(ai_trust_pre, center = TRUE, scale = TRUE)) |>
  mutate(nfc_pre_c = scale(nfc_pre, center = TRUE, scale = TRUE)) |>
  mutate(
    nars_social_influence_robots_c = scale(
      nars_social_influence_robots,
      center = TRUE,
      scale = TRUE
    )
  ) |>
  mutate(
    nars_emotion_robots_c = scale(
      nars_emotion_robots,
      center = TRUE,
      scale = TRUE
    )
  ) |>
  mutate(
    nars_interaction_robots_c = scale(
      nars_interaction_robots,
      center = TRUE,
      scale = TRUE
    )
  ) |>
  mutate(trust_items = factor(trust_items)) |>
  mutate(group = factor(group)) |>
  mutate(robot_xp = relevel(robot_xp, ref = "No")) |>
  mutate(native_english = factor(native_english)) |>
  mutate(scale = factor(scale))

scores_df_eligible <- scores_df_full |>
  filter(exclusions != 'exclude')

saveRDS(scores_df_full, "scores_df_full.rds")
