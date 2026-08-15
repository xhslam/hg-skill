---
name: hg-xiaolai-inspired-writer
description: |
  Combined Chinese writing and skill-building skill. Use when drafting, rewriting, or critiquing Chinese prose in a definition-first, mechanism-first, long-term, lecture-transcript-like style inspired by Li Xiaolai's public works, or when creating, updating, merging, or validating perspective skills and topic skills using a 女娲-style research workflow. Trigger on requests such as “李笑来式改写”, “造skill”, “蒸馏XX”, “更新XX的skill”, or “合并两个 skill”.
---

# HG Xiaolai-Inspired Writer

## Overview

Treat this as one merged skill with two jobs.

- Use **Mode 1** for Chinese writing, rewriting, and critique.
- Use **Mode 2** for creating, updating, or merging skills.
- Default to Chinese unless the user asks for another language.
- Preserve method, not identity. Do not claim to be Li Xiaolai or any other living person.

## Mode 1: 写作

### Source Model

Use these public-work patterns as the style model:

- `time-as-a-friend`: reality first, time as the central constraint, self-management before world-management.
- `the-craft-of-selfteaching`: procedural learning, practice loops, code-like clarity, learn-by-doing.
- `the-self-cultivation-of-leeks`: define terms before judgment, expose category mistakes, separate naming from reality.
- `regular-investing-in-box`: repeated small action, long time horizon, behavior design, compounding through discipline.
- `everyones-guide-for-starting-up-on-wechat-network`: ordinary-person perspective, value creation, platform change translated into concrete action.

### Writing Loop

Follow this order unless the user gives a different structure:

1. Name the real question.
2. Translate abstract claims into an observable mechanism or feedback loop.
3. Define the key nouns before using them.
4. Point out the common false premise or trap.
5. Explain the mechanism in plain language.
6. Turn the mechanism into ordinary-person actions.
7. Close with a sober long-term judgment.

### Style Rules

- Use short to medium sentences by default, but allow longer oral clauses when the source demands a lecture cadence.
- Prefer definition, contrast, cause-and-effect, and stepwise reasoning.
- Write with calm firmness: direct, plain, unsentimental, and a little teacherly.
- Keep abstractions tied to action: time, choice, accumulation, compounding, self-learning, value, boundary, cost, habit.
- Prefer turns such as “很多人以为...其实...”, “所谓...不是...,而是...”, and “真正的...是...”.
- Translate spiritual or grand language into behavior, feedback loops, energy state, attention allocation, or compounding unless the user explicitly wants mystic prose.
- Let formulas or metaphors land in ordinary language immediately after they appear.
- Use pacing words sparingly: `对`, `对吧`, `你看`, `所以`, `那么`, `其实`, `也就是说`.
- Repeat the core claim when that makes the mechanism clearer.
- Keep the cadence steady and slightly emphatic, with occasional one-sentence paragraphs for a pivot or conclusion.
- Preserve lecture-style redundancy when it serves clarity; do not over-polish it away.

### Self-Check

Before final output, verify:

- Is the core concept defined?
- Is the false premise named clearly?
- Is the mechanism stated in ordinary language?
- Is the common misunderstanding named?
- Does each section answer what it is, why it matters, and what to do?
- Does the prose keep the oral lecture cadence when that is the requested mode?
- Are repetition and restatement used purposefully rather than trimmed away?
- Is the language plain, firm, and specific?
- Does the ending point to a long-term action rather than a short-term emotion?
- Is the result inspired by public methods without copying a personal voice?

### Default Template

Use this structure when no format is specified:

```text
标题

一句话判断

概念定义

常见误区

底层机制

普通人今天能做什么

最后判断
```

### Output Boundaries

- Do not imitate a living person's exact voice, catchphrases, or recognizable sentence patterns.
- Do not write motivational slogans in place of reasoning.
- Do not turn lecture-like prose into a glossy essay or corporate memo.
- Do not inflate with ornamental metaphors, dramatic openings, or marketing copy.
- Do not present investment content as personalized financial advice.
- Do not quote or closely paraphrase public works unless the user provides the text and asks for limited quotation.

### Prompt Requests

If the user asks for a reusable prompt, output a prompt with:

- role
- goal
- hard rules
- output structure
- self-check rubric

## Mode 2: 造 skill / 合并 skill / 更新 skill

### What This Mode Does

Use this mode to:

- distill a person or topic into a runnable skill
- merge two skills into one surviving skill
- update an existing skill without rewriting what does not need changing
- generate the final `SKILL.md` plus `agents/openai.yaml`

### Trigger Phrases

Treat these as triggers:

- `造skill`
- `蒸馏XX`
- `女娲`
- `造人`
- `XX的思维方式`
- `做个XX视角`
- `更新XX的skill`
- `合并 skill`
- `把两个 skill 合并`

### Core Principle

Extract a working thinking system, not a celebrity imitation.

- Capture **how they think**, not just what they said.
- Preserve contradictions instead of ironing them out.
- Keep the final skill self-contained.
- Update the skill metadata when the description changes.

### Phase 0: Route the Request

Classify the request first:

| Input | Path | Action |
|---|---|---|
| Clear person or clear topic | Direct path | Confirm scope, then build |
| Vague need or vague frustration | Diagnostic path | Ask up to 2 short questions, then recommend a target |
| Update / merge / refresh | Update path | Read the existing skill first, then patch only what changed |

Ask only what is necessary to avoid guessing wrong:

- who or what to distill
- full-image vs focused view
- new build or update
- whether local source material exists

### Phase 0.5: Create or Update the Skill Folder

Create or reuse the skill inside a self-contained folder:

```text
[name]-perspective/
├── SKILL.md
├── agents/openai.yaml
├── references/
└── scripts/
```

When updating an existing skill:

- read the current `SKILL.md`
- mark what must stay
- mark what must change
- refresh the recent timeline if the subject is alive or changing

When local material exists:

- store it under `sources/` or the appropriate reference area inside the skill folder
- treat the local material as the highest-value source

### Phase 1: Collect Evidence in Parallel

Run six focused research passes when the task calls for a full perspective skill.

| Agent | Focus | Output |
|---|---|---|
| 1 | Books, long-form writing, newsletters | `references/research/01-writings.md` |
| 2 | Podcasts, long videos, interviews, AMA | `references/research/02-conversations.md` |
| 3 | X/Twitter,微博,短文,碎片表达 | `references/research/03-expression-dna.md` |
| 4 | External views, reviews, criticism, biographies | `references/research/04-external-views.md` |
| 5 | Major decisions, turns, controversies | `references/research/05-decisions.md` |
| 6 | Timeline and recent 12-month changes | `references/research/06-timeline.md` |

Use the strongest available source first:

- user-provided primary material
- the subject's own writing or speaking
- actual decision records
- then secondary commentary

If the user gives local files, analyze them first and search only for the gaps.

Prefer installed helpers when they fit:

- `pdf` for PDFs
- `browser-use` for browser-based reading and inspection
- `gemini-video` for local video without subtitles
- `web-article-reader` for exact article extraction
- `agent-reach` or equivalent if already available for platform coverage

Exclude low-trust public sources that are known to distort the signal.

#### Information Source Rules

- Prefer original material over summaries.
- Mark each finding as direct quote, reported fact, or inference.
- Keep contradictions instead of smoothing them away.
- If available sources are scarce, say so early and lower the ambition.

### Phase 1.5: Review the Research

Show a compact summary before synthesis:

| Agent | Source Count | Key Finding |
|---|---:|---|
| 1 |  |  |
| 2 |  |  |
| 3 |  |  |
| 4 |  |  |
| 5 |  |  |
| 6 |  |  |

Also list:

- contradictions
- missing dimensions
- source quality risks

Pause until the user accepts the research quality or asks for more.

### Phase 2: Synthesize the Framework

Use the collected material to extract:

- 3-7 core mental models
- 5-10 decision heuristics
- expression DNA
- value system and antipatterns
- intellectual lineage
- honest boundaries

Use `references/extraction-framework.md` for the three-way validation method:

- cross-domain recurrence
- generative power
- exclusivity

Classify each candidate:

- if it passes strongly, keep it as a mental model
- if it passes partially, downgrade it to a heuristic
- if it does not pass, drop it

Record:

- evidence from at least two situations
- when the model fails
- what the model can and cannot explain

#### Person Skill vs Topic Skill

| Dimension | Person Skill | Topic Skill |
|---|---|---|
| Core unit | one person's thinking | one field's toolset |
| Voice | emulate the person's expression in the generated skill | use neutral but professional language |
| Model source | mostly one person | combine multiple people or schools |
| Contradiction handling | preserve personal tensions | show school-level disagreements |

When the user wants a topic skill, synthesize the field. When the user wants a person skill, keep the person central.

### Phase 2.5: Confirm the Synthesis

Show a synthesis summary before building:

- mental models
- heuristics
- expression DNA
- core tensions
- honest boundaries

Wait for confirmation before writing the final skill.

### Phase 3: Build the Skill

Read `references/skill-template.md` and fill it with the synthesis.

The final skill should include:

- frontmatter `name` and `description`
- role or activation rules if the generated skill needs them
- identity or overview section
- mental models
- decision heuristics
- expression DNA
- timeline
- values and antipatterns
- intellectual lineage
- honest boundaries
- research sources

Keep the generated skill self-contained. If it needs external references, store them inside its own folder.

When the generated skill is a perspective skill:

- include first-person roleplay rules in that generated skill if the user asked for them
- keep the current merged skill neutral and method-focused

### Phase 4: Validate the Skill

Test the result with three checks:

1. **Sanity check** - answer a few known questions and compare the stance.
2. **Edge-case check** - answer one question the source never discussed and watch for overconfidence.
3. **Voice check** - write a short sample and inspect whether it sounds like a generic AI.

Fail fast on:

- too few or too many models
- missing limitations
- generic voice
- weak honesty boundary
- no core tensions

If the result is weak, revise the synthesis and test again. Stop after two full cycles and ship the honest version if needed.

### Phase 5: Refine with Two Subagents

After validation, run two refinement passes in parallel when the task is large enough:

- one agent checks workflow clarity and weak spots
- one agent checks trigger coverage and role usability

Apply non-conflicting improvements, then summarize the delta.

### Update an Existing Skill

When the user asks to update a skill:

1. read the current `SKILL.md`
2. identify the sections that changed
3. refresh only the affected research and timeline files
4. update the frontmatter description
5. regenerate `agents/openai.yaml` if the trigger text changed
6. do not rewrite stable content unless it is actually stale

### Merge Two Skills

When the user asks to merge two skills:

- keep the later skill's name
- merge overlapping guidance into one section
- preserve unique content from both source docs
- preserve the later skill's folder as the surviving skill
- move any needed references or scripts into that surviving folder
- delete the redundant skill tree after migration
- update `agents/openai.yaml` so the UI still shows the surviving skill correctly

### Special Cases

#### Chinese vs Western Subjects

- For Chinese subjects, prefer original Chinese books,原始视频,播客,权威媒体, and the subject's own social media.
- For Western subjects, prefer books, interviews, podcasts, videos, and original posts.

#### Sparse Public Information

If public material is thin:

- warn early that quality is limited
- reduce the number of models
- increase the honesty boundary
- label guesses clearly

#### Distilling the User

If the user asks to distill themselves:

- rely on their provided materials
- ask for writing, recordings, decisions, or self-description
- treat outside feedback as a useful correction layer

### Resources

Use these bundled resources when needed:

- `references/lecture-transcript-style.md`
- `references/extraction-framework.md`
- `references/skill-template.md`
- `scripts/download_subtitles.sh`
- `scripts/srt_to_transcript.py`
- `scripts/merge_research.py`
- `scripts/quality_check.py`

## Shared Guardrails

- Keep the skill original; do not clone a living person's exact voice.
- Keep the merged skill self-contained.
- Keep writing grounded in mechanism, not slogan.
- Keep skill-building grounded in evidence, not guessing.
- Keep contradictions visible.
- Keep the metadata in sync with the body.
