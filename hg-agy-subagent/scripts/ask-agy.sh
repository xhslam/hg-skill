#!/usr/bin/env bash
# ask-agy.sh — 以非交互方式调用 Antigravity CLI (agy) 作为子助理。
# 统一走 stdin 传提示词（避免 argv 长度与引号问题），统一用 --output-format json 取结构化信封。
set -uo pipefail

AGY_BIN="${AGY_BIN:-$HOME/.local/bin/agy}"
AGY_GRACE="${AGY_GRACE:-45}"   # 软超时之外的硬性宽限秒数
MODEL=""; EFFORT=""; SCHEMA=""; TIMEOUT=""; DIR=""; CONV=""; OUT=""
ALLOW=0; RAW=0
PROMPT_PARTS=()

usage() {
  cat <<'EOF'
用法:
  ask-agy.sh [选项] "提示词"
  cat prompt.txt | ask-agy.sh [选项]

选项:
  -m, --model <id>         模型，如 gemini-3.8-flash-medium / claude-sonnet-4-6 /
                           claude-opus-4-6-thinking / gpt-oss-120b-medium
  -e, --effort <level>     low | medium | high | xhigh | max
  -s, --schema <json|path> 强制结构化输出（JSON Schema 字符串或文件路径）
  -t, --timeout <秒>       print 超时；到点返回部分输出并退出 0
  -d, --dir <目录>         工作目录（agy 默认读该目录下的文件）
  -c, --conversation <id>  续接指定会话
  -o, --out <文件>         保存完整 JSON 信封（含 usage、conversation_id）
      --allow-tools        传 --dangerously-skip-permissions（headless 需要工具时）
      --raw                原样打印整个 JSON 信封，而不是只打印正文
  -h, --help               显示帮助

退出码: 0 成功 / 1 agy 失败或 status!=SUCCESS / 2 用法错误 / 3 工具权限被拒 / 124 硬超时
EOF
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
    --raw)             RAW=1; shift ;;
    -h|--help)         usage; exit 0 ;;
    --)                shift; while [[ $# -gt 0 ]]; do PROMPT_PARTS+=("$1"); shift; done ;;
    -*)                echo "未知选项: $1" >&2; usage >&2; exit 2 ;;
    *)                 PROMPT_PARTS+=("$1"); shift ;;
  esac
done

if [[ ! -x "$AGY_BIN" ]]; then
  echo "错误：找不到可执行的 agy（$AGY_BIN）。可用 AGY_BIN 环境变量覆盖。" >&2
  exit 2
fi

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

if [[ -n "$TIMEOUT" ]]; then
  # --print-timeout 是软约束（实测会额外多花数十秒收尾），再用 perl 的 alarm+exec 做硬看门狗
  if [[ -x /usr/bin/perl ]]; then
    printf '%s' "$PROMPT" | /usr/bin/perl -e 'alarm shift; exec @ARGV' "$((TIMEOUT + AGY_GRACE))" \
      "$AGY_BIN" "${ARGS[@]}" >"$TMPOUT" 2>"$TMPERR"
    rc=$?
    if [[ $rc -eq 142 || $rc -eq 143 ]]; then
      echo "[agy] 硬超时：$((TIMEOUT + AGY_GRACE))s 后被终止，结果可能不完整。" >&2
      HARD_TIMEOUT=1
      rc=124
    fi
  else
    printf '%s' "$PROMPT" | "$AGY_BIN" "${ARGS[@]}" >"$TMPOUT" 2>"$TMPERR"
    rc=$?
  fi
else
  printf '%s' "$PROMPT" | "$AGY_BIN" "${ARGS[@]}" >"$TMPOUT" 2>"$TMPERR"
  rc=$?
fi

if [[ -n "$OUT" && -s "$TMPOUT" ]]; then
  cp "$TMPOUT" "$OUT"
fi

python3 - "$TMPOUT" "$TMPERR" "$RAW" "$rc" "$HARD_TIMEOUT" <<'PY'
import json, sys

out_path, err_path, raw_flag, rc = sys.argv[1], sys.argv[2], sys.argv[3] == "1", int(sys.argv[4])
hard_timeout = sys.argv[5] == "1"
data = open(out_path, encoding="utf-8", errors="replace").read().strip()
err = open(err_path, encoding="utf-8", errors="replace").read().strip()

if not data:
    sys.stderr.write((err or "(agy 无输出)") + "\n")
    sys.exit(124 if hard_timeout else 1)

obj = None
try:
    obj = json.loads(data)
except Exception:
    pass

if not isinstance(obj, dict) or "status" not in obj:
    sys.stderr.write(data + ("\n" + err if err else "") + "\n")
    if "cannot prompt for" in data or "cannot prompt for" in err:
        sys.stderr.write("[agy] 该任务需要工具权限，headless 模式无法弹窗授权。改用 --allow-tools，或缩小任务范围。\n")
        sys.exit(3)
    sys.exit(1)

status = obj.get("status")
usage = obj.get("usage") or {}
sys.stderr.write(
    "[agy] status=%s duration=%ss turns=%s tokens=%s\n"
    % (status, obj.get("duration_seconds"), obj.get("num_turns"), usage.get("total_tokens"))
)

if raw_flag:
    print(data)
    if err:
        sys.stderr.write(err + "\n")
    sys.exit(0 if status == "SUCCESS" else 1)

structured = obj.get("structured_output")
if structured is not None:
    print(json.dumps(structured, ensure_ascii=False, indent=2))
    if err:
        sys.stderr.write(err + "\n")
    sys.exit(0 if status == "SUCCESS" else 1)

resp = obj.get("response") or ""
if not resp.strip():
    # 空正文有三种真实成因，必须区分，否则会把权限问题误报成模型不听话
    combined = data + "\n" + err
    if "cannot prompt for" in combined:
        sys.stderr.write(err + "\n" if err else "")
        sys.stderr.write(
            "[agy] 该任务需要工具权限，headless 模式无法弹窗授权。"
            "改用 --allow-tools，或缩小任务范围。\n"
        )
        sys.exit(3)
    if "print timeout" in combined:
        sys.stderr.write(err + "\n" if err else "")
        sys.stderr.write("[agy] print 超时，未产出正文。加大 -t 或拆分任务。\n")
        sys.exit(124)
    if status != "SUCCESS":
        sys.stderr.write(err + "\n" if err else "")
        sys.stderr.write("[agy] 调用失败（status=%s），无正文。\n" % status)
        sys.exit(1)
    sys.stderr.write(err + "\n" if err else "")
    sys.stderr.write("[agy] 返回了空正文（status=%s）。\n" % status)
    sys.exit(1)

print(resp.rstrip("\n"))
if err:
    sys.stderr.write(err + "\n")
sys.exit(0 if status == "SUCCESS" else 1)
PY
