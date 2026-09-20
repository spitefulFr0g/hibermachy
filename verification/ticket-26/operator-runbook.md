# Ticket 26 attended hardware gate and promotion runbook

This runbook is a control document. It is not evidence that any gate passed.

It is bound to candidate commit `625d5a22c57d7ab0f792330a3bb7eaa0880f7304`,
tree `8f3e33a03b1609d2957c63367a4a9c471b6e4ef6`, and source-archive SHA-256
`1eb0a56ca3cff03012884ef7cb7e8dc0c659b8b8db4ccf39d52a0fb75b3a9e5f` produced by
`git archive --format=tar --prefix=hibermachy-helper-0.1.0/ <commit> | gzip -n -9`.
Changing shipped bits, public artifacts, or any bound checksum invalidates the
run and requires a new candidate identity.

The procedure is driven by `handoff/attended-release-625d5a2.sh`, which walks
the operator through every stage below, records results as they are observed,
and stops before anything is published. This document is the specification that
script implements; read it before running the script.

## Determinations carried forward from issue #25

Issue #25 closed with three criteria resolved by owner determination rather than
by evidence. They are carried forward as accepted-unmet. They are not re-argued
here, and they do not block this run — but they permanently constrain what this
release may claim.

| Criterion | Determination | Consequence |
| --- | --- | --- |
| AC2 clean environment | accepted unmet; no clean environment exists | never describe this release as clean-room qualified |
| AC5 accessibility | assistive technology out of scope; accepted unmet | never describe it as accessible or screen-reader tested |
| AC7 independent review | met by owner determination; agent, not human | never describe it as security certified |

The predecessor ticket-24 runbook required every prerequisite to pass before
arming. Applied literally to these three, that rule would block this gate
forever. Recording them as accepted-unmet is what lets the run proceed without
inventing a pass for any of them.

## Hard stop and recording rules

- Run only on the designated battery-equipped machine with independently known
  working suspend and hibernation, with an operator physically present.
- Save work and close sensitive material before arming. Capability and status
  inspection must never invoke sleep.
- Enter every result as `PASS`, `FAIL`, or `NOT RUN`. A blank never means pass.
- Stop on any mismatch, product failure, intermittency, unexplained wake or
  power transition, restoration mismatch, or evidence gap. Investigate before a
  new run; after an anomaly, restart the consecutive-cycle count at zero.
- A Hibermachy `Completed` result, a successful systemd transaction, or
  free-form journal text does not certify physical hibernation.
- Never set `HBR_TEST_MODE`, `HBR_LIFECYCLE_TEST_MODE`, or any `HIBERMACHY_SIM_*`
  variable during the run, and never call the fixture entry points
  (`setActivityFixture`, `setStayAwakeFixture`, `setClockFixture`,
  `setSystemPolicyFixture`, `runAcceleratedSoak`, or the
  `dev.hibermachy.panel-test` target). With those unset they refuse by
  construction. With them set, the gate measures fixtures and any pass it
  produces is worthless.
- Sanitize hostnames, usernames, boot and session IDs, network identifiers,
  device serials, and journal content before committing or publishing evidence.

## Phase 0 — immutable inputs (non-mutating)

1. Run `verification/ticket-26/verify-candidate-identity.sh <repo>` and paste
   its complete output into the evidence record.
2. Record exact OS, kernel, Omarchy, Quickshell, systemd, hardware family and
   power-source state.
3. Verify the source archive and detached signature against the independently
   obtained maintainer fingerprint `0B1C5414F8D18F8B6AA78957335FEBC82DB247EC`.
4. Confirm no test-mode or simulation variable is set in the environment.

Clean-room, accessibility and independent-review prerequisites are recorded as
accepted-unmet per the determinations above rather than run.

## Phase 1 — capture initial state (non-sleeping)

Record sanitized before-inventories for effective `sleep.conf` and
`logind.conf`, the Hibermachy status snapshot, the lifecycle inventory, swap
topology, and current inhibitors. Take the external session checkpoint that can
distinguish a same-session resume. Querying capabilities is not an arm action
and must not sleep the machine.

Pre-flight also records two conditions of this specific machine, documented in
`verification/ticket-26/preflight-findings.md`: a vendor drop-in disables
user-session freezing on the sleep units, and the staged-sleep unit has never
run here before. Neither is a defect and neither may be "fixed" during the run.

## Phase 2 — explicit operator arm

After confirming Phase 0 and Phase 1 are complete and work is saved, the
physically present operator enters this exact statement:

`ARMED BY OPERATOR: work saved; designated machine confirmed; real sleep authorized`

Do not continue without that exact, timestamped acknowledgement.

## Phase 3 — separate behavioural cases

For every case record setup, public pre-state, action, typed receipt and reason
code, presence or absence of a sleep transition, public post-state, and
restoration. These cases do not count toward the three consecutive cycles.

| Case | Expected observable |
| --- | --- |
| Stay Awake suppression | `automaticBlockerReasonCode` = `HBR-STAY-AWAKE-ENABLED`, no sleep |
| Compositor idle inhibition | `automaticBlockerReasonCode` = `HBR-COMPOSITOR-IDLE-INHIBITED`, no sleep |
| System-inhibitor refusal | manual receipt `kind` = `refused`, `HBR-SLEEP-SYSTEM-INHIBITED`, no sleep |
| Fresh-activity re-arm | `HBR-FRESH-ACTIVITY-REQUIRED` until new activity is observed |
| Reload while latched | no replayed request, no restored countdown, re-arm required again |
| Deliberate suspend fallback | `selectedMode` = `suspend`, outcome Degraded, `HBR-SLEEP-SUSPEND-FALLBACK`, no hibernation claimed |
| Early wake | `HBR-SLEEP-EARLY-WAKE`, latch held, no invented hibernation claim |

Ordinary suspend and lid behaviour must remain owned by the platform and
unchanged throughout.

Two of these have no merge-gate coverage and are exercised here for the first
time: **early wake**, and **reload while latched on the same boot**. Give them
more attention than the other five.

Do not force the suspend-fallback case by mutating system sleep policy or swap
configuration. If it cannot be reached without such a mutation, record it
`NOT RUN` with the reason.

## Phase 4 — three consecutive physical cycles

Run three consecutive successful cycles collectively covering all three origins:

1. Automatic request after observed fresh activity and idle expiry.
2. Confirmed manual request through the menu confirmation journey.
3. AC deferral: begin on AC, confirm it stays suspended rather than
   transitioning, then disconnect AC and observe hibernation.

The order may change, but all three origins must occur within the same
uninterrupted consecutive series. Each cycle requires all of:

- an external pre-sleep session checkpoint;
- the typed request origin, attempt identity, and selected staged-sleep mode;
- an external observation that the machine reached a powered-down state;
- same-session restoration after power-on;
- sanitized corroborating typed system evidence; and
- no unexplained anomaly.

The external checkpoint is taken by `verification/ticket-26/hibernation-checkpoint.sh`, which
compares boot identity, the init instance, a RAM-resident nonce that cannot
survive a power cycle without a restored image, and the divergence between
`CLOCK_MONOTONIC` and `CLOCK_BOOTTIME` that measures the sleep interval.

That checkpoint establishes **same-session restoration across a sleep interval**
and nothing more. It cannot distinguish hibernation from ordinary suspend, and
it does not try to: that distinction rests on the operator's external
observation of a genuinely powered-down machine, which is why AC4 requires it
separately.

Any failure or anomaly resets the count to zero after investigation. Do not
erase a failed attempt; retain its sanitized record and the rerun cause.

## Phase 5 — restoration and release decision

Restore and verify equivalence of all initial owned policy and configuration,
and the absence of changes to unrelated state. Record final inventories. Mark
the hardware gate passed only when every separate case, every three-cycle
criterion, every evidence requirement, and every restoration check passes.

Before promotion, rerun the identity verifier against the exact promotion source
and compare public artifacts and checksums to the bound inputs.

Promotion, signing, publishing, pushing and merging are performed by the release
operator by hand, deliberately, with the finished evidence record in front of
them. The attended script deliberately stops before that boundary and publishes
nothing. After an authorized promotion, smoke-check public version metadata,
artifacts, signatures, checksums, clean downloads and lifecycle discovery.

Published artifacts are immutable per version. A failure creates a new candidate
identity; a post-release defect is documented and fixed in a new release, never
by replacing a published artifact in place.
