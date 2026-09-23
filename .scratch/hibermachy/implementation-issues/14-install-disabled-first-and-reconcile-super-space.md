# 14: Install disabled-first and reconcile Super+Space

**Parent spec:** [Architect Hibermachy for Omarchy Quattro](../spec.md)

**What to build:** The native-first guided setup completes the separately owned plugin, helper, menu, and activation scopes without suppressing trust prompts or applying machine-wide sleep policy.

**Blocked by:** 11: Present coherent operational readiness in an accessible panel; 13: Inventory every lifecycle scope independently.

**Status:** complete

## Completion record (2026-09-07)

- Base preparation: local dependency merge `0af41d9` of ticket 13 commit `a07ae34`; main and source branches were unchanged.
- Ticket commits: `a46f9e2`, `83f2c4f`, `f395ed4`, and `564e74f`.
- Review base: `0af41d9`; `git diff 0af41d9...HEAD --check` passes.
- Focused evidence: `tests/lifecycle_install.sh` and `npm run test:lifecycle-install` pass. The public lifecycle/JSONC fixture seam covers native-review gating, disabled-first setup, owner/scope inventory, helper failure, protocol mismatch, probe failure, exact namespaced Setup/System rows, search aliases, service-availability guards, comment/order preservation, atomic rerun, malformed/collision/modified-menu refusal, declined activation, later activation, partial retention, and no-policy-mutation.
- Existing lifecycle evidence: `npm run test:lifecycle` passes, including independent scope inventory and JSONC object-key compatibility.
- Full relevant suite: `npm test` exits successfully; the hosted Quickshell fixture emits headless-display warnings in this environment. Rust formatting/process tests could not run because no Rust toolchain is installed (`rustup toolchain list` is empty).
- Safety evidence: no live plugin installation, package transaction, system-policy mutation, sleep request, or publication was performed. Native review and interactive authorization remain explicit fixture gates; activation is a separate final confirmation.
- Two-axis review from `0af41d9`: Standards found no documented-standard breach; one non-blocking duplicated-shape judgement call in the JSONC fixture adapter. Spec found no missing or out-of-scope ticket behavior.

- [x] The journey begins after Quattro's native plugin-add review, preserves its unsandboxed-code warning and source-review opportunity, and keeps the checkout disabled during setup.
- [x] Setup discloses the one-installation-owner model, inventories all scopes, verifies Quattro, builds the helper as the unprivileged user, and installs it through normal interactive Arch tooling.
- [x] Structure-aware atomic menu reconciliation adds only the exact namespaced Setup and System entries, preserves unrelated JSONC comments and ordering, and refuses malformed input, identifier collisions, or modified managed entries.
- [x] Sleep & Hibernation opens the panel; Suspend then Hibernate invokes the confirmed manual flow; both entries are searchable by sleep, hibernate, and Hibermachy terms and self-hide without a compatible live service.
- [x] Installation performs compatibility and integration probes, reports incomplete scopes, never applies requested system policy, and offers activation only as a final explicit Quattro-native confirmation.
- [x] Declined activation leaves a complete disabled installation that can be activated later, and cancellation or failure retains completed valid work with an exact inventory suitable for safe rerun.
- [x] Clean setup, declined and later activation, helper failure, protocol mismatch, menu conflict, partial-step interruption, rerun, and no-policy-mutation journeys pass at the lifecycle public seam.
