# 07: Reconcile attempts into evidence-based outcomes

**Parent spec:** [Architect Hibermachy for Omarchy Quattro](../spec.md)

**What to build:** Accepted sleep requests become durable staged-sleep attempts whose typed platform evidence is reconciled into honest, bounded outcomes across sleep, resume, reload, and boot changes.

**Blocked by:** 06: Submit a confirmed manual staged-sleep request.

**Status:** complete

**Claim (2026-09-07):** Claimed by `impl/07-evidence-outcomes` with dependency
ticket 06 available at `d3fad754c7e32cea1ff64977f7b8898c8a61bfe6`.

**Implementation evidence (2026-09-07):** Committed as
`e49b4b5178969db1e8322ccaa06acbde4758b7fe` plus follow-up commits
`642b849e68a8f6a603ea680022f408aa3cf8cb76`,
`140f839c18d7e88c904081cbd58969adc17d68e8`, and
`a97d578edc9f0c3dbcfe58da6f1865b153b6bfe0`
(`feat: reconcile staged sleep evidence outcomes`, `fix: harden evidence persistence and hosted matrix`,
`fix: preserve one-document attempt durability`, `fix: model typed evidence subscription`).
The Quattro-hosted seam now persists a versioned open-attempt envelope and bounded
terminal history, records typed evidence outcomes (including explicit
hibernation-not-confirmed), retains the re-arm latch, reconciles reload and boot
changes as Indeterminate without replay, bounds suppression and notification data,
and injects deterministic platform/persistence scenarios without real sleep or
host policy mutation.

**Test evidence:** `bash -n tests/quattro-hosted-plugin.sh`,
`git diff --check d3fad754c7e32cea1ff64977f7b8898c8a61bfe6...HEAD`, focused
history-fault and open-attempt-fault cases, and final `npm test` all passed on the
Quattro-hosted simulated matrix. The full matrix covers typed evidence, early
wake, unit failure, missing/contradictory evidence, fallback, suppression,
reload, boot change, latch/open-attempt/history persistence faults, notification
coalescing, and the 256-terminal-outcome bound. Host startup retries and teardown
settling eliminate the prior registration race. No live sleep or host policy
mutation was performed.

**Review evidence (two-axis, against `d3fad754c7e32cea1ff64977f7b8898c8a61bfe6`):**
Standards found no documented-standard breach; remaining findings are judgement
calls only (duplicated expected-attempt calculation and positional test arguments).
Spec review completed with no remaining blocking finding after restoring the
single-document history invariant, checking open-attempt persistence before
enqueue, retaining terminal outcomes through diagnostic-history degradation, and
recording typed evidence subscription phases.

- [x] The re-arm latch commits before submission and an open attempt is durably recorded before enqueue; latch-persistence failure prevents submission while diagnostic-history failure alone does not.
- [x] The coordinator subscribes before enqueue, uses the specified entry and post-resume evidence windows, accounts for userspace freezing, and never derives product state from elapsed sleep time or free-form journal messages.
- [x] Suppressed, Refused, Degraded, Failed, Indeterminate, and Completed remain distinct, and staged Completed explicitly states that hibernation is not confirmed.
- [x] Requested and selected modes, operation, origin, phase, stable reason, evidence level, boot identity, service generation, and correlation identifiers remain orthogonal in a versioned structured envelope.
- [x] Service recreation and boot changes finalize matching open attempts as Indeterminate, retain the re-arm latch, restore no live capability or busy snapshot, and never replay the request.
- [x] Outcome history atomically retains at most one open attempt, 256 terminal outcomes for no more than 90 days, and bounded coalesced suppression and notification data without masquerading as live state.
- [x] Deterministic evidence, early wake, typed unit failure, missing/contradictory signals, reload, boot-change, persistence-fault, and history-bound tests observe public receipts, status, and history.
