<#
.SYNOPSIS
  ask-agy.ps1 — 以非交互方式调用 Antigravity CLI (agy)，Windows PowerShell 版。

.DESCRIPTION
  与同目录 ask-agy.sh 行为一致：提示词走标准输入、统一 --output-format json、
  用信封里的 status 判断成败、给出统一的退出码。

  与 POSIX 版的差异只在于实现手段，不是能力差异：
    - agy 位置不写死：AGY_BIN 环境变量 > PATH > 常见安装目录；自动处理 agy.exe / agy.cmd。
    - 参数按 Windows CRT 规则逐个转义，含空格和引号的 JSON Schema 不会被拆坏。
    - 提示词写入临时文件（UTF-8 无 BOM）再重定向给 agy，规避 PowerShell 5.1 默认非 UTF-8 管道编码导致的中文乱码。
    - 硬看门狗用 .NET WaitForExit，不依赖 perl / timeout。

.EXAMPLE
  .\ask-agy.ps1 -Model gemini-3.8-flash-high "把这句话翻成英文：今天下雨了"

.EXAMPLE
  Get-Content .\titles.txt -Raw | .\ask-agy.ps1 -Model gemini-3.8-flash-medium -Timeout 120
#>
[CmdletBinding()]
param(
  [Parameter(Position = 0)]
  [string]$Prompt,

  [Alias('m')][string]$Model,
  [Alias('e')][string]$Effort,
  [Alias('s')][string]$Schema,
  [Alias('t')][int]$Timeout = 0,
  [Alias('d')][string]$Dir,
  [Alias('c')][string]$Conversation,
  [Alias('o')][string]$Out,
  [string]$AgyBin,
  [int]$Grace = 45,
  [ValidateSet('auto', 'text', 'project', 'none')][string]$Contract = 'auto',
  [switch]$AllowTools,
  [switch]$Raw,
  [switch]$Help
)

$ErrorActionPreference = 'Stop'

# 让中文正文在控制台与管道里保持 UTF-8；部分托管宿主不支持设置，失败不影响主流程
try { [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding $false } catch { }

function Show-Usage {
  @'
用法:
  ask-agy.ps1 [选项] "提示词"
  Get-Content prompt.txt -Raw | ask-agy.ps1 [选项]

选项:
  -Model, -m <id>          模型，可用 `agy models` 查询准确 id
  -Effort, -e <level>      low | medium | high | xhigh | max
  -Schema, -s <json|path>  强制结构化输出（建议传文件路径，避免命令行转义问题）
  -Timeout, -t <秒>        print 软超时；到点返回部分输出
  -Dir, -d <目录>          工作目录（agy 默认读该目录下的文件）
  -Conversation, -c <id>   续接指定会话
  -Out, -o <文件>          保存完整 JSON 信封（含 usage、conversation_id）
  -AgyBin <路径>           显式指定 agy 可执行文件（也可用 AGY_BIN 环境变量）
  -Grace <秒>              硬看门狗宽限秒数（默认 45）
  -Contract <mode>         auto（默认）| text | project | none，控制默认注入的任务契约
  -AllowTools              传 --dangerously-skip-permissions（自动批准全部工具权限）
  -Raw                     原样打印整个 JSON 信封，而不是只打印正文
  -Help                    显示帮助

退出码: 0 成功 / 1 agy 失败或 status!=SUCCESS / 2 用法或环境错误 / 3 工具权限被拒 / 124 超时
'@
}

if ($Help) { Show-Usage; exit 0 }

function Resolve-Agy {
  param([string]$Explicit)

  if ($Explicit) { return $Explicit }
  if ($env:AGY_BIN) { return $env:AGY_BIN }

  $cmd = Get-Command agy -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($cmd -and $cmd.Source -and $cmd.Source -notmatch '\.ps1$') { return $cmd.Source }

  $names = @('agy.exe', 'agy.cmd', 'agy.bat', 'agy')
  foreach ($dir in ($env:PATH -split ';')) {
    if ([string]::IsNullOrWhiteSpace($dir)) { continue }
    foreach ($n in $names) {
      $candidate = Join-Path $dir $n
      if (Test-Path -LiteralPath $candidate -PathType Leaf) { return $candidate }
    }
  }

  # 环境变量可能不存在（非 Windows 宿主、精简环境），逐项判断后再拼路径
  $fallbacks = New-Object System.Collections.Generic.List[string]
  if ($env:USERPROFILE) { $fallbacks.Add((Join-Path $env:USERPROFILE '.local\bin\agy.exe')) }
  if ($env:LOCALAPPDATA) { $fallbacks.Add((Join-Path $env:LOCALAPPDATA 'Programs\agy\agy.exe')) }
  if ($env:ProgramFiles) { $fallbacks.Add((Join-Path $env:ProgramFiles 'agy\agy.exe')) }
  foreach ($f in $fallbacks) {
    if (Test-Path -LiteralPath $f -PathType Leaf) { return $f }
  }
  return $null
}

# Windows 命令行参数转义（CRT 规则）：反斜杠仅在引号前与结尾需要成倍，引号前加反斜杠
function ConvertTo-ArgString {
  param([string]$Value)
  if ($null -eq $Value) { return '""' }
  if ($Value -eq '') { return '""' }
  if ($Value -notmatch '[\s"]') { return $Value }

  $sb = New-Object System.Text.StringBuilder
  [void]$sb.Append('"')
  $backslashes = 0
  foreach ($ch in $Value.ToCharArray()) {
    if ($ch -eq '\') { $backslashes++; continue }
    if ($ch -eq '"') {
      if ($backslashes -gt 0) { [void]$sb.Append(('\' * (($backslashes * 2) + 1)) -join '') }
      else { [void]$sb.Append('\') }
      [void]$sb.Append('"')
      $backslashes = 0
      continue
    }
    if ($backslashes -gt 0) {
      [void]$sb.Append(('\' * $backslashes) -join '')
      $backslashes = 0
    }
    [void]$sb.Append($ch)
  }
  if ($backslashes -gt 0) { [void]$sb.Append(('\' * ($backslashes * 2)) -join '') }
  [void]$sb.Append('"')
  return $sb.ToString()
}

# 提示词来源：位置参数 > 管道输入
if (-not $PSBoundParameters.ContainsKey('Prompt')) {
  $items = @($input)
  if ($items.Count -gt 0) {
    $Prompt = ($items | ForEach-Object { [string]$_ }) -join "`n"
  }
}

if ([string]::IsNullOrWhiteSpace($Prompt)) {
  [Console]::Error.WriteLine('错误：需要提示词（位置参数，或通过管道传入）。')
  Show-Usage
  exit 2
}

# agy 默认只允许读类工具和一组只读命令；写文件、任意命令需要 permissions.allow 规则
$ContractText = "纯文本任务：只处理下面内联的内容并直接给出结果。不要执行命令、读写文件或联网；若必须借助工具，说明无法完成，不要尝试。`n`n任务：`n"
$ContractProject = "项目开发任务：可以读取并修改指定目录内的文件、运行本地检查。不要改动无关文件或覆盖他人已有改动；删除数据、发布/外发、付费、安装依赖或扩大权限前先停下说明。完成后报告改动文件、运行的检查与结果。`n`n任务：`n"

# 默认注入任务契约：纯文本模式明确不要用工具，项目模式明确可改范围。
# 避免“模型自己想调工具 → headless 拒绝 → 空正文”的白白失败。
if ($Contract -eq 'auto') { $Contract = if ($Dir) { 'project' } else { 'text' } }
switch ($Contract) {
  'text' { $Prompt = $ContractText + $Prompt }
  'project' { $Prompt = $ContractProject + $Prompt }
  'none' { }
}

function Show-Denial {
  param([string]$Blob)
  $tool = ''
  $rule = ''
  if ($Blob -match 'a tool required the "([a-z_]+)" permission') { $tool = $Matches[1] }
  if ($Blob -match 'e\.g\. ([A-Za-z_][A-Za-z_0-9]*\([^)]*\))') { $rule = $Matches[1] }
  if (-not $rule) { $rule = if ($tool) { "$tool(<target>)" } else { '<tool>(<target>)' } }
  $settings = Join-Path $env:USERPROFILE '.gemini\antigravity-cli\settings.json'
  [Console]::Error.WriteLine("[agy] 权限被拒：$(if ($tool) { $tool } else { '未知工具' })（headless 无法弹窗授权，已自动拒绝）")
  [Console]::Error.WriteLine("  agy 建议的规则：$rule")
  [Console]::Error.WriteLine("  配置文件：$settings 的 permissions.allow")
  [Console]::Error.WriteLine('  三条出路：')
  [Console]::Error.WriteLine('    1. 加最小 allow 规则（推荐，配一次长期生效）')
  [Console]::Error.WriteLine('    2. 本次显式放行：-AllowTools（自动批准全部工具，须用户明确确认后使用）')
  [Console]::Error.WriteLine('    3. 不需要工具：改成纯文本任务，或用 -Contract text 强制')
  [Console]::Error.WriteLine('  注意：--sandbox 与 --mode auto 不会提升工具权限。')
}

$agy = Resolve-Agy -Explicit $AgyBin
if (-not $agy) {
  $missingMsg = @'
错误：找不到 agy 可执行文件。
  - 确认已安装 Antigravity CLI，并运行过 `agy install` 让它写入 PATH。
  - 用 `Get-Command agy` 或 `where.exe agy` 确认当前 PowerShell 能看到它。
  - 也可显式指定：-AgyBin "$env:USERPROFILE\.local\bin\agy.exe"
'@
  [Console]::Error.WriteLine($missingMsg)
  exit 2
}
if (-not (Test-Path -LiteralPath $agy -PathType Leaf)) {
  [Console]::Error.WriteLine("错误：agy 路径不存在：$agy")
  exit 2
}

if ($Dir) {
  if (-not (Test-Path -LiteralPath $Dir -PathType Container)) {
    [Console]::Error.WriteLine("错误：工作目录不存在：$Dir")
    exit 2
  }
}

$agyArgs = New-Object System.Collections.Generic.List[string]
$agyArgs.Add('--output-format'); $agyArgs.Add('json')
if ($Model) { $agyArgs.Add('--model'); $agyArgs.Add($Model) }
if ($Effort) { $agyArgs.Add('--effort'); $agyArgs.Add($Effort) }
if ($Schema) {
  if ((Test-Path -LiteralPath $Schema -PathType Leaf)) {
    $agyArgs.Add('--json-schema'); $agyArgs.Add((Resolve-Path -LiteralPath $Schema).Path)
  } else {
    $agyArgs.Add('--json-schema'); $agyArgs.Add($Schema)
  }
}
if ($Conversation) { $agyArgs.Add('--conversation'); $agyArgs.Add($Conversation) }
if ($AllowTools) { $agyArgs.Add('--dangerously-skip-permissions') }
if ($Timeout -gt 0) { $agyArgs.Add('--print-timeout'); $agyArgs.Add("${Timeout}s") }

# .cmd / .bat 不能被 CreateProcess 直接启动，包一层 cmd.exe：用 /d /s /c ""..."" 的标准写法避免首尾引号被误解
$exe = $agy
$quotedArgs = foreach ($a in $agyArgs) { ConvertTo-ArgString $a }
if ($agy -match '\.(cmd|bat)$') {
  $exe = $env:ComSpec
  $argString = '/d /s /c "' + (ConvertTo-ArgString $agy) + ' ' + ($quotedArgs -join ' ') + '"'
} else {
  $argString = ($quotedArgs -join ' ')
}

$tmpIn = [IO.Path]::GetTempFileName()
$tmpOut = [IO.Path]::GetTempFileName()
$tmpErr = [IO.Path]::GetTempFileName()
$hardTimeout = $false

try {
  # UTF-8 无 BOM：PowerShell 5.1 的管道默认编码不是 UTF-8，走文件最稳
  [IO.File]::WriteAllText($tmpIn, $Prompt, (New-Object System.Text.UTF8Encoding $false))

  $spArgs = @{
    FilePath               = $exe
    ArgumentList           = $argString
    RedirectStandardInput  = $tmpIn
    RedirectStandardOutput = $tmpOut
    RedirectStandardError  = $tmpErr
    NoNewWindow            = $true
    PassThru               = $true
  }
  if ($Dir) { $spArgs['WorkingDirectory'] = (Resolve-Path -LiteralPath $Dir).Path }

  $proc = Start-Process @spArgs

  if ($Timeout -gt 0) {
    $limitMs = ($Timeout + $Grace) * 1000
    if (-not $proc.WaitForExit($limitMs)) {
      try { $proc.Kill() } catch { }
      try { $proc.WaitForExit(5000) | Out-Null } catch { }
      [Console]::Error.WriteLine("[agy] 硬超时：$($Timeout + $Grace)s 后被终止，结果可能不完整。")
      $hardTimeout = $true
    }
  } else {
    $proc.WaitForExit()
  }

  $rc = 0
  try { $rc = $proc.ExitCode } catch { $rc = 1 }

  $data = [IO.File]::ReadAllText($tmpOut, [Text.Encoding]::UTF8).Trim()
  $err = [IO.File]::ReadAllText($tmpErr, [Text.Encoding]::UTF8).Trim()

  if ($Out -and $data) { [IO.File]::WriteAllText($Out, $data, (New-Object System.Text.UTF8Encoding $false)) }

  if ($hardTimeout) { $rc = 124 }

  if (-not $data) {
    [Console]::Error.WriteLine($(if ($err) { $err } else { '(agy 无输出)' }))
    if ($hardTimeout) { exit 124 } else { exit 1 }
  }

  $obj = $null
  try { $obj = $data | ConvertFrom-Json } catch { $obj = $null }

  $hasEnvelope = ($obj -ne $null) -and ($obj.PSObject.Properties.Name -contains 'status')
  if (-not $hasEnvelope) {
    Write-Output $data
    if ($err) { [Console]::Error.WriteLine($err) }
    if (($data + $err) -match 'cannot prompt for|auto-denied') {
      Show-Denial ($data + "`n" + $err)
      exit 3
    }
    exit 1
  }

  $status = [string]$obj.status
  $tokens = ''
  if ($obj.usage -and $obj.usage.total_tokens) { $tokens = $obj.usage.total_tokens }
  [Console]::Error.WriteLine("[agy] status=$status duration=$($obj.duration_seconds)s turns=$($obj.num_turns) tokens=$tokens")

  if ($Raw) {
    Write-Output $data
    if ($err) { [Console]::Error.WriteLine($err) }
    if ($status -eq 'SUCCESS') { exit 0 } else { exit 1 }
  }

  $structured = $null
  if ($obj.PSObject.Properties.Name -contains 'structured_output') { $structured = $obj.structured_output }
  if ($null -ne $structured) {
    Write-Output ($structured | ConvertTo-Json -Depth 32)
    if ($err) { [Console]::Error.WriteLine($err) }
    if ($status -eq 'SUCCESS') { exit 0 } else { exit 1 }
  }

  $response = [string]$obj.response
  if ([string]::IsNullOrWhiteSpace($response)) {
    # 空正文有三种真实成因，必须区分，否则会把权限问题误报成模型不听话
    if ($err) { [Console]::Error.WriteLine($err) }
    $combined = "$data`n$err"
    if ($combined -match 'cannot prompt for|auto-denied') {
      Show-Denial $combined
      exit 3
    }
    if ($combined -match 'print timeout') {
      [Console]::Error.WriteLine('[agy] print 超时，未产出正文。加大 -Timeout 或拆分任务。')
      exit 124
    }
    if ($status -ne 'SUCCESS') {
      [Console]::Error.WriteLine("[agy] 调用失败（status=$status），无正文。")
      exit 1
    }
    [Console]::Error.WriteLine("[agy] 返回了空正文（status=$status）。")
    exit 1
  }

  Write-Output $response.TrimEnd("`r", "`n")
  if ($err) { [Console]::Error.WriteLine($err) }
  if ($status -eq 'SUCCESS') { exit 0 } else { exit 1 }
}
finally {
  foreach ($f in @($tmpIn, $tmpOut, $tmpErr)) {
    try { if (Test-Path -LiteralPath $f) { Remove-Item -LiteralPath $f -Force } } catch { }
  }
}
