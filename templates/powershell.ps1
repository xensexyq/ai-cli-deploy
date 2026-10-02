# 在这里配置两个 DuckCoding key；ChatGPT 订阅使用浏览器登录。修改后执行 . $PROFILE。
@@EXPORTS@@
# 避免 Claude 同时收到两种认证方式。
Remove-Item Env:ANTHROPIC_API_KEY -ErrorAction SilentlyContinue

# 重新加载时也能替换旧 alias/function。
foreach ($name in @('codex','codexgpt','codexduck','cxg','cxd','claude','codex-use','ai-status')) {
    Remove-Item "Alias:$name" -Force -ErrorAction SilentlyContinue
    Remove-Item "Function:$name" -Force -ErrorAction SilentlyContinue
}

# 清除子进程中的 API 路由；finally 保证退出或抛错后恢复当前终端的环境变量。
function Invoke-AiCliNative {
    param([string]$Program, [string[]]$CliArgs, [hashtable]$Overrides)
    # 新版 PowerShell 中 SetEnvironmentVariable($key, $null) 会留下空字符串，需显式删除。
    function Set-AiCliEnv([string]$Key, $Value) {
        if ($null -eq $Value) { Remove-Item "Env:$Key" -ErrorAction SilentlyContinue }
        else { Set-Item "Env:$Key" -Value $Value }
    }
    $saved = @{}
    foreach ($key in $Overrides.Keys) {
        $saved[$key] = [Environment]::GetEnvironmentVariable($key, 'Process')
        Set-AiCliEnv $key $Overrides[$key]
    }
    try {
        $native = Get-Command $Program -CommandType Application -ErrorAction Stop | Select-Object -First 1
        & $native.Source @CliArgs
        $global:LASTEXITCODE = $LASTEXITCODE
    } finally {
        foreach ($key in $saved.Keys) {
            Set-AiCliEnv $key $saved[$key]
        }
    }
}

function codexgpt {
    Invoke-AiCliNative -Program codex -CliArgs (@('-c','model_provider=openai','-c','forced_login_method=chatgpt') + $args) -Overrides @{
        OPENAI_API_KEY=$null; OPENAI_BASE_URL=$null; CODEX_API_KEY=$null
    }
}

# 完整指定 provider，不依赖未加载的配置文件。
# Windows 的 codex.cmd 会破坏参数中的双引号，因此逐项用不带引号的 -c 写法。
function codexduck {
    if (-not $env:DUCKCODING_API_KEY) { throw '请在 $PROFILE 设置 DUCKCODING_API_KEY，然后执行 . $PROFILE。' }
    $model = if ($env:DUCKCODING_CODEX_MODEL) { $env:DUCKCODING_CODEX_MODEL } else { 'gpt-5.6-sol' }
    $provider = @(
        '-c','model_provider=duckcoding',
        '-c','model_providers.duckcoding.name=DuckCoding',
        '-c','model_providers.duckcoding.base_url=@@CODEX_URL@@',
        '-c','model_providers.duckcoding.wire_api=responses',
        '-c','model_providers.duckcoding.env_key=DUCKCODING_API_KEY',
        '-c','model_providers.duckcoding.requires_openai_auth=false',
        '--model',$model
    )
    Invoke-AiCliNative -Program codex -CliArgs ($provider + $args) -Overrides @{
        OPENAI_API_KEY=$null; OPENAI_BASE_URL=$null; CODEX_API_KEY=$null
    }
}

# codex 默认使用订阅；cxg / cxd 是简写。
function codex { codexgpt @args }
function cxg { codexgpt @args }
function cxd { codexduck @args }

# 只检查本地配置，不联网、不显示密钥。
function ai-status {
    Write-Host ('Codex DuckCoding key：' + $(if ($env:DUCKCODING_API_KEY) { '已配置' } else { '未配置' }))
    Write-Host ('Claude key：' + $(if ($env:ANTHROPIC_AUTH_TOKEN) { '已配置' } else { '未配置' }))
    Write-Host ('DuckCoding Codex 模型：' + $(if ($env:DUCKCODING_CODEX_MODEL) { $env:DUCKCODING_CODEX_MODEL } else { 'gpt-5.6-sol' }))
    Write-Host ('Claude 接口：' + $(if ($env:ANTHROPIC_BASE_URL) { $env:ANTHROPIC_BASE_URL } else { '未配置' }))
}
