#!/usr/bin/env python3
"""Shared deployment engine. No credentials are stored inside this package."""
import argparse
from datetime import datetime
import getpass
import json
import os
from pathlib import Path
import re
import shlex
import shutil
import subprocess
import sys
import tempfile
from urllib.parse import urlparse

START, END = '# >>> AI CLI >>>', '# <<< AI CLI <<<'
BLOCK = re.compile(r'^# >>> AI CLI >>>\n.*?^# <<< AI CLI <<<[^\n]*\n?', re.M | re.S)
PACKAGE = Path(__file__).resolve().parent


def read_text(path):
    return path.read_text(encoding='utf-8-sig') if path.exists() else ''


def literal(text, name, shell):
    """Read generated literal assignments, never evaluate a profile."""
    for line in reversed(text.splitlines()):
        if shell == 'powershell':
            match = re.fullmatch(r"\$env:" + re.escape(name) + r"\s*=\s*'((?:[^']|'')*)'", line)
            if match:
                return match[1].replace("''", "'")
        else:
            try:
                parts = shlex.split(line, comments=True)
            except ValueError:
                continue
            if len(parts) == 2 and parts[0] == 'export' and parts[1].startswith(name + '='):
                return parts[1].split('=', 1)[1]
    return ''


def safe_line(value):
    if not isinstance(value, str) or any(ord(c) < 32 or ord(c) == 127 for c in value):
        raise ValueError('配置值必须为不含换行或控制字符的字符串。')
    return value


def endpoint(value):
    value = safe_line(value).rstrip('/')
    parsed = urlparse(value)
    if parsed.scheme != 'https' or not parsed.hostname or parsed.username or parsed.password or parsed.query or parsed.fragment:
        raise ValueError('API 地址必须是无账号、查询参数或片段的 HTTPS URL。')
    return value


def prepare(root, shell, profile, codex_key=None, claude_key=None,
            codex_url=None, claude_url=None, model=None, non_interactive=False):
    root, profile = Path(root), Path(profile).resolve()
    old = read_text(profile)
    if len(BLOCK.findall(old)) != old.count(START) or old.count(START) != old.count(END):
        raise ValueError('启动配置中的 AI CLI 标记不完整，请先修复；未修改配置。')
    claude_dir = Path(os.environ.get('CLAUDE_CONFIG_DIR') or root / '.claude')
    settings = (claude_dir / 'settings.json').resolve()
    raw_settings = read_text(settings)
    data = json.loads(raw_settings) if raw_settings else {}
    if not isinstance(data, dict) or not isinstance(data.get('env', {}), dict):
        raise ValueError('Claude settings.json 必须是 JSON 对象，env 也必须是对象。')
    legacy = root / '.codex/duckcoding-env.sh'
    saved_codex = (literal(old, 'DUCKCODING_API_KEY', shell)
                   or literal(read_text(legacy), 'DUCKCODING_API_KEY', 'bash')
                   or os.environ.get('DUCKCODING_API_KEY', ''))
    saved_claude = (literal(old, 'ANTHROPIC_AUTH_TOKEN', shell)
                    or data.get('env', {}).get('ANTHROPIC_AUTH_TOKEN')
                    or data.get('env', {}).get('ANTHROPIC_API_KEY')
                    or os.environ.get('ANTHROPIC_AUTH_TOKEN', ''))
    def key_value(given, saved, label):
        if given is not None:
            return safe_line(given)
        if non_interactive:
            return safe_line(saved)
        if not sys.stdin.isatty():
            raise ValueError('交互配置需要终端；自动化请使用 --non-interactive。')
        return safe_line(getpass.getpass(label + '（留空保留，未配置则稍后填写）: ') or saved)
    codex_key = key_value(codex_key, saved_codex, 'DuckCoding Codex API key')
    claude_key = key_value(claude_key, saved_claude, 'DuckCoding Claude API key')
    deploy = root / '.config/ai-cli'
    config = deploy / 'codex-duckcoding/config.toml'
    previous_config = read_text(config)
    def previous(name, fallback):
        match = re.search(r'^' + name + r'\s*=\s*(".*")\s*$', previous_config, re.M)
        return json.loads(match[1]) if match else fallback
    codex_url = endpoint(codex_url or previous('base_url', 'https://api.duckcoding.ai/v1'))
    claude_url = endpoint(claude_url or literal(old, 'ANTHROPIC_BASE_URL', shell) or 'https://api.duckcoding.ai')
    model = safe_line(model or previous('model', 'gpt-5.6-sol'))
    values = {'DUCKCODING_API_KEY': codex_key, 'ANTHROPIC_AUTH_TOKEN': claude_key,
              'ANTHROPIC_BASE_URL': claude_url, 'AI_CLI_DIR': str(deploy)}
    if shell == 'bash':
        assignments = '\n'.join('export ' + k + '=' + shlex.quote(v) for k, v in values.items())
    else:
        assignments = '\n'.join('$env:' + k + " = '" + v.replace("'", "''") + "'" for k, v in values.items())
    template = read_text(PACKAGE / 'templates' / ('bash.sh' if shell == 'bash' else 'powershell.ps1'))
    content = template.replace('@@EXPORTS@@', assignments)
    updated = BLOCK.sub('', old).rstrip('\n') + '\n\n' + START + '\n' + content.rstrip('\n') + '\n' + END + '\n'
    if shell == 'bash':
        subprocess.run(['bash', '-n'], input=updated, text=True, check=True, capture_output=True)
    elif shutil.which('pwsh'):
        # Parse only; never execute the profile while validating it.
        parse_command = ('$tokens=$null; $errors=$null; '
                         '[void][System.Management.Automation.Language.Parser]::ParseInput('
                         '[Console]::In.ReadToEnd(),[ref]$tokens,[ref]$errors); '
                         'if ($errors.Count) { exit 1 }')
        subprocess.run(['pwsh', '-NoProfile', '-NonInteractive', '-Command', parse_command],
                       input=updated, text=True, check=True, capture_output=True)
    # TOML string quoting is compatible with JSON for these single-line values.
    toml = ('# Managed by ai-cli-deploy. No API keys in this file.\n'
            'model_provider = "duckcoding"\nmodel = ' + json.dumps(model, ensure_ascii=False) + '\n'
            '[model_providers.duckcoding]\nname = "DuckCoding"\nbase_url = ' + json.dumps(codex_url) + '\n'
            'wire_api = "responses"\nenv_key = "DUCKCODING_API_KEY"\nrequires_openai_auth = false\n')
    # Profile keys are the source of authentication, retaining all unrelated settings.
    cleaned = json.loads(json.dumps(data))
    for name in ('ANTHROPIC_AUTH_TOKEN', 'ANTHROPIC_API_KEY', 'ANTHROPIC_BASE_URL', 'CLAUDE_CODE_OAUTH_TOKEN'):
        cleaned.get('env', {}).pop(name, None)
    if 'env' in cleaned and not cleaned['env']:
        del cleaned['env']
    plan = [(config, toml, 'utf-8'), (profile, updated, 'utf-8-sig' if shell == 'powershell' else 'utf-8')]
    if cleaned != data:
        plan.append((settings, json.dumps(cleaned, ensure_ascii=False, indent=2) + '\n', 'utf-8'))
    state = deploy / 'provider'
    if not state.exists():
        plan.append((state, 'gpt\n', 'utf-8'))
    # Preserve the legacy path for any old source statements, but retire its secret.
    if legacy.exists() and literal(read_text(legacy), 'DUCKCODING_API_KEY', 'bash'):
        plan.append((legacy, '# API key 已迁移到 shell 启动配置的 AI CLI 区块。\n', 'utf-8'))
    return plan


def commit(plan):
    stamp = datetime.now().strftime('%Y%m%d-%H%M%S-%f')
    completed = []
    try:
        for path, content, encoding in plan:
            path = path.resolve()
            blob = content.encode(encoding)
            if path.exists() and path.read_bytes() == blob:
                continue
            path.parent.mkdir(parents=True, exist_ok=True)
            backup = None
            if path.exists():
                backup = path.with_name(path.name + '.bak.' + stamp)
                shutil.copy2(path, backup)
                backup.chmod(0o600)
                print('备份：', backup)
            fd, temporary = tempfile.mkstemp(prefix='.' + path.name + '.', dir=path.parent)
            try:
                with os.fdopen(fd, 'wb') as stream:
                    stream.write(blob)
                os.replace(temporary, path)
                completed.append((path, backup))
            finally:
                if os.path.exists(temporary):
                    os.unlink(temporary)
            print('已配置：', path)
    except Exception:
        for path, backup in reversed(completed):
            if backup:
                shutil.copy2(backup, path)
            else:
                path.unlink()
        raise


def install():
    node, npm = shutil.which('node'), shutil.which('npm.cmd' if os.name == 'nt' else 'npm')
    if not node or not npm:
        raise ValueError('请先安装 Node.js 22+ 和 npm，或使用 --skip-install。')
    version = subprocess.check_output([node, '--version'], text=True).strip()
    if int(version.lstrip('v').split('.')[0]) < 22:
        raise ValueError('请先升级到 Node.js 22 或更新版本。')
    for package in ('@openai/codex@latest', '@anthropic-ai/claude-code@latest'):
        subprocess.run([npm, 'install', '-g', package, '--include=optional'], check=True)


def main():
    parser = argparse.ArgumentParser(description='Codex 双 provider 和 DuckCoding Claude 一键配置')
    parser.add_argument('--shell', choices=['bash', 'powershell'], required=True)
    parser.add_argument('--profile', type=Path)
    parser.add_argument('--skip-install', action='store_true')
    parser.add_argument('--non-interactive', action='store_true')
    parser.add_argument('--codex-base-url')
    parser.add_argument('--claude-base-url')
    parser.add_argument('--codex-model')
    args = parser.parse_args()
    if args.shell == 'powershell' and not args.profile:
        parser.error('请通过 setup-windows.ps1 运行，以确定当前 PowerShell 的 $PROFILE。')
    root = Path.home()
    profile = args.profile or root / '.bashrc'
    plan = prepare(root, args.shell, profile, codex_url=args.codex_base_url,
                   claude_url=args.claude_base_url, model=args.codex_model,
                   non_interactive=args.non_interactive)
    if not args.skip_install:
        install()
    commit(plan)
    print('\n配置完成。Linux：source ~/.bashrc；PowerShell：. $PROFILE')
    print('先执行 ai-status 检查密钥是否已填写。订阅首次登录：cxg login')
    print('切换：codex-use gpt / codex-use duck；临时启动：cxg / cxd；Claude：claude')
    print('备份包含历史配置，可能包含旧密钥，请保存在个人目录。')


if __name__ == '__main__':
    try:
        main()
    except (ValueError, OSError, subprocess.SubprocessError) as error:
        # Do not print JSON contents, command output or credential values.
        if isinstance(error, subprocess.SubprocessError):
            print('配置失败：命令执行失败，请检查依赖、配置语法或安装输出。', file=sys.stderr)
        elif isinstance(error, json.JSONDecodeError):
            print('配置失败：已有 JSON 配置无效，请先修复。', file=sys.stderr)
        else:
            print('配置失败：' + str(error), file=sys.stderr)
        sys.exit(1)
