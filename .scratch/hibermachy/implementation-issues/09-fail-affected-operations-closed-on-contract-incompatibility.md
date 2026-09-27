# 09: Fail affected operations closed on contract incompatibility

**Parent spec:** [Architect Hibermachy for Omarchy Quattro](../spec.md)

**What to build:** Runtime preflight projects compatibility and sleep executability per operation from current public contracts, allowing unaffected Hibermachy functions to remain usable without turning version metadata into a support promise.

**Blocked by:** 06: Submit a confirmed manual staged-sleep request; 08: Manage requested and effective system policy from the panel.

**Status:** complete

**Claim (2026-09-07):** Claimed by `impl/09-contract-compatibility` after
the completed 06/07/08 dependency chain was merged locally at `0d9fc30`.

**Implementation (2026-09-07):** Contract preflight, per-operation
fail-closed reasons, contract-vs-execution readiness, strict byte-level policy
observations, and predecessor policy regression fixes are complete on merged
base `0d9fc30`. Commits are `1810b48`, `45a0d1c`, and `80b3a23`.

The implementation runs a real external contract probe, records the observed
contract matrix, reports later verified environments separately, and exposes
automatic contract eligibility separately from the disarmed trigger/re-arm
execution state. It does not implement idle-trigger execution. Missing or
mismatched contracts fail only the affected public operation closed.

**Validation (2026-09-07):** Full merged hosted matrix passed with
`timeout 600s tests/quattro-hosted-plugin.sh`, including predecessor plugin and
system-policy cases, user-policy cases 001–012 (including BOM/UTF-8 and atomic
replacement failure), incompatible-contract closure, later verified probes,
and both evidence variants. A focused hosted run also passed with
`HIBERMACHY_MATRIX_CASE=1`.

Affected Rust validation passed with the scoped toolchain and
`cargo test --all-targets --features test-support`: 20 `apply_process` tests
and 4 `packaging_contract` tests passed. `cargo fmt --all -- --check`,
`bash -n tests/quattro-hosted-plugin.sh`, and `git diff --check` passed.

**Review (2026-09-07):** Two-axis review against post-merge base `0d9fc30`:
Standards: no documented repository-standard breach; no blocking findings.
Spec: public contract probes, operation-scoped closure, later-version probe
handling, execution/latch distinction, strict byte preservation, and all
predecessor behaviors are covered; no blocking findings.

- [x] Preflight observes installed Omarchy version, live shell readiness, discovery and activation, manifest and shell schemas, required public IPC and QML features, idle-monitor availability, helper protocol overlap, user and system policy, and logind capabilities.
- [x] The exact initial verified environment is reportable as evidence, later Omarchy 4.x environments require passing feature probes, and other major versions leave automatic actions disarmed without being labeled unsupported solely by version.
- [x] Missing or mismatched contracts fail only affected automatic, manual, system-policy, or diagnostics operations closed and expose stable contract-incompatibility reasons.
- [x] Plugin activation remains useful with an absent or incompatible helper: safe manual suspend fallback, panel status, and diagnostics can operate while privileged mutation and automatic staged sleep remain disarmed.
- [x] Capability and contract observations are refreshed rather than restored; hibernation loss preserves requested policy and user intent and allows per-request suspend fallback when suspend remains executable.
- [x] Compatibility, protocol-overlap, feature-probe, helper-absence, capability-transition, and later-version fixtures verify operational behavior without asserting a general support or hardware-compatibility claim.
