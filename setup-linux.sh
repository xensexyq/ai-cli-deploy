#!/usr/bin/env bash
if [[ "${BASH_SOURCE[0]}" != "$0" ]]; then
    echo '请使用 bash setup-linux.sh，完成后再 source ~/.bashrc。' >&2
    return 1
fi
set -euo pipefail
set +x
command -v python3 >/dev/null || { echo '请先安装 Python 3.8 或更新版本。' >&2; exit 1; }
deploy_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
exec python3 "$deploy_dir/configure.py" --shell bash "$@"
