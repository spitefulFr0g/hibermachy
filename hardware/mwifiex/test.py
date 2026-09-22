#!/usr/bin/env python3
"""Run the real hook against disposable module state and command adapters."""
import os
from pathlib import Path
import subprocess
import sys
import tempfile

source = Path(sys.argv[1] if len(sys.argv) > 1 else Path(__file__).with_name('sleep-hook')).read_text()
with tempfile.TemporaryDirectory() as directory:
    root = Path(directory)
    module, marker, calls = (root / name for name in ('module', 'marker', 'calls'))
    fake = root / 'modprobe'
    fake.write_text('''#!/usr/bin/python3
import os, pathlib, sys
p=pathlib.Path(os.environ['CASE_ROOT'])
with (p/'calls').open('a') as f: f.write(' '.join(sys.argv[1:])+'\\n')
if '-r' in sys.argv:
 if os.environ.get('REMOVE_FAIL') == '1': sys.exit(1)
 (p/'module').rmdir()
 sys.exit(124 if os.environ.get('REMOVE_TIMEOUT') == '1' else 0)
n=int((p/'loads').read_text())+1 if (p/'loads').exists() else 1
(p/'loads').write_text(str(n))
if n <= int(os.environ.get('LOAD_FAILURES','0')): sys.exit(1)
(p/'module').mkdir(exist_ok=True)
''')
    fake.chmod(0o755)
    hook = root / 'hook'
    # Production has no environment-controlled paths or executables.
    adapted = source.replace('/sys/module/mwifiex_pcie', str(module)).replace('/run/mwifiex-unloaded-for-hibernate', str(marker))
    adapted = adapted.replace('/usr/bin/modprobe', str(fake)).replace('timeout 10 modprobe', 'timeout 10 ' + str(fake)).replace('timeout 20 modprobe', 'timeout 20 ' + str(fake))
    adapted = adapted.replace('/usr/bin/logger', '/usr/bin/true').replace('/usr/bin/sleep 1', '/usr/bin/true')
    hook.write_text(adapted)
    def run(phase, action='suspend', **overrides):
        env = dict(os.environ, CASE_ROOT=str(root), SYSTEMD_SLEEP_ACTION=action, **overrides)
        return subprocess.run(['bash', str(hook), phase, 'suspend-then-hibernate'], env=env, check=False).returncode
    def reset():
        for path in (marker, calls, root/'loads'):
            path.unlink(missing_ok=True)
        if module.exists(): module.rmdir()
    # The actual failure: timeout/nonzero return despite the module disappearing.
    module.mkdir()
    run('pre', 'hibernate', REMOVE_TIMEOUT='1')
    assert not module.exists() and marker.exists(), 'timeout lost restoration obligation'
    assert run('post', 'hibernate') == 0 and module.exists() and not marker.exists()
    for action in ('suspend', 'hibernate', 'suspend-after-failed-hibernate'):
        reset(); module.mkdir()
        assert run('pre', action) == 0 and marker.exists() and not module.exists()
        assert run('post', action) == 0 and module.exists() and not marker.exists()
    reset()
    assert run('pre') == 0 and run('post') == 0 and not calls.exists(), 'loaded previously absent driver'
    module.mkdir(); run('pre')
    assert run('post', LOAD_FAILURES='3') != 0 and marker.exists() and not module.exists()
    assert run('post') == 0 and module.exists() and not marker.exists(), 'lost retry state'
    reset(); module.mkdir(); run('pre')
    assert run('post', LOAD_FAILURES='1') == 0 and (root/'loads').read_text() == '2'
    reset(); module.mkdir()
    run('pre', REMOVE_FAIL='1')
    assert module.exists() and marker.exists()
    assert run('post') == 0 and not marker.exists(), 'failed unload could not recover'
    reset(); module.mkdir()
    assert run('pre', 'hybrid-sleep') == 0 and not calls.exists()
print('PASS: timed-out removal, both sleep steps, absent driver, bounded reload retries, retained recovery state')
