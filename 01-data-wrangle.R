library(tidyverse)
library(janitor)
library(haven)

pre_in_progress <- read_sav('data/HRI-Responses-in-Progress.sav') |>
  clean_names()

pre <- read_sav('data/HRI-Experiment-Pre_November+22,+2025_09.13.sav') |>
  clean_names() |>
  select(login_id, recorded_date, email = q19, group, q1:q37_22) |>
  filter(grepl('Control|Experimental', group))

post <- read_sav('data/HRI-Experiment-Post_November+22,+2025_09.13.sav') |>
  clean_names() |>
  select(response_id, recorded_date, email = recipient_email, q2_1:q4_7) |>
  filter(recorded_date >= '2025-11-18')

valid_emails <- post |> pull(email) |> unique()

pre_filt <- pre |>
  filter(email %in% valid_emails)

long_prefix <- "Please answer the following based on how much you agree or disagree with the\nfollowing statements: - "

pre_item_names <- sjlabelled::get_label(
  pre_filt,
  def.value = names(pre_filt)
) |>
  str_remove(long_prefix) |> # drop leading boilerplate if present
  janitor::make_clean_names() # ensure syntactic, unique

names(pre_filt) <- pre_item_names

pre_filt2 <- pre_filt |>
  select(
    -contains('by_selecting'),
    -please_choose_a_date_and_time_for_your_session_from_the_available_options,
    -are_you_18_years_of_age_or_older_with_normal_or_corrected_to_normal_vision_and_hearing_comfortable_and_fluent_in_reading_and_communicating_in_english_and_willing_to_attend_an_in_person_session_at_laurentian_university
  ) |>
  rename(
    email = please_enter_your_email_address_so_that_we_can_link_your_registration_to_your_in_person_session
  )

long_prefix <- "Please rate the following statements, based on the task you have just completed. - "

post_item_names <- sjlabelled::get_label(
  post,
  def.value = names(post)
) |>
  str_remove(long_prefix) |> # drop leading boilerplate if present
  janitor::make_clean_names() # ensure syntactic, unique

names(post) <- post_item_names

final_df <- pre_filt2 |>
  select(
    -login_id,
    pre_date = recorded_date,
    email,
    age,
    gender:i_would_trust_a_human_assistant_to_give_me_accurate_information
  ) |>
  full_join(
    post |>
      select(
        -response_id,
        post_date = recorded_date,
        recipient_email:what_percent_of_the_time_did_this_robot_follow_directions
      ),
    by = join_by(email == recipient_email)
  ) |>
  select(-group)

write_csv(final_df, 'survey_data.csv')
