# 在这里配置两个 DuckCoding key；ChatGPT 订阅使用浏览器登录。
@@EXPORTS@@
# 避免 Claude 同时收到两种认证方式。
unset ANTHROPIC_API_KEY

# 重新 source 时也能替换旧 alias/function。
unalias codex codexgpt codexduck cxg cxd claude codex-use ai-status 2>/dev/null || true
unset -f codex codexgpt codexduck cxg cxd claude codex-use ai-status 2>/dev/null || true

# 清除子进程中的 API 路由；不影响当前终端的环境变量。
codexgpt() (
    unset OPENAI_API_KEY OPENAI_BASE_URL CODEX_API_KEY
    command codex -c 'model_provider="openai"' \
        -c 'forced_login_method="chatgpt"' "$@"
)

# 完整指定 provider，不依赖不存在的 profile 或未加载的配置文件。
codexduck() (
    if [[ -z "${DUCKCODING_API_KEY:-}" ]]; then
        echo '请在 ~/.bashrc 设置 DUCKCODING_API_KEY，然后 source ~/.bashrc。' >&2
        return 1
    fi
    unset OPENAI_API_KEY OPENAI_BASE_URL CODEX_API_KEY
    command codex -c 'model_provider="duckcoding"' \
        -c 'model_providers.duckcoding={name="DuckCoding",base_url="@@CODEX_URL@@",wire_api="responses",env_key="DUCKCODING_API_KEY",requires_openai_auth=false}' \
        --model "${DUCKCODING_CODEX_MODEL:-gpt-5.6-sol}" "$@"
)

# codex 默认使用订阅。
codex() { codexgpt "$@"; }

# 只检查本地配置，不联网、不显示密钥。
ai-status() {
    [[ -n "${DUCKCODING_API_KEY:-}" ]] && echo 'Codex DuckCoding key：已配置' || echo 'Codex DuckCoding key：未配置'
    [[ -n "${ANTHROPIC_AUTH_TOKEN:-}" ]] && echo 'Claude key：已配置' || echo 'Claude key：未配置'
    echo "DuckCoding Codex 模型：${DUCKCODING_CODEX_MODEL:-gpt-5.6-sol}"
    echo "Claude 接口：${ANTHROPIC_BASE_URL:-未配置}"
}
