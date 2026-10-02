import contextlib
import importlib.util
import io
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
from unittest.mock import patch

PACKAGE = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('configure', PACKAGE / 'configure.py')
deploy = importlib.util.module_from_spec(spec)
spec.loader.exec_module(deploy)


class DeploymentTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='ai-cli-tests-')
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name) / 'user with spaces'
        self.root.mkdir()
        self.rc = self.root / '.bashrc'
        self.rc.write_text('export KEEP_ME=yes\n')
        self.settings = self.root / '.claude/settings.json'
        self.settings.parent.mkdir()
        self.settings.write_text(json.dumps({'env': {'ANTHROPIC_AUTH_TOKEN': 'old-claude', 'KEEP_ENV': 'yes'}, 'permissions': {'allow': ['Read']}}))
        self.legacy = self.root / '.codex/duckcoding-env.sh'
        self.legacy.parent.mkdir()
        self.legacy.write_text("export DUCKCODING_API_KEY='old-codex'\n")
        self.auth = self.root / '.codex/auth.json'
        self.auth.write_text('{"test":"unchanged"}')
        self.env_patch = patch.dict(os.environ, {'CLAUDE_CONFIG_DIR': '', 'DUCKCODING_API_KEY': '', 'ANTHROPIC_AUTH_TOKEN': ''})
        self.env_patch.start()
        self.addCleanup(self.env_patch.stop)

    def configure(self, shell='bash', **kwargs):
        profile = self.rc if shell == 'bash' else self.root / 'PowerShell/Microsoft.PowerShell_profile.ps1'
        with contextlib.redirect_stdout(io.StringIO()):
            plan = deploy.prepare(self.root, shell, profile, non_interactive=True, **kwargs)
            deploy.commit(plan)
        return profile

    def test_migration_repeat_and_auth(self):
        self.configure()
        text = self.rc.read_text()
        self.assertIn('old-codex', text)
        self.assertIn('old-claude', text)
        self.assertEqual(json.loads(self.settings.read_text()), {'env': {'KEEP_ENV': 'yes'}, 'permissions': {'allow': ['Read']}})
        self.assertNotIn('old-codex', self.legacy.read_text())
        self.assertTrue(list(self.legacy.parent.glob('duckcoding-env.sh.bak.*')))
        self.configure()
        self.assertEqual(text, self.rc.read_text())
        self.assertEqual(self.auth.read_text(), '{"test":"unchanged"}')
        self.assertEqual(self.rc.stat().st_mode & 0o777, 0o600)

    def test_shell_routing_and_arguments(self):
        key = "test-'quoted $value $(false) ; & key"
        self.configure(codex_key=key, claude_key='test-claude')
        bin_dir = self.root / 'bin'
        bin_dir.mkdir()
        mock = '#!/usr/bin/env python3\nimport os,sys,json\nprint(json.dumps({"args":sys.argv[1:],"key":os.environ.get("DUCKCODING_API_KEY"),"home":os.environ.get("CODEX_HOME"),"openai":os.environ.get("OPENAI_API_KEY"),"token":os.environ.get("ANTHROPIC_AUTH_TOKEN"),"conflict":os.environ.get("ANTHROPIC_API_KEY")}))\n'
        for name in ('codex', 'claude'):
            path = bin_dir / name
            path.write_text(mock)
            path.chmod(0o700)
        env = dict(os.environ, PATH=str(bin_dir) + ':' + os.environ['PATH'], OPENAI_API_KEY='keep-me', ANTHROPIC_API_KEY='conflict')
        commands = 'source "$1"; source "$1"; cxg exec "two words"; cxd exec "duck prompt"; codex --version; claude -p "a prompt"; test "$OPENAI_API_KEY" = keep-me'
        result = subprocess.run(['bash', '-c', commands, 'test', str(self.rc)], env=env, text=True, capture_output=True, check=True)
        rows = [json.loads(line) for line in result.stdout.splitlines()]
        self.assertEqual(len(rows), 4)
        # codex 与 cxg 一样始终走订阅；cxd 走 DuckCoding，且共用同一个 CODEX_HOME。
        for row in (rows[0], rows[2]):
            self.assertEqual(row['args'][:4], ['-c', 'model_provider="openai"', '-c', 'forced_login_method="chatgpt"'])
        self.assertEqual(rows[0]['args'][-2:], ['exec', 'two words'])
        self.assertEqual(rows[1]['args'][:2], ['-c', 'model_provider="duckcoding"'])
        self.assertIn('base_url="https://api.duckcoding.ai/v1"', rows[1]['args'][3])
        self.assertEqual(rows[1]['args'][4:], ['--model', 'gpt-5.6-sol', 'exec', 'duck prompt'])
        for row in rows[:3]:
            self.assertIsNone(row['openai'])
            self.assertIsNone(row['home'])
            self.assertEqual(row['key'], key)
        self.assertEqual(rows[3]['args'], ['-p', 'a prompt'])
        self.assertEqual(rows[3]['token'], 'test-claude')
        self.assertIsNone(rows[3]['conflict'])
        fail = subprocess.run(['bash', '-c', 'source "$1"; unset DUCKCODING_API_KEY; cxd', 'test', str(self.rc)], env=env, capture_output=True)
        self.assertEqual(fail.returncode, 1)
        self.assertFalse(fail.stdout)

    def test_powershell_output(self):
        key = "test-a'b$variable;中文"
        profile = self.configure(shell='powershell', codex_key=key)
        self.assertTrue(profile.read_bytes().startswith(b'\xef\xbb\xbf'))
        text = deploy.read_text(profile)
        self.assertEqual(deploy.literal(text, 'DUCKCODING_API_KEY', 'powershell'), key)
        self.configure(shell='powershell')
        self.assertEqual(text, deploy.read_text(profile))
        self.assertNotIn('@@EXPORTS@@', text)

    @unittest.skipUnless(os.environ.get('AI_CLI_TEST_PWSH') or shutil.which('pwsh'), 'PowerShell runtime not available')
    def test_powershell_runtime(self):
        runtime = os.environ.get('AI_CLI_TEST_PWSH') or shutil.which('pwsh')
        profile = self.configure(shell='powershell', codex_key='test-duck', claude_key='test-claude')
        # Pass source via stdin to avoid native command-line quoting differences.
        parse = '$t=$null; $e=$null; [void][System.Management.Automation.Language.Parser]::ParseInput([Console]::In.ReadToEnd(),[ref]$t,[ref]$e); if ($e.Count) { exit 1 }'
        for path in (PACKAGE / 'setup-windows.ps1', profile):
            subprocess.run([runtime, '-NoProfile', '-NonInteractive', '-Command', parse], input=deploy.read_text(path), text=True, check=True, capture_output=True)
        if os.name == 'nt':
            return  # Native Windows needs actual CLI shims; POSIX mock executables below.
        bin_dir = self.root / 'bin'
        bin_dir.mkdir()
        mock = '#!/usr/bin/env python3\nimport os,sys,json\nprint(json.dumps({"args":sys.argv[1:],"home":os.environ.get("CODEX_HOME"),"openai":os.environ.get("OPENAI_API_KEY"),"token":os.environ.get("ANTHROPIC_AUTH_TOKEN")}))\nsys.exit(7 if "--fail" in sys.argv else 0)\n'
        for name in ('codex', 'claude'):
            path = bin_dir / name
            path.write_text(mock)
            path.chmod(0o700)
        quote = lambda text: "'" + str(text).replace("'", "''") + "'"
        command = (
            '. ' + quote(profile) + '; . ' + quote(profile) + '; '
            'cxg exec "two words"; cxd exec "duck prompt"; '
            'codex --version; claude -p "a prompt"; '
            'cxd --fail; if ($LASTEXITCODE -ne 7) { throw "Exit status lost" }; '
            'if ($env:OPENAI_API_KEY -ne "keep-me") { throw "Environment not restored" }; '
            'if ($env:CODEX_HOME -ne "original-home") { throw "Codex home not restored" }; '
            'exit 0')
        env = dict(os.environ, PATH=str(bin_dir) + ':' + os.environ['PATH'], OPENAI_API_KEY='keep-me', CODEX_HOME='original-home')
        result = subprocess.run([runtime, '-NoProfile', '-NonInteractive', '-Command', command], env=env, capture_output=True, text=True, check=True)
        rows = [json.loads(line) for line in result.stdout.splitlines()]
        self.assertEqual(len(rows), 5)
        self.assertEqual(rows[0]['args'][-2:], ['exec', 'two words'])
        for row in (rows[0], rows[2]):
            self.assertIn('model_provider=openai', row['args'])
        for row in (rows[1], rows[4]):
            self.assertIn('model_provider=duckcoding', row['args'])
            self.assertIn('model_providers.duckcoding.base_url=https://api.duckcoding.ai/v1', row['args'])
            self.assertIn('gpt-5.6-sol', row['args'])
        for row in rows:
            self.assertEqual(row['home'], 'original-home')
        for row in (rows[0], rows[1], rows[2], rows[4]):
            self.assertIsNone(row['openai'])
        self.assertEqual(rows[3]['args'], ['-p', 'a prompt'])

    def test_validation_is_non_mutating(self):
        original = self.rc.read_bytes()
        self.settings.write_text('{invalid')
        with self.assertRaises(json.JSONDecodeError):
            self.configure()
        self.assertEqual(self.rc.read_bytes(), original)
        self.settings.write_text('{}')
        for kwargs in ({'codex_key': 'bad\nkey'}, {'codex_url': 'https://user:secret@example.org'},
                       {'codex_url': "https://example.org/v1'\"x"}, {'claude_url': 'https://example.org/$(id)'}):
            with self.assertRaises(ValueError):
                self.configure(**kwargs)
        self.assertEqual(self.rc.read_bytes(), original)
        self.rc.write_text(deploy.START + '\n')
        with self.assertRaises(ValueError):
            self.configure()

    def test_custom_config_preserved(self):
        self.configure(codex_url='https://example.org/v1', claude_url='https://example.org', model='custom-model')
        text = self.rc.read_text()
        self.assertIn('base_url="https://example.org/v1"', text)
        self.assertIn("export DUCKCODING_CODEX_MODEL='custom-model'", text)
        self.configure()
        self.assertEqual(text, self.rc.read_text())
        ps = self.configure(shell='powershell', codex_url='https://example.org/v1', model='custom-model')
        self.configure(shell='powershell')
        self.assertIn('model_providers.duckcoding.base_url=https://example.org/v1', deploy.read_text(ps))

    def test_rollback(self):
        original = self.rc.read_bytes()
        replacement = os.replace
        count = 0
        def fail_second(src, dst):
            nonlocal count
            count += 1
            if count == 2:
                raise OSError('simulated disk error')
            return replacement(src, dst)
        with patch.object(deploy.os, 'replace', side_effect=fail_second):
            with self.assertRaises(OSError):
                self.configure()
        self.assertEqual(original, self.rc.read_bytes())
        self.assertIn('old-claude', self.settings.read_text())

    @unittest.skipUnless(shutil.which('codex'), 'Codex CLI not installed')
    def test_real_codex_config_parser(self):
        self.configure(codex_key='fake-test-key')
        home = self.root / 'codex-home'
        home.mkdir()
        env = dict(os.environ, CODEX_HOME=str(home))
        for command in ('cxd features list', 'cxg features list'):
            result = subprocess.run(['bash', '-c', 'source "$1"; ' + command, 'test', str(self.rc)], env=env, capture_output=True, text=True, timeout=60)
            self.assertEqual(result.returncode, 0, result.stderr)


if __name__ == '__main__':
    unittest.main(verbosity=2)
