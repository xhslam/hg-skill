"""BDD 回归：只运行本地假 CLI，不联网，不调用模型。"""
import importlib.util
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import tempfile
import time
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / 'scripts' / 'ask-agy.py'
spec = importlib.util.spec_from_file_location('ask_agy', SCRIPT)
runner = importlib.util.module_from_spec(spec)
spec.loader.exec_module(runner)

FAKE = r'''
import json, os, subprocess, sys, time
from pathlib import Path
prompt = sys.stdin.read()
case = os.environ.get('FAKE_CASE', 'normal')
if case == 'hang':
    time.sleep(30)
if case == 'tree':
    child = subprocess.Popen([sys.executable, '-c', 'import time, pathlib, sys; time.sleep(2); pathlib.Path(sys.argv[1]).write_text("alive")', os.environ['CHILD_MARKER']])
    Path(os.environ['READY_MARKER']).write_text(str(child.pid))
    time.sleep(30)
if case == 'invalid':
    print('not json'); sys.exit(0)
if case == 'denied_text':
    print('no output produced - headless mode cannot prompt for permission'); sys.exit(0)
obj = {'status': 'SUCCESS', 'response': 'OK', 'conversation_id': 'fake-conversation-42'}
if case in ('edit', 'edit_failed'):
    Path('example.py').write_text('answer = 42\n', encoding='utf-8')
    test = subprocess.run([sys.executable, '-c', 'from example import answer; assert answer == 42'], capture_output=True)
    obj['response'] = json.dumps({'changed': ['example.py'], 'test_exit': test.returncode})
    if case == 'edit_failed': obj['status'] = 'ERROR'
if case == 'inspect':
    obj['response'] = json.dumps({'cwd': os.getcwd(), 'args': sys.argv[1:], 'prompt': prompt})
if case == 'structured':
    obj['response'] = ''; obj['structured_output'] = {'items': [1, 2]}
if case == 'empty': obj['response'] = ''
if case == 'empty_structured': obj['response'] = ''; obj['structured_output'] = None
if case == 'missing_status': del obj['status']
if case == 'failed': obj['status'] = 'ERROR'
if case == 'denied': obj['response'] = 'headless mode cannot prompt for permission'
if case == 'soft': print('print timeout after 1s with turn in progress; returning partial output', file=sys.stderr)
if case == 'soft_structured':
    obj['structured_output'] = {'partial': True}
    print('print timeout after 1s', file=sys.stderr)
print(json.dumps(obj))
if case == 'exit_error': sys.exit(7)
'''


class GivenEnvelopeWhenClassified(unittest.TestCase):
    def test_hard_timeout_overrides_success(self):
        self.assertEqual(runner.classify({'status': 'SUCCESS', 'response': 'partial'}, '', 124, 'timed_out')[0], 124)

    def test_cancel_overrides_success(self):
        self.assertEqual(runner.classify({'status': 'SUCCESS', 'response': 'partial'}, '', 0, 'cancelled')[0], 130)


class GivenFakeCliWhenRun(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='agy-test-')
        self.root = Path(self.temp.name)
        self.fake = self.root / 'fake cli.py'
        self.fake.write_text(FAKE, encoding='utf-8')
        self.driver = self.root / 'driver.py'
        self.driver.write_text(
            'import os, runpy, subprocess, sys\n'
            'original = subprocess.Popen\n'
            'def fake_popen(command, **kwargs):\n'
            '    if command[0] == os.path.realpath(sys.executable):\n'
            '        command = [command[0], os.environ["FAKE_SCRIPT"], *command[1:]]\n'
            '    return original(command, **kwargs)\n'
            'subprocess.Popen = fake_popen\n'
            'runpy.run_path(sys.argv.pop(1), run_name="__main__")\n', encoding='utf-8')

    def tearDown(self):
        self.temp.cleanup()

    def env(self, case):
        return {**os.environ, 'AGY_BIN': sys.executable, 'FAKE_CASE': case,
                'PYTHONIOENCODING': 'utf-8', 'FAKE_SCRIPT': str(self.fake)}

    def invoke(self, case='normal', extra=(), prompt='你好，逐条处理。'):
        return subprocess.run([sys.executable, str(self.driver), str(SCRIPT), *extra],
                              input=prompt, text=True, encoding='utf-8', capture_output=True,
                              env=self.env(case), timeout=15)

    def test_normal_then_success(self):
        result = self.invoke()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.strip(), 'OK')

    def test_structured_then_machine_readable(self):
        result = self.invoke('structured')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout), {'items': [1, 2]})

    def test_failures_never_become_success_even_in_raw_mode(self):
        for case, expected in [('exit_error', 1), ('soft', 124), ('soft_structured', 124),
                               ('empty', 1), ('empty_structured', 1), ('missing_status', 1),
                               ('failed', 1), ('denied', 3), ('denied_text', 3), ('invalid', 1)]:
            for raw in [(), ('--raw',)]:
                with self.subTest(case=case, raw=raw):
                    result = self.invoke(case, raw)
                    self.assertEqual(result.returncode, expected, result.stderr)

    def test_hard_timeout_then_124(self):
        result = self.invoke('hang', ('-t', '1', '--grace', '0'))
        self.assertEqual(result.returncode, 124, result.stderr)

    def test_hard_timeout_then_descendants_do_not_continue(self):
        marker, ready = self.root / 'timeout-child-alive', self.root / 'timeout-ready'
        env = {**self.env('tree'), 'CHILD_MARKER': str(marker), 'READY_MARKER': str(ready)}
        result = subprocess.run([sys.executable, str(self.driver), str(SCRIPT), '-t', '1', '--grace', '0'],
                                input='test', text=True, encoding='utf-8', capture_output=True,
                                env=env, timeout=15)
        self.assertEqual(result.returncode, 124, result.stderr)
        self.assertTrue(ready.exists())
        time.sleep(2.2)
        self.assertFalse(marker.exists())

    def test_missing_cli_then_usage_error(self):
        env = {**self.env('normal'), 'AGY_BIN': str(self.root / 'missing-agy.exe')}
        result = subprocess.run([sys.executable, str(self.driver), str(SCRIPT), 'test'],
                                text=True, encoding='utf-8', capture_output=True, env=env, timeout=10)
        self.assertEqual(result.returncode, 2)

    def test_temp_cwd_sandbox_and_prompt_contract(self):
        result = self.invoke('inspect')
        self.assertEqual(result.returncode, 0, result.stderr)
        info = json.loads(result.stdout)
        self.assertNotEqual(Path(info['cwd']).resolve(), Path.cwd().resolve())
        self.assertFalse(Path(info['cwd']).exists())
        self.assertIn('--sandbox', info['args'])
        self.assertNotIn('--dangerously-skip-permissions', info['args'])
        self.assertIn('不要执行', info['prompt'])
        self.assertIn('你好', info['prompt'])

    def test_out_and_record_then_preserve_envelope_and_status(self):
        out, record = self.root / 'out.json', self.root / 'record.json'
        result = self.invoke('soft', ('-o', str(out), '--record', str(record)))
        self.assertEqual(result.returncode, 124)
        self.assertEqual(json.loads(out.read_text(encoding='utf-8'))['status'], 'SUCCESS')
        self.assertEqual(json.loads(record.read_text(encoding='utf-8'))['state'], 'timed_out')
        self.assertNotIn('prompt', json.loads(record.read_text(encoding='utf-8')))

    def test_schema_path_resolved_before_changing_cwd(self):
        schema = self.root / 'schema.json'
        schema.write_text('{"type":"object"}', encoding='utf-8')
        result = self.invoke('inspect', ('-s', str(schema)))
        info = json.loads(result.stdout)
        self.assertEqual(info['args'][info['args'].index('--json-schema') + 1], '{"type":"object"}')

    def test_unsafe_and_invalid_arguments_then_usage_error(self):
        for extra in [('--allow-tools',), ('-d', str(self.root / 'missing')), ('-t', '0'), ('-t', '-1'),
                      ('-t', 'nan'), ('--grace', 'inf'), ('-s', '{}oops'),
                      ('-o', str(self.root / 'same'), '--record', str(self.root / 'same'))]:
            with self.subTest(extra=extra):
                self.assertEqual(self.invoke(extra=extra).returncode, 2)
        self.assertEqual(self.invoke(prompt='  ').returncode, 2)

    def test_project_then_can_modify_code_and_run_validation(self):
        project = self.root / 'project with spaces'
        project.mkdir()
        record = self.root / 'project-run.json'
        result = self.invoke('edit', ('-d', str(project), '--record', str(record)))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((project / 'example.py').read_text(encoding='utf-8'), 'answer = 42\n')
        self.assertEqual(json.loads(result.stdout)['test_exit'], 0)
        saved = json.loads(record.read_text(encoding='utf-8'))
        self.assertEqual(Path(saved['cwd']), project.resolve())
        self.assertEqual(saved['task_kind'], 'project')
        self.assertEqual(saved['conversation_id'], 'fake-conversation-42')
        self.assertEqual(saved['permission_mode'], 'native')
        self.assertTrue(project.is_dir())

    def test_project_then_native_permissions_and_development_contract(self):
        result = self.invoke('inspect', ('-d', str(self.root)))
        info = json.loads(result.stdout)
        self.assertEqual(Path(info['cwd']), self.root.resolve())
        self.assertNotIn('--sandbox', info['args'])
        self.assertNotIn('--dangerously-skip-permissions', info['args'])
        self.assertEqual(info['args'][info['args'].index('--mode') + 1], 'accept-edits')
        self.assertIn('允许读取', info['prompt'])
        self.assertNotIn('不要执行任何命令', info['prompt'])

    def test_project_then_explicit_conversation_and_mode_forwarded(self):
        result = self.invoke('inspect', ('-d', str(self.root), '-c', 'known-session', '--mode', 'plan', '--sandbox'))
        info = json.loads(result.stdout)
        self.assertEqual(info['args'][info['args'].index('--conversation') + 1], 'known-session')
        self.assertEqual(info['args'][info['args'].index('--mode') + 1], 'plan')
        self.assertIn('--sandbox', info['args'])

    def test_project_then_bypass_only_when_explicitly_requested(self):
        result = self.invoke('inspect', ('-d', str(self.root), '--dangerously-skip-permissions'))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('--dangerously-skip-permissions', json.loads(result.stdout)['args'])
        self.assertIn('全部工具', result.stderr)

    def test_project_options_without_directory_then_usage_error(self):
        for extra in [('-c', 'session'), ('--mode', 'auto'), ('--dangerously-skip-permissions',),
                      ('-d', str(self.root), '-c', ' '), ('--mo', 'auto')]:
            with self.subTest(extra=extra):
                self.assertEqual(self.invoke(extra=extra).returncode, 2)

    def test_project_timeout_preserves_project_and_records_final_state(self):
        original = self.root / 'user-file.txt'
        original.write_text('keep', encoding='utf-8')
        record = self.root / 'timeout-run.json'
        result = self.invoke('hang', ('-d', str(self.root), '-t', '1', '--grace', '0', '--record', str(record)))
        self.assertEqual(result.returncode, 124, result.stderr)
        self.assertEqual(original.read_text(encoding='utf-8'), 'keep')
        self.assertEqual(json.loads(record.read_text(encoding='utf-8'))['state'], 'timed_out')
        self.assertTrue(self.root.is_dir())

    def test_failed_project_does_not_erase_partial_changes(self):
        result = self.invoke('edit_failed', ('-d', str(self.root)))
        self.assertEqual(result.returncode, 1)
        self.assertEqual(result.stdout, '')
        self.assertTrue((self.root / 'example.py').is_file())

    def test_signal_cancel_then_tree_terminated(self):
        marker, ready = self.root / 'child-alive', self.root / 'ready'
        env = {**self.env('tree'), 'CHILD_MARKER': str(marker), 'READY_MARKER': str(ready)}
        proc = subprocess.Popen([sys.executable, str(self.driver), str(SCRIPT)],
                                stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                                env=env, creationflags=subprocess.CREATE_NEW_PROCESS_GROUP if os.name == 'nt' else 0)
        try:
            proc.stdin.write(b'test'); proc.stdin.close(); proc.stdin = None
            deadline = time.monotonic() + 5
            while not ready.exists() and time.monotonic() < deadline:
                time.sleep(0.05)
            self.assertTrue(ready.exists())
            if os.name == 'nt':
                # Windows SIGTERM/TerminateProcess 不执行 Python handler；测试真实可用的 Ctrl+Break 路径。
                proc.send_signal(signal.CTRL_BREAK_EVENT)
            else:
                proc.send_signal(signal.SIGTERM)
            proc.communicate(timeout=10)
            self.assertEqual(proc.returncode, 130)
            time.sleep(2.2)
            self.assertFalse(marker.exists())
        finally:
            if proc.poll() is None:
                proc.kill(); proc.communicate()


if __name__ == '__main__':
    unittest.main()
