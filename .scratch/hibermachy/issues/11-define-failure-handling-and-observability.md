# Define failure handling and observability

Type: grilling
Status: resolved
Blocked by: 07, 08, 09, 10, 13

## Question

How should Hibermachy detect, report, recover from, and make diagnosable failures in idle monitoring, locking, authorization, policy writes, suspend, RTC wake, hibernation, resume, and plugin reload?

## Answer

Hibermachy uses an evidence-based outcome model and never equates command
acceptance with a successful sleep cycle. Evaluation or execution produces one
of six outcomes:

- **Suppressed**: a valid condition prevents an automatic request from becoming
  a staged-sleep attempt, such as Stay Awake, idle inhibition, invalid policy,
  or the re-arm rule.
- **Refused**: an attempted operation is deliberately declined, including a
  system sleep inhibitor, authentication cancellation, or a busy/conflict
  result.
- **Degraded**: the requested behavior is safely reduced, specifically staged
  sleep using ordinary suspend because hibernation is unavailable.
- **Failed**: typed evidence positively establishes a fault.
- **Indeterminate**: expected evidence is missing or contradictory, so
  Hibermachy cannot establish what occurred.
- **Completed**: the observable system sleep transaction returned successfully.
  This does not claim that hibernation occurred.

A staged-sleep attempt begins only after suppression checks. Its durable and
observable phases are eligibility evaluation, re-arm latch commit, request
enqueue, sleep-transaction observation, transaction return, and outcome
reconciliation. The coordinator subscribes to logind evidence before enqueue.
After enqueue it waits for `PrepareForSleep(true)` for the greater of 30 seconds
or logind's advertised inhibitor-delay maximum plus 10 seconds. User-space
freezing pauses its deadline during real sleep. After `PrepareForSleep(false)`,
it allows 30 seconds for typed unit-result reconciliation. Missing or
contradictory evidence at either deadline is indeterminate and is never retried
as the same attempt.

Systemd 261 exposes only an aggregate transaction boundary. A successful
`systemctl suspend-then-hibernate` invocation means the request was enqueued;
`PrepareForSleep(true/false)` and the typed unit result can establish that a
sleep transaction ran and returned. No stable public interface identifies the
requester or proves suspend entry, RTC wake, the hibernation attempt,
hibernation success, or a human/manual wake cause. Aggregate unit success can
also follow an early wake or failed hibernation followed by successful fallback
suspend. Hibermachy therefore records requested and selected modes separately,
labels a successful staged transaction **hibernation not confirmed**, never
infers phases from elapsed time, and never parses free-form journal `MESSAGE`
text to drive product state. Stable journal identifiers and kernel messages may
corroborate a human diagnosis but do not upgrade product state.

Failure handling is operation-specific:

- The idle-monitor module validates construction and configuration, exposes
  health, and records activity/callback transitions. A positive monitor fault
  disarms automatic staged sleep. V1 does not add a second idle detector or
  synthesize missed idle expiry: silent non-firing is indistinguishable from
  continued activity or inhibition and belongs in verification rather than a
  runtime guess.
- Omarchy remains the sole owner of pre-suspend locking. Hibermachy neither
  issues a duplicate lock nor gates sleep on an unavailable lock signal. It
  records a lock failure only when typed evidence explicitly establishes one;
  otherwise the lock outcome is **not observed**, never assumed successful.
- A valid negative eligibility fact is suppression or refusal. Failure to read
  any required safety gate is a failed evaluation and fails closed without
  stale configuration, Stay Awake, policy, capability, or inhibitor state.
  Manual staged sleep ignores automatic-policy and Stay Awake state but still
  requires fresh capability and inhibitor results.
- Authentication cancellation is refused rather than failed. Authorization
  denial, helper validation/security rejection, and helper write failure are
  failures. Busy and stale conflicts are refusals that return current state for
  review.
- `apply` or `reset` succeeds only after the owned drop-in and its metadata read
  back as the requested result. A contradictory readback is failed
  verification; unavailable readback is indeterminate. Effective policy is
  then read separately. An administrator override produces successful
  requested-policy mutation plus **Policy differs**, not a write failure, and
  Hibermachy never implies that applying again will defeat precedence.
- Service recreation never restores stale busy state or attaches an old attempt
  to an uncorrelated systemd transaction. It finalizes an unfinished record as
  **Indeterminate — service instance ended before reconciliation**, exposes any
  current logind transaction separately as external live state, retains the
  re-arm latch, and requires fresh activity before automation. A different boot
  ID produces **Indeterminate — prior boot ended before reconciliation**; this
  never claims failed hibernation or triggers another request.

Hibermachy automatically retries only read-only probes, outcome-history writes,
and safe internal initialization. Transient work retries after 1, 5, and 30
seconds, then every 5 minutes while the service remains active; a relevant file
or property change, explicit panel refresh, or new manual request triggers an
immediate fresh observation. Success resets the schedule. Deterministic schema
errors, protocol incompatibility, and unsupported contracts wait for their
input to change. Sleep submission and privileged `apply`/`reset` are never
automatically replayed. A new automatic attempt requires fresh activity and a
new idle expiry; a new manual attempt or privileged mutation requires explicit
user action. Foreground drafts survive failure for review.

Operational readiness is projected independently for automatic staged sleep,
manual staged sleep, system-policy mutation, and diagnostics. There is no
global healthy/unhealthy flag. The panel retains all four projections and uses
this hero precedence: active sleep transaction, actionable failure or
indeterminate attempt, **Unavailable now**, **Policy differs**, **Suspend
fallback**, **Automation paused** or awaiting fresh activity, then **Ready**.
Disabled automatic policy is neutral. Diagnostic degradation does not make a
working manual action or policy mutation appear unavailable.

The manual `requestStagedSleep()` interface returns immediately with either a
typed suppression/refusal/failure or an accepted receipt containing the attempt
ID, selected mode, and staged-versus-suspend-fallback result. It does not hold a
caller across sleep. A disconnected caller neither cancels nor retries an
accepted attempt; final outcome is read through the status snapshot or outcome
history. The coordinator remains a deep module: panel, menu, and diagnostics
consume its coherent projection rather than reproducing eligibility,
classification, evidence, or recovery policy.

Observability uses a versioned structured envelope shared by live status,
outcome history, journals, copied diagnostics, notifications, and tests. It
contains an event ID, optional attempt ID, wall-clock timestamp, boot ID,
boot-relative monotonic time, service-generation ID, origin, operation, phase,
outcome, stable reason code, requested and selected sleep modes, evidence
level, and a small allowlisted details object. Human-facing copy is derived
separately. The closed v1 reason-code families are `runtime`, `config`, `idle`,
`policy`, `sleep`, `lock`, and `history`, using `<area>.<condition>` names.
Outcome, operation, phase, and reason stay orthogonal. Existing code meanings
never change within schema version 1; an unknown code receives generic safe
copy while remaining visible for diagnostics.

The required v1 conditions cover missing runtime contracts, interrupted
reload, re-arm-latch and internal faults; invalid/read/write/conflict/migration
configuration failures; idle-monitor and Stay Awake state/query outcomes;
missing or incompatible helper, authorization cancellation/denial, busy,
helper rejection/failure, requested-policy read/verification failure,
effective-policy read failure, and policy difference; sleep inhibition,
unsupported capability, capability-query failure, execution-gate busy,
suspend fallback, enqueue failure, transaction failure, incomplete evidence,
and completed-with-hibernation-unconfirmed; observed/not-observed locking; and
corrupt, unwritable, or unexportable history.

Durable outcome history lives in one atomically replaced, versioned JSON
document at `$XDG_STATE_HOME/hibermachy/outcomes.json`. It contains an optional
open attempt, at most 256 terminal outcomes retained no longer than 90 days,
coalesced suppression summaries with first/last timestamps and count, and a
bounded set of active notification fingerprints. A fingerprint stores only the
reason code, affected operation, first/last observation, and last-notified
time. The open attempt is written after the safety-critical re-arm latch commits
and before sleep submission, then atomically becomes its terminal record.
History never stores or restores live capability, inhibitor, readiness, busy,
or sleep state.

History failure is diagnostic degradation: safe sleep continues using in-memory
status and structured journal warnings. Corrupt or newer history is preserved
and no replacement is started until explicit reset; reset archives the rejected
owned file under a timestamped diagnostic name and creates an empty valid
document. Transient writes recover through the read-only retry schedule. By
contrast, failure to persist the re-arm latch disarms automatic staged sleep and
fails a manual request before submission.

Routine suppression is silent. Foreground operations report inline. After
resume, Hibermachy sends one notification for a new background failure,
indeterminate attempt, explicitly observed lock failure, or first transition to
suspend fallback. Identical conditions remain deduplicated across plugin reload
until the affected readiness projection recovers or the condition materially
changes. No notification is sent during sleep entry. Explicit history reset
also resets notification deduplication.

The panel may show escaped, length-limited inhibitor application/reason text
while it remains local and current. History contains only normalized codes and
allowlisted fields. **Copy diagnostics** emits deterministic, pretty-printed,
versioned JSON with component versions, readiness projections, sanitized policy
state and provenance, capability results, history health, and the latest 20
sanitized outcomes. It excludes raw configuration, journal text, usernames,
PIDs, arbitrary inhibitor text, environment data, and unrestricted paths.
Nothing is transmitted automatically.

The user service writes structured user-journal events; the privileged helper
writes each authenticated action and typed result to the system journal. Info
covers lifecycle/readiness transitions, successful policy mutations, attempts,
selected modes, and terminal outcomes. Notice covers first fallback, policy
difference, explicit refusal, and recovery. Warning covers indeterminate
outcomes, diagnostic degradation, and observed lock failures. Error covers
positive configuration, monitor, helper, verification, submission, and
sleep-transaction faults. Debug covers probe attempts and retry scheduling.
Events record transitions rather than polling noise and coalesce repeated
conditions. Journal failure never changes an operation's result.

Recovery controls stay within existing ownership: refresh observations, reset
invalid user policy to safe disabled defaults, reset corrupt outcome history,
authenticated reapply/reset of requested system policy, and an explicit new
manual staged-sleep request. Installation, helper, protocol, and menu problems
route to the terminal lifecycle workflow. The panel shows override provenance
without defeating it, shows inhibitors without bypassing them, and routes
observed lock failures to Omarchy diagnostics. It never edits administrator
files, installs packages, reloads the shell, overrides inhibitors, or repeats
sleep as an automatic repair.

Primary systemd 261 evidence:

- [`systemctl` asynchronous sleep contract](https://github.com/systemd/systemd/blob/v261/man/systemctl.xml#L1702-L1710)
- [login1 capability outcomes](https://github.com/systemd/systemd/blob/v261/man/org.freedesktop.login1.xml#L657-L676)
- [login1 sleep signals and state](https://github.com/systemd/systemd/blob/v261/man/org.freedesktop.login1.xml#L724-L737)
- [sleep actions and user-session freezing](https://github.com/systemd/systemd/blob/v261/man/systemd-suspend.service.xml#L48-L88)
- [suspend-then-hibernate execution and fallback](https://github.com/systemd/systemd/blob/v261/src/sleep/sleep.c#L359-L552)
- [journal field semantics](https://github.com/systemd/systemd/blob/v261/man/systemd.journal-fields.xml#L42-L60)

## Comments

Resolved with the user through eight numbered grilling rounds. The user
accepted every recommendation and explicitly confirmed the consolidated model
as shared understanding. Domain vocabulary was updated inline in `CONTEXT.md`.
The factual systemd evidence check was bounded and read-only; it created no
separate ticket or implementation artifact.
