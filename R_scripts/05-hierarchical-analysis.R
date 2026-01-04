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
library(brms)

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

### Priors

priors <- c(
  prior(normal(50, 25), class = "Intercept"), # trust score center-ish, wide
  prior(normal(0, 10), class = "b"), # effects in points on 0-100
  prior(exponential(1), class = "sd"), # RE SDs: subject/item
  prior(exponential(1), class = "sigma") # residual SD
)
# priors for the null
priors_null <- c(
  prior(normal(50, 25), class = "Intercept"),
  prior(exponential(1), class = "sd"),
  prior(exponential(1), class = "sigma")
)
# sensitivity analysis: wider and tighter priors
priors_wide <- c(
  prior(normal(50, 40), class = "Intercept"),
  prior(normal(0, 20), class = "b"),
  prior(exponential(0.5), class = "sd"),
  prior(exponential(0.5), class = "sigma")
)
priors_tight <- c(
  prior(normal(50, 20), class = "Intercept"),
  prior(normal(0, 7), class = "b"),
  prior(exponential(1.5), class = "sd"),
  prior(exponential(1.5), class = "sigma")
)

## Models Eligible

hri_mod_elig <- brm(
  robot_trust_post ~ group +
    nars_pre_c +
    native_english +
    (1 | session_id) +
    (1 | trust_items),
  data = scores_df_eligible |> filter(scale == 'HRI_perception_post'),
  family = gaussian(),
  prior = priors,
  chains = 4,
  cores = 10,
  iter = 4000,
  warmup = 1000,
  control = list(adapt_delta = 0.95)
)

hrc_mod_elig <- brm(
  robot_trust_post ~ group +
    nars_pre_c +
    native_english +
    (1 | session_id) +
    (1 | trust_items),
  data = scores_df_eligible |> filter(scale != 'HRI_perception_post'),
  family = gaussian(),
  prior = priors,
  chains = 4,
  cores = 10,
  iter = 4000,
  warmup = 1000,
  control = list(adapt_delta = 0.95)
)


## Models Full Sensitivity

hri_mod_sens <- brm(
  robot_trust_post ~ group +
    nars_pre_c +
    native_english +
    (1 | session_id) +
    (1 | trust_items),
  data = scores_df_full |> filter(scale != 'HRI_perception_post'),
  family = gaussian(),
  prior = priors,
  chains = 4,
  cores = 10,
  iter = 4000,
  warmup = 1000,
  control = list(adapt_delta = 0.95)
)

hrc_mod_sens <- brm(
  robot_trust_post ~ group +
    nars_pre_c +
    native_english +
    (1 | session_id) +
    (1 | trust_items),
  data = scores_df_full |> filter(scale == 'HRI_perception_post'),
  family = gaussian(),
  prior = priors,
  chains = 4,
  cores = 10,
  iter = 4000,
  warmup = 1000,
  control = list(adapt_delta = 0.95)
)

## Models Full Mechanism

hri_mod_mech <- brm(
  robot_trust_post ~ group *
    prop_comm_breakdown +
    nars_pre_c +
    #native_english +
    (1 | session_id) +
    (1 | trust_items),
  data = scores_df_full |> filter(scale == 'HRI_perception_post'),
  family = gaussian(),
  prior = priors,
  chains = 4,
  cores = 10,
  iter = 4000,
  warmup = 1000,
  control = list(adapt_delta = 0.95)
)

hrc_mod_mech <- brm(
  robot_trust_post ~ group *
    prop_comm_breakdown +
    nars_pre_c +
    # native_english +
    (1 | session_id) +
    (1 | trust_items),
  data = scores_df_full |> filter(scale != 'HRI_perception_post'),
  family = gaussian(),
  prior = priors,
  chains = 4,
  cores = 10,
  iter = 4000,
  warmup = 1000,
  control = list(adapt_delta = 0.95)
)


summary(hri_mod)
summary(hrc_mod)

pp_check(hri_mod) # post_trust_perc
pp_check(hrc_mod) # post_trust (likert)

nuts_params(hri_mod) %>% count(Parameter == "divergent__")
nuts_params(hrc_mod) %>% count(Parameter == "divergent__")

post <- posterior::as_draws_df(hri_mod)

mean(post$b_groupRESPONSIVE > 0) # P(effect > 0)
mean(post$b_groupRESPONSIVE > 5) # P(effect > small)
mean(post$b_groupRESPONSIVE > 10) # P(effect > moderate)
mean(post$b_groupRESPONSIVE > 15) # P(effect > large)

post <- posterior::as_draws_df(hrc_mod)

mean(post$b_groupRESPONSIVE > 0) # P(effect > 0)
mean(post$b_groupRESPONSIVE > 5) # P(effect > small)
mean(post$b_groupRESPONSIVE > 10) # P(effect > moderate)
mean(post$b_groupRESPONSIVE > 15) # P(effect > large)

VarCorr(hri_mod)
VarCorr(hrc_mod)

## Lmer models

baseline <- lmer(
  robot_trust_post ~ group +
    (1 | session_id),
  data = scores_df_eligible |> filter(scale == 'HRI_perception_post')
)

mod_dep <- lmer(
  robot_trust_post ~ group +
    (1 | session_id) +
    (1 | trust_items),
  data = scores_df_eligible |> filter(scale == 'HRI_perception_post')
)

mod_dep.2 <- lmer(
  robot_trust_post ~ group *
    prop_comm_breakdown +
    (1 | session_id) +
    (1 | trust_items),
  data = scores_df_eligible |> filter(scale == 'HRI_perception_post')
)

# adding robot_xp worsens fit
mod_dep2 <- lmer(
  robot_trust_post ~ group +
    robot_xp +
    (1 | session_id),
  data = scores_df_eligible |> filter(scale == 'HRI_perception_post')
)
# adding nars improves fit
mod_dep3 <- lmer(
  robot_trust_post ~ group +
    nars_pre_c +
    (1 | session_id),
  data = scores_df_eligible |> filter(scale == 'HRI_perception_post')
)
# adding native english improves fit
mod_dep4 <- lmer(
  robot_trust_post ~ group +
    nars_pre_c +
    native_english +
    (1 | session_id),
  data = scores_df_eligible |> filter(scale == 'HRI_perception_post')
)
compare_performance(mod_dep, mod_dep2, mod_dep3, mod_dep4, rank = TRUE)

mod_dep <- lmer(
  robot_trust_post ~ group +
    (1 | session_id) +
    (1 | trust_items),
  data = scores_df |> filter(scale != 'HRI_perception_post')
)

mod_dep2 <- lmer(
  robot_trust_post ~ group *
    prop_comm_breakdown +
    (1 | session_id) +
    (1 | trust_items),
  data = scores_df |> filter(scale != 'HRI_perception_post')
)
mod_dep3 <- lmer(
  robot_trust_post ~ group *
    prop_comm_breakdown +
    nars_pre_c +
    (1 | session_id) +
    (1 | trust_items),
  data = scores_df |> filter(scale != 'HRI_perception_post')
)
mod_dep4 <- lmer(
  robot_trust_post ~ group *
    prop_comm_breakdown +
    nars_pre_c +
    native_english +
    (1 | session_id) +
    (1 | trust_items),
  data = scores_df |> filter(scale != 'HRI_perception_post')
)
compare_performance(mod_dep, mod_dep2, mod_dep3, mod_dep4, rank = TRUE)

baseline <- lmer(
  robot_trust_post ~ group +
    (1 | session_id),
  data = scores_df_full |> filter(scale != 'HRI_perception_post')
)

mod_dep <- lmer(
  robot_trust_post ~ group +
    (1 | session_id) +
    (1 | trust_items),
  data = scores_df_full |> filter(scale != 'HRI_perception_post')
)

# adding robot_xp worsens fit
mod_dep2 <- lmer(
  robot_trust_post ~ group +
    robot_xp +
    (1 | session_id) +
    (1 | trust_items),
  data = scores_df_full |> filter(scale != 'HRI_perception_post')
)
# adding nars improves fit
mod_dep3 <- lmer(
  robot_trust_post ~ group +
    nars_pre_c +
    (1 | session_id) +
    (1 | trust_items),
  data = scores_df_full |> filter(scale != 'HRI_perception_post')
)
# adding native english improves fit
mod_dep4 <- lmer(
  robot_trust_post ~ group +
    nars_pre_c +
    native_english +
    (1 | session_id) +
    (1 | trust_items),
  data = scores_df_full |> filter(scale != 'HRI_perception_post')
)

mod_dep <- lmer(
  robot_trust_post ~ group +
    (1 | session_id) +
    (1 | trust_items),
  data = scores_df |> filter(scale == 'HRI_perception_post')
)

mod_dep2 <- lmer(
  robot_trust_post ~ group *
    prop_comm_breakdown +
    (1 | session_id) +
    (1 | trust_items),
  data = scores_df |> filter(scale == 'HRI_perception_post')
)
mod_dep3 <- lmer(
  robot_trust_post ~ group *
    prop_comm_breakdown +
    nars_pre_c +
    (1 | session_id) +
    (1 | trust_items),
  data = scores_df |> filter(scale == 'HRI_perception_post')
)
mod_dep4 <- lmer(
  robot_trust_post ~ group *
    prop_comm_breakdown +
    nars_pre_c +
    native_english +
    (1 | session_id) +
    (1 | trust_items),
  data = scores_df |> filter(scale == 'HRI_perception_post')
)
compare_performance(mod_dep, mod_dep2, mod_dep3, mod_dep4, rank = TRUE)
