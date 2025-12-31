# Purpose: Build markdown coding sheets for manual coding of dialogue turns with task outcomes

library(tidyverse)
library(glue)
library(stringr)
library(fs)

# ---- config ----
csv_path <- "data/clean_data/dialogue_turns_with_task_outcomes.csv"
out_dir <- "data/clean_data/coded_turns"
dir_create(out_dir)

# Optional: order stages (edit to match your labels)
stage_order <- c("greeting", "brief", "task_1", "task_2", "wrapup")

# ---- helper: escape markdown chars lightly ----
md_escape <- function(x) {
  x %>%
    replace_na("") %>%
    str_replace_all("\\|", "\\\\|") %>% # don't break tables if you paste later
    str_replace_all("\r", "") # windows newlines
}

# ---- helper: checkbox block templates ----
human_checks <- c(
  "human_help_request",
  "human_sentence_fragment",
  "human_reasoning_aloud",
  "human_non_response",
  "human_misunderstanding",
  "human_off_topic",
  "human_frustration_expression",
  "human_confusion",
  "human_confirmation_seeking",
  "human_affective_engagement",
  "human_social_reciprocity",
  "human_anthropomorphic_language",
  "human_emotional_disengagement"
)

robot_checks <- c(
  "robot_helpful_guidance",
  "robot_proactive_checkin",
  "robot_encouragement",
  "robot_collaborative_language",
  "robot_reasoning_aloud",
  "robot_misleading_guidance",
  "robot_factually_incorrect",
  "robot_policy_violation",
  "robot_on_policy_unhelpful",
  "robot_stt_problems",
  "robot_clarification_request",
  "robot_empathy_expression",
  "robot_emotion_acknowledgement",
  "robot_affect_misaligned"
)

checkbox_block <- function(vars) {
  paste0("- [ ] `", vars, "`\n", collapse = "")
}

# ---- NEW: turn meta / housekeeping codes ----
turn_type_options <- c(
  "normal",
  "system_init",
  "silence_checkin",
  "sentence_fragment",
  "other_meta"
)

turn_meta_block <- function() {
  paste0(
    "- [ ] `turn_include_in_analysis`\n",
    "- turn_type:\n",
    paste0("  - [ ] `", turn_type_options, "`\n", collapse = ""),
    "- [ ] `human_input_fragment`\n"
  )
}

# ---- read + prep ----
turns <- readr::read_csv(csv_path, show_col_types = FALSE) %>%
  mutate(
    session_id = as.character(session_id),
    stage = as.character(stage),
    turn_number = as.integer(turn_number),
    user_input = md_escape(user_input),
    llm_response = md_escape(llm_response),
    expression = md_escape(expression),
    flags = md_escape(flags),
    suspect = as.character(suspect_id),
    status = as.character(status),
    building = as.character(building),
    floor = as.character(floor),
    zone = as.character(zone),
  )

# If stage has a known order, apply it (optional)
if (all(stage_order %in% unique(turns$stage))) {
  turns <- turns %>% mutate(stage = factor(stage, levels = stage_order))
}

# ---- build one markdown file per session_id x stage ----
groups <- turns %>%
  arrange(session_id, stage, turn_number) %>%
  group_by(session_id, stage) %>%
  group_split()

for (g in groups) {
  sid <- g$session_id[[1]]
  stg <- as.character(g$stage[[1]])
  suspect <- as.character(g$suspect[[1]])
  status <- as.character(g$status[[1]])
  building <- as.character(g$building[[1]])
  floor <- as.character(g$floor[[1]])
  zone <- as.character(g$zone[[1]])

  # file name: safe + sortable
  stg_slug <- stg %>%
    tolower() %>%
    str_replace_all("[^a-z0-9]+", "_") %>%
    str_replace_all("^_|_$", "")

  file_path <- path(out_dir, glue("session_{sid}__{stg_slug}.md"))

  header <- glue(
    "# Coding Sheet\n\n",
    "**Session:** `{sid}`  \n",
    "**Stage:** `{stg}`  \n\n",
    "**Answers Submitted:**  \n",
    "**Task 1 (suspect):** `{suspect}`  \n",
    "**Task 2:**\n",
    "**Status:** `{status}`  \n",
    "**Building:** `{building}`  \n",
    "**Floor:** `{floor}`  \n",
    "**Zone:** `{zone}`  \n",
    "**Generated:** {format(Sys.time(), '%Y-%m-%d %H:%M')}  \n\n",
    "---\n\n",
    "## Task outcome (fill once per stage)\n\n",
    "- task_outcome:\n",
    "  - [ ] `completed`\n",
    "  - [ ] `timeout`\n",
    "  - [ ] `skipped`\n",
    "  - [ ] `partial`\n",
    "  - [ ] `abandoned`\n\n",
    "- `task_time_remaining_sec`: \n\n",
    # robot guidance informed at least 2 dropdowns
    "- [ ] `task_completed_with_some_help`\n",
    # robot guidance informaed 1 dropdown
    "- [ ] `task_completed_with_little_help`\n",
    # no evidence of robot informing decisions
    "- [ ] `task_completed_without_help`\n",
    # robot guidance informed at least 3 dropdowns
    # considerable, shared problem-solving
    "- [ ] `task_completed_collaboratively`\n",
    "---\n\n",
    "## Turn-by-turn coding\n\n"
  )

  # Build turn blocks
  blocks <- map_chr(seq_len(nrow(g)), function(i) {
    tn <- g$turn_number[[i]]

    ui <- g$user_input[[i]]
    rr <- g$llm_response[[i]]
    ex <- g$expression[[i]]
    fl <- g$flags[[i]]

    # Optional: word count (helps spot fragments quickly)
    ui_wc <- ifelse(nchar(ui) == 0, 0L, str_count(ui, "\\S+"))

    glue(
      "### Turn {tn}\n\n",
      "**Turn meta**\n\n",
      "{turn_meta_block()}\n",
      "\n",
      "**Human:**\n\n",
      "> {ifelse(nchar(ui) == 0, '(no input)', ui)}\n\n",
      "(word_count: {ui_wc})\n\n",
      "**Human codes**\n\n",
      "{checkbox_block(human_checks)}\n",
      "**Misty:**\n\n",
      "> {ifelse(nchar(rr) == 0, '(no response)', rr)}\n\n",
      "- expression: `{ifelse(nchar(ex) == 0, 'NA', ex)}`\n",
      "- flags: `{ifelse(nchar(fl) == 0, 'NA', fl)}`\n\n",
      "**Robot codes**\n\n",
      "{checkbox_block(robot_checks)}\n",
      "- coder_notes: \n\n",
      "---\n\n"
    )
  })

  writeLines(c(header, blocks), file_path)
}

cat("Done. Wrote coding sheets to:", out_dir, "\n")
