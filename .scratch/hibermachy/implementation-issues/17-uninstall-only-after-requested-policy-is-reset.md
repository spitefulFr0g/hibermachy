# 17: Uninstall only after requested policy is reset

**Parent spec:** [Architect Hibermachy for Omarchy Quattro](../spec.md)

**What to build:** Full Hibermachy uninstall removes machine-wide and user-owned executable artifacts only after recognized requested system policy has been authenticated, reset, and verified absent.

**Blocked by:** 14: Install disabled-first and reconcile Super+Space.

**Status:** complete (impl/17-reset-before-uninstall)

- [x] Uninstall discloses installation-owner and machine-wide scope, disables the plugin, and invokes a fresh authenticated recognized-policy reset before package or checkout removal.
- [x] Authentication cancellation, reset refusal, reset failure, or indeterminate absence stops uninstall before removing the helper and reports exact surviving state.
- [x] After verified reset, uninstall removes the helper through the package manager, verifies helper and owned-policy absence, removes only recognized menu entries, and removes the checkout last.
- [x] User configuration and outcome history remain available for a later reinstall and are reported as retained rather than accidentally presented as complete cleanup.
- [x] Package-scriptlet defense-in-depth does not weaken the explicit lifecycle reset rule or cause scriptlet failure to be mistaken for package-transaction failure.
- [x] Clean, cancelled, denied, suspicious-policy, package-failure, modified-menu, missing-checkout, interrupted-step, retained-data, and rerun journeys verify ordering and preservation at the lifecycle seam.

## Evidence

- Commit: `d3b3e18` (`feat: reset requested policy before uninstall`); worktree clean.
- Passed: `tests/lifecycle_uninstall.sh` (`HBR-CHK-LIFECYCLE-007`), `npm run test:lifecycle`, `npm run test:lifecycle-install`, `node --check lifecycle/install`, `bash -n lifecycle/uninstall tests/lifecycle_uninstall.sh`, and `git diff --check`.
- `cargo test --all-targets` was attempted but this environment has no configured Rust toolchain (`rustup could not choose a version of cargo`). Full `npm test` was attempted; its Quickshell-hosted portion exits nonzero because Wayland/X11 cannot initialize in this headless environment.
- Two-axis review against `564e74f`: Standards — no documented-rule violations; one lifecycle-function-size baseline smell was a judgment call. Spec — all ticket acceptance criteria covered; no scope creep or incorrect required behavior found.
