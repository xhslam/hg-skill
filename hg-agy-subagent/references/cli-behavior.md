# agy CLI 实测行为记录

环境：macOS，`/Users/apple/.local/bin/agy`，版本 1.4.2，实测日期 2026-10-18。

## 可用模型

```
gemini-3.8-flash-high      Gemini 3.8 Flash (High)
gemini-3.8-flash-medium    Gemini 3.8 Flash (Medium)
gemini-3.8-flash-low       Gemini 3.8 Flash (Low)
claude-sonnet-4-6          Claude Sonnet 4.6 (Thinking)
claude-opus-4-6-thinking   Claude Opus 4.6 (Thinking)
gpt-oss-120b-medium        GPT-OSS 120B (Medium)
```

模型清单随 CLI 更新变化，使用前以 `agy models` 输出为准。

## 关键命令行参数

| 参数 | 作用 |
| --- | --- |
| `-p` / `--print` | 单次非交互执行并打印结果 |
| `--output-format text\|json\|stream-json` | 输出形态，默认 text |
| `--input-format text\|stream-json` | stream-json 需要配合 `--output-format stream-json` |
| `--model` | 指定模型 |
| `--effort low\|medium\|high\|xhigh\|max` | 推理强度 |
| `--json-schema` | JSON Schema 字符串或文件路径，强制结构化输出 |
| `--print-timeout` | 超时，`0` 表示一直等到本轮结束（默认值） |
| `--conversation` / `--continue` | 续接指定会话 / 最近会话 |
| `--mode accept-edits\|auto\|plan` | 执行模式 |
| `--dangerously-skip-permissions` | 自动批准全部工具权限 |
| `--sandbox` | 限制终端能力的沙箱 |
| `--add-dir` | 追加工作目录（可重复） |

子命令：`agent`/`agents`、`changelog`、`install`、`mcp`、`models`、`plugin`、`remote-control`、`update`、`mic-serve`。

## 实测结果

### 输出信封（`--output-format json`）

```json
{"conversation_id":"316c637a-...","status":"SUCCESS","response":"OK\n","duration_seconds":3.14,"num_turns":1,
 "usage":{"input_tokens":29956,"output_tokens":95,"thinking_tokens":94,"cache_read_tokens":0,"total_tokens":30051}}
```

要点：`status` 是唯一的成功判据；`response` 自带尾部换行；单次调用 input_tokens 约 30k，是可观固定开销。

### 结构化输出（`--json-schema`）

`response` 里可能混有人类可读的解释文本，但信封顶层会额外回填 `structured_output`（以及回显 `json_schema`），解析应以 `structured_output` 为准，不要在正文里找 JSON。

实测样例返回：

```json
{"structured_output":{"words":["今天","天气","很","好"]},"num_turns":2}
```

`num_turns` 在带 schema 时可能大于 1，属于正常现象。

### stdin 传提示词

| 写法 | 行为 |
| --- | --- |
| `echo "x" \| agy` | 正常读取 stdin 作为提示词并输出结果 |
| `echo "x" \| agy -p` | 打印 usage，退出 0，不执行 |
| `echo "x" \| agy -p -` | 把 `-` 当提示词，返回一句通用寒暄，**不读 stdin** |
| `echo "x" \| agy --output-format json` | 正常，且返回 JSON 信封 |

结论：无 `-p` 且 stdin 非 tty 时才读 stdin。包装脚本据此统一走 stdin，规避 argv 长度与引号问题。

### 工具权限（headless）

任务需要写文件但未授权时：

- 退出码 **0**
- 正文只有一句：`jetski: no output produced — a tool required the "write_file" permission that headless mode cannot prompt for, so it was auto-denied. Add an allow-rule under permissions.allow in settings.json ... Alternatively, re-run with --dangerously-skip-permissions`
- 文件实际未被创建

加 `--dangerously-skip-permissions` 后同一任务正常写入。注意 `--mode plan` 不能绕过这一点：计划模式仍可能因 `command` 权限被拒并返回同样的空结果提示。

所以「退出码 0」不代表成功，必须以正文与 `status` 判断。

### 错误与退出码

| 情况 | 退出码 | 输出 |
| --- | --- | --- |
| 模型名不存在 | 1 | `error: invalid model selection (...)`，后附可用模型列表 |
| 正常完成 | 0 | 结果 |
| headless 权限被拒 | 0 | 上述空结果提示（危险） |
| `--print-timeout` 到点 | 0 | 部分输出 + `[agy] print timeout after Ns with turn in progress; returning partial output` |

### 并发与耗时

- 单次简单问答：约 3–4 秒。
- 3 个并发同时跑：总墙钟 10.6 秒，单条 3.3 / 3.8 / 4.0 秒，未报错。
- `--print-timeout 5s` 的调用实际在约 11 秒后返回（进程收尾有额外开销），说明超时是软约束，需要外层看门狗兜底。

### 会话续接

`-p "记住 42" --output-format json` 拿到 `conversation_id` 后，用 `--conversation <id>` 追问「我刚让你记住什么」，返回 `42`。续接可用，且省掉重复背景。

### stream-json

每行一个事件：`init`（含 cwd、tools、permission_mode）、`step_update`（含 `text_delta`）、`result`（最终信封）。需要流式展示或调试时用它，日常批处理用 `json` 就够。
