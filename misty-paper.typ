// Some definitions presupposed by pandoc's typst output.
#let blockquote(body) = [
  #set text( size: 0.92em )
  #block(inset: (left: 1.5em, top: 0.2em, bottom: 0.2em))[#body]
]

#let horizontalrule = line(start: (25%,0%), end: (75%,0%))

#let endnote(num, contents) = [
  #stack(dir: ltr, spacing: 3pt, super[#num], contents)
]

#show terms: it => {
  it.children
    .map(child => [
      #strong[#child.term]
      #block(inset: (left: 1.5em, top: -0.4em))[#child.description]
      ])
    .join()
}

// Some quarto-specific definitions.

#show raw.where(block: true): set block(
    fill: luma(230),
    width: 100%,
    inset: 8pt,
    radius: 2pt
  )

#let block_with_new_content(old_block, new_content) = {
  let d = (:)
  let fields = old_block.fields()
  fields.remove("body")
  if fields.at("below", default: none) != none {
    // TODO: this is a hack because below is a "synthesized element"
    // according to the experts in the typst discord...
    fields.below = fields.below.abs
  }
  return block.with(..fields)(new_content)
}

#let empty(v) = {
  if type(v) == str {
    // two dollar signs here because we're technically inside
    // a Pandoc template :grimace:
    v.matches(regex("^\\s*$")).at(0, default: none) != none
  } else if type(v) == content {
    if v.at("text", default: none) != none {
      return empty(v.text)
    }
    for child in v.at("children", default: ()) {
      if not empty(child) {
        return false
      }
    }
    return true
  }

}

// Subfloats
// This is a technique that we adapted from https://github.com/tingerrr/subpar/
#let quartosubfloatcounter = counter("quartosubfloatcounter")

#let quarto_super(
  kind: str,
  caption: none,
  label: none,
  supplement: str,
  position: none,
  subrefnumbering: "1a",
  subcapnumbering: "(a)",
  body,
) = {
  context {
    let figcounter = counter(figure.where(kind: kind))
    let n-super = figcounter.get().first() + 1
    set figure.caption(position: position)
    [#figure(
      kind: kind,
      supplement: supplement,
      caption: caption,
      {
        show figure.where(kind: kind): set figure(numbering: _ => numbering(subrefnumbering, n-super, quartosubfloatcounter.get().first() + 1))
        show figure.where(kind: kind): set figure.caption(position: position)

        show figure: it => {
          let num = numbering(subcapnumbering, n-super, quartosubfloatcounter.get().first() + 1)
          show figure.caption: it => {
            num.slice(2) // I don't understand why the numbering contains output that it really shouldn't, but this fixes it shrug?
            [ ]
            it.body
          }

          quartosubfloatcounter.step()
          it
          counter(figure.where(kind: it.kind)).update(n => n - 1)
        }

        quartosubfloatcounter.update(0)
        body
      }
    )#label]
  }
}

// callout rendering
// this is a figure show rule because callouts are crossreferenceable
#show figure: it => {
  if type(it.kind) != str {
    return it
  }
  let kind_match = it.kind.matches(regex("^quarto-callout-(.*)")).at(0, default: none)
  if kind_match == none {
    return it
  }
  let kind = kind_match.captures.at(0, default: "other")
  kind = upper(kind.first()) + kind.slice(1)
  // now we pull apart the callout and reassemble it with the crossref name and counter

  // when we cleanup pandoc's emitted code to avoid spaces this will have to change
  let old_callout = it.body.children.at(1).body.children.at(1)
  let old_title_block = old_callout.body.children.at(0)
  let old_title = old_title_block.body.body.children.at(2)

  // TODO use custom separator if available
  let new_title = if empty(old_title) {
    [#kind #it.counter.display()]
  } else {
    [#kind #it.counter.display(): #old_title]
  }

  let new_title_block = block_with_new_content(
    old_title_block, 
    block_with_new_content(
      old_title_block.body, 
      old_title_block.body.body.children.at(0) +
      old_title_block.body.body.children.at(1) +
      new_title))

  block_with_new_content(old_callout,
    block(below: 0pt, new_title_block) +
    old_callout.body.children.at(1))
}

// 2023-10-09: #fa-icon("fa-info") is not working, so we'll eval "#fa-info()" instead
#let callout(body: [], title: "Callout", background_color: rgb("#dddddd"), icon: none, icon_color: black, body_background_color: white) = {
  block(
    breakable: false, 
    fill: background_color, 
    stroke: (paint: icon_color, thickness: 0.5pt, cap: "round"), 
    width: 100%, 
    radius: 2pt,
    block(
      inset: 1pt,
      width: 100%, 
      below: 0pt, 
      block(
        fill: background_color, 
        width: 100%, 
        inset: 8pt)[#text(icon_color, weight: 900)[#icon] #title]) +
      if(body != []){
        block(
          inset: 1pt, 
          width: 100%, 
          block(fill: body_background_color, width: 100%, inset: 8pt, body))
      }
    )
}



#let article(
  title: none,
  subtitle: none,
  authors: none,
  date: none,
  abstract: none,
  abstract-title: none,
  cols: 1,
  lang: "en",
  region: "US",
  font: "libertinus serif",
  fontsize: 11pt,
  title-size: 1.5em,
  subtitle-size: 1.25em,
  heading-family: "libertinus serif",
  heading-weight: "bold",
  heading-style: "normal",
  heading-color: black,
  heading-line-height: 0.65em,
  sectionnumbering: none,
  toc: false,
  toc_title: none,
  toc_depth: none,
  toc_indent: 1.5em,
  doc,
) = {
  set par(justify: true)
  set text(lang: lang,
           region: region,
           font: font,
           size: fontsize)
  set heading(numbering: sectionnumbering)
  if title != none {
    align(center)[#block(inset: 2em)[
      #set par(leading: heading-line-height)
      #if (heading-family != none or heading-weight != "bold" or heading-style != "normal"
           or heading-color != black) {
        set text(font: heading-family, weight: heading-weight, style: heading-style, fill: heading-color)
        text(size: title-size)[#title]
        if subtitle != none {
          parbreak()
          text(size: subtitle-size)[#subtitle]
        }
      } else {
        text(weight: "bold", size: title-size)[#title]
        if subtitle != none {
          parbreak()
          text(weight: "bold", size: subtitle-size)[#subtitle]
        }
      }
    ]]
  }

  if authors != none {
    let count = authors.len()
    let ncols = calc.min(count, 3)
    grid(
      columns: (1fr,) * ncols,
      row-gutter: 1.5em,
      ..authors.map(author =>
          align(center)[
            #author.name \
            #author.affiliation \
            #author.email
          ]
      )
    )
  }

  if date != none {
    align(center)[#block(inset: 1em)[
      #date
    ]]
  }

  if abstract != none {
    block(inset: 2em)[
    #text(weight: "semibold")[#abstract-title] #h(1em) #abstract
    ]
  }

  if toc {
    let title = if toc_title == none {
      auto
    } else {
      toc_title
    }
    block(above: 0em, below: 2em)[
    #outline(
      title: toc_title,
      depth: toc_depth,
      indent: toc_indent
    );
    ]
  }

  if cols == 1 {
    doc
  } else {
    columns(cols, doc)
  }
}

#set table(
  inset: 6pt,
  stroke: none
)
#import "@preview/fontawesome:0.5.0": *

#set page(
  paper: "us-letter",
  margin: (x: 1.25in, y: 1.25in),
  numbering: "1",
)

#show: doc => article(
  title: [Responsive Robotics to Increase Trust in Autonomous Human--Robot Interaction],
  subtitle: [An In-Person Pilot Study],
  authors: (
    ( name: [M.C. Lau],
      affiliation: [Laurentian University],
      email: [mclau\@laurentian.ca] ),
    ( name: [Shauna Heron],
      affiliation: [Laurentian University],
      email: [sheron\@laurentian.ca] ),
    ),
  date: [2026-01-02],
  abstract: [This study implements a multi-stage collaborative task system where participants collaborate with the Misty-II social robot to solve a who-dunnit type task. The system utilizes an autonomous, mixed-initiative dialogue architecture with affect-responsive capabilities.

],
  abstract-title: "Abstract",
  toc_title: [Table of contents],
  toc_depth: 3,
  cols: 1,
  doc,
)

== Introduction
<introduction>
As automation expands across safety-critical domains such as manufacturing, healthcare, and mining, robotic systems are increasingly expected to operate alongside humans rather than in isolation @fu2021@racette2024. In these collaborative settings, successful deployment depends not only on technical performance but on whether human users are willing to rely on, communicate with, and coordinate their actions around autonomous systems @campagna2025@emaminejad2022. Trust has therefore emerged as a central determinant of adoption and effective use in human--robot collaboration (HRC). Insufficient trust can lead to disuse or rejection of automation, whereas excessive trust risks overreliance and automation bias, particularly in environments characterized by uncertainty or incomplete information @devisser2020.

A substantial body of human--robot interaction (HRI) research has examined how robot behaviour shapes user trust, perceived reliability, and cooperation @shayganfar2019@fartook2025. Prior work has demonstrated that trust influences both subjective evaluations of robotic partners and objective outcomes such as compliance, task performance, and collaborative efficiency. However, much of this literature relies on interactions conducted under highly controlled conditions, including scripted behaviours, simulated environments, or Wizard-of-Oz paradigms in which a human operator covertly manages aspects of the robot's behaviour. While these approaches are valuable for isolating specific design factors, they often obscure the interaction breakdowns and system imperfections that characterize real-world autonomous robots.

In deployed systems, limitations such as speech recognition errors, delayed responses, misinterpretations of user intent, and incomplete affect sensing are not peripheral issues but defining features of interaction. These failures are likely to play a decisive role in shaping trust and collaboration, yet remain underrepresented in empirical HRI research. Understanding how trust emerges---and sometimes deteriorates---under realistic autonomous conditions is therefore critical for the design of robots intended for real-world collaborative use.

One proposed mechanism for supporting trust in HRI is #strong[responsiveness];: the extent to which a robot adapts its behaviour based on user state and interaction context @shayganfar2019@fartook2025. Responsive robots may adjust their dialogue, timing, or support strategies in response to inferred affective cues such as confusion, frustration, or disengagement. Prior studies suggest that such adaptive behaviour can enhance perceived social intelligence and trustworthiness, particularly in dialogue-driven tasks @birnbaum2016. However, most evidence for these effects comes from simulated or semi-autonomous systems, leaving open questions about how responsiveness operates when implemented in fully autonomous, in-person interactions.

From an engineering perspective, responsiveness represents an interaction policy rather than a superficial social cue. Proactive, state-contingent assistance differs fundamentally from reactive, request-based behaviour, particularly when implemented under strict autonomy constraints. Designing and evaluating such policies requires systems capable of managing spoken-language dialogue, maintaining interaction state, and coordinating verbal and nonverbal responses in real time---while remaining robust to noise, latency, and sensing errors.

The present work addresses these gaps through a pilot study examining trust and collaboration during in-person interaction with a fully autonomous social robot. Participants collaborated with one of two versions of the same robot platform during a dialogue-driven puzzle task requiring shared problem solving. In both conditions, all interaction management---including speech recognition, dialogue state tracking, task progression, and response generation---was handled autonomously by the robot without human intervention. In the #strong[responsive] condition, the robot employed a proactive interaction policy, adapting its assistance based on conversational cues and inferred user affect. In the #strong[neutral] condition, the robot followed a reactive policy, providing assistance only when explicitly requested.

This study was conducted as a pilot with three primary objectives: (1) to evaluate the feasibility of deploying an autonomous spoken-language interaction system with affect-responsive behaviour on a mobile robot platform; (2) to assess whether differences in interaction policy influence trust, perceived social intelligence, and collaborative experience under realistic autonomous conditions; and (3) to examine how individual differences in baseline attitudes toward robots and cognitive engagement may moderate responses to adaptive robotic behaviour. Rather than optimizing for flawless interaction, the system was intentionally designed to reflect the capabilities and limitations of contemporary social robots, allowing interaction breakdowns to surface naturally.

An additional objective of this pilot study was to inform the design of an autonomous affect-adaptive interaction system under real-time constraints. The initial system concept included multimodal affect inference based on facial expressions, vocal prosody, and interaction dynamics. However, early integration testing revealed substantial challenges related to latency, model orchestration, and timing sensitivity when deploying multiple perception models concurrently on an edge-supported mobile robot platform. Given the small-scale nature of the pilot and the central importance of maintaining stable, real-time dialogue, the deployed system prioritized robustness of spoken-language interaction and dialogue-based affect inference over broader multimodal sensing. Affect adaptation in this study was therefore driven primarily by speech-based affect signals and conversational context, allowing us to evaluate responsiveness within a fully autonomous interaction while preserving realistic system constraints.

By combining post-interaction trust measures with task-level and behavioural observations, this pilot study aims to contribute empirical evidence on how trust in human--robot collaboration emerges in fully autonomous settings. The findings are intended to inform the design of a larger, subsequent study by identifying technical, interactional, and methodological challenges---including speech recognition limitations, language barriers, and interaction design trade-offs---that must be addressed when evaluating affect-responsive robots in real-world contexts.

The remainder of this paper is structured as follows. Section 2 reviews related work on spoken-language interaction, trust, and responsiveness in HRI. Section 3 describes the autonomous system architecture, experimental design, and measurement approach. Section 4 presents results from the pilot study, followed by a discussion of implications, limitations, and directions for future work.

= Methods
<methods>
== Experimental Design and Conditions
<experimental-design-and-conditions>
This study employed a between-subjects experimental design to examine how robot interaction policy influences trust and collaboration during fully autonomous, in-person human--robot interaction. The sole experimental factor was the robot's interaction policy, with participants randomly assigned to interact with either a #strong[responsive] or #strong[neutral] version of the same robot system.

Participants interacted with a Misty-II social robot in a shared physical workspace that included a participant-facing computer interface @mistya. The interface was used to display task materials, collect participant inputs, and manage task progression. Importantly, the interface did not function as a control mechanism for the robot. Instead, the robot autonomously monitored task state and participant inputs via the interface and managed dialogue and behaviour accordingly, without real-time human intervention.

Random assignment to condition was performed at sign-up using Qualtrics. Due to no-shows, last-minute cancellations, and technical exclusions (described below), final group sizes were #emph[n] = 14 in the RESPONSIVE condition and #emph[n] = 9 in the CONTROL condition.

=== Interaction Policies
<interaction-policies>
- #strong[RESPONSIVE condition (experimental):] \
  The robot employed a proactive, affect-adaptive interaction policy. Robot responses were modulated based on inferred participant affect, dialogue context, and task demands, resulting in unsolicited encouragement, clarification, and engagement-oriented behaviours when appropriate.

- #strong[CONTROL condition (baseline):] \
  The robot employed a neutral, reactive interaction policy. Assistance and information were provided only when explicitly requested by the participant, without affect-based adaptation or proactive support.

Both conditions used identical hardware, software infrastructure, sensing capabilities, and task logic. The only difference between conditions was the robot's interaction policy.

=== Collaborative Task Design
<collaborative-task-design>
Participants completed an immersive, narrative-driven puzzle game consisting of five sequential stages and two timed reasoning tasks. The game context positioned participants as investigators searching for a missing robot colleague, with the robot serving as a diegetic guide and collaborative partner. The overall interaction lasted approximately 15 minutes.

#figure([
#box(image("images/misty-pullback.jpg", width: 5.02083in))
], caption: figure.caption(
position: bottom, 
[
Experimental setup showing the autonomous robot and participant-facing task interface used during in-person sessions. Participants entered task responses and navigated between task stages using the interface, while the robot autonomously tracked task state and adapted its interaction based on participant input. No real-time human intervention occurred during the interaction.
]), 
kind: "quarto-float-fig", 
supplement: "Figure", 
)
<fig-setup>


The task structure was designed to elicit collaboration under two distinct dependency conditions: (1) enforced collaboration, where the robot was required to complete the task, and (2) optional collaboration, where participants could choose whether to engage the robot.

==== Stage Overview
<stage-overview>
+ #strong[Greeting:] The robot introduced itself and engaged in brief rapport-building dialogue. \
+ #strong[Mission Brief:] The robot explained the narrative context and overall objectives. \
+ #strong[Task 1:] Robot-dependent collaborative reasoning task. \
+ #strong[Task 2:] Open-ended problem solving with optional robot support. \
+ #strong[Wrap-up:] The robot provided closing feedback and concluded the interaction.

Participants advanced between stages using the interface, either at the robot's prompting or at their own discretion. All spoken dialogue and interaction events were logged automatically.

==== Task 1: Robot-Dependent Collaborative Reasoning
<task-1-robot-dependent-collaborative-reasoning>
In Task 1, participants were required to identify a suspect from a 6 × 4 grid of 24 candidates by asking the robot a series of yes/no questions about the suspect's features (e.g., clothing, accessories). The grid was displayed on the interface, while questions were posed verbally.

#figure([
#box(image("images/task1-whodunnit.png", width: 5.02083in))
], caption: figure.caption(
position: bottom, 
[
In the first task, participants were required to identify a suspect from a 6 × 4 grid of 24 candidates by asking the robot a series of yes/no questions about the suspect's features (e.g., hair color, accessories, clothing). The grid was displayed on the interface, while questions were posed verbally to the robot. Participants could track those eliminated here and input their final answer.
]), 
kind: "quarto-float-fig", 
supplement: "Figure", 
)
<fig-task1>


The robot possessed ground-truth information necessary to answer each question correctly. Successful task completion was therefore dependent on interaction with the robot, creating a forced collaborative dynamic. Participants were required to coordinate questioning strategies with the robot to narrow down the suspect within a five-minute time limit. The structured nature of the task ensured consistent interaction demands across participants and conditions.

==== Task 2: Open-Ended Collaborative Problem Solving
<task-2-open-ended-collaborative-problem-solving>
Task 2 involved a more open-ended reasoning challenge. Participants were presented with multiple technical logs through a simulated terminal interface that could be used to infer the location of the missing robot.

#figure([
#box(image("images/task2-cryptic-puzzle.png", width: 5.02083in))
], caption: figure.caption(
position: bottom, 
[
The task 2 interface presented multiple technical logs through a simulated terminal interface that could be used to determine the location of the missing robot.
]), 
kind: "quarto-float-fig", 
supplement: "Figure", 
)
<fig-task2>


Unlike Task 1, the robot did not have access to ground-truth information or the contents of the logs. The robot's assistance was limited to general reasoning support derived from its language model, such as explaining how to interpret log formats, suggesting problem-solving strategies, or prompting participants to reflect on inconsistencies.

Participants could complete this task independently or solicit assistance from the robot at their discretion @lin2022. This design allowed collaboration to emerge voluntarily rather than being enforced by task structure, positioning the robot as an advisory partner rather than an authoritative source.

=== Study Protocol
<study-protocol>
In-person sessions were conducted in a quiet, private room at Laurentian University between November and December. Prior to each session, the robot's interaction policy was configured to the assigned experimental condition.

Upon arrival, participants were greeted by the researcher, provided with a brief overview of the session, and given instructions for effective communication with the robot, including waiting for a visual indicator before speaking. Once participants indicated readiness, the researcher exited the room, leaving the participant and robot to complete the interaction without human presence or observation. Participants initiated the interaction by clicking a start button on the interface and were informed that they could terminate the session at any time without penalty.

Following task completion, participants completed a post-interaction questionnaire assessing trust. Participants then engaged in a brief debrief with the researcher. Total session duration averaged approximately 30 minutes.

=== Measures
<measures>
A combination of self-report and objective measures was used to assess trust, engagement, and task performance.

==== Self-Report Measures
<self-report-measures>
Participants completed a pre-session questionnaire assessing baseline characteristics, including the Negative Attitudes Toward Robots Scale (NARS) and the short form of the Need for Cognition scale (NFC-s). These measures were used to capture individual differences that may moderate responses to robot interaction.

Post-interaction trust was assessed using two validated instruments: the Trust Perception Scale--HRI and the Trust in Industrial Human--Robot Collaboration scale @bartneck2009@charalambous. Together, these measures capture multiple dimensions of trust, including perceived reliability, competence, and collaborative suitability.

==== Objective and behavioural Measures
<objective-and-behavioural-measures>
Objective task metrics included task completion, task accuracy, time to completion, and the number of assistance requests made to the robot. behavioural engagement metrics were derived from interaction logs and manually coded dialogue transcripts, including number of dialogue turns, frequency of communication breakdowns, response timing, and task-relevant robot contributions.

=== Participants, Communication Viability, and Analytic Strategy
<participants-communication-viability-and-analytic-strategy>
A total of 29 participants were recruited from the Laurentian University community via word of mouth and the SONA recruitment system. Eligibility criteria included being 18 years or older, fluent in spoken and written English, and having normal or corrected-to-normal hearing and vision. Participants received a \$15 gift card as compensation for their time. All procedures were approved by the Laurentian University Research Ethics Board (REB \#6021966).

Although English fluency was an eligibility requirement, in-person observation of variability in actual english language ability was noted for each session. Later post-hoc review of interaction transcripts and system logs revealed that a subset of sessions exhibited severe and sustained communication failure. In these sessions, automatic speech recognition (ASR) output was largely unintelligible or fragmented, preventing the robot from extracting sufficient linguistic content to maintain dialogue, respond meaningfully to participant queries, or support task progression. As a result, interaction frequently stalled, participant questions went unanswered or were misinterpreted, and collaborative problem-solving was effectively impossible. These sessions did not reflect degraded interaction quality but rather a complete breakdown of language-mediated communication, rendering the experimental manipulation inoperative.

Because the study relied fundamentally on spoken-language collaboration, sessions exhibiting persistent communication failure were classified as #strong[protocol non-adherence] and excluded from task-level analyses (#emph[n] = 6). Exclusion decisions were based solely on communication viability and interaction mechanics, not on task outcomes or trust measures.

To ensure transparency and to evaluate the impact of communication-based exclusions, analyses were conducted in three stages. First, the #strong[eligible-sample analysis] (excluding non-viable sessions) was treated as the primary analysis because it reflects interactions in which the spoken-language protocol---and therefore the experimental manipulation---operated as intended. Second, a #strong[full-sample analysis] including all participants was conducted as a sensitivity test to evaluate robustness to communication failures and protocol deviations. Third, a #strong[mechanism-focused analysis] compared excluded and included sessions on interaction-process metrics (e.g., ASR failure rates, dialogue turn completion, task abandonment) to quantify how severe communication breakdown alters the interaction dynamics and renders the manipulation inoperative.

It is important to note that while full-sample analyses are informative as robustness checks, trust measures obtained from sessions with complete communication breakdown are not interpreted as valid estimates of human--robot trust in the intended sense. In these cases, the robot was unable to sustain dialogue or collaborative behaviour, meaning that participants could not meaningfully evaluate reliability, competence, or collaborative intent. Full-sample analyses are therefore treated as sensitivity analyses reflecting real-world failure conditions, rather than as alternative estimates of trust under functional interaction.

Across analyses, participants in the responsive and control conditions were comparable with respect to demographic characteristics, prior experience with robots, and baseline attitudes toward robots, including Negative Attitudes Toward Robots (NARS) and Need for Cognition scores @nomura2006@cacioppo1984@cacioppo1996.

= Results
<results>
== Communication Viability and Analytic Samples
<communication-viability-and-analytic-samples>
Prior to hypothesis testing, interaction sessions were classified based on communication viability using a dialogue-level metric derived from system logs and manual coding. Specifically, the proportion of dialogue turns affected by speech-recognition failure or fragmented utterances was computed for each session. Sessions in which more than 50% of dialogue turns (half of all turns were dependent on human speech) were characterized by communication breakdown were classified as non-viable (n=6). This criterion closely matched sessions independently flagged during administration and reflects cases in which sustained spoken-language interaction was not possible.

Of the 29 completed sessions, 6 were classified as non-viable due to severe and persistent communication failure (i.e., unintelligble sentence fragments). Because the experimental manipulation relied on language-mediated collaboration, analyses were conducted using three complementary approaches: (1) a primary eligible-sample analysis excluding non-viable sessions, (2) a full-sample sensitivity analysis including all sessions, and (3) a mechanism-focused analysis examining how communication breakdown altered interaction dynamics.

Unless otherwise noted, inferential results reported below refer to the eligible sample.

== Primary Analysis: Eligible Sample
<primary-analysis-eligible-sample>
=== Descriptive Outcomes
<descriptive-outcomes>
Descriptive comparisons of post-interaction trust measures indicated higher trust ratings in the RESPONSIVE condition relative to the CONTROL condition across both trust scales (see #ref(<tbl-post-eligible>, supplement: [Table])). Average post-interaction scores on the Trust in Industrial Human--Robot Collaboration scale differed by approximately 26 points (Likert 1-5 converted to 0-100 scale for easier comparison across scales). While differences in Trust Perception Scale--HRI scores were approximately 15 points higher in the responsive condition, while scores on the Behavioural summaries further indicated differences in dialogue patterns and robot assistance behaviours consistent with the intended interaction policies.

Importantly objective task accuracy did not differ between conditions across any task-level measures. This suggests that observed differences in trust were not driven by differential task success.

#figure([
#{set text(font: ("system-ui", "Segoe UI", "Roboto", "Helvetica", "Arial", "sans-serif", "Apple Color Emoji", "Segoe UI Emoji", "Segoe UI Symbol", "Noto Color Emoji") , size: 9.75pt); table(
  columns: (25%, 25%, 25%, 25%),
  align: (left,center,center,center,),
  table.header(table.cell(align: bottom + left, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #strong[Characteristic];], table.cell(align: bottom + center, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #strong[CONTROL] \
    N = 9#text(size: 0.75em , style: "italic" , weight: "regular")[#super[1];]], table.cell(align: bottom + center, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #strong[RESPONSIVE] \
    N = 14#text(size: 0.75em , style: "italic" , weight: "regular")[#super[1];]], table.cell(align: bottom + center, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #strong[p-value];#text(size: 0.75em , style: "italic" , weight: "regular")[#super[2];]],),
  table.hline(),
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Trust in Industrial HRI Collaboration], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[41 (22)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[67 (21)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(weight: "bold"); 0.007],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Subscales], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Reliability subscale], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[41 (25)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[65 (18)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(weight: "bold"); 0.022],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Trust Perception subscale], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[46 (21)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[60 (22)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.14],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Affective Trust subscale], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[52 (32)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[79 (22)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(weight: "bold"); 0.030],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Trust Perception Scale--HRI], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[62 (15)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[77 (18)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(weight: "bold"); 0.046],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Overall Task Accuracy], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.60 (0.22)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.66 (0.23)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.49],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Objective Measures], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Dialogue Turns], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[36 (7)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[33 (5)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.21],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Avg Task Duration (mins)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[13.82 (2.60)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[15.26 (2.12)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.16],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Avg Response Time (ms)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[13.21 (0.84)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[17.24 (2.52)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(weight: "bold"); \<0.001],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Silent Periods], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5.67 (2.06)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4.71 (2.05)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.29],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Engaged Responses], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2.22 (2.22)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3.50 (1.95)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.077],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Frustrated Responses], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.56 (0.73)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.93 (1.21)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.58],
  table.hline(),
  table.footer(table.cell(colspan: 4)[#text(size: 0.75em , style: "italic" , weight: "regular")[#super[1];] Mean (SD)],
    table.cell(colspan: 4)[#text(size: 0.75em , style: "italic" , weight: "regular")[#super[2];] Wilcoxon rank sum test; Wilcoxon rank sum exact test],),
)}
], caption: figure.caption(
position: top, 
[
Table 2. Post-Interaction Raw Outcome Measures by Group
]), 
kind: "quarto-float-tbl", 
supplement: "Table", 
)
<tbl-post-eligible>


Despite similar task accuracy, interactions in the responsive condition were characterized by longer durations, slower response times, and a higher number of AI-detected engaged responses. These findings suggest that responsiveness altered the interaction dynamics and affective tone rather than task outcomes.

=== Hierarchical Models of Post-Interaction Trust
<hierarchical-models-of-post-interaction-trust>
To evaluate condition effects on post-interaction trust, linear mixed-effects models were fitted separately for each trust outcome. All models included interaction policy (RESPONSIVE vs.~CONTROL) as the primary fixed effect, along with baseline negative attitudes toward robots (NARS) and native English fluency as covariates. Random intercepts for session were included in all models to account for repeated measurement at the participant level.

Model building proceeded by comparing a baseline model containing interaction policy alone against models incorporating theoretically motivated covariates. Adding baseline negative attitudes toward robots significantly improved model fit (χ² = 4.82, p = .028), whereas prior experience with robots did not. Native English fluency did not significantly improve model fit but was retained as a covariate due to its relevance for spoken-language interaction viability.

=== Trust in Industrial Human--Robot Collaboration
<trust-in-industrial-humanrobot-collaboration>
In the final model predicting Trust in Industrial Human--Robot Collaboration, interaction with the responsive robot was associated with significantly higher post-interaction trust scores (β = 16.28, SE = 5.14, t = 3.17, p = .005). Higher baseline negative attitudes toward robots were associated with lower trust (β = −7.43, SE = 2.81, p = .016). Native English fluency showed a negative but non-significant association with trust.

For this outcome, inclusion of random intercepts for individual trust items significantly improved model fit, indicating meaningful item-level variability beyond session-level differences.

=== Trust Perception Scale--HRI
<trust-perception-scalehri>
For the Trust Perception Scale--HRI, a comparable mixed-effects model was fitted using the same fixed effects structure. In this model, interaction with the responsive robot was associated with higher post-interaction trust scores (β = 14.17, SE = 6.5, t = 2.00, p = 0.046). Effects of baseline negative attitudes toward robots and native English fluency followed a similar directional pattern but did not reliably differ from zero.

In contrast to the collaboration trust scale, inclusion of random intercepts for individual trust items did not improve model fit for the Trust Perception Scale--HRI and was therefore omitted. This divergence likely reflects differences in scale format and response interface: the Trust Perception scale was administered using a continuous slider input, whereas the Trust in Industrial Human--Robot Collaboration scale employed discrete Likert-style response options.

Informal observation during administration and post-hoc inspection of item-level variance suggest that the slider-based interface, administered via a touchpad, may have reduced response precision relative to discrete response formats. While this likely attenuated item-level variability, the Trust Perception Scale--HRI nevertheless captured meaningful between-condition differences at the aggregate level.

Together, these models indicate that robot responsiveness had a consistent positive effect on post-interaction trust, with effect magnitude and measurement sensitivity varying by trust dimension and scale format.

#figure([
#box(image("misty-paper_files/figure-typst/fig-post-eligible2-1.svg"))
], caption: figure.caption(
position: bottom, 
[
Distribution of Trust in Industrial Human--Robot Collaboration scores by interaction policy. Points represent individual observations; violins depict score distributions. Red points indicate group means with 95% confidence intervals. Statistical comparisons are reported in the Results section.
]), 
kind: "quarto-float-fig", 
supplement: "Figure", 
)
<fig-post-eligible2>


#figure([
#box(image("misty-paper_files/figure-typst/fig-post-eligible-1.svg"))
], caption: figure.caption(
position: bottom, 
[
Distribution of Trust Percention in HRI scores by interaction policy. Points represent individual observations; violins depict score distributions. Red points indicate group means with 95% confidence intervals. Statistical comparisons are reported in the Results section.
]), 
kind: "quarto-float-fig", 
supplement: "Figure", 
)
<fig-post-eligible>


==== Bayesian analysis
<bayesian-analysis>
To complement frequentist mixed-effects models, Bayesian hierarchical models were fitted separately for each trust outcome using weakly informative priors. Models predicted post-interaction trust as a function of interaction policy (RESPONSIVE vs.~CONTROL), with random intercepts for session and trust scale items to account for repeated measurement and item-level variability.

Across both trust measures, posterior estimates favored higher trust ratings in the RESPONSIVE condition. For the Trust in Industrial Human--Robot Collaboration scale, the estimated group difference was #emph[\[insert median\]] points (95% credible interval \[#emph[lower];, #emph[upper];\]), with a posterior probability greater than #emph[\[insert\]%] that the effect exceeded a practically meaningful threshold of five points on the 0--100 scale. Posterior mass exceeding ten points was #emph[\[insert\]%];, indicating a substantial likelihood of a large effect.

For the Trust Perception Scale--HRI, the estimated group difference was smaller and more uncertain (#emph[\[insert median\]] points; 95% credible interval \[#emph[lower];, #emph[upper];\]). Although the credible interval included zero, the posterior probability that the responsive condition increased trust was greater than #emph[\[insert\]%];, suggesting a consistent directional effect with greater individual variability.

Sensitivity analyses using wider priors yielded nearly identical posterior estimates, indicating that results were not driven by prior specification.

=== Sensitivity Analysis: Full Sample
<sensitivity-analysis-full-sample>
Including sessions classified as non-viable increased variability and attenuated estimated effect sizes across trust measures. As expected, posterior uncertainty increased relative to the eligible-sample analysis. However, directional trends favoring the RESPONSIVE condition remained evident across both trust outcomes.

#figure([
#{set text(font: ("system-ui", "Segoe UI", "Roboto", "Helvetica", "Arial", "sans-serif", "Apple Color Emoji", "Segoe UI Emoji", "Segoe UI Symbol", "Noto Color Emoji") , size: 9.75pt); table(
  columns: (25%, 25%, 25%, 25%),
  align: (left,center,center,center,),
  table.header(table.cell(align: bottom + left, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #strong[Characteristic];], table.cell(align: bottom + center, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #strong[CONTROL] \
    N = 13#text(size: 0.75em , style: "italic" , weight: "regular")[#super[1];]], table.cell(align: bottom + center, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #strong[RESPONSIVE] \
    N = 16#text(size: 0.75em , style: "italic" , weight: "regular")[#super[1];]], table.cell(align: bottom + center, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #strong[p-value];#text(size: 0.75em , style: "italic" , weight: "regular")[#super[2];]],),
  table.hline(),
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Trust in Industrial HRI Collaboration], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[47 (26)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[61 (26)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.094],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Subscales], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Reliability subscale], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[46 (24)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[62 (20)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.11],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Trust Perception subscale], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[49 (26)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[57 (25)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.32],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Affective Trust subscale], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[59 (33)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[72 (29)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.26],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Trust Perception Scale--HRI], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[63 (17)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[73 (19)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.16],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Overall Task Accuracy], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.63 (0.20)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.61 (0.27)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.98],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Objective Measures], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Dialogue Turns], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[32 (10)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[36 (11)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.95],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Avg Task Duration (mins)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[12.84 (4.02)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[16.81 (6.38)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(weight: "bold"); 0.050],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Avg Response Time (ms)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[15.1 (4.1)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[17.2 (2.4)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(weight: "bold"); 0.006],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Silent Periods], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5.15 (2.27)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5.31 (2.82)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.88],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Engaged Responses], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1.92 (2.25)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3.50 (1.83)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(weight: "bold"); 0.020],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Frustrated Responses], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.54 (0.66)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.88 (1.15)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.56],
  table.hline(),
  table.footer(table.cell(colspan: 4)[#text(size: 0.75em , style: "italic" , weight: "regular")[#super[1];] Mean (SD)],
    table.cell(colspan: 4)[#text(size: 0.75em , style: "italic" , weight: "regular")[#super[2];] Wilcoxon rank sum test; Wilcoxon rank sum exact test],),
)}
], caption: figure.caption(
position: top, 
[
Table 3. Post-Interaction Raw Outcome Measures by Group
]), 
kind: "quarto-float-tbl", 
supplement: "Table", 
)
<tbl-post-fullsample>


These results indicate that while communication breakdown weakens the interpretability of trust measures, the overall pattern of results is not solely an artifact of exclusion decisions. Full-sample analyses are therefore treated as robustness checks reflecting real-world interaction variability rather than as alternative estimates of trust under functional interaction conditions.

=== Mechanism Analysis: Communication Breakdown as a Failure Mode
<mechanism-analysis-communication-breakdown-as-a-failure-mode>
To examine why communication-based exclusion was necessary, interaction dynamics were compared between viable and non-viable sessions. Sessions classified as non-viable were characterized by substantially higher rates of speech-recognition failure, reduced dialogue coherence, increased task abandonment, and limited task-relevant information exchange.

Notably, under conditions of severe communication breakdown, the RESPONSIVE robot continued to generate proactive assistance, encouragement, and meta-communication aimed at repairing the interaction. However, these efforts did not restore mutual understanding and, in several cases, appeared to increase participant confusion and cognitive load. In contrast, the CONTROL robot's reactive interaction policy resulted in fewer unsolicited interventions, which---while less supportive under normal conditions---reduced interaction complexity when language-mediated collaboration was no longer viable.

As a result, trust ratings in non-viable sessions did not systematically track the intended responsiveness manipulation. These findings suggest that when spoken-language interaction collapses, higher-level constructs such as trust and collaboration are no longer meaningfully instantiated. Communication viability therefore represents a boundary condition for evaluating affect-adaptive interaction policies in autonomous social robots.

== Trust subscale patterns
<trust-subscale-patterns>
== Interaction dynamics and task performance
<interaction-dynamics-and-task-performance>
=== Task performance
<task-performance>
Objective task accuracy did not differ between conditions across any task-level measures except suspect accuracy (robot dependendant task), indicating that increased trust was only attributable to improved task success when interaction was necessary to complete accurately.

Despite similar task accuracy, interactions in the responsive condition were characterized by longer durations, slower response times, and a higher number of AI-detected engaged responses. These findings suggest that responsiveness altered the interaction dynamics and affective tone rather than task outcomes.

== Individual differences and correlational patterns
<individual-differences-and-correlational-patterns>
As expected, we found that higher Need for Cognition (NFC) scores were negatively associated with Negative Attitudes Towards Robots (NARS), indicating that individuals who enjoy effortful thinking tend to have more positive attitudes towards robots. This relationship is consistent with prior literature suggesting that cognitive engagement is associated with openness to new technologies. In terms of NARS subscales, NFC was negatively correlated with all three subscales, but significantly so only in the domain of Situations of Interaction with Robots. This suggests that individuals with higher NFC are less likely to hold negative attitudes across various dimensions of robot interaction but especially around direct interaction with robots.

--\> how to talk about post-interaction correlations w/pre-interaction measures Several behavioural and task-level measures were correlated with post-interaction trust, consistent with the interpretation that trust judgments were shaped by interaction quality; these variables were not included as covariates in primary models to avoid conditioning on potential mediators.

Baseline negative attitudes toward robots were negatively correlated with post-interaction trust, with the strongest associations observed for affective trust subscales. In contrast, objective task performance was selectively associated with perceived reliability. Need for cognition was negatively correlated with negative robot attitudes and interaction-level negative affect, suggesting that individual differences contributed to variability in trust responses.

#figure([
#box(image("misty-paper_files/figure-typst/fig-corr-1.svg"))
], caption: figure.caption(
separator: "", 
position: bottom, 
[
#block[
]
]), 
kind: "quarto-float-fig", 
supplement: "Figure", 
)
<fig-corr>


=== Model robustness and predictive checks
<model-robustness-and-predictive-checks>
Sensitivity analyses using alternative prior specifications yielded substantively similar estimates, and leave-one-out cross-validation indicated comparable predictive performance between models with and without the group effect.

#block[
#callout(
body: 
[
- add subscale column to long format data
- run an analysis of performance by robot-dependent versus robot-independent tasks
- write up a future directions section for the planned larger study
- talk about unexpected language issues with people signing up with difficultly speaking and understanding english which cuased problems with asr and interaction
- run analysis of dialogue dynamics included Bertopic or some other analysis of the actual content of the conversations/interactions

]
, 
title: 
[
TO DO:
]
, 
background_color: 
rgb("#f7dddc")
, 
icon_color: 
rgb("#CC1914")
, 
icon: 
fa-exclamation()
, 
body_background_color: 
white
)
]
#block[
#callout(
body: 
[
Manually score each dialogue series.

For each interaction and stage:

- did the participant ask for help?
- how many times?
- did the robot give useful help?
- did the robot give misleading or incorrect help?
- did the robot stick to the policy?
- how many times did the robot fail to understand the participant?

For each task:

- is there evidence that the robot helped complete the task?
- is there evidence that the participant solved the problem without help?

]
, 
title: 
[
TODO2
]
, 
background_color: 
rgb("#f7dddc")
, 
icon_color: 
rgb("#CC1914")
, 
icon: 
fa-exclamation()
, 
body_background_color: 
white
)
]
= Discussion
<discussion>
Mention language confounders!! The present findings also highlight an important boundary condition for trust measurement in spoken-language HRI. When language-mediated interaction collapses entirely, higher-level constructs such as trust and collaboration are no longer meaningfully defined. Under such conditions, trust does not simply decrease; rather, the interaction fails to instantiate the prerequisites necessary for trust formation. This distinction is critical for both system evaluation and experimental design, particularly as autonomous robots are deployed in linguistically diverse, real-world environments.

Because the study relied fundamentally on spoken-language collaboration, sessions exhibiting persistent communication failure were classified as #strong[protocol non-adherence] and excluded from task-level analyses (#emph[n] = 6). While the experimenter documented all cases where language might pose an issue (as observed when meeting each participant), exclusion decisions were based solely on actual communication viability and interaction mechanics, not on task outcomes or trust measures.

The second task was intentionally designed to be sufficiently challenging that completing it within the allotted time was difficult without assistance. This ensured that interaction with the robot represented a meaningful opportunity for collaboration rather than a trivial or purely optional exchange. By contrasting a robot-dependent task with an open-ended advisory task, the study examined trust formation across interaction contexts that varied in both informational asymmetry and reliance on the robot.

This pilot study examined trust outcomes following in-person interaction with an autonomous social robot under two interaction policies: a responsive, affect-adaptive condition and a neutral, non-responsive control condition. By leveraging a fully autonomous dialogue system integrated with speech recognition and affect detection, the study aimed to evaluate how robot responsiveness influences trust formation in realistic human--robot collaboration scenarios.

Descriptive comparisons of post-interaction measures indicated that participants in the responsive condition reported consistently higher trust across all trust measures, with differences ranging from approximately 8 to 16 points on a 0--100 scale, although uncertainty remained high given the small sample. Notably, the responsive condition did not differ from control in objective task accuracy, suggesting that increased trust was not driven by improved task success. Instead, responsive interactions were characterized by longer durations, slower response times, and a higher number of AI-detected engaged responses, indicating a shift in interaction dynamics rather than performance.

Baseline negative attitudes toward robots were most strongly associated with affective components of trust rather than perceptions of reliability, suggesting that pre-existing attitudes primarily shape emotional responses to interaction rather than judgments of system competence. Conversely, objective task performance was selectively associated with perceived reliability, indicating that participants distinguished between affective and functional aspects of trust.

Future work with larger samples could formally test mediation pathways linking robot responsiveness, interaction fluency, affective responses, and trust judgments, as well as moderation by baseline attitudes toward robots and need for cognition.

Participants in the responsive condition also exhibited higher levels of AI-detected engagement during interaction, as indexed by a greater number of responses classified as positive affect (t-test result). This suggests that responsive behaviours altered the affective tone of the interaction itself.

== Technical challenges
<technical-challenges>
Need to discuss that these items were on a 0-100 scale that required sliding a bar, while the other trust scale was on a 1-5 Likert that required simply clicking. The post test was administered on a laptop with a trackpad which may have caused difficulties for some participants who found it difficult to drag the slider with the trackpad. This could have introduced additional noise into the measurement of this scale, which may explain why the effects were somewhat weaker here.

- Need to talk about language issues with participants who had difficulty speaking and understanding English which caused problems with ASR and interaction.
- Need to talk about issues where the AI was not able to flexibly handle when people asked a question about the suspect that was close to or another word for a ground-truth feature but not exactly the same word, causing confusion and miscommunication. E.g., "Was the suspect wearing pink?" The ground-truth feature was top: PINK, top-type: HOODIE; but the ASR and NLU did not extrapolate to understand that "wearing pink" referred to the same feature as "top: PINK", causing confusion and miscommunication. Maybe the prompt could have included some examples of different phrasing which could improve this? To solve this issue in future work, we can expand the NLU training data to include more paraphrases and synonyms for each feature.

There was also a case where someone asked 'is the top shirt hoodie red?' to which the AI answered YES. It may have been confused by the multiple descriptors in the question. Future work could involve improving the NLU to handle more complex queries with multiple attributes.

Discuss future work where we will look investigate the 'embodied' effect of having a physical robot versus a virtual agent on trust and collaboration in HRI.

Also, prompt could include examples of what to do when dialogue appears fragmented, to remind participants to wait until the blue light is on before speaking and to switch up its phrasing if the robot seems to not understand.

Also, the control condition seemed to be somewhat neutered in terms of flexibility in responding in different ways. it would always respond with the exact same phrase when confronted with a sentence fragment or a question it could not directly answer.

Also issues with people not paying attention to the robot's visual cues to know when to speak, leading to more fragmented dialogue. Future work could involve improving participant instructions, improved latency and 'listening' … and the robot's feedback mechanisms to better manage turn-taking.

Need to remember to flag participants who did not complete/skipped specific tasks. E.g. P56 skipped the wrapup entirely. Many skipped the brief (by advancing on their own through the dashboard).

= Conclusion and Future Work
<conclusion-and-future-work>
= Appendix
<appendix>
== Dialogue Coding Scheme
<dialogue-coding-scheme>
=== Task Outcome Layer (Stage-Level)
<task-outcome-layer-stage-level>
#table(
  columns: (33.33%, 33.33%, 33.33%),
  align: (auto,auto,auto,),
  table.header([Variable], [Type], [Description],),
  table.hline(),
  [`task_outcome`], [categorical], [Final task status (`completed`, `timeout`, `skipped`, `partial`, `abandoned`). Exactly one per task.],
  [`task_completed`], [binary], [Task goal was fully completed within the allotted time.],
  [`task_timed_out`], [binary], [Task ended due to expiration of the time limit before completion.],
  [`task_skipped`], [binary], [Participant explicitly skipped or advanced past the task without completing it.],
  [`task_partially_completed`], [binary], [Task progress was made, but the full solution was not reached.],
  [`task_abandoned`], [binary], [Participant disengaged or stopped attempting the task before timeout.],
  [`task_time_remaining_sec`], [numeric], [Time remaining (in seconds) when the task ended; 0 if timed out.],
  [`task_completed_without_help`], [binary], [Task was completed without any help requests to the robot.],
  [`task_required_robot_help`], [binary], [At least one robot help interaction was required for task completion.],
)
=== Dialogue Interaction Layer (Turn-Level)
<dialogue-interaction-layer-turn-level>
==== Human Turn Codes
<human-turn-codes>
#table(
  columns: (33.33%, 33.33%, 33.33%),
  align: (auto,auto,auto,),
  table.header([Variable], [Type], [Description],),
  table.hline(),
  [`human_help_request`], [binary], [Participant explicitly or implicitly asks the robot for help or guidance.],
  [`human_reasoning_self`], [binary], [Participant articulates their own reasoning or problem-solving independent of the robot.],
  [`human_confusion`], [binary], [Participant expresses confusion or uncertainty.],
  [`human_confirmation_seeking`], [binary], [Participant seeks confirmation of a tentative belief or solution.],
  [`human_ignores_robot`], [binary], [Participant proceeds without engaging with the robot's prior input.],
)
==== Robot Turn Codes
<robot-turn-codes>
#table(
  columns: (33.33%, 33.33%, 33.33%),
  align: (auto,auto,auto,),
  table.header([Variable], [Type], [Description],),
  table.hline(),
  [`robot_helpful_guidance`], [binary], [Robot provides accurate, task-relevant guidance.],
  [`robot_misleading_guidance`], [binary], [Robot provides misleading or incorrect guidance.],
  [`robot_factually_incorrect`], [binary], [Robot states information that is objectively incorrect.],
  [`robot_policy_violation`], [binary], [Robot violates stated system or task constraints.],
  [`robot_on_policy_unhelpful`], [binary], [Robot adheres to policy but provides vague or non-actionable assistance.],
  [`robot_stt_failure`], [binary], [Robot response reflects a speech-to-text or input understanding failure.],
  [`robot_clarification_request`], [binary], [Robot asks the participant to repeat or clarify their input.],
)
=== Affective Interaction Layer (Turn-Level)
<affective-interaction-layer-turn-level>
==== Robot Affective behaviour
<robot-affective-behaviour>
#table(
  columns: (33.33%, 33.33%, 33.33%),
  align: (auto,auto,auto,),
  table.header([Variable], [Type], [Description],),
  table.hline(),
  [`robot_empathy_expression`], [binary], [Robot expresses empathy, encouragement, or reassurance.],
  [`robot_emotion_acknowledgement`], [binary], [Robot explicitly references an inferred participant emotional state.],
  [`robot_affect_task_aligned`], [binary], [Robot's affective response is appropriate and supportive in context.],
  [`robot_affect_misaligned`], [binary], [Robot's affective response is mistimed or disruptive to the task.],
)
==== Human Affective Response
<human-affective-response>
#table(
  columns: (33.33%, 33.33%, 33.33%),
  align: (auto,auto,auto,),
  table.header([Variable], [Type], [Description],),
  table.hline(),
  [`human_affective_engagement`], [binary], [Participant responds in a socially warm or emotionally engaged manner.],
  [`human_social_reciprocity`], [binary], [Participant mirrors or responds to the robot's affective expression.],
  [`human_anthropomorphic_language`], [binary], [Participant treats the robot as a social agent.],
  [`human_emotional_disengagement`], [binary], [Participant responds in a curt, dismissive, or withdrawn manner.],
)
=== Notes
<notes>
- Turn-level variables are coded per dialogue turn.
- Task outcome variables are coded once per `session_id × stage`.
- Raw dialogue text was retained during coding and removed prior to aggregation.
- Multiple turn-level codes may co-occur unless otherwise specified.

== Key Components of the System
<key-components-of-the-system>
This study implemented a multi-stage collaborative task system where participants collaborate with the Misty II social robot to solve a who-dunnit type task. The system utilizes an autonomous, mixed-initiative dialogue architecture via langchain with affect-responsive capabilities.

+ Misty-II Robot: A programmable robot platform equipped with sensors and actuators for interaction.

+ Automated Speech Recognition (ASR): A speech-to-speech pipeline that processes spoken input from users and converts it into text for LLM processing then back to speech for output on the robot.

  - STT: Deepgram API for real-time speech-to-text conversion.
  - DistilRoBERTa-base fine-tuned on emotion classification for emotion detection from user utterances
  - LLM: Gemini API for processing text input and generating contextually relevant responses in JSON format
  - TTS: Misty-II text-to-speech (TTS) engine on 820 processor.

+ Langchain Dialogue Management: A system that manages the flow of conversation, ensuring coherent and contextually appropriate dialogue within a two-part collaborative task.

+ Collaborative-Tasks

  - Task 1: Whodunnit style task where human and robot collaborate to find a missing robot via the human asking Yes/No questions (process of elimination in 6x4 suspect grid) to the robot. Robot knows ground truth but can only answer Yes/No questions about suspect features. Can not directly describe the suspect or name them. (human can choose a random suspect to solve on their own but only 1 in 24 chance of being correct without robot help)
  - Task 2: Where is Atlas? Robot collaborates with human to find Atlas by deciphering cryptic system and sensor logs. Robot does not know the answer here and can only guide the human usinng its expertise and knowledge of computer systems and basic logical reasoning. (human can solve on their own but very difficult without robot help depending on participants technical background).

+ Flask-gui dashboard interface: A web-based interface/dashboard that allowed participants to interact with the tasks, view task-related information and input their answers to the questions. Responses were sent to the robot to signal task progression.

  - Task 1 dashboard: Displays the suspect grid and allows the user to select suspects and view their features.
  - Task 2 dashboard: Displays system logs and allows the user to input their findings.

+ Pre and post tests:

  - PRE-TESTS: Need for Cognition Scale (short); Negative Attitudes to Robots Scale (NARS);
  - POST-TESTS: Trust Perception Scale-HRI; 9 custom questions adapted from Charalambous et al.~(2020) on trust in industrial human-robot collaboration;

= Technical Specifications
<technical-specifications>
== System Overview
<system-overview>
This study implements a multi-stage collaborative task system where participants collaborate with the Misty II social robot to solve a who-dunniti type task. The system utilizes an autonomous, mixed-initiative dialogue architecture with affect-responsive capabilities.

== Hardware Platform
<hardware-platform>
#strong[Robot];: Misty II Social Robot (Furhat Robotics)

- Mobile social robot platform with expressive display, arm actuators, and head movement
- RGB LED for state indication
- RTSP video streaming (1920×1080, 30fps) for audio capture
- Custom action scripting for synchronized multimodal expressions

== Software Architecture
<software-architecture>
=== Core System Components
<core-system-components>
#strong[Programming Language];: Python 3.10

#strong[Primary Dependencies];:

- `misty-sdk` (Python SDK for Misty Robotics API) - Robot control and sensor access
- `deepgram-sdk` (4.8.1) - Speech-to-text processing
- `ffmpeg-python` (0.2.0) - Audio stream processing
- `flask` (3.1.2) + `flask-socketio` (5.5.1) - Web interface for task presentation
- `duckdb` (1.4.0) - Experimental data logging database

=== Large Language Models
<large-language-models>
#strong[LLM Provider];:

#strong[Google Gemini];:

- Model: `gemini-2.5-flash-lite` (configurable via environment variable)
- Integration: `langchain-google-genai` with `google-generativeai` API
- Response format: JSON-only output (`response_mime_type: "application/json"`). This format is required by Misty-II for reliable parsing and for action execution.

#strong[LLM Configuration];:

- Temperature: 0.7 (for balanced creativity and coherence)
- Memory: Conversation buffer memory with file-based persistence (`langchain.memory.ConversationBufferMemory`)
- Context window: Full conversation history maintained across interaction stages but reset between sessions.

== LangChain Framework Integration
<langchain-framework-integration>
=== Core LangChain Components
<core-langchain-components>
#strong[Framework Version];: `langchain-core` with modular provider packages

- `langchain` (meta-package)
- `langchain-community` (0.3.31)
- `langchain-google-genai` Gemini integration

=== ConversationChain Architecture
<conversationchain-architecture>
#strong[Memory Management] (`ConversationChain` class in `conversation_chain.py`):

+ #strong[Conversation Buffer Memory];:
  - Implementation: `langchain.memory.ConversationBufferMemory`
  - Storage: File-based persistent chat history (`FileChatMessageHistory`)
  - Format: JSON files in `.memory/` directory, one per participant session
  - Memory key: `"history"`
  - Return format: Message objects (full conversation context)
+ #strong[Memory Reset Policy];:
  - Default: Reset on each new session launch
  - Archive previous session: Timestamped archive files stored in `.memory/archive/`
  - Configuration: `RESET_MEMORY` and `ARCHIVE_MEMORY` environment variables

=== Prompt Construction
<prompt-construction>
#strong[Message Structure]

(LangChain message types): `python [SystemMessage, *history_messages, HumanMessage]`

System Message Assembly:

- Core instructions (task framing, role definition)
- Personality instructions (mode-specific behaviour)
- Stage-specific instructions (current task context)
- Output format constraints (JSON schema specification)

```
Human Message Format:   {     
"user": "<transcribed_speech>",     
"stage": "<current_stage>",     
"detected_emotion": "<emotion_label>",     
"frustration_note": "<optional_alert>",     
"timer_expired": "<task_id>",     ...   }
```

- JSON-encoded context variables passed alongside user input
- Enables LLM to access environmental state without breaking message history

=== Memory Persistence:
<memory-persistence>
- Save after each turn: memory.save\_context({"input": user\_text}, {"output": llm\_response})
- Maintains conversational coherence across multi-stage interaction
- Enables LLM to reference previous exchanges (e.g., "As I mentioned earlier…")

=== LangChain Design Rationale
<langchain-design-rationale>
Why LangChain for this application:

+ Memory abstraction: Automatic conversation history management without manual message list handling
+ Provider flexibility: Easy switching between Gemini and OpenAI without rewriting prompt logic
+ Message typing: Structured SystemMessage/HumanMessage/AIMessage types maintain role clarity
+ File persistence: Built-in FileChatMessageHistory enables session recovery and archiving
+ Future extensibility: Framework supports adding tools, retrieval, or multi-agent patterns if needed

Alternatives considered: Direct API calls would reduce dependencies but require reimplementing conversation history management, prompt templating, and cross-provider compatibility layers.

=== LangChain Limitations in This Context
<langchain-limitations-in-this-context>
- No chains used: Despite name ConversationChain, this is a direct LLM wrapper (no LangChain Expression Language chains)
- No tools/agents: Simple request-response pattern (could extend for future tool-use capabilities)
- Custom JSON parsing: LangChain's built-in output parsers not used; custom extraction handles malformed responses more robustly

=== Speech Processing
<speech-processing>
#strong[Speech-to-Text (STT)];:

- Provider: Deepgram Nova-2 (`deepgram-sdk` 4.8.1)
- Model: `nova-2` with US English (`en-US`)
- Smart formatting enabled
- Interim results for real-time partial transcription
- Voice Activity Detection (VAD) events
- Adaptive endpointing: 200ms (conversational stages) / 500ms (log-reading task)
- Utterance end timeout: 1000ms (conversational) / 2000ms (log-reading)
- Audio processing: RTSP stream from Misty → FFmpeg MP3 encoding → Deepgram WebSocket

#strong[Text-to-Speech (TTS)] - Three options:

+ #strong[Misty Onboard TTS] (this is the one we used): Native robot voice via onboard TTS

+ #strong[OpenAI TTS];:

  - Model: `tts-1` (low-latency variant)
  - Voice: `sage`
  - Format: MP3, served via HTTP (port 8000)
  - Ultimately chose not to use because we wanted a more robotic, non-human voice
  - Didn't want the human voice influencing trust on its own (future research could look at trust in relation to type of voice)

+ #strong[Deepgram Aura];:

  - Model: `aura-stella-en` (conversational female voice)
  - Format: MP3, served via HTTP
  - Ultimately chose not to use because we wanted a more robotic, non-human voice

=== Emotion Detection
<emotion-detection>
#strong[Model];: DistilRoBERTa-base fine-tuned on emotion classification

- HuggingFace identifier: `j-hartmann/emotion-english-distilroberta-base`
- Framework: `transformers` (4.57.1) pipeline
- Hardware: CUDA GPU acceleration (automatic fallback to CPU)
- Output classes: joy, anger, sadness, fear, disgust, surprise, neutral
- Mapped to interaction states: positively engaged, irritated, disappointed, anxious, frustrated, curious, neutral

=== Multimodal Robot behaviour
<multimodal-robot-behaviour>
#strong[Expression System];: 25 custom action scripts combining:

- LLM was prompted to choose an appropriate expression from a predefined set based on context.
- Facial displays (image eye-expression files on screen)
- LED color patterns (solid, breathe, blink)
- Arm movements (bilateral position control)
- Head movements (pitch, yaw, roll control)

#strong[Nonverbal Backchannel behaviours] (RESPONSIVE mode only):

- Real-time listening cues triggered by partial transcripts (disfluencies, hesitation markers)
- Emotion-matched expressions (e.g., "concern" for hesitation, "excited" for breakthroughs)

#strong[LED State Indicators];:

- Blue (0, 199, 252): Actively listening (microphone open)
- Purple (100, 70, 160): Processing/speaking (microphone closed)

== Data Collection
<data-collection>
#strong[Database];: DuckDB relational database (`experiment_data.duckdb`)

#strong[Logged Data];:

1. #strong[Sessions table];: participant ID (auto-incremented P01, P02…), condition assignment, timestamps, duration

2. #strong[Dialogue turns table];: turn-by-turn user input, LLM response, expression, response latency (ms), behavioural flags

3. #strong[Task responses table];: submitted answers with timestamps and time-on-task

4. #strong[Events table];: stage transitions, silence check-ins, timer expirations, detected emotions

== Interaction Dynamics
<interaction-dynamics>
=== Silence Handling
<silence-handling>
#strong[Silence detection];: 25-second threshold triggers check-in prompt

- RESPONSIVE: "Still working on it? No rush - I'm here if you need help!"
- CONTROL: "I am ready when you have a question."

=== Emotion-Responsive behaviours (RESPONSIVE condition only)
<emotion-responsive-behaviours-responsive-condition-only>
#strong[Frustration tracking];:

- Consecutive detection of frustrated/anxious/irritated/disappointed states
- Threshold: ≥2 consecutive frustrated turns triggers proactive support
- RESPONSIVE adaptation: "This part can be tough. Want me to walk you through it?"

#strong[Positive emotion matching];:

- Celebratory language for curious/engaged states
- Momentum maintenance: "Yes! Great observation!"

#strong[Run Mode];: Set programmatically in `mistyGPT_emotion.py` line 126:

```python
RUN_MODE = "RESPONSIVE"  # or "CONTROL"
```

== Prompt Engineering
<prompt-engineering>
Modular prompt system (PromptLoader class):

- core\_system.md: Task framing, role description, output format schema
- role\_responsive.md / role\_control.md: Condition-specific personality instructions
- stage1\_greeting.md through stage5\_wrap\_up.md: Stage-specific task instructions.

Context injection: Real-time contextual variables passed to LLM:

- Current stage
- Detected emotion (if enabled)
- Task submission status
- Timer expiration notifications
- Silence check-in flags

== Inter-process Communication
<inter-process-communication>
Flask REST API endpoints:

- GET /stage\_current: Synchronize stage state with facilitator GUI
- GET /task\_submission\_status: Detect participant task submissions
- GET /timer\_expired\_status: Detect timer expirations
- POST /stage: Update stage (facilitator override)
- POST /reset\_timer: Clear timer expiration flags

#bibliography("bibliography.bib")

