#!/bin/bash
# NovaForge — 新建项目脚本 (macOS/Linux)
# 用法: bash new-project.sh 项目名称

set -e

PROJ_NAME="${1:-我的知识笔记}"
TARGET_DIR="$HOME/Desktop/$PROJ_NAME"

if [ -d "$TARGET_DIR" ]; then
    echo "[错误] $TARGET_DIR 已存在"
    exit 1
fi

echo "创建项目: $PROJ_NAME"
mkdir -p "$TARGET_DIR"/{assets,latex}

cp "$(dirname "$0")/../latex/template.tex" "$TARGET_DIR/latex/"
cp "$(dirname "$0")/../latex/preamble.tex" "$TARGET_DIR/latex/"

echo "✅ 项目已创建: $TARGET_DIR"
echo "编辑 $TARGET_DIR/latex/template.tex 开始你的笔记之旅！"
