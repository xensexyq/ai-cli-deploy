# Codex 双 Provider 切换与 Claude 一键配置

一条命令在新电脑（Linux / Windows）上装好 **Codex** 与 **Claude Code**，并可一键在 **ChatGPT 订阅版 Codex** 与 **DuckCoding API 版 Codex** 之间切换。

## 快速开始（新电脑一键部署）

**Linux / WSL**（bash，普通用户，不要 sudo）：

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/xensexyq/ai-cli-deploy/main/install.sh)
source ~/.bashrc
ai-status
```

缺少 Node.js 22+ 时自动通过 nvm 安装（无需 sudo）；缺少 Python 3 时尝试用系统包管理器安装。

**Windows**（Windows PowerShell 5.1 或 PowerShell 7 均可）：

```powershell
irm https://raw.githubusercontent.com/xensexyq/ai-cli-deploy/main/install.ps1 | iex
```

缺少的 PowerShell 7、Node.js LTS、Python 3、Git 会通过 winget 自动安装。部署完成后**打开 PowerShell 7（pwsh）**，执行 `ai-status`。需要传参时：

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/xensexyq/ai-cli-deploy/main/install.ps1))) -SkipInstall
```

部署过程中按提示输入两枚 DuckCoding key（输入不回显，可留空稍后填写）。仓库中不包含任何密钥，密钥只写入本机的 `~/.bashrc` 或 `$PROFILE`。

日常使用：

```text
codex-use gpt    # 默认切到 ChatGPT 订阅（首次需 cxg login）
codex-use duck   # 默认切到 DuckCoding
codex            # 按当前默认来源启动
cxg / cxd        # 仅本次使用订阅 / DuckCoding
claude           # 走 DuckCoding 的 Claude Code
```

下文为详细说明；已经克隆仓库时也可以直接运行 `bash setup-linux.sh` / `.\setup-windows.ps1`。

---

适用于 Linux Bash 和 Windows PowerShell 7.2+。所有部署脚本和提示均使用简体中文。

本包配置的服务：

| 命令 | 服务与认证 | 是否改变默认来源 |
| --- | --- | --- |
| `codex` | 使用当前默认来源，首次部署默认为 ChatGPT 订阅 | 否 |
| `codex-use gpt` | 将默认来源设为 ChatGPT 订阅 | 是，跨终端保存 |
| `codex-use duck` | 将默认来源设为 DuckCoding API | 是，跨终端保存 |
| `cxg` / `codexgpt` | 本次启动使用 ChatGPT 订阅 | 否 |
| `cxd` / `codexduck` | 本次启动使用 DuckCoding API | 否 |
| `claude` | 使用 DuckCoding 的 Claude 兼容接口 | 否 |
| `ai-status` | 显示默认来源、配置位置、密钥是否已填写 | 否，不联网、不显示密钥 |

切换只影响新启动的 Codex，不会改变已经运行的会话。订阅和 DuckCoding 是两个不同的服务来源，分别登录或计费；订阅不需要 OpenAI API key。

## 1. 文件与前提

请复制或解压整个 `ai-cli-deploy` 目录，保留文件结构：

```text
ai-cli-deploy/
  install.sh            # 远程一键安装（Linux）
  install.ps1           # 远程一键安装（Windows）
  README.md
  setup-linux.sh
  setup-windows.ps1
  configure.py
  templates/
    bash.sh
    powershell.ps1
  tests/
    test_deploy.py
```

依赖：

- Python 3.8+：负责安全引用密钥、合并 JSON、备份与写入配置。
- Node.js 22+ 与 npm：默认通过 npm 安装或更新 Codex、Claude Code。安装包包含可选的平台二进制依赖，请勿禁用 optional dependencies。
- Windows 使用 PowerShell 7.2+（命令 `pwsh`），不是 Windows PowerShell 5.1，也不是 CMD。建议安装 Git for Windows，便于 CLI 使用 Git/Bash。
- Linux 使用 Bash。WSL 按 Linux 流程单独部署，与 Windows 原生环境各自保存配置。

如果两个 CLI 已经安装且在 PATH 中，可跳过 npm 安装。脚本不会安装 Node、Python 或修改系统级执行策略。

运行前检查：

```text
node --version
npm --version
```

Linux 检查 `python3 --version`；Windows 检查 `python --version` 或 `py -3 --version`，并在 PowerShell 中查看 `$PSVersionTable.PSVersion`。

## 2. Linux 一键部署

在解压后的目录执行：

```bash
bash setup-linux.sh
source ~/.bashrc
ai-status
```

按提示输入两枚 DuckCoding key。输入不回显，留空保留已有值；没有旧值则生成空字段，稍后填写。请以日常使用 CLI 的账号运行，不要使用 `sudo`。

如果已经安装 Codex 和 Claude：

```bash
bash setup-linux.sh --skip-install
source ~/.bashrc
```

两枚 key 都保存在 `~/.bashrc` 的 `AI CLI` 区块中：

```bash
export DUCKCODING_API_KEY='填写 Codex 的 DuckCoding key'
export ANTHROPIC_AUTH_TOKEN='填写 Claude 的 DuckCoding key'
export ANTHROPIC_BASE_URL='https://api.duckcoding.ai'
```

脚本会正确引用交互输入中的特殊字符；手工编辑时需遵守 Bash 引用规则。每次修改后执行 `source ~/.bashrc`。

## 3. Windows 一键部署

打开 **PowerShell 7**，进入解压后的目录：

```powershell
.\setup-windows.ps1
. $PROFILE
ai-status
```

如果脚本因执行策略被阻止，可在当前 PowerShell 进程中设置：

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\setup-windows.ps1
. $PROFILE
```

此设置仅作用于当前 PowerShell 进程。如果组织策略禁止运行脚本，请遵循组织配置；本包不会修改组织策略。

如果两个 CLI 已安装：

```powershell
.\setup-windows.ps1 -SkipInstall
. $PROFILE
```

Windows 原生 PowerShell 不读取 `.bashrc`。对应的启动配置是 `$PROFILE.CurrentUserCurrentHost`，也就是上述 `$PROFILE`。两枚 key 直接保存在该文件的 `AI CLI` 区块中：

```powershell
$env:DUCKCODING_API_KEY = '填写 Codex 的 DuckCoding key'
$env:ANTHROPIC_AUTH_TOKEN = '填写 Claude 的 DuckCoding key'
$env:ANTHROPIC_BASE_URL = 'https://api.duckcoding.ai'
```

查看、编辑实际路径：

```powershell
$PROFILE
notepad $PROFILE
```

修改后执行 `. $PROFILE`。脚本自动处理 Windows 文档目录重定向，不硬编码 `Documents`。VS Code 的 PowerShell 主机可能使用不同的 profile；需要在哪个主机使用，就在那个主机运行部署脚本。

## 4. 首次登录与使用

### ChatGPT 订阅

两个系统命令相同：

```text
cxg login
cxg login status
codex-use gpt
codex
```

按 CLI 提示完成浏览器登录。无浏览器或远程机器可尝试 `cxg login --device-auth`，以 CLI 和账号实际支持情况为准。

### DuckCoding Codex

```text
codex-use duck
codex
```

也可直接执行 `cxd`，不会改变默认来源。DuckCoding 使用 `DUCKCODING_API_KEY`，无需执行 `cxd login` 或 OpenAI 的 API-key 登录命令。

### DuckCoding Claude

```text
claude
```

按 CLI 提示完成必要的首次启动、目录信任等交互。Claude 使用 `ANTHROPIC_AUTH_TOKEN` 作为 Bearer 凭证。脚本清理用户 `settings.json` 中重复的认证字段，保留权限、插件等其他配置。

### 参数传递

```text
cxg exec "解释这个仓库的结构"
cxd exec "检查当前修改"
claude -p "只回复 OK"
```

最后三条命令会访问对应服务，可能产生用量。`ai-status` 只检查本地配置；`cxg login status` 只检查订阅登录状态。密钥显示“已配置”不代表已通过服务端认证。

## 5. 服务地址与模型

本包沿用原脚本中的默认值：

| 设置 | 默认值 |
| --- | --- |
| Codex DuckCoding API | `https://api.duckcoding.ai/v1` |
| Claude DuckCoding API | `https://api.duckcoding.ai` |
| DuckCoding Codex 模型 | `gpt-5.6-sol` |

这些是迁移默认值，并非服务商可用性保证。以 DuckCoding 控制台给出的接口地址、模型名称和密钥权限为准。两枚 key 可以不同；不要在网址中嵌入 key。

Linux 自定义：

```bash
bash setup-linux.sh --skip-install \
  --codex-base-url 'https://你的域名/v1' \
  --claude-base-url 'https://你的域名' \
  --codex-model '服务商提供的模型名称'
source ~/.bashrc
```

Windows 自定义：

```powershell
.\setup-windows.ps1 -SkipInstall `
  -CodexBaseUrl 'https://你的域名/v1' `
  -ClaudeBaseUrl 'https://你的域名' `
  -CodexModel '服务商提供的模型名称'
. $PROFILE
```

重复部署会保留密钥、默认来源，以及已配置的 DuckCoding 模型和服务地址。命令行显式提供的新值优先。

## 6. 配置位置与切换原理

| 内容 | Linux | Windows |
| --- | --- | --- |
| 密钥及启动函数 | `~/.bashrc` | `$PROFILE` |
| 默认来源文件 | `~/.config/ai-cli/provider` | 用户目录下 `.config\ai-cli\provider` |
| DuckCoding Codex 配置 | `~/.config/ai-cli/codex-duckcoding/config.toml` | 用户目录下 `.config\ai-cli\codex-duckcoding\config.toml` |
| 订阅的配置和认证 | Codex 原来的目录，通常为 `~/.codex` | Codex 原来的目录，通常为用户目录下 `.codex` |
| Claude 用户配置 | `~/.claude/settings.json` | 用户目录下 `.claude\settings.json` |

若设置了 `CLAUDE_CONFIG_DIR`，部署脚本会处理该目录中的 `settings.json`。

订阅启动时明确选择内置 `openai` provider 和 ChatGPT 认证，并清除该进程中的 OpenAI API key、API 路由环境变量。DuckCoding 启动时通过 `CODEX_HOME` 使用独立目录，配置 `env_key = "DUCKCODING_API_KEY"` 和 `requires_openai_auth = false`。

**独立目录意味着 DuckCoding 的历史、会话、用户级技能及其他 Codex 配置与订阅目录分开。** 本包不复制订阅登录令牌，也不在切换时删除认证文件。项目级或组织强制配置仍可能影响运行，需要单独检查。

DuckCoding 的 `config.toml` 由部署脚本管理，重复部署会重建它；需要其他自定义设置时请先备份。订阅的 `config.toml` 不由本包重写。

函数只在加载了相应启动配置的 shell 中生效。`codex.exe`、`codex.cmd`、Linux `command codex`、IDE 插件和桌面应用会绕过这些函数；非交互任务应明确加载 profile 或自行提供环境变量和配置目录。

## 7. 无交互部署

先配置已有环境变量或稍后编辑启动配置，然后执行：

```bash
bash setup-linux.sh --skip-install --non-interactive
```

```powershell
.\setup-windows.ps1 -SkipInstall -NonInteractive
```

无交互模式优先保留启动文件中的旧 key，再使用迁移来源和当前环境中的 key；没有值时写入空字段。脚本不接受命令行明文 key 参数，避免密钥进入命令历史和进程参数。

## 8. 备份、迁移与恢复

每次实际修改文件前，在原目录生成 `文件名.bak.时间戳`。Linux 新写入的配置及备份权限为 `600`。Windows 文件继承所在用户目录的访问权限。密钥以明文保存在启动配置中；不要将该文件或含 key 的备份上传到仓库或共享目录。

旧版脚本的 `~/.codex/duckcoding-env.sh` 会先备份，再替换为不含密钥的说明，避免旧的 `source` 语句报错。旧文件的副本仍可能包含历史密钥。配置文件格式错误会在写入前报错，写入中途失败会尝试恢复已经修改的文件。

恢复方法：

1. 根据部署输出找到本次修改前的 `.bak.时间戳` 文件。
2. 将需要恢复的备份复制回对应原路径，保留备份本身。
3. 关闭并重新打开终端，避免旧函数继续留在当前进程中。

如果是首次部署、没有原启动文件备份，可以从 `.bashrc` / `$PROFILE` 删除整个 `# >>> AI CLI >>>` 到 `# <<< AI CLI <<<` 区块，然后打开新终端。DuckCoding 独立目录中可能已有会话历史，不要为停用快捷命令而直接删除该目录。npm 安装或升级的 CLI 版本不随配置恢复而回退。

## 9. 常见问题

| 现象 | 检查方法 |
| --- | --- |
| `cxg` / `cxd` 不存在 | Linux 执行 `source ~/.bashrc`；PowerShell 执行 `. $PROFILE` |
| CLI 找不到 | 检查 `codex --version`、`claude --version`、npm 全局可执行目录是否在 PATH；必要时重开终端 |
| 订阅提示登录 | 执行 `cxg login`；确认使用具有 Codex 访问权限的账号 |
| DuckCoding 401/403 | 检查 key、余额/权限和服务地址；本包不会自动测试或修正服务商账号 |
| 模型不存在 | 使用服务商提供的模型名重新部署，或本次执行 `cxd --model 模型名称` |
| Claude 仍使用旧路由 | 检查项目 `.claude/settings.json`、`.claude/settings.local.json` 和组织配置；本包只迁移用户级认证字段 |
| PowerShell profile 不加载 | 确认不是 `-NoProfile` 启动，检查执行策略和当前主机的 `$PROFILE` 路径 |
| `codex-use` 不影响桌面应用 | 切换仅作用于本包提供的 shell 函数 |
| 重复部署后自定义函数丢失 | 管理区块会被重建，把与本包无关的自定义内容放在区块外 |

## 10. 测试与参考

在 Linux 下进入本包目录运行：

```bash
python3 -m unittest discover -s tests -v
```

测试使用临时目录和假密钥，涵盖配置迁移、特殊字符、重复部署、默认来源持久化、参数传递、认证文件保留、非法配置拒绝及失败回滚。Linux 下若安装了 Codex，还会运行不请求模型服务的 `features list` 验证配置解析。若 PATH 中有 `pwsh`，还会验证 PowerShell 语法、函数路由、退出码和环境恢复；没有该运行时则跳过这一项。也可以设置 `AI_CLI_TEST_PWSH` 为测试用 `pwsh` 的路径。

当前交付的 8 项测试已在 Linux 通过，其中 PowerShell 函数测试使用 Linux 上的 PowerShell 7.4.6。Windows 原生 npm 安装、Windows 的 CLI 启动 shim、浏览器登录和 DuckCoding 真实请求仍需要在目标机器上验收。测试不会验证 API key 的有效性，也没有修改本机真实账号配置。

官方资料：

- [Codex 认证：ChatGPT 登录与自定义 provider 的环境变量认证](https://learn.chatgpt.com/docs/auth)
- [Codex 配置参考：provider、env_key、CODEX 配置字段](https://learn.chatgpt.com/docs/config-file/config-reference)
- [Claude Code 安装：npm、Node 版本与 Windows 支持](https://code.claude.com/docs/en/setup)
- [Claude Code 环境变量：ANTHROPIC_AUTH_TOKEN 等认证变量](https://code.claude.com/docs/en/env-vars)

以上官方文档用于确认 CLI 配置机制；DuckCoding 服务地址和模型默认值来自原脚本，本包未找到可核对的 DuckCoding 官方公开配置文档。
