# Marvell Wi-Fi restoration across staged sleep

This opt-in administrator workaround is for the Surface Pro 4's `mwifiex_pcie`
Wi-Fi driver. On the observed linux-surface 6.19.8 system, suspend/resume can
wedge firmware. A timeout can remove the module despite reporting failure, so
restoration responsibility is recorded **before** attempting removal.

For staged sleep, a service drop-in requires a companion Wi-Fi guard. Its
`ExecStart` unloads Wi-Fi, which stays unloaded through every timer wake and
hibernation fallback. Once staged sleep ends, `StopWhenUnneeded` stops the guard
and its `ExecStopPost` restores Wi-Fi. Cleanup also runs on early wake and failed preparation. A failed
preparation prevents `systemd-sleep` from starting. The separate unit ensures a
failing IPTS cleanup cannot skip Wi-Fi cleanup. Recovery gets a 120-second
timeout, covering the bounded retries even on hosts with a short stop timeout. Ordinary suspend and direct
hibernation continue to use per-step system-sleep hooks. Installing all three files
is required for the transaction behavior; the hook alone retains the old
per-step behavior.

The previous per-step workaround reloaded the driver at the timer wake and
immediately unloaded it again for hibernation. On 2026-09-22 that sequence
preceded a kernel fault in `mwifiex_pcie_work`; blocked kernel tasks prevented
hibernation and fallback suspend. See [the incident record](../../verification/2026-09-22-staged-sleep-failure.md).
This change avoids that intermediate reload/unload; it does **not** fix the
underlying kernel fault or prove hardware reliability.

Restoration makes up to three attempts and retains recovery records on failure.
A previously absent module stays absent unless an outstanding restoration record
exists. NetworkManager handles reconnection; this workaround does not toggle
the radio, modify profiles, restart NetworkManager, change lid policy, or change
hibernate delay. Kernel operations stuck in uninterruptible sleep can outlast
userspace timeout bounds. Module presence does not prove working firmware or a
usable connection.

## Installation and rollback

Install while awake with no sleep transaction running:

```sh
sudo hardware/mwifiex/manage install
hardware/mwifiex/manage status
systemctl cat systemd-suspend-then-hibernate.service
```

The installer copies reviewed code into root-owned paths:

- `/etc/systemd/system/hibermachy-mwifiex.service`
- `/usr/lib/systemd/system-sleep/mwifiex-hibernate`
- `/etc/systemd/system/systemd-suspend-then-hibernate.service.d/91-hibermachy-mwifiex.conf`

It accepts a fresh installation, identical installed files, or the exact previous
hook from issue #32. The previous hook is saved at
`/var/lib/hibermachy/backups/mwifiex-hibernate.before-transaction-fix`.
Unrecognized files, symlinks, active sleep services, and outstanding recovery
records cause refusal. Installation reloads systemd but does not manipulate
Wi-Fi or initiate sleep. It is independent of plugin/helper lifecycle operations.

To roll back from the same checkout while awake:

```sh
sudo hardware/mwifiex/manage remove
```

This removes the guard unit and drop-in and restores the saved per-step hook if present;
otherwise it removes the hook. The saved hook retains the previous limitations.
Modified files require administrator inspection.

## Recovery and verification

Inspect results with `journalctl -t mwifiex-hibernate` and
`journalctl -u systemd-suspend-then-hibernate.service -u hibermachy-mwifiex.service`.
Wi-Fi recovery failure is reported by the companion unit; a successful staged-sleep
service result does not certify Wi-Fi recovery. If cleanup failed, an
administrator can retry while awake and after both the staged-sleep service and Wi-Fi guard have stopped:

```sh
sudo /usr/lib/systemd/system-sleep/mwifiex-hibernate restore
```

For an outstanding ordinary suspend/direct hibernate recovery record, use:

```sh
sudo env SYSTEMD_SLEEP_ACTION=hibernate /usr/lib/systemd/system-sleep/mwifiex-hibernate post hibernate
```

These commands act only on outstanding restoration records. If the kernel is
already wedged, userspace retry may not recover it. Runtime records clear on a
cold reboot; preserve journal evidence first.

`npm run test:mwifiex-workaround` drives the production hook and service callbacks
against disposable module state, and the installer against isolated system
paths. It covers timer wake, early wake, fallback, failed preparation, absent
driver, bounded retries, retained recovery state, installation and rollback.
No actual device or sleep action is invoked.

With a running user systemd manager, `python3 hardware/mwifiex/test_systemd.py`
also verifies the actual unit lifecycle using disposable user services and harmless
callback fixtures, including failure of the preceding touch cleanup. It removes
its temporary units on completion and never invokes actual sleep or drivers.

An attended hardware cycle is still required: verify Wi-Fi restoration after
early wake, actual hibernation/power-off, same-session resume, and a usable
connection. The earlier per-step hook completed one attended cycle on
2026-09-21; that does not validate this revision or complete the release gate.
