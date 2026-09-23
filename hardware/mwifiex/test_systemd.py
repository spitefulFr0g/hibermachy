#!/usr/bin/env python3
"""Exercise real systemd unit lifetimes using harmless user-service fixtures.

Explicit integration check; requires a running user manager. Only disposable
user units and temporary callback files are used, never real sleep or devices.
"""
import os
from pathlib import Path
import subprocess
import tempfile
import time

source = Path(__file__).resolve().parent
runtime = Path(os.environ['XDG_RUNTIME_DIR'])/'systemd/user'
runtime.mkdir(parents=True, exist_ok=True)


def ctl(*args, check=True):
    return subprocess.run(['systemctl', '--user', *args], capture_output=True, text=True, check=check, timeout=15)


for case in ('complete', 'early-wake', 'sleep-failure', 'touch-cleanup-failure', 'prepare-failure', 'wifi-cleanup-failure'):
    with tempfile.TemporaryDirectory(prefix='hbr-unit-') as temp:
        root = Path(temp)
        guard = f'hbr-wifi-test-{os.getpid()}-{case}.service'
        main = f'hbr-sleep-test-{os.getpid()}-{case}.service'
        helper = root/'callback.py'
        helper.write_text('''import pathlib,sys
p=pathlib.Path(__file__).parent
with (p/'calls').open('a') as f: f.write(sys.argv[1]+'\\n')
case=(p/'case').read_text()
fail={('prepare-failure','hold'), ('touch-cleanup-failure','touch'),
      ('sleep-failure','main'), ('wifi-cleanup-failure','restore')}
sys.exit(1 if (case,sys.argv[1]) in fail else 0)
''')
        (root/'case').write_text(case)
        guard_code = (source/'hibermachy-mwifiex.service').read_text()
        guard_code = guard_code.replace('systemd-suspend-then-hibernate.service', main)
        guard_code = guard_code.replace('/usr/lib/systemd/system-sleep/mwifiex-hibernate', f'/usr/bin/python3 {helper}')
        dropin = (source/'91-hibermachy-mwifiex.conf').read_text().replace('hibermachy-mwifiex.service', guard)
        main_code = dropin + f'\n[Service]\nType=oneshot\nExecStart=/usr/bin/python3 {helper} main\nExecStopPost=/usr/bin/python3 {helper} touch\n'
        files = [runtime/guard, runtime/main]
        try:
            files[0].write_text(guard_code); files[1].write_text(main_code)
            ctl('daemon-reload')
            result = ctl('start', main, check=False)
            assert (result.returncode == 0) == (case in ('complete', 'early-wake', 'wifi-cleanup-failure')), result.stderr
            for _ in range(100):
                calls = (root/'calls').read_text().splitlines() if (root/'calls').exists() else []
                state = ctl('show', '-p', 'ActiveState', '--value', guard).stdout.strip()
                if 'restore' in calls and state in ('inactive', 'failed'): break
                time.sleep(.05)
            assert calls.count('hold') == 1 and calls.count('restore') == 1, (case, calls, state)
            if case == 'prepare-failure': assert 'main' not in calls, calls
            else: assert calls == ['hold', 'main', 'touch', 'restore'], (case, calls)
            assert state == ('failed' if case in ('prepare-failure', 'wifi-cleanup-failure') else 'inactive'), (case, state)
            print('PASS:', case, flush=True)
        finally:
            ctl('stop', main, guard, check=False)
            ctl('reset-failed', main, guard, check=False)
            for p in files: p.unlink(missing_ok=True)
            ctl('daemon-reload')
