# 16: Disable or remove the plugin without claiming uninstall

**Parent spec:** [Architect Hibermachy for Omarchy Quattro](../spec.md)

**What to build:** Disablement and plugin removal delegate to Quattro, preserve their explicitly out-of-scope artifacts, and disclose any surviving machine-wide requested policy without calling the result a Hibermachy uninstall.

**Blocked by:** 14: Install disabled-first and reconcile Super+Space.

**Status:** complete

## Completion record (2026-09-07)

- Commit: `82d0a03` (`feat: add native delegated plugin disablement and removal`), based on review point `564e74f`.
- Focused evidence: `node --check lifecycle/remove`, `npm run test:lifecycle`, and `npm run test:lifecycle-install` all pass. The lifecycle fixture seam covers accepted disablement, accepted plugin-only removal, native cancellation, partial removal, rerun, active/disabled state, helper/user/policy preservation, exact surviving inventory, machine-wide policy warnings, modified-menu preservation, and live-service menu guards.
- Full-suite evidence: `npm test` was attempted; lifecycle suites are covered above, while the existing Quickshell-hosted suite cannot initialize Wayland/X in this sandbox (`Failed to create wl_display`, Qt platform initialization failure), so npm exits 1 before hosted assertions. No Rust toolchain is configured in the environment.
- Two-axis review: `git diff 564e74f...HEAD --check` passes. Standards review found no documented-standard breach or remaining baseline smell after renaming the vague result helper and deduplicating the live-menu fixture. Spec review found no missing or out-of-scope ticket behavior.
- Safety evidence: no real checkout, package transaction, plugin operation, sleep request, host system-policy write, publication, push, merge, or additional worker was performed; all lifecycle mutations were confined to disposable fixtures and native confirmation fixtures.

- [x] Disablement unloads service and panel while preserving checkout, menu contribution, user configuration/state, helper package, and effective system policy.
- [x] Plugin removal disables first and removes only the user-owned checkout through Quattro, preserving the helper, user data, menu conflict state, and requested system policy.
- [x] Both operations report the exact surviving lifecycle inventory and clearly warn when machine-wide requested policy remains effective.
- [x] Menu rows become non-actionable through their compatible-live-service condition even when recognized menu entries remain after disablement or plugin removal.
- [x] Active, disabled, policy-present, helper-present, partial-removal, modified-menu, and rerun journeys verify the distinction among automatic-policy disablement, plugin disablement, plugin removal, and full uninstall.
