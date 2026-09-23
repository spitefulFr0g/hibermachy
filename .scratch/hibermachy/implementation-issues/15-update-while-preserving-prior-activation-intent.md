# 15: Update while preserving prior activation intent

**Parent spec:** [Architect Hibermachy for Omarchy Quattro](../spec.md)

**What to build:** A guided, rerunnable update transfers control across independently versioned plugin and helper artifacts while preserving the user's prior activation intent and reporting partial completion honestly.

**Blocked by:** 14: Install disabled-first and reconcile Super+Space.

**Status:** complete

- [x] Update records prior activation and disables an active plugin before invoking Quattro's reviewed fast-forward operation without automatic acceptance.
- [x] The updated lifecycle interface resumes control, builds and upgrades the helper from the new immutable signed/checksummed source, reconciles recognized menu entries, and reruns protocol and integration probes.
- [x] Prior activation is restored only after required update steps succeed; a previously disabled plugin remains disabled.
- [x] Cancellation or failure retains completed valid cross-scope work, reports exact surviving state, and performs no automatic downgrade, destructive rollback, or mutation replay.
- [x] Active, disabled, protocol-mismatch, helper-build, package-authorization, menu-conflict, probe-failure, interrupted-step, and safe-rerun journeys are verified through the public lifecycle command.

## Comments

- Implemented in commit `5d2b97b562e4f6a89eac4d3b1b49dc7647fa668d` (`feat: preserve activation intent across updates`), based on `564e74fb6c4a195e0cc061ec7328a357a38e5b5a`.
- Public lifecycle evidence: `npm run test:lifecycle` (HBR-CHK-LIFECYCLE-001/002/003/004/005), `npm run test:lifecycle-install` (HBR-CHK-LIFECYCLE-006), `npm run test:lifecycle-update` (HBR-CHK-LIFECYCLE-007); all passed. Also passed `node --check lifecycle/install`, `bash -n lifecycle/status tests/lifecycle_update.sh`, and `git diff --check`.
- Two-axis review of `git diff 564e74f...HEAD`: Standards — no documented standards violations; no actionable smell finding. Spec — no missing, partial, or scope-creep finding against ticket 15. Fixed point resolved and diff was non-empty.
- Full `npm test` reached the pre-existing Quattro-hosted test but could not start Quickshell in this headless worktree (no Wayland/X11 display and unavailable `/run/user/1000` runtime paths). `cargo test --locked` could not start because rustup has no configured default toolchain. No real sleep, package transaction, plugin operation, host policy write, or publication was performed.
