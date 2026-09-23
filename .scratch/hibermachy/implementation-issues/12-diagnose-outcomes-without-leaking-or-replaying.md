# 12: Diagnose outcomes without leaking or replaying

**Parent spec:** [Architect Hibermachy for Omarchy Quattro](../spec.md)

**What to build:** Hibermachy reports structured transitions, bounded history, useful notifications, and deterministic shareable diagnostics while protecting private data and never replaying consequential operations.

**Blocked by:** 11: Present coherent operational readiness in an accessible panel.

**Status:** complete

**Claimed by:** impl/12-privacy-safe-diagnostics

- [x] Status, history, user and system journals, diagnostics, notifications, and tests share the versioned structured envelope and closed v1 reason families, while human copy remains separately derived.
- [x] Unknown reason codes retain their diagnostic identity and receive generic safe copy without changing outcome, operation, phase, or evidence meaning.
- [x] Routine suppression is silent; foreground results stay inline; new background failures, indeterminate attempts, observed lock failures, and first fallback transitions notify once after resume and deduplicate across reload until material recovery or change.
- [x] Corrupt or newer history is preserved and disables replacement until explicit reset archives the rejected owned document; history failure degrades diagnostics without blocking otherwise safe sleep.
- [x] Read-only probes, history persistence, and safe initialization use the bounded retry schedule, while sleep submission and privileged apply/reset are never automatically replayed.
- [x] Copy diagnostics emits deterministic versioned JSON with component versions, readiness, sanitized policy/provenance, capabilities, history health, and at most 20 sanitized outcomes, excluding raw configuration, free-form journals, identity data, arbitrary inhibitor text, environment data, and unrestricted paths.
- [x] Structured journal failure never changes an operation result, no data is automatically transmitted, and redaction, retry, notification, history-reset, journal-failure, and deterministic-export behavior is verified at public surfaces.

**Evidence:**

- Commit: `be10a4a` (`feat: add privacy-safe diagnostic outcomes`) on `impl/12-privacy-safe-diagnostics`, based at `0e827b68c215b1838276426c0917655995a21c66`.
- Hosted validation: `npm test` / `tests/quattro-hosted-plugin.sh` passed the complete matrix, including deterministic redaction/export, journal-failure receipt preservation, rejected-history archive/reset, contract incompatibility, fallback, evidence, suppression, accessibility, policy, reload, and teardown checks.
- Static validation: `bash -n tests/quattro-hosted-plugin.sh` and `git diff 0e827b68c215b1838276426c0917655995a21c66...HEAD --check` passed.
- Two-axis review: Standards — no repository standards files found and no documented-standard violations; no actionable baseline smell. Spec — all seven ticket criteria covered by the service-owned envelope/history/diagnostic boundaries and hosted checks; no scope-creep finding.
- Safety: no real sleep, system-policy write, package operation, network publication, or automatic external transmission was performed.
- Rust helper validation was not runnable because this environment has no installed Rust toolchain; no toolchain was installed.
