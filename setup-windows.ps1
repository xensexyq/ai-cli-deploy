#requires -Version 7.2
[CmdletBinding()]
param(
    [switch]$SkipInstall,
    [switch]$NonInteractive,
    [string]$CodexBaseUrl,
    [string]$ClaudeBaseUrl,
    [string]$CodexModel
)
$ErrorActionPreference = 'Stop'
$python = $null
$pythonArgs = @()
# 逐个试运行，跳过 Microsoft Store 的 python.exe 占位程序。
foreach ($candidate in @(@('python.exe'), @('py.exe', '-3'))) {
    $cmd = Get-Command $candidate[0] -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $cmd) { continue }
    $extra = @($candidate | Select-Object -Skip 1)
    try { & $cmd.Source @extra -c 'import sys; sys.exit(sys.version_info < (3, 8))' *> $null } catch { continue }
    if ($LASTEXITCODE -eq 0) { $python = $cmd; $pythonArgs = $extra; break }
}
if (-not $python) { throw '请先安装 Python 3.8+，并将其加入 PATH。' }
$setupArgs = @((Join-Path $PSScriptRoot 'configure.py'), '--shell', 'powershell', '--profile', $PROFILE.CurrentUserCurrentHost)
if ($SkipInstall) { $setupArgs += '--skip-install' }
if ($NonInteractive) { $setupArgs += '--non-interactive' }
if ($CodexBaseUrl) { $setupArgs += @('--codex-base-url', $CodexBaseUrl) }
if ($ClaudeBaseUrl) { $setupArgs += @('--claude-base-url', $ClaudeBaseUrl) }
if ($CodexModel) { $setupArgs += @('--codex-model', $CodexModel) }
& $python.Source @pythonArgs @setupArgs
if ($LASTEXITCODE -ne 0) { throw "配置失败，退出码：$LASTEXITCODE" }
Write-Host '在当前 PowerShell 中执行：. $PROFILE'
