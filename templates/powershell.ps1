# 此区块由部署脚本管理；修改 key 后请执行 . $PROFILE。
@@EXPORTS@@
Remove-Item Env:ANTHROPIC_API_KEY, Env:CLAUDE_CODE_OAUTH_TOKEN -ErrorAction SilentlyContinue
foreach ($name in @('codex','codexgpt','codexduck','cxg','cxd','claude','codex-use','ai-status')) {
    Remove-Item "Alias:$name" -Force -ErrorAction SilentlyContinue
}

# finally 保证 CLI 退出或抛错后恢复当前 PowerShell 环境。
function Invoke-AiCliNative {
    param([string]$Program, [string[]]$CliArgs, [hashtable]$Overrides)
    $saved = @{}
    foreach ($key in $Overrides.Keys) {
        $saved[$key] = [Environment]::GetEnvironmentVariable($key, 'Process')
        [Environment]::SetEnvironmentVariable($key, $Overrides[$key], 'Process')
    }
    try {
        $native = Get-Command $Program -CommandType Application -ErrorAction Stop | Select-Object -First 1
        & $native.Source @CliArgs
        $global:LASTEXITCODE = $LASTEXITCODE
    } finally {
        foreach ($key in $saved.Keys) {
            [Environment]::SetEnvironmentVariable($key, $saved[$key], 'Process')
        }
    }
}
function codexgpt {
    Invoke-AiCliNative -Program codex -CliArgs (@('-c','model_provider=openai','-c','forced_login_method=chatgpt') + $args) -Overrides @{
        OPENAI_API_KEY=$null; OPENAI_BASE_URL=$null; CODEX_API_KEY=$null
    }
}
function codexduck {
    if (-not $env:DUCKCODING_API_KEY) { throw '请在 $PROFILE 配置 DUCKCODING_API_KEY 并重新加载。' }
    Invoke-AiCliNative -Program codex -CliArgs (@('-c','model_provider=duckcoding') + $args) -Overrides @{
        OPENAI_API_KEY=$null; OPENAI_BASE_URL=$null; CODEX_API_KEY=$null
        CODEX_HOME=(Join-Path $env:AI_CLI_DIR 'codex-duckcoding')
    }
}
function codex {
    $state = Join-Path $env:AI_CLI_DIR 'provider'
    $provider = if (Test-Path -LiteralPath $state) { (Get-Content -LiteralPath $state -Raw).Trim() } else { 'gpt' }
    switch ($provider) {
        gpt { codexgpt @args }
        duck { codexduck @args }
        default { throw '默认来源无效，请执行 codex-use gpt 或 codex-use duck。' }
    }
}
function codex-use {
    param([ValidateSet('gpt','duck')][Parameter(Mandatory)][string]$Provider)
    Set-Content -LiteralPath (Join-Path $env:AI_CLI_DIR 'provider') -Value $Provider -Encoding utf8
    Write-Host "Codex 默认来源：$Provider（下次启动生效）"
}
function cxg { codexgpt @args }
function cxd { codexduck @args }
function claude {
    if (-not $env:ANTHROPIC_AUTH_TOKEN) { throw '请在 $PROFILE 配置 ANTHROPIC_AUTH_TOKEN 并重新加载。' }
    Invoke-AiCliNative -Program claude -CliArgs $args -Overrides @{
        ANTHROPIC_API_KEY=$null; CLAUDE_CODE_OAUTH_TOKEN=$null
    }
}
function ai-status {
    $state = Join-Path $env:AI_CLI_DIR 'provider'
    $provider = if (Test-Path -LiteralPath $state) { (Get-Content -LiteralPath $state -Raw).Trim() } else { 'gpt' }
    Write-Host "Codex 默认来源：$provider"
    Write-Host "DuckCoding 配置：$(Join-Path $env:AI_CLI_DIR 'codex-duckcoding/config.toml')"
    Write-Host ('Codex key：' + $(if ($env:DUCKCODING_API_KEY) { '已配置' } else { '未配置' }))
    Write-Host ('Claude key：' + $(if ($env:ANTHROPIC_AUTH_TOKEN) { '已配置' } else { '未配置' }))
}
