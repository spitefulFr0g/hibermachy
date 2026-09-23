# 13: Inventory every lifecycle scope independently

**Parent spec:** [Architect Hibermachy for Omarchy Quattro](../spec.md)

**What to build:** A read-only checkout-local lifecycle status reports every independently owned Hibermachy scope and the exact recovery implications of partial state.

**Blocked by:** 01: Load Hibermachy safely as a disabled-first Quattro plugin; 04: Package and authenticate the privileged policy helper.

**Status:** complete

## Completion record (2026-09-07)

- Base preparation: local dependency merge `f147fd1` (`ec315a1` merged with existing branch history); main and source branches were unchanged.
- Ticket commits: `de987b5`, `5c5449f`, `4b574e6`, `d7360da`, `a500aac`, `1c6e41d`, `4eed4e8`, and `a07ae34`.
- Review base: `f147fd1`; `git diff f147fd1...HEAD --check` passes and `git log f147fd1..HEAD --oneline` contains only the ticket commits.
- Focused evidence: `tests/lifecycle_status.sh` and `npm run test:lifecycle` pass. The seam covers clean, disabled, active, plugin-only-removed, helper-only, policy-only, protocol mismatch, menu collision, retained user data, unrecognized shared state, custom policy, JSONC comments, malformed/incomplete, inaccessible, modified, and stable reason-code inventories.
- Existing helper/package evidence: `cargo fmt -- --check` and `cargo test --features test-support` pass (23 tests: 19 helper process tests and 4 packaging contract tests).
- Full suite evidence: escalated `npm test` passes the Quattro-hosted plugin checks and lifecycle checks with normal disposable display access. The initial failure was diagnosed from the exact host log (`IpcHandler is not a type`, then `Cannot assign to non-existent default property`) and fixed minimally by importing `Quickshell.Io` and changing the inherited service root to `Item` in `a07ae34`; this did not import unrelated changes from `a97d578`.
- Safety evidence: no real sleep, package transaction, or host system-policy mutation was performed.
- Two-axis review after `a07ae34`: no documented standards violations; one non-blocking duplicated-code judgement call in shared policy-target probing. The Spec axis found no lifecycle-inventory gap; it noted the two-line `Service.qml` load fix as scope-adjacent, which was explicitly authorized by the request to complete the inherited full-suite validation and was limited to the required host-boundary defect.

- [x] Status reports checkout, activation, menu contribution, helper package, helper protocol, user configuration/state, requested system policy, and owned target independently rather than collapsing them into installed or healthy.
- [x] The inventory identifies the installation owner and clearly distinguishes that user's artifacts from machine-wide helper and requested-policy scopes.
- [x] Compatible, missing, mismatched, modified, colliding, inaccessible, and incomplete states produce stable actionable results without changing any scope.
- [x] Plugin activation, automatic-policy enablement, plugin removal, Hibermachy uninstall, and purge use the repository glossary meanings and cannot be confused in output.
- [x] Lifecycle-command seam tests cover clean, disabled, active, plugin-only-removed, helper-only, policy-only, protocol-mismatch, menu-conflict, retained-user-data, and unrecognized shared-state inventories.
