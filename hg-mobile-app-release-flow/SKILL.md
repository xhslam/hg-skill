---
name: hg-mobile-app-release-flow
description: Use when working on Expo/React Native mobile apps, especially requests like 制作App, 修复App功能, 打包, 安装包, APK, 更新手机上的包, Android build, or when source changes must become a preview, installable package, or installed app.
---

# Mobile App Release Flow

## Overview

Use this workflow to keep four states separate: source changed, preview running, APK/AAB built, and app installed. Never imply the installation package changed unless a fresh package build produced a verified artifact.

Default to Chinese for user-facing updates when the user writes Chinese.

## Core Rule

Treat these as different deliverables:

| State | Evidence required before saying it is done |
| --- | --- |
| Source changed | Diff plus relevant tests/typecheck passing |
| Preview running | Dev server URL/port plus no startup failure |
| Package built | Fresh APK/AAB path, timestamp, size or hash |
| App installed | Install command succeeded on target device/emulator |

If only source or preview was changed, say “安装包还没更新”.

## Workflow

1. **Orient**
   - Find the app root. In this workspace, prefer `C:\Users\gan79\Desktop\手机软件\offline-markdown-mobile` when the task is about the note app.
   - Read local `AGENTS.md`, `package.json`, app config, and the relevant screen/component files before editing.
   - Check `git status --short`; do not revert unrelated user changes.

2. **Define Done**
   - Write a short internal checklist: `Goal`, `Context`, `Constraints`, `Done when`.
   - If the user mentions 安装包, APK, 打包, 手机上更新, or “能安装”, include package build or install evidence in `Done when`.
   - If the user only asks for UI/function fixes, source verification plus optional preview is enough; do not silently promise a package.

3. **Implement**
   - Follow existing React Native/Expo structure and styles.
   - For behavior changes, add or update focused tests first when practical.
   - Keep changes narrow; avoid unrelated refactors, generated folders, and broad rewrites.

4. **Verify Source**
   - Run the smallest relevant tests, then broader checks when touched behavior is shared.
   - Prefer these commands when available:
     - `npm test`
     - `npm run typecheck`
     - `npm run lint`
   - If starting Expo/Metro, report it as preview only: `http://localhost:8081` or the actual shown URL.

5. **Build Package When Required**
   - Inspect scripts and Android project before choosing a command.
   - Common local Android debug build:
     - `cd android`
     - `.\gradlew assembleDebug`
   - Common artifact path:
     - `android\app\build\outputs\apk\debug\app-debug.apk`
   - Release builds require signing config; do not invent release readiness.
   - After building, verify the artifact is fresh:
     - full path
     - last write time
     - size or hash

6. **Install When Required**
   - Confirm a target device/emulator is visible with `adb devices`.
   - Install with `adb install -r <apk-path>` only after a fresh package exists.
   - If installation fails, report the exact failure and do not claim the phone has the new version.

7. **Final Status**
   - End with one explicit status label:
     - `源码已更新，未打包`
     - `源码已更新，预览服务已启动，未打包`
     - `APK 已重新构建`
     - `APK 已重新构建并安装`
   - Include verification commands and package/install evidence. Keep it short.

## Common Mistakes

- Starting Expo/Metro and calling that “安装包已更新”.
- Reporting an old APK path without checking timestamp after the current changes.
- Building in a copied directory instead of the active source directory.
- Treating `npm run android` as package creation without checking whether it installed, built, or failed.
- Forgetting to say what was not verified.
