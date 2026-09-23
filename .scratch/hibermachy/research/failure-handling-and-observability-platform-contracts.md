# Failure handling and observability platform contracts

Research date: 2026-08-30  
Installed baseline: Omarchy `4.0.1-1` (Quattro), Quickshell `0.3.1-1`,
systemd `261.2-1`, Polkit `127-3`

## Question

What factual platform contracts constrain how Hibermachy detects, reports,
recovers from, and makes diagnosable failures in idle monitoring, the existing
Omarchy pre-suspend lock, authorization, user/system policy writes, suspend,
RTC wake, hibernation, resume, and Quattro plugin reload?

## Short answer

No single return code describes a staged-sleep outcome. The platform exposes a
sequence of separately observable facts: the idle monitor is usable; a request
was admitted; authorization completed; the sleep job started; the kernel
entered a sleep state; the machine returned; and, for staged sleep, hibernation
either happened, was abandoned after manual wake, or failed and systemd fell
back to another suspend. Hibermachy must not collapse those phases into a
single `success` boolean.

Three failure seams cannot be repaired from inside Hibermachy's in-shell
service:

1. Quickshell's idle monitor reports `false` and logs a warning when the
   compositor lacks the required protocol; it has no error property.
2. Omarchy's delay inhibitor cannot cancel sleep if its secure-lock handshake
   misses the deadline; logind proceeds and Omarchy reports the unsecured sleep
   only after resume.
3. Quattro's plugin reload destroys the old service before scanning and loading
   the replacement. A malformed manifest or QML load failure leaves no old
   Hibermachy instance to report the problem, and the rescan IPC has no result
   handshake.

systemd and the journal provide the durable evidence for sleep itself. In
particular, systemd 261's staged-sleep implementation logs structured sleep
start/stop events and, if the hibernate step fails, tries suspend again. If that
second suspend succeeds, the overall command may eventually return success;
the exit code alone therefore cannot prove that hibernation succeeded.

## 1. Idle monitoring

Quickshell `IdleMonitor` requires compositor support for
`ext-idle-notify-v1`. Its public state is only `enabled`, `timeout`,
`respectInhibitors`, and read-only `isIdle`. With `respectInhibitors: true`,
`isIdle` depends on both input activity and active Wayland idle inhibitors; it
does not identify which condition kept the session active. ([Quickshell
`IdleMonitor` source](https://git.outfoxxed.me/quickshell/quickshell/src/commit/49d4f46cf1b2d40e4095791d56e3b88eb8f0d0df/src/wayland/idle_notify/monitor.hpp))

When the compositor protocol is unavailable, Quickshell logs
`Cannot create idle monitor ...`, creates no notification object, and binds
`isIdle` to `false`. There is no separate QML error or readiness signal.
Consequently an unsupported/broken monitor is observationally identical to a
forever-active user unless Hibermachy has an explicit startup/readiness probe
or treats failure evidence from the host log as disarming. ([Quickshell
implementation](https://git.outfoxxed.me/quickshell/quickshell/src/commit/08c7fc2472dab5277f1a0e6ebb87c83fef2978c7/src/wayland/idle_notify/monitor.cpp))

Quattro's own idle service also uses `IdleMonitor` with
`respectInhibitors: true`. Its diagnostics model is useful precedent: it logs
timestamped transitions and process exits and exposes current monitor, timer,
child-process, and last-event state through an IPC status snapshot. It does not
expose a monitor-error field. [Installed idle service, lines
34-56, 147-207, and 250-295](</usr/share/omarchy/shell/plugins/services/idle/Service.qml>)

Implication: a Hibermachy status should distinguish at least `initializing`,
`ready-active`, `ready-idle`, `suppressed`, and `unavailable/unknown`. A mere
`isIdle=false` cannot justify claiming the monitor is healthy or explaining
whether a Wayland inhibitor is active.

## 2. Locking and logind inhibitors

logind's `sleep` delay inhibitor is finite. On `PrepareForSleep(true)`, the
holder gets a short opportunity to finish and close its inhibitor file
descriptor; when `InhibitDelayMaxSec=` expires, logind ignores the inhibitor and
continues. `PrepareForSleep(false)` is sent after the system returns. The
`PreparingForSleep` property brackets the same interval but deliberately does
not identify the requester or sleep operation. ([systemd inhibitor-lock
contract](https://systemd.io/INHIBITOR_LOCKS/), [systemd 261 logind D-Bus
contract](https://github.com/systemd/systemd/blob/v261/man/org.freedesktop.login1.xml#L533-L555))

Omarchy implements this exact pattern in the user unit
`omarchy-sleep-lock.service`: a `Restart=always` monitor holds a delay
inhibitor, consumes one `PrepareForSleep(true)`, runs the lock handshake, and
then exits so logind may proceed. [Installed monitor](</usr/share/omarchy/bin/omarchy-system-sleep-monitor>)
[installed user unit](</usr/lib/systemd/user/omarchy-sleep-lock.service>)

The lock request's command exit is not proof of a secure lock.
`omarchy-system-lock` discards the shell's IPC reply and continues through
best-effort cleanup, while the native lock service distinguishes requested,
session-locked, and compositor-confirmed `secure` states. Quickshell defines
`secure` as confirmation that every screen is covered. If a session-lock client
dies while locked, a conforming compositor remains locked behind a solid
failsafe rather than exposing the session. ([Quickshell
`WlSessionLock`](https://quickshell.org/docs/v0.2.1/types/Quickshell.Wayland/WlSessionLock/))
[installed Omarchy lock IPC, lines 510-541](</usr/share/omarchy/shell/plugins/lock/Service.qml>)
[installed lock command](</usr/share/omarchy/bin/omarchy-system-lock>)

Omarchy's pre-suspend helper therefore polls until the lock status reports
`.secure == true`, under a budget derived from logind's live
`InhibitDelayMaxUSec`. If it cannot confirm security, it writes an error,
queues a critical post-resume notification, and exits nonzero; its own source
explicitly notes that logind suspends anyway. [Installed secure-lock handshake,
lines 7-40, 67-124](</usr/share/omarchy/bin/omarchy-system-sleep-lock>)

Because the monitor intentionally exits after every sleep and is configured
with `Restart=always`, its systemd restart counter rises during normal
operation. `NRestarts` is not a failure count for this unit. The useful facts
are current `ActiveState`/`SubState`, whether the delay inhibitor is listed,
the most recent invocation/exit result, and its journal entries.

Implication: Hibermachy can observe whether Omarchy's lock monitor and inhibitor
are present before an automatic request, but it cannot turn Omarchy's delay
lock into a veto or reliably learn the final secure-lock result through its own
sleep-command exit. A failure policy must explicitly decide whether absence of
that monitor disarms automatic requests, and must never label “sleep request
accepted” as “screen locked.”

## 3. Authorization and policy-write commits

`pkexec` passes through the helper's exit status after it launches the helper.
It returns `126` when the user dismisses authentication and `127` when
authorization cannot be obtained or another authorization/execution error
occurs. The session Polkit agent used by Omarchy separately observes failed,
succeeded, and cancelled authentication flows, but a Hibermachy caller sees the
`pkexec` process result. ([official `pkexec(1)`, Return Value](https://polkit.pages.freedesktop.org/polkit/pkexec.1.html))
[installed Omarchy Polkit flow, lines 176-218](</usr/share/omarchy/shell/plugins/polkit/PolkitAgent.qml>)

Because successful `pkexec` returns the program's status unchanged, a helper
that itself uses `126` or `127` makes cancellation/authorization failure
ambiguous. Hibermachy's helper result vocabulary must reserve those two values,
or return an additional machine-readable result that lets the caller preserve
the already-decided cancellation distinction.

The two already-decided persistence domains expose different commit points:

- Quickshell `FileView` uses atomic replacement by default and emits `saved()`
  or `saveFailed()`. The service must not advance its durable revision before
  `saved()`. ([Quickshell 0.3.1
  `FileView`](https://quickshell.org/docs/v0.3.1/types/Quickshell.Io/FileView/))
- Linux `rename(2)` atomically replaces a destination name, but does not detect
  a stale read-modify-write; one-writer/revision checks remain necessary.
  ([Linux `rename(2)`](https://man7.org/linux/man-pages/man2/rename.2.html))
- systemd reads `sleep.conf` and its drop-ins when each `systemd-sleep` process
  starts, so a successful helper replacement needs no daemon reload and cannot
  change an already-running staged-sleep cycle. ([systemd 261 sleep parse
  path](https://github.com/systemd/systemd/blob/v261/src/sleep/sleep.c#L673-L687))
- `systemd-analyze cat-config --tldr systemd/sleep.conf` displays the ordered
  sources used for precedence. A successful owned-file write is therefore
  distinct from a verified effective-policy match. ([systemd 261
  `cat-config`](https://github.com/systemd/systemd/blob/v261/man/systemd-analyze.xml#L629-L650))

Implication: cancellation is terminal and non-error user intent, not something
to retry automatically. Each mutation needs a phase-specific result:
validation, authorization cancellation/denial, helper execution, owned-file
commit, and effective-policy reconciliation. A later readback mismatch must
not retroactively claim that the owned-file write failed.

## 4. Suspend request, entry, return, and service failure

logind's capability calls and sleep methods enforce Polkit and inhibitors.
Capability results include `yes`, `challenge`, `no`, `na`, `inhibited`,
`inhibitor-blocked`, and `challenge-inhibitor-blocked`; held inhibitors are a
transient refusal, not hardware failure. `PrepareForSleep(true/false)` brackets
the transaction, but does not establish why the machine returned or whether a
staged hibernate phase succeeded. ([systemd 261 logind D-Bus
contract](https://github.com/systemd/systemd/blob/v261/man/org.freedesktop.login1.xml#L657-L676))

The actual sleep targets require the corresponding one-shot
`systemd-suspend.service`, `systemd-hibernate.service`, or
`systemd-suspend-then-hibernate.service`. systemd service objects retain
diagnostic properties including `Result`, `ExecMainCode`, `ExecMainStatus`,
`InvocationID`, and restart count. Result values distinguish such causes as
`exit-code`, `signal`, `core-dump`, `timeout`, `watchdog`, and `start-limit`.
([systemd D-Bus service properties](https://www.freedesktop.org/wiki/Software/systemd/dbus/))

For a separately supervised long-running process, `Restart=on-failure` is
systemd's recommended policy; restarts are subject to
`StartLimitIntervalSec=`/`StartLimitBurst=`. `WatchdogSec=` marks a missed
`WATCHDOG=1` deadline failed and can combine with restart. These mechanisms
apply only at a systemd unit seam. Hibermachy's selected runtime is an object
inside `omarchy-shell`, so it has no independent unit, restart counter, or
watchdog; an in-process heartbeat also cannot diagnose a hung host event loop.
([systemd 261 `Restart=` and
`WatchdogSec=`](https://github.com/systemd/systemd/blob/v261/man/systemd.service.xml))

The journal supplies stable correlation fields. Service output is tagged with
the unit and invocation; well-known fields include `MESSAGE_ID`, `PRIORITY`,
`ERRNO`, source location, `_SYSTEMD_UNIT`/`_SYSTEMD_USER_UNIT`, and
`_SYSTEMD_INVOCATION_ID`. ([systemd journal fields](https://www.freedesktop.org/software/systemd/man/latest/systemd.journal-fields.html))
systemd's sleep implementation emits structured start/stop messages with a
sleep-operation field, including an error message when writing
`/sys/power/state` fails. ([systemd 261 sleep implementation](https://github.com/systemd/systemd/blob/v261/src/sleep/sleep.c#L192-L310))

Implication: record a request/correlation id, wall and monotonic timestamps,
boot id, chosen action, and the coordinator phase before invoking sleep. After
return, reconcile the process result, `PrepareForSleep` observations, relevant
unit result/invocation, and journal evidence. “Accepted,” “entered sleep,”
“returned,” and “final outcome known” are different states. If evidence is
missing or contradictory, the honest result is `unknown`, not success and not
an automatic retry.

## 5. RTC wake, hibernation, and resume

The kernel's direct `/sys/class/rtc/rtcX/wakealarm` interface is a one-shot
alarm. The attribute exists only when the RTC has alarm support and its parent
can wake the system. A future absolute epoch or relative `+seconds` value arms
it; a past value disables it. The kernel rejects a new alarm with `EBUSY` if an
alarm is already enabled, propagates RTC read/set failures, and reading the
file returns the enabled alarm or empty output when disabled. ([Linux RTC ABI](https://www.kernel.org/doc/Documentation/ABI/testing/sysfs-class-rtc),
[kernel `wakealarm` implementation](https://github.com/torvalds/linux/blob/master/drivers/rtc/sysfs.c))

Hibermachy should not touch that interface. systemd 261 checks wake-alarm
support as part of `CanSuspendThenHibernate()` and owns staged wake with a
`CLOCK_BOOTTIME_ALARM` timerfd. Failures to create, arm, or poll that timer
propagate from `systemd-sleep` and are journaled. A manual/non-timer wake ends
the staged cycle without hibernating. ([systemd 261 staged-sleep support
checks](https://github.com/systemd/systemd/blob/v261/src/shared/sleep-config.c#L250-L388),
[staged-sleep loop](https://github.com/systemd/systemd/blob/v261/src/sleep/sleep.c#L359-L552))

If the staged hibernate step fails, systemd 261 logs the failure and tries
suspend again with `SYSTEMD_SLEEP_ACTION=suspend-after-failed-hibernate`.
Therefore a later successful return from the command does not prove that the
machine ever hibernated. ([systemd 261 fallback path](https://github.com/systemd/systemd/blob/v261/src/sleep/sleep.c#L539-L552),
[official sleep-hook action contract](https://www.freedesktop.org/software/systemd/man/latest/systemd-suspend.service.html))

A successful hibernation restore continues the suspended kernel and journal
boot identity. If the resume device/image is unavailable, the kernel can fail
the resume attempt and continue an ordinary boot instead; evidence then spans
the previous and current boot. The kernel documents the resume device/image
signature checks and provides PM debugging knobs, but those knobs are
diagnostic tools, not safe automatic recovery behavior. ([Linux swap-suspend
resume contract](https://docs.kernel.org/power/swsusp.html), [kernel suspend and
hibernate debugging](https://docs.kernel.org/6.14/power/basic-pm-debugging.html))

Implication: RTC evidence belongs to systemd/kernel diagnostics, not a second
Hibermachy timer or wakealarm write. Preserve the re-arm latch across any
entered/unknown sleep, do not automatically issue another sleep after return,
and require fresh activity as already decided. A bounded outcome history should
be able to say `manual wake before hibernate`, `hibernate failed; systemd
re-suspended`, `hibernate restored`, `ordinary boot after possible failed
restore`, or `unknown`, rather than only `success/failure`.

## 6. Quattro plugin reload and shell failure

A write under `~/.config/omarchy/plugins/` triggers a global plugin reload.
Quattro first destroys all panels, plugin services, and plugin widgets, clears
the QML component cache, then rescans and recreates enabled objects. The old
Hibermachy service is gone before the new source is validated or instantiated.
[Installed reload path, lines 739-778](</usr/share/omarchy/shell/shell.qml>)

During rescan, an invalid/malformed manifest is warned and omitted from the new
registry. A service QML compile or object-creation failure is only logged with
`console.warn`; the loader leaves no service object and exposes no load-failure
status for services. The public `rescanPlugins()` IPC method returns no result,
so successful IPC transport means only that a reload was requested. [Installed
registry scan, lines 545-615](</usr/share/omarchy/shell/services/PluginRegistry.qml>)
[installed service loader, lines 285-320 and rescan IPC, lines
890-892](</usr/share/omarchy/shell/shell.qml>)

Widget loads have a `pluginLoadFailed` signal and may retry on a later rescan;
service loads do not. The filesystem watcher restarts one second after it exits,
but likewise emits no health result. [Installed widget/retry path, lines
788-811](</usr/share/omarchy/shell/shell.qml>) [watcher, lines
636-659](</usr/share/omarchy/shell/services/PluginRegistry.qml>)

Omarchy's explicit full-shell restart command demonstrates the stronger
available pattern: restart, poll shell readiness, and when recovering a
compositor lock, poll until `.secure == true`; it reports failure if readiness
does not arrive. [Installed restart implementation](</usr/share/omarchy/bin/omarchy-restart-shell>)

Implication: service recreation must start disarmed, rebuild from durable intent
and fresh observations, and expose a readiness/status probe. An external
lifecycle operation can poll that probe and report reload failure; the vanished
old service cannot. Menu self-hiding handles absence, but diagnosing a host
crash/hang or failed replacement requires an external observer (lifecycle
status, shell IPC, or system journal). Adding an independent watchdog daemon
would be a new runtime seam beyond the selected architecture, not a free
property of the plugin.

## 7. Diagnostic evidence available on the installed baseline

These read-only commands expose the relevant primary evidence without adding a
new daemon:

```bash
# Hibermachy's host/service readiness and Omarchy's lock owner
omarchy-shell shell ping
omarchy-shell lock status
systemctl --user show omarchy-sleep-lock.service \
  -p ActiveState -p SubState -p Result -p ExecMainStatus -p InvocationID -p NRestarts
systemd-inhibit --list

# Sleep units and system/kernel history
systemctl show systemd-suspend-then-hibernate.service \
  -p ActiveState -p SubState -p Result -p ExecMainStatus -p InvocationID
journalctl -b \
  -u systemd-suspend-then-hibernate.service \
  -u systemd-hibernate.service -u systemd-suspend.service
journalctl --user -b -u omarchy-sleep-lock.service
journalctl -b -k -g 'PM:|hibernate|resume'
journalctl --list-boots

# Requested/effective policy provenance
systemd-analyze cat-config --tldr systemd/sleep.conf
```

On this installed machine, the unprivileged desktop user can read both the
sleep-unit and kernel journal records. That access should still be treated as a
capability and reported if unavailable, rather than assumed on every target.

## Decision implications for the grilling frontier

1. Use one deep outcome model across idle, manual request, user-policy save,
   helper apply/reset, and post-resume reconciliation, but retain typed phases
   and causes. At minimum distinguish user cancellation, validation/conflict,
   unavailable capability, held inhibitor, authorization denial/error, IO or
   helper failure, lock unconfirmed, sleep refusal, sleep entered, manual wake,
   hibernate fallback, restore, reload disappearance, and unknown evidence.
2. Keep recovery bounded and phase-specific. Retry read-only probes; do not
   retry authentication cancellation, a stale write, or an entered/unknown
   sleep. Preserve validated intent and require explicit correction or fresh
   activity where prior decisions already demand it.
3. Treat Omarchy lock health as a preflight fact, not as a Hibermachy-owned
   action. The frontier must decide whether automatic requests fail closed when
   `omarchy-sleep-lock.service`/its inhibitor is absent. Manual behavior is a
   separate user-facing decision because the delay inhibitor itself cannot
   guarantee a lock.
4. Make current health and a small durable outcome history separate. Current
   live status is reconstructed; durable history records outcomes and
   correlation metadata but never restores busy/capability/sleep state.
5. Promise only failures observable from the selected in-shell architecture.
   A failed replacement, shell crash, or host hang needs an external probe or
   journal. If v1 must actively notify on those events, that requirement would
   introduce a new supervised module and should be decided explicitly rather
   than implied by an in-process heartbeat.
6. Provide a copyable diagnostic summary that reports versions, config
   validity/revisions, requested/effective policy and provenance, capability
   results, inhibitor/lock-monitor health, last outcome/correlation id, plugin
   readiness, and the exact journal commands/time window. Do not collect
   secrets, full arbitrary logs, or mutable recovery actions as part of a
   read-only diagnostic export.

## Prior project context consulted

- Resolutions for “Establish helper security and packaging constraints,”
  “Choose the plugin runtime architecture,” “Choose configuration and state
  ownership,” “Choose the installation and lifecycle model,” and “Choose
  configuration defaults and validation rules” in the local Markdown tracker
- [`Configuration and state ownership constraints`](../../../docs/research/configuration-and-state-ownership-constraints.md)
- [`Installation and lifecycle contracts for Hibermachy`](installation-and-lifecycle-contracts.md)
