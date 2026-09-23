# 20: Complete the deterministic Quattro product merge gate

**Parent spec:** [Architect Hibermachy for Omarchy Quattro](../spec.md)

**What to build:** The Quattro-hosted product seam receives deterministic, traceable merge-gate coverage of every safety-relevant user, IPC, platform, persistence, and accessibility behavior without real sleep or privileged host mutation.

**Blocked by:** 12: Diagnose outcomes without leaking or replaying.

**Status:** complete

**Claimed by:** impl/20-quattro-product-merge-gate

- [x] Stable checks cover controlled time, activity, Stay Awake, compositor and system inhibitors, logind capabilities/signals, AC state, helper results, persistence failures, reload, boot changes, concurrency, and all outcome, phase, readiness, reason, notification, re-arm, retry, history, and redaction cases.
- [x] Permanent fixtures cover every shipped user-policy schema and migration, malformed and newer documents, protocol overlaps, requested/effective policy readback, administrator precedence, and structured event envelopes.
- [x] Public hosted tests drive panel controls, confirmations, keyboard journeys, Super+Space adapters, IPC, activity/idle transitions, policy mutations, reload, notifications, journals, and diagnostics while observing only public receipts, status, durable artifacts, and selected simulated submissions.
- [x] Configuration parsers receive property or fuzz coverage and persistence, evidence, timing, concurrency, and retry boundaries receive deterministic fault injection.
- [x] An accelerated product transition soak detects duplicate sleep submission, stuck busy state, stale state, retry storms, unbounded history or notification growth, and resource growth across thousands of transitions.
- [x] Tests avoid private coordinator state, private QML structure, internal call order, free-form log wording, real sleep, and real privileged host writes; named external invariants take precedence over a line-coverage percentage.

**Completion evidence:** Commit `e05a052` (`test: complete deterministic quattro merge gate`) adds permanent policy fixtures, removes private QML-structure assertions, adds a test-only controlled clock and public accelerated 2,000-transition soak, and keeps hosted assertions on public receipts, status, diagnostics, and durable artifacts. `bash -n tests/quattro-hosted-plugin.sh`, fixture JSON classification, and `git diff --check` pass. No real sleep, privileged host mutation, package/plugin operation, publication, merge, push, or worker delegation was performed.

**Validation constraints:** `npm test` reaches the Quickshell-hosted gate but cannot launch in this environment: `Could not create instance runtime directory at "/run/user/1000/quickshell/..."`, `Failed to create wl_display (Operation not permitted)`, and `This application failed to start because no Qt platform plugin could be initialized.` Rust validation was not runnable: `rustup could not choose a version of cargo to run, because one wasn't specified explicitly, and no default is configured`; no toolchain was installed.

**Review evidence:** Two-axis review against fixed point `be10a4a`: Standards — no documented-standard violations or actionable baseline smell. Spec — no missing/partial requirement or scope-creep finding in the ticket-scoped diff. Review was performed in-agent because the request prohibited worker delegation.
