---
name: hg-english-review
description: Use when the user gives 40 vocabulary items and wants matching English/Chinese workbook review images for English-to-Chinese, Chinese-to-English, and mixed-direction drills.
---

# HG English Review

## Overview

Use this skill to turn 40 vocabulary items into four study-sheet images in the same orange two-column table style as the reference.

Do not use image generation for the layout. This is text-heavy and should be rendered code-native so spelling, spacing, and alignment stay exact.

## Workflow

1. Normalize the 40 items in order. Preserve exact spelling, hyphens, and multiword expressions.
2. If the user only provides English words, translate them into concise Chinese study meanings.
3. Split the list into two 20-item blocks: 1-20 and 21-40.
4. Render four PNGs as full 40-item drills:
   - page 1: all 40 items, known English / write Chinese meaning
     - left half: items 1-20 show English words; Chinese meaning cells are blank
     - right half: items 21-40 show English words; Chinese meaning cells are blank
   - page 2: all 40 items, known Chinese meaning / write English
     - left half: items 1-20 show Chinese meanings; English word cells are blank
     - right half: items 21-40 show Chinese meanings; English word cells are blank
   - page 3: mixed direction
     - left half: items 1-20 show English words; Chinese meaning cells are blank
     - right half: items 21-40 show Chinese meanings; English word cells are blank
   - page 4: mixed direction reversed
     - left half: items 1-20 show Chinese meanings; English word cells are blank
     - right half: items 21-40 show English words; Chinese meaning cells are blank
5. Keep the reference styling:
   - orange header band
   - pale peach alternating rows
   - thin grid lines
   - centered row numbers
   - checkbox column on the far right of each half
   - no decorative extras
6. Keep text inside cells. If a long word or meaning risks clipping, shrink the font slightly before changing the layout.
7. Save the four images with stable names in the workspace or the requested folder:
   - `page-1-english-to-chinese.png`
   - `page-2-chinese-to-english.png`
   - `page-3-mixed-english-then-chinese.png`
   - `page-4-mixed-chinese-then-english.png`

## Rendering

Use `scripts/render_review_sheets.ps1` for deterministic layout. It expects a JSON spec shaped like:

```json
{
  "blocks": [
    { "words": ["...", "..."], "meanings": ["...", "..."] },
    { "words": ["...", "..."], "meanings": ["...", "..."] }
  ]
}
```

Each block must contain exactly 20 words and 20 meanings.

## Check

Before finishing, verify:

- all 40 items are present
- the two 20-item blocks are in the right order
- the four exported PNGs exist with the expected stable names
- no English word is truncated
- no Chinese meaning spills outside its cell
