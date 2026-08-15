@echo off
chcp 65001 >nul
setlocal

echo ════════════════════════════════════
echo  NovaForge — 新建项目
echo ════════════════════════════════════

set /p PROJ_NAME=请输入项目名称（如 我的考研笔记）:

if "%PROJ_NAME%"=="" (
    echo [错误] 项目名称不能为空
    pause
    exit /b 1
)

set TARGET_DIR=%USERPROFILE%\Desktop\%PROJ_NAME%

if exist "%TARGET_DIR%" (
    echo [错误] %TARGET_DIR% 已存在
    pause
    exit /b 1
)

echo 正在创建项目：%PROJ_NAME%
mkdir "%TARGET_DIR%"
mkdir "%TARGET_DIR%\assets"
mkdir "%TARGET_DIR%\latex"

rem 拷贝模板
copy "%~dp0..\latex\template.tex" "%TARGET_DIR%\latex\" >nul
copy "%~dp0..\latex\preamble.tex" "%TARGET_DIR%\latex\" >nul

echo.
echo ✅ 项目已创建！
echo 📁 %TARGET_DIR%
echo 编辑 latex\template.tex 开始你的笔记之旅！
pause
