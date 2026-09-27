"""Exercise production guard/installer copies with isolated files and commands.

No host systemctl, privileged write, or sleep operation is reachable: all fixed
system paths and PATH are replaced in the copies, never via production overrides.
"""
import os
from pathlib import Path
import subprocess
import tempfile

REPO = Path(__file__).resolve().parents[1]
SOURCE = REPO / "hardware/iptsd"


def fixture(base):
    root = Path(base)
    for name in ("bin", "src", "run/hibermachy-iptsd", "run/systemd/system", "etc/systemd/system", "usr/lib/systemd/system", "usr/local/libexec"):
        (root / name).mkdir(parents=True, exist_ok=True)
    (root / "run/hibermachy-iptsd").chmod(0o700)
    (root / "usr/lib/systemd/system/iptsd@.service").touch()
    # Mock tools preserve the real shell flow, return codes and file operations.
    commands = {
        "systemctl": '''#!/bin/bash
printf '%s\\n' "$*" >> "$TEST_ROOT/calls"
case $1 in
 show)
   if [[ $2 == --property=UnitPath ]]; then
     printf '%s\\n' "$TEST_ROOT/etc/systemd/system $TEST_ROOT/run/systemd/system $TEST_ROOT/run/systemd/transient $TEST_ROOT/usr/local/lib/systemd/system $TEST_ROOT/usr/lib/systemd/system"
   else cat "$TEST_ROOT/service-state"; fi;;
 stop) [[ ! -e $TEST_ROOT/stop-fails ]];;
 daemon-reload) exit 0;;
 *) echo "Unexpected systemctl: $*" >&2; exit 99;;
esac
''',
        "pgrep": '#!/bin/bash\n[[ -e $TEST_ROOT/process-remains || -e $TEST_ROOT/daemon-running ]]\n',
        "iptsd-systemd": '#!/bin/bash\necho restart >> "$TEST_ROOT/calls"\n[[ -e $TEST_ROOT/restart-fails ]] && exit 1\n[[ -e $TEST_ROOT/restart-no-device ]] || touch "$TEST_ROOT/daemon-running"\nexit 0\n',
        "timeout": '#!/bin/bash\n[[ $1 == --kill-after=* ]] && shift\nshift\nexec "$@"\n',
        "install": '#!/bin/bash\nargs=(); while (( $# )); do case $1 in -o|-g) shift 2;; *) args+=("$1"); shift;; esac; done\nexec /usr/bin/install "${args[@]}"\n',
    }
    for name, code in commands.items():
        p = root / "bin" / name
        p.write_text(code)
        p.chmod(0o755)
    (root / "service-state").write_text("inactive\n")
    for name in ("manage", "hibermachy-iptsd-guard"):
        code = (SOURCE / name).read_text()
        code = code.replace("PATH=/usr/bin:/bin", f"PATH={root}/bin:/usr/bin:/bin")
        code = code.replace('[[ $EUID -eq 0 ]]', 'true')
        code = code.replace('== 0:700', f'== {os.getuid()}:700')
        code = code.replace('== 0:1', f'== {os.getuid()}:1')
        code = code.replace('== 0 ]]', f'== {os.getuid()} ]]')
        for path in ("/run/", "/etc/", "/usr/local/", "/usr/lib/"):
            code = code.replace(path, str(root) + path)
        # Test files live below /tmp, so validate only fixture ancestors.
        code = code.replace('[[ $parent != / ]]', f'[[ $parent != {root} ]]')
        p = root / "src" / name
        p.write_text(code)
        p.chmod(0o755)
    (root / "src/90-hibermachy-iptsd.conf").write_text((SOURCE / "90-hibermachy-iptsd.conf").read_text())
    return root


def run(root, tool, action, expected=0):
    result = subprocess.run([str(root / "src" / tool), action], env=dict(os.environ, TEST_ROOT=str(root)), capture_output=True, text=True, timeout=5)
    assert result.returncode == expected, (tool, action, result.returncode, result.stdout, result.stderr)
    return result.stdout + result.stderr


for case in ("completed", "early-wake", "sleep-failure", "stop-failure", "process-remains", "existing-mask", "instance-override", "vendor-instance", "transient-instance", "replaced-mask", "restart-failure", "restart-no-device", "no-hold"):
    with tempfile.TemporaryDirectory() as base:
        root = fixture(base)
        mask = root / "run/systemd/system/iptsd@.service"
        marker = root / "run/hibermachy-iptsd/mask-owned"
        if case == "existing-mask": mask.symlink_to('/dev/null')
        if case == "instance-override": (root / "etc/systemd/system/iptsd@dev-hidraw0.service").write_text('administrator override')
        if case in ('vendor-instance', 'transient-instance'):
            parent = root / ('usr/local/lib/systemd/system' if case == 'vendor-instance' else 'run/systemd/transient')
            parent.mkdir(parents=True, exist_ok=True)
            (parent / 'iptsd@dev-hidraw0.service').write_text('instance bypass')
        if case == "stop-failure": (root / "stop-fails").touch()
        if case == "process-remains": (root / "process-remains").touch()
        if case != "no-hold":
            run(root, 'hibermachy-iptsd-guard', 'hold', 1 if case in ('existing-mask', 'instance-override', 'vendor-instance', 'transient-instance', 'stop-failure', 'process-remains') else 0)
        if case in ('existing-mask', 'instance-override', 'vendor-instance', 'transient-instance'):
            run(root, 'hibermachy-iptsd-guard', 'restore')
            assert mask.is_symlink() == (case == 'existing-mask')
            assert not marker.exists()
        elif case == 'replaced-mask':
            # Keep the original inode allocated to make this deterministic.
            mask.rename(root / 'original-mask')
            mask.symlink_to('/dev/null')
            run(root, 'hibermachy-iptsd-guard', 'restore', 1)
            assert mask.is_symlink()
        else:
            if case == 'restart-failure': (root / 'restart-fails').touch()
            if case == 'restart-no-device': (root / 'restart-no-device').touch()
            run(root, 'hibermachy-iptsd-guard', 'restore', 1 if case in ('restart-failure', 'restart-no-device') else 0)
            assert not mask.is_symlink()
            assert not marker.exists()
            if case != 'no-hold': assert 'restart' in (root / 'calls').read_text()
            # ExecStopPost may be invoked after a failed/no-op preparation.
            run(root, 'hibermachy-iptsd-guard', 'restore')
        print('PASS guard:', case)

for case in ('install-remove', 'collision', 'busy', 'symlink', 'modified-removal'):
    with tempfile.TemporaryDirectory() as base:
        root = fixture(base)
        guard = root / 'usr/local/libexec/hibermachy-iptsd-guard'
        dropin = root / 'etc/systemd/system/systemd-suspend-then-hibernate.service.d/90-hibermachy-iptsd.conf'
        if case == 'collision': guard.write_text('administrator file')
        if case == 'symlink': guard.symlink_to(root / 'administrator-file')
        if case == 'busy': (root / 'service-state').write_text('activating\n')
        if case in ('collision', 'symlink', 'busy'):
            run(root, 'manage', 'install', 1)
            assert not dropin.exists()
        else:
            run(root, 'manage', 'install')
            run(root, 'manage', 'install')
            assert 'installed (matches' in run(root, 'manage', 'status')
            assert guard.stat().st_mode & 0o777 == 0o755
            assert dropin.stat().st_mode & 0o777 == 0o644
            if case == 'modified-removal':
                guard.write_text('modified by administrator')
                run(root, 'manage', 'remove', 1)
                assert dropin.exists() and guard.read_text() == 'modified by administrator'
            else:
                run(root, 'manage', 'remove')
                run(root, 'manage', 'remove')
                assert not guard.exists() and not dropin.exists()
        print('PASS manage:', case)

# These are the systemd semantics relied upon: pre runs before the entire main
# operation; stop-post runs even when pre/main fail. No per-resume post hook.
unit = (SOURCE / '90-hibermachy-iptsd.conf').read_text()
assert 'ExecStartPre=/usr/local/libexec/hibermachy-iptsd-guard hold' in unit
assert 'ExecStopPost=/usr/local/libexec/hibermachy-iptsd-guard restore' in unit
assert 'RuntimeDirectoryMode=0700' in unit
assert 'ExecStartPost=' not in unit
