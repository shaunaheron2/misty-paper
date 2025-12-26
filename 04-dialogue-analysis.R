library(tidyverse)
library(janitor)
library(readr)
library(jsonlite)
library(stringr)
library(fs)

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

all_sessions <- sort(unique(turns$session_id))

expected_stages <- c("greeting", "brief", "task1", "task2", "wrap")


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

final_table <- stage_presence |>
  left_join(task_outcomes_df, by = join_by("session_id", "stage")) |>
  mutate(task_outcome = ifelse(is.na(task_outcome), "skipped", task_outcome)) |>
  mutate(across(where(is.numeric), ~ replace_na(., 0)))


stage_summary <- turn_level_df %>%
  group_by(session_id, stage) %>%
  summarise(
    n_help_requests = sum(human_help_request),
    n_sentence_frag = sum(
      human_sentence_fragment == 1 | human_input_fragment == 1
    ),
    n_human_confirmation_seeking = sum(human_confirmation_seeking),
    n_human_reasoning = sum(human_reasoning_aloud),
    n_human_misunderstanding = sum(human_misunderstanding),
    n_human_social_reciprocity = sum(human_social_reciprocity),
    n_human_affective_engagement = sum(human_affective_engagement),
    n_human_anthro = sum(human_anthropomorphic_language),
    n_robot_helpful_guidance = sum(robot_helpful_guidance),
    n_robot_misleading_guidance = sum(
      robot_misleading_guidance == 1 | robot_factually_incorrect == 1
    ),
    n_robot_policy_violation = sum(robot_policy_violation),
    n_robot_unhelpful = sum(robot_on_policy_unhelpful),
    n_robot_proactive_checkin = sum(robot_proactive_checkin),
    n_robot_encouragement = sum(robot_encouragement),
    n_robot_collaborative_lang = sum(robot_collaborative_language),
    n_robot_reasoning = sum(robot_reasoning_aloud),
    n_robot_clarification = sum(robot_clarification_request),
    n_robot_comm_failures = sum(robot_stt_problems),
    n_robot_empathy_expression = sum(robot_empathy_expression),
    n_robot_emotion = sum(robot_emotion_acknowledgement),
    n_comm_breakdown = sum(
      human_misunderstanding == 1 | robot_stt_problems == 1
    ),
    .groups = "drop"
  )


final_table2 <- final_table |>
  left_join(stage_summary, by = join_by("session_id", "stage")) |>
  mutate(across(where(is.numeric), ~ replace_na(., 0)))


df_stage <- final_table2 %>%
  mutate(
    # ---- Define which stages are true tasks and which require robot help ----
    is_task = stage %in% c("task1", "task2"),

    # EDIT THIS RULE to match your design:
    # - If Task 1 *requires* robot help to be solvable, set TRUE for task_1
    # - If Task 2 can be solved solo, set FALSE for task_2 (or TRUE if you believe help is required)
    task_requires_robot_help = stage %in% c("task1"),

    # ---- Help style (single representation) ----
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
      is.na(help_style_ord) ~ 0,
      TRUE ~ NA_real_
    ),

    # ---- Task validity / guessing flag ----
    likely_guessed = as.integer(
      is_task == TRUE &
        task_requires_robot_help == TRUE &
        task_outcome == "completed" &
        task_completed_without_help == 1
    ),

    # ---- Communication flags (timeout is NOT comm failure) ----
    task_disengaged = as.integer(task_outcome %in% c("skipped", "abandoned")),
    task_timed_out = as.integer(task_outcome == "timeout"),

    comm_breakdown_hard = as.integer(
      n_comm_breakdown > 0 |
        n_robot_comm_failures > 0 |
        n_sentence_frag > 0 |
        task_disengaged == 1 |
        stage_skipped == 1
    ),

    # graded comm burden (NO timeout, NO "guessed" penalty)
    comm_burden = n_comm_breakdown +
      n_robot_comm_failures +
      n_sentence_frag +
      2 * task_disengaged +
      2 * stage_skipped,

    comm_viability = 1 - scales::rescale(comm_burden, to = c(0, 1)),

    # ---- Task support indices ----
    task_support = n_robot_helpful_guidance +
      n_robot_reasoning -
      n_robot_misleading_guidance -
      n_robot_comm_failures,

    task_support_index = task_assistance_score +
      n_robot_helpful_guidance -
      n_robot_misleading_guidance -
      n_robot_comm_failures,

    # ---- Relational quality (social only) ----
    relational_quality = n_robot_empathy_expression +
      n_robot_encouragement +
      n_robot_collaborative_lang +
      n_human_affective_engagement +
      n_human_social_reciprocity +
      n_human_anthro,

    # ---- Overall interaction quality (optional): penalize guessing ----
    interaction_quality_overall = task_support_index +
      relational_quality -
      2 * likely_guessed
  )

safe_min <- function(x) {
  x <- x[!is.na(x)]
  if (length(x) == 0) NA_real_ else min(x)
}

safe_mean <- function(x) {
  x <- x[!is.na(x)]
  if (length(x) == 0) NA_real_ else mean(x)
}

stage_context <- df_stage %>%
  filter(stage %in% c("greeting", "brief")) %>%
  group_by(session_id) %>%
  summarise(
    greeting_skipped = as.integer(any(
      stage == "greeting" & stage_skipped == 1
    )),
    brief_skipped = as.integer(any(stage == "brief" & stage_skipped == 1)),
    .groups = "drop"
  )


df_session <- df_stage %>%
  group_by(session_id) %>%
  summarise(
    n_tasks_attempted = sum(is_task & stage_skipped == 0, na.rm = TRUE),

    n_completed = sum(is_task & task_outcome == "completed", na.rm = TRUE),
    n_timeouts = sum(is_task & task_timed_out == 1, na.rm = TRUE),
    n_disengaged = sum(is_task & task_disengaged == 1, na.rm = TRUE),

    n_likely_guessed = sum(likely_guessed, na.rm = TRUE),
    any_likely_guessed = as.integer(any(likely_guessed == 1)),

    mean_task_assistance = safe_mean(task_assistance_score[is_task]),

    relational_quality_total = sum(relational_quality[is_task], na.rm = TRUE),
    task_support_index_total = sum(task_support_index[is_task], na.rm = TRUE),

    any_comm_breakdown = as.integer(any(comm_breakdown_hard[is_task] == 1)),

    comm_viability_mean = safe_mean(comm_viability[is_task]),
    comm_viability_worst = safe_min(comm_viability[is_task]),

    .groups = "drop"
  )

df_session2 <- df_session %>%
  left_join(stage_context, by = "session_id") %>%
  mutate(
    greeting_skipped = coalesce(greeting_skipped, 0L),
    brief_skipped = coalesce(brief_skipped, 0L),

    brief_greeting_skipped = as.integer(
      greeting_skipped == 1 & brief_skipped == 1
    ),

    # Core failure signals (any one suggests interaction non-viability)
    core_failure_signal = as.integer(
      comm_viability_mean < 0.6 |
        n_disengaged > 0 |
        n_likely_guessed > 0 |
        brief_greeting_skipped == 1
    ),

    # Supporting signals (contextual evidence)
    supporting_failure_signal = as.integer(
      task_support_index_total < 20 |
        relational_quality_total < 2
    ),

    # Final drop rule: core failure + at least one supporting signal
    drop_due_to_comm_failure = as.integer(
      core_failure_signal == 1 &
        supporting_failure_signal == 1
    )
  )

#Participants were excluded from task-level analyses when interaction was judged to be non-viable due to communication breakdown. This was operationalized using a rule-based combination of indicators capturing (a) reduced communicative viability (e.g., frequent speech recognition failures or fragmented input), (b) task disengagement or task completion inconsistent with the intended collaborative design, and (c) absence of interactional grounding (e.g., skipping initial greeting and briefing stages).
#This rule was validated against manual review of session transcripts and reliably identified the same cases judged to reflect total communication breakdown.

write_csv(
  df_session2,
  'data/analysis_output/dialogue_stage_summary_20251212_153544.csv'
)
