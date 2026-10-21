#!/usr/bin/env bash
# ask-agy.sh — 以非交互方式调用 Antigravity CLI (agy)。
# 适用平台：macOS / Linux / Windows 的 Git Bash、MSYS2、WSL。
#   - Windows 原生 PowerShell / CMD 请用同目录的 ask-agy.ps1。
# 设计要点：
#   - 提示词统一走 stdin（规避 argv 长度限制与引号转义）。
#   - 统一 --output-format json，用信封里的 status 判断成败，真正退出码只由本脚本给出。
#   - agy 位置不写死：AGY_BIN 环境变量 > PATH > 常见安装目录。
#   - JSON 解析按 jq > python3 > python 降级；都缺失时原样输出信封并提示。
#   - 硬看门狗按 perl > timeout > 无 降级，缺失时明确告知，不假装有超时保护。
set -uo pipefail

AGY_GRACE="${AGY_GRACE:-45}"   # --print-timeout 之外的硬性宽限秒数
MODEL=""; EFFORT=""; SCHEMA=""; TIMEOUT=""; DIR=""; CONV=""; OUT=""
ALLOW=0; RAW=0; CONTRACT="auto"
PROMPT_PARTS=()

# agy 默认只允许读类工具和一组只读命令；写文件、任意命令需要 permissions.allow 规则
CONTRACT_TEXT='纯文本任务：只处理下面内联的内容并直接给出结果。不要执行命令、读写文件或联网；若必须借助工具，说明无法完成，不要尝试。\n\n任务：\n'
CONTRACT_PROJECT='项目开发任务：可以读取并修改指定目录内的文件、运行本地检查。不要改动无关文件或覆盖他人已有改动；删除数据、发布/外发、付费、安装依赖或扩大权限前先停下说明。完成后报告改动文件、运行的检查与结果。\n\n任务：\n'

# 权限被拒时给出可执行的下一步，而不是只报一句“无法使用”
report_denial() {
  local blob="$1" tool rule settings
  tool="$(printf '%s' "$blob" | sed -n 's/.*a tool required the "\([a-z_]*\)" permission.*/\1/p' | head -1)"
  rule="$(printf '%s' "$blob" | sed -n 's/.*e\.g\. \([A-Za-z_][A-Za-z_0-9]*([^)]*)\).*/\1/p' | head -1)"
  settings="${HOME}/.gemini/antigravity-cli/settings.json"
  {
    printf '%s\n' "[agy] 权限被拒：${tool:-未知工具}（headless 无法弹窗授权，已自动拒绝）"
    printf '%s\n' "  agy 建议的规则：${rule:-${tool:-<tool>}(<target>)}"
    printf '%s\n' "  配置文件：${settings} 的 permissions.allow"
    printf '%s\n' "  三条出路："
    printf '%s\n' "    1. 加最小 allow 规则（推荐，配一次长期生效）"
    printf '%s\n' "    2. 本次显式放行：--allow-tools（自动批准全部工具，须用户明确确认后使用）"
    printf '%s\n' "    3. 不需要工具：改成纯文本任务，或用 --contract text 强制"
    printf '%s\n' "  注意：--sandbox 与 --mode auto 不会提升工具权限。"
  } >&2
}

usage() {
  cat <<'EOF'
用法:
  ask-agy.sh [选项] "提示词"
  cat prompt.txt | ask-agy.sh [选项]

选项:
  -m, --model <id>         模型，可用 `agy models` 查询准确 id
  -e, --effort <level>     low | medium | high | xhigh | max
  -s, --schema <json|path> 强制结构化输出（JSON Schema 字符串或文件路径）
  -t, --timeout <秒>       print 超时；到点返回部分输出并退出 0
  -d, --dir <目录>         工作目录（agy 默认读该目录下的文件）
  -c, --conversation <id>  续接指定会话
  -o, --out <文件>         保存完整 JSON 信封（含 usage、conversation_id）
      --allow-tools        传 --dangerously-skip-permissions（自动批准全部工具权限）
      --contract <mode>    auto（默认）| text（强制纯文本契约）| project | none
      --raw                原样打印整个 JSON 信封，而不是只打印正文
  -h, --help               显示帮助

环境变量:
  AGY_BIN                  显式指定 agy 可执行文件路径
  AGY_GRACE                硬看门狗宽限秒数（默认 45）

退出码: 0 成功 / 1 agy 失败或 status!=SUCCESS / 2 用法或环境错误 / 3 工具权限被拒 / 124 超时
EOF
}

# 定位 agy：不假设固定安装路径，PATH 优先，其次常见目录（含 Windows 的 .exe）
resolve_agy() {
  if [[ -n "${AGY_BIN:-}" ]]; then
    printf '%s' "$AGY_BIN"
    return 0
  fi
  local found
  found="$(command -v agy 2>/dev/null || true)"
  if [[ -n "$found" ]]; then
    printf '%s' "$found"
    return 0
  fi
  local c
  for c in \
    "$HOME/.local/bin/agy" "$HOME/.local/bin/agy.exe" \
    "$HOME/bin/agy" "/usr/local/bin/agy" "/opt/homebrew/bin/agy" \
    "${LOCALAPPDATA:-}/Programs/agy/agy.exe" \
    "$HOME/AppData/Local/Programs/agy/agy.exe"; do
    [[ -n "$c" && -f "$c" ]] && { printf '%s' "$c"; return 0; }
  done
  return 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -m|--model)        MODEL="${2:?缺少模型值}"; shift 2 ;;
    -e|--effort)       EFFORT="${2:?缺少 effort 值}"; shift 2 ;;
    -s|--schema)       SCHEMA="${2:?缺少 schema 值}"; shift 2 ;;
    -t|--timeout)      TIMEOUT="${2:?缺少秒数}"; shift 2 ;;
    -d|--dir)          DIR="${2:?缺少目录}"; shift 2 ;;
    -c|--conversation) CONV="${2:?缺少会话 ID}"; shift 2 ;;
    -o|--out)          OUT="${2:?缺少输出路径}"; shift 2 ;;
    --allow-tools)     ALLOW=1; shift ;;
    --contract)        CONTRACT="${2:?缺少 contract 值}"; shift 2 ;;
    --raw)             RAW=1; shift ;;
    -h|--help)         usage; exit 0 ;;
    --)                shift; while [[ $# -gt 0 ]]; do PROMPT_PARTS+=("$1"); shift; done ;;
    -*)                echo "未知选项: $1" >&2; usage >&2; exit 2 ;;
    *)                 PROMPT_PARTS+=("$1"); shift ;;
  esac
done

AGY_RESOLVED="$(resolve_agy || true)"
if [[ -z "$AGY_RESOLVED" ]]; then
  cat >&2 <<'EOF'
错误：找不到 agy 可执行文件。
  - 确认已安装 Antigravity CLI，并运行过 `agy install` 让它写入 PATH。
  - Windows 上 `agy` 可能是 agy.exe / agy.cmd，请在能直接执行 `agy --version` 的同一套环境里调用本脚本。
  - 也可用 AGY_BIN 显式指定路径，例如：
      export AGY_BIN="$HOME/.local/bin/agy"              # macOS / Linux
      export AGY_BIN="$HOME/.local/bin/agy.exe"          # Windows（Git Bash）
EOF
  exit 2
fi
AGY_BIN="$AGY_RESOLVED"

if [[ ${#PROMPT_PARTS[@]} -gt 0 ]]; then
  PROMPT="${PROMPT_PARTS[*]}"
elif [[ ! -t 0 ]]; then
  PROMPT="$(cat)"
else
  echo "错误：需要提示词（位置参数，或从 stdin 传入）。" >&2
  usage >&2
  exit 2
fi

if [[ -z "${PROMPT//[[:space:]]/}" ]]; then
  echo "错误：提示词为空。" >&2
  exit 2
fi

# 默认注入任务契约：纯文本模式明确不要用工具，项目模式明确可改范围。
# 避免“模型自己想调工具 → headless 拒绝 → 空正文”的白白失败。
case "$CONTRACT" in
  auto)    if [[ -n "$DIR" ]]; then CONTRACT=project; else CONTRACT=text; fi ;;
  text|project|none) ;;
  *) echo "错误：--contract 只能是 auto|text|project|none" >&2; exit 2 ;;
esac
case "$CONTRACT" in
  text)    PROMPT="$CONTRACT_TEXT$PROMPT" ;;
  project) PROMPT="$CONTRACT_PROJECT$PROMPT" ;;
  none)    ;;
esac

if [[ -n "$DIR" ]]; then
  cd "$DIR" || { echo "错误：无法进入目录 $DIR" >&2; exit 2; }
fi

ARGS=(--output-format json)
[[ -n "$MODEL" ]]  && ARGS+=(--model "$MODEL")
[[ -n "$EFFORT" ]] && ARGS+=(--effort "$EFFORT")
[[ -n "$SCHEMA" ]] && ARGS+=(--json-schema "$SCHEMA")
[[ -n "$CONV" ]]   && ARGS+=(--conversation "$CONV")
[[ $ALLOW -eq 1 ]] && ARGS+=(--dangerously-skip-permissions)
[[ -n "$TIMEOUT" ]] && ARGS+=(--print-timeout "${TIMEOUT}s")

TMPOUT="$(mktemp)"; TMPERR="$(mktemp)"
HARD_TIMEOUT=0
cleanup() { rm -f "$TMPOUT" "$TMPERR"; }
trap cleanup EXIT

run_plain() {
  printf '%s' "$PROMPT" | "$AGY_BIN" "${ARGS[@]}" >"$TMPOUT" 2>"$TMPERR"
}

if [[ -n "$TIMEOUT" ]]; then
  TOTAL=$((TIMEOUT + AGY_GRACE))
  if command -v perl >/dev/null 2>&1 && [[ -x "$(command -v perl)" ]]; then
    # perl 的 alarm+exec 在 macOS / Linux / Git Bash 都可用，作为优先看门狗
    printf '%s' "$PROMPT" | perl -e 'alarm shift; exec @ARGV' "$TOTAL" \
      "$AGY_BIN" "${ARGS[@]}" >"$TMPOUT" 2>"$TMPERR"
    rc=$?
    if [[ $rc -eq 142 || $rc -eq 143 ]]; then
      echo "[agy] 硬超时：${TOTAL}s 后被终止，结果可能不完整。" >&2
      HARD_TIMEOUT=1
      rc=124
    fi
  elif command -v timeout >/dev/null 2>&1; then
    printf '%s' "$PROMPT" | timeout "$TOTAL" "$AGY_BIN" "${ARGS[@]}" >"$TMPOUT" 2>"$TMPERR"
    rc=$?
    if [[ $rc -eq 124 ]]; then
      echo "[agy] 硬超时：${TOTAL}s 后被终止，结果可能不完整。" >&2
      HARD_TIMEOUT=1
    fi
  elif command -v gtimeout >/dev/null 2>&1; then
    printf '%s' "$PROMPT" | gtimeout "$TOTAL" "$AGY_BIN" "${ARGS[@]}" >"$TMPOUT" 2>"$TMPERR"
    rc=$?
    [[ $rc -eq 124 ]] && { echo "[agy] 硬超时：${TOTAL}s 后被终止，结果可能不完整。" >&2; HARD_TIMEOUT=1; }
  else
    echo "[agy] 未找到 perl/timeout，跳过硬看门狗；仅 --print-timeout 的软超时生效。" >&2
    run_plain
    rc=$?
  fi
else
  run_plain
  rc=$?
fi

if [[ -n "$OUT" && -s "$TMPOUT" ]]; then
  cp "$TMPOUT" "$OUT"
fi

# 统一解析：优先 jq，其次 python3/python，都缺失时原样输出信封。
STATUS=""; DUR=""; TURNS=""; TOKENS=""; KIND=""; BODY=""

extract_jq() {
  STATUS="$(jq -r '.status // empty' "$TMPOUT" 2>/dev/null)" || return 1
  [[ -z "$STATUS" ]] && return 1
  DUR="$(jq -r '.duration_seconds // empty' "$TMPOUT" 2>/dev/null)"
  TURNS="$(jq -r '.num_turns // empty' "$TMPOUT" 2>/dev/null)"
  TOKENS="$(jq -r '.usage.total_tokens // empty' "$TMPOUT" 2>/dev/null)"
  if jq -e '(.structured_output // null) != null' "$TMPOUT" >/dev/null 2>&1; then
    KIND=json; BODY="$(jq '.structured_output' "$TMPOUT" 2>/dev/null)"
  else
    KIND=text; BODY="$(jq -r '.response // ""' "$TMPOUT" 2>/dev/null)"
  fi
  return 0
}

extract_py() {
  local py="$1"
  local meta
  meta="$("$py" - "$TMPOUT" <<'PY' 2>/dev/null
import json, sys
data = open(sys.argv[1], encoding="utf-8", errors="replace").read().strip()
try:
    obj = json.loads(data)
except Exception:
    sys.exit(1)
if not isinstance(obj, dict) or "status" not in obj:
    sys.exit(1)
usage = obj.get("usage") or {}
print(obj.get("status"))
print(obj.get("duration_seconds"))
print(obj.get("num_turns"))
print(usage.get("total_tokens"))
if obj.get("structured_output") is not None:
    print("json")
    print(json.dumps(obj["structured_output"], ensure_ascii=False, indent=2))
else:
    print("text")
    print((obj.get("response") or "").rstrip("\n"))
PY
)" || return 1
  [[ -z "$meta" ]] && return 1
  STATUS="$(printf '%s\n' "$meta" | sed -n '1p')"
  DUR="$(printf '%s\n' "$meta" | sed -n '2p')"
  TURNS="$(printf '%s\n' "$meta" | sed -n '3p')"
  TOKENS="$(printf '%s\n' "$meta" | sed -n '4p')"
  KIND="$(printf '%s\n' "$meta" | sed -n '5p')"
  BODY="$(printf '%s\n' "$meta" | sed -n '6,$p')"
  return 0
}

PARSED=0
if command -v jq >/dev/null 2>&1 && extract_jq; then
  PARSED=1
elif command -v python3 >/dev/null 2>&1 && extract_py python3; then
  PARSED=1
elif command -v python >/dev/null 2>&1 && extract_py python; then
  PARSED=1
fi

DATA="$(cat "$TMPOUT" 2>/dev/null)"
ERR="$(cat "$TMPERR" 2>/dev/null)"

if [[ ! -s "$TMPOUT" ]]; then
  printf '%s\n' "${ERR:-(agy 无输出)}" >&2
  exit $([[ $HARD_TIMEOUT -eq 1 ]] && echo 124 || echo 1)
fi

if [[ $PARSED -eq 0 ]]; then
  # 拿不到 status：输出不是信封，或解析器全缺失。原样输出，交由调用方判断。
  command -v jq >/dev/null 2>&1 || command -v python3 >/dev/null 2>&1 || command -v python >/dev/null 2>&1 || \
    echo "[agy] 未找到 jq/python 解析器，以下为原始输出（可能不是合法信封）。" >&2
  printf '%s\n' "$DATA"
  [[ -n "$ERR" ]] && printf '%s\n' "$ERR" >&2
  case "$DATA$ERR" in
    *"cannot prompt for"*|*"auto-denied"*)
      report_denial "$DATA$ERR"
      exit 3 ;;
  esac
  # 无解析器时用粗粒度匹配还原成功判定，避免把成功调用误报为失败
  if printf '%s' "$DATA" | grep -q '"status"[[:space:]]*:[[:space:]]*"SUCCESS"'; then
    exit 0
  fi
  exit 1
fi

printf '[agy] status=%s duration=%ss turns=%s tokens=%s\n' \
  "$STATUS" "${DUR:-?}" "${TURNS:-?}" "${TOKENS:-?}" >&2

if [[ $RAW -eq 1 ]]; then
  printf '%s\n' "$DATA"
  [[ -n "$ERR" ]] && printf '%s\n' "$ERR" >&2
  [[ "$STATUS" == "SUCCESS" ]] && exit 0 || exit 1
fi

if [[ -z "${BODY//[[:space:]]/}" ]]; then
  # 空正文有三种真实成因，必须区分，否则会把权限问题误报成模型不听话
  printf '%s' "$ERR" >&2; [[ -n "$ERR" ]] && printf '\n' >&2
  case "$DATA$ERR" in
    *"cannot prompt for"*|*"auto-denied"*)
      report_denial "$DATA$ERR"
      exit 3 ;;
    *"print timeout"*)
      echo "[agy] print 超时，未产出正文。加大 -t 或拆分任务。" >&2
      exit 124 ;;
  esac
  if [[ "$STATUS" != "SUCCESS" ]]; then
    echo "[agy] 调用失败（status=$STATUS），无正文。" >&2
    exit 1
  fi
  echo "[agy] 返回了空正文（status=$STATUS）。" >&2
  exit 1
fi

printf '%s\n' "$BODY"
[[ -n "$ERR" ]] && printf '%s' "$ERR" >&2
[[ "$STATUS" == "SUCCESS" ]] && exit 0 || exit 1
