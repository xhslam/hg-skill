# AGY CLI 行为与验证范围

## 2026-10-19：1.0.2 恢复项目开发定位（当前版本）

用户明确其用途是项目开发子 Agent，1.0.1 的仅文本限制不符合目标。本版恢复 `-d/--dir`、`-c/--conversation`，支持 `--mode accept-edits|auto|plan`，项目默认 accept-edits、600 秒；无 -d 则保留原文本模式。

项目契约允许读写代码、执行本地测试和构建。项目 cwd 不清理、不自动回滚；同项目并行优先 worktree 或不重叠范围，不强制所有任务使用临时目录。

默认使用 AGY 原生权限，不传跳过权限或强制 sandbox。可显式选择 `--sandbox`；`--dangerously-skip-permissions` 仅作为事先明确确认后的选项，运行时打印全部工具放行警告，不恢复含糊的 `--allow-tools` 别名。包装器不能拦截每个工具请求，也不自动把 AGY 授权桥接到 Gamma。

已再次读取本机 agy 1.4.2 帮助以核对参数；本轮没有实际委派模型或修改 AGY 权限配置。新增模拟 CLI 覆盖：指定路径、代码文件写入与真实本地 Python 校验、模式/会话透传、默认无 bypass、显式 bypass 警告、项目保留、失败后改动保留及模式参数边界。运行记录新增 cwd、task_kind、conversation_id、permission_mode、execution_mode 与 sandbox。

以下 1.0.1 的“不支持项目/会话”说明仅记录该历史版本，不适用于当前版本。Windows 测试已运行；macOS/Linux 分支未实机验证。模拟开发成功不代表真实 CLI headless 工具权限已配置好，需在用户授权的后续试跑中验证。

## 2026-10-19：1.0.1 封装加固

本轮环境为 Windows，确认 PATH 中存在 `agy.exe`，`agy --version` 为 1.4.2。已读取本机 `agy --help`，支持 JSON、Schema、stdin 相关选项、`--sandbox`、`--disable-slash-commands`、`--print-timeout` 和会话参数。本轮没有调用真实模型，没有验证实际工具隔离效果。

本机帮助将 `--dangerously-skip-permissions` 描述为自动批准全部工具请求；`--sandbox` 描述为启用终端限制。不能据此宣称网络或文件系统全隔离。

### 已修复的旧包装器问题

旧版 `ask-agy.sh` 在解析时读取了进程 rc 与 hard_timeout，但有效 SUCCESS 信封分支没有优先检查它们；软超时只在空正文分支识别。模拟测试可复现：进程失败、超时部分结果或 raw 空正文被返回为成功。

新版共用 Python 分类器，检查顺序为：取消 → 硬超时 → 软超时 → 权限拒绝 → 进程退出码 → 信封状态 → 内容完整性。raw 与 structured_output 不另设绕过路径。

新版默认 120 秒软超时 + 15 秒宽限，创建临时 cwd，开启 CLI sandbox，禁用 slash/Skill 展开，不提供 `-d`、会话续接、跳过权限或任意 CLI 参数透传。

### 自动回归范围

`tests/test_ask_agy.py` 使用 Python 假 CLI，覆盖正常文本/结构化结果、失败优先级、raw 模式、软硬超时、权限拒绝、空结果、无效信封、参数错误、Schema 文件、临时 cwd、运行记录和取消后的子进程清理。Windows Ctrl+Break 与 taskkill 路径已实跑；POSIX 进程组分支仍需在 macOS/Linux 上跑同一套测试。

模拟信封测试只证明包装器遇到这些输入时不会误报成功，不代表真实 AGY 必然采用这些状态组合。stderr 文本识别是防御性兼容，不替代未来 CLI 的结构化错误字段。

## 2026-10-18：原作者历史实测（未在本轮重新核验）

环境：macOS，`/Users/apple/.local/bin/agy`，CLI 1.4.2。以下保留用于解释调用方式，不作为当前版本、模型清单、成本或安全性的保证。

### JSON 信封

```json
{"conversation_id":"316c637a-...","status":"SUCCESS","response":"OK\n","duration_seconds":3.14,"num_turns":1,"usage":{"input_tokens":29956,"output_tokens":95,"thinking_tokens":94,"cache_read_tokens":0,"total_tokens":30051}}
```

有 Schema 时会另返 `structured_output`，可能同时附有说明性正文；应优先解析结构化结果。`status=SUCCESS` 是必要条件而非唯一成功判据，还要检查进程码、超时、权限、非空输出及业务内容。

### stdin 行为

| 写法 | 历史结果 |
| --- | --- |
| `echo "x" \| agy` | 读取 stdin |
| `echo "x" \| agy -p` | 打印 usage，exit 0，未执行 |
| `echo "x" \| agy -p -` | 将 `-` 当提示词，不读 stdin |
| `echo "x" \| agy --output-format json` | 读取 stdin 并输出 JSON |

据此新版继续采用“无 -p + stdin”，长提示词不放 argv。

### 权限与超时

headless 工具请求被拒时，曾观察到 exit 0 并返回如下说明，而没有实际创建文件：

```text
no output produced — a tool required the "write_file" permission that headless mode cannot prompt for, so it was auto-denied
```

历史记录中开启跳过权限后可写文件；新版有意不支持这一做法。`--mode plan` 也不能被当作工具权限隔离。

`--print-timeout` 曾返回部分内容，附 `print timeout after Ns with turn in progress; returning partial output`，且 exit 0。软超时还可能额外花数秒收尾，需外层硬超时兜底。

### 模型、用量和并发

原记录包含数个 Gemini/Claude/GPT-OSS 模型，单次简单任务约 30k input token，单条约 3–4 秒。模型 ID、用量与耗时都是当时样本；使用时重新查询 `agy models`，不能把这些观测当长期固定开销或限流保证。

三次并发历史样本总耗时约 10.6 秒，没有报错；不能据此推断安全并发上限。

### 其他接口

历史实测 `--conversation <id>` 可以续接上下文；新版文本执行器不开放此接口，避免隐式继承项目与权限状态。

历史 `stream-json` 事件为 `init`、`step_update`、`result`。新版使用最终 JSON 信封；若要 Gamma 原生流式状态与授权交互，应另做宿主适配层，而不是把未验证的事件直接当完成状态。
