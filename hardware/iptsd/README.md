# IPTS workaround for staged sleep

On a Surface Pro 4 running linux-surface 6.19.8 and iptsd 3.1.0, udev restarts
`iptsd` after suspend. If the timer immediately transitions into hibernation,
that new process can remain inside a touch-device restart ioctl and refuse the
kernel freezer. Hibernation aborts, and the fallback suspend may fail too.
[Upstream iptsd issue #190](https://github.com/linux-surface/iptsd/issues/190)
reports the same class of failure.

This opt-in administrator workaround stops `iptsd` before the **entire staged-sleep
transaction**, blocks udev from restarting it between suspend and hibernation,
and restores it when the transaction ends. It applies equally to idle, manual,
and lid requests that already select staged sleep. Touchscreen/stylus processing
is unavailable during the transaction. The Type Cover keyboard is separate.

The guard runs through `ExecStartPre` and `ExecStopPost` on
`systemd-suspend-then-hibernate.service`. The post action also runs after a failed
preparation or sleep operation. An early wake ends the transaction and restores
the daemon. The mask lives in `/run`, so a cold reboot clears it. Restoration
uses the packaged `iptsd-systemd` helper to discover the current hidraw device,
whose number may have changed across resume.

## Install and inspect

From the repository root, on an awake machine with `iptsd` installed:

```bash
sudo hardware/iptsd/manage install
hardware/iptsd/manage status
systemctl cat systemd-suspend-then-hibernate.service
```

Installation copies reviewed code to root-owned paths; systemd never executes
code from a user-writable checkout. It does not request sleep. Existing files
that differ from this checkout, symlinks, and an active staged-sleep transaction
cause installation/removal to refuse. During preparation, existing instance or
template overrides/masks are preserved and cause staged sleep to fail before
suspend, rather than risking a restart through a conflicting unit.

Installed files:

- `/usr/local/libexec/hibermachy-iptsd-guard`
- `/etc/systemd/system/systemd-suspend-then-hibernate.service.d/90-hibermachy-iptsd.conf`

These are an independently installed administrator workaround, outside the
plugin/helper lifecycle. Normal Hibermachy setup does not install them, and
Hibermachy uninstall does not remove them. This does not change ordinary suspend,
direct hibernation, lid action, hibernate delay, or the privileged policy helper.
The separate Wi-Fi and timer workarounds on the test machine remain necessary
parts of its test configuration; this change only addresses the iptsd failure.

## Verify on hardware

Use the existing attended test with the permanent guard installed:

```bash
staged-sleep-test --lid
```

Do **not** use `--without-iptsd` alongside the permanent guard: the diagnostic
mask deliberately conflicts with the guard's ownership check. Close the lid
only when prompted; leave it shut for at least three minutes for the one-minute
test, then open it and press power if needed. The wrapper is local diagnostic
tooling, not part of the distributed plugin.

Inspect the guard and daemon after returning:

```bash
journalctl -b -u systemd-suspend-then-hibernate.service --no-pager
systemctl --all list-units 'iptsd@*.service'
```

The journal should show the daemon blocked before suspend and restored after
the transaction. Successful systemd return alone does not prove physical
power-off. The permanent service integration still requires an attended cycle.

Evidence for the underlying workaround: on 2026-09-20, the 23:19 cycle failed
with `task:iptsd` refusing to freeze. The 23:37 isolation cycle, with the template
masked for the whole transaction, suspended for 60.14 seconds, entered
hibernation without a logged failure, and restored an active daemon afterward.
The operator reported success. The 900-second policy was restored. This single
cycle does not complete issue #26's hardware qualification gate.

## Remove or recover

Use the same checkout revision that installed the files:

```bash
sudo hardware/iptsd/manage remove
```

This removes only byte-identical files and reloads systemd. Re-running install
or remove is safe. To upgrade, remove using the old checkout, then install from
the reviewed new checkout. Modified files require administrator inspection.

If restoration fails, inspect the journal before retrying staged sleep. A
remaining `/run/systemd/system/iptsd@.service` mask may have been replaced by an
administrator, in which case the guard preserves it. A reboot clears the runtime
mask and normal udev startup can restore iptsd. If the guard reports that its mask
was removed but daemon startup failed, the device/driver needs investigation;
this is reported as a service failure rather than silently claiming recovery.
