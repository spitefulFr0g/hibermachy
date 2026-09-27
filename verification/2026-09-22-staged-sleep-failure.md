# Staged-sleep failure on 2026-09-22

Local journal evidence; timestamps are America/Denver. Previous boot:
`85d00eb9ffd34d108956927519f36f81`. Surface Pro 4, linux-surface
`6.19.8-arch1-3-surface`, systemd 261.2. Installed Wi-Fi hook matched the
repository's issue #32 version (SHA-256
`79a0d3b1f3f8c62717296b76f22a7e816040479c534468a71d8e145dd15778cd`).

## Observed sequence

- 00:03:58: logind accepted a staged-sleep request from a user-session `systemctl`.
  No lid-switch event was recorded for this request; the user's lid-close account
  cannot be independently tied to the request source from this journal.
- 00:04:00: IPTS guard reported the touch daemon stopped and blocked.
- 00:04:10: Wi-Fi unload returned failure/timeout despite module removal. The
  per-step hook logged retained restoration responsibility. Suspend proceeded.
- 01:04:00: the machine returned from suspend after the configured 3600-second
  hibernate delay. The post-suspend hook reloaded Wi-Fi.
- 01:04:10: firmware command `0xfa` timed out. Kernel fault: `BUG: unable to handle
  page fault for address: 0000000000001880`, workqueue `events mwifiex_pcie_work`,
  instruction `mwifiex_pcie_work+0x49/0x4b0`. Driver removal hung.
- 01:04:32: hibernation freezer failed after 20 seconds. `modprobe` was in state D,
  blocked at `mwifiex_pcie_remove`; `quickshell` was also in state D, blocked at
  `fsnotify_destroy_group` / `__flush_work` while closing an inotify descriptor.
- 01:04:36: hibernation returned `Device or resource busy`.
- 01:04:59: fallback suspend failed the same freezer checks. The service reported
  failure at 01:05:27 and could not kill the stuck modprobe.
- Logs continued until 08:39:09 with repeated service/connection timeouts and no
  later successful sleep recorded. The next boot began at 21:45:43. The operator
  reported an empty battery. The journal supports continued wakefulness but does
  not independently measure the final discharge or shutdown cause.

## Findings and limits

Confirmed kernel driver fault, plus two actionable workaround defects: driver
reload/unload between staged-sleep phases, and relying on a system-sleep hook
failure to stop entry into sleep. Systemd invokes those hooks per phase and
continues despite a failed hook. The command chronology is consistent with the
intermediate reload/unload triggering the fault, but is not a controlled kernel
reproduction. Quickshell's separate blocked stack is recorded without claiming
the driver crash necessarily caused it. The IPTS process was not among the
refusing tasks in this cycle.

The machine also has `DefaultTimeoutStopSec=5s`. The new Wi-Fi guard gives its
cleanup command 120 seconds, covering bounded retries instead of cutting them
short at five seconds. This does not bound an uninterruptible kernel task.

The repository fix requires a companion service that places unload in `ExecStart`
and restoration in `ExecStopPost`, skipping intermediate hooks while the
transaction owns Wi-Fi. `StopWhenUnneeded` ends the guard after staged sleep.
A shared list of cleanup callbacks was rejected after a real-systemd fixture
confirmed that failing IPTS cleanup skips subsequent Wi-Fi cleanup. The separate
unit preserves both cleanup attempts and their independent failure results.
The regression drives the real hook with disposable command adapters and catches
intermediate reload, failed preparation, early wake, hibernation fallback, and
restoration failures. The new transaction test failed before the implementation
and passed after it. Real kernel fault reproduction is deliberately excluded
from unattended tests; hardware verification remains outstanding.

No unrelated idle, policy, or outcome implementation was changed. Current
boot reconciliation recorded `HBR-SLEEP-BOOT-CHANGED` as Indeterminate, which does
not claim that the previous attempt completed.

## Evidence commands and platform references

```sh
journalctl -b -1 -u systemd-suspend-then-hibernate -u systemd-logind --no-pager
journalctl -b -1 -t mwifiex-hibernate --no-pager
journalctl -b -1 -k --since '2026-09-22 00:00:00' --until '2026-09-22 01:10:00' --no-pager
npm run test:mwifiex-workaround
```

The installed `systemd-suspend.service(8)` documents per-phase hooks and
`SYSTEMD_SLEEP_ACTION`. The installed `systemd.service(5)` documents preparation
failure and cleanup semantics. Upstream implementations:
[systemd sleep](https://github.com/systemd/systemd/blob/v261.2/src/sleep/sleep.c)
and [service execution](https://github.com/systemd/systemd/blob/v261.2/man/systemd.service.xml).

## Validation and installation

The isolated hook/installer regressions and a harmless real-systemd user-unit
integration check cover completion, early wake, failed preparation, failed sleep,
IPTS cleanup failure, and Wi-Fi cleanup failure. Independent review identified
the shared-cleanup interaction; the revised companion unit addresses it.
The ordinary Rust invocation requires the repository test-support feature;
`cargo test --locked --features test-support --test helper_merge_gate --test apply_process --test packaging_contract`
passed all 33 tests. Static checks passed; shellcheck is not installed.

Hardware validation remains outstanding. No real sleep or live driver action
was initiated during diagnosis or installation.

The final companion-service version was installed locally on 2026-09-22.
`hardware/mwifiex/manage status` confirmed matching source bytes, and
`systemd-analyze verify` accepted both units. The manager reported the required
ordering, independent Wi-Fi cleanup, a 120-second guard cleanup timeout, and both
services inactive. NetworkManager still reported Wi-Fi connected. The prior
issue #32 hook remains backed up for rollback.

Broader validation: all 17 Quattro matrix cases completed successfully across
the initial run and targeted continuations. One disabled-first discovery/startup
failure in the corrupt-history case did not reproduce on its traced rerun.
The non-Quattro groups passed except `tests/lifecycle_production.sh`, whose
fixture omitted `HIBERMACHY_LIFECYCLE_POLICY` and therefore observed this host's
real installed policy. It failed with `HBR-LIFECYCLE-PKEXEC-FAILED` through the
isolated command directory, without invoking the host helper. This separate
test-isolation defect is outside the Wi-Fi workaround and needs its own fix.
