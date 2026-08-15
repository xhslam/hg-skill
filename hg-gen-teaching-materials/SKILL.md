---
name: hg-gen-teaching-materials
description: Use when turning problem solutions, technical explanations, physics/engineering derivations, exam answers, or rough notes into layered Chinese teaching materials, handouts, lecture notes, or tutorial-style explanations that need visible problem-reading traces, formulas, intuition, diagrams, plots, comparisons, and transferable rules.
---

# HG Teaching Materials

## Overview

Use this skill to transform a terse answer or rough derivation into a teaching handout that feels like a patient blackboard explanation: first build the ground, then extend, compare sideways, and move to the next related problem.

The output should not merely solve the problem. It should teach the reader how to think through this class of problems next time.

The target effect is a visible teaching process: the reader should see how the problem is read, where the hidden condition is, why a coordinate/moment point is chosen, what each curve or force means, and why an apparently possible result is physically unreachable.

Do not dump raw private chain-of-thought. Convert the reasoning into a concise **可见解题轨迹**: a polished teaching narrative that says what was checked and why, without exposing messy scratchpad deliberation.

Good visible trace:

```markdown
先读题，我抓到一个隐藏信息：题目没有直接给前后轴静载荷，但给了“最大爬坡度 40%”。这不是背景，它是用来反推质心位置的钥匙。

下一步选后轮接地点 O 取矩，因为 O 点处 Fz2 的力臂为 0，可以直接消掉一个未知量。
```

Bad visible trace:

```markdown
我现在有点纠结符号，先试一下这个方向，不对再改……
```

## Core Order

Default to this four-part progression unless the user gives a different structure:

1. **打地基**: establish variables, forces, assumptions, coordinate/sign conventions, and the first equation.
2. **引申**: explain why each term exists, what changes under nearby conditions, and how the same method adapts.
3. **横向对比**: compare adjacent cases in tables, formulas, feedback directions, limiting conditions, or graphs.
4. **第二题 / 下一题**: connect the first result to the next concept, especially when the next problem depends on the same hidden principle.

Use section titles that name the concept and the purpose, for example:

- `一、第一题完整受力图与“对后轮取矩”`
- `二、第三问的几何解释 - 为什么 12 m/s^2 永远到不了`
- `三、推广到后驱 (FR) 与四驱 (4WD)`
- `四、万有特性图与经济车速`

When the source is a homework file, lecture note, screenshot, PDF, or Word document, first extract the visible problem statement and restate it in a compact "读题抓手" block:

```markdown
读题抓手:
1. 直接给出的量: ...
2. 没直接给但必须求出的量: ...
3. 隐藏条件: ...
4. 本题真正的限制: 不是发动机，而是...
```

## Teaching Rhythm

For every major concept, use this rhythm:

1. State what is being analyzed in plain language.
2. List the objects, forces, variables, or constraints.
3. Explain the strategic choice: why this moment point, coordinate system, graph, or comparison is useful.
4. Put fragile sign/arm/direction details into a table.
5. Derive the formula in one or two compact steps.
6. Immediately explain the physical meaning of each important term.
7. Add a strong one-sentence conclusion.
8. Add a memory rule, transferable rule, or "what changes if..." extension.

Before the formal derivation, add a short **我先怎么想** paragraph when it helps:

- `我先不急着代数值，因为题目没有给静态轴荷。真正要先解决的是质心位置。`
- `我先把所有关键量都写成加速度 a 的函数，这样第三问能直接变成几何问题。`
- `第二题不是背“高速省油”，而是要找到发动机经济区和整车阻力曲线的交点。`

Never leave a formula alone. A formula must be followed by an interpretation such as:

- `第二项把第一项扣掉了，所以...`
- `分母从加号变成减号，正好对应反馈方向反转。`
- `再向右走一步，所需就超过所能给，所以...`
- `这个结论不是永远成立，它成立的前提是...`

## Visual-First Requirement

When the task involves physics, engineering, mechanics, vehicles, circuits, thermodynamics, charts, or process workflows, include visuals as first-class explanation objects, not decoration.

If the deliverable format allows images (DOCX, PDF, HTML, slides, Markdown with images), generate actual clean diagrams or plots and place them next to the derivation. Use vector-like shapes, Mermaid, SVG, matplotlib, reportlab, python-docx drawing/image insertion, or another reliable tool. If the current medium is plain text only, provide a graph-in-words version and a clear plan for the visual.

Minimum visual expectations:

| Problem type | Required visual | What the visual must show |
|---|---|---|
| Force / moment / vehicle dynamics | Complete force diagram | Object, coordinate direction, dimensions, force names, moment point, driven axle |
| Load transfer / feasibility | Curve or line plot | Key quantities as functions of acceleration/time/speed, feasible and impossible intersections |
| Slope / ramp | Inclined free-body diagram | `G sinα`, `G cosα`, normal reactions, height arm, wheelbase arm |
| Fuel economy / engine map | Map or conceptual contour plot | economic zone, external characteristic, city point, highway point, over-speed point |
| Comparison question | Table plus mini schematic | what changes, formula change, intuition, conclusion |

For visuals, prefer labels that teach:

- `蓝线 Fz1: 前轴载荷，每 1 m/s^2 向后转移多少`
- `绿线 ma: 驱动需求`
- `橙线 μFz1: 附着上限`
- `红点: 真实附着极限`
- `粉点: 载荷相等所需状态，但在物理上到不了`

Do not use generic unlabeled arrows or decorative charts. Every arrow, line, point, and shaded area must have a role in the explanation.

## Diagram-Backed Derivation Pattern

For mechanics and vehicle problems, use this sequence:

1. **完整受力图**: draw or describe all forces before writing equations.
2. **选点理由**: say why this moment point removes an unknown.
3. **力矩表**: list every force, direction, arm, and contribution.
4. **一行方程**: write the compact equilibrium equation.
5. **项解释**: explain each term as static support, load transfer, slope component, or friction limit.
6. **几何图解**: if feasibility is involved, plot the relevant functions and mark intersections.
7. **物理结论**: say not only the number, but whether the state can actually occur.

Example for load-transfer feasibility:

```markdown
把所有关键量都画成 a 的函数:

- 蓝线 Fz1 = 13500 - 375a: 前轴载荷，随着加速下降。
- 紫线 Fz2 = 4500 + 375a: 后轴载荷，随着加速上升。
- 绿线 ma: 想要的驱动力，随着 a 增大。
- 橙线 μFz1: 前轮能给的附着上限，随着 a 增大反而下降。

红点是 ma 与 μFz1 的交点，也就是真实最大加速度。
粉点是 Fz1 与 Fz2 的交点，也就是前后轴载荷相等。
粉点远在红点右边，所以不是算不出来，而是地面根本不允许车走到那里。
```

## Blackboard Tables

Use tables whenever the reader could confuse signs, directions, cases, or meanings.

For force and moment problems, prefer:

| 力 | 大小 | 方向 | 力臂 | 力矩贡献 |
|---|---|---|---|---|

For comparisons, prefer:

| 情况 | 核心变化 | 公式变化 | 直觉 | 结论 |
|---|---|---|---|---|

For graph explanations, prefer bullet lines plus named points:

- 蓝线: ...
- 紫线: ...
- 绿线: ...
- 橙线: ...

**关键交点**:

1. 红点: ...
2. 粉点: ...

For generated teaching materials, use tables as the "blackboard skeleton" around visuals:

- Before a derivation: variable / meaning / value / unit table.
- During a moment equation: force / size / direction / arm / moment contribution table.
- Before a comparison essay: condition / energy flow / engine operating point / main loss / conclusion table.
- After a solution: answer summary table.

## Language Style

Write in clear Chinese with a teaching tone: precise, direct, vivid, and slightly conversational.

Use concrete physical verbs for abstract math:

- `抬前轴`
- `压前轴`
- `扣掉`
- `顶上去`
- `跑到上方`
- `救不回来`
- `注定不可达`
- `一眼可见`

Use "直觉点" paragraphs for ideas students often compute correctly but do not understand physically.

Good pattern:

> 这是一个直觉点 - 可以想象急加速时车头会抬起来，正是这个力矩在起作用。

Avoid generic textbook filler such as:

- `由此可见`
- `综上所述`
- `根据相关理论`
- `具有重要意义`

## Formula Rules

Keep derivations short and readable. Use LaTeX for equations:

```markdown
$$F_{z1}L - mgb + mah_g = 0$$

$$F_{z1} = \frac{mgb - mah_g}{L}$$
```

After each formula, name the role of important terms:

- Which term is static support?
- Which term is load transfer?
- Which term changes sign on slope, braking, or reverse direction?
- Which denominator/numerator change marks the physical feedback?

When extending formulas across cases, show the structural change rather than re-deriving everything from zero.

Example:

```markdown
FF 前驱: 驱动轴 = 前轴。加速时前轴载荷下降，附着力下降 -> 负反馈。

FR 后驱: 驱动轴 = 后轴。加速时后轴载荷上升，附着力上升 -> 正反馈。
```

## Graph-In-Words Rule

When a graph matters but no image is provided, describe it as geometry:

1. Say what each line represents.
2. Say its starting point and slope if available.
3. Identify the intersection points.
4. Explain what walking left or right on the graph means physically.
5. End with the impossibility or feasibility conclusion.

Use phrases like:

- `粉点远在红点右边`
- `地面根本不允许走到那么远`
- `绿线跑到橙线上方`
- `所需 > 所能给`

If you are creating a PDF, DOCX, HTML, slide deck, or image-based handout, graph-in-words is not enough. Generate the actual graph unless tool or environment limitations make that impossible. If generation fails, state that and keep the graph-in-words explanation.

For curve explanations, always name:

1. x-axis physical meaning.
2. y-axis physical meaning.
3. each line's formula or qualitative law.
4. each highlighted point's meaning.
5. the feasible region and impossible region.

For engine economy maps, use this teaching structure:

```markdown
万有特性图读法:
- 横轴: 发动机转速 n。
- 纵轴: 转矩 T。
- 等高线: 比油耗 g_e，数字越小越省。
- 中心岛: 最经济区。
- 城市点: 小负荷、低转速/频繁变化，偏离经济区。
- 高速巡航点: 稳定中等负荷，靠近经济区。
- 超高速点: 外特性附近，高负荷高转速，空气阻力把所需功率顶上去。
```

## Extension Rules

After solving the local problem, push one layer outward:

- Slope: split gravity into perpendicular and parallel components, then explain both moment arms.
- Drive layout: change the driven axle and feedback direction; if discussing FF, also briefly compare FR and 4WD.
- Braking: reverse the inertial/load transfer direction.
- Economy/speed: connect engine maps with vehicle resistance curves.
- Feasibility: compare the required state against friction, power, geometry, or thermal limits.
- Visualization: after deriving a formula, ask whether a diagram would make the limiting mechanism visible. If yes, include it.

Do not overgeneralize. State the condition under which the common saying holds.

Example:

```markdown
所以“后驱加速好”这句话是有前提的：质心不能严重靠前，后轴必须先有足够静态载荷，正反馈才有发挥空间。
```

## Ending Pattern

End each major block with one of these:

- **一句话总结**: compress the mechanism into one sentence.
- **记忆口诀**: give an operation rule the student can reuse.
- **判定标准**: say how to decide this type of problem next time.
- **本题结论**: state the numerical or conceptual answer decisively.

Good endings:

- `碰到斜坡，先把重力拆成两份。`
- `经济车速不是发动机单独决定的，而是发动机万有特性图和整车阻力曲线共同决定的交点。`
- `粉点远在红点右边，所以这个状态不是算不出来，而是物理上到不了。`

For homework or lecture-note deliverables, end with a **教师可讲版总结**:

```markdown
这题真正训练的不是代公式，而是三件事:
1. 会从隐藏条件反推缺失参数。
2. 会用受力图和取矩点消掉未知量。
3. 会用几何交点判断“算出来”和“到得了”是不是一回事。
```

## Quality Checklist

Before finalizing, check:

- The answer starts from assumptions and symbols before formulas.
- The output includes a visible teaching trace, not just final equations.
- Every sign convention or moment direction is explicit.
- Every force/moment problem has a complete force diagram or a precise diagram-in-words fallback.
- Every feasibility/impossibility conclusion is supported by a curve, intersection, or explicit inequality.
- At least one table is used when there are multiple forces or cases.
- Every important formula has an immediate physical interpretation.
- The explanation includes at least one intuition paragraph.
- If the deliverable is DOCX/PDF/HTML/slides, visuals are generated as actual figures when feasible.
- Every generated figure has labeled axes/forces/points and is referenced in the text.
- The output contains transferable rules, not only the answer.
- The conclusion is decisive and tied to the original question.
