# 10: Trigger automatic staged sleep only after fresh activity

**Parent spec:** [Architect Hibermachy for Omarchy Quattro](../spec.md)

**What to build:** The long-lived service initiates automatic staged sleep after the user-owned idle delay only when policy, activity, inhibitors, runtime contracts, and current system state all permit it.

**Blocked by:** 05: Save and recover strict user policy; 07: Reconcile attempts into evidence-based outcomes; 09: Fail affected operations closed on contract incompatibility.

**Status:** complete

**Claim (2026-09-07):** Claimed by `impl/10-fresh-activity-automation` on
review base `80b3a23` after dependency tickets 05/07/09 were available.

**Completion record (2026-09-07):** Committed as
`b8b9e19dc80c21863f018eae1d131b2de597aa8e` (`feat: trigger automatic staged
sleep after fresh activity`). The service now uses Quickshell's independent,
inhibitor-aware `IdleMonitor`, Omarchy's public `omarchy-toggle-idle status`,
live `loginctl show-logind` capability/inhibitor observations, live requested /
effective system-policy readback, normal systemd sleep verbs, durable
fail-closed re-arm persistence, and a shared automatic/manual execution gate.
Test-mode-only public-boundary fixtures cover fresh activity, stale-idle
suppression, Stay Awake, compositor inhibition, staged/fallback selection, and
manual availability while latched. No live sleep or host policy mutation was
enabled or exercised.

**Test evidence:** `npm test` passed the complete recursive Quattro-hosted
simulated matrix; the focused staged and suspend-fallback cases passed;
`bash -n tests/quattro-hosted-plugin.sh`, `git diff --check`,
`cargo +stable fmt --all -- --check`, and
`cargo +stable test --all-targets --features test-support` passed (20
`apply_process` and 4 `packaging_contract` tests). The hosted suite used the
disposable display escalation and simulated sleep only. The initial Rust
invocation was corrected to the supplied scoped stable toolchain.

**Review evidence:** Two-axis review against `80b3a23` completed. Standards:
0 documented breaches; remaining findings were judgement-call divergent-change
and duplication concerns, with shared comparison helpers added. Spec review
findings were fixed by wiring live capability/policy adapters, eliminating the
Stay Awake readiness deadlock, correcting production readback parsing, and
adding fallback-aware hosted acceptance. No unresolved blocking review finding
remains.

- [x] An independent Quickshell idle monitor respects compositor inhibitors and uses the configured idle delay without cloning or extending Omarchy's private idle implementation.
- [x] Idle expiry is an internal automatic origin and rechecks the public Stay Awake status immediately before the shared execution gate; no public caller can spoof this path.
- [x] Automatic eligibility requires active plugin runtime, enabled valid user policy, readable valid requested/effective system policy, compatible contracts, healthy idle monitoring, satisfied re-arm, fresh capabilities and inhibitors, no compositor inhibitor, and Stay Awake off.
- [x] Valid suppression remains quiet and submits nothing; failure to read a required safety gate fails evaluation closed without using stale state.
- [x] Activation, service recreation, reload, newly enabled automation, shortened idle delay, newly ready policy, and every prior sleep cycle require observed fresh activity before another automatic request.
- [x] Manual requests remain available while latched, while a known pre-sleep failure may clear the latch and an entered or indeterminate sleep keeps it set.
- [x] Systemd alone owns the suspended interval and AC deferral semantics; configuration changes during an active cycle affect only a future request.
- [x] Controlled activity, idle, Stay Awake, compositor/system inhibitor, fallback, AC transition, reload, policy-change, re-arm, concurrency, and no-duplicate-submission journeys pass through the public hosted seam.
