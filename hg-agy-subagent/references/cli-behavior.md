# agy CLI 实测行为记录

环境：macOS，`/Users/apple/.local/bin/agy`，版本 1.4.2，实测日期 2026-10-18。

## 1.4.4 补充验证（2026-10-21）

以下结论修正后文 1.4.2 历史记录的概括，模型列表仍需运行时查询。

- `--output-format stream-json` 实际 envelope 为 `{event:"init", conversation_id, init:{cwd,tools,permission_mode}}`、`{event:"step_update",step_update:{step_index,state,step_type,...}}`、`{event:"result",result:{status,response,...}}`，不是 flat `type` 结构。
- `agent_response` 文本位于 `step_update.text_delta`；工具事件为 `step_type:"tool"`，含 `tool_name`、`tool_info.parameters`，失败可能含 `tool_info.error`。
- 未加 `--dangerously-skip-permissions`，在 `request-review` 模式下读取一个不存在文件仍发生了工具尝试，返回 `file does not exist`。因此 headless 并非默认禁用全部工具，权限依赖 agy 自有配置和工具类型。
- `--log-file`、`--disable-slash-commands`、`--sandbox` 在当前帮助中存在；`--sandbox` 只标注终端限制，未核实完整覆盖。
- 2026-10-22 复核：带 `--json-schema` 的纯文本任务仍出现过模型调用 `command` 被 auto-deny（拿回空正文、`status` 仍为 `SUCCESS`），所以“纯文本任务也要写不要执行任何命令”这条约束在当前版本依然必要。
- Gamma 原生面板仅对 `AgyStart` 发起的受管任务生效，旧脚本/Bash 调用不会自动创建原生 Tab。源码已实现不等于当前运行 App 已安装该版本。
- 目前核实了纯文本正常路径与不存在文件的读取失败；没有据此证明所有工具都会上报完整成功结果或权限事件。

## 平台与可移植性（2026-10-22）

Skill 会被下载到 macOS 与 Windows，因此包装脚本不再写死 `~/.local/bin/agy`，也不再假设对方有 bash / python3 / perl。

已在本机（macOS 26, darwin25, agy 1.4.4, bash 3.2.57, jq / python3 / perl 均存在）验证 `scripts/ask-agy.sh`：

| 场景 | 结果 |
| --- | --- |
| 位置参数 + 中文提示词 | 正文正常，`status=SUCCESS`，退出 0 |
| stdin 传提示词 | 正常，退出 0 |
| `jq` 被失效遮蔽 | 自动降级到 python3 解析，结果一致 |
| `jq` 与 `python` 全部缺失 | 原样输出信封，靠 `grep` 粗判 `status` 得出退出 0 |
| 不存在的模型名 | 退出 1，stderr 带 `status=ERROR` 与 `invalid model selection` |
| 需要 `command` 权限的 schema 任务 | 退出 3，提示 headless 无法弹窗授权 |
| `-t 1` | 退出 124，提示 print 超时 |
| 环境里找不到 agy | 退出 2，输出安装与 `AGY_BIN` 排查提示 |

Windows 侧未在本机执行过：`scripts/ask-agy.ps1` 只做了静态审阅，没有在真实 Windows 上跑过。首次在 Windows 使用时应按下面清单验一次，发现问题按实际情况修，不要先把结论当已核实：

1. `agy --version` 与 `agy models` 能直接在同一个 PowerShell 里执行。
2. `& scripts\ask-agy.ps1 -Model gemini-3.8-flash-low "只回答两个字：收到"` 返回中文不乱码、退出 0。
3. 管道输入 + 中文：`"只回答两个字：收到" | & scripts\ask-agy.ps1 -Model gemini-3.8-flash-low`（重点看编码）。
4. `-Schema .\schema.json` 传文件路径可用；含空格路径也要试一次（验证参数转义）。
5. `-Timeout 5` 能触发硬看门狗并返回 124。
6. 若 `agy` 在 PATH 上是 `agy.cmd` 而非 `.exe`，确认脚本包 `cmd.exe /c` 后仍能拿到 stdout 与退出码。

Windows 已知风险点（脚本已按此实现，但尚未在真机确认）：PowerShell 5.1 管道默认非 UTF-8、`Start-Process -ArgumentList` 的引号拆分、`.cmd` 垫片不能直接被 CreateProcess 启动、ExecutionPolicy 拦脚本。

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
