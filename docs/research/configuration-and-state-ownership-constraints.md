# Configuration and state ownership constraints

Research date: 2026-08-28  
Target: Omarchy `4.0.1-1` (Quattro), Quickshell `0.3.1-1`, systemd `261.2-1`

## Question

What facts constrain ownership and reconciliation of Hibermachy's user settings,
system-wide sleep policy, live coordinator state, capability state, reloads, and
concurrent changes?

## Short answer

The stable ownership boundary is three-way:

1. Omarchy owns plugin activation in `~/.config/omarchy/shell.json`.
2. Hibermachy's service owns its user-scoped durable intent and is the only
   writer of that document; panels and IPC clients submit mutations to the
   service rather than writing independently.
3. systemd owns effective staged-sleep policy. Hibermachy's privileged helper
   owns only its dedicated drop-in, while the effective values are the result of
   all systemd configuration in precedence order.

Transient coordinator state is memory-only and is rebuilt after reload from
durable intent plus fresh logind/systemd observations. A small durable outcome
history may live in XDG state, but it must never masquerade as current system
state.

Two terminology corrections are important. The systemd 261 directive is
`HibernateOnACPower=`, **not** `AllowHibernationOnACPower=`. Also, an atomic file
replacement prevents a torn document but does not prevent two writers from
silently overwriting one another.

## 1. Omarchy configuration and reload behavior

### What `shell.json` owns

Quattro documents one authoritative shell configuration file. A non-bar plugin
is enabled by an entry in `plugins[]`; settings are inline on that entry, and a
valid user file replaces the defaults wholesale rather than being deep-merged.
The public shell IPC can reload the file and toggle plugin enablement, but it has
no generic service/panel settings mutation method. ([Omarchy 4.0.1 shell
contract](https://github.com/basecamp/omarchy/blob/v4.0.1/shell/README.md#persisted-state))

The v4.0.1 implementation exposes a seam gap behind that documentation. The
service loader injects `omarchyPath`, `shell`, `manifest`, and registries, while
the panel loader additionally injects the matching service; neither injects an
inline `settings` object. The host has internal `shellConfig` and
`updateEntryInline()` members, but those are absent from the public IPC/plugin
contract. `updateEntryInline()` also replaces the complete matching entry rather
than patching one key. ([service loader](https://github.com/basecamp/omarchy/blob/v4.0.1/shell/shell.qml#L263-L345),
[private inline updater](https://github.com/basecamp/omarchy/blob/v4.0.1/shell/shell.qml#L361-L405),
[public IPC methods](https://github.com/basecamp/omarchy/blob/v4.0.1/shell/README.md#ipc-contract))

Consequently, strict use of public 4.0.1 contracts means `shell.json` can safely
own Hibermachy's installed/enabled presence, but using it as the live policy
store would require either a private host dependency or an external
read-modify-write tool operating on a shared user file. A plugin-owned config is
the less coupled persistence seam, although this deliberately departs from
Quattro's stated “no separate per-plugin settings file” convention. That tradeoff
must be explicit in the specification rather than hidden as an implementation
detail.

`reloadConfig` does not recreate an already-enabled service. It changes the
host's `shellConfig`, emits registry change notifications, and `_syncServices()`
retains the existing instance. A service that snapshots its `plugins[]` entry at
construction would therefore remain stale after a shell-config reload unless it
couples to private host state/signals. ([config change handling](https://github.com/basecamp/omarchy/blob/v4.0.1/shell/shell.qml#L66-L70),
[service retention](https://github.com/basecamp/omarchy/blob/v4.0.1/shell/shell.qml#L323-L345),
[reloadConfig implementation](https://github.com/basecamp/omarchy/blob/v4.0.1/shell/shell.qml#L890-L897))

### Reload is object replacement

Saving plugin source or calling `rescanPlugins` triggers a global plugin reload.
The host unloads panels, services, and widgets, clears/rescans components, then
recreates enabled services. All Hibermachy QML object state therefore disappears
on reload. ([documented reload](https://github.com/basecamp/omarchy/blob/v4.0.1/shell/README.md#installing-a-third-party-plugin),
[reload implementation](https://github.com/basecamp/omarchy/blob/v4.0.1/shell/shell.qml#L734-L778))

Durable settings must be committed before the service reports success. On
recreation, the service must parse durable intent, reject invalid/newer schemas,
query fresh effective/capability state, and then re-arm its idle monitor. It must
not persist or restore a stale `busy`, inhibitor, countdown, power-source, or
“currently sleeping” flag. systemd owns any already-started suspended interval,
so destroying the Quickshell service cannot cancel or retime it.

## 2. User configuration and state files

The XDG Base Directory specification assigns user-specific configuration to
`$XDG_CONFIG_HOME` (default `~/.config`) and restart-persistent, non-portable
application state to `$XDG_STATE_HOME` (default `~/.local/state`). Runtime-only
coordination belongs under `$XDG_RUNTIME_DIR` or in process memory and does not
survive full logout/reboot. ([XDG Base Directory Specification
0.8](https://specifications.freedesktop.org/basedir/0.8/))

The resulting constraints are:

- A versioned Hibermachy config under `$XDG_CONFIG_HOME/hibermachy/` may own
  user intent such as automatic-policy enablement and idle delay. Invalid JSON,
  invalid ranges, or a newer schema must leave automatic requests disarmed; the
  runtime must not silently arm guessed defaults.
- Effective `HibernateDelaySec=` and `HibernateOnACPower=` must not have a
  second authoritative copy in the user config. Hibermachy's dedicated system
  drop-in records its requested system-wide values; the ordered systemd
  configuration records what is effective. A UI draft or “last requested” value
  is not effective state.
- Optional last-completed outcome/error history belongs under
  `$XDG_STATE_HOME/hibermachy/`. It is diagnostic history only and must carry a
  timestamp/schema. Current capabilities, inhibitors, external-power state, and
  sleep progress must always be re-observed.
- Uninstalling/disabling the plugin removes its runtime but does not imply that
  the separately owned system drop-in was reset. This is an intentional
  cross-scope mismatch the UI/lifecycle specification must disclose.

## 3. systemd 261 policy semantics

### Correct names and behavior

`HibernateDelaySec=` is the time spent suspended before the automatic
hibernation phase and applies only to suspend-then-hibernate.
`HibernateOnACPower=` applies only when a delay is configured and only on a
battery-equipped system. When it is `no`, the delay countdown begins after AC is
disconnected and the machine remains suspended while AC is connected. Its
default is `yes`. ([systemd 261 sleep configuration](https://github.com/systemd/systemd/blob/v261/man/systemd-sleep.conf.xml#L192-L216),
[v261 parser/defaults](https://github.com/systemd/systemd/blob/v261/src/shared/sleep-config.c#L98-L142))

There is no `AllowHibernationOnACPower=` setting in the v261 parser. A
specification, helper protocol, generated drop-in, or test using that spelling
would not control AC behavior. The helper's fixed output must use exactly
`HibernateOnACPower=yes|no`. ([accepted v261 keys](https://github.com/systemd/systemd/blob/v261/src/shared/sleep-config.c#L112-L135))

Manual wake ends the active staged-sleep cycle. In both the low-battery-alarm and
timer/estimation paths, systemd returns without hibernating when resume was not
caused by its hibernation trigger. It does not continue counting in userspace
after the user resumes the machine. ([v261 staged-sleep loop](https://github.com/systemd/systemd/blob/v261/src/sleep/sleep.c#L359-L552))

### Precedence and effective values

The main `sleep.conf` has lower precedence than drop-ins. Drop-ins from `/usr`,
`/usr/local`, `/run`, and `/etc` are sorted together lexicographically; for a
scalar directive, the last assignment wins. A same-named file in `/etc` masks a
lower-priority directory's file. systemd reserves `/etc` for local administrator
policy and recommends numbered names, with local files generally in the `60–90`
range. ([systemd 261 `systemd-sleep.conf(5)` source](https://github.com/systemd/systemd/blob/v261/man/systemd-sleep.conf.xml),
[standard configuration precedence](https://github.com/systemd/systemd/blob/v261/man/standard-conf.xml))

Therefore `/etc/systemd/sleep.conf.d/90-hibermachy.conf` is Hibermachy's requested
system policy, not proof of the effective policy. A later administrator entry
such as `99-local-sleep.conf` may override it. Read
`systemd-analyze cat-config --tldr systemd/sleep.conf` to show the ordered
sources, parse the last assignments to the two owned scalar keys, and surface
drift/provenance rather than repeatedly fighting an administrator override.
`cat-config` is explicitly the systemd tool for displaying a configuration file
and its drop-ins. ([systemd-analyze 261](https://github.com/systemd/systemd/blob/v261/man/systemd-analyze.xml#L629-L650))

### Reload boundary

No `daemon-reload` or logind restart is needed. Each newly started
`systemd-sleep` process calls `parse_sleep_config()` before dispatching the
operation, and that parser reads `systemd/sleep.conf` with drop-ins. The completed
atomic helper write therefore affects the next request. ([process-start parse](https://github.com/systemd/systemd/blob/v261/src/sleep/sleep.c#L673-L687),
[drop-in parser call](https://github.com/systemd/systemd/blob/v261/src/shared/sleep-config.c#L98-L142))

The converse is equally important: an active suspend-then-hibernate process has
already parsed its configuration and armed its timer. Config changes during that
interval do not alter that cycle. They apply after manual wake/return or on a
later request.

## 4. Authoritative live and capability state

The logind Manager's `CanSuspend()`, `CanHibernate()`, and
`CanSuspendThenHibernate()` methods test both platform support and the calling
user's authorization. In v261 their result set is `yes`, `challenge`, `no`,
`na`, `inhibited`, `inhibitor-blocked`, or
`challenge-inhibitor-blocked`; the inhibited variants describe transient held
inhibitors and must not be collapsed into permanent hardware unavailability.
([systemd 261 logind D-Bus contract](https://github.com/systemd/systemd/blob/v261/man/org.freedesktop.login1.xml#L657-L676))

Each capability call invokes systemd's sleep support checks afresh. Those checks
reparse sleep configuration and evaluate allowed operations, kernel states and
modes, the wake alarm, resume setup/device, and hibernation swap. Re-querying
capabilities after a helper apply/reset is sufficient; restarting logind is not.
([logind capability implementation](https://github.com/systemd/systemd/blob/v261/src/login/logind-dbus.c#L2546-L2667),
[sleep support checks](https://github.com/systemd/systemd/blob/v261/src/shared/sleep-config.c#L250-L388))

Useful read-only Manager state is deliberately narrower than Hibermachy's full
status model:

- `BlockInhibited`, `BlockWeakInhibited`, and `DelayInhibited` summarize active
  inhibitor classes; `ListInhibitors()` provides who/why/mode/UID/PID details.
- `OnExternalPower` reports current external power.
- `PrepareForSleep(true/false)` and `PreparingForSleep` bracket a logind sleep
  transaction.

These are live observations, not durable settings. `PreparingForSleep` does not
identify Hibermachy's request or expose the staged-sleep timer, and logind exposes
no documented property for the effective `HibernateDelaySec=` or
`HibernateOnACPower=`. Use capability calls for executability and ordered config
readback for policy/provenance. ([logind properties and signals](https://github.com/systemd/systemd/blob/v261/man/org.freedesktop.login1.xml#L724-L798))

## 5. Atomic persistence and concurrency

Quickshell 0.3.1 `FileView` enables `atomicWrites` by default: it writes a
temporary file and renames it over the destination, emits `saved()` or
`saveFailed()`, and can watch external/self changes. This prevents a failed
write from exposing a partial JSON document. ([Quickshell 0.3.1
`FileView`](https://quickshell.org/docs/v0.3.1/types/Quickshell.Io/FileView/))

Linux `rename()` atomically replaces an existing destination name, but it does
not compare the file a writer read with the file currently at that name. Two
independent read-modify-write sequences can both succeed and the later rename
silently loses the earlier update. ([Linux `rename(2)`](https://man7.org/linux/man-pages/man2/rename.2.html))

The robust v1 concurrency rule is consequently **one writer**:

- The long-lived Hibermachy service serializes config mutations and privileged
  apply/reset requests.
- The settings panel calls the service; it never owns a second `FileView` writer.
- A companion CLI/IPC caller sends a mutation command to the service rather than
  rewriting JSON directly.
- Mutations carry a base revision (or are rejected/rebased after an external
  file change), so an open panel cannot overwrite a newer manual/other-client
  edit with a stale full document.
- The service reports a user-config mutation complete only on `saved()` and
  reports `saveFailed()` without changing its advertised durable revision.
- Only one helper request may be in flight. A later request either queues behind
  it or receives a deterministic busy/conflict result; it never overlaps a
  privileged apply/reset.

If later requirements introduce multiple direct file-writing processes, all
cooperating writers need the same separate lock file and must acquire it before
re-reading, validating, and atomically replacing the document. `flock()` locks
are advisory and can be ignored by non-cooperating writers, so a lock cannot make
shared-file mutation safe against arbitrary editors. ([Linux
`flock(2)`](https://man7.org/linux/man-pages/man2/flock.2.html))

Atomic replacement is not by itself a promise of power-loss durability. Tests
should distinguish “no torn live file after write failure” from “survives sudden
power loss,” and the UI should not advance the durable revision merely because
`setText()` was invoked.

## Decision constraints for the ticket

1. Keep plugin activation and Hibermachy automatic-policy enablement distinct.
   Absence from `shell.json` unloads the whole runtime; a user policy toggle can
   leave the installed plugin/service available while disarming automatic
   requests.
2. Preserve valid user intent while hibernation is temporarily unavailable.
   Runtime capability loss selects the already-decided suspend fallback; it must
   not silently rewrite the user's desired policy.
3. Represent requested system policy, effective system policy, and live
   executability as three different status fields. A successful helper write can
   coexist with an administrator override or a negative/transient logind result.
4. A config change during active staged sleep applies next cycle. Manual wake
   ends the current systemd cycle; Hibermachy must not resume or recreate its own
   hibernate countdown.
5. Plugin reload reconstructs the service from durable user intent and fresh
   system observations. Ephemeral execution state is never restored from disk.
6. Every mutation has one serialized owner and an observable commit/failure
   result. Atomic replacement is necessary but not sufficient for concurrency.

## Prior project context consulted

- `research/quattro-integration-seams` at `e2ac62d`
- `research/helper-security-packaging` at `65c3dc8`
- `research/compatibility-envelope` at `c198999`
- Resolutions for “Constrain privileged configuration,” “Map Quattro integration
  seams,” “Establish helper security and packaging constraints,” and “Choose the
  plugin runtime architecture” in the local Markdown tracker
