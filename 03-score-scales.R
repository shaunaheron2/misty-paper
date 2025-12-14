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
library(skimr)

session_df <- readRDS("full_session_data.rds")
survey_df <- readRDS("survey_data.rds") |>
  arrange(post_date) |>
  select(-pre_date)

skim(session_df)
skim(survey_df)

df <- cbind(session_df, survey_df) |>
  select(
    session_id,
    email,
    post_date,
    group,
    age,
    gender,
    program = what_is_your_primary_program_of_study,
    robot_xp = do_you_have_any_experience_with_robots,
    native_english,
    26:69
  ) |>
  mutate(robot_xp = if_else(is.na(robot_xp), 1, robot_xp)) |>
  # mutate(age = haven::as_factor(age)) |>
  mutate(across(gender:robot_xp, ~ haven::as_factor(.x))) |>
  mutate(
    native_english = ifelse(
      native_english == TRUE,
      'Native English',
      'Non-Native English'
    )
  ) |>
  mutate(
    group = factor(
      group,
      levels = c("CONTROL", "EXPERIMENTAL"),
      labels = c('CONTROL', 'RESPONSIVE')
    )
  )

write_csv(df, "check_groups.csv")
#write_csv(df, "codebook.csv")
# The score can range from 1 (you do not like deep thinking) to 5 (you like effortful thinking).

# an individual’s score on each (NARS)
# subscale is calculated by summing the scores of all the items
# included in the subscale, with the reverse of scores in some
# items. hus, the minimum and maximum scores are 6 and
# 30 in S1, 5 and 25 in S2, and 3 and 15 in S3, respectively.
# rescale likert items to 1-5 for scoring

df2 <- df |>
  mutate(across(10:40, ~ as.numeric(.x))) |>
  mutate(across(10:40, ~ scales::rescale(.x, to = c(1, 5))))

# build scoring keys
nfc_keys <- list(
  nfc_pre = c(
    'i_would_prefer_complex_to_simple_problems',
    'i_like_to_have_the_responsibility_of_handling_a_situation_that_requires_a_lot_of_thinking',
    '-thinking_is_not_my_idea_of_fun',
    "-i_would_rather_do_something_that_requires_little_thought_than_something_that_is_sure_to_challenge_my_thinking",
    'i_really_enjoy_a_task_that_involves_coming_up_with_new_solutions_to_problems',
    'i_would_prefer_a_task_that_is_intellectual_difficult_and_important_to_one_that_is_somewhat_important_but_does_not_require_much_thought'
  )
)

# 14 NARS items from pre-survey
# https://doi.org/10.1016/j.chb.2008.09.
nars_keys <- list(
  nars_pre = c(
    'i_would_feel_uneasy_if_robots_really_had_emotions',
    'something_bad_might_happen_if_robots_developed_into_living_beings',
    '-i_would_feel_relaxed_talking_with_robots',
    'i_would_trust_a_robot_assistant_to_give_me_accurate_information',
    '-if_robots_had_emotions_i_would_be_able_to_make_friends_with_them',
    '-i_feel_comforted_being_with_robots_that_have_emotions',
    'the_word_robot_means_nothing_to_me',
    'i_would_feel_nervous_operating_a_robot_in_front_of_other_people',
    'i_would_hate_the_idea_that_robots_or_artificial_intelligences_were_making_judgements_about_things',
    'i_would_feel_very_nervous_to_be_in_the_same_room_as_a_robot',
    'i_feel_that_if_i_depend_on_robots_too_much_something_bad_might_happen',
    'i_would_feel_paranoid_talking_with_a_robot',
    'i_am_concerned_that_robots_would_be_a_bad_influence_on_children',
    'i_feel_that_in_the_future_society_will_be_dominated_by_robots'
  ),
  # Negative At-titude toward Social Influence of Robots”
  nars_social_influence_robots = c(
    'i_would_feel_uneasy_if_robots_really_had_emotions',
    'something_bad_might_happen_if_robots_developed_into_living_beings',
    'i_feel_that_if_i_depend_on_robots_too_much_something_bad_might_happen',
    'i_am_concerned_that_robots_would_be_a_bad_influence_on_children',
    'i_feel_that_in_the_future_society_will_be_dominated_by_robots'
  ),
  #Negative Attitude toward Emotions in Interaction with Robots”
  nars_emotion_robots = c(
    '-i_would_feel_relaxed_talking_with_robots',
    '-if_robots_had_emotions_i_would_be_able_to_make_friends_with_them',
    '-i_feel_comforted_being_with_robots_that_have_emotions'
  ),
  # Negative Attitude toward Situations of Interaction with Robots
  nars_interaction_robots = c(
    'the_word_robot_means_nothing_to_me',
    '-i_would_trust_a_robot_assistant_to_give_me_accurate_information',
    'i_would_feel_nervous_operating_a_robot_in_front_of_other_people',
    'i_would_hate_the_idea_that_robots_or_artificial_intelligences_were_making_judgements_about_things',
    'i_would_feel_very_nervous_to_be_in_the_same_room_as_a_robot',
    'i_would_feel_paranoid_talking_with_a_robot'
  )
)

my_trust_items = list(
  mytrust_pre = c(
    'i_would_trust_an_ai_assistant_to_give_me_accurate_information',
    'i_would_trust_a_human_assistant_to_give_me_accurate_information',
    'i_would_trust_a_robot_assistant_to_give_me_accurate_information'
  )
)

post_trust_keys = list(
  #9
  post_trust = c(
    "-the_way_the_robot_moved_made_me_uncomfortable",
    "-the_way_the_robot_spoke_made_me_uncomfortable",
    "-talking_to_the_robot_made_me_uneasy",
    "i_trusted_that_the_robot_would_give_me_accurate_answers",
    "the_robots_responses_seemed_reliable",
    "i_felt_i_could_rely_on_the_robot_to_do_what_it_was_supposed_to_do",
    "the_robot_seemed_to_enjoy_helping_me",
    "the_robot_was_responsive_to_my_needs",
    "the_robot_seemed_to_care_about_helping_me"
  ),
  post_trust_reliability = c(
    "i_trusted_that_the_robot_would_give_me_accurate_answers",
    "the_robots_responses_seemed_reliable",
    "i_felt_i_could_rely_on_the_robot_to_do_what_it_was_supposed_to_do"
  ),
  post_trust_perception = c(
    "the_robot_seemed_to_enjoy_helping_me",
    "the_robot_was_responsive_to_my_needs",
    "the_robot_seemed_to_care_about_helping_me"
  ),
  post_trust_feelings = c(
    "-the_way_the_robot_moved_made_me_uncomfortable",
    "-the_way_the_robot_spoke_made_me_uncomfortable",
    "-talking_to_the_robot_made_me_uneasy"
  )
)

# https://hriscaledatabase.psychology.gmu.edu/trust/2024/10/31/trustschaefer.html
# next time we need to include the full scale including the reverse scored items

trust_perception_post = list(
  trust_perc_post = c(
    "what_percent_of_the_time_was_the_robot_dependable",
    "what_percent_of_the_time_was_the_robot_reliable",
    "what_percent_of_the_time_was_the_robot_responsive",
    "what_percent_of_the_time_was_the_robot_trustworthy",
    "what_percent_of_the_time_was_the_robot_supportive",
    "what_percent_of_the_time_did_this_robot_act_consistently",
    "what_percent_of_the_time_did_this_robot_provide_feedback",
    "what_percent_of_the_time_did_this_robot_meet_the_needs_of_the_mission_task",
    "what_percent_of_the_time_did_this_robot_provide_appropriate_information",
    "what_percent_of_the_time_did_this_robot_communicate_appropriately",
    "what_percent_of_the_time_did_this_robot_follow_directions",
    "what_percent_of_the_time_did_this_robot_answer_the_questions_asked"
  )
)

nars_scores_stats <- scoreItems(nars_keys, df2, totals = TRUE)


test <- df2 |> select(group, contains('what_per'))
#trust_items2 <- scoreItems(my_trust_items, df2, totals = FALSE)$scores
nars_scores_totals <- scoreItems(nars_keys, df2, totals = TRUE)$scores
nars_scores_means <- scoreItems(nars_keys, df2, totals = FALSE)$scores
nfc_scores <- scoreItems(nfc_keys, df2, totals = FALSE)$scores
post_trust_short <- scoreItems(post_trust_keys, df2, totals = FALSE)$scores

pts <- df2 |>
  select(
    the_way_the_robot_moved_made_me_uncomfortable:the_robot_seemed_to_care_about_helping_me
  )
fa.parallel(pts, fm = "pa", fa = "both")
fa_results <- fa(pts, nfactors = 2)
fa.diagram(fa_results)

post_trust_perc <- scoreItems(
  trust_perception_post,
  df2,
  totals = FALSE,
  min = 0,
  max = 100,
  n.obs = 29
)$scores

all_scores <- cbind(
  #trust_items2,
  nars_scores_totals,
  # nars_scores_means,
  nfc_scores,
  post_trust_short,
  post_trust_perc
) |>
  data.frame()

df_flat_scores <- df2 |>
  select(
    session_id,
    group,
    gender,
    age,
    program,
    robot_xp,
    human_trust_pre = i_would_trust_a_human_assistant_to_give_me_accurate_information,
    robot_trust_pre = i_would_trust_a_robot_assistant_to_give_me_accurate_information,
    ai_trust_pre = i_would_trust_an_ai_assistant_to_give_me_accurate_information,
    everything()
  )

df_flat_scores_final <- cbind(df_flat_scores, all_scores)

df_flat_scores_final2 <- df_flat_scores_final |>
  full_join(
    session_df |> select(-native_english, -participant_name, -group),
    by = join_by(session_id)
  )


saveRDS(df_flat_scores_final2, 'full_dataset_with_items.rds')
