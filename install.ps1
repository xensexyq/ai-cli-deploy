# 新机器一键部署（Windows）。可在 Windows PowerShell 5.1 或 PowerShell 7 中运行：
#   irm https://raw.githubusercontent.com/xensexyq/ai-cli-deploy/main/install.ps1 | iex
# 需要传参时：
#   & ([scriptblock]::Create((irm https://raw.githubusercontent.com/xensexyq/ai-cli-deploy/main/install.ps1))) -SkipInstall
# 缺少的 PowerShell 7、Node.js LTS、Python 3、Git 会通过 winget 安装。
param(
    [switch]$SkipInstall,
    [switch]$NonInteractive,
    [string]$CodexBaseUrl,
    [string]$ClaudeBaseUrl,
    [string]$CodexModel
)
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$Repo = if ($env:AI_CLI_REPO) { $env:AI_CLI_REPO } else { 'xensexyq/ai-cli-deploy' }
$Branch = if ($env:AI_CLI_BRANCH) { $env:AI_CLI_BRANCH } else { 'main' }
$Dest = if ($env:AI_CLI_HOME) { $env:AI_CLI_HOME } else { Join-Path $env:LOCALAPPDATA 'ai-cli-deploy' }

function Say($msg) { Write-Host "==> $msg" -ForegroundColor Cyan }

function Update-SessionPath {
    $machine = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $user = [Environment]::GetEnvironmentVariable('Path', 'User')
    $env:Path = "$machine;$user"
}

function Test-Command($name, [string[]]$probe) {
    $cmd = Get-Command $name -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $cmd) { return $false }
    # Microsoft Store 的 python.exe 占位程序存在但无法运行，需要实际执行一次。
    try { & $cmd.Source @probe *> $null; return ($LASTEXITCODE -eq 0) } catch { return $false }
}

function Install-WingetPackage($id, $label) {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        throw "未找到 winget，请手动安装 $label 后重试（或从 Microsoft Store 安装 App Installer（应用安装程序）。"
    }
    Say "安装 $label（winget: $id）"
    winget install --id $id -e --source winget --accept-package-agreements --accept-source-agreements --silent
    Update-SessionPath
}

if (-not (Test-Command 'pwsh' @('-NoProfile', '-Command', 'exit 0'))) {
    Install-WingetPackage 'Microsoft.PowerShell' 'PowerShell 7'
}
if (-not $SkipInstall) {
    $nodeOk = Test-Command 'node' @('-e', 'process.exit(+process.versions.node.split(".")[0] >= 22 ? 0 : 1)')
    if (-not $nodeOk) { Install-WingetPackage 'OpenJS.NodeJS.LTS' 'Node.js LTS' }
}
$pyOk = (Test-Command 'python' @('-c', 'import sys; sys.exit(sys.version_info < (3, 8))')) -or
        (Test-Command 'py' @('-3', '-c', 'import sys; sys.exit(sys.version_info < (3, 8))'))
if (-not $pyOk) { Install-WingetPackage 'Python.Python.3.12' 'Python 3.12' }
if (-not (Get-Command git -ErrorAction SilentlyContinue)) { Install-WingetPackage 'Git.Git' 'Git for Windows' }

Say "下载 $Repo@$Branch 到 $Dest"
$tmp = Join-Path ([IO.Path]::GetTempPath()) ("ai-cli-" + [guid]::NewGuid())
New-Item -ItemType Directory -Path $tmp | Out-Null
$zip = Join-Path $tmp 'src.zip'
Invoke-WebRequest -UseBasicParsing -Uri "https://codeload.github.com/$Repo/zip/refs/heads/$Branch" -OutFile $zip
Expand-Archive -Path $zip -DestinationPath $tmp -Force
$src = Get-ChildItem -Path $tmp -Directory | Select-Object -First 1
if (Test-Path $Dest) { Remove-Item -Recurse -Force $Dest }
Move-Item -Path $src.FullName -Destination $Dest
Remove-Item -Recurse -Force $tmp

$setupArgs = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', (Join-Path $Dest 'setup-windows.ps1'))
if ($SkipInstall) { $setupArgs += '-SkipInstall' }
if ($NonInteractive) { $setupArgs += '-NonInteractive' }
if ($CodexBaseUrl) { $setupArgs += @('-CodexBaseUrl', $CodexBaseUrl) }
if ($ClaudeBaseUrl) { $setupArgs += @('-ClaudeBaseUrl', $ClaudeBaseUrl) }
if ($CodexModel) { $setupArgs += @('-CodexModel', $CodexModel) }

Say '开始配置（在 PowerShell 7 中运行）'
& (Get-Command pwsh -CommandType Application | Select-Object -First 1).Source @setupArgs
if ($LASTEXITCODE -ne 0) { throw "配置失败，退出码：$LASTEXITCODE" }

Write-Host ''
Say '完成。之后请使用 PowerShell 7（开始菜单搜索 pwsh），然后执行：ai-status'
Say '配置写入的是 PowerShell 7 的 $PROFILE，旧版 Windows PowerShell 5.1 中不可用。'
