---
name: hg-after-work-review
description: Create an honest end-of-day self-review grounded in repository evidence and the user's lived workday. Use when the user asks for 下班复盘, 今日复盘, 工作复盘, 总结今天做了什么, 盘点今天推进, 今日代码总结, 明天先做什么, or a private engineering reflection that should inspect git status, recent commits, changed files, and relevant diffs before asking only the necessary follow-up questions and producing a truthful review plus tomorrow's first concrete action.
---

# After Work Review

## Overview

Run a private, honest end-of-day review for the user. Treat this as a self-calibration workflow, not as a polished status report and not as a performance report for a manager unless the user explicitly asks for that format.

Default to Chinese unless the user asks for another language.

The review should combine two sources:

1. Repository evidence: git status, today's commits, changed files, affected areas, and selective diffs.
2. Human context: what the user actually intended, struggled with, postponed, learned, or needs to do first tomorrow.

Repository facts are the starting point, not the whole truth. Git can show activity, but it cannot prove value, explain blockers, or reveal invisible work such as debugging, design thinking, reading, meetings, waiting, coordination, or failed attempts.

## When To Use

Use this skill when the user wants any of the following:

- 下班复盘 / 今日复盘 / 工作复盘
- 总结今天做了什么 / 盘点今天推进
- 今日代码总结 / 今天改了什么
- 帮我复盘今天开发进展
- 明天先做什么 / 给我一个明早开工动作
- A private end-of-day reflection grounded in a code repository

Also use this skill when the user asks for a review of today's work and the current environment is likely inside or near a git repository.

## Non-goals

This skill does not:

- write a manager-facing daily report by default
- inflate work into achievements
- judge productivity by commit count, file count, or lines changed alone
- create commits, push code, revert work, stash changes, or modify the repository
- perform a code review unless the user explicitly asks for one
- expose secrets, credentials, tokens, private URLs, or sensitive code snippets found in diffs
- pretend unfinished work is complete
- replace the user's own reflection when repository evidence is thin

## Evidence Policy

Use repository evidence first, then interpretation.

Evidence hierarchy:

1. Direct repository evidence: `git status`, commits, staged changes, unstaged changes, changed files, diff summaries.
2. Nearby repository context: branch name, commit messages, issue IDs in branch or commits, file paths, tests or docs touched.
3. User statements: what they say they intended, struggled with, learned, delayed, or finished.
4. Reasonable interpretation: only when clearly marked as inference.

Never treat git activity as proof of meaningful progress. A large diff may be churn. A small diff may be the result of hard debugging. No commit does not mean no work.

If a diff appears to contain secrets, credentials, tokens, private keys, personal data, or private endpoints:

- do not reproduce the sensitive value
- mention the risk generically
- recommend reviewing or removing it before commit if relevant

## Visible Progress Plan

For every review, keep a visible checklist so the user can see where the work is up to. Create the checklist before starting, keep one step active at a time, and update it as each step finishes.

Use this checklist for a normal review:

1. 先看证据。
2. 再找缺口。
3. 问关键问题。
4. 输出复盘。

What each step means:

- `先看证据。` Inspect repository state and today's visible activity.
- `再找缺口。` Identify what git cannot explain.
- `问关键问题。` Ask only the few questions needed to make the review truthful.
- `输出复盘。` Produce the short version, full version, and tomorrow's first concrete action.

Only mark a step as complete when the corresponding evidence, question, or review section actually exists.

If this is a no-git or no-evidence review, start from the first relevant step instead of pretending repository inspection succeeded.

## Default Workflow

### Step 0: Establish Context

Before writing the review, determine:

- whether the current directory is inside a git repository
- the current branch, if available
- the intended review window
- whether the user asked for private reflection or manager-facing summary

Default to private reflection.

If the user gives no date range:

- First choice: today in local time.
- Fallback: the last 24 hours if today's evidence is too thin.

If the user gives no repository path:

- Use the current working directory if it is inside a git repository.
- If the current directory is not a git repository, say so plainly and switch to a question-led review.

If the user gives no work context:

- Gather repository evidence first if available.
- Then ask targeted questions only for the biggest missing pieces.

If the user asks to “直接写” or “不要问我问题”:

- Produce a best-effort review from available evidence.
- Mark uncertain interpretations explicitly.
- Do not invent motives, value, blockers, or completion status.

### Step 1: Gather Repository Evidence

When inside a git repository, inspect the current workday before writing conclusions.

Start with read-only evidence:

```bash
git rev-parse --is-inside-work-tree
git branch --show-current
git status --short
```

Then inspect recent commits for today or the chosen window:

```bash
git log --since="today 00:00" --oneline --decorate --stat
```

If that is too sparse, use a last-24-hours fallback:

```bash
git log --since="24 hours ago" --oneline --decorate --stat
```

Inspect uncommitted work:

```bash
git diff --stat
git diff --name-status
git diff --cached --stat
git diff --cached --name-status
```

Read full diffs selectively only when they clarify:

- what was actually shipped, fixed, or removed
- whether work is exploratory, incomplete, or reverted
- whether there was rework or churn
- whether the next step is obvious from unfinished changes

Do not read every diff by default if summaries are enough.

### Step 2: Build An Evidence Snapshot

Before asking questions, make a private evidence snapshot with:

- branch name
- clean or dirty status
- today's commits, if any
- staged and unstaged files
- affected areas by path
- likely work themes
- incomplete or risky threads
- uncertainty level: high, medium, or low

This snapshot is for reasoning. In the final response, include only a concise evidence summary when useful.

### Step 3: Separate Activity From Progress

Classify the day into these buckets:

- clear progress: something finished, simplified, fixed, tested, documented, or made easier to continue
- partial progress: useful but not closed
- churn or rework: files changed but direction, stability, or completion is unclear
- invisible work: debugging, reading, design, meetings, decisions, waiting, coordination
- open risk: unresolved bug, failing test, unclear requirement, uncommitted risky change, blocked dependency

If evidence cannot support a bucket, mark it unknown instead of filling it with generic language.

## Questioning Rules

Git rarely explains the most important parts of a workday. Explicitly look for these gaps:

- What mattered most today?
- What consumed time without proportional output?
- What blocker or uncertainty slowed the work?
- Was there rework, interruption, waiting, or context switching?
- What is still not closed?
- What should happen first tomorrow morning?

Ask 3 to 5 targeted questions only when needed. Keep them short, specific, and easy to answer.

Do not ask generic questions that the evidence already answers.

Use question patterns based on the evidence:

If there are many file changes but no commits:

- 这些改动目前是接近完成，还是还在探索？
- 今天最想闭环的是哪个点？现在卡在哪里？
- 明早第一步是继续改代码、先跑测试，还是先确认需求？

If there are commits but unclear value:

- 这些提交里，哪个才是真正有价值的推进？
- 有没有一个提交只是试错或返工？
- 还有什么没有随着提交一起闭环？

If evidence is sparse:

- 今天主要做了哪一件事？哪怕没有留下代码痕迹。
- 时间主要花在哪个环节：调试、阅读、沟通、等待，还是切换任务？
- 明天最不能拖的第一件事是什么？

If the user appears tired or frustrated:

- 今天最消耗你的点是什么？
- 是任务本身难，还是来回切换或等待拖慢了你？
- 明天只做一个最小动作的话，应该是什么？

If the user asks for direct output without questions:

- skip questions
- write a best-effort review
- clearly mark uncertain parts

## Output Format

Always produce two versions unless the user asks for only one.

### Short Version

Use 5 bullets or fewer.

Include:

- 今日真正推进了什么
- 主要低效、阻塞或消耗是什么
- 仍未闭环的事项
- 一个判断修正或经验
- 明天第一优先级 / 明天开工第一步

### Full Version

Use this structure:

```markdown
## 今日实际推进
- ...

## 低效与干扰
- ...

## 未闭环事项与风险
- ...

## 一个经验或判断修正
- ...

## 明天第一优先级
- ...

## 明天开工第一步
- ...
```

The “明天开工第一步” must be a concrete physical action, not a vague intention.

Good:

- 打开 `src/auth/session.ts`，先复现登录过期问题，再记录触发条件。
- 先跑 `npm test -- auth`，确认今天的改动有没有破坏旧逻辑。
- 把接口字段差异列成 3 条，先发给后端确认。

Bad:

- 继续优化
- 尽快推进
- 提高效率
- 加强沟通
- 完成剩余工作

## Tone

Write like a clear private notebook for a competent engineer.

The tone should be:

- calm
- direct
- specific
- non-performative
- lightly reflective

Do not sound like:

- formal daily report
- HR self-evaluation
- motivational speech
- manager-facing status update
- blame-heavy postmortem

## Repair Workflow

If the user says the review is inaccurate, too generic, too harsh, too positive, or missing the point:

1. Separate evidence from interpretation.
2. Ask which part is wrong only if the correction is not obvious.
3. Revise the review using the user's correction as higher-priority context.
4. Preserve useful repository facts.
5. Remove unsupported claims.

If new repository evidence appears after the first review:

- update only the affected sections
- do not rewrite the entire review unless the interpretation changes substantially

## Fallback Strategy

If repository commands cannot be run because the environment blocks shell access, the path is unavailable, or git is not installed:

- explain the blocker briefly
- switch to a question-led review
- ask the user to paste any useful context, such as changed files, commit messages, or what they remember doing

If the user cannot or does not want to answer questions:

- produce a best-effort review from available context
- label it as evidence-limited
- keep the output modest

## Manager-Facing Mode

Only switch to manager-facing style if the user asks for 日报, 周报, 汇报, leader-facing, manager-facing, or similar.

In that mode:

- keep facts truthful
- remove overly private reflection
- keep blockers objective
- still avoid exaggeration

## Rules

- Be concrete, not motivational.
- Name uncertainty explicitly.
- Do not exaggerate progress.
- Do not convert activity into achievement.
- Do not hide rework.
- Do not treat an uncommitted diff as shipped work.
- Do not treat a commit as proof that the task is done.
- Explain waiting cost or switching cost when it mattered.
- Convert vague plans into one first physical action.
- Keep the review private-notebook style unless asked otherwise.
- Do not run destructive or state-changing git commands.
- Do not paste long diffs into the final review.
- Do not expose secrets, tokens, or private endpoints from diffs.

Avoid empty lessons such as:

- “要提高效率”
- “要加强沟通”
- “要做好规划”
- “继续保持”

Replace them with trigger-based lessons:

- “今天低效不是因为写得慢，而是接口字段没有先确认，导致后面调试成本变高。”
- “明天不要先大改，先用一个最小复现确认问题边界。”
- “这类任务下次应该先列验收条件，再开始改代码。”

## Acceptance Criteria

A completed review must satisfy all of these:

- Repository evidence was checked when available.
- Evidence limitations were stated when evidence was sparse or unavailable.
- The review separates activity from progress.
- The review separates effort from outcome.
- The review does not claim unfinished work is complete.
- Rework, waiting, blockers, or context switching are named when relevant.
- The short version is 5 bullets or fewer.
- The full version includes all required sections unless the user requested a shorter format.
- Tomorrow's first step is concrete enough to do immediately.
- No sensitive diff content, secrets, or private tokens are exposed.
- The final review answers the five good-outcome questions:
  - What truly moved today?
  - What was more expensive than it should have been?
  - What is still open?
  - What did I learn or correct?
  - What exactly do I do first tomorrow?
