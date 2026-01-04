# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a research project analyzing trust in human-robot interaction through a pilot study with the Misty-II social robot. The repository contains a Quarto-based research paper with integrated R analysis code, DuckDB databases of experimental data, and processed results from manual dialogue coding.

The project examines how robot interaction policy (responsive vs. neutral) influences trust during fully autonomous spoken-language collaboration tasks.

## Document Build System

**Primary document**: `misty-paper.qmd` - A Quarto manuscript combining narrative text, embedded R code chunks, and academic citations.

**Build commands**:
- `quarto render misty-paper.qmd` - Renders to all formats (HTML + IEEE PDF)
- `quarto render misty-paper.qmd --to html` - HTML preview only
- `quarto render misty-paper.qmd --to ieee-typst` - IEEE format PDF only
- `quarto preview misty-paper.qmd` - Live preview with auto-reload

**Output formats**:
- HTML with interactive tables (uses bootstrap theme)
- IEEE-formatted PDF via Typst (template in `_extensions/quarto-ext/ieee/`)

**Important**: The `.qmd` file contains extensive R code chunks. Many chunks have `eval: false` in headers, indicating they were run once to generate saved results (`.rds` files) and should not re-execute on every render.

## Data Processing Pipeline

The analysis follows a multi-stage pipeline. **Execute scripts in numerical order**:

1. **`R_scripts/02-db-wrangle.R`** - Extracts and merges data from DuckDB
   - Reads from `data/experiment_data.duckdb`
   - Joins sessions, dialogue turns, events, and task responses
   - Outputs: `full_session_data.rds`, `data/clean_data/dialogue_turns_with_task_outcomes.csv`

2. **`R_scripts/03-score-scales.R`** - Processes survey data and scales
   - Reads Qualtrics survey exports (SPSS `.sav` format)
   - Scores NARS, NFC, and trust scales
   - Outputs: `survey_data.rds`, trust scale datasets

3. **`R_scripts/04-dialogue-analysis.R`** - Aggregates manually coded dialogue data
   - Reads markdown files from `data/clean_data/coded_turns/`
   - Computes turn-level and session-level interaction metrics
   - Outputs: `data/analysis_output/final_dialogue_summary.csv`

4. **`R_scripts/05-hierarchical-analysis.R`** - Runs mixed-effects and Bayesian models
   - Fits lme4 and brms models
   - Generates model comparison tables

5. **Render `misty-paper.qmd`** - Integrates all processed data into final manuscript

## Key Data Files

**Primary databases**:
- `experiment_data.duckdb` - Robot interaction logs (470 MB)
- `data/clean_data/coded_turns/*.md` - Manually coded dialogue transcripts with checkboxes for interaction codes

**Analysis outputs** (loaded directly in `.qmd`):
- `full_session_data.rds` - Per-session objective measures
- `survey_data.rds` - Pre/post questionnaire responses
- `full_dataset_with_items.rds` - Item-level trust data (wide format)
- `full_dataset_long_trust_post.csv` - Item-level trust data (long format)
- `data/analysis_output/final_dialogue_summary.csv` - Aggregated dialogue coding metrics

## R Environment

**Required packages**:
```r
# Data manipulation
tidyverse, dplyr, janitor, readr

# Database
duckdb

# Survey data
haven (for SPSS .sav files)

# Mixed models
lme4, lmerTest, performance

# Bayesian models
brms

# Tables and visualization
gtsummary, gt, sjPlot, ggstatsplot, corrplot

# Quarto integration
quarto (implicit via RStudio/command line)
```

**Session setup**: The `.qmd` loads all packages in its first R chunk. If running scripts standalone, install missing packages via `install.packages()`.

## Manual Dialogue Coding Structure

Dialogue transcripts are stored as markdown files in `data/clean_data/coded_turns/` following this naming pattern:
- `session_<ParticipantID>__<stage>.md`
- Example: `session_P12__task1.md`

Each file contains:
- Header metadata: session ID, stage
- Task outcome checkboxes: `completed`, `timeout`, `skipped`, etc.
- Per-turn coding blocks with checkbox variables for interaction codes

The R script `04-dialogue-analysis.R` parses these files to extract:
- Turn-level codes (help requests, communication breakdown, robot guidance quality)
- Stage-level task outcomes
- Session-level aggregates (proportions of responsive behaviors, viability metrics)

## Experimental Design Context

**Conditions**: Between-subjects design with two robot interaction policies:
- **RESPONSIVE** (experimental): Proactive, affect-adaptive dialogue
- **CONTROL**: Reactive, neutral dialogue

**Session structure**: 5 stages per participant
1. `greeting` - Rapport building
2. `brief` - Mission context
3. `task1` - Robot-dependent collaborative reasoning (who-dunnit puzzle)
4. `task2` - Optional robot assistance (log analysis)
5. `wrap` - Closing

**Data exclusion**: Sessions with >60% communication breakdown (n=5) are marked but retained in sensitivity analyses. The variable `exclusions` in datasets flags these as `'exclude'`.

## Analysis Approach

**Primary analyses**: Use `filter(exclusions != 'exclude')` for main results (viable sessions only).

**Sensitivity analyses**: Run on full sample (all 29 participants) to assess robustness.

**Modeling strategy**:
- Linear mixed-effects models via `lme4::lmer()` with random intercepts for session and trust items
- Bayesian hierarchical models via `brms::brm()` for posterior inference
- Fixed effects: group (interaction policy), baseline NARS, native English fluency
- Trust outcomes: TPS-HRI (perceived trust) and TI-HRC (experienced trust)

## Common Workflows

**To regenerate all analysis outputs**:
```bash
cd /home/sheron/Documents/misty-paper
Rscript R_scripts/02-db-wrangle.R
Rscript R_scripts/03-score-scales.R
Rscript R_scripts/04-dialogue-analysis.R
Rscript R_scripts/05-hierarchical-analysis.R
quarto render misty-paper.qmd
```

**To preview the paper during editing**:
```bash
quarto preview misty-paper.qmd
```

**To update dialogue coding**:
1. Edit markdown files in `data/clean_data/coded_turns/`
2. Run `Rscript R_scripts/04-dialogue-analysis.R`
3. Re-render `.qmd` to update tables/figures

## Git Workflow

Current branch: `final-submission-branch`

The repository does not have a configured main branch. When creating pull requests or merging, confirm target branch with the user.

## File Locations

**Source code**: `R_scripts/` - Numbered analysis scripts
**Raw data**: `data/experiment_data.duckdb`, `data/archive-first-round-data/`
**Processed data**: `.rds` files in root, `.csv` in `data/analysis_output/`
**Dialogue coding**: `data/clean_data/coded_turns/*.md`
**Images**: `images/` - Screenshots and task interface images
**References**: `bibliography.bib` - BibTeX citations
**Archived versions**: `archive/` - Previous `.qmd` iterations

## Important Notes

- **Do not modify** `.rds` or `.csv` files directly - regenerate via R scripts
- **Do not run** R chunks with `eval: false` in the `.qmd` unless instructed - these are computationally expensive or depend on saved model objects
- **DuckDB connection**: Scripts open a connection to `data/experiment_data.duckdb`. Ensure `dbDisconnect(con)` is called if interrupted
- **Bayesian models**: `brms` models in the `.qmd` are marked `eval: false` because they take ~10-30 minutes to fit. Results are summarized in text from manual runs.
- **Image paths**: Figures in the `.qmd` use relative paths like `images/misty-pullback.jpg` - maintain this structure

## Citation Style

Uses IEEE format with URLs enabled via `ieee-with-url.csl`. Citations are in `bibliography.bib` and inserted using `[@citationkey]` syntax in the `.qmd`.
