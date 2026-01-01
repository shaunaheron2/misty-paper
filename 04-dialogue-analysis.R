library(tidyverse)
library(janitor)
library(readr)
library(jsonlite)
library(stringr)
library(fs)

# all valid participants (excluding my own test runs)

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

# Load dialogue turns data
turns <- read_csv('data/analysis_output/dialogue_turns_20251212_153544.csv') |>
  filter(session_id %in% valid_ids)

all_sessions <- sort(unique(turns$session_id))

# Define expected stages
expected_stages <- c("greeting", "brief", "task1", "task2", "wrap")

# Directory containing manually coded markdown files
md_dir <- "data/clean_data/coded_turns"

md_files <- dir_ls(md_dir, regexp = "\\.md$")

extract_header_info <- function(lines) {
  sid <- str_match(lines, "\\*\\*Session:\\*\\* `([^`]+)`")[, 2]
  stg <- str_match(lines, "\\*\\*Stage:\\*\\* `([^`]+)`")[, 2]

  tibble(
    session_id = sid[which(!is.na(sid))[1]],
    stage = stg[which(!is.na(stg))[1]]
  )
}

extract_task_outcome <- function(lines) {
  tibble(
    task_completed = as.integer(any(str_detect(lines, "\\[x\\] `completed`"))),
    task_timeout = as.integer(any(str_detect(lines, "\\[x\\] `timeout`"))),
    task_skipped = as.integer(any(str_detect(lines, "\\[x\\] `skipped`"))),
    task_partial = as.integer(any(str_detect(lines, "\\[x\\] `partial`"))),
    task_abandoned = as.integer(any(str_detect(lines, "\\[x\\] `abandoned`")))
  )
}

parse_turn_blocks <- function(lines, session_id, stage) {
  turn_starts <- which(str_detect(lines, "^### Turn\\s+\\d+"))
  if (length(turn_starts) == 0) {
    return(tibble())
  }

  # add sentinel
  turn_starts <- c(turn_starts, length(lines) + 1)

  purrr::map_dfr(seq_len(length(turn_starts) - 1), function(i) {
    block <- lines[turn_starts[i]:(turn_starts[i + 1] - 1)]

    turn_number <- str_match(block[1], "^### Turn\\s+(\\d+)")[, 2] %>%
      as.integer()

    # any checkbox like: - [x] `variable_name`
    checks <- str_match(block, "- \\[(x| )\\] `([^`]+)`")
    checks <- checks[!is.na(checks[, 1]), , drop = FALSE]

    check_df <- tibble(
      variable = checks[, 3],
      value = as.integer(checks[, 2] == "x")
    )

    check_wide <- check_df %>%
      distinct(variable, .keep_all = TRUE) %>% # just in case duplicates
      pivot_wider(names_from = variable, values_from = value, values_fill = 0)

    tibble(
      session_id = session_id,
      stage = stage,
      turn_number = turn_number
    ) %>%
      bind_cols(check_wide)
  })
}


turn_level_df <- purrr::map_dfr(md_files, function(f) {
  lines <- read_lines(f)

  hdr <- extract_header_info(lines)

  if (nrow(hdr) == 0 || any(is.na(hdr$session_id), is.na(hdr$stage))) {
    warning("Header missing in file: ", f)
    return(tibble())
  }

  parse_turn_blocks(lines, hdr$session_id, hdr$stage)
})

# Ensure all sessions and stages are represented
stage_presence <- expand_grid(
  session_id = all_sessions,
  stage = expected_stages
) %>%
  left_join(
    turn_level_df |> distinct(session_id, stage) |> mutate(md_exists = 1),
    by = join_by("session_id", "stage")
  ) %>%
  mutate(
    stage_skipped = ifelse(is.na(md_exists), 1, 0)
  ) |>
  select(-md_exists)

# Extract task outcomes and help styles from markdown files
extract_task_outcomes <- function(lines) {
  # Which outcome is checked?
  outcome_matches <- str_match(
    lines,
    "^\\s*- \\[(x| )\\]\\s*`(completed|timeout|skipped|partial|abandoned)`\\s*$"
  )
  outcome_matches <- outcome_matches[
    !is.na(outcome_matches[, 1]),
    ,
    drop = FALSE
  ]

  outcome_checked <- outcome_matches[outcome_matches[, 2] == "x", 3]
  task_outcome <- if (length(outcome_checked) == 0) {
    NA_character_
  } else {
    outcome_checked[1]
  }

  # task_time_remaining_sec (optional; will be NA if blank)
  ttrs <- str_match(lines, "`task_time_remaining_sec`:\\s*([0-9]+)")[, 2]
  task_time_remaining_sec <- as.numeric(ttrs[which(!is.na(ttrs))[1]])

  # Help-style checkboxes (these are global checkboxes elsewhere in the file too,
  # but your labels are unique, so it's safe to search the full file.)
  get_check <- function(var) {
    as.integer(any(str_detect(
      lines,
      glue::glue("^\\s*- \\[x\\]\\s*`{var}`\\s*$")
    )))
  }

  tibble(
    task_outcome = task_outcome,
    task_time_remaining_sec = task_time_remaining_sec,
    task_completed_with_some_help = get_check("task_completed_with_some_help"),
    task_completed_with_little_help = get_check(
      "task_completed_with_little_help"
    ),
    task_completed_without_help = get_check("task_completed_without_help"),
    task_completed_collaboratively = get_check("task_completed_collaboratively")
  )
}

task_outcomes_df <- map_dfr(md_files, function(f) {
  lines <- read_lines(f)

  hdr <- extract_header_info(lines)
  if (nrow(hdr) == 0 || any(is.na(hdr$session_id), is.na(hdr$stage))) {
    warning("Header missing in file: ", f)
    return(tibble())
  }

  bind_cols(hdr, extract_task_outcomes(lines))
})

task_outcomes_df <- task_outcomes_df %>%
  mutate(
    help_style = case_when(
      task_completed_with_some_help == 1 ~ "some_help",
      task_completed_with_little_help == 1 ~ "little_help",
      task_completed_without_help == 1 ~ "without_help",
      task_completed_collaboratively == 1 ~ "collaborative",
      TRUE ~ NA_character_
    )
  )

# Combine stage presence with task outcomes

final_table <- stage_presence |>
  left_join(task_outcomes_df, by = join_by("session_id", "stage")) |>
  mutate(task_outcome = ifelse(is.na(task_outcome), "skipped", task_outcome)) |>
  mutate(across(where(is.numeric), ~ replace_na(., 0)))

safe_div <- function(num, den) {
  dplyr::if_else(den > 0, num / den, NA_real_)
}

# Aggregate turn-level codes to stage level

stage_summary <- turn_level_df %>%
  group_by(session_id, stage) %>%
  summarise(
    n_turns = n(),
    # n_skipped = sum(n_turns <1, na.rm=TRUE),
    # ---- counts ----
    n_help_requests = sum(
      as.integer(human_help_request == 1 | human_confirmation_seeking == 1),
      na.rm = TRUE
    ),

    n_sentence_frag = sum(
      as.integer(
        human_sentence_fragment == 1 | human_input_fragment == 1
      ),
      na.rm = TRUE
    ),
    # turns where human reasons aloud with the robot
    n_human_reasoning = sum(
      as.integer(human_reasoning_aloud == 1),
      na.rm = TRUE
    ),
    # turns where robot shows misunderstanding of human speech
    n_human_misunderstanding = sum(
      as.integer(human_misunderstanding == 1),
      na.rm = TRUE
    ),
    # turns where human engages affectively with the robot as collaborative partner
    n_human_affective_engagement = sum(
      as.integer(
        human_affective_engagement == 1 |
          human_social_reciprocity == 1 |
          human_anthropomorphic_language == 1
      ),
      na.rm = TRUE
    ),
    # turns where robot provides helpful guidance
    n_robot_helpful_guidance = sum(
      as.integer(robot_helpful_guidance == 1),
      na.rm = TRUE
    ),
    # turns where robot provides unhelpful guidance
    n_robot_unhelpful = sum(
      as.integer(
        robot_misleading_guidance == 1 |
          robot_factually_incorrect == 1 |
          robot_on_policy_unhelpful == 1 |
          robot_policy_violation == 1
      ),
      na.rm = TRUE
    ),
    # turns where robot proactively checks in with human after silence
    n_robot_proactive_checkin = sum(
      as.integer(robot_proactive_checkin == 1),
      na.rm = TRUE
    ),
    # turns where robot offers encouragement
    n_robot_encouragement = sum(
      as.integer(robot_encouragement == 1),
      na.rm = TRUE
    ),
    # turns where robot uses collaborative language (e.g., "we", "let's")
    n_robot_collaborative_lang = sum(
      as.integer(robot_collaborative_language == 1),
      na.rm = TRUE
    ),
    # turns where robot reasons aloud (collaboratively) with human
    n_robot_reasoning = sum(
      as.integer(robot_reasoning_aloud == 1),
      na.rm = TRUE
    ),
    # turns where robot seeks clarification (e.g., what do you see in the log?)
    n_robot_clarification = sum(
      as.integer(robot_clarification_request == 1),
      na.rm = TRUE
    ),
    # turns where robot expresses empathy or understanding of human's state
    n_robot_empathy_expression = sum(
      as.integer(
        robot_empathy_expression == 1 | robot_emotion_acknowledgement == 1
      ),
      na.rm = TRUE
    ),
    # turns where communication breakdown occurs
    n_comm_breakdown = sum(
      as.integer(
        human_misunderstanding == 1 |
          robot_stt_problems == 1 |
          human_sentence_fragment == 1
      ),
      na.rm = TRUE
    ),

    # ---- rates per turn ----
    prop_help_requests = safe_div(n_help_requests, n_turns),
    prop_sentence_frag = safe_div(n_sentence_frag, n_turns),
    prop_human_reasoning = safe_div(n_human_reasoning, n_turns),
    prop_human_misunderstanding = safe_div(n_human_misunderstanding, n_turns),
    prop_human_affective_engagement = safe_div(
      n_human_affective_engagement,
      n_turns
    ),

    prop_robot_helpful_guidance = safe_div(n_robot_helpful_guidance, n_turns),
    prop_robot_unhelpful = safe_div(n_robot_unhelpful, n_turns),
    prop_robot_proactive_checkin = safe_div(n_robot_proactive_checkin, n_turns),
    prop_robot_encouragement = safe_div(n_robot_encouragement, n_turns),
    prop_robot_collaborative_lang = safe_div(
      n_robot_collaborative_lang,
      n_turns
    ),
    prop_robot_reasoning = safe_div(n_robot_reasoning, n_turns),
    prop_robot_clarification = safe_div(n_robot_clarification, n_turns),
    prop_robot_empathy_expression = safe_div(
      n_robot_empathy_expression,
      n_turns
    ),

    prop_comm_breakdown = safe_div(n_comm_breakdown, n_turns),

    .groups = "drop"
  )

# Merge stage summary back into final table
final_table2 <- final_table |>
  left_join(stage_summary, by = join_by("session_id", "stage")) |>
  mutate(across(where(is.numeric), ~ replace_na(., 0)))

write_csv(
  final_table2,
  'data/clean_data/dialogue_allstage_details.csv'
)

# Summarize per-participant across task 1 and 2 stages only
participant_task_summary <- final_table2 %>%
  filter(stage %in% c("task1", "task2")) %>%
  group_by(session_id) %>%
  summarise(
    n_turns = sum(n_turns, na.rm = TRUE),
    stage_skipped = sum(stage_skipped == 1 | n_turns < 8, na.rm = TRUE),
    # summed counts
    n_help_requests = sum(n_help_requests, na.rm = TRUE),
    n_sentence_frag = sum(n_sentence_frag, na.rm = TRUE),
    n_human_reasoning = sum(n_human_reasoning, na.rm = TRUE),
    n_human_misunderstanding = sum(n_human_misunderstanding, na.rm = TRUE),
    n_human_affective_engagement = sum(
      n_human_affective_engagement,
      na.rm = TRUE
    ),
    n_robot_helpful_guidance = sum(n_robot_helpful_guidance, na.rm = TRUE),
    n_robot_unhelpful = sum(n_robot_unhelpful, na.rm = TRUE),
    n_robot_proactive_checkin = sum(n_robot_proactive_checkin, na.rm = TRUE),
    n_robot_encouragement = sum(n_robot_encouragement, na.rm = TRUE),
    n_robot_collaborative_lang = sum(n_robot_collaborative_lang, na.rm = TRUE),
    n_robot_reasoning = sum(n_robot_reasoning, na.rm = TRUE),
    n_robot_clarification = sum(n_robot_clarification, na.rm = TRUE),
    n_robot_empathy_expression = sum(n_robot_empathy_expression, na.rm = TRUE),
    n_comm_breakdown = sum(n_comm_breakdown, na.rm = TRUE),

    # normalized rates
    prop_help_requests = safe_div(n_help_requests, n_turns),
    prop_sentence_frag = safe_div(n_sentence_frag, n_turns),
    prop_human_reasoning = safe_div(n_human_reasoning, n_turns),
    prop_human_misunderstanding = safe_div(n_human_misunderstanding, n_turns),
    prop_human_affective_engagement = safe_div(
      n_human_affective_engagement,
      n_turns
    ),

    prop_robot_helpful_guidance = safe_div(n_robot_helpful_guidance, n_turns),
    prop_robot_unhelpful = safe_div(n_robot_unhelpful, n_turns),
    prop_robot_proactive_checkin = safe_div(n_robot_proactive_checkin, n_turns),
    prop_robot_encouragement = safe_div(n_robot_encouragement, n_turns),
    prop_robot_collaborative_lang = safe_div(
      n_robot_collaborative_lang,
      n_turns
    ),
    prop_robot_reasoning = safe_div(n_robot_reasoning, n_turns),
    prop_robot_clarification = safe_div(n_robot_clarification, n_turns),
    prop_robot_empathy_expression = safe_div(
      n_robot_empathy_expression,
      n_turns
    ),

    prop_comm_breakdown = safe_div(n_comm_breakdown, n_turns),

    .groups = "drop"
  )

write_csv(
  participant_task_summary,
  'data/clean_data/dialogue_stage_details_tasks1and2.csv'
)

df_stage <- final_table2 %>%
  select(-task_time_remaining_sec) %>%
  mutate(
    is_task = stage %in% c("task1", "task2"),
    task_requires_robot_help = stage %in% c("task1"),

    help_style_ord = case_when(
      task_completed_collaboratively == 1 ~ "collaborative",
      task_completed_with_some_help == 1 ~ "some_help",
      task_completed_with_little_help == 1 ~ "little_help",
      task_completed_without_help == 1 ~ "no_help",
      TRUE ~ NA_character_
    ) %>%
      factor(
        levels = c("no_help", "little_help", "some_help", "collaborative"),
        ordered = TRUE
      ),

    task_assistance_score = case_when(
      help_style_ord == "no_help" ~ 0,
      help_style_ord == "little_help" ~ 1,
      help_style_ord == "some_help" ~ 2,
      help_style_ord == "collaborative" ~ 3,
      TRUE ~ 0
    ),

    likely_guessed = as.integer(
      is_task &
        task_requires_robot_help &
        # task_outcome %in% c("completed", "partial") &
        task_completed_without_help == 1
    ),

    task_disengaged = as.integer(task_outcome %in% c("skipped", "abandoned")),
    task_timed_out = as.integer(task_outcome == "timeout"),

    comm_breakdown_hard = as.integer(
      n_comm_breakdown > 0 | task_disengaged == 1 | stage_skipped > 0
    ),

    # ---- rates (per turn) ----
    p_comm_breakdown = safe_div(n_comm_breakdown, n_turns),
    p_sentence_frag = safe_div(n_sentence_frag, n_turns),

    p_robot_empathy = safe_div(n_robot_empathy_expression, n_turns),
    p_robot_checkin = safe_div(n_robot_proactive_checkin, n_turns),
    p_robot_encour = safe_div(n_robot_encouragement, n_turns),
    p_robot_collab = safe_div(n_robot_collaborative_lang, n_turns),
    p_human_affect = safe_div(n_human_affective_engagement, n_turns),

    p_robot_helpful = safe_div(n_robot_helpful_guidance, n_turns),
    p_robot_unhelpful = safe_div(n_robot_unhelpful, n_turns),

    # ---- comm burden + fixed viability ----
    comm_burden = n_comm_breakdown +
      n_sentence_frag +
      2 * task_disengaged +
      2 * stage_skipped,

    comm_viability = 1 - pmin(comm_burden, 9) / 9
  ) %>%

  select(
    session_id,
    stage,
    stage_skipped,
    likely_guessed,
    task_outcome,
    help_style,
    n_turns,
    contains('prop'),
    is_task,
    task_requires_robot_help,
    task_disengaged,
    help_style_ord,
    task_assistance_score,
    comm_viability,
    comm_burden,
    comm_breakdown_hard,
    #relational_quality_raw,
    contains('p_')
    # contains('index')
  ) %>%
  mutate(
    no_grounding = ifelse(
      stage_skipped == 1 & stage %in% c("greeting", "brief"),
      1,
      0
    )
  )

write_csv(
  df_stage,
  'data/clean_data/dialogue_stage_summary.csv'
)

df_session <- df_stage %>%
  group_by(session_id) %>%
  summarise(
    # ---- exposure ----
    n_task_turns = sum(n_turns[is_task], na.rm = TRUE),
    n_stage_skipped = sum(stage_skipped, na.rm = TRUE),
    #n_tasks_attempted = sum(is_task & stage_skipped == 0, na.rm = TRUE),

    mean_comm_burden = mean(comm_burden[is_task], na.rm = TRUE),
    max_comm_burden = max(comm_burden[is_task], na.rm = TRUE),
    # ---- communication rates (task stages only) ----
    mean_comm_breakdown = mean(p_comm_breakdown[is_task], na.rm = TRUE),
    max_comm_breakdown = max(p_comm_breakdown[is_task], na.rm = TRUE),

    mean_sentence_frag = mean(p_sentence_frag[is_task], na.rm = TRUE),
    max_sentence_frag = mean(p_sentence_frag[is_task], na.rm = TRUE),

    mean_comm_viability = mean(comm_viability[is_task], na.rm = TRUE),
    min_comm_viability = min(comm_viability[is_task], na.rm = TRUE),

    # ---- disengagement ----
    any_task_disengaged = as.integer(any(task_disengaged[is_task] == 1)),
    n_tasks_disengaged = sum(task_disengaged[is_task], na.rm = TRUE),

    # ---- design violations ----
    n_likely_guessed = sum(likely_guessed[is_task], na.rm = TRUE),
    any_likely_guessed = as.integer(any(likely_guessed[is_task] == 1)),

    .groups = "drop"
  )

test <- participant_task_summary |>
  left_join(df_session, by = join_by("session_id"))

write_csv(
  df_session,
  'data/analysis_output/dialogue_session_summary.csv'
)

final_df <- participant_task_summary |>
  left_join(df_session, by = join_by("session_id"))

write_csv(
  final_df,
  'data/analysis_output/final_dialogue_summary.csv'
)
