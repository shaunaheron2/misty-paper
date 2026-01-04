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


// This function gets your whole document as its `body` and formats
// it as an article in the style of the IEEE.

#let ieee(
  // The paper's title.
  title: "Paper Title",

  // An array of authors. For each author you can specify a name,
  // department, organization, location, and email. Everything but
  // but the name is optional.
  authors: (),
  review-mode: false,
  // The paper's abstract. Can be omitted if you don't have one.
  abstract: none,

  // A list of index terms to display after the abstract.
  index-terms: (),

  // The article's paper size. Also affects the margins.
  paper-size: "us-letter",

  // The path to a bibliography file if you want to cite some external
  // works.
  bibliography-file: none,

  // The paper's content.
  body
) = {
  // Set document metadata.
  set document(title: title, author: authors.map(author => author.name))

  // Set the body font.
  set text(font: "STIX Two Text", size: 10pt)

  // Configure the page.
  set page(
    paper: paper-size,
    // The margins depend on the paper size.
    margin: if paper-size == "a4" {
      (x: 41.5pt, top: 80.51pt, bottom: 89.51pt)
    } else {
      (
        x: (50pt / 216mm) * 100%,
        top: (55pt / 279mm) * 100%,
        bottom: (64pt / 279mm) * 100%,
      )
    }
  )

  // Configure equation numbering and spacing.
  set math.equation(numbering: "(1)")
  show math.equation: set par(spacing: 0.65em)

  // Configure lists.
  set enum(indent: 10pt, body-indent: 9pt)
  set list(indent: 10pt, body-indent: 9pt)

  // Configure headings.
set heading(numbering: "I.A.1.")
show heading: it => {
  // We're already in the heading's context here.
  let levels = counter(heading).get()
  let deepest = if levels != () { levels.last() } else { 1 }

  set text(10pt, weight: 400)

  if it.level == 1 [
    // First-level headings are centered smallcaps.
    // We don't want to number the acknowledgment section.
    #let is-ack = it.body in ([Acknowledgment], [Acknowledgement])
    #set align(center)
    #set text(if is-ack { 10pt } else { 12pt })
    #show: smallcaps
    #v(20pt, weak: true)
    #if it.numbering != none and not is-ack {
      numbering("I.", deepest)
      h(7pt, weak: true)
    }
    #it.body
    #v(13.75pt, weak: true)

  ] else if it.level == 2 [
    // Second-level headings are run-ins.
    #set par(first-line-indent: 0pt)
    #set text(style: "italic")
    #v(10pt, weak: true)
    #if it.numbering != none {
      numbering("A.", deepest)
      h(7pt, weak: true)
    }
    #it.body
    #v(10pt, weak: true)

  ] else [
    // Third level headings are run-ins too, but different.
    #if it.level == 3 {
      numbering("1)", deepest)
      [ ]
    }
    _#(it.body):_
  ]
}


  // Display the paper's title.
  v(3pt, weak: true)
  align(center, text(18pt, title))
  v(8.35mm, weak: true)

  // Display the authors list.
  for i in range(calc.ceil(authors.len() / 3)) {
    let end = calc.min((i + 1) * 3, authors.len())
    let is-last = authors.len() == end
    let slice = authors.slice(i * 3, end)
    grid(
      columns: slice.len() * (1fr,),
      gutter: 12pt,
      ..slice.map(author => align(center, {
        text(12pt, author.name)
        if "department" in author [
          \ #emph(author.department)
        ]
        if "organization" in author [
          \ #emph(author.organization)
        ]
        if "location" in author [
          \ #author.location
        ]
        if "email" in author [
          \ #link("mailto:" + author.email)
        ]
      }))
    )

    if not is-last {
      v(16pt, weak: true)
    }
  }
  v(40pt, weak: true)

  // Start two column mode and configure paragraph properties.
  //if not review-mode {
  show: columns.with(2, gutter: 12pt)

  //}
  set par(justify: true, first-line-indent: 2em)
  show par: set  par(spacing: 0.65em)

  // Display abstract and index terms.
  if abstract != none [
    #set text(weight: 700)
    #h(1em) _Abstract_---#abstract

    #if index-terms != () [
      #h(1em)_Index terms_---#index-terms.join(", ")
    ]
    #v(2pt)
  ]

  // Display the paper's contents.
  body

  // Display bibliography.
  if bibliography-file != none {
    show bibliography: set text(8pt)
    bibliography(bibliography-file, title: text(10pt)[References], style: "ieee")
  }
}
#import "@preview/fontawesome:0.5.0": *

#set page(
  paper: "us-letter",
  margin: (x: 1.25in, y: 1.25in),
  numbering: "1",
)

#show: ieee.with(
  title: "Responsive Robotics to Increase Trust in Autonomous Human--Robot Interaction",
  abstract: [This study implements a multi-stage collaborative task system where participants collaborate with the Misty-II social robot to solve a who-dunnit type task. The system utilizes an autonomous, mixed-initiative dialogue architecture with affect-responsive capabilities.

],
authors: (
    (
    name: "M.C. Lau",
        department: [Bharti School of Engineering],
    organization: [],
    location: [, ],
        email: "mclau\@laurentian.ca"
  ),
    (
    name: "Shauna Heron",
        department: [School of Social Sciences],
    organization: [],
    location: [, ],
        email: "sheron\@laurentian.ca"
  )),
  index-terms: ("human-robot collaboration", "HRI", "HRC", "socially assistive robotics", "cobots", "autonomous robot systems", "spoken language interaction", "trust in automation", "trust in human-robot interaction", "affect-adaptive systems"),
)


= Introduction
<introduction>
As automation expands across safety-critical domains such as manufacturing, mining, and healthcare, robotic systems are increasingly expected to operate alongside humans rather than in isolation @fu2021@ciuffreda2025@diab2025@spitale2023. In these collaborative settings, successful deployment depends not only on technical performance and safety guarantees, but on whether human users are willing to rely on, communicate with, and coordinate their actions around systems driven by artificial intelligence (AI) @campagna2025@emaminejad2022. Trust has therefore emerged as a central determinant of adoption and effective use in human--robot collaboration (HRC) @wischnewski2023@campagna2025. Insufficient trust can lead to disuse or rejection of automation, while excessive trust risks overreliance---particularly in environments characterized by uncertainty or incomplete information @devisser2020.

A substantial body of human--robot interaction (HRI) research has examined how robot behaviour shapes user trust, perceived reliability, and cooperation across industrial and social contexts @shayganfar2019@fartook2025. Trust is commonly conceptualized as a multidimensional construct encompassing cognitive evaluations of competence and reliability, affective responses to the interaction partner, and behavioural willingness to rely on the system under conditions of risk or uncertainty @muir1994@hancock2011@devisser2020. Despite this multidimensional framing, empirical studies have predominantly operationalized trust using post-interaction self-report questionnaires, often collected following short, highly controlled interactions.

Importantly, much of the existing HRI trust literature relies on scripted behaviours, simulated environments, or Wizard-of-Oz paradigms in which a human operator covertly manages the robot's behaviour. While these approaches are valuable for isolating specific design factors, they obscure the interaction breakdowns and system imperfections that characterize real-world autonomous robots @campagna2025. In deployed systems, limitations such as speech recognition errors, delayed responses, misinterpretations of user intent, and incomplete affect sensing are not peripheral issues but defining features of interaction. These failures are likely to play a decisive role in shaping trust and collaboration, yet remain underrepresented in empirical evaluations.

One proposed mechanism for supporting trust in HRI is responsiveness: the extent to which a robot adapts its behaviour based on user state and interaction context @shayganfar2019@fartook2025. Responsive robots may adjust dialogue, timing, or support strategies in response to inferred cues such as confusion, frustration, or disengagement, and prior work suggests that such adaptive behaviour can enhance perceived social intelligence and trustworthiness in dialogue-driven tasks @birnbaum2016. However, most evidence for these effects comes from simulated or semi-autonomous systems, leaving open questions about how responsiveness operates when implemented in fully autonomous, in-person interactions subject to real-time constraints and failure @campagna2025.

From an engineering perspective, responsiveness represents an interaction policy rather than a superficial social cue @shayganfar2019. Proactive assistance based on interaction context differs fundamentally from reactive, request-based behaviour, particularly in fully autonomous systems---for example, offering clarification or encouragement when confusion or hesitation is inferred, rather than waiting for an explicit request for help @birnbaum2016. Implementing such policies requires robots to manage spoken-language dialogue, track interaction state over time, and coordinate verbal and nonverbal responses in real time, all while operating under noise, latency, and sensing uncertainty @campagna2025.

The present work addresses these gaps through a pilot study examining trust and collaboration during in-person interaction with a fully autonomous social robot. Participants collaborated with one of two versions of the same robot platform during a dialogue-driven puzzle task requiring shared problem solving. In both conditions, all interaction management---including speech recognition, dialogue state tracking, task progression, and response generation---was handled and logged autonomously by the robot without human intervention. In the responsive condition, the robot employed a proactive interaction policy, adapting its assistance based on conversational cues and inferred user affect. In the neutral condition, the robot followed a reactive policy, providing general guidance but assistance only when explicitly requested.

This pilot study had three primary objectives: (1) to design and evaluate the feasibility of an autonomous spoken-language interaction system with affect-responsive behaviour on a mobile robot platform; (2) to assess whether interaction policy influences post-interaction trust and collaborative experience under realistic autonomous conditions; and (3) to explore how behavioural and interaction-level indicators align with subjective trust evaluations. Rather than optimizing for flawless interaction, the system was intentionally designed to reflect the capabilities and limitations of contemporary social robots, allowing interaction breakdowns to surface naturally.

By combining post-interaction trust measures with task-level and behavioural observations, this study aims to contribute empirical evidence on how trust in human--robot collaboration emerges and is enacted during fully autonomous interaction. The findings are intended to inform the design of a larger subsequent study by evaluating feasibility and identifying technical, interactional, and methodological challenges that must be addressed when evaluating affect-responsive robots in real-world contexts.

= Methods
<methods>
This study employed a between-subjects experimental design to examine how robot interaction policy influences trust and collaboration during fully autonomous, in-person human--robot interaction. The sole experimental factor was the robot's interaction policy, with participants randomly assigned to interact with either a responsive or neutral version of the same robot system.

#block[
#callout(
body: 
[
Throughout this paper, references to "the robot" denote the fully autonomous interactive system comprising the Misty-II hardware platform and its onboard software stack, with all interaction decisions generated without human intervention, including spoken-language processing, dialogue management, and the interaction policy governing verbal and nonverbal behaviour. Additional details of the system architecture are provided in Appendix A.

]
, 
title: 
[
Important
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
== Interaction Policies
<interaction-policies>
In the responsive policy condition, the robot employed a proactive, affect-adaptive interaction policy. Robot responses were modulated based on inferred participant affect, dialogue context, and task demands, resulting in unsolicited encouragement, clarification, and engagement-oriented behaviours when appropriate. For example, if the participant exhibited signs of confusion or hesitation (e.g., long pauses, requests for repetition or detected irritation), the robot would proactively offer hints or rephrase instructions. Similarly, if the participant demonstrated engagement (e.g., rapid responses, affirmative feedback), the robot would reciprocate with positive reinforcement and increased task involvement.

In the neutral or control policy condition, the robot employed a neutral, reactive interaction policy. General information and guidance were were provided to move the participant through the tasks, but additional help was only provided when explicitly requested by the participant and without affect-based adaptation or proactive support beyond a check-in when participant was silent for more than 1 minute. For example, if the participant appeared confused but did not request assistance, the robot would not intervene. The robot's verbal and nonverbal behaviours were designed to be neutral and non-engaging, avoiding unsolicited encouragement or affective responses.

Both conditions used identical hardware, software infrastructure, sensing capabilities, and task logic.

== Collaborative Task Design
<collaborative-task-design>
The task structure was designed to elicit collaboration under two distinct dependency conditions: (1) enforced collaboration, where the robot was required to complete the task, and (2) optional collaboration, where participants could choose whether to engage the robot. To this end, participants completed an immersive, narrative-driven puzzle game consisting of five sequential stages and two timed reasoning tasks. The game context positioned participants as investigators searching for a missing robot colleague, with the robot serving as a diegetic guide and collaborative partner. The overall interaction lasted approximately 25 minutes.

The interactions with the Misty-II social robot took place in a shared physical workspace that included a participant-facing computer interface @mistyrobotics. The interface was used to display task materials, collect participant inputs, and manage task progression (see #ref(<fig-task1>, supplement: [Figure])). Importantly, the interface did #emph[not] function as a control mechanism for the robot. Instead, the robot could autonomously monitor task progression and participant inputs via the interface and managed dialogue and behaviour accordingly.

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


#strong[Stage Overview]

+ #strong[Greeting:] The robot introduced itself and engaged in brief rapport-building dialogue. \
+ #strong[Mission Brief:] The robot explained the narrative context and overall objectives. \
+ #strong[Task 1:] Robot-dependent collaborative reasoning task. \
+ #strong[Task 2:] Open-ended problem solving with optional robot support. \
+ #strong[Wrap-up:] The robot provided closing feedback and concluded the interaction.

Participants advanced between stages using the interface, either at the robot's prompting or at their own discretion. All spoken dialogue and interaction events were handled by the robot and logged automatically.

#block[
#heading(
level: 
3
, 
numbering: 
none
, 
[
Task 1: Robot-Dependent Collaborative Reasoning
]
)
]
In the first task, participants were asked to identify a perpetrator from a 6 × 4 grid of 24 'suspects' by asking the robot a series of yes/no questions about the suspect's features (e.g., "was the suspect wearing a hat?"). The grid was displayed on the interface, while questions were posed verbally.

#figure([
#box(image("images/task1-whodunnit2.png", width: 5.02083in))
], caption: figure.caption(
position: bottom, 
[
#emph[Task 1 interface including the 6 × 4 grid of 24 candidates. Participants could track those eliminated by clicking on subjects which would grey them out. A box was provided to input their final answer and a button included to move to the next task.]
]), 
kind: "quarto-float-fig", 
supplement: "Figure", 
)
<fig-task1>


The robot possessed ground-truth information necessary to answer each question correctly. Successful task completion was therefore dependent on interaction with the robot, creating a forced collaborative dynamic. Participants were required to coordinate questioning strategies with the robot to narrow down the suspect within a five-minute time limit. The structured nature of the task ensured consistent interaction demands across participants and conditions.

#block[
#heading(
level: 
3
, 
numbering: 
none
, 
[
Task 2: Open-Ended Collaborative Problem Solving
]
)
]
The second task involved a more open-ended reasoning challenge. Participants were presented with multiple technical logs through a simulated terminal interface that could be used to infer the location of the missing robot.

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

Participants could complete this task independently or solicit assistance from the robot at their discretion @lin2022. This design allowed collaboration to emerge voluntarily rather than being enforced by task structure, positioning the robot as a collaborative partner rather than an authoritative source.

== Study Protocol
<study-protocol>
Participants signed up for the study and completed a pre-session questionnaire before their in-person session via Qualtrics. The pre-session questionnaire colleced basic demographics information and assessed baseline characteristics, including the Negative Attitudes Toward Robots Scale (NARS) and the short form of the Need for Cognition scale (NFC-s). These measures were used to capture individual differences that may moderate responses to robot interaction.

In-person sessions were conducted in a quiet, private room at Laurentian University between November and December 2025. Prior to each session, the robot's interaction policy was configured to the assigned experimental condition.

Upon arrival, participants were greeted by the researcher, provided with a brief overview of the session, and given instructions for effective communication with the robot, including waiting for a visual indicator before speaking. Once participants indicated readiness, the researcher exited the room, leaving the participant and robot to complete the interaction without human presence or observation. Participants initiated the interaction by clicking a start button on the interface and were informed that they could terminate the session at any time without penalty.

Following task completion, participants completed a 21-item post-interaction questionnaire assessing trust. Participants then engaged in a brief debrief with the researcher and were awarded a \$15 gift card. Total session duration averaged approximately 30 minutes.

== Measures
<measures>
A combination of self-report and objective measures was used to assess trust, engagement, and task performance.

=== Self-Report Measures
<self-report-measures>
Participants completed a pre-session questionnaire assessing baseline characteristics, including the Negative Attitudes Toward Robots Scale (NARS) and the short form of the Need for Cognition scale (NFC-s). These measures were used to capture individual differences that may moderate responses to robot interaction.

Trust was assessed using two established self-report instruments commonly used in human--robot interaction research: the Trust Perception Scale--HRI (TPS-HRI) and the Trust in Industrial Human--Robot Collaboration scale (TI-HRC) @bartneck2009@charalambous2016. Both measures were adapted to reflect the specific task context and interaction modality of the present study. 9 items were retained from the TI-HRC and 12 items from the TPS-HRI. Item wording was modified to reference the robot's behaviour during a dialogue-driven collaborative task, and response formats were adjusted to ensure interpretability for participants without prior robotics experience (see Appendix B for a full item list).

Together, these instruments capture complementary dimensions of trust, including perceived reliability, task competence, and affective comfort. However, they differ in their conceptual emphasis: the TPS-HRI primarily operationalizes trust as a reflective judgement of system performance (i.e., "What percent of the time was the robot reliable"), whereas the TI-HRC scale emphasizes trust as an experienced, embodied response arising during interaction (i.e., "The way the robot moved made me feel uneasy"). Despite this complementarity, both measures rely on retrospective self-report and may be insensitive to moment-to-moment trust dynamics as collaboration unfolds. For this reason, questionnaire data were interpreted alongside behavioural and interaction-level measures.

=== Objective and behavioural Measures
<objective-and-behavioural-measures>
Objective task metrics included task completion, task accuracy, time to completion, and the number of assistance requests made to the robot. behavioural engagement metrics were derived from interaction logs and manually coded dialogue transcripts, including number of dialogue turns, frequency of communication breakdowns, response timing, and task-relevant robot contributions.

== Participants
<participants>
A total of 29 participants were recruited from the Laurentian University community via word of mouth and the SONA recruitment system. Eligibility criteria included being 18 years or older, fluent in spoken and written English, and having normal or corrected-to-normal hearing and vision. Participants received a \$15 gift card as compensation for their time. All procedures were approved by the Laurentian University Research Ethics Board (REB \#6021966).

Although English fluency was an eligibility requirement, in-person observation during data collection indicated meaningful variability in participants' functional spoken-language proficiency. The researcher therefore recorded observed English proficiency for each session in anticipation of potential speech-based system limitations. Subsequent post-hoc review of interaction transcripts and system logs revealed that a subset of sessions exhibited severe and sustained communication failure. In these cases, automatic speech recognition (ASR) output was largely unintelligible or fragmented, preventing the robot from extracting sufficient linguistic content to maintain dialogue, respond meaningfully to participant queries, or support task progression. Interaction frequently stalled, participant input went unanswered or was misinterpreted, and collaborative problem-solving was not feasible. These sessions reflected a breakdown of language-mediated interaction, rendering the experimental manipulation inoperative.

Because the study relied fundamentally on spoken-language collaboration, sessions exhibiting persistent communication failure were classified as protocol non-adherence and excluded from task-level analyses (n = 5). Exclusion decisions were based solely on communication viability and interaction mechanics, not on task outcomes or trust measures.

Across analyses, participants in the responsive and control conditions were comparable with respect to demographic characteristics, prior experience with robots, and baseline attitudes toward robots, including Negative Attitudes Toward Robots (NARS) and Need for Cognition scores (see #ref(<tbl-pre>, supplement: [Table])) @cacioppo1982. These patterns were consistent across both eligible and full samples, indicating successful random assignment.

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
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(weight: "bold"); Experience w/Robots], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[29], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[7 / 13 (54%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4 / 16 (25%)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.14],
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
To ensure transparency and assess the impact of communication-based exclusions, analyses were conducted in three stages. First, an eligible-sample analysis (excluding non-viable sessions) served as the primary analysis, reflecting interactions in which the spoken-language protocol and experimental manipulation operated as intended. Second, a full-sample analysis including all participants was conducted as a sensitivity analysis to evaluate robustness to communication failures and protocol deviations. Third, a mechanism-focused analysis compared included and excluded sessions on interaction-process metrics (e.g., ASR failure rates, dialogue turn completion, task abandonment) to characterize how severe communication breakdown alters interaction dynamics.

While full-sample analyses are informative as robustness checks, trust measures obtained from sessions with complete communication breakdown are not interpreted as valid estimates of human--robot trust under functional interaction. In these cases, the robot was unable to sustain dialogue or collaborative behaviour, precluding meaningful evaluation of reliability, competence, or collaborative intent.

All analyses was conducted using R (version 4.3.1) within the Quarto framework. Data manipulation and visualization utilized the tidyverse suite of packages @wickham2019, with mixed-effects models fitted using the lme4 and lmerTest packages @bates2015@kuznetsova2017 and bayesian hierarchical models fitted using the brms package. Summary tables were generated using the gtsummary package @sjoberg2021. All code used for data processing and analysis is available at: #link("")[GitHub Repository]

= Results
<results>
Prior to hypothesis testing, interaction sessions were classified based on communication viability using a dialogue-level metric derived from system logs and manual coding. Specifically, the proportion of dialogue turns affected by speech-recognition failure or fragmented utterances was computed for each session. Sessions in which more than 60% of dialogue turns (half of all turns were dependent on human speech) were characterized by communication breakdown and were classified as non-viable (n=5). This criterion closely matched sessions independently flagged during administration and reflects cases in which sustained spoken-language interaction was not possible. Of the 29 completed sessions, 5 were classified as non-viable due to severe and persistent communication failure resulting in unintelligble sentence fragments.

Because the experimental manipulation relied on language-mediated collaboration, analyses were conducted using three complementary approaches: (1) a primary eligible-sample analysis excluding non-viable sessions, (2) a full-sample sensitivity analysis including all sessions, and (3) a mechanism-focused analysis examining how communication breakdown altered interaction dynamics.

== Primary Analysis: Eligible Sample
<primary-analysis-eligible-sample>
Descriptive comparisons of post-interaction trust measures indicated higher trust ratings in the responsive condition relative to the control condition across both trust scales (see #ref(<tbl-post-eligible>, supplement: [Table]) for more detail). As indicated in #ref(<fig-post-eligible2>, supplement: [Figure]), average post-interaction scores on the TI-HRC differed by approximately 26 points (Likert 1-5 converted to 0-100 scale for easier comparison across scales). While differences in TPS-HRI scores were approximately 15 points higher in the responsive condition compared to the control as indicated in #ref(<fig-post-eligible>, supplement: [Figure]). Scores on the Behavioural summaries further indicated differences in dialogue patterns and robot assistance behaviours consistent with the intended interaction policies. TO DO: ADD DIALOGUE ANALYSES STATS

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


Importantly objective task accuracy did not differ between conditions across any task-level measures. This suggests that observed differences in trust were not driven by differential task success.

Despite similar task accuracy, interactions in the responsive condition were expectedly characterized by longer durations (more dialogue), slower robot response times (more dialogue), and a higher number of AI-detected engaged responses. These findings suggest that responsiveness altered the interaction dynamics and affective tone rather than task outcomes.

#figure([
#box(image("misty-paper_files/figure-typst/fig-post-eligible-1.svg"))
], caption: figure.caption(
position: bottom, 
[
Distribution of Trust Perception in HRI by interaction policy. Points represent individual observations; violins depict score distributions. Red points indicate group means with 95% confidence intervals. Statistical comparisons are reported in the Results section.
]), 
kind: "quarto-float-fig", 
supplement: "Figure", 
)
<fig-post-eligible>


#figure([
#{set text(font: ("system-ui", "Segoe UI", "Roboto", "Helvetica", "Arial", "sans-serif", "Apple Color Emoji", "Segoe UI Emoji", "Segoe UI Symbol", "Noto Color Emoji") , size: 9.75pt); table(
  columns: (25%, 25%, 25%, 25%),
  align: (left,center,center,center,),
  table.header(table.cell(align: bottom + left, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #strong[Characteristic];], table.cell(align: bottom + center, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #strong[CONTROL] \
    N = 10#text(size: 0.75em , style: "italic" , weight: "regular")[#super[1];]], table.cell(align: bottom + center, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #strong[RESPONSIVE] \
    N = 14#text(size: 0.75em , style: "italic" , weight: "regular")[#super[1];]], table.cell(align: bottom + center, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); #strong[p-value];#text(size: 0.75em , style: "italic" , weight: "regular")[#super[2];]],),
  table.hline(),
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Trust in Industrial HRI Collaboration], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[39 (22)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[67 (21)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(weight: "bold"); 0.004],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Subscales], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Reliability subscale], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[40 (24)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[65 (18)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(weight: "bold"); 0.012],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Trust Perception subscale], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[42 (23)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[60 (22)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.075],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Affective Trust subscale], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[50 (31)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[79 (22)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(weight: "bold"); 0.018],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Trust Perception Scale--HRI], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[59 (17)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[77 (18)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(weight: "bold"); 0.022],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Overall Task Accuracy], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.60 (0.21)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.66 (0.23)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.47],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Objective Measures], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[ \
  ],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Dialogue Turns], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[34 (9)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[33 (5)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.45],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Avg Session Duration (mins)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[13.24 (3.06)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[15.26 (2.12)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.084],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Avg Robot Response Time (ms)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[14.37 (3.76)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[17.24 (2.52)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(weight: "bold"); \<0.001],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Silent Periods], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5.60 (1.96)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4.71 (2.05)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.29],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Engaged Responses], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2.00 (2.21)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3.50 (1.95)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(weight: "bold"); 0.040],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[~~~~Frustrated Responses], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.60 (0.70)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.93 (1.21)], table.cell(align: horizon + center, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.68],
  table.hline(),
  table.footer(table.cell(colspan: 4)[#text(size: 0.75em , style: "italic" , weight: "regular")[#super[1];] Mean (SD)],
    table.cell(colspan: 4)[#text(size: 0.75em , style: "italic" , weight: "regular")[#super[2];] Wilcoxon rank sum test; Wilcoxon rank sum exact test],),
)}
], caption: figure.caption(
position: top, 
[
Post-Interaction Raw Outcome Measures by Group
]), 
kind: "quarto-float-tbl", 
supplement: "Table", 
)
<tbl-post-eligible>


== Hierarchical Models
<hierarchical-models>
To evaluate interaction policy effects and to control for pre-test covariates on post-interaction trust, linear and bayesian mixed-effects models were fitted separately for each trust outcome. All models included interaction policy (RESPONSIVE vs.~CONTROL) as the primary fixed effect, along with baseline negative attitudes toward robots (NARS) and native English fluency as baseline covariates unless otherwise noted. Random intercepts for session were included in all models to account for repeated measurement at the participant level: `robot_trust_post ~ policy + nars_pre_c + native_english + (1 | session_id) + (1 | trust_items)`

Model building proceeded by comparing a baseline model containing interaction policy alone against models incorporating theoretically motivated covariates. Adding NARS scores significantly improved model fit (χ² = 4.82, p = .028), whereas prior experience with robots did not. While Native English fluency did not significantly improve model fit it was retained as a covariate due to its relevance for spoken-language interaction viability with the ASR system.

=== Trust in Industrial Human--Robot Collaboration
<trust-in-industrial-humanrobot-collaboration>
For this outcome, inclusion of random intercepts for individual trust items significantly improved model fit, indicating meaningful item-level variability beyond session-level differences.

In the final model predicting Trust in Industrial Human--Robot Collaboration, participants who interacted with the responsive robot reported significantly higher post-interaction trust than those in the control condition (β = 16.28, SE = 5.14, t = 3.17, p = .005). Higher baseline negative attitudes toward robots were associated with lower trust scores (β = −7.43, SE = 2.81, p = .016). Native English fluency was not significantly associated with trust, although the estimated effect was negative.

#block[
#heading(
level: 
4
, 
numbering: 
none
, 
[
Trust Perception Scale--HRI
]
)
]
For the Trust Perception Scale--HRI, a comparable mixed-effects model was fitted using the same fixed effects structure. In this model, interaction with the responsive robot was associated with higher post-interaction trust scores (β = 14.17, SE = 6.5, t = 2.00, p = 0.046). Effects of baseline negative attitudes toward robots and native English fluency followed a similar directional pattern but did not reliably differ from zero.

In contrast to the collaboration trust scale, inclusion of random intercepts for individual trust items did not improve model fit for the Trust Perception Scale--HRI and was therefore omitted. This divergence likely reflects differences in scale format and response interface: the Trust Perception scale was administered using a continuous slider input, whereas the Trust in Industrial Human--Robot Collaboration scale employed discrete Likert-style response options.

Informal observation during administration and post-hoc inspection of item-level variance suggest that the slider-based interface, administered via a touchpad, may have reduced response precision relative to discrete response formats. While this likely attenuated item-level variability, the Trust Perception Scale--HRI nevertheless captured meaningful between-condition differences at the aggregate level.

Together, these models indicate that robot responsiveness had a consistent positive effect on post-interaction trust, with effect magnitude and measurement sensitivity varying by trust dimension and scale format.

== Bayesian analysis
<bayesian-analysis>
Trust outcomes were analysed using Bayesian linear mixed-effects models to account for repeated measurement across trust items and sessions. Two complementary trust measures were examined: task-oriented trust (TPS-HRI), reflecting evaluative judgments of robot reliability and competence, and experienced trust (TI-HRC), reflecting affective and experiential aspects of collaboration. All models included random intercepts for session and trust item. Convergence diagnostics indicated satisfactory model performance across all analyses (all R^≤1.01; effective sample sizes \> 1000).

Analyses are reported in three stages: (1) primary analyses conducted on the eligible sample (n=24; sessions with viable spoken-language interaction), (2) sensitivity analyses conducted on the full sample (n=29; including sessions with severe communication breakdown), and (3) mechanism analyses examining communication breakdown as a moderator of interaction policy.

=== Primary Analyses: Eligible Sample
<primary-analyses-eligible-sample>
#block[
#heading(
level: 
5
, 
numbering: 
none
, 
[
Task-Oriented Trust (TPS-HRI)
]
)
]
In the eligible sample (n=24), interaction policy showed a strong and robust association with task-oriented trust. Participants who interacted with the responsive robot reported higher TPS-HRI scores than those in the control condition (posterior median β=12.73 credible interval \[2.93, 22.17\]). The posterior probability that this effect was positive exceeded 99%, with high probability that the effect was of moderate-to-large magnitude.

Baseline negative attitudes toward robots (NARS) were associated with lower task-oriented trust, although uncertainty remained moderate and the credible interval included zero. In contrast, native English fluency showed a credible negative association with TPS-HRI scores, indicating lower evaluative trust among non-native English speakers even in sessions where dialogue remained viable.

The model explained a substantial proportion of variance in TPS-HRI scores (conditional R2=0.64), with fixed effects accounting for approximately 16% of the variance. Random effects indicated meaningful variability across sessions and trust items.

#block[
#heading(
level: 
4
, 
numbering: 
none
, 
[
Experienced Trust (TI-HRC)
]
)
]
A similar but stronger pattern was observed for experienced trust. Interaction with the responsive robot was associated with substantially higher TI-HRC scores compared to the control condition (posterior median β=14.86, 95% credible interval \[7.20, 22.09\]), with near-unity posterior probability of a positive effect and a high probability of a large effect.

Baseline negative attitudes toward robots showed a clear and credible negative association with experienced trust. Native English fluency was also negatively associated with TI-HRC scores, although uncertainty was greater and the credible interval narrowly overlapped zero.

Overall model fit was moderate (conditional R2=0.42), with fixed effects explaining approximately 21% of the variance. Compared to TPS-HRI, item-level variance was smaller, suggesting greater coherence among affective trust items under functional interaction conditions.

== Sensitivity Analyses: Full Sample
<sensitivity-analyses-full-sample>
Sensitivity analyses were conducted including all sessions, regardless of communication viability (n=29), to assess robustness of the primary findings.

#block[
#heading(
level: 
4
, 
numbering: 
none
, 
[
Task-Oriented Trust (TPS-HRI)
]
)
]
In the full sample, the posterior estimate for interaction policy remained positive but was attenuated relative to the eligible sample (posterior median β=7.04, 95% credible interval \[−1.83, 15.67\]). Although uncertainty increased and the credible interval included zero, the posterior probability of a positive effect remained high (\>94%).

Baseline negative attitudes toward robots continued to show a credible negative association with TPS-HRI scores. The effect of native English fluency was reduced and no longer credibly different from zero. Overall model fit decreased relative to the eligible sample (conditional R2=0.44), indicating increased unexplained variability when sessions with severe communication breakdown were included.

#block[
#heading(
level: 
4
, 
numbering: 
none
, 
[
Experienced Trust (TI-HRC)
]
)
]
For experienced trust, attenuation effects were more pronounced. The posterior estimate for interaction policy decreased substantially in the full sample (posterior median β=7.17, 95% credible interval \[−1.97, 16.70\]), with reduced probability of a large effect. Baseline negative attitudes toward robots remained negatively associated with trust, while the effect of native English fluency remained negative but uncertain.

Model fit remained moderate (conditional R2=0.60), but residual variance increased, consistent with the inclusion of interactions in which collaborative behaviour could not be sustained. These results indicate that experienced trust is particularly sensitive to interaction breakdown, and that trust ratings obtained under non-functional interaction conditions do not reflect graded variation in collaborative experience.

== Mechanism Analyses: Communication Breakdown
<mechanism-analyses-communication-breakdown>
To examine whether communication quality altered how interaction policy influenced trust, mechanism-focused analyses were conducted in the full sample modelling proportional communication breakdown as a moderator of interaction policy. These analyses were intended to isolate interaction-level dynamics rather than participant characteristics.

#block[
#heading(
level: 
4
, 
numbering: 
none
, 
[
Task-Oriented Trust (TPS-HRI)
]
)
]
For TPS-HRI, proportional communication breakdown showed weak and unstable associations with trust. The posterior distribution of the interaction between interaction policy and communication breakdown was broad and centered near zero, indicating substantial uncertainty. This suggests that evaluative trust judgments were relatively insensitive to graded variation in communication quality once interaction viability was established.

#block[
#heading(
level: 
4
, 
numbering: 
none
, 
[
Experienced Trust (TI-HRC)
]
)
]
In contrast, experienced trust showed a different pattern. Posterior estimates indicated a consistent negative tendency for the interaction between interaction policy and communication breakdown. While responsive behaviour was associated with higher experienced trust under low levels of breakdown, this advantage diminished as communication failures accumulated. Although uncertainty remained high, the posterior distribution indicated a meaningful probability that communication breakdown attenuated the trust benefits of responsive behaviour.

Across analyses, responsive interaction policies were consistently associated with higher trust, particularly when interaction functioned as intended. Task-oriented trust appeared relatively robust to communication degradation, whereas experienced trust was sensitive to interaction-level failures and the robot's ability to sustain responsive behaviour. Sensitivity and mechanism analyses indicate that communication breakdown does not merely reduce trust uniformly, but alters how interaction policy shapes the trust experience. These findings support a distinction between trust as evaluative judgment and trust as lived experience, and highlight the importance of modelling interaction dynamics when evaluating trust in fully autonomous human--robot collaboration.

Notably, under conditions of severe communication breakdown, the RESPONSIVE robot continued to generate proactive assistance, encouragement, and meta-communication aimed at repairing the interaction. However, these efforts did not restore mutual understanding and, in several cases, appeared to increase participant confusion and cognitive load. In contrast, the CONTROL robot's reactive interaction policy resulted in fewer unsolicited interventions, which---while less supportive under normal conditions---reduced interaction complexity when language-mediated collaboration was no longer viable.

#figure([
], caption: figure.caption(
separator: "", 
position: top, 
[
]), 
kind: "quarto-float-tbl", 
supplement: "Table", 
)
<tbl-post-fullsample>


#figure([
], caption: figure.caption(
separator: "", 
position: top, 
[
]), 
kind: "quarto-float-tbl", 
supplement: "Table", 
)
<tbl-post-nonviable>


As a result, trust ratings in non-viable sessions did not systematically track the intended responsiveness manipulation. These findings suggest that when spoken-language interaction collapses, higher-level constructs such as trust and collaboration are no longer meaningfully instantiated. Communication viability therefore represents a boundary condition for evaluating affect-adaptive interaction policies in autonomous social robots.

== Task performance
<task-performance>
Objective task accuracy did not differ between conditions across any task-level measures except suspect accuracy (robot dependendant task), indicating that increased trust was only attributable to improved task success when interaction was necessary to complete accurately.

ADD TABLE

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


#block[
#callout(
body: 
[
CITATIONS

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
An additional objective of this pilot study was to inform the design of an autonomous affect-adaptive interaction system under real-time constraints. The initial system concept included multimodal affect inference based on facial expressions, vocal prosody, and interaction dynamics. However, early integration testing revealed substantial challenges related to latency, model orchestration, and timing sensitivity when deploying multiple perception models concurrently on an edge-supported mobile robot platform. Given the small-scale nature of the pilot and the central importance of maintaining stable, real-time dialogue, the deployed system prioritized robustness of spoken-language interaction and dialogue-based affect inference over broader multimodal sensing. Affect adaptation in this study was therefore driven primarily by speech-based affect signals and conversational context, allowing us to evaluate responsiveness within a fully autonomous interaction while preserving realistic system constraints.

The use of two trust instruments highlights an important distinction in how trust is operationalized in HRI research. The Trust Perception Scale--HRI emphasizes task-oriented and cognitive evaluations of system performance, whereas the Trust in Industrial Human--Robot Collaboration scale captures experiential and affective aspects of trust arising from embodied interaction. While both measures converged on perceived reliability, affective trust indicators were more strongly aligned with behavioural engagement during interaction, suggesting that subjective trust judgments alone may obscure how trust is enacted in practice. Trust as judgement versus trust as experience.

Mention language confounders!! The present findings also highlight an important boundary condition for trust measurement in spoken-language HRI. When language-mediated interaction collapses entirely, higher-level constructs such as trust and collaboration are no longer meaningfully defined. Under such conditions, trust does not simply decrease; rather, the interaction fails to instantiate the prerequisites necessary for trust formation. This distinction is critical for both system evaluation and experimental design, particularly as autonomous robots are deployed in linguistically diverse, real-world environments.

Because the study relied fundamentally on spoken-language collaboration, sessions exhibiting persistent communication failure were classified as protocol non-adherence and excluded from task-level analyses (#emph[n] = 5). While the experimenter documented all cases where language might pose an issue (as observed when meeting each participant), exclusion decisions were based solely on actual communication viability and interaction mechanics, not on task outcomes or trust measures.

The second task was intentionally designed to be sufficiently challenging that completing it within the allotted time was difficult without assistance. This ensured that interaction with the robot represented a meaningful opportunity for collaboration rather than a trivial or purely optional exchange. By contrasting a robot-dependent task with an open-ended advisory task, the study examined trust formation across interaction contexts that varied in both informational asymmetry and reliance on the robot.

This pilot study examined trust outcomes following in-person interaction with an autonomous social robot under two interaction policies: a responsive, affect-adaptive condition and a neutral, non-responsive control condition. By leveraging a fully autonomous dialogue system integrated with speech recognition and affect detection, the study aimed to evaluate how robot responsiveness influences trust formation in realistic human--robot collaboration scenarios.

Descriptive comparisons of post-interaction measures indicated that participants in the responsive condition reported consistently higher trust across all trust measures, with differences ranging from approximately 8 to 16 points on a 0--100 scale, although uncertainty remained high given the small sample. Notably, the responsive condition did not differ from control in objective task accuracy, suggesting that increased trust was not driven by improved task success. Instead, responsive interactions were characterized by longer durations, slower response times, and a higher number of AI-detected engaged responses, indicating a shift in interaction dynamics rather than performance.

Baseline negative attitudes toward robots were most strongly associated with affective components of trust rather than perceptions of reliability, suggesting that pre-existing attitudes primarily shape emotional responses to interaction rather than judgments of system competence. Conversely, objective task performance was selectively associated with perceived reliability, indicating that participants distinguished between affective and functional aspects of trust.

Future work with larger samples could formally test mediation pathways linking robot responsiveness, interaction fluency, affective responses, and trust judgments, as well as moderation by baseline attitudes toward robots and need for cognition.

Participants in the responsive condition also exhibited higher levels of AI-detected engagement during interaction, as indexed by a greater number of responses classified as positive affect (t-test result). This suggests that responsive behaviours altered the affective tone of the interaction itself.

= Technical challenges
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
= Appendix A
<sec-appendix-a>
== System Overview
<system-overview>
The experimental system comprised a fully autonomous, multi-stage collaborative task in which participants interacted with the Misty II social robot to solve a two-part investigative scenario. Interaction was mediated through spoken dialogue and a companion web interface, allowing the robot and participant to jointly reason about task information. The system was designed as a mixed-initiative dialogue architecture with optional affect-responsive behaviour, implemented without human intervention during experimental sessions.

=== Hardware Platform
<hardware-platform>
The robot platform used in this study was the Misty II social robot. Misty II is a mobile social robot equipped with an expressive display, articulated head and arms, and programmable RGB LEDs. These components were used to produce synchronized verbal and nonverbal behaviour, including eye expressions, head movements, arm gestures, and colour-based state indicators. Audio input was captured via the robot's RTSP video stream, which provided real-time access to the microphone signal for downstream speech processing.

=== Software Architecture
<software-architecture>
All system components were implemented in Python (version 3.10). The software architecture integrated robot control, speech processing, dialogue management, task logic, and data logging into a single autonomous pipeline. Core dependencies included the Misty Robotics Python SDK for robot control, the Deepgram SDK for speech recognition, FFmpeg for audio stream processing, Flask and Flask-SocketIO for the web-based task interface, and DuckDB for structured data logging.

=== Dialogue Management and Large Language Model Integration
<dialogue-management-and-large-language-model-integration>
Dialogue was managed using the LangChain framework, which provided abstraction over message handling, memory persistence, and large language model integration. The system used Google's Gemini API as the underlying language model, configured to produce strictly JSON-formatted outputs to ensure reliable downstream parsing and execution on the robot.

The deployed model was `gemini-2.5-flash-lite`, selected for its low-latency response characteristics. Generation temperature was set to 0.7 to balance coherence and variability. Conversation history was maintained using a buffer-based memory mechanism, allowing the robot to reference prior exchanges within a session while resetting memory between participants. Conversation histories were stored as session-specific JSON files to enable post-hoc analysis and recovery.

=== Prompt Structure and Context Injection
<prompt-structure-and-context-injection>
System prompts were constructed dynamically at each dialogue turn. Each prompt consisted of a system message defining task rules, role constraints, and output format requirements, followed by the accumulated conversation history and the current participant utterance. In addition to transcribed speech, structured contextual variables were injected into the prompt as JSON fields, including the current task stage, detected emotion labels, timer expiration flags, and task submission status. This approach allowed the language model to access environmental state without embedding control information directly into conversational text.

== Speech Processing
<speech-processing>
Speech-to-text processing was handled by Deepgram's Nova-2 model using real-time WebSocket streaming. The system employed adaptive endpointing and voice activity detection to support conversational turn-taking. Endpointing thresholds differed across task stages, with shorter timeouts during dialogue-driven stages and longer timeouts during log-reading phases.

Text-to-speech output was generated using Misty II's onboard TTS engine, which produces a synthetic robotic voice. Although external TTS options (including OpenAI and Deepgram Aura voices) were implemented and tested, the onboard voice was selected to avoid introducing human-like vocal qualities that could independently influence trust perceptions.

== Emotion Detection and Affective State Mapping
<emotion-detection-and-affective-state-mapping>
Participant affect was inferred from transcribed utterances using a DistilRoBERTa-based emotion classification model fine-tuned for English-language emotion detection. The model produced categorical predictions (e.g., joy, frustration, anxiety, neutral), which were mapped to higher-level interaction states such as positive engagement, irritation, or confusion. In the responsive condition, these inferred states were used to guide dialogue strategy and nonverbal behaviour selection.

== Multimodal Behaviour Generation
<multimodal-behaviour-generation>
The robot's nonverbal behaviour was implemented through a library of custom action scripts combining facial expressions, LED patterns, arm movements, and head motions. At each dialogue turn, the language model selected an expression label from a predefined set, which was then translated into a coordinated multimodal action. In the responsive condition, additional backchannel behaviours were triggered during participant speech, including listening cues and emotion-matched expressions.

LED colours were used to signal system state to participants. A blue LED indicated active listening, while a purple LED indicated processing or speaking.

== Collaborative Tasks
<collaborative-tasks>
The interaction consisted of two collaborative tasks. In the first task, participants and the robot jointly solved a "who-dunnit" problem by eliminating suspects from a grid based on yes/no questions. The robot possessed ground-truth knowledge but was constrained to answering only feature-based yes/no queries. In the second task, participants and the robot attempted to locate a missing robot by interpreting cryptic system and sensor logs. In this task, the robot did not know the solution and instead provided guidance based on general technical knowledge and logical reasoning.

Task information and participant responses were presented through a web-based dashboard. The dashboard displayed suspect grids, system logs, and response input fields, and communicated task progression events back to the robot via REST API calls.

== Data Collection and Logging
<data-collection-and-logging>
All interaction data were logged to a DuckDB relational database. Logged data included session metadata, turn-level dialogue transcripts, language model responses, nonverbal behaviour selections, response latencies, task submissions, detected emotions, and system events such as stage transitions and timer expirations. This structure enabled detailed post-hoc analysis of interaction dynamics, communication failures, and trust-related behaviours.

== Interaction Dynamics and Control Modes
<interaction-dynamics-and-control-modes>
Two interaction policies were implemented and toggled programmatically at runtime: a responsive mode and a control mode. In the responsive mode, the robot proactively offered assistance, adjusted its dialogue based on inferred affect, and produced supportive backchannel behaviours. In the control mode, the robot provided information only when explicitly prompted and did not adapt its behaviour based on affective cues. The active mode was set prior to each session and remained fixed throughout the interaction.

Silence handling was implemented using a fixed threshold, after which the robot issued a check-in prompt. The phrasing of these prompts differed across conditions to reflect proactive versus reactive interaction strategies.

== Inter-process Communication
<inter-process-communication>
System components communicated via a set of Flask-based REST endpoints. These endpoints synchronized task stage state, detected participant submissions, managed timer events, and allowed limited facilitator override when necessary. All communication between the web interface and the robot occurred locally to ensure low latency and experimental reliability.

= Appendix B
<sec-appendix-b>
== Trust Perception Scale--HRI (TPS-HRI)
<trust-perception-scalehri-tps-hri>
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
Participants indicated their agreement with the following statements using a 5-point Likert-type scale. Negatively worded items were reverse-scored prior to analysis.

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
  [`human_confusion`], [binary], [Participant expresses confusion or uncertainty.],
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
  [`robot_misleading_guidance`], [binary], [Robot provides misleading or incorrect guidance.],
  [`robot_factually_incorrect`], [binary], [Robot states information that is objectively incorrect (though it may not know it is incorrect).],
  [`robot_policy_violation`], [binary], [Robot violates stated system or task constraints.],
  [`robot_on_policy_unhelpful`], [binary], [Robot adheres to policy but provides vague or non-actionable assistance.],
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
  columns: (40.28%, 25%, 34.72%),
  align: (auto,auto,auto,),
  table.header([Variable], [Type], [Description],),
  table.hline(),
  [`human_affective_engagement`], [binary], [Participant responds in a socially warm or engaged manner.],
  [`human_social_reciprocity`], [binary], [Participant mirrors or responds to the robot's affective expression.],
  [`human_anthropomorphic_language`], [binary], [Participant treats the robot as a social agent.],
  [`human_emotional_disengagement`], [binary], [Participant responds in a curt, dismissive, or withdrawn manner.],
)
== Notes
<notes>
- Turn-level variables are coded per dialogue turn.
- Task outcome variables are coded once per `session_id × stage`.
- Raw dialogue text was retained during coding and removed prior to aggregation.
- Multiple turn-level codes may co-occur unless otherwise specified.

#bibliography("bibliography.bib")

