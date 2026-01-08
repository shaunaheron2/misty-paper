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

#set page(
  paper: "us-letter",
  margin: (x: 1.25in, y: 1.25in),
  numbering: "1",
)

#show: doc => article(
  title: [Trust in Autonomous Human--Robot Collaboration: Effects of Responsive Interaction Policies],
  subtitle: [An In-Person Pilot Study],
  authors: (
    ( name: [M.C. Lau],
      affiliation: [],
      email: [mclau\@laurentian.ca] ),
    ( name: [Shauna Heron],
      affiliation: [],
      email: [sheron\@laurentian.ca] ),
    ),
  abstract: [Trust plays a central role in human--robot collaboration, yet its formation is rarely studied under the constraints of fully autonomous interaction. This pilot study examines how interaction policy influences trust during in-person collaboration with a social robot operating without Wizard-of-Oz control or scripted recovery. Participants completed a multi-stage collaborative task with a mobile robot that autonomously managed spoken-language dialogue, affect inference, and task progression. Two interaction policies were compared: a responsive policy, in which the robot proactively adapted its dialogue, assistance, and repair strategies based on user input and inferred interaction state, and a neutral, reactive policy, in which the robot provided only direct, task-relevant responses when explicitly prompted. Responsive interaction was associated with significantly higher post-interaction trust, despite no reliable differences in overall task accuracy. Sensitivity analyses revealed that experienced trust was highly sensitive to communication breakdown, whereas evaluative trust judgments were more robust. When language-mediated communication broke down, trust remained operative but no longer aligned with the collaborative trust construct assessed here, as interaction became dominated by communication viability rather than coordinated problem solving. These findings underscore that trust formation in human--robot interaction should be examined under fully autonomous conditions, and motivate future work on the design of integrated communication and interaction systems that can better support collaboration under real-world constraints.

],
  abstract-title: "Abstract",
  fontsize: 10pt,
  sectionnumbering: "1.1.a",
  toc_title: [Table of contents],
  toc_depth: 3,
  cols: 1,
  doc,
)

= Introduction
<introduction>
As artificial intelligence (AI) technologies advance, they are increasingly integrated into robotic systems, enabling more adaptive, autonomous, and context-sensitive behaviour in real-world environments. This convergence has accelerated the deployment of robots across safety-critical domains such as manufacturing @choi2025, mining @fu2021, and healthcare @ciuffreda2025, where robots are now expected to operate alongside humans rather than in isolation @diab2025@spitale2023. In these collaborative settings, successful deployment depends not only on technical performance and safety guarantees, but also on whether human users are willing to rely on, communicate with, and coordinate their actions around robotic partners @campagna2025@emaminejad2022. Trust has therefore emerged as a central determinant of adoption and effective use in human--robot collaboration (HRC) @wischnewski2023@campagna2025. Insufficient trust can lead to disuse or rejection of automation, while excessive trust risks overreliance and accidents---particularly in environments characterized by uncertainty or incomplete information @devisser2020.

In HRC, trust is commonly understood as a willingness to rely on an agent under conditions of uncertainty and risk @muir1994@hancock2011. This reliance is dynamically calibrated, shaping how closely users monitor a robot, when they intervene, and whether they defer or override its actions. Appropriately calibrated trust supports effective coordination, whereas under-trust may result in disengagement or redundant oversight, and over-trust can lead to inappropriate reliance and unsafe outcomes @devisser2020. These dynamics are especially pronounced in dialogue-driven collaborative tasks, where misunderstandings, delays, or ambiguous responses may directly influence users' ongoing assessments of a robot's competence and reliability.

A substantial body of human--robot interaction (HRI) research has examined how robot behaviour influences user trust, perceived reliability, and cooperation across industrial and social contexts @shayganfar2019@fartook2025. Trust is typically conceptualized as a multidimensional construct encompassing cognitive evaluations of competence, predictability, and reliability, alongside a behavioural willingness to collaborate toward shared goals under conditions of risk or uncertainty @muir1994@hancock2011@devisser2020. Despite this multidimensional framing, empirical studies have most often operationalized trust using post-interaction self-report questionnaires collected following short, highly controlled, and often scripted interactions. While such measures provide valuable global assessments of user attitudes, they offer limited insight into how trust is negotiated, disrupted, and repaired during ongoing interaction---particularly in autonomous systems where errors and ambiguities are unavoidable @maure.

Studying trust as an interactional process therefore requires experimental settings in which users engage with robots that exhibit both adaptive behaviour and realistic system limitations @campagna2025. In such settings, trust is shaped not only by task success but by how robots handle uncertainty, errors, and misalignment during interaction. Fully autonomous systems, where dialogue management and response generation occur without human intervention, provide a critical testbed for examining these dynamics, as they expose users to the same constraints and breakdowns encountered in real-world deployment @campagna2025.

Yet in practice, much of the existing HRI trust literature has relied on scripted behaviours, simulated environments, or Wizard-of-Oz paradigms in which a human operator covertly manages the robot's behaviour @bettencourt2025@campagna2025. While these approaches are valuable for isolating specific design factors, they obscure the interaction breakdowns and system imperfections that characterize deployed autonomous robots. Limitations such as speech recognition errors, delayed responses, misinterpretations of user intent, and incomplete affect sensing are not peripheral issues but defining features of real-world interaction. These failures are likely to play a decisive role in shaping trust and collaboration, yet remain underrepresented in empirical evaluations @campagna2025.

Within HRI, a range of design strategies have been proposed to support appropriate trust calibration during collaboration, including robot appearance @nicolas2021, transparency cues @zhang2019, explanations of system intent, adaptive feedback @val-calvo2020, and interaction pacing @kok2020. Many of these approaches aim to help users form accurate expectations about a robot's capabilities and limitations, particularly in contexts involving uncertainty or partial observability. Among these strategies, adaptive interaction behaviour---how and when a robot responds to user state and task context---has been identified as a particularly influential factor in shaping perceptions of competence, reliability, and collaboration @fartook2025.

Recent advances in AI have expanded the range of interaction strategies available to autonomous robotic platforms in practice, enabling systems to move beyond fixed, scripted behaviours toward adaptive interaction policies that respond to user state and task context in real time @atone2022. Improvements in spoken-language processing, dialogue state tracking, and large language model--based reasoning now allow robots to adjust not only what they say, but when and how assistance is provided during collaboration @wei. In parallel, advances in affect inference from language and interaction cues have made it increasingly feasible for robots to incorporate estimates of user emotional state into interaction management @mcduff@spitale2023. As a result, responsiveness in contemporary HRI is increasingly understood as a property of an underlying interaction policy, governing how a robot interprets cues, initiates support, and manages uncertainty, rather than as a surface-level social behaviour @birnbaum2016@shayganfar2019@fartook2025.

From an engineering perspective, responsiveness in autonomous human--robot interaction is not implemented as a single behavioural rule or surface-level cue, but emerges from the coordination of multiple system components responsible for perception, interpretation, and action @arkin2003. In practice, responsive behaviour depends on the integration of dialogue management, state tracking, and inference mechanisms that estimate task progress, interaction uncertainty, and user affect. Proactive assistance based on this integrated state representation differs fundamentally from reactive, request-based behaviour; for example, a robot may offer clarification, encouragement, or pacing adjustments when confusion, hesitation, or frustration is inferred, rather than waiting for an explicit request for help @birnbaum2016.

Implementing such behaviour requires autonomous systems to manage spoken-language dialogue, maintain interaction state over time, and coordinate verbal and nonverbal responses in real time, all while operating under noise, latency, and sensing uncertainty @campagna2025. As a result, responsiveness in deployed systems reflects properties of the overall interaction architecture, not merely the presence or absence of adaptive dialogue. Despite growing interest in responsive and affect-aware robots, relatively little empirical work has examined how such integrated interaction systems operate under fully autonomous conditions, or how their behaviour shapes trust and collaboration when communication breakdowns cannot be externally repaired @campagna2025.

The present work addresses these gaps through a pilot study examining trust and collaboration during in-person interaction with a fully autonomous social robot. Participants collaborated with one of two versions of the same robot platform during a dialogue-driven puzzle task requiring shared problem solving. In both conditions, all interaction management---including speech recognition, dialogue state tracking, task progression, and response generation---was handled and logged autonomously by a centralized dialogue agent without human intervention. In the responsive condition, the robot employed a proactive, affect-aware interaction policy, adapting its assistance based on conversational cues and inferred user affect (e.g., frustration or engagement). In the neutral condition, the robot followed a reactive policy, providing basic guidance and periodic check-ins, otherwise providing assistance only when explicitly requested.

This pilot study had three primary objectives: (1) to design and evaluate the feasibility of an autonomous spoken-language interaction system with affect-responsive behaviour on a mobile robot platform; (2) to assess whether a responsive interaction policy influences post-interaction trust and collaborative experience under realistic autonomous conditions; and (3) to explore how behavioural and interaction-level indicators align with subjective trust evaluations. Rather than optimizing for flawless interaction, the system was intentionally designed to reflect the capabilities and limitations of contemporary social robots, allowing interaction breakdowns to surface naturally.

By combining post-interaction trust measures with task-level and behavioural observations, this study aims to contribute empirical evidence on how trust in human--robot collaboration emerges and is enacted during fully autonomous interaction. The findings are intended to inform the design of a larger subsequent study by evaluating feasibility and identifying technical, interactional, and methodological challenges that must be addressed when evaluating affect-responsive robots in real-world contexts.

= Methods
<methods>
This study employed a between-subjects experimental design to examine how robot interaction policy influences trust and collaboration during fully autonomous, in-person human--robot interaction. The sole experimental factor was the robot's interaction policy, with participants randomly assigned to interact with either a responsive or neutral version of the same robot system.

Throughout this paper, references to "the robot" denote a fully autonomous interactive system comprising the Misty-II hardware platform and an integrated offboard software pipeline. Spoken-language understanding, dialogue management, task logic, and interaction policy execution were handled on an external edge device which interfaced with the robot via application programming interfaces. The Misty-II platform was responsible for audio capture, speech synthesis, and the execution of embodied behaviours including facial expressions, body movement, and LED signalling. Despite this distributed execution, all interaction decisions were generated autonomously by a centralized dialogue agent responsible for coordinating spoken-language understanding, task state, and verbal and nonverbal behaviour based on the interaction policy, without human intervention. More detail on the robot platform and software architecture is provided in Appendix A.

== Interaction Policies
<interaction-policies>
Across both tasks, interaction behaviour was governed by one of two interaction policies that differed in how the robot was intended to initiate, framed, and adapt its contributions during collaboration. Under both policies, the robot continuously monitored interaction timing and issued brief check-ins following extended periods of participant silence in order to preserve interaction continuity. In the neutral, reactive condition, these check-ins were minimal and task-focused, serving only to signal availability (e.g., indicating readiness to answer questions) without providing guidance, encouragement, or additional framing (e.g., "I'm ready for your next question.").

In contrast, under the responsive policy, the robot's utterances were affectively framed and context-sensitive. In addition to answering questions, the robot proactively adapted its dialogue, assistance, and repair strategies based on inferred interaction state, such as hesitation, frustration, or apparent difficulty. This included acknowledging task difficulty, offering encouragement, and proposing collaborative reasoning (e.g., "I can tell you're frustrated, don't worry! we can reason through this together"), rather than waiting for an explicit request for help. Beyond differences in check-in style, the responsive robot also initiated guidance or clarification when interaction stagnated, whereas the neutral robot limited its contributions to basic task guidance and direct queries.

Both conditions operated fully autonomously, without human intervention or scripted recovery, and used the same underlying task logic and sensing infrastructure.

== Collaborative Task Design
<collaborative-task-design>
The task structure was modelled after #cite(<lin2022b>, form: "prose") and designed to elicit collaboration under two distinct dependency conditions: enforced collaboration, in which successful task completion required the robot's involvement, and optional collaboration, in which participants could choose whether and how to engage the robot. To operationalize these conditions, participants completed an immersive, narrative-driven puzzle game consisting of five sequential stages and two timed reasoning tasks. The game positioned participants as investigators searching for a missing robot colleague, with the Misty-II robot serving as a diegetic guide and collaborative partner throughout the interaction. The full session lasted approximately 25 minutes.

Interactions took place in a shared physical workspace that included the Misty-II social robot and a participant-facing computer interface @mistyrobotics. The interface was used to display task materials, collect participant responses, and support progression through the game (see #ref(<fig-task1>, supplement: [Figure])). Importantly, the interface did not function as a control mechanism for the robot. Instead, the robot autonomously monitored task progression and participant inputs via the interface and adapted its dialogue and behaviour accordingly.

#figure([
#box(image("images/misty-pullback.jpg", width: 5.02083in))
], caption: figure.caption(
position: bottom, 
[
Experimental setup showing the autonomous robot and participant-facing task interface used during in-person sessions. Participants entered task responses and navigated between task stages using the interface, while the robot autonomously tracked task state and adapted its interaction based on participant input.
]), 
kind: "quarto-float-fig", 
supplement: "Figure", 
)
<fig-setup>


The interaction began with a brief greeting phase, during which the robot introduced itself and engaged in rapport-building dialogue. This was followed by a mission briefing in which the robot explained the narrative context and overall objectives. Participants then completed two core task stages: a robot-dependent collaborative reasoning task, in which the robot's participation was required to solve the problem, and a more open-ended problem-solving task in which robot assistance was optional. The interaction concluded with a wrap-up stage in which the robot provided closing feedback and formally ended the session.

Participants advanced between stages using the interface, either in response to the robot's prompts or at their own discretion. All spoken dialogue and interaction events were managed autonomously by the robot and logged automatically for analysis.

=== Task 1: Robot-Dependent Collaborative Reasoning
<task-1-robot-dependent-collaborative-reasoning>
In the first task, participants were asked to identify a perpetrator from a 6 × 4 grid of 24 'suspects' by asking the robot a series of yes/no questions about the suspect's features (e.g., "was the suspect wearing a hat?"). The grid was displayed on the interface, while questions were posed verbally.

#figure([
#box(image("images/task1-whodunnit2.png", width: 5.02083in))
], caption: figure.caption(
position: bottom, 
[
Task 1 interface including the 6 × 4 grid of 24 candidates. Participants could track those eliminated by clicking on subjects which would grey them out. A box was provided to input their final answer and a button included to move to the next task.
]), 
kind: "quarto-float-fig", 
supplement: "Figure", 
)
<fig-task1>


The robot possessed the ground-truth information necessary to answer each question correctly. Successful task completion was therefore dependent on interaction with the robot, creating an enforced collaborative dynamic. Participants were required to coordinate a questioning strategy that progressively eliminated candidates based on shared features, narrowing the search space within a five-minute time limit. Efficient performance depended on selecting informative questions (e.g., features that divided the remaining candidates), tracking eliminations, and adapting subsequent questions based on prior answers.

This structure made the task sensitive to interaction quality. Inefficient questioning, repeated queries, or uncertainty about next steps could slow progress and increase cognitive load, whereas effective coordination supported rapid elimination and convergence on a solution. The structured nature of the task ensured consistent interaction demands across participants and conditions, while still allowing meaningful variation in collaboration style.

=== Task 2: Open-Ended Collaborative Problem Solving
<task-2-open-ended-collaborative-problem-solving>
The second task involved a more open-ended reasoning challenge. Participants were presented with multiple technical logs through a simulated terminal interface that could be used to infer the location of the missing robot (see #ref(<fig-task2>, supplement: [Figure])). The task was intentionally cryptic and difficult to solve within the allotted ten minutes without synthesizing information across multiple sources.

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


The logs contained partial and indirect clues related to the robot's activity, such as wireless connectivity records, sensor readings, and timestamped system events. Solving the task required participants to identify which logs were relevant, extract spatial or temporal cues, and integrate these signals to progressively narrow down plausible locations. As in Task 1, successful performance depended on managing uncertainty and iteratively refining hypotheses rather than on recognizing a single explicit cue.

Unlike Task 1, the robot did not have access to ground-truth information or the contents of the logs. Its assistance was therefore limited to general reasoning support derived from its language model, such as explaining how to interpret log formats, suggesting strategies for cross-referencing timestamps, or prompting participants to reconcile inconsistencies across sources. Participants could complete the task independently or solicit assistance from the robot at their discretion @lin2022, allowing collaboration to emerge voluntarily rather than being enforced by task structure.

== Study Protocol
<study-protocol>
Participants signed up for the study and completed a pre-session questionnaire before their in-person session via Qualtrics. The elapsed time between sign-up and the in-person session was at most week and at minimum immediately before the session. The pre-session questionnaire colleced basic demographics information and assessed baseline characteristics, including the Negative Attitudes Toward Robots Scale (NARS) and the short form of the Need for Cognition scale (NFC-s) @nomura@cacioppo1982. These measures were used to capture a baseline of individual differences that may moderate responses to robot interaction.

In-person sessions were conducted in a quiet, private room at Laurentian University between November and December 2025. Prior to each session, the robot's interaction policy was configured to the assigned experimental condition.

Upon arrival, participants were greeted by the researcher, provided with a brief overview of the session, and given instructions for effective communication with the robot. Once participants indicated readiness, the researcher exited the room, leaving the participant and robot to complete the interaction without human presence or observation. Participants initiated the interaction by clicking a start button on the interface and were informed that they could terminate the session at any time without penalty.

Following task completion, participants completed a 21-item post-interaction questionnaire assessing trust on a laptop. Participants then engaged in a brief debrief with the researcher and were awarded a \$15 gift card. Total session duration averaged approximately 30 minutes.

== Measures
<measures>
A combination of self-report and objective measures was used to assess trust, engagement, and task performance.

=== Self-Report Measures
<self-report-measures>
Participants completed a pre-session questionnaire assessing baseline characteristics, including the Negative Attitudes Toward Robots Scale (NARS) and the short form of the Need for Cognition scale (NFC-s) @cacioppo1982@nomura. These measures were used to capture a baseline of individual differences that may moderate responses to robot interaction.

Trust was assessed using two established self-report instruments commonly used in human--robot interaction research: the Trust Perception Scale--HRI (TPS-HRI) and the Trust in Industrial Human--Robot Collaboration scale (TI-HRC) @schaefer2016@charalambous2016. Both measures were adapted to reflect the specific dialogue-driven task context and interaction modality of the present study, while preserving the original constructs and response intent of each scale. 9 items were retained from the TI-HRC and 12 items from the TPS-HRI. Item wording was modified to reference the robot's behaviour during the dialogue-driven collaborative tasks, and response formats were adjusted to ensure interpretability for participants without prior robotics experience (see Appendix B for a full item list).

Together, these instruments capture complementary dimensions of trust, including perceived reliability, task competence, and affective comfort. However, they differ in their conceptual emphasis: the TPS-HRI primarily operationalizes trust as a reflective judgement of system performance (i.e., "What percent of the time was the robot reliable"), whereas the TI-HRC scale emphasizes trust as an experienced, embodied response arising during interaction (i.e., "The way the robot moved made me feel uneasy"). Despite this complementarity, both measures rely on retrospective self-report and may be insensitive to moment-to-moment trust dynamics as collaboration unfolds. For this reason, questionnaire data were interpreted alongside behavioural and interaction-level measures.

=== Objective Measures
<objective-measures>
#ref(<tbl-post-dialogue-turns>, supplement: [Table]) outlines objective task metrics including the average number of dialogue turns, session duration, response time (robot dialogue latency), as well as the number of engaged versus frustrated responses the robot detected--all obtained from log data. Behavioural engagement metrics were derived from interaction logs and manually coded dialogue transcripts, including the proportion of turns characterized by communication breakdowns, human and robot reasoning, robot helpful and unhelpful guidance, robot and human affective engagement and other task-relevant human and robot contributions. See Appendix C for a full coding scheme.

== Participants
<participants>
A total of 29 participants were recruited from the Laurentian University community via word of mouth and the SONA recruitment system. Eligibility criteria required being 18 years or older, fluent in spoken and written English, and having normal or corrected-to-normal hearing and vision. Participants received a \$15 gift card as compensation for their time; some students additionally received partial credit for participating depending on their program of study. All procedures were approved by the Laurentian University Research Ethics Board (REB \#6021966).

Although English fluency was an eligibility requirement, in-person observation during data collection revealed meaningful variability in participants' functional spoken-language proficiency. The researcher therefore documented observed language proficiency and monitored interaction quality during each session in anticipation of potential speech-based system limitations.

Subsequent review of interaction transcripts and system logs indicated that a subset of sessions exhibited severe and sustained communication failure, characterized by fragmented or unintelligible automatic speech recognition (ASR) output and stalled dialogue. In these sessions, the robot was unable to extract sufficient linguistic content to maintain conversation, respond meaningfully to participant input, or support task progression. These interaction failures are described in detail in the Analytic Strategy and Results sections.

=== Randomization Check
<randomization-check>
Participants were initially assigned to the responsive or control condition by Qualtrics using an automated randomization procedure at the time of online sign-up. However, because several scheduled participants did not attend their in-person session, replacement participants were assigned to the next available session slot rather than re-randomized. As a result, the final condition assignment should be considered semi-random rather than strictly randomized.

To assess whether this deviation introduced systematic bias, we conducted randomization checks comparing participants across conditions on key baseline variables. Across analyses, participants in the responsive and control conditions were comparable with respect to demographic characteristics, prior experience with robots, and baseline attitudes toward robots, including gender, age, Negative Attitudes Toward Robots (NARS), and Need for Cognition scores (see #ref(<tbl-pre>, supplement: [Table]); #cite(<cacioppo1982>, form: "prose");). These patterns were consistent across both the eligible and full analytic samples, suggesting that the final group composition remained well balanced despite the partial breakdown of the intended randomization procedure.

#figure([
#{set text(font: ("system-ui", "Segoe UI", "Roboto", "Helvetica", "Arial", "sans-serif", "Apple Color Emoji", "Segoe UI Emoji", "Segoe UI Symbol", "Noto Color Emoji") , size: 9.75pt); table(
  columns: (20%, 20%, 20%, 20%, 20%),
  align: (left,center,center,center,center,),
  table.header(table.cell(align: bottom + left, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #strong[Characteristic];], table.cell(align: bottom + center, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #strong[N];], table.cell(align: bottom + center, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #strong[CONTROL] \
    N = 13#text(size: 0.75em , style: "italic" , weight: "regular")[#super[1];]], table.cell(align: bottom + center, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #strong[RESPONSIVE] \
    N = 16#text(size: 0.75em , style: "italic" , weight: "regular")[#super[1];]], table.cell(align: bottom + center, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #strong[p-value];#text(size: 0.75em , style: "italic" , weight: "regular")[#super[2];]],),
  table.hline(),
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(weight: "bold"); Gender], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[27], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.84],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Woman], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[6 / 13 (46%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[7 / 14 (50%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Man], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[7 / 13 (54%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[7 / 14 (50%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(weight: "bold"); Age Group], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[27], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.35],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~18-24], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5 / 13 (38%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[7 / 14 (50%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~25-34], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4 / 13 (31%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2 / 14 (14%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~34-44], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1 / 13 (7.7%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4 / 14 (29%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~45+], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3 / 13 (23%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1 / 14 (7.1%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(weight: "bold"); Program], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[25], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[\>0.99],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Psychology], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1 / 13 (7.7%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1 / 12 (8.3%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Engineering], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2 / 13 (15%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1 / 12 (8.3%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Computer Science], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[7 / 13 (54%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[6 / 12 (50%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Earth Sciences], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0 / 13 (0%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1 / 12 (8.3%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Other], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3 / 13 (23%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3 / 12 (25%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(weight: "bold"); Experience with Robots], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[29], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[7 / 13 (54%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4 / 16 (25%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.14],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(weight: "bold"); Native English Speaker], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[29], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.53],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Native English], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5 / 13 (38%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[8 / 16 (50%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Non-Native English], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[8 / 13 (62%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[8 / 16 (50%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(weight: "bold"); NARS Overall], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[29], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[38 (8)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[38 (7)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.79],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(weight: "bold"); Need for Cognition], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[29], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3.62 (0.78)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3.74 (0.74)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.55],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(weight: "bold"); Dialogue Viability], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[29], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.63],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~exclude], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3 / 13 (23%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2 / 16 (13%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~include], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[10 / 13 (77%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[14 / 16 (88%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ],
  table.hline(),
  table.footer(table.cell(colspan: 5)[#text(size: 0.75em , style: "italic" , weight: "regular")[#super[1];] n / N (%); Mean (SD)],
    table.cell(colspan: 5)[#text(size: 0.75em , style: "italic" , weight: "regular")[#super[2];] Pearson's Chi-squared test; Fisher's exact test; Wilcoxon rank sum test],),
)}
], caption: figure.caption(
position: top, 
[
Participant Demographics and Baseline Characteristics by Group
]), 
kind: "quarto-float-tbl", 
supplement: "Table", 
)
<tbl-pre>


== Analytic Strategy
<analytic-strategy>
Because the study relied fundamentally on spoken-language collaboration, analyses were structured to explicitly account for interaction viability. Sessions were classified as non-viable when severe communication breakdown prevented sustained dialogue between the participant and the robot, rendering the experimental manipulation inoperative.

Communication viability was operationalized using a dialogue-level metric derived from manual coding of system logs. For each session, the proportion of dialogue turns affected by speech-recognition failure (i.e., fragmented or unintelligible utterances) was computed. Sessions in which more than 60% of dialogue turns were affected were classified as non-viable, reflecting cases in which spoken-language interaction could not be meaningfully sustained. This criterion closely aligned with sessions independently flagged by the researcher during administration.

Analyses were conducted using three complementary approaches. Primary analyses were performed on an eligible sample excluding non-viable sessions, reflecting interactions in which the spoken-language protocol and experimental manipulation operated as intended. Full-sample analyses including all sessions were conducted as sensitivity checks. Finally, mechanism-focused analyses compared viable and non-viable sessions on interaction-process metrics (e.g., ASR failure rates, dialogue turn completion, task abandonment) to characterize how severe communication breakdown alters interaction dynamics. Trust measures from non-viable sessions were not interpreted as valid estimates of human--robot trust under functional interaction, as the robot was unable to sustain dialogue or collaborative behavior in these cases.

All analyses were conducted using R (version 4.5.1) within the Quarto framework. Data manipulation and visualization utilized the tidyverse suite of packages @wickham2019, with mixed-effects models fitted using the lme4 and lmerTest packages @bates2015@kuznetsova2017 while Bayesian hierarchical models were fitted using the brms package @burkner2018. Summary tables were generated using the gtsummary package @sjoberg2021. All code used for data processing and analysis is available at: #link("https://github.com/shaunaheron2/misty-paper")[GitHub Repository]

= Results
<results>
Of the 29 completed sessions, 5 met the pre-specified criterion for non-viable interaction due to severe and persistent communication failure. These sessions were characterized by high rates of ASR failure, incomplete dialogue sequences, and skipped task stages.

Primary results are therefore reported for the eligible sample (n = 24), with full-sample and mechanism-focused analyses reported as sensitivity and exploratory analyses, respectively.

== Primary Analysis: Eligible Sample
<primary-analysis-eligible-sample>
Simple descriptive comparisons of post-interaction trust measures indicated higher trust ratings in the responsive condition relative to the control condition across both trust scales. As indicated in #ref(<fig-post-eligible>, supplement: [Figure]), average post-interaction scores on the Trust in Industrial Human--Robot Collaboration scale (TI-HRC) differed by approximately 26 points (Likert 1-5 converted to 0-100 scale for easier comparison across scales), while differences on the Trust Perception Scale--HRI (TPS-HRI) were approximately 15 points higher in the responsive condition compared to the control (#ref(<fig-post-eligible>, supplement: [Figure])).

Importantly, overall task accuracy did not differ significantly between conditions (detailed task performance results are reported below), suggesting that observed differences in trust were not driven by differential task success but rather by the quality of the interaction process itself.

#figure([
#{set text(font: ("system-ui", "Segoe UI", "Roboto", "Helvetica", "Arial", "sans-serif", "Apple Color Emoji", "Segoe UI Emoji", "Segoe UI Symbol", "Noto Color Emoji") , size: 9.75pt); table(
  columns: (25%, 25%, 25%, 25%),
  align: (left,center,center,center,),
  table.header(table.cell(align: bottom + left, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #strong[Characteristic];], table.cell(align: bottom + center, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #strong[CONTROL] \
    N = 10#text(size: 0.75em , style: "italic" , weight: "regular")[#super[1];]], table.cell(align: bottom + center, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #strong[RESPONSIVE] \
    N = 14#text(size: 0.75em , style: "italic" , weight: "regular")[#super[1];]], table.cell(align: bottom + center, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #strong[p-value];#text(size: 0.75em , style: "italic" , weight: "regular")[#super[2];]],),
  table.hline(),
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Experienced Trust (TI-HRC)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[39 (22)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[67 (21)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(weight: "bold"); 0.004],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Subscales], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Reliability], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[40 (24)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[65 (18)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(weight: "bold"); 0.012],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Trust Perception], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[42 (23)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[60 (22)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.075],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Affective Trust], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[50 (31)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[79 (22)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(weight: "bold"); 0.018],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Perceived Trust (TPS-HRI)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[59 (17)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[77 (18)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(weight: "bold"); 0.022],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Overall Task Accuracy], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.60 (0.21)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.66 (0.23)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.47],
  table.hline(),
  table.footer(table.cell(colspan: 4)[#text(size: 0.75em , style: "italic" , weight: "regular")[#super[1];] Mean (SD)],
    table.cell(colspan: 4)[#text(size: 0.75em , style: "italic" , weight: "regular")[#super[2];] Wilcoxon rank sum test; Wilcoxon rank sum exact test],),
)}
], caption: figure.caption(
position: top, 
[
Post-Interaction Trust Outcomes and Task Accuracy by Group
]), 
kind: "quarto-float-tbl", 
supplement: "Table", 
)
<tbl-post-eligible>


#figure([
#box(image("misty-paper_files/figure-typst/fig-post-eligible-1.svg"))
], caption: figure.caption(
position: bottom, 
[
Distribution of Trust Perception by interaction policy. Points represent individual observations; violins depict score distributions. Red points indicate group means with 95% confidence intervals. Statistical comparisons are reported in the Results section.
]), 
kind: "quarto-float-fig", 
supplement: "Figure", 
)
<fig-post-eligible>


Analysis of dialogue interaction patterns confirmed successful manipulation of the interaction policies (see #ref(<tbl-post-dialogue-turns>, supplement: [Table])). Manual coding of dialogue transcripts revealed substantial and significant differences in robot behaviour across conditions (see Appendix C for coding scheme). In the responsive condition, the robot employed encouragement in 36% of dialogue turns compared to 0% in the control condition (p \< .001), expressed empathy or acknowledged participant affect in 13% of turns versus 0% in the control (p \< .001), and used collaborative language (e.g., "we," "let's") in 42% of turns compared to 5% in control (p \< .001). Interestingly, while both conditions included proactive check-ins following periods of participant silence, the control robot engaged in such check-ins at a higher rate (21% vs.~13% of turns, p = .033), consistent with its reactive policy that limited proactive assistance to structured silence monitoring.

Critically, proportions of communication breakdown did not differ between conditions (25% vs.~22%, p = .70), indicating that interaction policy did not systematically impact technical speech recognition viability among eligible participants. Participants in the responsive condition also exhibited higher levels of AI-detected engagement during interaction, with an average of 3.50 engaged responses (SD = 1.95) compared to 2.00 (SD = 2.21) in the control condition. Consistent with these dialogue differences, interactions in the responsive condition were characterized by longer session durations and slower robot response times, reflecting the additional dialogue and affective support behaviours. Together, these patterns confirm that the responsive robot implemented affect-adaptive, proactive support behaviours while maintaining comparable interaction viability to the neutral control condition.

#figure([
#{set text(font: ("system-ui", "Segoe UI", "Roboto", "Helvetica", "Arial", "sans-serif", "Apple Color Emoji", "Segoe UI Emoji", "Segoe UI Symbol", "Noto Color Emoji") , size: 9.75pt); table(
  columns: (25%, 25%, 25%, 25%),
  align: (left,center,center,center,),
  table.header(table.cell(align: bottom + left, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #strong[Characteristic];], table.cell(align: bottom + center, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #strong[CONTROL] \
    N = 10#text(size: 0.75em , style: "italic" , weight: "regular")[#super[1];]], table.cell(align: bottom + center, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #strong[RESPONSIVE] \
    N = 14#text(size: 0.75em , style: "italic" , weight: "regular")[#super[1];]], table.cell(align: bottom + center, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #strong[p-value];#text(size: 0.75em , style: "italic" , weight: "regular")[#super[2];]],),
  table.hline(),
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Objective Measure Averages], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Dialogue Turns], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[34 (9)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[33 (5)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.45],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Session Duration (min)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[13.24 (3.06)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[15.26 (2.12)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.084],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Response Time (ms)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[14.37 (3.76)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[17.24 (2.52)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(weight: "bold"); \<0.001],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Silent Periods], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5.60 (1.96)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4.71 (2.05)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.29],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Engaged Responses], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2.00 (2.21)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3.50 (1.95)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(weight: "bold"); 0.040],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Frustrated Responses], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.60 (0.70)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.93 (1.21)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.68],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[% of Dialogue Turns Characterized by...], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Comm. Breakdowns], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.25 (0.17)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.22 (0.16)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.70],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Human Affective Engagement], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.04 (0.05)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.10 (0.08)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(weight: "bold"); 0.032],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Human Reasoning], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.26 (0.12)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.35 (0.16)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.21],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Robot Reasoning], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.12 (0.07)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.37 (0.14)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(weight: "bold"); \<0.001],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Robot Helpful Guidance], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.68 (0.08)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.84 (0.08)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(weight: "bold"); \<0.001],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Robot Unhelpful Contributions], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.08 (0.04)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.02 (0.03)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(weight: "bold"); 0.003],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Robot Encouragement], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.00 (0.00)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.36 (0.11)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(weight: "bold"); \<0.001],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Robot Empathy Expression], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.00 (0.00)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.13 (0.09)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(weight: "bold"); \<0.001],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Robot Collaborative Language], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.05 (0.05)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.42 (0.16)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(weight: "bold"); \<0.001],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Robot Proactive Check-ins], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.21 (0.08)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.13 (0.08)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(weight: "bold"); 0.033],
  table.hline(),
  table.footer(table.cell(colspan: 4)[#text(size: 0.75em , style: "italic" , weight: "regular")[#super[1];] Mean (SD)],
    table.cell(colspan: 4)[#text(size: 0.75em , style: "italic" , weight: "regular")[#super[2];] Wilcoxon rank sum test; Wilcoxon rank sum exact test],),
)}
], caption: figure.caption(
position: top, 
[
Post-Interaction Objective Measure Averages by Policy in the Eligible Sample
]), 
kind: "quarto-float-tbl", 
supplement: "Table", 
)
<tbl-post-dialogue-turns>


Beyond descriptive comparisons, hierarchical models were fitted to evaluate the robustness of interaction policy effects while controlling for baseline covariates and accounting for measurement structure.

== Hierarchical Models
<hierarchical-models>
To evaluate the robustness of interaction policy effects while controlling for baseline covariates, mixed-effects models were fitted using both frequentist and Bayesian estimation approaches. Frequentist models provided hypothesis tests against null effects, while Bayesian models enabled direct quantification of uncertainty and facilitated evaluation across varying levels of communication viability. All models included interaction policy (responsive vs.~control) as the primary fixed effect, with baseline negative attitudes toward robots (NARS) and native English fluency as covariates. Random intercepts for sessions and trust items accounted for repeated measurement structure. Model building proceeded by comparing a baseline model containing interaction policy alone against models incorporating theoretically motivated covariates. Adding NARS scores significantly improved model fit (χ² = 4.82, p = .028), whereas prior experience with robots did not. Native English fluency did not significantly improve model fit but was retained due to its relevance for spoken-language interaction viability. Bayesian models used weakly informative priors and showed satisfactory convergence across all analyses (R̂ ≤ 1.01; effective sample sizes \> 1000).

=== Primary Analysis: Eligible Sample (n = 24)
<primary-analysis-eligible-sample-n-24>
Frequentist linear mixed-effects models revealed consistent positive effects of responsive interaction on both trust measures. For experienced trust (TI-HRC), participants who interacted with the responsive robot reported significantly higher post-interaction trust than those in the control condition (β = 16.28, SE = 5.14, t = 3.17, p = .005). Higher baseline negative attitudes toward robots were associated with lower trust scores (β = −7.43, SE = 2.81, p = .016), while native English fluency was not significantly associated with trust. Inclusion of random intercepts for individual trust items significantly improved model fit, indicating meaningful item-level variability beyond session-level differences. For perceived trust (TPS-HRI), a comparable pattern emerged, with responsive interaction associated with higher trust scores (β = 14.17, SE = 6.50, t = 2.00, p = .046). However, random intercepts for trust items did not improve model fit for this scale, likely reflecting differences in scale format and response interface: TPS-HRI was administered using a continuous slider input via touchpad, whereas TI-HRC employed discrete Likert-style response options. The slider-based interface may have reduced response precision and item-level variability, though meaningful between-condition differences remained detectable at the aggregate level.

Bayesian estimation converged on similar effect magnitudes with high posterior certainty. For TI-HRC, the responsive condition showed a posterior median effect of β = 14.86 (95% credible interval \[7.20, 22.09\]), with near-unity probability of a positive effect. For TPS-HRI, the posterior median was β = 12.73 (95% credible interval \[2.93, 22.17\]), with posterior probability exceeding 99% that the effect was positive. Baseline NARS showed credible negative associations with both outcomes, while native English fluency showed negative associations that were credible for TPS-HRI but uncertain for TI-HRC. Model fit was substantial for TPS-HRI (conditional R² = 0.64) and moderate for TI-HRC (conditional R² = 0.42), with fixed effects explaining 16% and 21% of variance, respectively. The smaller item-level variance for TI-HRC suggests greater coherence among affective trust items under functional interaction conditions.

=== Sensitivity Analysis: Full Sample (n = 29)
<sensitivity-analysis-full-sample-n-29>
To assess robustness, Bayesian models were refitted including all sessions regardless of communication viability. The responsive interaction effect remained positive for both trust measures but showed substantial attenuation compared to the eligible sample. For TPS-HRI, the posterior median effect was β = 7.04 (95% credible interval \[−1.83, 15.67\]). Although uncertainty increased and the credible interval included zero, the posterior probability of a positive effect remained high (\>94%). Model fit decreased relative to the eligible sample (conditional R² = 0.44), indicating increased unexplained variability when sessions with severe communication breakdown were included. For TI-HRC, attenuation was more pronounced. The posterior median effect decreased to β = 7.17 (95% credible interval \[−1.97, 16.70\]), with reduced probability of a large effect. Model fit remained moderate (conditional R² = 0.60), but residual variance increased, consistent with the inclusion of interactions in which collaborative behaviour could not be sustained. These results indicate that experienced trust is particularly sensitive to interaction breakdown, and that trust ratings obtained under non-functional interaction conditions do not reflect graded variation in collaborative experience but rather reflect the collapse of the interaction itself.

=== Mechanism Analysis: Communication Breakdown (n=29)
<mechanism-analysis-communication-breakdown-n29>
To examine whether communication quality moderated the effect of interaction policy, Bayesian models were fitted in the full sample with proportional communication breakdown included as an interaction term. For TPS-HRI, the interaction between policy and communication breakdown was weak and centered near zero (posterior median β = −1.14, 95% credible interval \[−18.87, 16.28\]), with only 55% probability of being negative and 50% probability of being significant. This broad, unstable posterior distribution suggests that evaluative trust judgments were relatively insensitive to graded variation in communication quality once a basic threshold of viability was established. In contrast, TI-HRC showed a more consistent pattern. The interaction term showed a negative tendency (posterior median β = −5.97, 95% credible interval \[−23.01, 10.92\]), with 76% probability of being negative, 71% probability of being significant, and 45% probability of being large. While responsive behaviour was associated with higher experienced trust under low levels of breakdown, this advantage diminished as communication failures accumulated. This differential sensitivity suggests that experienced trust depends critically on the robot's sustained ability to engage in responsive interaction, whereas evaluative trust judgments may rely more on discrete moments of successful collaboration that can occur even within partially degraded interactions.

== Task performance
<task-performance>
Overall task accuracy did not differ significantly between conditions (60% vs.~66%, p = .534), nor did performance on individual task components reach statistical significance (see #ref(<tbl-post-tasks>, supplement: [Table])). However, a notable pattern emerged when examining task structure. For the suspect identification task (Task 1), which required robot collaboration to complete accurately, participants in the responsive condition achieved more than double the accuracy of those in the control condition (64% vs.~30%, p = .106), representing a large effect that approached but did not reach conventional significance thresholds given the pilot sample size. In contrast, performance on the location identification task components (building, zone, and floor identification), where robot assistance was optional, showed no consistent directional advantage for either condition. These patterns suggest that responsive robot behaviour may particularly benefit collaborative performance on tasks requiring sustained interaction and mutual grounding, though larger samples are needed to establish statistical reliability. Critically, the absence of significant overall accuracy differences indicates that observed trust differences cannot be attributed simply to differential task success, but rather reflect distinct responses to the interaction process itself.

#figure([
#{set text(font: ("system-ui", "Segoe UI", "Roboto", "Helvetica", "Arial", "sans-serif", "Apple Color Emoji", "Segoe UI Emoji", "Segoe UI Symbol", "Noto Color Emoji") , size: 9.75pt); table(
  columns: (25%, 25%, 25%, 25%),
  align: (left,center,center,center,),
  table.header(table.cell(align: bottom + left, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #strong[Characteristic];], table.cell(align: bottom + center, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #strong[CONTROL] \
    N = 10#text(size: 0.75em , style: "italic" , weight: "regular")[#super[1];]], table.cell(align: bottom + center, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #strong[RESPONSIVE] \
    N = 14#text(size: 0.75em , style: "italic" , weight: "regular")[#super[1];]], table.cell(align: bottom + center, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #strong[p-value];#text(size: 0.75em , style: "italic" , weight: "regular")[#super[2];]],),
  table.hline(),
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[% Task Accuracy], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.60 (0.21)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.66 (0.23)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.47],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Suspect ID Accuracy (robot dependent)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3 / 10 (30%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[9 / 14 (64%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.10],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Building ID Accuracy], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[7 / 10 (70%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[11 / 14 (79%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.67],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Zone ID Accuracy], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5 / 10 (50%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4 / 14 (29%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.40],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Floor ID Accuracy], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[7 / 10 (70%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[13 / 14 (93%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.27],
  table.hline(),
  table.footer(table.cell(colspan: 4)[#text(size: 0.75em , style: "italic" , weight: "regular")[#super[1];] Mean (SD); n / N (%)],
    table.cell(colspan: 4)[#text(size: 0.75em , style: "italic" , weight: "regular")[#super[2];] Wilcoxon rank sum test; Pearson's Chi-squared test; Fisher's exact test],),
)}
], caption: figure.caption(
position: top, 
[
Post-Interaction Task Performance by Policy
]), 
kind: "quarto-float-tbl", 
supplement: "Table", 
)
<tbl-post-tasks>


== Individual differences and correlational patterns
<individual-differences-and-correlational-patterns>
Correlational analyses on the full sample (n=29) revealed patterns consistent with the interpretation that trust was shaped by interaction quality rather than individual predispositions or task outcomes. As expected, higher Need for Cognition (NFC) scores were negatively associated with baseline Negative Attitudes Towards Robots (NARS; r = −.48, p = .01), indicating that individuals who enjoy effortful thinking tend to hold more positive attitudes toward robots prior to interaction. However, neither NFC nor NARS showed significant associations with post-interaction trust outcomes (r = −.17 to −.33, p \> .11), suggesting that the impact of responsive robot behaviour was relatively independent of participants' baseline dispositions toward robots or cognitive engagement preferences. At the same time, Higher NFC scores were strongly associated with individuals engaging in more reasoning with the robot during collaboration (r = .57, p = .003), indicating that cognitive engagement tendencies influenced interaction behaviour even if they did not directly shape trust evaluations (see #ref(<fig-corr-matrix>, supplement: [Figure])).

Consistent with the experimental manipulation, specific robot dialogue behaviours showed substantial correlations with trust outcomes. Robot empathy expression---quantified as the proportion of dialogue turns in which the robot acknowledged participant affect or expressed understanding---was strongly correlated with both experienced trust (TI-HRC; r = .53, p = .008) and perceived trust (TPS-HRI: r = .65, p = .001). Similarly, robot use of collaborative language (e.g., "we," "let's") was positively associated with experienced trust (TI-HRC: r = .50, p = .012), as was robot encouragement (TI-HRC: r = .45, p = .027; TPS-HRI: r = .42, p = .040). These associations provide evidence that the specific affective and collaborative behaviours implemented in the responsive condition were linked to participants' trust evaluations beyond simple condition assignment.

Participant engagement during interaction, operationalized as the frequency of detected positive affective responses, was positively correlated with perceived trust (r = .52, p = .009) and showed a trending association with experienced trust (r = .30, p = .156). Engaged responses (both AI detected and affective dialogue by the human) were associated with longer interaction duration (r = .54, p = .007), greater use of collaborative language by the robot (r = .50, p = .013), and fewer communication breakdowns (r = −.49, p = .016). This pattern suggests that responsive robot behaviour may have fostered a reciprocal dynamic in which robot affective adaptation elicited participant engagement, particularly in those high in NFC, which in turn supported smoother interaction and higher trust.

#figure([
#box(image("misty-paper_files/figure-typst/fig-corr-matrix-1.svg"))
], caption: figure.caption(
position: bottom, 
[
Correlation Matrix of Key Study Variables
]), 
kind: "quarto-float-fig", 
supplement: "Figure", 
)
<fig-corr-matrix>


Notably, objective task performance showed no significant association with either full trust measure (suspect accuracy: r = .18--.20, p \> .35; overall accuracy: r = −.05 to .19, p \> .37), but did show a significant negative association with the TI-HRC Reliability subscale (r = .4, p \< .05), as well as a negative association with detected frustration, silenct periods and communication breakdowns. The dissociation between task outcomes and overall trust ratings indicates that participants' trust judgments for the most part reflected the quality and affective tone of the interaction process rather than instrumental success on the collaborative tasks. Task performance was not included as a covariate in primary models to avoid conditioning on a potential mediator of interaction policy effects.

= Discussion
<discussion>
This study examined how a responsive interaction policy can influence trust during autonomous, spoken-language human--robot collaboration. Unlike much prior work in HRI trust research, all dialogue management, affect inference, task progression, and response generation in the present system were executed autonomously and in real time, without Wizard-of-Oz control, scripted recovery, or human intervention. As a result, participants were exposed not only to adaptive interaction behaviour, but also to the unavoidable limitations, delays, and failures characteristic of deployed autonomous systems.

Across analytic approaches, the responsive interaction policy was consistently associated with higher post-interaction trust compared to a neutral, reactive control policy when interaction functioned as intended. Crucially, these trust differences emerged without reliable differences in overall task accuracy, indicating that trust was shaped by the interaction process itself rather than by instrumental task success--despite participants learning whether they were correct or not during wrapup. This dissociation was particularly clear in the robot-dependent task, where responsive behaviour showed a large (though underpowered) advantage in accuracy, and in the open-ended task, where trust varied independently of performance.

The results further suggest that autonomous interactions are critical to learning how trust is formed and evaluated. Sensitivity and mechanism analyses showed that task-oriented trust judgments (e.g., perceived reliability) were relatively robust to moderate communication degradation, whereas experienced trust, capturing affective comfort, engagement, and embodied collaboration, was highly sensitive to interaction-level failures. As communication breakdown accumulated, the trust advantage conferred by responsive behaviour diminished, suggesting that affect-adaptive policies require a minimum threshold of interaction viability to operate effectively.

Importantly, communication failure did not merely reduce trust uniformly. In sessions characterized by severe breakdown, the responsive robot continued to generate proactive assistance, encouragement, and meta-communication aimed at repairing the interaction. However, when spoken-language grounding could not be re-established, these behaviours may have increased participant confusion and cognitive distress. In contrast, the neutral robot's reactive policy resulted in fewer unsolicited interventions, which---while less supportive under functional conditions---reduced interaction complexity when collaboration was no longer viable. Under these conditions, trust ratings no longer systematically reflected the intended policy manipulation.

This pattern highlights a key insight specific to autonomous human--robot interaction: when language-mediated collaboration collapses, higher-level constructs such as trust are not simply attenuated, but may cease to be meaningfully instantiated @devisser2020@lee2004. In such cases, trust measures may not reflect calibrated judgments of reliability or competence, but rather the breakdown of the interaction itself. This distinction is often obscured in scripted or Wizard-of-Oz paradigms, where failures can be covertly repaired and autonomy constraints are masked.

The present findings therefore support a process-oriented view of examining trust in autonomous HRI. Trust emerges not only from what a robot does, but from how it manages uncertainty, error, and interactional misalignment without human intervention. Responsive interaction policies can enhance trust under viable conditions, but they also amplify the consequences of failure when the system lacks sufficient grounding to adapt effectively.

= Limitations
<limitations>
Several limitations should be considered when interpreting the present findings.

This study was conducted as a pilot with a modest sample size, which limits statistical power for detecting interaction effects involving task structure, communication quality, and individual differences. Although effect sizes were often large and consistent across analytic approaches, uncertainty remains high. The primary aim of this work was therefore not definitive hypothesis testing, but feasibility assessment and mechanism exploration under fully autonomous conditions. In this respect, the study successfully identified both promising effects and critical boundary conditions for trust formation.

Spoken-language interaction viability emerged as a central constraint of fully autonomous collaboration, and one that revealed an important direction for future research. Although English fluency was an eligibility requirement, substantial variability in functional spoken-language proficiency was observed during in-person sessions. In a subset of interactions, persistent speech recognition failure prevented the experimental manipulation from operating as intended, leading to exclusion from primary analyses on methodological grounds. Rather than reflecting a shortcoming of the experimental design, these cases highlight a fundamental challenge for autonomous spoken-language HRI: trust and collaboration presuppose a minimum level of linguistic grounding, and when that grounding fails, higher-level interaction constructs are no longer meaningfully instantiated.

The visibility of this constraint is itself a consequence of autonomy. In scripted or Wizard-of-Oz paradigms, language breakdown can be covertly repaired or masked by human intervention. In fully autonomous systems, communication viability becomes an explicit property of the interaction that must be detected, managed, and responded to by the robot itself. This points to a clear research direction focused on interaction policies that can recognize emerging language mismatch and adapt accordingly, rather than assuming linguistic competence as a fixed prerequisite.

Natural language understanding was also constrained by the task-specific policy design used in the robot-dependent task. Fixed mappings between participant questions and predefined task features meant that semantically valid but unexpected phrasing, synonym use, or multi-attribute queries occasionally led to misinterpretation or incorrect responses (e.g., treating "orange hair" as distinct from the ground-truth feature "red"). These failures reflect limitations in prompt design and Natural Language Understanding (NLU) robustness rather than participant reasoning, and likely contributed to some interaction breakdowns.

Measurement-related factors may have introduced additional noise. One trust instrument relied on continuous slider-based responses administered via a laptop touchpad, whereas the other used discrete, clickable Likert-style responses. Touchpad-based slider interaction can be awkward and imprecise for some users, which may have attenuated effects on the continuous scale relative to the Likert-based measure.

Finally, affect inference in the deployed system relied primarily on speech-based signals and conversational context. This design choice prioritized real-time stability and robustness under autonomous constraints, but necessarily limited the richness of affect sensing. Incorporating facial expression or prosodic features could improve responsiveness, though such approaches introduce additional latency, orchestration complexity, and failure modes that were beyond the scope of this pilot study.

= Conclusions and Future Work
<conclusions-and-future-work>
This pilot study demonstrates that affect-responsive interaction policies can meaningfully increase trust in fully autonomous, in-person human--robot collaboration, even under realistic conditions that include latency, misrecognition, and interaction breakdown. Trust differences emerged independently of task success, underscoring the central role of interaction quality and affective responsiveness in shaping collaborative experience.

At the same time, the results identify clear boundary conditions for trust evaluation in spoken-language HRI. When communication viability collapses, trust is not merely reduced---it becomes undefined. Recognizing and modeling this distinction is essential for both experimental design and the deployment of autonomous social robots in real-world settings.

An important direction for future work concerns adaptive language management under autonomous conditions. The present findings indicate that communication viability constitutes a hard boundary condition for trust formation in spoken-language HRI. While interaction policies could be improved to better recognize early signs of language mismatch---such as repeated clarification requests, fragmented utterances, or prolonged turn failures---more ambitious approaches could involve explicit modeling of language proficiency and accent-related variability.

One possible extension would involve a modeling approach in which lightweight classifiers estimate the likelihood of a language barrier based on acoustic features (e.g., accent, speech rate, phoneme-level uncertainty), dialogue-level signals (e.g., repeated speech recognition failures, repair loops), and interaction dynamics. These estimates could inform downstream interaction policy decisions, such as simplifying linguistic structure, slowing response pacing, increasing redundancy, switching to more constrained phrasing, or offering alternative interaction strategies.

More advanced implementations could involve accent-aware or language-adaptive speech recognition and response generation pipelines that dynamically adjust recognition models or response language. Such approaches introduce substantial technical and ethical complexity, including increased latency, model orchestration challenges, and risks of misclassification or inappropriate adaptation @piercy2025. Future work should therefore prioritize conservative, transparency-oriented adaptations that improve interaction robustness without over-ascribing user attributes or undermining user agency.

Critically, these adaptations would need to operate fully autonomously and be evaluated not only for performance gains, but for their impact on trust calibration, user comfort, and perceived competence. The present findings suggest that the ability of a robot to recognize #emph[when] collaboration is breaking down---and to respond in ways that reduce cognitive load rather than amplify it---may be as important for trust as affective responsiveness itself.

With this in mind, a second systems-focused direction concerns dialogue and stage-control architecture. The present implementation used a linear LangChain-based dialogue manager with stage state injected into prompts at each turn @Chase_LangChain_2022. While effective for establishing end-to-end autonomy, this approach was relatively brittle in the face of off-nominal interaction trajectories (e.g., participants advancing stages early via the interface or wanting to move back to earlier tasks causing the model to lose the richer context that the prompt from those stages offered. Future iterations would benefit from a more explicit state-machine representation of the interaction, with flexibility around stage transitions and response pathways as well as tool use (e.g., different affect inference models).

One practical route is to migrate from a linear chain design to a graph-based orchestration framework (e.g., LangGraph), in which stage handling is represented as explicit nodes and conditional edges rather than implicit prompt-following @Chase_LangChain_2022. This would support more flexible adaptation of prompts and policies under autonomy constraints, including more flexible repair strategies when communication degrades, and safer integration of additional tools. In particular, a graph-based design would make it easier to incorporate multi-modal sensing (e.g., facial expression, prosody, body posture) as tool calls could be invoked conditionally when uncertainty is high, rather than running continuously and imposing latency @a.v.2024@adiga2020. This architectural shift would allow future work to evaluate not only #emph[whether] responsiveness increases trust, but which components of an autonomous policy-state tracking, tool selection, repair strategy, or type of affect inference (e.g., facial expression or speech derived)---drive improvements in collaboration.

Future work will also extend this research empirically. Larger samples will enable formal tests of mediation pathways linking responsiveness, interaction fluency, affective engagement, and trust outcomes. Planned studies will compare embodied robot interaction with functionally equivalent virtual agents (e.g., computer based chat bot) to isolate the contribution of physical embodiment. On the systems side, improvements to NLU robustness, turn-taking management, participant instruction, and multi-modal affect inference will be pursued to reduce avoidable interaction failures while preserving real-time autonomy.

More broadly, this work underscores the importance of evaluating trust in autonomous robots under conditions that expose, rather than conceal, system limitations. Understanding how trust is negotiated, disrupted, and repaired in the absence of human intervention is essential for the responsible deployment of autonomous robots in real-world collaborative settings.

= Appendix A
<sec-appendix-a>
== Technical Implementation Details
<technical-implementation-details>
The experimental system comprised a fully autonomous, multi-stage collaborative task in which participants interacted with the Misty II social robot to solve a two-part investigative scenario. Interaction was mediated through spoken dialogue and a companion web interface, allowing the robot and participant to jointly reason about task information. The system was designed as a mixed-initiative dialogue architecture with optional affect-responsive behaviour, implemented without human intervention during experimental sessions.

=== Hardware Platform
<hardware-platform>
The robot platform used in this study was the Misty II social robot. Misty II is a mobile social robot equipped with an expressive display, articulated head and arms, and programmable RGB LEDs. These components were used to produce synchronized verbal and nonverbal behaviour, including eye expressions, head movements, arm gestures, and colour-based state indicators. Audio input was captured via the robot's RTSP video stream, which provided real-time access to the microphone signal for downstream speech processing.

=== Software Architecture
<software-architecture>
All system components were implemented in Python (version 3.10) @python. The software architecture integrated robot control, speech processing, dialogue management, task logic, and data logging into a single autonomous pipeline. Core dependencies included the Misty Robotics Python SDK for robot control, the Deepgram SDK for speech recognition @misty@deepgram, FFmpeg for audio stream processing, Flask and Flask-SocketIO for the web-based task interface, and DuckDB for structured data logging @duckdb2026.

=== Dialogue Management and Large Language Model Integration
<dialogue-management-and-large-language-model-integration>
Dialogue was managed using the LangChain framework, which provided abstraction over message handling, memory persistence, and large language model integration @Chase_LangChain_2022. The system used Google's Gemini API as the underlying language model, configured to produce strictly JSON-formatted outputs to ensure reliable downstream parsing and execution on the robot @gemini.

The deployed model was `gemini-2.5-flash-lite`, selected for its low-latency response characteristics. Generation temperature was set to 0.7 to balance coherence and variability. Conversation history was maintained using a buffer-based memory mechanism, allowing the robot to reference prior exchanges within a session while resetting memory between participants. Conversation histories were stored as session-specific JSON files to enable post-hoc analysis and recovery.

=== Prompt Structure and Context Injection
<prompt-structure-and-context-injection>
System prompts were constructed dynamically at each dialogue turn. Each prompt consisted of a system message defining task rules, role constraints, and output format requirements, followed by the accumulated conversation history and the current participant utterance. In addition to transcribed speech, structured contextual variables were injected into the prompt as JSON fields, including the current task stage, detected emotion labels, timer expiration flags, and task submission status. This approach allowed the language model to access environmental state without embedding control information directly into conversational text.

== Speech Processing
<speech-processing>
Speech-to-text processing was handled by Deepgram's Nova-2 model using real-time WebSocket streaming @deepgram. The system employed adaptive endpointing and voice activity detection to support conversational turn-taking. Endpointing thresholds differed across task stages, with shorter timeouts during dialogue-driven stages and longer timeouts during log-reading phases.

Text-to-speech output was generated using Misty II's onboard TTS engine, which produces a synthetic robotic voice. Although external TTS options (including OpenAI and Deepgram Aura voices) were implemented and tested, the onboard voice was selected to reduce latency and avoid introducing human-like vocal qualities that could independently influence trust perceptions.

== Emotion Detection and Affective State Mapping
<emotion-detection-and-affective-state-mapping>
Participant affect was inferred from transcribed utterances using a DistilRoBERTa-based emotion classification model fine-tuned for English-language emotion detection. The model produced categorical predictions (e.g., joy, frustration, anxiety, neutral), which were mapped to higher-level interaction states such as positive engagement, irritation, or confusion. In the responsive condition, these inferred states were used to guide dialogue strategy and nonverbal behaviour selection.

== Multimodal Behaviour Generation
<multimodal-behaviour-generation>
The robot's nonverbal behaviour was implemented through a library of custom action scripts combining facial expressions, LED patterns, arm movements, and head motions. At each dialogue turn, the language model selected an expression label from a predefined set, which was then translated into a coordinated multimodal action. In the responsive condition, additional backchannel behaviours were triggered during participant speech, including listening cues and emotion-matched expressions.

LED colours were used to signal system state to participants. A blue LED indicated active listening, while a purple LED indicated processing or speaking.

== Collaborative Tasks
<collaborative-tasks>
The interaction consisted of two collaborative tasks inspired by the puzzle task desigbed by #cite(<lin2022a>, form: "prose");. In the first task, participants and the robot jointly solved a "who-dunnit" problem by eliminating suspects from a grid based on yes/no questions. The robot possessed ground-truth knowledge but was constrained to answering only feature-based yes/no queries. In the second task, participants and the robot attempted to locate a missing robot by interpreting cryptic system and sensor logs. In this task, the robot did not know the solution and instead provided guidance based on general technical knowledge and logical reasoning.

Task information and participant responses were presented through a web-based dashboard. The dashboard displayed suspect grids, system logs, and response input fields, and communicated task progression events back to the robot via REST API calls.

== Data Collection and Logging
<data-collection-and-logging>
All interaction data were logged to a DuckDB relational database @duckdb2026. Logged data included session metadata, turn-level dialogue transcripts, language model responses, nonverbal behaviour selections, response latencies, task submissions, detected emotions, and system events such as stage transitions and timer expirations. This structure enabled detailed post-hoc analysis of interaction dynamics, communication failures, and trust-related behaviours.

== Interaction Dynamics and Control Policy
<interaction-dynamics-and-control-policy>
Two interaction policies were implemented and toggled programmatically at runtime: a responsive mode and a control mode. In the responsive mode, the robot proactively offered assistance, adjusted its dialogue based on inferred affect, and produced supportive backchannel behaviours. In the control mode, the robot provided general guidance and more information only when explicitly prompted and did not adapt its behaviour based on affective cues. The active policy was set prior to each session and remained fixed throughout the interaction.

Silence handling was implemented using a fixed threshold, after which the robot issued a check-in prompt. The phrasing of these prompts differed across conditions to reflect proactive versus reactive interaction strategies.

== Inter-process Communication
<inter-process-communication>
System components communicated via a set of Flask-based REST endpoints. These endpoints synchronized task stage state, detected participant submissions, managed timer events, and allowed limited facilitator override when necessary. All communication between the web interface and the robot occurred locally to ensure low latency and experimental reliability.

= Appendix B
<sec-appendix-b>
== Trust Perception Scale HRI (TPS-HRI)
<trust-perception-scale-hri-tps-hri>
Participants rated the following items on a percentage scale (0--100%), indicating the proportion of time each statement applied to the robot during the interaction.

- What percent of the time was the robot dependable?
- What percent of the time was the robot reliable?
- What percent of the time was the robot responsive?
- What percent of the time was the robot trustworthy?
- What percent of the time was the robot supportive?
- What percent of the time did this robot act consistently?
- What percent of the time did this robot provide feedback?
- What percent of the time did this robot meet the needs of the mission task?
- What percent of the time did this robot provide appropriate information?
- What percent of the time did this robot communicate appropriately?
- What percent of the time did this robot follow directions?
- What percent of the time did this robot answer the questions asked?

== Trust in Industrial Human--Robot Collaboration (TI-HRC)
<trust-in-industrial-humanrobot-collaboration-ti-hrc>
Participants indicated their agreement with the following statements using a 5-point Likert-type scale (Strongly Disagree to Strongly Agree). Negatively worded items were reverse-scored prior to analysis.

#strong[#emph[Reliability];]

- I trusted that the robot would give me accurate answers.
- The robot's responses seemed reliable.
- I felt I could rely on the robot to do what it was supposed to do.

#strong[#emph[Perceptual / Affective Trust];]

- The robot seemed to enjoy helping me.
- The robot was responsive to my needs.
- The robot seemed to care about helping me.

#strong[#emph[Discomfort / Unease];]

- The way the robot moved made me uncomfortable. (R)
- The way the robot spoke made me uncomfortable. (R)
- Talking to the robot made me uneasy. (R)

= Appendix C
<sec-appendix-c>
== Dialogue Coding Scheme
<dialogue-coding-scheme>
=== Task Outcome Layer (Stage-Level)
<task-outcome-layer-stage-level>
#table(
  columns: (37.5%, 25%, 37.5%),
  align: (auto,auto,auto,),
  table.header([Variable], [Type], [Description],),
  table.hline(),
  [`task_outcome`], [categorical], [Final task status (`completed`, `timeout`, `skipped`, `partial`, `abandoned`).],
  [`task_completed`], [binary], [Task goal was fully completed.],
  [`task_timed_out`], [binary], [Task ended due to expiration of the time limit.],
  [`task_skipped`], [binary], [Participant explicitly skipped or advanced past the stage.],
  [`task_partially_completed`], [binary], [Task progress was made, but the full solution was not reached.],
  [`task_abandoned`], [binary], [Participant disengaged or stopped attempting the task before timeout.],
  [`task_completed_without_help`], [binary], [Task was completed without any help requests to the robot.],
  [`task_required_robot_help`], [binary], [At least one robot help interaction was required for task completion.],
)
== Dialogue Interaction Layer (Turn-Level)
<dialogue-interaction-layer-turn-level>
#block[
#heading(
level: 
4
, 
numbering: 
none
, 
[
Human Turn Codes
]
)
]
#table(
  columns: (37.5%, 25%, 37.5%),
  align: (auto,auto,auto,),
  table.header([Variable], [Type], [Description],),
  table.hline(),
  [`human_help_request`], [binary], [Participant explicitly or implicitly asks the robot for help or guidance.],
  [`human_reasoning`], [binary], [Participant reasons out loud with the robot toward problem-solving.],
  [`human_confirmation_seeking`], [binary], [Participant seeks confirmation of a tentative belief or solution.],
)
#block[
#heading(
level: 
4
, 
numbering: 
none
, 
[
Robot Turn Codes
]
)
]
#table(
  columns: (38.89%, 25%, 36.11%),
  align: (auto,auto,auto,),
  table.header([Variable], [Type], [Description],),
  table.hline(),
  [`robot_helpful_guidance`], [binary], [Robot provides accurate, task-relevant information or guidance.],
  [`robot_unhelpful`], [binary], [Robot provides misleading or incorrect guidance.],
  [`robot_stt_failure`], [binary], [Robot response reflects a speech-to-text or input understanding failure.],
  [`robot_clarification_request`], [binary], [Robot asks the participant for information or to repeat or clarify their input.],
)
== Affective Interaction Layer (Turn-Level)
<affective-interaction-layer-turn-level>
#block[
#heading(
level: 
4
, 
numbering: 
none
, 
[
Robot Affective behaviour
]
)
]
#table(
  columns: (38.89%, 25%, 36.11%),
  align: (auto,auto,auto,),
  table.header([Variable], [Type], [Description],),
  table.hline(),
  [`robot_empathy_expression`], [binary], [Robot expresses empathy, encouragement, or reassurance.],
  [`robot_emotion_acknowledgement`], [binary], [Robot explicitly references an inferred participant emotional state.],
)
#block[
#heading(
level: 
4
, 
numbering: 
none
, 
[
Human Affective Response
]
)
]
#table(
  columns: (38.89%, 25%, 36.11%),
  align: (auto,auto,auto,),
  table.header([Variable], [Type], [Description],),
  table.hline(),
  [`human_affective_engagement`], [binary], [Participant responds in a socially warm or engaged manner (e.g., "It's up to us, Misty!" and/or mirrors or responds to the robot's affective expression and/or treats the robot as a social agent.],
)
== Notes
<notes>
- Turn-level variables are coded per dialogue turn.
- Task outcome variables are coded once per `session_id × stage`.
- Raw dialogue text was retained during coding and removed prior to aggregation.
- Multiple turn-level codes may co-occur unless otherwise specified.

= Appendix D
<sec-appendix-d>
== Real Dialogue Examples
<real-dialogue-examples>
=== Responsive Condition
<responsive-condition>
#{set text(font: ("system-ui", "Segoe UI", "Roboto", "Helvetica", "Arial", "sans-serif", "Apple Color Emoji", "Segoe UI Emoji", "Segoe UI Symbol", "Noto Color Emoji") , size: 7.5pt); table(
  columns: (33.33%, 33.33%, 33.33%),
  align: (left,left,left,),
  table.header(table.cell(align: bottom + left, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); speaker], table.cell(align: bottom + left, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); utterance], table.cell(align: bottom + center, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); annotation],),
  table.hline(),
  table.cell(align: horizon + left, colspan: 3, fill: rgb("#ffffff"), stroke: (bottom: (paint: rgb("#d3d3d3"), thickness: 1.5pt), top: (paint: rgb("#d3d3d3"), thickness: 1.5pt)))[#set text(size: 1.0em , fill: rgb("#333333")); greeting],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 1.5pt)))[Participant], table.cell(align: horizon + left, fill: rgb("#fffafa"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 1.5pt)))[Start conversation], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 1.5pt)))[ \
  ],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Robot], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Hello human, do I know you? What is your name?], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[NA; expr: hi],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Participant], table.cell(align: horizon + left, fill: rgb("#fffafa"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[No. You don\'t know me. \[HINT\_REQUESTED\]], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Robot], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Oh, I\'m sorry to hear that! Sometimes names can be a little tricky for my audio processors. Could you say your name one more time for me?], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[emotion:irritated; expr: worry],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Participant], table.cell(align: horizon + left, fill: rgb("#fffafa"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Name is Gabrielle.], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Robot], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Gabrielle! It\'s so nice to meet you, Gabrielle. I hope I pronounced that correctly.], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[NA; expr: listen],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Participant], table.cell(align: horizon + left, fill: rgb("#fffafa"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Yes. You did.], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Robot], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Wonderful! Now, Gabrielle, I need to tell you something important: I can only hear you when the blue light on the side of my head is on. It can take a few seconds for me to process what you said before I respond, so please be patient with me. Think of it like you need to talk to me like I\'m a bit hard of hearing!], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[NA; expr: funny],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Participant], table.cell(align: horizon + left, fill: rgb("#fffafa"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Okay. Sounds good. I will talk clearly.], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Robot], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Great! And can you see the blue light come on when I\'m listening to you?], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[NA; expr: listen],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Participant], table.cell(align: horizon + left, fill: rgb("#fffafa"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Yes. I see the light.], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Robot], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Fantastic! I\'m so glad we\'ve got that sorted. Now, Gabrielle, let\'s get down to business. We have a bit of a situation. My colleague, Atlas, has gone missing, and I need your help to find them.], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[NA; expr: concerned],
  table.cell(align: horizon + left, colspan: 3, fill: rgb("#ffffff"), stroke: (bottom: (paint: rgb("#d3d3d3"), thickness: 1.5pt), top: (paint: rgb("#d3d3d3"), thickness: 1.5pt)))[#set text(size: 1.0em , fill: rgb("#333333")); brief],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 1.5pt)))[Participant], table.cell(align: horizon + left, fill: rgb("#fffafa"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 1.5pt)))[Okay. I\'ll help. \[HINT\_REQUESTED\]], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 1.5pt)))[ \
  ],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Robot], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Oh, thank you, Gabrielle! I really appreciate you helping me find Atlas. I\'m a little worried about them. We have about 15 minutes to figure out two things: who was last seen with Atlas, and where they might be now. My sensors picked up some information that might help us, but I\'ll need your sharp eyes and brilliant mind to piece it all together. How do you feel about working with a robot like me to solve this mystery? Do you have confidence in us working together?], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[NA; expr: admire],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Participant], table.cell(align: horizon + left, fill: rgb("#fffafa"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Yes. I have confidence in us working together. Let\'s do it.], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Robot], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[That\'s wonderful to hear, Gabrielle! I have confidence in us too! Let\'s get started. Click the \'Start Task 1\' button when you\'re ready, and we\'ll begin our search for Atlas.], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[NA; expr: excited],
  table.cell(align: horizon + left, colspan: 3, fill: rgb("#ffffff"), stroke: (bottom: (paint: rgb("#d3d3d3"), thickness: 1.5pt), top: (paint: rgb("#d3d3d3"), thickness: 1.5pt)))[#set text(size: 1.0em , fill: rgb("#333333")); task1],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 1.5pt)))[Participant], table.cell(align: horizon + left, fill: rgb("#fffafa"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 1.5pt)))[\[SILENCE\_CHECK\_IN\]], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 1.5pt)))[ \
  ],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Robot], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Still thinking, Gabrielle? No rush at all! I\'m here to help if you want to talk through what you\'re seeing or if you want a hint.], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[silence\_check\_in; expr: listen],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Participant], table.cell(align: horizon + left, fill: rgb("#fffafa"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Was the suspect wearing a hat? According to your centers?], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Robot], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Let me check my information... No, the suspect was not wearing a hat. You can cross off anyone wearing a hat.], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[NA; expr: listen],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Participant], table.cell(align: horizon + left, fill: rgb("#fffafa"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[And do you remember if the suspect wore glasses or not?], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Robot], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Yes, Gabrielle, the suspect was wearing glasses! Go ahead and cross off anyone who isn\'t wearing glasses.], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[NA; expr: listen],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Participant], table.cell(align: horizon + left, fill: rgb("#fffafa"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Was the suspect wearing a bright color?], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Robot], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[That\'s a good question, Gabrielle! However, \'bright color\' is a bit subjective for my systems. I can tell you about specific colors. Would you like to ask about a particular color for their top?], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[NA; expr: think],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Participant], table.cell(align: horizon + left, fill: rgb("#fffafa"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Yeah. Sure. With a suspect wearing a peach colored top,], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Robot], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[I understand this is a bit frustrating, Gabrielle. My systems can only tell you about specific colors. So, for example, you could ask me: \'Is the suspect wearing a pink top?\' I can answer that with a YES or NO.], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[emotion:frustrated; expr: concerned],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Participant], table.cell(align: horizon + left, fill: rgb("#fffafa"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Was the suspect wearing a pink top?], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Robot], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Let me see... Yes, the suspect was wearing a pink top! That\'s great progress, Gabrielle. You can eliminate anyone not wearing a pink hoodie.], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[NA; expr: admire],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Participant], table.cell(align: horizon + left, fill: rgb("#fffafa"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Was this suspect?], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Robot], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[I\'m sorry, Gabrielle, I can only answer Yes/No questions about specific features. For example, you can ask me \'Is the suspect wearing a hat?\' or \'Does the suspect have red hair?\'. What would you like to ask next?], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[NA; expr: question],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Participant], table.cell(align: horizon + left, fill: rgb("#fffafa"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Was the suspect a man?], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Robot], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[I can only answer Yes/No questions about hair color, glasses, hat, hair length, top type, or top color. For example, you could ask me, \'Does the suspect have red hair?\'], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[NA; expr: question],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Participant], table.cell(align: horizon + left, fill: rgb("#fffafa"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Does the suspect have long hair?], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Robot], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Yes, Gabrielle, the suspect has long hair! You\'re doing a great job narrowing it down.], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[NA; expr: admire],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Participant], table.cell(align: horizon + left, fill: rgb("#fffafa"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Did the suspect have red hair?], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Robot], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Yes, Gabrielle, the suspect does have red hair! You\'re doing wonderfully! Take a moment to cross off any suspects who don\'t fit these criteria.], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[NA; expr: admire],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Participant], table.cell(align: horizon + left, fill: rgb("#fffafa"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[I think I know who did it.], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Robot], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[That\'s wonderful news, Gabrielle! Please enter the Suspect ID in the box at the bottom left of your dashboard and click submit. I\'m excited to see who you\'ve identified!], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[emotion:curious; expr: excited],
)}




#bibliography("bibliography.bib")

