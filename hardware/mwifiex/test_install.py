#!/usr/bin/env python3
"""Run the installer with isolated destinations; never invoke host systemctl."""
import os
from pathlib import Path
import subprocess
import tempfile

source = Path(__file__).resolve().parent
legacy = (source.parents[1]/'tests/fixtures/mwifiex/per-step-hook').read_bytes()


def run(root, action, ok=True):
    result = subprocess.run([str(root/'src/manage'), action], env=dict(os.environ, CASE_ROOT=str(root)),
                            capture_output=True, text=True, timeout=5)
    assert (result.returncode == 0) == ok, (action, result.stdout, result.stderr)
    return result


for case in ('fresh', 'legacy', 'modified', 'busy', 'pending', 'symlink', 'modified-dropin', 'modified-backup', 'guard-busy', 'modified-unit'):
    with tempfile.TemporaryDirectory() as temp:
        root = Path(temp)
        (root/'src').mkdir(); (root/'bin').mkdir()
        hook = root/'usr/lib/systemd/system-sleep/mwifiex-hibernate'
        dropin = root/'etc/systemd/system/systemd-suspend-then-hibernate.service.d/91-hibermachy-mwifiex.conf'
        unit = root/'etc/systemd/system/hibermachy-mwifiex.service'
        backup = root/'var/lib/hibermachy/backups/mwifiex-hibernate.before-transaction-fix'
        for p in (hook, dropin, unit, backup, root/'run/placeholder'):
            p.parent.mkdir(parents=True, exist_ok=True)
        for name in ('sleep-hook', '91-hibermachy-mwifiex.conf', 'hibermachy-mwifiex.service'):
            (root/'src'/name).write_bytes((source/name).read_bytes())
        code = (source/'manage').read_text()
        code = code.replace('PATH=/usr/bin:/bin', f'PATH={root}/bin:/usr/bin:/bin')
        code = code.replace('[[ $EUID -eq 0 ]]', 'true').replace('== 0:1', f'== {os.getuid()}:1').replace('== 0 ]]', f'== {os.getuid()} ]]')
        for prefix in ('/usr/lib/', '/etc/', '/var/lib/', '/run/'):
            code = code.replace(prefix, str(root)+prefix)
        code = code.replace('[[ $parent != / ]]', f'[[ $parent != {root} ]]')
        (root/'src/manage').write_text(code); (root/'src/manage').chmod(0o755)
        commands = {
            'systemctl': '''#!/bin/bash
printf '%s\\n' "$*" >> "$CASE_ROOT/calls"
case $1 in
show) if [[ -f $CASE_ROOT/busy && $5 == systemd-suspend.service ]]; then echo active; elif [[ -f $CASE_ROOT/guard-busy && $5 == hibermachy-mwifiex.service ]]; then echo deactivating; else echo inactive; fi;;
daemon-reload) exit 0;;
*) exit 99;;
esac
''',
            'install': '''#!/bin/bash
args=(); while (( $# )); do case $1 in -o|-g) shift 2;; *) args+=("$1"); shift;; esac; done
exec /usr/bin/install "${args[@]}"
''',
        }
        for name, code in commands.items():
            (root/'bin'/name).write_text(code); (root/'bin'/name).chmod(0o755)
        if case == 'legacy': hook.write_bytes(legacy)
        if case == 'modified': hook.write_text('administrator hook')
        if case == 'symlink': hook.symlink_to(root/'unrelated')
        if case == 'guard-busy': (root/'guard-busy').touch()
        if case == 'modified-unit': unit.write_text('administrator guard')
        if case == 'busy': (root/'busy').touch()
        if case == 'pending': (root/'run/mwifiex-unloaded-for-hibernate').touch()
        if case == 'modified-dropin': dropin.write_text('administrator override')
        if case == 'modified-backup': backup.write_text('administrator backup')
        if case not in ('fresh', 'legacy'):
            before = {p: p.read_bytes() for p in (hook, dropin, unit, backup) if p.is_file()}
            run(root, 'install', ok=False)
            assert all(p.read_bytes() == data for p, data in before.items())
            assert 'daemon-reload' not in (root/'calls').read_text()
            continue
        run(root, 'install'); run(root, 'status'); run(root, 'install')
        assert unit.read_bytes() == (source/'hibermachy-mwifiex.service').read_bytes()
        assert hook.read_bytes() == (source/'sleep-hook').read_bytes()
        assert dropin.read_bytes() == (source/'91-hibermachy-mwifiex.conf').read_bytes()
        if case == 'legacy': assert backup.read_bytes() == legacy
        # Installation/rollback must never invoke sleep, modprobe or start a unit.
        assert all(line.startswith(('show ', 'daemon-reload')) for line in (root/'calls').read_text().splitlines())
        run(root, 'remove')
        assert not dropin.exists() and not unit.exists()
        if case == 'legacy': assert hook.read_bytes() == legacy
        else: assert not hook.exists()
print('PASS: fresh install, known legacy upgrade/rollback, rerun, busy services, pending recovery and conflicting files')
