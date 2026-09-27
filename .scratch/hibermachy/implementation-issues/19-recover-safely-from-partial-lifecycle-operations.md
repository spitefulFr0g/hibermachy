# 19: Recover safely from partial lifecycle operations

**Parent spec:** [Architect Hibermachy for Omarchy Quattro](../spec.md)

**What to build:** Supported recovery uses the public lifecycle inventory and native tools to finish or safely rerun interrupted setup, update, removal, uninstall, and purge without hidden rollback or unsafe guesses.

**Blocked by:** 15: Update while preserving prior activation intent; 16: Disable or remove the plugin without claiming uninstall; 18: Purge retained user data last.

**Status:** complete

- [x] Every mutating lifecycle step records enough externally observable completion state for a later invocation to inventory and continue safely without replaying already valid work.
- [x] A missing checkout can be re-added compatibly and disabled before uninstall or purge recovery, preserving Quattro's native source-review boundary.
- [x] A missing helper with recognized requested policy can be rebuilt and reinstalled compatibly before authenticated validated reset and removal.
- [x] Protocol mismatch, menu collision, modified managed entry, suspicious requested policy, and unrecognized shared state remain visible and untouched until explicitly resolved.
- [x] Recovery never performs automatic downgrade, cross-scope rollback, root bypass, policy overwrite, shared-menu overwrite, or destructive cleanup outside a confirmed operation.
- [x] Cancellation or failure after every cross-scope step, incomplete native removal, helper-only removal, policy-only residue, activation restoration, re-add, reinstall, and repeated recovery journeys converge to an accurate stable inventory.

## Evidence

- Implemented in commit `997d3b4` (`feat: recover partial lifecycle operations`), based on `013b079`.
- Added durable `lifecycle-state.json` phases and public inventory reporting; reviewed native checkout re-add, helper reinstall, protocol overlap, ownership, menu, policy, update, disable/remove, uninstall, and purge boundaries.
- Deterministic fixture evidence: `npm run test:lifecycle`, `npm run test:lifecycle-install`, `npm run test:lifecycle-uninstall`, and `npm run test:lifecycle-recovery` all pass. The new checks are `HBR-CHK-LIFECYCLE-008` (partial recovery) and `HBR-CHK-LIFECYCLE-009` (interrupted update continuation). Also passed `node --check` for lifecycle Node tools, `bash -n` for lifecycle shell tools, and `git diff --check`.
- Two-axis review against `013b079`: Standards — no documented standards source was present and no hard standards breach found; local smell review found no blocking finding. Spec — all six acceptance criteria are covered; no scope creep or incorrect required behavior found.
- Full `npm test` was attempted but stops at the existing Quickshell-hosted gate because this headless environment cannot create `/run/user/1000` runtime paths or initialize Wayland/X11. `cargo test --locked` was attempted but rustup has no configured default toolchain.
- Safety constraints honored: all lifecycle mutations used disposable fixture roots and native-tool confirmation fixtures. No real sleep, privilege/policy write, package/plugin operation, destructive host deletion, publication, push, merge, or worker delegation was performed.
