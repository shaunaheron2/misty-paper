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
library(rstan)
library(bayesplot)

#theme_set(theme_tidybayes() + panel_border())

rstan_options(auto_write = TRUE)
options(mc.cores = parallel::detectCores())

session_df <- readRDS("full_session_data.rds")
survey_df <- readRDS("survey_data.rds") |>
  arrange(post_date)

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
      from = c(1, 5)
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

#saveRDS(scores_df_full, "scores_df_full_scaled.rds")

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

hri_elig_df <- scores_df_eligible |>
  filter(scale == 'HRI_perception_post')

set.seed(15693)
## Models Eligible

hri_mod_elig <- brm(
  robot_trust_post ~ group +
    nars_pre_c +
    native_english +
    (1 | session_id) +
    (1 | trust_items),
  data = hri_elig_df,
  family = gaussian(),
  prior = priors,
  chains = 4,
  cores = 10,
  iter = 4000,
  warmup = 1000,
  control = list(adapt_delta = 0.95)
)
#saveRDS(hri_mod_elig, 'data/analysis_output/hri_mod_elig.rds')
saveRDS(hri_mod_elig, 'data/analysis_output/hri_mod_elig_corrected.rds')
hri_posterior <- as.matrix(hri_mod_elig)

plot_title1 <- ggtitle(
  "Posterior distributions for HRI Trust Perception Scale",
  "with medians and 80% intervals"
)

mcmc_areas(
  hri_posterior,
  pars = c(
    "b_groupRESPONSIVE",
    "b_nars_pre_c",
    "b_native_englishNonMNativeEnglish"
  ),
  prob = 0.8
) +
  plot_title1

hrc_mod_elig <- brm(
  robot_trust_post ~ group +
    (nars_pre_c) +
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
#saveRDS(hrc_mod_elig, 'data/analysis_output/hrc_mod_elig.rds')
saveRDS(hrc_mod_elig, 'data/analysis_output/hrc_mod_elig_corrected.rds')

hrc_posterior <- as.matrix(hrc_mod_elig)

plot_title2 <- ggtitle(
  "Posterior distributions for HRC Trust Experience Scale",
  "with medians and 80% intervals"
)

mcmc_areas(
  hrc_posterior,
  pars = c(
    "b_groupRESPONSIVE",
    "b_nars_pre_c",
    "b_native_englishNonMNativeEnglish"
  ),
  prob = 0.8
) +
  plot_title2


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
#saveRDS(hri_mod_sens, 'data/analysis_output/hri_mod_sens.rds')
saveRDS(hri_mod_sens, 'data/analysis_output/hri_mod_sens_corrected.rds')

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
#saveRDS(hrc_mod_sens, 'data/analysis_output/hrc_mod_sens.rds')
saveRDS(hrc_mod_sens, 'data/analysis_output/hrc_mod_sens_corrected.rds')

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
#saveRDS(hri_mod_mech, 'data/analysis_output/hri_mod_mech.rds')
saveRDS(hri_mod_mech, 'data/analysis_output/hri_mod_mech_corrected.rds')

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

#saveRDS(hrc_mod_mech, 'data/analysis_output/hrc_mod_mech.rds')
saveRDS(hrc_mod_mech, 'data/analysis_output/hrc_mod_mech_corrected.rds')

summary(hri_mod_elig)
summary(hrc_mod_elig)

pp_check(hri_mod_elig) # post_trust_perc
pp_check(hrc_mod_elig) # post_trust (likert)

nuts_params(hri_mod_elig) %>% count(Parameter == "divergent__")
nuts_params(hrc_mod_elig) %>% count(Parameter == "divergent__")

post <- posterior::as_draws_df(hri_mod_elig)

mean(post$b_groupRESPONSIVE > 0) # P(effect > 0)
mean(post$b_groupRESPONSIVE > 5) # P(effect > small)
mean(post$b_groupRESPONSIVE > 10) # P(effect > moderate)
mean(post$b_groupRESPONSIVE > 15) # P(effect > large)

post <- posterior::as_draws_df(hrc_mod_elig)

mean(post$b_groupRESPONSIVE > 0) # P(effect > 0)
mean(post$b_groupRESPONSIVE > 5) # P(effect > small)
mean(post$b_groupRESPONSIVE > 10) # P(effect > moderate)
mean(post$b_groupRESPONSIVE > 15) # P(effect > large)

VarCorr(hri_mod_elig)
VarCorr(hrc_mod_elig)

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
  data = scores_df_eligible |> filter(scale != 'HRI_perception_post')
)

mod_dep2 <- lmer(
  robot_trust_post ~ group *
    prop_comm_breakdown +
    (1 | session_id) +
    (1 | trust_items),
  data = scores_df_eligible |> filter(scale != 'HRI_perception_post')
)
mod_dep3 <- lmer(
  robot_trust_post ~ group *
    prop_comm_breakdown +
    nars_pre_c +
    (1 | session_id) +
    (1 | trust_items),
  data = scores_df_eligible |> filter(scale != 'HRI_perception_post')
)
mod_dep4 <- lmer(
  robot_trust_post ~ group *
    prop_comm_breakdown +
    nars_pre_c +
    native_english +
    (1 | session_id) +
    (1 | trust_items),
  data = scores_df_eligible |> filter(scale != 'HRI_perception_post')
)
compare_performance(mod_dep, mod_dep2, mod_dep3, mod_dep4, rank = TRUE)

# > summary(hri_mod_sens)
#  Family: gaussian
#   Links: mu = identity
# Formula: robot_trust_post ~ group + nars_pre_c + native_english + (1 | session_id) + (1 | trust_items)
#    Data: filter(scores_df_full, scale != "HRI_perception_po (Number of observations: 261)
#   Draws: 4 chains, each with iter = 4000; warmup = 1000; thin = 1;
#          total post-warmup draws = 12000

# Multilevel Hyperparameters:
# ~session_id (Number of levels: 29)
#               Estimate Est.Error l-95% CI u-95% CI Rhat Bulk_ESS Tail_ESS
# sd(Intercept)    11.79      1.57     9.00    15.19 1.00     5284     6971

# ~trust_items (Number of levels: 9)
#               Estimate Est.Error l-95% CI u-95% CI Rhat Bulk_ESS Tail_ESS
# sd(Intercept)     2.64      1.43     0.14     5.57 1.00     3696     4170

# Regression Coefficients:
#                                 Estimate Est.Error l-95% CI u-95% CI Rhat Bulk_ESS Tail_ESS
# Intercept                          66.97      4.44    58.35    75.59 1.00     4889     6541
# groupRESPONSIVE                     7.06      4.40    -1.63    15.71 1.00     5195     6565
# nars_pre_c                         -5.58      2.46   -10.39    -0.80 1.00     5503     6489
# native_englishNonMNativeEnglish    -4.80      4.63   -13.90     4.33 1.00     4848     6016

# Further Distributional Parameters:
#       Estimate Est.Error l-95% CI u-95% CI Rhat Bulk_ESS Tail_ESS
# sigma    16.77      0.79    15.32    18.38 1.00     9757     9369

# Draws were sampled using sampling(NUTS). For each parameter, Bulk_ESS
# and Tail_ESS are effective sample size measures, and Rhat is the potential
# scale reduction factor on split chains (at convergence, Rhat = 1).
# > summary(hrc_mod_sens)
#  Family: gaussian
#   Links: mu = identity
# Formula: robot_trust_post ~ group + nars_pre_c + native_english + (1 | session_id) + (1 | trust_items)
#    Data: filter(scores_df_full, scale == "HRI_perception_po (Number of observations: 346)
#   Draws: 4 chains, each with iter = 4000; warmup = 1000; thin = 1;
#          total post-warmup draws = 12000

# Multilevel Hyperparameters:
# ~session_id (Number of levels: 29)
#               Estimate Est.Error l-95% CI u-95% CI Rhat Bulk_ESS Tail_ESS
# sd(Intercept)    13.57      1.57    10.81    16.92 1.00     4575     6345

# ~trust_items (Number of levels: 12)
#               Estimate Est.Error l-95% CI u-95% CI Rhat Bulk_ESS Tail_ESS
# sd(Intercept)     1.15      0.88     0.04     3.18 1.00     5436     6293

# Regression Coefficients:
#                                 Estimate Est.Error l-95% CI u-95% CI Rhat Bulk_ESS Tail_ESS
# Intercept                          69.78      4.71    60.51    78.99 1.00     4782     6441
# groupRESPONSIVE                     7.12      4.66    -2.09    16.21 1.00     4295     6184
# nars_pre_c                         -3.82      2.64    -8.93     1.35 1.00     4512     6066
# native_englishNonMNativeEnglish    -9.39      4.93   -18.93     0.21 1.00     4755     6164

# Further Distributional Parameters:
#       Estimate Est.Error l-95% CI u-95% CI Rhat Bulk_ESS Tail_ESS
# sigma    13.83      0.54    12.81    14.93 1.00    14876     9293

# Draws were sampled using sampling(NUTS). For each parameter, Bulk_ESS
# and Tail_ESS are effective sample size measures, and Rhat is the potential
# scale reduction factor on split chains (at convergence, Rhat = 1).
# > report(hrc_mod_mech)

# > hrc_mod_mech
#  Family: gaussian
#   Links: mu = identity
# Formula: robot_trust_post ~ group * prop_comm_breakdown + nars_pre_c + (1 | session_id) + (1 | trust_items)
#    Data: filter(scores_df_full, scale != "HRI_perception_po (Number of observations: 261)
#   Draws: 4 chains, each with iter = 4000; warmup = 1000; thin = 1;
#          total post-warmup draws = 12000

# Multilevel Hyperparameters:
# ~session_id (Number of levels: 29)
#               Estimate Est.Error l-95% CI u-95% CI Rhat Bulk_ESS Tail_ESS
# sd(Intercept)    11.67      1.58     8.89    15.09 1.00     5584     7331

# ~trust_items (Number of levels: 9)
#               Estimate Est.Error l-95% CI u-95% CI Rhat Bulk_ESS Tail_ESS
# sd(Intercept)     2.68      1.43     0.14     5.60 1.00     3840     4245

# Regression Coefficients:
#                                     Estimate Est.Error l-95% CI u-95% CI Rhat Bulk_ESS Tail_ESS
# Intercept                              63.61      4.34    55.11    72.31 1.00     7251     7792
# groupRESPONSIVE                         9.35      4.80    -0.29    18.55 1.00     7495     7006
# prop_comm_breakdown                     2.12      7.65   -12.73    17.20 1.00     9748     8908
# nars_pre_c                             -4.90      2.38    -9.53    -0.15 1.00     6169     7780
# groupRESPONSIVE:prop_comm_breakdown    -7.58      8.66   -24.54     9.56 1.00    11784     8742

# Further Distributional Parameters:
#       Estimate Est.Error l-95% CI u-95% CI Rhat Bulk_ESS Tail_ESS
# sigma    16.77      0.79    15.32    18.40 1.00    10632     9038

# Draws were sampled using sampling(NUTS). For each parameter, Bulk_ESS
# and Tail_ESS are effective sample size measures, and Rhat is the potential
# scale reduction factor on split chains (at convergence, Rhat = 1).
# > report(hrc_mod_mech)
# Response residuals not available to calculate mean square error. (R)MSE is probably not reliable.
# Response residuals not available to calculate mean square error. (R)MSE is probably not reliable.
# We fitted a Bayesian linear mixed model (estimated using MCMC sampling with 4 chains of 4000 iterations and a warmup of 1000) to predict
# robot_trust_post with group, prop_comm_breakdown and nars_pre_c (formula: robot_trust_post ~ group * prop_comm_breakdown + nars_pre_c). The model
# included session_id as random effects (formula: list(~1 | session_id, ~1 | trust_items)). Priors were: b_Intercept ~ Normal(μ = 50.00, σ = 25.00),
# b_groupRESPONSIVE ~ Normal(μ = 0.00, σ = 10.00), b_prop_comm_breakdown ~ Normal(μ = 0.00, σ = 10.00), b_nars_pre_c ~ Normal(μ = 0.00, σ = 10.00)
# and b_groupRESPONSIVE:prop_comm_breakdown ~ Normal(μ = 0.00, σ = 10.00). The model's explanatory power is substantial (R2 = 0.44, 95% CI [0.35,
# 0.52], adj. R2 = 0.39) and the part related to the fixed effects alone (marginal R2) is of 0.08 (95% CI [8.27e-03, 0.17]). Within this model:

#   - The effect of b Intercept (Median = 63.58, 95% CI [55.11, 72.31]) has a 100.00% probability of being positive (> 0), 100.00% of being
# significant (> 1.18), and 100.00% of being large (> 7.06). The estimation successfully converged (Rhat = 1.000) and the indices are reliable (ESS
# = 7454)
#   - The effect of b groupRESPONSIVE (Median = 9.47, 95% CI [-0.29, 18.55]) has a 97.12% probability of being positive (> 0), 95.23% of being
# significant (> 1.18), and 68.65% of being large (> 7.06). The estimation successfully converged (Rhat = 1.000) and the indices are reliable (ESS =
# 11675)
#   - The effect of b prop comm breakdown (Median = 1.99, 95% CI [-12.73, 17.20]) has a 60.66% probability of being positive (> 0), 54.87% of being
# significant (> 1.18), and 26.03% of being large (> 7.06). The estimation successfully converged (Rhat = 1.000) and the indices are reliable (ESS =
# 7234)
#   - The effect of b nars pre c (Median = -4.91, 95% CI [-9.53, -0.15]) has a 97.82% probability of being negative (< 0), 94.00% of being significant
# (< -1.18), and 18.02% of being large (< -7.06). The estimation successfully converged (Rhat = 1.000) and the indices are reliable (ESS = 6150)
#   - The effect of b groupRESPONSIVE × prop comm breakdown (Median = -7.60, 95% CI [-24.54, 9.56]) has a 81.15% probability of being negative (< 0),
# 77.57% of being significant (< -1.18), and 52.62% of being large (< -7.06). The estimation successfully converged (Rhat = 1.000) and the indices
# are reliable (ESS = 9695)

# Following the Sequential Effect eXistence and sIgnificance Testing (SEXIT) framework, we report the median of the posterior distribution and its
# 95% CI (Highest Density Interval), along the probability of direction (pd), the probability of significance and the probability of being large.
# The thresholds beyond which the effect is considered as significant (i.e., non-negligible) and large are |1.18| and |7.06| (corresponding
# respectively to 0.05 and 0.30 of the outcome's SD). Convergence and stability of the Bayesian sampling has been assessed using R-hat, which should
# be below 1.01 (Vehtari et al., 2019), and Effective Sample Size (ESS), which should be greater than 1000 (Burkner, 2017).
# > report(hri_mod_mech)
# Response residuals not available to calculate mean square error. (R)MSE is probably not reliable.
# Response residuals not available to calculate mean square error. (R)MSE is probably not reliable.
# We fitted a Bayesian linear mixed model (estimated using MCMC sampling with 4 chains of 4000 iterations and a warmup of 1000) to predict robot_trust_post with
# group, prop_comm_breakdown and nars_pre_c (formula: robot_trust_post ~ group * prop_comm_breakdown + nars_pre_c). The model included session_id as random effects
# (formula: list(~1 | session_id, ~1 | trust_items)). Priors were: b_Intercept ~ Normal(μ = 50.00, σ = 25.00), b_groupRESPONSIVE ~ Normal(μ = 0.00, σ = 10.00),
# b_prop_comm_breakdown ~ Normal(μ = 0.00, σ = 10.00), b_nars_pre_c ~ Normal(μ = 0.00, σ = 10.00) and b_groupRESPONSIVE:prop_comm_breakdown ~ Normal(μ = 0.00, σ =
# 10.00). The model's explanatory power is substantial (R2 = 0.60, 95% CI [0.55, 0.65], adj. R2 = 0.58) and the part related to the fixed effects alone (marginal R2)
# is of 0.07 (95% CI [3.61e-03, 0.16]). Within this model:

#   - The effect of b Intercept (Median = 65.70, 95% CI [56.68, 74.87]) has a 100.00% probability of being positive (> 0), 100.00% of being significant (> 1.13), and
# 100.00% of being large (> 6.78). The estimation successfully converged (Rhat = 1.001) and the indices are reliable (ESS = 4609)
#   - The effect of b groupRESPONSIVE (Median = 8.61, 95% CI [-1.96, 18.86]) has a 94.62% probability of being positive (> 0), 92.01% of being significant (> 1.13), and
# 63.43% of being large (> 6.78). The estimation successfully converged (Rhat = 1.000) and the indices are reliable (ESS = 8160)
#   - The effect of b prop comm breakdown (Median = -4.56, 95% CI [-20.18, 11.13]) has a 71.33% probability of being negative (< 0), 66.42% of being significant (<
# -1.13), and 38.78% of being large (< -6.78). The estimation successfully converged (Rhat = 1.001) and the indices are reliable (ESS = 4307)
#   - The effect of b nars pre c (Median = -2.46, 95% CI [-7.81, 2.71]) has a 82.62% probability of being negative (< 0), 69.67% of being significant (< -1.13), and
# 5.60% of being large (< -6.78). The estimation successfully converged (Rhat = 1.000) and the indices are reliable (ESS = 3885)
#   - The effect of b groupRESPONSIVE × prop comm breakdown (Median = -3.94, 95% CI [-21.16, 13.42]) has a 66.86% probability of being negative (< 0), 62.22% of being
# significant (< -1.13), and 37.67% of being large (< -6.78). The estimation successfully converged (Rhat = 1.000) and the indices are reliable (ESS = 6814)

# Following the Sequential Effect eXistence and sIgnificance Testing (SEXIT) framework, we report the median of the posterior distribution and its 95% CI (Highest
# Density Interval), along the probability of direction (pd), the probability of significance and the probability of being large. The thresholds beyond which the
# effect is considered as significant (i.e., non-negligible) and large are |1.13| and |6.78| (corresponding respectively to 0.05 and 0.30 of the outcome's SD).
# Convergence and stability of the Bayesian sampling has been assessed using R-hat, which should be below 1.01 (Vehtari et al., 2019), and Effective Sample Size
# (ESS), which should be greater than 1000 (Burkner, 2017).
# > report(hrc_mod_elig)
# Response residuals not available to calculate mean square error. (R)MSE is probably not reliable.
# Response residuals not available to calculate mean square error. (R)MSE is probably not reliable.
# We fitted a Bayesian linear mixed model (estimated using MCMC sampling with 4 chains of 4000 iterations and a warmup of 1000) to predict robot_trust_post with group,
# nars_pre_c and native_english (formula: robot_trust_post ~ group + nars_pre_c + native_english). The model included session_id as random effects (formula: list(~1 |
# session_id, ~1 | trust_items)). Priors were: b_Intercept ~ Normal(μ = 50.00, σ = 25.00), b_groupRESPONSIVE ~ Normal(μ = 0.00, σ = 10.00), b_nars_pre_c ~ Normal(μ = 0.00, σ =
# 10.00) and b_native_englishNonMNativeEnglish ~ Normal(μ = 0.00, σ = 10.00). The model's explanatory power is substantial (R2 = 0.42, 95% CI [0.32, 0.51], adj. R2 = 0.37) and
# the part related to the fixed effects alone (marginal R2) is of 0.22 (95% CI [0.09, 0.33]). Within this model:

#   - The effect of b Intercept (Median = 62.75, 95% CI [55.42, 69.95]) has a 100.00% probability of being positive (> 0), 100.00% of being significant (> 1.12), and 100.00% of
# being large (> 6.74). The estimation successfully converged (Rhat = 1.001) and the indices are reliable (ESS = 5296)
#   - The effect of b groupRESPONSIVE (Median = 14.98, 95% CI [7.29, 22.22]) has a 99.98% probability of being positive (> 0), 99.97% of being significant (> 1.12), and 98.21%
# of being large (> 6.74). The estimation successfully converged (Rhat = 1.001) and the indices are reliable (ESS = 5047)
#   - The effect of b nars pre c (Median = -6.62, 95% CI [-10.60, -2.48]) has a 99.88% probability of being negative (< 0), 99.50% of being significant (< -1.12), and 47.73% of
# being large (< -6.74). The estimation successfully converged (Rhat = 1.001) and the indices are reliable (ESS = 5106)
#   - The effect of b native englishNonMNativeEnglish (Median = -7.68, 95% CI [-15.39, 0.57]) has a 96.64% probability of being negative (< 0), 94.27% of being significant (<
# -1.12), and 59.14% of being large (< -6.74). The estimation successfully converged (Rhat = 1.000) and the indices are reliable (ESS = 4466)

# Following the Sequential Effect eXistence and sIgnificance Testing (SEXIT) framework, we report the median of the posterior distribution and its 95% CI (Highest Density
# Interval), along the probability of direction (pd), the probability of significance and the probability of being large. The thresholds beyond which the effect is considered
# as significant (i.e., non-negligible) and large are |1.12| and |6.74| (corresponding respectively to 0.05 and 0.30 of the outcome's SD). Convergence and stability of the
# Bayesian sampling has been assessed using R-hat, which should be below 1.01 (Vehtari et al., 2019), and Effective Sample Size (ESS), which should be greater than 1000
# (Burkner, 2017).
# > report(hri_mod_elig)
# Response residuals not available to calculate mean square error. (R)MSE is probably not reliable.
# Response residuals not available to calculate mean square error. (R)MSE is probably not reliable.
# We fitted a Bayesian linear mixed model (estimated using MCMC sampling with 4 chains of 4000 iterations and a warmup of 1000) to predict robot_trust_post with group,
# nars_pre_c and native_english (formula: robot_trust_post ~ group + nars_pre_c + native_english). The model included session_id as random effects (formula: list(~1 |
# session_id, ~1 | trust_items)). Priors were: b_Intercept ~ Normal(μ = 50.00, σ = 25.00), b_groupRESPONSIVE ~ Normal(μ = 0.00, σ = 10.00), b_nars_pre_c ~ Normal(μ = 0.00, σ =
# 10.00) and b_native_englishNonMNativeEnglish ~ Normal(μ = 0.00, σ = 10.00). The model's explanatory power is substantial (R2 = 0.64, 95% CI [0.59, 0.68], adj. R2 = 0.61) and
# the part related to the fixed effects alone (marginal R2) is of 0.16 (95% CI [0.04, 0.29]). Within this model:

#   - The effect of b Intercept (Median = 66.30, 95% CI [57.23, 75.52]) has a 100.00% probability of being positive (> 0), 100.00% of being significant (> 1.15), and 100.00% of
# being large (> 6.88). The estimation successfully converged (Rhat = 1.001) and the indices are reliable (ESS = 5197)
#   - The effect of b groupRESPONSIVE (Median = 12.76, 95% CI [2.96, 22.06]) has a 99.36% probability of being positive (> 0), 98.84% of being significant (> 1.15), and 88.52%
# of being large (> 6.88). The estimation successfully converged (Rhat = 1.001) and the indices are reliable (ESS = 5871)
#   - The effect of b nars pre c (Median = -3.84, 95% CI [-9.11, 1.59]) has a 91.85% probability of being negative (< 0), 83.68% of being significant (< -1.15), and 12.60% of
# being large (< -6.88). The estimation successfully converged (Rhat = 1.001) and the indices are reliable (ESS = 5771)
#   - The effect of b native englishNonMNativeEnglish (Median = -10.40, 95% CI [-20.35, -0.14]) has a 97.66% probability of being negative (< 0), 95.99% of being significant (<
# -1.15), and 75.15% of being large (< -6.88). The estimation successfully converged (Rhat = 1.000) and the indices are reliable (ESS = 5373)

# Following the Sequential Effect eXistence and sIgnificance Testing (SEXIT) framework, we report the median of the posterior distribution and its 95% CI (Highest Density
# Interval), along the probability of direction (pd), the probability of significance and the probability of being large. The thresholds beyond which the effect is considered
# as significant (i.e., non-negligible) and large are |1.15| and |6.88| (corresponding respectively to 0.05 and 0.30 of the outcome's SD). Convergence and stability of the
# Bayesian sampling has been assessed using R-hat, which should be below 1.01 (Vehtari et al., 2019), and Effective Sample Size (ESS), which should be greater than 1000
# (Burkner, 2017).
