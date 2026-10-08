<a id="codexchatgpt-订阅--duckcoding与-claude-code-一键部署"></a>

<div align="center">

# ai-cli-deploy

**Linux / Windows 的 Codex 与 Claude Code 命令行部署工具**

[特性](#特性) · [安装](#安装) · [快速开始](#快速开始) · [恢复](#备份与恢复) · [测试](#测试)

</div>

## 特性

一条命令在新电脑（Linux / Windows）上装好 **Codex** 与 **Claude Code**，并配置好下列快捷命令：

| 命令 | 作用 |
| --- | --- |
| `codex` | Codex，使用 **ChatGPT 订阅**（浏览器登录） |
| `codexgpt` | 同上，ChatGPT 订阅 |
| `codexduck` | Codex，使用 **DuckCoding API**（模型由 `DUCKCODING_CODEX_MODEL` 决定，默认 `gpt-5.6-sol`） |
| `claude` | Claude Code，使用 DuckCoding 的 Claude 接口 |
| `ai-status` | 只检查本地配置：key 是否已填写、模型、接口地址（不联网、不显示密钥） |

切换方式就是**换一个命令启动**：想用订阅就 `codex` / `codexgpt`，想用 DuckCoding 就 `codexduck`，互不影响，也不需要改任何配置文件。两种方式共用同一个 Codex 目录（`~/.codex`），会话历史、技能、项目信任设置都是共享的。

## 工作原理

- `codex` / `codexgpt`：在子进程中清除 `OPENAI_API_KEY`、`OPENAI_BASE_URL`、`CODEX_API_KEY`，并以 `-c model_provider="openai" -c forced_login_method="chatgpt"` 启动，确保走订阅登录。
- `codexduck`：同样清除上述变量，通过 `-c` 完整指定 `duckcoding` provider（地址、`wire_api = "responses"`、`env_key = "DUCKCODING_API_KEY"`、`requires_openai_auth = false`）并带上 `--model`，不依赖 `~/.codex/config.toml` 中的任何配置。
- `claude`：启动配置中导出 `ANTHROPIC_AUTH_TOKEN` 与 `ANTHROPIC_BASE_URL`，并清除冲突的 `ANTHROPIC_API_KEY`，`claude` 直接调用原程序。
- 只修改当前 shell 函数所启动的子进程环境，不影响当前终端；IDE 插件和桌面应用不经过这些函数。

## 安装

支持 Linux / WSL Bash，以及原生 Windows PowerShell；Windows 安装后使用 PowerShell 7。安装器可能下载软件、修改当前用户的 Shell 配置并保存认证信息，应先阅读[备份与恢复](#备份与恢复)。

想先检查源码，可克隆后使用[本地安装入口](#已克隆仓库时)：

```bash
git clone https://github.com/xensexyq/ai-cli-deploy.git
cd ai-cli-deploy
```

一键安装方法见下方。账号登录、订阅与第三方 API 权限需要自行准备，不包含在仓库中。

## 快速开始

### Linux / WSL

用日常使用的普通用户运行，不要 sudo：

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/xensexyq/ai-cli-deploy/main/install.sh)
source ~/.bashrc
ai-status
```

缺少 Node.js 22+ 时自动通过 nvm 安装（无需 sudo）；缺少 Python 3 时尝试用系统包管理器安装（需要 sudo 密码）。

### Windows

在开始菜单打开 PowerShell（自带的 Windows PowerShell 5.1 或 PowerShell 7 都可以），粘贴：

```powershell
irm https://raw.githubusercontent.com/xensexyq/ai-cli-deploy/main/install.ps1 | iex
```

缺少的 PowerShell 7、Node.js LTS、Python 3、Git 会通过 winget 自动安装。完成后**打开 PowerShell 7（pwsh）** 使用上面的命令。快捷命令写在 PowerShell 7 的 `$PROFILE` 中，旧版 Windows PowerShell 5.1、CMD 中不可用。

### 部署时会做什么

1. 用 npm 全局安装或更新 `@openai/codex` 与 `@anthropic-ai/claude-code`；
2. 提示输入两枚 DuckCoding key（Codex 用一枚、Claude 用一枚，可以相同；输入不回显，留空保留旧值或稍后填写）；
3. 把 key 和快捷命令写入 `~/.bashrc`（Linux）或 `$PROFILE`（Windows）中 `# >>> AI CLI >>>` 到 `# <<< AI CLI <<<` 的区块；
4. 从 `~/.claude/settings.json` 中移除重复的认证字段（保留主题、权限、插件等其他设置）。

仓库本身不包含任何密钥，密钥只保存在本机的启动配置文件中。

### 首次使用

```text
codex login        # ChatGPT 订阅：按提示在浏览器登录（无浏览器可用 codex login --device-auth）
codex              # 订阅版
codexduck          # DuckCoding 版，无需 login
claude             # Claude Code
```

参数会原样传递，例如 `codexduck exec "检查当前修改"`、`claude -p "只回复 OK"`。

## 项目结构

```text
install.sh / install.ps1               远程安装入口
setup-linux.sh / setup-windows.ps1     平台环境准备
configure.py                          Shell 配置与认证迁移
templates/                            快捷命令模板
tests/                                隔离配置与命令路由测试
```

## 文档

[本地安装与参数](#已克隆仓库时) · [修改配置](#修改-key-或模型) · [备份恢复](#备份与恢复) · [常见问题](#常见问题)

本项目管理 CLI 启动方式，不等同于桌面端 provider 切换；现有规则和限制见[工作原理](#工作原理)。

## 已克隆仓库时

```bash
bash setup-linux.sh            # Linux
```

```powershell
.\setup-windows.ps1            # Windows，在 PowerShell 7 中运行
```

执行策略阻止运行时，可在当前进程中先执行 `Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass`（只影响当前窗口）。

### 参数

| Linux（bash） | Windows（PowerShell） | 作用 |
| --- | --- | --- |
| `--skip-install` | `-SkipInstall` | Codex / Claude 已安装，跳过 npm 安装 |
| `--non-interactive` | `-NonInteractive` | 不提示输入 key，沿用已有值或当前环境变量 |
| `--codex-base-url URL` | `-CodexBaseUrl URL` | DuckCoding Codex 接口，默认 `https://api.duckcoding.ai/v1` |
| `--claude-base-url URL` | `-ClaudeBaseUrl URL` | DuckCoding Claude 接口，默认 `https://api.duckcoding.ai` |
| `--codex-model 名称` | `-CodexModel 名称` | `codexduck` 默认模型，默认 `gpt-5.6-sol` |

远程一键安装同样支持这些参数：

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/xensexyq/ai-cli-deploy/main/install.sh) --skip-install
```

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/xensexyq/ai-cli-deploy/main/install.ps1))) -SkipInstall
```

重复部署会保留已有的 key、模型和接口地址；命令行显式给出的新值优先。脚本不接受明文 key 参数，避免密钥进入命令历史。

## 修改 key 或模型

直接编辑启动配置中的 AI CLI 区块，然后重新加载：

```bash
# Linux：编辑 ~/.bashrc
export DUCKCODING_API_KEY=你的 Codex key
export ANTHROPIC_AUTH_TOKEN=你的 Claude key
export ANTHROPIC_BASE_URL='https://api.duckcoding.ai'
export DUCKCODING_CODEX_MODEL='gpt-5.6-sol'
```

```powershell
# Windows：notepad $PROFILE
$env:DUCKCODING_API_KEY = '你的 Codex key'
$env:ANTHROPIC_AUTH_TOKEN = '你的 Claude key'
$env:ANTHROPIC_BASE_URL = 'https://api.duckcoding.ai'
$env:DUCKCODING_CODEX_MODEL = 'gpt-5.6-sol'
```

Linux 执行 `source ~/.bashrc`，Windows 执行 `. $PROFILE`。临时换模型可用 `codexduck --model 模型名`。

## 备份与恢复

每次实际修改文件前，都会在原位置生成 `文件名.bak.时间戳` 备份（Linux 权限 `600`）。备份可能含有旧密钥，不要上传或共享。写入中途失败会自动回滚。

恢复：把需要的 `.bak.时间戳` 文件复制回原路径，然后重开终端。也可以直接删除整个 `# >>> AI CLI >>>` 到 `# <<< AI CLI <<<` 区块。旧版脚本的 `~/.codex/duckcoding-env.sh` 中的密钥会被迁移，原文件替换为无密钥的说明。

## 常见问题

| 现象 | 处理 |
| --- | --- |
| `codexgpt` / `codexduck` 不存在 | Linux：`source ~/.bashrc`；Windows：确认在 PowerShell 7 中，执行 `. $PROFILE` |
| 找不到 codex / claude | 重开终端；检查 npm 全局目录是否在 PATH |
| 订阅提示登录 | 执行 `codex login`，确认账号有 Codex 权限 |
| DuckCoding 401/403 | 检查 key、余额/权限和接口地址 |
| 模型不存在 | 改 `DUCKCODING_CODEX_MODEL`，或 `codexduck --model 模型名` |
| Claude 仍走旧路由 | 检查项目内 `.claude/settings.json`、`.claude/settings.local.json` |
| PowerShell profile 没加载 | 确认不是 `-NoProfile` 启动；VS Code 的 PowerShell 主机使用单独的 `$PROFILE`，需在其中再运行一次部署 |
| 重复部署后自定义内容丢失 | AI CLI 区块会被重建，自定义内容请放在区块之外 |

## 测试

```bash
python3 -m unittest discover -s tests -v
```

测试使用临时目录和假密钥，覆盖配置迁移、特殊字符、重复部署、命令路由与参数传递、认证文件保留、非法配置拒绝、失败回滚；已安装 Codex 时会用真实 CLI 的 `features list` 校验 `codexduck` / `codexgpt` 生成的配置（不请求模型服务）。PATH 中有 `pwsh`（或设置 `AI_CLI_TEST_PWSH`）时还会测试 PowerShell 版函数。

已在 Linux + PowerShell 7.6 下全部通过。Windows 原生安装、浏览器登录和 DuckCoding 真实请求需要在目标机器上验收。

## 致谢与许可

<a id="参考"></a>

### 致谢与参考项目

- Codex 与 Claude Code 是本项目部署和配置的外部工具，本仓库提供安装脚本与启动配置，不是这两个工具的实现或官方发行版。

以下官方文档用于认证、配置及环境变量的接口对照：

- [Codex 认证](https://learn.chatgpt.com/docs/auth)
- [Codex 配置参考](https://learn.chatgpt.com/docs/config-file/config-reference)
- [Claude Code 安装](https://code.claude.com/docs/en/setup)
- [Claude Code 环境变量](https://code.claude.com/docs/en/env-vars)

### 许可

[MIT License](LICENSE)
