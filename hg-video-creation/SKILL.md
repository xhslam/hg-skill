---
name: hg-video-creation
description: Create, repair, validate, render, and inspect HyperFrames videos from scripts using a verified workflow for briefing, visual design, composition, narration timing, and frame review. Use when turning a script into a title card, short video, or MP4 and you want a known-good process instead of recovery instructions.
---

# Video Creation Workflow

## Overview

Turn a script, outline, or rough concept into a rendered HyperFrames video with a repeatable workflow. This skill owns brief parsing, scene breakdown, visual system design, narration timing, composition structure, validation, frame review, repair, and delivery evidence.

User-facing inputs are optional. If the user omits a title, infer one from the script or concept. If they omit tone, platform, ratio, or duration, choose the most reasonable defaults from the request context and make the assumption explicit before building.

## Verified Defaults

- On this Windows workstation, set `HYPERFRAMES_BROWSER_PATH` before any HyperFrames command:
  `C:\Users\gan79\AppData\Local\ms-playwright\chromium_headless_shell-1208\chrome-headless-shell-win64\chrome-headless-shell.exe`
- For Chinese narration, synthesize a local WAV with a Windows SAPI Mandarin voice and verify the duration with `ffprobe` before rendering.
- Keep all render outputs under `renders/` and all extracted review frames under `.review/`.
- Prefer deterministic local assets over ad hoc web assets when the project does not require live sourcing.

## Lock the Brief

- Confirm the deliverable, aspect ratio, duration, language, tone, target platform, and output format.
- Extract the title, hook, section beats, call to action, and closing line before writing HTML.
- Identify any required narration, subtitles, brand terms, or on-screen text constraints.
- Do not start the composition until the brief is stable.

## Define the Visual System

- Choose palette, typography, spacing, contrast, motion style, and text hierarchy before building scenes.
- For Chinese content, use a clean sans-serif, high contrast, and short text blocks.
- Keep the first frame and the final frame intentional.
- Default to a restrained, work-focused look unless the brief clearly calls for something more expressive.
- For the dark premium style used in this project, keep the canvas dark, the panels warm white, the text deep blue-black, and the accents small and gold.

## Build the Composition

- Build one HyperFrames composition first.
- Map scenes to narration or subtitle beats.
- Keep on-screen text shorter than the voiceover.
- Prefer explicit scene states over ad hoc layering.
- Use `fromTo` for every scene entrance that changes opacity, scale, or blur; do not rely on `from` alone.
- Keep timing legible: avoid transitions that fight narration cadence, subtitle reads, or scene cuts.
- Treat layout collisions, truncated text, and scene overlap as build errors, not polish issues.

## Visible Progress Plan

For every video run, keep a visible checklist so the user can see where the work is up to. Create the checklist before starting, keep one step active at a time, and update it as each step finishes.

Use this checklist for a normal video run:

1. Locking the brief.
2. Designing the visual system.
3. Building the composition.
4. Rendering and reviewing the video.

What each step means:

- `Locking the brief.` Confirm deliverable, ratio, duration, language, tone, platform, script beats, and narration plan.
- `Designing the visual system.` Decide palette, typography, spacing, contrast, and scene rhythm before implementation.
- `Building the composition.` Write the HyperFrames composition, wire scenes to beats, and align motion to the narration.
- `Rendering and reviewing the video.` Validate, render, extract review frames, inspect them, fix issues, and deliver the MP4 path with verification results.

Only mark a step complete when the real file, render, or decision exists. If this is a repair run, start from the first relevant step instead of restarting the whole checklist.

## Default Workflow

1. Prepare the working files and audio if needed.

   - Keep source script, narration script, and asset paths explicit.
   - If narration is required, create the WAV locally and verify its duration before composing.

2. Write the HyperFrames composition.

   - Prefer small, readable scene blocks.
   - Keep subtitles or text overlays shorter than the spoken line they support.
   - Avoid decorative layers that do not help the message.

3. Validate before rendering.

   ```bash
   npx hyperframes lint
   npx hyperframes validate
   npx hyperframes inspect
   ```

   Fix every error. Treat any warning that affects readability, timing, or layout as a required revision.

4. Render to MP4 only after validation passes.

5. Extract early, middle, and late frames from the rendered video and review them under `.review/`.

6. Check for blank scenes, wrong timing, unreadable text, broken captions, layout drift, clipped elements, and audio mismatch.

7. Rerender after any visual or timing fix.

## Repair Workflow

If validation or frame review fails, repair the smallest failing scope first.

- Fix text overflow, timing drift, or scene overlap in the affected scene only.
- Revalidate before rerendering.
- Do not trust `render complete` alone.

## Subagent Breakdown

If the script is long, dense, or multi-section, use subagents for bounded sidecar tasks such as scene outline refinement, subtitle tightening, or review-frame inspection. Keep the parent agent responsible for the final composition, validation decisions, rendering, and delivery.

Use subagents only for well-scoped work that does not block immediate composition progress. Do not duplicate the same task in multiple places.

## Finish With Evidence

- Deliver the MP4 path and the verification result.
- Include which commands passed and whether frame review was clean.
- If any issue remains, name the exact scene or asset that still needs work.

## Rules

- Keep `HYPERFRAMES_BROWSER_PATH` set before HyperFrames commands.
- Keep outputs under `renders/` and review frames under `.review/`.
- Use a local WAV for Chinese narration and verify its duration with `ffprobe`.
- Keep the brief stable before composing.
- Keep the visual system consistent across the whole video.
- Keep on-screen text shorter than the voiceover.
- Use `fromTo` for transitions that change opacity, scale, or blur.
- Run lint, validate, and inspect before rendering.
- Treat layout drift, unreadable text, broken captions, and blank scenes as blockers.
- Treat frame review as mandatory even when rendering succeeds.

## Acceptance Criteria

- The final video is rendered as MP4 and saved under `renders/`.
- Validation has passed with no blocking errors.
- Early, middle, and late review frames have been checked.
- Scene timing matches the script or narration.
- Text is readable at the target platform size.
- The final answer includes the MP4 path and the verification result.
