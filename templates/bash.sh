# 此区块由部署脚本管理；修改 key 后请 source ~/.bashrc。
@@EXPORTS@@
unset ANTHROPIC_API_KEY CLAUDE_CODE_OAUTH_TOKEN
unalias codex codexgpt codexduck cxg cxd claude codex-use ai-status 2>/dev/null || true
unset -f codex codexgpt codexduck cxg cxd claude codex-use ai-status 2>/dev/null || true

codexgpt() (
    unset OPENAI_API_KEY OPENAI_BASE_URL CODEX_API_KEY
    command codex -c model_provider=openai -c forced_login_method=chatgpt "$@"
)
codexduck() (
    if [[ -z "${DUCKCODING_API_KEY:-}" ]]; then
        echo '请在 ~/.bashrc 配置 DUCKCODING_API_KEY 并重新加载。' >&2
        return 1
    fi
    unset OPENAI_API_KEY OPENAI_BASE_URL CODEX_API_KEY
    export CODEX_HOME="$AI_CLI_DIR/codex-duckcoding"
    command codex -c model_provider=duckcoding "$@"
)
codex() {
    local provider=gpt
    if [[ -f "$AI_CLI_DIR/provider" ]]; then
        IFS= read -r provider < "$AI_CLI_DIR/provider" || true
    fi
    case "$provider" in
        gpt) codexgpt "$@" ;;
        duck) codexduck "$@" ;;
        *) echo '默认来源无效，请执行 codex-use gpt 或 codex-use duck。' >&2; return 1 ;;
    esac
}
codex-use() {
    case "${1:-}" in
        gpt|duck)
            (umask 077; printf '%s\n' "$1" > "$AI_CLI_DIR/provider") || return
            printf 'Codex 默认来源：%s（下次启动生效）\n' "$1" ;;
        *) echo '用法：codex-use gpt|duck' >&2; return 2 ;;
    esac
}
cxg() { codexgpt "$@"; }
cxd() { codexduck "$@"; }
claude() (
    if [[ -z "${ANTHROPIC_AUTH_TOKEN:-}" ]]; then
        echo '请在 ~/.bashrc 配置 ANTHROPIC_AUTH_TOKEN 并重新加载。' >&2
        return 1
    fi
    unset ANTHROPIC_API_KEY CLAUDE_CODE_OAUTH_TOKEN
    command claude "$@"
)
ai-status() {
    local provider=gpt
    if [[ -f "$AI_CLI_DIR/provider" ]]; then
        IFS= read -r provider < "$AI_CLI_DIR/provider" || true
    fi
    printf 'Codex 默认来源：%s\n' "$provider"
    printf 'DuckCoding 配置：%s/codex-duckcoding/config.toml\n' "$AI_CLI_DIR"
    [[ -n "${DUCKCODING_API_KEY:-}" ]] && echo 'Codex key：已配置' || echo 'Codex key：未配置'
    [[ -n "${ANTHROPIC_AUTH_TOKEN:-}" ]] && echo 'Claude key：已配置' || echo 'Claude key：未配置'
}
