---
name: hg-break-things-down
description: Use when the user asks to break a learning goal or work task into actionable steps and concept layers, including 拆解任务, 分解任务, 横向拆解, 纵向拆解, 捋清思路, 自学方法, 学习计划拆分, or a structured self-teaching breakdown.
---

# HG Break Things Down

## Overview

Help the user turn a learning or work goal into small executable units, layered concepts, a practice path, and clear checkpoints.

## Workflow

1. Clarify the target and constraints.
Collect the goal, scope, deadline, current level, available time, and desired output. Ask only for information that blocks decomposition.

2. Do horizontal decomposition.
Split the task into the smallest independently executable units. Prefer units that are both small and complete, then arrange them from easy to hard.

3. Do vertical decomposition.
Split knowledge into layers such as:
- core concept
- logic or process
- language or tool implementation
- environment, usage, or scenario

Separate universal understanding from tool-specific details.

4. Map dependencies.
Link each horizontal unit to the layers it depends on. Mark prerequisites, missing knowledge, and likely bottlenecks.

5. Build the practice path.
Sequence the units from low difficulty to normal difficulty. Use "read first, then write" or "observe first, then reproduce" when appropriate.

6. Add checkpoints and iteration.
Define how the user can verify each unit. If the user gets stuck, reduce unit size, revisit prerequisites, and redraw the concept map.

## Output Template

Use this structure in the response.

```text
目标:
约束/资源:
横向拆解:
- ...
纵向拆解:
- ...
依赖与先修:
最小可执行单元:
练习路径:
检查点/验收:
```

## Heuristics

- If the task feels hard, treat it as too large and split it further.
- Prefer fewer, clearer layers over exhaustive detail.
- If the user feels stuck, shrink the unit size and slow the pace.
- If concepts are tangled, separate by layer before practicing.
- Keep each step observable and testable.

## Example follow-up questions

Ask only when needed:
- 你想完成的具体目标是什么？
- 你当前的水平和可投入时间是多少？
- 你希望最后产出的形式是什么？
