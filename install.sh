#!/usr/bin/env bash
# 新机器一键部署（Linux / WSL）：
#   bash <(curl -fsSL https://raw.githubusercontent.com/xensexyq/ai-cli-deploy/main/install.sh)
# 额外参数会原样传给 setup-linux.sh，例如：
#   bash <(curl -fsSL .../install.sh) --skip-install
set -euo pipefail

REPO="${AI_CLI_REPO:-xensexyq/ai-cli-deploy}"
BRANCH="${AI_CLI_BRANCH:-main}"
DEST="${AI_CLI_HOME:-$HOME/.local/share/ai-cli-deploy}"

say() { printf '\033[1;36m==>\033[0m %s\n' "$*"; }
die() { printf '\033[1;31m错误：\033[0m%s\n' "$*" >&2; exit 1; }

[[ $EUID -ne 0 ]] || die '请以日常使用 CLI 的普通用户运行，不要使用 sudo/root。'
command -v curl >/dev/null || die '请先安装 curl。'
command -v tar >/dev/null || die '请先安装 tar。'

if ! command -v python3 >/dev/null; then
    say '未找到 python3，尝试安装（需要 sudo）'
    if command -v apt-get >/dev/null; then sudo apt-get update && sudo apt-get install -y python3
    elif command -v dnf >/dev/null; then sudo dnf install -y python3
    elif command -v pacman >/dev/null; then sudo pacman -S --noconfirm python
    elif command -v brew >/dev/null; then brew install python
    else die '请手动安装 Python 3.8+ 后重试。'
    fi
fi

node_major() { node -p 'process.versions.node.split(".")[0]' 2>/dev/null || echo 0; }
if ! command -v npm >/dev/null || (( $(node_major) < 22 )); then
    say '未找到 Node.js 22+，通过 nvm 安装 Node LTS（无需 sudo）'
    export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
    if [[ ! -s "$NVM_DIR/nvm.sh" ]]; then
        curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
    fi
    # shellcheck disable=SC1091
    set +u; . "$NVM_DIR/nvm.sh"; nvm install --lts; nvm alias default 'lts/*'; set -u
fi

say "下载 $REPO@$BRANCH 到 $DEST"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
curl -fsSL "https://codeload.github.com/$REPO/tar.gz/refs/heads/$BRANCH" | tar -xz -C "$tmp" --strip-components=1
rm -rf "$DEST"
mkdir -p "$(dirname "$DEST")"
mv "$tmp" "$DEST"
trap - EXIT

say '开始配置'
bash "$DEST/setup-linux.sh" "$@"

say '完成。请执行：source ~/.bashrc && ai-status'
