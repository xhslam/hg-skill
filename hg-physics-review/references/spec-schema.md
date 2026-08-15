# Physics review render spec

The renderer accepts UTF-8 JSON with exactly four `pages`, in output order.

```json
{
  "paper_title": "高一物理期中复习",
  "scope": "必修第一册 · 第 1–18 题",
  "input_mode": "marked",
  "pages": [
    {
      "title": "01 试卷全景诊断",
      "subtitle": "先看结构，再决定复习顺序",
      "metrics": [
        {"label": "总分", "value": "100"},
        {"label": "重点模块", "value": "动力学"},
        {"label": "优先复习", "value": "受力分析"}
      ],
      "sections": [
        {
          "heading": "模块分布",
          "tag": "结构",
          "question_refs": "题 1–6、12、16",
          "items": [
            "运动学：图像与匀变速直线运动",
            "动力学：受力分析与牛顿第二定律"
          ],
          "formula": "",
          "note": "复习顺序：先补受力图，再练联立方程",
          "image_path": ""
        }
      ]
    }
  ]
}
```

## Fields

- Root:
  - `paper_title`: required string.
  - `scope`: optional source range or course.
  - `input_mode`: required; `blank`, `answered`, or `marked`.
  - `pages`: exactly four objects.
- Page:
  - `title`, `subtitle`: required strings.
  - `metrics`: optional; 0–4 `{label, value}` objects.
  - `sections`: required; 3–6 card objects.
- Section:
  - `heading`: required.
  - `tag`, `question_refs`, `formula`, `note`, `image_path`: optional strings.
  - `items`: required array of concise strings.

Use an absolute `image_path`. Crop source figures before rendering. Prefer at most one figure per card and no more than two figure cards per page.

Keep a card within roughly 8 wrapped text lines. If rendering reports overflow, shorten wording or split priorities across cards while keeping exactly four pages.
