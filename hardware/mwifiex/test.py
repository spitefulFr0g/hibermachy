#!/usr/bin/env python3
"""Run the real hook against disposable module state and command adapters."""
import os
from pathlib import Path
import subprocess
import sys
import tempfile

source_path = Path(sys.argv[1] if len(sys.argv) > 1 else Path(__file__).with_name('sleep-hook'))
source = source_path.read_text()
dropin = source_path.with_name('91-hibermachy-mwifiex.conf').read_text()
service = source_path.with_name('hibermachy-mwifiex.service').read_text()
assert 'Requires=hibermachy-mwifiex.service' in dropin
assert 'After=hibermachy-mwifiex.service' in dropin
assert 'StopWhenUnneeded=yes' in service and 'RemainAfterExit=yes' in service
assert 'TimeoutStopSec=120s' in service, 'service must allow bounded recovery to finish'
callbacks = dict(line.split('=', 1) for line in service.splitlines() if line.startswith('Exec'))
assert set(callbacks) == {'ExecStart', 'ExecStopPost'}
for command in callbacks.values():
    assert command.split()[0] == '/usr/lib/systemd/system-sleep/mwifiex-hibernate'
    assert len(command.split()) == 2
with tempfile.TemporaryDirectory() as directory:
    root = Path(directory)
    module, marker, calls, held = (root / name for name in ('module', 'marker', 'calls', 'held'))
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
    adapted = adapted.replace('/run/hibermachy-mwifiex-staged-sleep', str(held))
    adapted = adapted.replace('/usr/bin/modprobe', str(fake)).replace('timeout 10 modprobe', 'timeout 10 ' + str(fake)).replace('timeout 20 modprobe', 'timeout 20 ' + str(fake))
    adapted = adapted.replace('/usr/bin/logger', '/usr/bin/true').replace('/usr/bin/sleep 1', '/usr/bin/true')
    hook.write_text(adapted)
    def run(phase, action='suspend', transaction=None, **overrides):
        env = dict(os.environ, CASE_ROOT=str(root), SYSTEMD_SLEEP_ACTION=action, **overrides)
        return subprocess.run(['bash', str(hook), phase, transaction or action], env=env, check=False).returncode
    def reset():
        for path in (marker, calls, held, root/'loads'):
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
    # Drive the real service callbacks and each system-sleep phase. The timer
    # wake is not the end of the transaction, including failed-hibernate fallback.
    for actions in (('suspend',), ('suspend', 'hibernate'),
                    ('suspend', 'hibernate', 'suspend-after-failed-hibernate')):
        reset(); module.mkdir()
        assert run(callbacks['ExecStart'].split()[1]) == 0
        assert not module.exists() and marker.exists() and held.exists(), 'service preparation did not hold Wi-Fi'
        for action in actions:
            assert run('pre', action, transaction='suspend-then-hibernate') == 0
            assert run('post', action, transaction='suspend-then-hibernate') == 0
            assert not module.exists(), 'intermediate wake reloaded Wi-Fi before the transaction ended'
        assert run(callbacks['ExecStopPost'].split()[1]) == 0
        assert module.exists() and not marker.exists() and not held.exists()
        assert calls.read_text().splitlines() == ['-r mwifiex_pcie', 'mwifiex_pcie'], 'driver churn inside transaction'
    for failure in ('REMOVE_TIMEOUT', 'REMOVE_FAIL'):
        reset(); module.mkdir()
        # Nonzero ExecStart must block entry to systemd-sleep. ExecStopPost
        # still runs and recovers after failed preparation.
        assert run(callbacks['ExecStart'].split()[1], **{failure: '1'}) != 0, 'failed preparation would enter sleep'
        assert marker.exists() and held.exists()
        assert run(callbacks['ExecStopPost'].split()[1]) == 0 and module.exists() and not held.exists()
    reset()
    assert run(callbacks['ExecStart'].split()[1]) == 0 and run(callbacks['ExecStopPost'].split()[1]) == 0
    assert not calls.exists() and not module.exists() and not held.exists()
    reset(); module.mkdir(); assert run(callbacks['ExecStart'].split()[1]) == 0
    assert run(callbacks['ExecStopPost'].split()[1], LOAD_FAILURES='3') != 0 and marker.exists() and held.exists()
    assert run(callbacks['ExecStopPost'].split()[1]) == 0 and module.exists() and not marker.exists() and not held.exists()
    assert run(callbacks['ExecStopPost'].split()[1]) == 0, 'cleanup must be idempotent'
print('PASS: standalone recovery and transaction hold, timer wake, early wake, fallback, failed preparation, recovery retry')
