#!/usr/bin/env bash
# 兼容入口：所有执行与结果判定集中在 Python，Windows 推荐直接调用 ask-agy.py。
set -uo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)" || exit 2

if [[ -n "${PYTHON_BIN:-}" ]]; then
  exec "$PYTHON_BIN" "$SCRIPT_DIR/ask-agy.py" "$@"
fi
for candidate in python3 python; do
  if command -v "$candidate" >/dev/null 2>&1; then
    version="$("$candidate" -c 'import sys; print(sys.version_info.major)' 2>/dev/null)"
    if [[ "$version" == "3" ]]; then
      exec "$candidate" "$SCRIPT_DIR/ask-agy.py" "$@"
    fi
  fi
done
echo '错误：需要 Python 3.9+；请安装或通过 PYTHON_BIN 指定解释器。' >&2
exit 2
