---
name: hg-physics-review
description: Turn a physics exam paper, worksheet, answer sheet, or marked student paper (PDF or images) into four accurate Chinese PNG review sheets covering paper diagnosis, physical models and formulas, solution methods, and error correction or transfer practice. Use when the user provides a physics paper and asks for four review images, exam analysis cards, formula sheets, method summaries, or personalized wrong-question revision.
---

# HG Physics Review

## Overview

Convert one physics paper into four portrait review images. Adapt the content to the evidence available: a blank paper produces paper-level analysis and predicted traps; an answered or marked paper produces personalized diagnosis.

Render text, equations, and layout code-native. Do not use image generation for the page layout or factual diagrams. Preserve an original diagram by cropping it from the paper when its geometry matters.

## Workflow

1. Read every supplied page before drafting. Record the paper title, grade or course, question numbers, scores when visible, diagrams, units, and any student or teacher marks.
2. Classify the input:
   - `blank`: questions only
   - `answered`: student answers are visible but correctness is not marked
   - `marked`: scores, corrections, or teacher marks are visible
3. Build an evidence table internally with one row per question: question number, topic, model, law or formula, difficulty, answer evidence, correctness evidence, and likely error cause. Never infer a student's error from a blank response unless the image clearly shows it.
4. Select the highest-learning-value content. Cover the paper rather than mechanically listing every question. Keep exact question references so the user can return to the source.
5. Create exactly four pages:
   - Page 1 — **试卷全景诊断**: paper structure, topic and score distribution, difficulty, ability demands, and priority order.
   - Page 2 — **核心模型与公式**: 4–6 model cards with recognition cues, laws, equations, units, sign conventions, and applicability boundaries.
   - Page 3 — **典型题解法链**: 3–5 representative question cards using `对象 → 过程/状态 → 规律 → 方程 → 检验`. Prefer transferable methods over full answer copying.
   - Page 4 — **错因与迁移训练**:
     - For `marked`, show evidence-backed errors, causes, corrected pivots, and one short variant prompt per error.
     - For `answered`, label conclusions as provisional and separate answer evidence from inferred risk.
     - For `blank`, show predicted traps, checking rules, and retrieval or variant prompts; do not call them personal mistakes.
6. Use concise Chinese. Normalize formulas to readable Unicode where practical, for example `Eₖ = ½mv²`, `U = IR`, `Δp = FΔt`. Define every uncommon symbol and keep units explicit.
7. If a source figure is essential, crop it without altering geometry and pass its absolute path as `image_path`. Do not fabricate circuit connections, ray paths, scale readings, or force directions.
8. Write a JSON spec following [references/spec-schema.md](references/spec-schema.md), then render:

```bash
python3 scripts/render_physics_review.py --spec /absolute/path/spec.json --output-dir /absolute/path/output
```

9. Inspect all four PNGs visually. Revise the spec and rerender if text is too small, a formula is ambiguous, a diagram is unreadable, or a card lacks a source question reference.

## Visual Rules

- Use a clean blue-and-amber physics workbook style with strong information hierarchy.
- Keep each page to 3–6 cards and each bullet to one idea.
- Use color to distinguish evidence, method, warning, and self-test—not as decoration.
- Never squeeze overflow into illegible type. Reduce content before reducing body text below 18 px.
- Keep original question numbering, numerical values, significant figures, vector directions, and SI units exact.

## Output

Save these stable filenames:

- `page-1-paper-map.png`
- `page-2-models-and-formulas.png`
- `page-3-methods-and-solutions.png`
- `page-4-errors-and-transfer.png`

## Check

Before finishing, verify:

- all source pages were considered and all claims are traceable to visible evidence
- the input mode is correctly identified
- no guessed score or personal error is presented as fact
- formulas, symbols, units, signs, and question references are accurate
- exactly four PNGs exist with the stable names
- no text is clipped and each embedded source figure remains legible
