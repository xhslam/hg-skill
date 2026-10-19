---
name: hg-agy-subagent
description: 通过 Antigravity CLI（agy）委派项目开发子 Agent：读代码、实现功能、修复 bug、修改文件、运行测试/构建、代码审查和会话续接，也支持批量分类/抽取/翻译等文本任务。用户提到 agy、Antigravity 子助理、外挂模型、让另一个 agent 做项目、并行开发或交叉验证时使用。包含跨平台执行脚本、超时取消和运行留痕；保留 Skill 形态，不要求 Gamma 原生子会话集成。
version: "1.0.3"
compatibility: Python 3.9+；已安装并登录的 agy CLI；Bash 为可选兼容入口。
---

# AGY 项目开发子 Agent

通过 Skill 把任务交给 AGY CLI，它可以承担读代码、改文件、执行测试的子 Agent 角色，不只是文本助手。主 Agent 负责划分任务、授权边界、收敛结果和验收。

入口为本 Skill 目录下的 `scripts/ask-agy.py`；`scripts/ask-agy.sh` 仅为 Bash 兼容入口，共用同一实现。它不是 Gamma 原生 collaboration 会话，不会自动出现在协作面板中；这不妨碍它承担项目开发工作。

## 1. 选择模式与任务

- **项目模式**：显式 `-d <项目或worktree目录>`，允许在委派范围内读代码、改文件和运行本地检查。默认 `--mode accept-edits`，默认超时 600 秒，不强制临时目录或 sandbox。
- **文本模式**：省略 `-d`，使用独立临时 cwd，附加不使用工具的文本约束，默认超时 120 秒，启用 CLI sandbox。用于批量翻译、分类、摘要等。

用户指定 AGY 时按此 Skill 执行，不因存在 Gamma 原生 collaboration 就拒绝使用。未指定执行方式时，依据任务独立性、可见性、模型和实际成本选择；简单任务可由主 Agent 直接完成。

外派提示词必须自包含。AGY 不知道本会话历史，主 Agent 要提供必要的项目规则、已完成工作、输入与验收标准。不要把完整聊天历史无差别复制过去。

外派前说明必要输入会交给 AGY 配置的模型服务。遵守宿主的外发/付费确认规则，不传凭据或未经授权的数据。允许项目开发不等于允许发布、删除重要数据或扩大权限。

## 2. 前置检查

后台检查，不为展示日志打开终端：

```bash
agy --version
agy --help
agy models
```

根据 `agy models` 的当前结果选择模型 ID；不把历史模型清单、耗时或 token 样本当长期固定保证。

脚本按 `AGY_BIN` → PATH → `~/.local/bin/agy` 查找。Windows 使用 `agy.exe`，不接受 `.cmd/.bat`；调用不经过 shell 拼接。不自动安装、登录或修改 AGY 配置。

确认本机支持 JSON、`--disable-slash-commands`、`--print-timeout`，以及所选模式需要的 `--mode`、`--conversation`、`--sandbox`。不兼容时报告，不静默丢弃参数或降级到旧脚本。

## 3. 项目开发标准流程

### A. 明确范围和目录

1. 确认 `-d` 是用户授权的项目或 worktree。传入规范路径；不要传用户主目录、父级全集目录或不相关项目。
2. 读取已授权项目规则，显式交给 AGY；不要假定外部 CLI 会继承 Gamma 的指令解析与路径边界。
3. 记录 Git 基线：分支/HEAD、`git status --short`、已有 tracked diff 和 untracked 文件。不要为了“干净”而重置、清理或 stash 用户改动。
4. 单个独立任务可直接使用真实项目目录。并行修改同一项目时优先独立 worktree 或明确不重叠的文件范围；不要两个 Agent 同时改同一文件。worktree 是冲突管理措施，不是权限沙箱。
5. 若要新建 worktree，由主 Agent 使用 Git 创建并记录基线，再将路径传给 `-d`。本脚本不自动创建、合并或删除 worktree。宿主提供 worktree 绑定工具且主 Agent 自己要编辑该 worktree 时，先按宿主要求绑定。

### B. 写开发契约并委派

任务至少包含：

- 目标、背景、允许修改的目录/文件，以及不要改的部分。
- 项目规则、构建工具、已有改动与协作分工。
- 要运行的最小相关测试/类型检查/构建和验收标准。
- 报告格式：修改文件、关键 diff、检查命令/结果、未完成项与风险。
- 禁止擅自提交/推送、安装依赖、删除重要数据、外发/发布、付费或扩大权限；遇到这些需求暂停并交主 Agent 取得确认。

脚本项目契约允许读写代码与执行检查，不再附加“不要执行任何命令”的文本限制。契约是行为指引，不是可靠权限拦截器。

Windows PowerShell，替换实际路径：

```powershell
$SkillDir = "<当前SKILL.md的父目录>"
python "$SkillDir/scripts/ask-agy.py" -d "C:/projects/demo" -m "<实时模型ID>" --record "C:/runs/task-01.json" "修复指定模块的输入校验，补充边界测试并运行相关测试；不要修改其他模块。"
```

macOS/Linux：

```bash
SKILL_DIR="<当前SKILL.md的父目录>"
python3 "$SKILL_DIR/scripts/ask-agy.py" -d '/projects/demo' -m '<实时模型ID>' --record '/runs/task-01.json' '修复指定模块的输入校验，补充边界测试并运行相关测试；不要修改其他模块。'
```

记录输出目录必须已经存在。记录建议放在宿主会话目录而非项目中，避免污染 diff。长提示词用 UTF-8 stdin：

```bash
cat task.txt | python3 "$SKILL_DIR/scripts/ask-agy.py" -d '/projects/demo' -t 900 --record '/runs/task-01.json'
```

PowerShell 管道先设置 UTF-8：

```powershell
$env:PYTHONIOENCODING = "utf-8"
[Console]::InputEncoding = [System.Text.UTF8Encoding]::new($false)
$OutputEncoding = [System.Text.UTF8Encoding]::new($false)
Get-Content -Raw -Encoding UTF8 "task.txt" | python "$SkillDir/scripts/ask-agy.py" -d "C:/projects/demo" -t 900
```

### C. 主 Agent 验收

1. 检查退出码和最终记录；`0` 仅代表传输层成功，不证明功能正确。
2. 对比委派前后的 tracked diff、untracked 文件和 Git 状态，区分用户原有改动；检查范围、敏感文件、依赖和意外生成文件。不要只看子 Agent 的文字总结。
3. 阅读关键 diff，并独立运行必要检查；未运行的检查明确说明，不能根据模型声称“通过”就交付。
4. 超时、失败或取消不意味着文件未变。项目目录和部分改动会保留；先检查状态，再决定续接或修复，不自动回滚、不盲目重复整个任务。
5. worktree 结果由主 Agent 审核后按用户授权整合，不自动提交、推送或删除。

## 4. 工具权限：允许开发，不默认全部放行

默认沿用 AGY 自身配置与权限规则。项目模式的 `accept-edits` 是执行模式，**不保证** headless 下所有工具都已授权；读写文件和测试命令也可能被拒。

权限被拒时返回 `3`：报告需要的工具/命令，让用户在 AGY 中按最小范围授权，或进行必要的交互授权后再续接。不要臆造未核验的权限配置格式，也不要静默改变用户全局配置。外部 CLI 不会自动把授权请求桥接回 Gamma。

脚本保留显式 `--dangerously-skip-permissions` 供确有需要的项目任务使用，但主 Agent 在添加前必须：

1. 说明这会**自动批准全部工具请求**，不是“只允许改代码/跑测试”。
2. 说明可能执行删除、联网等操作，提示词无法可靠阻止。
3. 取得用户对本次目录与任务的明确授权；“修功能”“允许做项目”不是全部工具授权。

此标志不作为默认模板，不得在权限失败后自动追加。包装器不会弹出确认框，也不能证明授权已取得，主 Agent 必须落实。旧版含糊的 `--allow-tools` 别名不恢复，避免将其误读为细粒度授权。

项目模式可显式 `--sandbox` 增加 CLI 终端限制；不支持在脚本里自动关闭限制重试。无论 cwd、worktree、执行模式还是 CLI sandbox，都不等于文件系统/网络完整隔离。涉及陌生代码或不可信工具配置时，使用真正受控的 OS/宿主隔离环境。

## 5. 会话续接

用 `--record` 保存 `cwd` 与 `conversation_id`。续接前读取记录，确认 ID 来自同一任务且目录与授权范围一致，再显式传 `-d` 和 `-c`：

```powershell
$Run = Get-Content -Raw -Encoding UTF8 "C:/runs/task-01.json" | ConvertFrom-Json
python "$SkillDir/scripts/ask-agy.py" -d $Run.cwd -c $Run.conversation_id --record "C:/runs/task-02.json" "根据测试失败修复同一模块，不扩大修改范围。"
```

包装器要求续接时有显式项目目录，但不读取 AGY 内部会话库，不能证明 ID 与目录一致，仍由主 Agent核对。不使用 `--continue` 隐式选择最近会话。不跨项目复用旧会话；跨授权范围要新建任务。每次仍显式传所需模式、模型和权限选项，不依赖历史会话隐式继承授权。

## 6. 参数、结果和记录

| 参数 | 行为 |
| --- | --- |
| `-d/--dir` | 现有项目/worktree；省略为文本临时目录模式 |
| `-c/--conversation` | 显式会话 ID，要求 `-d` |
| `--mode` | accept-edits / auto / plan，项目默认 accept-edits；不等于授权 |
| `--sandbox` | 项目可选终端限制，文本始终启用 |
| `--dangerously-skip-permissions` | 仅项目；显式全部工具放行，须提前确认 |
| `-m/--model`、`-e/--effort` | 实时模型 ID；low / medium / high / xhigh / max |
| `-s/--schema` | JSON Schema 对象或 UTF-8 文件；启动前读入 |
| `-t/--timeout` | 正数秒；项目默认 600，文本默认 120 |
| `--grace` | 硬超时宽限秒数，默认 15，可为 0 |
| `-o/--out` | 保存原始有效 JSON 信封；失败信封也可保存，不代表成功 |
| `--record` | 原子更新 starting → running → 最终状态，含 cwd、任务类型、模式、会话 ID、pid、退出码和信封 |
| `--raw` | 成功时输出原始信封，不绕过失败判定 |

不接受模糊长选项缩写；不支持旧环境变量 `AGY_GRACE`，改用 `--grace`。

退出码：`0` 传输层成功、`1` 进程/信封/空输出失败、`2` 参数或环境错误、`3` 权限拒绝、`124` 超时、`130` 取消。失败不向 stdout 输出可误用的部分答案，但诊断文件和项目改动可能存在。

成功要求：未取消/超时，未发现权限拒绝，CLI 进程 exit 0，信封 `status=SUCCESS`，且有非空正文或非 null 的结构化结果。业务正确性由主 Agent 验收。机器结果优先读取 `structured_output`；脚本不内置 JSON Schema 验证库，主 Agent仍须检查字段、条数和 id。

记录含模型输出与 stderr，可能复述输入或含项目数据，只放用户允许的位置；不用来存密钥。`--out` 与 `--record` 不能为同一文件。现有同名输出会被替换，调用前选用任务专属文件。

## 7. 超时与取消

软超时返回部分结果也按 `124`，外层到 `timeout+grace` 后尝试硬终止，清理可能另需数秒。项目任务长于默认值时显式设置合理超时，不使用无限等待。

取消：POSIX 对包装进程发送 SIGINT/SIGTERM；Windows 使用 Ctrl+Break（宿主以 `CREATE_NEW_PROCESS_GROUP` 启动包装进程后定向发送 CTRL_BREAK_EVENT）。宿主等包装器退出后再读最终记录。

Windows 尝试用 `taskkill /PID <自有pid> /T /F` 结束自有进程树；POSIX 使用独立进程组。直接强杀包装器、断电、脱离进程组的后台进程或远端任务不保证清理；Windows `proc.terminate()` 也不是优雅取消。需要更强归属保证时在宿主使用 Job Object/OS 隔离。

**项目模式绝不自动删除目录或撤销改动**；文本模式仅清理自己创建的临时 cwd。并发任务使用不同记录路径，同一项目优先 worktree 或不重叠修改范围。

## 8. 本地回归与能力边界

```bash
python -m unittest discover -s tests -v
# macOS/Linux 如只有 python3，改用 python3。
```

测试使用假 CLI，包括指定目录写代码和运行本地校验，不联网、不消耗模型额度。不证明真实 AGY 工具授权已配好或模型开发质量。平台和历史行为见 `references/cli-behavior.md`。
