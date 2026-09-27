# Architect Hibermachy for Omarchy Quattro

Status: ready-for-agent
Source map: [Architect Hibermachy for Omarchy Quattro](map.md)

## Problem Statement

Omarchy Quattro can suspend or hibernate on explicit request, but it does not offer a public, independently installable policy that suspends after an idle delay and then transitions to hibernation after a further suspended interval. A user who wants that behavior currently has to coordinate user-idle detection, Stay Awake, Wayland idle inhibitors, logind sleep inhibitors, systemd's machine-wide staged-sleep policy, hibernation readiness, locking, configuration persistence, and privileged system configuration themselves.

That coordination is easy to make unsafe. A plugin can accidentally bypass inhibitors, duplicate Omarchy's locking behavior, depend on private shell internals, lose its timer during shell reload or suspend, mistake a request accepted by systemd for a completed hibernation, or grant a user-writable plugin an overly broad root execution path. Installation and removal also cross independently owned user and system scopes, so ordinary plugin removal can otherwise leave active machine-wide policy behind without explaining it.

Hibermachy must provide automatic staged sleep and a deliberate manual staged-sleep action while feeling native to Quattro, failing closed when required contracts or policy are invalid, preserving administrator authority, and remaining diagnosable without claiming more evidence than the platform exposes.

## Solution

Build Hibermachy as a public, independently installable Omarchy Quattro plugin with a long-lived service and a native settings panel. The service coordinates an independent inhibitor-aware idle monitor with Omarchy's public Stay Awake check and systemd/logind's supported sleep interfaces. It delegates the entire suspended interval to systemd, preserves Omarchy's existing lock integration, and funnels automatic and manual requests through one execution gate.

Automatic staged sleep uses a user-owned idle delay, then requests systemd suspend-then-hibernate when it is executable. If hibernation is unavailable but suspend is executable, Hibermachy safely degrades to ordinary suspend and explains the limitation. A separate confirmed manual action bypasses Stay Awake and compositor idle inhibition because it expresses immediate user intent, while continuing to honor system sleep inhibitors.

Keep machine-wide hibernate delay and AC behavior behind a separately packaged, root-owned, one-shot Rust helper. Every apply or reset requires fresh administrator authorization. The helper accepts only a fixed, bounded command vocabulary, atomically owns one Hibermachy systemd drop-in, never initiates sleep, and refuses suspicious filesystem or protocol state.

Expose configuration through a single-sheet native panel and two namespaced Super+Space entries. Separate unprivileged user-policy saves from authenticated system-policy changes. Present user intent, requested system policy, effective system policy, live sleep executability, fallbacks, blockers, and historical outcomes as distinct concepts.

Ship a native-first, rerunnable lifecycle for installation, update, disablement, plugin removal, full uninstall, and purge. Treat the plugin checkout, activation, menu contribution, user data, helper package, and requested system policy as separate scopes. Verify one immutable release candidate through traceable automated, clean-room, security, accessibility, lifecycle, and attended hardware gates before stable promotion.

## User Stories

1. As an Omarchy user, I want my computer to suspend after an idle delay and hibernate after a further suspended interval, so that it saves power without sacrificing quick short-term resume.
2. As an Omarchy user, I want the idle delay and hibernate delay to be described as sequential periods, so that I understand when each phase begins.
3. As an Omarchy user, I want automatic staged sleep disabled on first activation, so that installing or activating Hibermachy never surprises me with an automatic power action.
4. As an Omarchy user, I want to enable or disable automatic staged sleep independently of plugin activation, so that I can keep settings, status, diagnostics, and manual actions available.
5. As an Omarchy user, I want disabling automatic staged sleep to preserve my other policy values, so that I can pause automation without reconfiguring it later.
6. As an Omarchy user, I want automatic staged sleep to respect Wayland idle inhibitors, so that presentations, media, and other inhibitor-aware activity are not interrupted.
7. As an Omarchy user, I want automatic staged sleep to respect Omarchy's Stay Awake state, so that Quattro's existing user control remains authoritative.
8. As an Omarchy user, I want manual staged sleep to bypass Stay Awake and compositor idle inhibition, so that an explicit request acts on my immediate intent.
9. As an Omarchy user, I want manual staged sleep to continue honoring system sleep inhibitors, so that Hibermachy never forces the machine past system safety policy.
10. As an Omarchy user, I want ordinary Suspend and laptop-lid behavior left unchanged, so that Hibermachy adds a policy rather than replacing familiar power controls.
11. As an Omarchy user, I want Omarchy's existing pre-suspend lock integration to remain the sole lock owner, so that duplicate locking and ordering races are avoided.
12. As an Omarchy user, I want a manual Suspend then Hibernate action in the Super+Space System submenu, so that it sits alongside the existing power actions.
13. As an Omarchy user, I want Sleep & Hibernation in the Super+Space Setup submenu, so that configuration is discoverable without cluttering the root menu.
14. As an Omarchy user, I want both menu entries searchable by sleep, hibernate, and Hibermachy terms, so that I can reach them without navigating the hierarchy.
15. As an Omarchy user, I want stale menu entries hidden when the compatible Hibermachy service is unavailable, so that disabled or removed runtime code does not leave broken actions.
16. As an Omarchy user, I want a compact, native Quattro settings panel, so that Hibermachy feels like part of the desktop rather than a separate application.
17. As a keyboard user, I want every panel, confirmation, and cancellation path operable without a pointer, so that the feature is accessible.
18. As a low-vision user, I want semantic status that does not rely on color alone and works under enlarged scaling and varied contrast themes, so that I can understand current behavior.
19. As an Omarchy user, I want user-policy edits and system-policy edits held as drafts until I explicitly commit their owning section, so that merely opening or changing a control does not mutate policy.
20. As an Omarchy user, I want to save automatic-policy enablement and idle delay without authentication, so that user-owned intent stays convenient to change.
21. As an Omarchy user, I want hibernate delay and AC behavior clearly labeled as system-wide, so that I understand their effect on every user and every suspend-then-hibernate caller.
22. As an administrator, I want every system-policy apply and reset to require fresh authentication, so that prior approval is never silently retained.
23. As an administrator, I want an apply review to show the exact delay and AC behavior together, so that I know what the one authenticated mutation will change.
24. As an Omarchy user, I want cancellation of authentication to leave requested policy unchanged and be reported as cancellation rather than failure, so that declining is a safe outcome.
25. As an Omarchy user, I want reset to remove only Hibermachy's requested system policy while preserving plugin activation and user policy, so that cleanup boundaries are predictable.
26. As an Omarchy user, I want a confirmation before any immediate manual staged-sleep request, so that an accidental click does not suspend the machine.
27. As an Omarchy user, I want the manual confirmation to say whether the request will use staged sleep or suspend-only fallback, so that I know the immediate consequence.
28. As an Omarchy user, I want friendly duration presets and exact preservation of valid custom durations, so that the interface is convenient without rewriting my values.
29. As an Omarchy user, I want hibernation on AC disabled by default, so that a battery-equipped machine remains suspended while plugged in unless I choose otherwise.
30. As an Omarchy user, I want an enabled automatic policy with missing or invalid system policy shown as intended but not ready, so that intent is preserved without unsafe execution.
31. As an Omarchy user, I want automatic staged sleep to require fresh activity after activation, reload, relevant policy changes, or a prior sleep cycle, so that it cannot immediately repeat from stale idle state.
32. As an Omarchy user, I want manual actions to remain available while the automatic re-arm latch is set, so that the latch suppresses repetition rather than explicit intent.
33. As an Omarchy user, I want hibernation unavailability to preserve my staged-sleep intent and requested policy, so that normal behavior resumes automatically when capability returns.
34. As an Omarchy user, I want ordinary suspend used when staged hibernation is unavailable but suspend is executable, so that the machine still saves power safely.
35. As an Omarchy user, I want guidance toward Omarchy's hibernation setup when hibernation is unavailable, so that I know the native remediation path.
36. As an Omarchy user, I want no sleep request made when neither staged sleep nor suspend is executable, so that capability failure is safe.
37. As an administrator, I want later administrator systemd policy to remain authoritative, so that Hibermachy never fights local machine policy.
38. As an Omarchy user, I want requested and effective system policy shown separately with override provenance when available, so that a successful write is not confused with the winning configuration.
39. As an Omarchy user, I want live capabilities and inhibitors re-observed rather than restored from disk, so that status reflects the machine now.
40. As an Omarchy user, I want configuration changes during an active staged-sleep cycle to apply only to the next request, so that Hibermachy does not compete with systemd's active timer.
41. As an Omarchy user, I want a valid external edit detected as a new revision and a stale panel mutation rejected, so that concurrent changes are not silently overwritten.
42. As an Omarchy user, I want malformed, out-of-range, unknown, or newer user policy preserved for inspection while automation fails closed, so that Hibermachy does not guess or destroy data.
43. As an Omarchy user, I want an explicit reset for invalid user policy, so that recovery returns to safe disabled defaults only when requested.
44. As an Omarchy user, I want future schema migrations explicit, sequential, and intent-preserving, so that upgrades cannot silently enable automation or privileged policy.
45. As an Omarchy user, I want manual staged sleep not to create configuration or apply system policy as a side effect, so that an immediate action remains independent of setup.
46. As an Omarchy user, I want one coherent status snapshot for the panel and diagnostics, so that different surfaces do not reproduce or disagree about safety policy.
47. As an IPC caller, I want a manual request to return immediately with a typed refusal/failure or an accepted receipt, so that I am not held open across system sleep.
48. As an IPC caller, I want an accepted receipt to identify the attempt and selected mode, so that I can correlate the later outcome without assuming completion.
49. As an Omarchy user, I want outcomes to distinguish suppression, refusal, degradation, failure, indeterminate evidence, and observable completion, so that status is honest and actionable.
50. As an Omarchy user, I want successful staged-sleep transactions labeled as hibernation not confirmed, so that Hibermachy does not claim evidence systemd cannot expose.
51. As an Omarchy user, I want sleep submissions and privileged mutations never replayed automatically, so that recovery cannot duplicate a destructive action.
52. As an Omarchy user, I want routine suppression to remain quiet and new background faults or fallback transitions deduplicated, so that notifications are useful rather than noisy.
53. As an Omarchy user, I want a bounded outcome history that never masquerades as live state, so that prior events remain diagnosable without corrupting current decisions.
54. As a privacy-conscious user, I want copied diagnostics sanitized and deterministic, so that I can share useful evidence without exposing usernames, arbitrary paths, raw configuration, inhibitor text, or unrestricted logs.
55. As an Omarchy user, I want automatic, manual, system-policy, and diagnostics readiness reported independently, so that one degraded operation does not make every feature appear broken.
56. As an Omarchy user, I want plugin reload to finalize an unfinished attempt as indeterminate and retain the re-arm latch, so that disappearance cannot be mistaken for success or trigger a retry.
57. As an Omarchy user, I want a prior open attempt from another boot reported as indeterminate rather than failed hibernation, so that Hibermachy does not invent a cause.
58. As an Omarchy user, I want first-run installation to preserve Quattro's source-review warning and leave the plugin disabled, so that unsandboxed code is not activated implicitly.
59. As an installation owner, I want helper installation to build from an immutable signed and checksummed source release as an unprivileged user and use the normal package manager, so that privileged code follows an explicit trust path.
60. As an installation owner, I want plugin activation offered only after lifecycle and compatibility probes, so that I can review incomplete state before loading the runtime.
61. As an installation owner, I want installation never to apply machine-wide sleep policy, so that package setup alone changes no sleep behavior.
62. As an installation owner, I want helper and plugin versions allowed to differ only when their protocol ranges overlap, so that independent update channels remain safe.
63. As an installation owner, I want lifecycle status to inventory checkout, activation, menu, helper, protocol, user data, requested policy, and owned drop-in separately, so that partial state is visible.
64. As an installation owner, I want setup, update, uninstall, and purge safe to rerun after cancellation or partial failure, so that recovery does not depend on hidden rollback.
65. As an installation owner, I want disabling the plugin distinguished from plugin removal and full uninstall, so that I understand which artifacts and policies remain.
66. As an installation owner, I want full uninstall to reset recognized system policy before removing the helper or checkout, so that machine-wide behavior is not orphaned.
67. As an installation owner, I want purge to require a separate destructive confirmation after uninstall and enumerate the user data it will remove, so that retained intent and history are not erased accidentally.
68. As an installation owner, I want user-modified or colliding menu entries preserved and reported instead of overwritten, so that Hibermachy respects shared user state.
69. As an installation owner, I want supported reinstall-then-reset recovery when native plugin removal or helper removal was incomplete, so that stale recognized policy can still be cleaned safely.
70. As another desktop user on the same machine, I want the guided workflow to disclose that v1 has one installation owner and machine-wide policy, so that I do not assume independent per-user installations are supported.
71. As a contributor, I want automatic verification to simulate sleep and privileged writes in ordinary CI, so that untrusted changes cannot suspend or mutate the host.
72. As a maintainer, I want every normative requirement mapped to a stable check and evidence, so that release readiness is traceable rather than inferred from coverage percentages.
73. As a maintainer, I want clean-room native, lifecycle, security, accessibility, and hardware gates run against one immutable candidate, so that the promoted release is the artifact that was actually verified.
74. As a maintainer, I want product failures and intermittent product behavior to block release, so that promotion cannot rely on informal waivers.
75. As a maintainer, I want attended hardware testing to externally confirm hibernation across repeated cycles, so that a successful transaction return is not mistaken for a physical hibernate result.
76. As a maintainer, I want verification records to name exact environment versions without promising support or certification, so that evidence remains factual and bounded.

## Implementation Decisions

### Product and integration boundary

- V1 is a public, independently installable third-party plugin targeting the Omarchy 4.0.1 Quattro contract. It is designed so its ideas may later be upstreamed, but it does not replace or clone Omarchy's idle service.
- The main plugin declares only `service` and `panel` kinds. It does not include a same-id bar widget because Quattro cannot remove that widget while keeping the service active. A companion widget is deferred.
- The long-lived service owns all automatic behavior and state coordination. The panel, menu rows, lifecycle tooling, and IPC clients remain adapters; they do not choose fallback behavior, inspect inhibitors independently, issue system policy writes directly, or invoke sleep outside the coordinator.
- Use only documented Quattro seams: plugin service/panel loading, panel summon, plugin-owned IPC, explicit menu extension, Quickshell's idle monitor, the public Stay Awake status command, and public shell readiness/discovery operations. Do not depend on private idle objects, the Stay Awake state-file location, private shell mutation methods, `bar.shell`, or an `omarchy.idle` clone.
- The independent idle monitor uses inhibitor-aware behavior. V1 accepts bounded drift from Omarchy's screensaver-aware idle cycle rather than depending on private objects. Exact cross-service idle-cycle alignment requires a future public Omarchy contract.
- Super+Space uses the exact namespaced menu ids `setup.hibermachy` and `system.hibermachy-staged-sleep`. Setup opens Sleep & Hibernation; System invokes the manual Suspend then Hibernate flow. No Hibermachy root-menu row is added.
- Menu actions use fixed unprivileged shell/IPC adapters and fixed arguments. Both rows self-hide whenever a compatible live service is unavailable.

### Runtime and staged-sleep coordination

- The service contains one private staged-sleep coordinator and one execution gate shared by automatic and manual requests. Concurrent sleep requests receive a deterministic typed refusal; no stale request is queued.
- Automatic eligibility requires plugin activation, valid user policy with automatic-policy enablement on, a valid and readable requested/effective system policy, compatible required runtime contracts, a healthy configured idle monitor, a satisfied re-arm rule, fresh capability and inhibitor observations, no compositor idle inhibitor, and Stay Awake off.
- Idle expiry is an internal automatic origin. Immediately before acting, the coordinator queries the public Stay Awake status. The caller cannot spoof automatic versus manual origin.
- The only public mutating sleep-control command is `requestStagedSleep()`. It is always manual, bypasses automatic-policy state, Stay Awake, and compositor idle inhibition, but honors current system/logind inhibitors and capability results.
- The public sleep-control read surface is one coherent status snapshot. Capability selection, Stay Awake evaluation, eligibility, fallback, evidence reconciliation, and re-arm policy remain private.
- Every request re-queries logind's suspend, hibernate, and suspend-then-hibernate capabilities. If suspend-then-hibernate is executable, select staged sleep. If it is not executable but suspend is, select ordinary suspend and report a degraded outcome. If neither is executable, do nothing and report the typed reason.
- Sleep requests use systemd's normal suspend-then-hibernate or suspend operations without inhibitor-override flags. systemd owns the suspended interval and the eventual transition to hibernation; Hibermachy maintains no userspace hibernate timer and never touches RTC wakealarm interfaces.
- Omarchy remains the sole owner of pre-suspend locking. Hibermachy issues no lock command and does not claim lock success without typed evidence. An unavailable lock signal is recorded as not observed rather than guessed.
- The re-arm latch is durably committed before either automatic or manual sleep submission. A known pre-sleep failure may clear it. A request that enters sleep or becomes indeterminate keeps it set; automatic sleep cannot run again until the idle monitor observes fresh user activity. Manual requests remain possible while latched.
- Service creation, plugin reload, valid enablement, a shortened idle delay, and any state transition that newly makes automation possible require fresh user activity before automatic execution. Reload reconstructs durable intent and fresh live observations and never restores a hibernate countdown, busy state, inhibitor snapshot, or capability snapshot.

### Configuration and state ownership

- Omarchy owns plugin activation. Hibermachy's user policy does not duplicate activation.
- The service is the sole writer of a versioned user-policy document under the user's XDG configuration scope. Panels and IPC clients submit revisioned mutations to the service.
- V1 user policy is a UTF-8 JSON object without a byte-order mark, no larger than 16 KiB, containing exactly four required keys: schema version, revision, automatic-policy enablement, and idle delay in seconds.
- V1 accepts schema version 1; a JSON boolean enablement; an integer idle delay from 300 through 86,400 seconds inclusive; and an integer revision from 1 through JavaScript's maximum safe integer inclusive. Duplicate, unknown, missing, mistyped, fractional, unsafe, or out-of-range values invalidate the whole document.
- First load of an absent document atomically creates revision 1 with automation disabled and a 1,800-second idle delay. Automation stays disarmed until persistence succeeds. A manual staged-sleep request never creates configuration.
- The canonical writer uses stable key ordering, two-space indentation, and one trailing newline. Friendly UI durations normalize to whole seconds only when committed.
- User-policy mutations include a base revision. The service serializes writes, validates the complete result, atomically replaces the document, and advances the advertised durable revision only after confirmed persistence. A stale mutation returns the current snapshot as a conflict.
- A valid external semantic edit must retain the service's current revision. The service validates and canonicalizes it as a new mutation, then advances the revision. A differing observed revision is a conflict that disarms automation until correction or explicit reset. Formatting-only changes may be canonicalized without advancing revision.
- Missing, malformed, invalid, unknown-schema, or newer-schema documents are left untouched, disarm automatic execution, and expose a precise error. Explicit reset writes safe disabled defaults using the next known valid revision or revision 1 when no valid revision is available.
- Future migrations accept only explicitly recognized older schemas, run sequentially, validate the complete result, and commit atomically with one revision advance. They cannot enable automation, alter established intent, or apply privileged policy merely to populate a field. Failure leaves the original untouched and automation disarmed.
- The requested system policy contains the hibernate delay and whether hibernation may occur while connected to AC. It is owned only by Hibermachy's dedicated root-managed systemd drop-in and is not duplicated as authoritative user configuration.
- Effective system policy is the reconciled result of all ordered systemd configuration. Hibermachy reads requested and effective values separately with source provenance when possible. A complete administrator override remains valid and authoritative even when outside Hibermachy's helper input range.
- Live sleep executability, inhibitors, external power, and sleep-transaction observations belong to logind and are always refreshed. The coordinator's execution-gate state is memory-only.
- The only reload-surviving runtime coordination is the re-arm latch in the user's runtime scope. Durable outcome history belongs to the user's XDG state scope and never restores live state.

### Settings panel and user interaction

- Use the selected single-sheet native panel: a compact, vertically scrolling surface styled and sized like stock Quattro panels, with native hero, separators, uppercase section headers, theme roles, focus treatment, and keyboard behavior.
- The hero names Sleep & Hibernation, shows a semantic operation state, and explains what the next automatic or manual request would do.
- Automatic staged sleep contains the automatic-policy toggle and idle-delay draft with a distinct Save automatic policy action. Saving is unprivileged and never implies a system-policy change.
- System policy contains the hibernate-delay draft, Hibernate while plugged in draft, a system-wide notice, authenticated Apply system policy action, and authenticated Reset action when owned policy exists. Apply always submits both values as one pair.
- Current status separately shows automatic-policy enablement, requested system policy, effective system policy, current sleep executability, Stay Awake, and active blocking reason.
- The panel includes a secondary confirmed manual action; the Super+Space System row remains its primary menu location.
- Idle-delay presets are 5, 15, and 30 minutes and 1, 2, 4, 8, and 24 hours. Hibernate-delay presets are 15 and 30 minutes and 1, 2, 4, 8, and 24 hours and 7 days. Valid non-preset values remain exact and display as custom friendly durations.
- The primary semantic states are Ready, Suspend fallback, Automation paused, Unavailable now, Policy differs, and intended-but-Not-ready policy. Status uses non-color text and operation-scoped detail.
- Applying system policy reviews the exact pair and then uses the native Polkit flow. Reset explains its narrow effect before authorization. Manual staged sleep always requires a confirmation describing the selected mode, Stay Awake/compositor-inhibitor bypass, and continued system-inhibitor enforcement.
- User and system drafts are separate commit domains. Each reports its own success, cancellation, stale conflict, busy refusal, or failure. Partial success is never presented as an atomic save.

### Privileged policy helper

- The helper is a small, non-setuid, root-owned Rust executable in a separate Arch package with minimal dependencies and a matching application Polkit policy. It is neither a daemon nor a sleep executor.
- Unsafe Rust is forbidden except in one isolated, reviewed low-level filesystem module. The privileged implementation and packaging require an independent security-aware human review before daily use; the project does not call the component audited or secure without corresponding evidence.
- The mutating protocol is exactly `apply <delay-seconds> <yes|no>` and `reset`. A separate unprivileged read-only protocol/version probe is allowed. No status mutation, arbitrary key/value input, caller-selected path, stdin configuration, command execution, shell fragment, or free-form escape hatch exists.
- Apply accepts canonical unsigned ASCII decimal seconds from 900 through 604,800 inclusive and exactly `yes` or `no` for AC behavior. It always validates both after elevation and generates a canonical format-version-1 systemd Sleep section containing only the two owned directives.
- The initial panel proposal is a 7,200-second hibernate delay with hibernation on AC disabled. It is not persisted until the user explicitly applies it.
- Reset is idempotent only for an absent or recognized Hibermachy-managed target. A modified, unfamiliar, symlinked, hard-linked, wrongly owned, wrongly permissioned, or otherwise suspicious object is refused for manual administrator inspection.
- Every mutation uses active-session `auth_admin` without retained authorization. No passwordless rule, application-shipped Polkit rules file, GUI environment allowance, setuid bit, file capability, sudo fallback, or root graphical settings process is permitted.
- The helper requires effective root for mutation, uses compile-time absolute paths, distrusts all arguments and environment, changes to a safe working directory, sets a restrictive umask, closes unexpected descriptors, emits bounded diagnostics, and invokes no shell, external command, network access, or plugin loader.
- Filesystem traversal is descriptor-relative and refuses symlinks or escape through every path component. The helper verifies directory and target type, ownership, mode, and link count; serializes cooperating mutations; writes a unique same-directory temporary file; verifies metadata; syncs file and directory; and atomically replaces or removes only its fixed target.
- On any failure, the previous complete policy remains in place and cleanup targets only the temporary object created by that invocation. No wildcard cleanup is used.
- Apply/reset success requires recognized owned-policy readback. Contradictory readback is failed verification; unavailable readback is indeterminate. Effective-policy reconciliation follows separately and cannot turn administrator precedence into a write failure.
- The helper never reloads systemd or logind, initiates sleep, bypasses inhibitors, configures hibernation, modifies swap/initramfs/bootloader settings, writes RTC state, or edits another administrator file.

### Compatibility and operational readiness

- The initial verified environment is Omarchy 4.0.1, Quickshell 0.3.1, and systemd 261, subject to the release gates. The published verification record names exact package versions rather than promising continued support.
- Later Omarchy 4.x and development environments may operate only when required runtime contracts pass and remain unverified until their exact combination passes release verification. Other Omarchy majors leave automatic actions disarmed. Pre-Quattro and Omarchy 5 receive no v1 compatibility promise.
- Runtime preflight checks the authoritative installed Omarchy version, live shell readiness, plugin discovery and activation, manifest and shell schema contracts, required public IPC and QML features, idle-monitor availability, helper protocol overlap, user policy, requested/effective policy readback, and logind capabilities.
- Version metadata cannot substitute for feature probes. Missing or mismatched required contracts produce operation-scoped contract incompatibility and fail the affected operation closed.
- Plugin activation remains possible with an absent or incompatible helper so the panel, diagnostics, and safe manual suspend fallback remain available. Privileged mutation and automatic staged sleep remain disarmed until compatible helper and policy readiness are established.
- Hibernation unavailability does not erase user intent or requested policy. Suspend fallback is selected per request when possible, and staged behavior resumes when capability returns and the re-arm rule is satisfied.
- `HibernateOnACPower=no` uses systemd semantics directly. On a battery-equipped machine, the system remains suspended on AC and begins the hibernate countdown after AC disconnects. Hibermachy adds no competing power timer or manual-action exception.
- There is no single global health value. Operational readiness is projected separately for automatic staged sleep, manual staged sleep, system-policy mutation, and diagnostics.

### Failure handling and observability

- Evaluation and execution use six outcomes: Suppressed, Refused, Degraded, Failed, Indeterminate, and Completed. Only Failed denotes positively established fault evidence. Completed means the observable system sleep transaction returned successfully and does not prove hibernation.
- A staged-sleep attempt begins only after suppression checks. Its durable phases are eligibility evaluation, re-arm commit, request enqueue, sleep-transaction observation, transaction return, and outcome reconciliation.
- The coordinator subscribes to logind evidence before enqueue. It waits for sleep-entry evidence for the greater of 30 seconds or logind's advertised inhibitor-delay maximum plus 10 seconds. After resume evidence it allows 30 seconds for typed unit-result reconciliation. User-space freezing pauses the deadline during real sleep.
- Missing or contradictory expected evidence becomes Indeterminate and is never retried as the same attempt. Free-form journal text may corroborate human diagnosis but never drives product state.
- Requested and selected modes are recorded separately. The staged Completed result explicitly carries hibernation not confirmed because systemd's aggregate transaction cannot prove suspend entry, RTC wake, hibernation, restore, or wake cause.
- `requestStagedSleep()` returns immediately with a typed refusal/failure or an accepted receipt containing attempt id, selected mode, and staged-versus-suspend-fallback selection. Caller disconnect does not cancel or retry an accepted attempt. Final results are read from status or outcome history.
- Required safety-gate read failure is a failed evaluation and uses no stale state. Authentication cancellation, inhibitors, busy results, and stale conflicts are refusals; authorization denial, helper rejection, persistence failure, request submission failure, and typed sleep-unit failure are failures.
- Service recreation finalizes an open attempt as Indeterminate because the service generation ended. A boot-id change finalizes it as Indeterminate because the prior boot ended. Neither condition claims failed hibernation or submits another request.
- Only read-only probes, outcome-history persistence, and safe initialization retry automatically. Transient retries occur after 1, 5, and 30 seconds, then every 5 minutes while active; relevant changes, explicit refresh, or a new manual request trigger a fresh observation. Deterministic schema, protocol, and contract errors wait for input change.
- Sleep submission and helper apply/reset are never automatically replayed. A new automatic attempt requires fresh activity and a new idle expiry; a manual request or privileged mutation requires fresh user action.
- Status hero precedence is active sleep transaction, actionable failure or indeterminate attempt, Unavailable now, Policy differs, Suspend fallback, Automation paused or awaiting fresh activity, then Ready. Disabled automatic policy is neutral, and diagnostic degradation does not mask other working operations.
- All status, history, journal, diagnostics, notifications, and tests use a versioned structured event envelope with event and correlation identifiers, wall and monotonic time, boot and service-generation identifiers, origin, operation, phase, outcome, stable reason code, requested and selected modes, evidence level, and a small allowlisted detail object.
- Stable v1 reason codes use closed `runtime`, `config`, `idle`, `policy`, `sleep`, `lock`, and `history` families. Human copy is derived separately; unknown codes get generic safe copy without changing their diagnostic identity.
- Durable outcome history is one atomically replaced, versioned JSON document with at most one open attempt, 256 terminal outcomes retained no longer than 90 days, coalesced suppression summaries, and bounded notification fingerprints. It stores no live capability, inhibitor, readiness, busy, or sleep state.
- Corrupt or newer history is preserved and disables replacement until explicit reset archives the owned rejected document and starts an empty valid history. History failure degrades diagnostics but does not block otherwise safe sleep; re-arm-latch persistence failure does block submission.
- Routine suppression is silent. Foreground work reports inline. After resume, one deduplicated notification is emitted for a new background failure, indeterminate attempt, explicitly observed lock failure, or first transition to suspend fallback. Recovery or material condition change resets relevant deduplication.
- Copy diagnostics emits deterministic, pretty-printed, versioned JSON containing component versions, readiness projections, sanitized policy/provenance, capabilities, history health, and the latest 20 sanitized outcomes. It excludes raw configuration, journal text, usernames, process ids, arbitrary inhibitor text, environment data, and unrestricted paths; nothing is transmitted automatically.
- The user service emits structured user-journal transitions; the privileged helper emits authenticated actions and typed results to the system journal. Journal failure never changes the operation result.
- Recovery controls are limited to refresh, explicit reset of invalid user policy or history, authenticated reapply/reset of requested policy, and a new explicit manual request. Package, protocol, installation, and menu faults route to the lifecycle workflow.

### Distribution and lifecycle

- V1 supports one installation owner per machine. The checkout, menu contribution, configuration, and state are owned by that Omarchy desktop user; helper and requested system policy are machine-wide. Guided workflows disclose this before privileged changes and full removal.
- The public GitHub repository is the sole v1 publication source and contains plugin source, helper source, lifecycle tooling, and an Arch packaging recipe. V1 is not published to AUR and ships no unsigned prebuilt root helper.
- The `hibermachy-helper` recipe builds locally as the unprivileged user from an immutable, cryptographically signed, checksummed GitHub release source. Pacman owns the installed helper and Polkit files. The package identity remains suitable for a later AUR channel without changing installed identity.
- Installation begins with Quattro's native plugin-add command and preserves its unsandboxed-code warning and review opportunity. The checkout remains disabled.
- The checkout-local lifecycle interface inventories every scope, verifies the Quattro environment, builds and installs the helper package through normal interactive Arch tooling, atomically reconciles the menu contribution, probes integration, and reports incomplete scopes.
- Installation never applies requested system policy. Final activation is an explicit confirmation delegated to Quattro's native enable operation; declining leaves the plugin disabled.
- The running plugin can invoke only authenticated apply/reset and the unprivileged helper protocol probe. It cannot install, update, replace, or remove packages. Lifecycle tooling cannot suppress Quattro's review prompt or pacman's authorization prompt.
- Plugin/helper release versions may differ when declared protocol ranges overlap. Mismatch reports both versions, disables helper-backed mutation and automatic staged sleep, and preserves safe manual suspend fallback. Compatibility is rechecked before privileged use.
- Menu reconciliation is an atomic, structure-aware edit of shared JSONC. It preserves unrelated entries, ordering, and comments; changes only recognized generated entries; and refuses malformed input, id collisions, or modified managed entries.
- Guided update records activation, disables an active plugin, invokes Quattro's reviewed fast-forward update without automatic acceptance, transfers control to the updated lifecycle interface, rebuilds the helper from the new immutable release, reconciles known menu entries, reruns probes, and restores prior activation only after success. A previously disabled plugin remains disabled.
- Cross-scope lifecycle operations are not atomic. They retain completed valid work, report exact surviving state, and are safe to rerun. They do not perform automatic downgrade or cross-scope rollback after cancellation or failure.
- Disablement delegates to Quattro and unloads service/panel while preserving checkout, menu, user data, helper, and effective system policy.
- Plugin removal disables and removes only the user checkout through Quattro. It is explicitly not Hibermachy uninstall and may leave machine-wide requested policy effective.
- Hibermachy uninstall disables the plugin, authenticates and resets recognized policy, and stops if reset is cancelled or fails. It then removes the helper through pacman, verifies helper and owned policy absence, removes recognized menu entries, and removes the checkout last. User configuration and state remain.
- The helper package repeats recognized-policy reset before removal as defense in depth. Package scriptlet failure is not treated as proof that pacman aborted.
- Hibermachy purge completes uninstall, enumerates the exact owned user-data scopes, requires an additional destructive confirmation, validates ownership without following escaping symlinks, and deletes user configuration/state last.
- Lifecycle status independently reports checkout, activation, menu, helper, protocol, user data, requested policy, and owned target. Supported recovery may re-add a compatible checkout disabled or reinstall a compatible helper before validated reset. Unrecognized shared state is left for explicit resolution.

### Verification and release

- Maintain a version-controlled verification matrix mapping every normative requirement to a stable check identifier, gate layer, applicability, environment, and expected evidence. A requirement without a check blocks release unless explicitly observational with a rationale.
- Maintain a component-to-gate mapping. Only non-shipped prose may receive a documentation-only exemption. Uncertain impact selects the broader gate set; unexplained behavioral coverage regression blocks release.
- The merge gate is deterministic and performs no real privileged host write or sleep. It includes clean candidate-only builds; formatting, lint, QML, shell, Rust, static-analysis, packaging, generated-file, and fixture validation; exhaustive safety-state behavior; property/fuzz testing; deterministic fault injection; and an accelerated transition soak.
- Safety behavior covers controlled time, activity, Stay Awake, inhibitors, capabilities/signals, AC state, helper results, filesystem failures, reload, boot changes, concurrency, every outcome/phase/readiness/reason, notification deduplication, re-arm, retry, history bounds, and diagnostic redaction.
- Permanent fixtures cover every shipped user-policy schema and migration, invalid and newer documents, every still-supported plugin/helper protocol overlap, canonical policy readback, administrator precedence, and lifecycle/menu conflicts.
- The release-candidate gate starts from a fresh user profile on a clean verified environment and installs only immutable candidate artifacts. It exercises native discovery, disabled-first installation, activation/disable/reload, service/panel, menu, IPC, idle inhibition, Stay Awake, policy persistence, helper protocol, real Polkit cancellation/authorization, readback, administrator override, journals, diagnostics, and teardown.
- Privileged security and lifecycle tests include hostile arguments, environment, filesystem object substitution, concurrent mutation, interrupted writes, forged protocol data, inactive/denied/cancelled authorization, modified menu entries, and purge-path escape attempts. Rejection must leave everything outside Hibermachy's owned target unchanged.
- Lifecycle journeys cover clean add/setup/activation, declined and later activation, update from the immediately previous public release where one exists, cancellation/failure after every cross-scope step, protocol mismatch, menu collision, disablement, plugin-only removal, uninstall, purge, and incomplete-removal recovery.
- Accessibility sign-off covers keyboard-only forward/reverse navigation, focus restoration, escape/cancellation, dirty/disabled states, authentication return, status announcements, scaling, contrast, non-color distinctions, requested/effective comparison, accessible names/states, and an assistive-technology smoke test.
- Supply-chain checks verify source signature and checksum, unprivileged build, package contents/ownership/modes, dependency/toolchain versions, and current applicable advisories. A known exploitable high- or critical-severity issue in shipped code blocks release unless a version-controlled determination establishes non-applicability.
- Untrusted contributions cannot trigger privileged or hardware jobs or access reusable credentials. Real helper, package, Polkit, hostile-filesystem, destructive lifecycle, and root tests run only in a disposable VM or equivalent disposable system environment after maintainer authorization against a reviewed immutable candidate.
- Every public code release has an attended hardware gate on one designated battery-equipped machine with known-working suspend and hibernation. The procedure is explicitly armed, warns the operator to save work, records/restores initial policy, and never lets capability detection trigger sleep.
- The hardware gate requires three consecutive successful staged-sleep, hibernate, and same-session resume cycles covering at least one automatic request, one manual request, and AC deferral through disconnect. It separately exercises early wake, Stay Awake, compositor inhibition, system-inhibitor refusal, fresh-activity re-arm, reload while latched, and deliberate suspend fallback.
- Hardware evidence uses an external pre-sleep session checkpoint and observation of the powered-down/hibernated state plus sanitized corroborating system evidence. Hibermachy's Completed result or free-form journal text cannot certify hibernation.
- Promotion freezes one candidate commit, publishes exact source and checksums as a prerelease, passes automated gates, builds from that public source, runs applicable native/security/accessibility/hardware gates, publishes a sanitized verification record, promotes the unchanged candidate, and smoke-checks public metadata and downloads.
- Published artifacts are immutable per version. Failure creates a new candidate identity; post-release defects are documented and fixed in a new release.
- The sole maintainer may sign and promote after all gates pass, but the privileged helper still requires the separate security-aware review. Evidence records exact versions and results without claiming general version support, hardware compatibility, security certification, or accessibility certification.

## Testing Decisions

- A good test drives Hibermachy through a public user, IPC, process, lifecycle, or platform boundary and asserts externally visible behavior. Tests must not assert private coordinator states, private QML object structure, helper implementation choices, internal call order, or free-form log wording. Narrow parser/property tests and fault injection supplement but never replace boundary-level acceptance tests.
- The primary Quattro-hosted product seam runs the real plugin service and panel in a disposable Quattro/Wayland environment. Tests drive Super+Space rows, keyboard/panel controls, public IPC, activity/idle transitions, Stay Awake, compositor inhibitors, system inhibitors, capability/evidence scenarios, policy mutations, and reload. They observe public receipts/status, durable user policy and history, notifications/journal envelopes, and the selected sleep submission without performing real sleep in the merge gate.
- The privileged-helper process seam invokes the compiled helper through its exact public command protocol in an isolated filesystem environment and disposable VM. Tests assert process results, recognized policy bytes/metadata, readback, absence of changes outside the owned target, Polkit behavior, concurrency, atomicity, hostile input, and fail-closed handling.
- The lifecycle command seam runs the checkout-local public lifecycle interface against disposable Omarchy, XDG, menu, package, protocol, and policy state. Tests assert scope inventory, disabled-first setup, preservation of unrelated shared JSONC, partial outcomes, safe rerun, update activation restoration, uninstall ordering, purge confirmation, and recovery.
- The immutable-candidate release and attended hardware gates join the three seams into complete user journeys. They validate real Quattro, Quickshell, Polkit, package, systemd, locking, and physical sleep behavior without introducing a fourth implementation-facing test API.
- Existing prior art is platform-level rather than project test code: Quattro's idle service exposes a public-style status snapshot and transition logging; Quattro provides shell readiness, plugin discovery, summon, and reload seams; systemd exposes typed logind capabilities, sleep signals, unit results, and ordered policy readback. The current repository has no Hibermachy implementation or test harness to preserve.
- Automatic/manual distinctions, one execution gate, fallback, inhibitor behavior, re-arm persistence, reload/boot reconciliation, mutation revisions, requested/effective policy, history bounds, notification fingerprints, diagnostic redaction, and all stable reason codes receive deterministic merge-gate coverage.
- Configuration and privileged input parsers receive property or fuzz coverage. Filesystem, concurrency, persistence, evidence, and retry boundaries receive deterministic fault injection. A bounded accelerated soak checks duplicate submissions, stuck busy state, stale state, retry storms, unbounded data/notifications, and resource growth.
- Real sleep, real host policy writes, package destruction, and privileged filesystem attacks are prohibited in ordinary CI. They run only through explicit disposable or attended gates with exact scope inventories and restoration evidence.
- Test results attach to stable requirement/check identifiers. A line-coverage percentage cannot replace named invariant and state-transition evidence.

## Out of Scope

- Implementing, packaging, publishing, submitting, or upstreaming Hibermachy as part of this specification transition.
- Creating implementation tickets; decomposition is a separate workflow transition.
- Supporting pre-Quattro Omarchy, promising compatibility with Omarchy 5, or promising maintenance for unverified version combinations.
- Independent Hibermachy installations for multiple Omarchy desktop users on one machine in v1.
- Replacing Omarchy's normal Suspend action, Hibernate action, laptop-lid policy, screensaver, idle service, or pre-suspend locking integration.
- Cloning `omarchy.idle`, depending on private Quattro shell objects, or guaranteeing exact alignment with Omarchy's screensaver-aware idle cycle.
- A bundled or same-id optional bar widget.
- AUR publication, a project-operated binary package repository, unsigned prebuilt root binaries, pipe-to-root installers, automatic helper installation, or automatic package updates by the running plugin.
- A privileged daemon, root graphical settings application, passwordless/retained authorization, general root command execution, or a helper capable of initiating sleep.
- Reimplementing or repairing swap, initramfs, bootloader, resume-device, RTC, kernel, firmware, GPU, or device-specific hibernation configuration.
- Bypassing Stay Awake for automatic requests, bypassing system sleep inhibitors, or adding inhibitor override controls.
- Proving hibernation from the in-shell runtime alone, inferring sleep phases from elapsed time, or driving product state from free-form journal messages.
- A global health flag, an external watchdog daemon, automatic replay of sleep/policy mutations, unbounded outcome history, or automatic telemetry/upload.
- Hardware-family compatibility claims beyond the designated verified machine and its factual release evidence.
- Future migrations or compatibility changes whose need arises only from later Omarchy, Quickshell, systemd, kernel, or packaging contracts; those require a new decision effort.

## Further Notes

- This specification is the direct downstream artifact of the completed [Architect Hibermachy for Omarchy Quattro](map.md) Wayfinder map. All fourteen linked decision tickets are resolved, unclaimed, and represented here; the map's Not yet specified section is empty.
- The external-behavior test seams were confirmed directly by the user on 2026-08-31 before publication: Quattro-hosted product behavior, the privileged-helper process boundary, and the lifecycle command boundary, joined by immutable-candidate and hardware journeys.
- Domain language follows the repository glossary: suspend, hibernate, staged sleep, idle delay, hibernate delay, automatic-policy enablement, requested system policy, effective system policy, sleep executability, operational readiness, staged-sleep attempt, staged-sleep outcome, and outcome history retain their defined meanings.
- The selected Super+Space placement comes from the resolved Setup + System prototype. The selected panel hierarchy comes from the resolved Single-sheet settings prototype. Prototype code is not normative; the behavioral decisions recorded in this spec are.
- The initial release is experimental. The root helper must remain off daily-use machines until its adversarial suite and independent security-aware review are complete.
