#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#

library(tidyverse)
library(janitor)
library(scales)
library(corrplot)
library(sjPlot)
library(ggstatsplot)
library(psych)
library(performance)
library(Hmisc)
library(haven)
library(gtsummary)

session_df <- readRDS("full_session_data.rds")
survey_df <- readRDS("survey_data.rds") |>
  arrange(post_date)


set_gtsummary_theme(theme_gtsummary_journal("jama"))
set_gtsummary_theme(theme_gtsummary_compact())

df_flat_scores_final <- readRDS("full_dataset_with_items.rds") #|>
# filter(!grepl('sprig', email))

#saveRDS(df_flat_scores_final_with_items, 'full_dataset_with_items.rds')
#
#
#
#
#
#
#
#
#
#
#
#
#

df_flat_scores_final |>
  data.frame() |>
  select(-post_date) |>
  droplevels() |>
  select(
    group,
    gender,
    age,
    program,
    robot_xp,
    native_english,
    nars_pre,
    nars_social_influence_robots,
    nars_emotion_robots,
    nars_interaction_robots,
    nfc_pre,
    robot_trust_pre,
    ai_trust_pre,
    human_trust_pre
    #contains('trust')
    #-mytrust_pre
  ) |>
  tbl_summary(
    by = group,
    type = list(
      nars_pre ~ 'continuous',
      nars_social_influence_robots ~ 'continuous',
      nars_emotion_robots ~ 'continuous',
      nars_interaction_robots ~ 'continuous',
      human_trust_pre ~ 'continuous',
      robot_trust_pre ~ 'continuous',

      ai_trust_pre ~ 'continuous',
      nfc_pre ~ 'continuous'
    ),
    statistic = list(
      all_continuous() ~ "{mean} ({sd})",
      all_categorical() ~ "{n} / {N} ({p}%)"
    ),
    label = list(
      gender ~ "Gender",
      age ~ "Age Group",
      program ~ "Program",
      robot_xp ~ "Experience w/Robots",
      native_english ~ 'Native English Speaker',
      nfc_pre ~ 'Need for Cognition',
      nars_pre ~ "NARS Overall",
      nars_social_influence_robots ~ "NARS: Social Influence",
      nars_emotion_robots ~ "NARS: Emotions",
      nars_interaction_robots ~ "NARS: Interaction"
    ),
    missing_text = ('Missing')
  ) |>
  add_n() |>
  add_p() |>
  #add_overall() |>
  bold_p() |>
  bold_labels() |>
  modify_caption(
    "Table 1. Participant Demographics and Baseline Characteristics by Group"
  )

post_table <- df_flat_scores_final |>
  drop_na(gender) |>
  select(group, contains('post'), contains('correct'), 63:76) |>
  data.frame()

post_table |>
  tbl_summary(
    by = group,
    type = list(
      post_trust_reliability ~ 'continuous',
      post_trust_feelings ~ 'continuous',
      post_trust_perception ~ 'continuous',
      total_correct ~ 'continuous',
      avg_response_ms ~ 'continuous',
      prop_correct ~ 'continuous',
      n_engaged ~ 'continuous',
      n_frust ~ 'continuous',
      n_neg ~ 'continuous'
    ),
    # missing=FALSE,
    statistic = list(
      all_continuous() ~ "{mean} ({sd})",
      all_categorical() ~ "{n} / {N} ({p}%)"
    ),
    label = list(
      suspect_correct ~ "Suspect ID Accuracy",
      status_correct ~ "Status ID Accuracy",
      duration_mins ~ "Avg Task Duration (mins)",

      total_correct ~ "Total Task Accuracy",
      n_turns ~ "Number of Dialogue Turns",
      n_silence ~ "Number of Silent Periods",
      avg_response_ms ~ "Avg Response Time (ms)",
      prop_correct ~ "Overall Task Accuracy",
      n_engaged ~ "Number of Engaged Responses",
      n_frust ~ "Number of Frustrated Responses",
      trust_perc_post ~ "Post-Task Trust Perception"
    )
  ) |>
  add_n() |>
  add_p() |>
  # add_overall() |>
  bold_p() |>
  #bold_labels() |>
  modify_caption("Table 2. Post-Interaction Raw Outcome Measures by Group")


#
#
#
#
#| fig-height: 7
#| fig-width: 7

df_flat <- df_flat_scores_final |>
  mutate(group = factor(group, levels = c("CONTROL", "RESPONSIVE"))) |>
  mutate(
    native_english = factor(native_english, levels = c("FALSE", "TRUE"))
  ) |>
  select(
    -contains('what_perc'),
    -contains('i_'),
    -contains('the_'),
    -contains('something'),
    -contains('thinking')
  )

# df_flat %>%
#   group_by(group) %>%
#   dplyr::summarise(
#     correlation = cor(human_trust, robot_trust, method = "pearson", use = "pairwise.complete.obs"),
#     .groups = "drop"
#   )

res2 <- rcorr(as.matrix(df_flat_scores_final %>% select(where(is.numeric))))

corr <- cor(
  df_flat %>% select(where(is.numeric)),
  use = "pairwise.complete.obs"
)

testRes = cor.mtest(corr, conf.level = 0.95)
#corrplot(corr, p.mat = testRes$p,  cl.pos = 'n')

corrplot(
  corr,
  p.mat = testRes$p,
  insig = 'label_sig',
  sig.level = c(0.001, 0.01, 0.05),
  pch.cex = 0.9,
  pch.col = 'grey20'
)

#corrplot(corr, p.mat = testRes$p, insig = 'p-value')
# ++++++++++++++++++++++++++++
# flattenCorrMatrix
# ++++++++++++++++++++++++++++
# cormat : matrix of the correlation coefficients
# pmat : matrix of the correlation p-values
flattenCorrMatrix <- function(cormat, pmat) {
  ut <- upper.tri(cormat)
  data.frame(
    row = rownames(cormat)[row(cormat)[ut]],
    column = rownames(cormat)[col(cormat)[ut]],
    cor = (cormat)[ut],
    p = pmat[ut]
  )
}

flatmatrix <- flattenCorrMatrix(res2$r, res2$P)


# https://sjdm.org/dmidi/Need_for_Cognition_short.html
# Lins de Holanda Coelho G, H P Hanel P, J Wolf L. The Very Efficient Assessment of Need for
#Cognition: Developing a Six-Item Version. Assessment. 2020 Dec;27(8):1870-1885. doi:
#10.1177/1073191118793208. Epub 2018 Aug 10. PMID: 30095000; PMCID: PMC7545655
# https://rins.st.ryukoku.ac.jp/~nomura/docs/NARS_AAAI06.pdf
# items. hus, the minimum and maximum scores are 6 and
#  https://uhra.herts.ac.uk/id/eprint/13608/1/SyrdalDDautenhahn.pdf <-- discusses problems using standardized scale cross-culturally
#
#
#
#
#
#
#
#
#| fig-height: 7
#| fig-width: 7
#|
df_pre_cor <- df_flat_scores_final |>
  drop_na(gender) |>
  select(
    session_id,
    group,
    age,
    program,
    robot_xp,
    native_english,
    contains('nars'),
    contains('pre')
  )

res2 <- rcorr(as.matrix(df_pre_cor %>% select(where(is.numeric))))

group_correlations <- df_pre_cor |>
  group_by(native_english) |>
  dplyr::summarize(cor = cor(nars_pre, nfc_pre))

df_pre_cor |>
  group_by(native_english) |>
  summarise(
    n = n(),
    mean_nfc = mean(nfc_pre, na.rm = TRUE),
    mean_nars = mean(nars_pre, na.rm = TRUE),
    mean_nars_interation = mean(nars_interaction_robots, na.rm = TRUE),
    mean_nars_emotion = mean(nars_emotion_robots, na.rm = TRUE),
    mean_nars_social = mean(nars_social_influence_robots, na.rm = TRUE)
  )

ggbetweenstats(x = native_english, y = nfc_pre, df_pre_cor)

df_pre_cor |>
  group_by(program) |>
  summarise(
    n = n(),
    mean_nfc = mean(nfc_pre, na.rm = TRUE),
    mean_nars = mean(nars_pre, na.rm = TRUE),
    mean_nars_interation = mean(nars_interaction_robots, na.rm = TRUE),
    mean_nars_emotion = mean(nars_emotion_robots, na.rm = TRUE),
    mean_nars_social = mean(nars_social_influence_robots, na.rm = TRUE)
  )


df_pre_cor |>
  group_by(robot_xp) |>
  summarise(
    n = n(),
    mean_nfc = mean(nfc_pre, na.rm = TRUE),
    mean_nars = mean(nars_pre, na.rm = TRUE),
    mean_nars_interation = mean(nars_interaction_robots, na.rm = TRUE),
    mean_nars_emotion = mean(nars_emotion_robots, na.rm = TRUE),
    mean_nars_social = mean(nars_social_influence_robots, na.rm = TRUE)
  )

ggbetweenstats(x = robot_xp, y = nfc_pre, df_pre_cor)
ggbetweenstats(x = robot_xp, y = nars_pre, df_pre_cor)

grouped_ggbetweenstats(
  x = group,
  y = nfc_pre,
  df_pre_cor,
  grouping.var = robot_xp
)
grouped_ggbetweenstats(
  x = group,
  y = nars_pre,
  df_pre_cor,
  grouping.var = robot_xp
)

corr <- cor(
  df_pre_cor %>% select(where(is.numeric)),
  use = "pairwise.complete.obs"
)

testRes = cor.mtest(corr, conf.level = 0.95)
#corrplot(corr, p.mat = testRes$p,  cl.pos = 'n')

corrplot(
  corr,
  p.mat = testRes$p,
  insig = 'label_sig',
  sig.level = c(0.001, 0.01, 0.05),
  pch.cex = 0.9,
  pch.col = 'grey20'
)

library("PerformanceAnalytics")
chart.Correlation(
  df_pre_cor |> select(where(is.numeric)),
  histogram = TRUE,
  pch = 19
)

hist(df_pre_cor$nfc_pre)
hist(df_pre_cor$nars_pre)

ggplot(df_pre_cor, aes(x = nfc_pre, fill = group)) +
  geom_density(alpha = 0.5)

ggplot(df_pre_cor, aes(x = nfc_pre, fill = group)) +
  geom_histogram(color = 'grey30', fill = "white") +
  facet_wrap(~group)
#https://uc-r.github.io/histograms
ggplot(df_pre_cor, aes(x = nars_pre, fill = group)) +
  geom_histogram(color = 'grey30', fill = "white") +
  facet_wrap(~group)
#corrplot(corr, p.mat = testRes$p, insig = 'p-value')
# ++++++++++++++++++++++++++++
# flattenCorrMatrix
# ++++++++++++++++++++++++++++
# cormat : matrix of the correlation coefficients
# pmat : matrix of the correlation p-values
flattenCorrMatrix <- function(cormat, pmat) {
  ut <- upper.tri(cormat)
  data.frame(
    row = rownames(cormat)[row(cormat)[ut]],
    column = rownames(cormat)[col(cormat)[ut]],
    cor = (cormat)[ut],
    p = pmat[ut]
  )
}

flatmatrix <- flattenCorrMatrix(res2$r, res2$P)


# https://sjdm.org/dmidi/Need_for_Cognition_short.html
# Lins de Holanda Coelho G, H P Hanel P, J Wolf L. The Very Efficient Assessment of Need for
#Cognition: Developing a Six-Item Version. Assessment. 2020 Dec;27(8):1870-1885. doi:
#10.1177/1073191118793208. Epub 2018 Aug 10. PMID: 30095000; PMCID: PMC7545655
# https://rins.st.ryukoku.ac.jp/~nomura/docs/NARS_AAAI06.pdf
# items. hus, the minimum and maximum scores are 6 and
#  https://uhra.herts.ac.uk/id/eprint/13608/1/SyrdalDDautenhahn.pdf <-- discusses problems using standardized scale cross-culturally
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#

library(lme4)
library(lmerTest)
library(ggeffects)
# mixed models

scores_df <- df_flat_scores_final |>
  #drop_na(gender) |>
  select(
    session_id,
    email,
    group,
    gender,
    age,
    native_english,
    program,
    robot_xp,
    nars_pre,
    human_trust_pre,
    robot_trust_pre,
    ai_trust_pre,
    nars_social_influence_robots,
    nars_emotion_robots,
    nars_interaction_robots,
    nfc_pre,
    contains("what_percent"),
  ) |>
  pivot_longer(
    what_percent_of_the_time_was_the_robot_dependable:what_percent_of_the_time_did_this_robot_answer_the_questions_asked,
    names_to = "trust_items",
    values_to = "robot_trust_post"
  ) |>
  # scale continuous predictors
  mutate(
    robot_trust_post_c = scale(robot_trust_post, center = TRUE, scale = TRUE)
  ) |>
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
  mutate(robot_xp = relevel(robot_xp, ref = "No")) |>
  mutate(native_english = factor(native_english))

hist(scores_df$robot_trust_post)
hist(scores_df$robot_trust_post_c)

#
#
#

base = lm(robot_trust_post ~ group, data = scores_df)
mod1 <- lmer(
  robot_trust_post ~ group +
    (1 | session_id) ,
  data = scores_df
)

mod2 <- lmer(
  robot_trust_post ~ group +
    #(1 | session_id) +
    (1 | trust_items),
  data = scores_df
)


mod2 <- lmer(
  robot_trust_post ~ group +
    nars_pre_c +
    nfc_pre_c +
    (1 | session_id) +
    (1 | trust_items),
  contrasts = list(
    trust_items = "contr.sum",
    labels = TRUE
  ),
  data = scores_df
)

mod3 <- lmer(
  robot_trust_post ~ group +
    nars_pre_c +
    nfc_pre_c +
    robot_xp +
    (1 | session_id) +
    (1 | trust_items),
  contrasts = list(
    trust_items = "contr.sum",
    labels = TRUE
  ),
  data = scores_df
)

mod4 <- lmer(
  robot_trust_post ~ group * robot_xp + (1 | session_id),
  contrasts = list(
    trust_items = "contr.sum",
    labels = TRUE
  ),
  data = scores_df
)

anova(mod1, mod2, mod3, mod4, base)
tab_model(mod1, mod3, mod4)
#
#
#
#
#
#
#

library(brms)

df <- scores_df |> mutate(trust_z = scale(robot_trust_post))

priors_trust <- c(
  prior(normal(0, 0.5), class = "b"), # group effect
  prior(normal(0, 1), class = "Intercept"), # grand mean
  prior(exponential(1), class = "sd"), # random effects
  prior(exponential(1), class = "sigma") # residual SD
)

fit_trust <- brm(
  robot_trust_post ~ group + (1 | session_id),
  data = df,
  family = gaussian(),
  # prior = priors_trust,
  chains = 4,
  iter = 4000,
  cores = 10,
  control = list(adapt_delta = 0.95)
  #family=gaussian()
)

fit_trust2 <- brm(
  robot_trust_post ~ group + (1 | session_id) + (1 | trust_items),
  data = df,
  family = gaussian(),
  # prior = priors_trust,
  chains = 4,
  iter = 4000,
  cores = 10,
  control = list(adapt_delta = 0.95)
)


posterior_summary(fit_trust, variable = "b_groupRESPONSIVE")
# build a baseline flat model without random effects
#base <- brm(robot_trust ~ group, data = scores_df)

post <- posterior_samples(fit_trust)

mean(post$b_groupRESPONSIVE > 0) # P(effect > 0)
mean(post$b_groupRESPONSIVE > 5) # P(effect > small)
mean(post$b_groupRESPONSIVE > 10) # P(effect > moderate)


#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#| fig.height: 9
#| fig.width: 6

predictions <- predict_response(
  mod7,
  terms = c("group", "native_english", "robot_xp")
)

plot(predictions, n_rows = 1, connect_lines = TRUE, ci_style = 'dot') +
  theme(legend.position = "bottom") +
  scale_color_discrete() +
  theme(legend.position = "bottom", legend.direction = "vertical")

plot(predictions, n_rows = 1, connect_lines = TRUE, ci_style = 'dot') +
  theme(legend.position = "bottom") +
  scale_color_discrete() +
  ggtitle(
    "Treatment x Native English Speaker (True vs False)"
  ) +
  theme(legend.position = "bottom", legend.direction = "vertical")

#
#
#

ggbetweenstats(x = group, y = trust_perc_post, df_flat_scores_final)

ggbetweenstats(x = group, y = post_trust, df_flat_scores_final)

#
#
#
#
#

scores_df2 <- df_flat_scores_final |>
  select(
    session_id,
    email,
    group,
    gender,
    age,
    native_english,
    program,
    robot_xp,
    nars_pre,
    human_trust_pre,
    robot_trust_pre,
    ai_trust_pre,
    nars_social_influence_robots,
    nars_emotion_robots,
    nars_interaction_robots,
    nfc_pre,
    the_way_the_robot_moved_made_me_uncomfortable:the_robot_seemed_to_care_about_helping_me
  ) |>
  pivot_longer(
    the_way_the_robot_moved_made_me_uncomfortable:the_robot_seemed_to_care_about_helping_me,
    names_to = "trust_items",
    values_to = "robot_trust_post"
  ) |>
  # scale continuous predictors
  #mutate(robot_trust_c = scale(robot_trust, center=TRUE, scale=TRUE)) |>
  mutate(nars_pre_c = scale(nars_pre, center = TRUE, scale = TRUE)) |>
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
  mutate(robot_xp = relevel(robot_xp, ref = "No")) |>
  mutate(native_english = factor(native_english))


#
#
#
# put the other trust scale on the same 0-100 scale for easier interpretation
# scores_df2$robot_trust_post <- (scores_df2$robot_trust2 - 1) / 4 * 100

base <- lm(robot_trust_post ~ group, data = scores_df2)

mod1 <- lmer(
  robot_trust_post ~ group +
    (1 | session_id) +
    (1 | trust_items),
  data = scores_df2
)

mod2 <- lmer(
  robot_trust_post ~ group +
    nars_pre +
    nfc_pre +

    (1 | session_id) +
    (1 | trust_items),
  data = scores_df2
)

anova(mod1, mod2, base)

grouped_ggbetweenstats(
  x = group,
  y = robot_trust_post,
  grouping.var = trust_items,
  scores_df2
)

grouped_ggbetweenstats(
  x = group,
  y = robot_trust_post,
  grouping.var = trust_items,
  scores_df
)
#
#
#
#
#

#| fig.height: 8
#| fig.width: 6
predictions <- predict_response(
  mod5,
  terms = c(
    "group",
    "trust_items",
    #"native_english",
    "robot_xp"
  )
)

plot(predictions, n_rows = 1, connect_lines = TRUE, ci_style = 'dot') +
  theme(legend.position = "bottom") +
  scale_color_discrete() +
  ggtitle(
    "Treatment x Prior Robot Experience (Yes vs No)"
  ) +
  theme(legend.position = "bottom", legend.direction = "vertical")

#
#
#

#
#
#
# put the likert scores on a 0-100 scale for easier interpretation

base <- lm(robot_trust ~ group + nars_pre + nfc_pre, data = scores_df2)

mod1 <- lmer(
  robot_trust ~ group +
    nars_pre +
    nfc_pre +
    (1 | session_id) +
    (1 | trust_items),
  data = scores_df2
)

mod2 <- lmer(
  robot_trust ~ group *
    #  trust_items +
    nars_pre +
    nfc_pre +
    (1 | session_id) +
    (1 | trust_items),
  data = scores_df2
)

mod3 <- lmer(
  robot_trust ~ group *
    trust_items +
    nars_pre +
    nars_pre_s1 +
    nars_pre_s2 +
    nars_pre_s3 +
    (1 | session_id),
  data = scores_df2
)

mod4 <- lmer(
  robot_trust ~ group *
    trust_items +
    native_english +
    nars_pre +
    nfc_pre +
    (1 | session_id),
  data = scores_df2
)


mod5 <- lmer(
  robot_trust ~ group *
    trust_items +
    robot_xp +
    native_english +
    nars_pre +
    nfc_pre +
    (1 | session_id),
  data = scores_df2
)

# predictions <- predict_response(mod2, terms = c("group", "trust_items"))

# plot(predictions, n_rows = 2) +
#   theme(legend.position = "bottom") +
#   scale_color_discrete()

#compare_performance(mod1, mod2, mod3, mod4, mod5, rank = TRUE)

# grouped_ggbetweenstats(
#   x = group,
#   y = robot_trust,
#   grouping.var = trust_items,
#   data = scores_df2
# )
grouped_ggbetweenstats(
  x = group,
  y = robot_trust2,
  grouping.var = trust_items,
  scores_df_2
)
#
#
#
#
#

accuracy_df <- df2 |>
  select(
    session_id,
    group,
    gender,
    age,
    program,
    robot_xp,
    the_way_the_robot_moved_made_me_uncomfortable:the_robot_seemed_to_care_about_helping_me,
    native_english:n_frust
  ) |>
  pivot_longer(
    suspect_correct:zone_correct,
    names_to = "accuracy_items",
    values_to = "accuracy",
  ) |>
  left_join(
    df_flat_scores_final |>
      select(session_id, contains('nars_'), contains('nfc_')),
    by = "session_id"
  ) |>
  mutate(accuracy_items = factor(accuracy_items)) |>
  mutate(group = factor(group, levels = c("CONTROL", "EXPERIMENTAL"))) |>
  mutate(program = as_factor(program)) |>
  mutate(robot_xp = as_factor(robot_xp)) |>
  mutate(
    native_english = factor(native_english, levels = c("FALSE", "TRUE"))
  ) |>
  select(-total_correct)


base <- glm(
  accuracy ~ group + nars_pre + nfc_pre,
  family = binomial(link = "logit"),
  data = accuracy_df
)
base2 <- glm(
  accuracy ~ group + accuracy_items + nars_pre + nfc_pre,
  family = binomial(link = "logit"),
  data = accuracy_df
)
base3 <- glm(
  accuracy ~ group * accuracy_items + nars_pre + nfc_pre,
  family = binomial(link = "logit"),
  data = accuracy_df
)
base4 <- glm(
  accuracy ~ group * native_english + accuracy_items + nars_pre + nfc_pre,
  family = binomial(link = "logit"),
  data = accuracy_df
)

mod1 <- glmer(
  accuracy ~ group +
    nars_pre +
    nfc_pre +
    (1 | session_id) +
    (1 | accuracy_items),
  family = binomial(link = "logit"),
  data = accuracy_df
)


mod2 <- glmer(
  accuracy ~ group +
    accuracy_items +
    native_english +
    # robot_xp +
    nars_pre +
    nfc_pre +
    (1 | accuracy_items) +
    (1 | session_id),
  family = binomial(link = "logit"),
  data = accuracy_df
)
tab_model(mod2)

# predictions <- predict_response(mod2, terms = c("native_english", "group"))

# plot(predictions, n_rows = 2) +
#   theme(legend.position = "bottom") +
#   scale_color_discrete()

compare_performance(mod1, mod2, mod3, mod4, mod5, rank = TRUE)

# grouped_ggbetweenstats(x = group, y = accuracy, grouping.var = native_english, accuracy_df)
# mod3 <- lmer(
#   robot_trust ~ group *
#     trust_items +
#     nars_pre +
#     nars_pre_s1 +
#     nars_pre_s2 +
#     nars_pre_s3 +
#     (1 | session_id),
#   data = scores_df2
# )

# mod4 <- lmer(
#   robot_trust ~ group *
#     trust_items +
#     native_english +
#     nars_pre +
#     nfc_pre +
#     (1 | session_id),
#   data = scores_df2
# )

# mod5 <- lmer(
#   robot_trust ~ group *
#     trust_items +
#     robot_xp +
#     native_english +
#     nars_pre +
#     nfc_pre +
#     (1 | session_id),
#   data = scores_df2
# )
#
#
#

# ggbetweenstats(x = group, y = nars_pre, df_flat_scores_final)
# ggbetweenstats(x = group, y = nars_pre_s1, df_flat_scores_final)
# ggbetweenstats(x = group, y = nars_pre_s2, df_flat_scores_final)
# ggbetweenstats(x = group, y = nars_pre_s3, df_flat_scores_final)

#ggbetweenstats(x = group, y = post_trust, df_flat_scores_final)

#
#
#
