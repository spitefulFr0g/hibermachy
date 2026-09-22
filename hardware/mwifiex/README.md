# Marvell Wi-Fi restoration after suspend and hibernation

This opt-in administrator workaround is for the Surface Pro 4's `mwifiex_pcie`
Wi-Fi driver. On the observed linux-surface 6.19.8 system, suspend/resume could
wedge firmware. An older hibernate-only hook then timed out unloading the
module, although removal completed. Because it recorded only successful
unloads, it never restored Wi-Fi. Reboot was required to bring the device back.

The hook records restoration responsibility **before** unloading and covers both
suspend and hibernate steps, including the fallback suspend after failed hibernation. On resume it reloads the
module with up to three attempts. A failed reload keeps the recovery marker for
another attempt. A module absent before preparation is left alone unless an
outstanding restoration record exists. NetworkManager handles reconnection;
the hook does not toggle the radio, modify profiles, or restart NetworkManager.
The timeout commands include a kill grace period; kernel operations stuck in
uninterruptible sleep can still outlast userspace timeout bounds.

## Installation and rollback

Install while awake with no sleep transaction running. This replaces the older
local hook at the same path; do not install a second copy alongside it. Save the
old file first if present:

```sh
sudo install -d -m 700 /var/lib/hibermachy/backups
sudo cp -p /usr/lib/systemd/system-sleep/mwifiex-hibernate /var/lib/hibermachy/backups/mwifiex-hibernate.before-recovery-fix
sudo install -o root -g root -m 755 hardware/mwifiex/sleep-hook /usr/lib/systemd/system-sleep/mwifiex-hibernate
```

For a first installation, omit the backup command when no old hook exists.
Systemd invokes this root-owned copy; it never executes the user checkout.
Installation does not unload the driver or initiate sleep. Roll back by copying
the saved hook to its original path while awake, or remove the installed hook
if it was a first installation. Retain an outstanding recovery marker until the
module has been restored.

Failures and successful restoration appear under:

```sh
journalctl -t mwifiex-hibernate
```

If automatic restoration exhausted its retries, an administrator can retry the
same bounded recovery path while awake:

```sh
sudo env SYSTEMD_SLEEP_ACTION=hibernate /usr/lib/systemd/system-sleep/mwifiex-hibernate post suspend-then-hibernate
```

This acts only when `/run/mwifiex-unloaded-for-hibernate` exists. Successful
module loading is not proof that a Wi-Fi connection is usable; verify the device
and connection after an attended suspend and hibernation test.

## Regression verification

`python3 hardware/mwifiex/test.py` runs the production hook against disposable
module state and command adapters. It covers timeout with completed removal,
ordinary suspend and hibernate, absent modules, reload retries and failures,
and preservation of recovery state. No real driver or sleep action is invoked.
These checks do not replace hardware validation after installation.


An attended Surface Pro 4 test on 2026-09-21 confirmed suspend at 21:21:18,
hibernation at 21:36:18, and resume at 21:43:22 (America/Denver). The installed
hook matched this source, logged driver restoration after both steps, and
NetworkManager reconnected at 21:43:31 without a radio toggle. This records one
successful hardware cycle; it does not complete the separate release gate.
