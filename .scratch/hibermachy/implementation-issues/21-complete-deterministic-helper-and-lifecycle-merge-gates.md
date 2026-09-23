# 21: Complete deterministic helper and lifecycle merge gates

**Parent spec:** [Architect Hibermachy for Omarchy Quattro](../spec.md)

**What to build:** The public helper-process and lifecycle-command seams receive deterministic adversarial, packaging, concurrency, and partial-state verification suitable for ordinary non-privileged CI.

**Blocked by:** 19: Recover safely from partial lifecycle operations.

**Status:** complete

**Claimed by:** impl/21-helper-lifecycle-merge-gates

- [x] Helper input property/fuzz tests cover malformed, missing, extra, oversized, Unicode, signed, fractional, overflow, boundary, forged protocol, and incompatible protocol cases.
- [x] Isolated filesystem fault tests cover symlinks, hard links, ownership, permissions, object types, parent substitution, concurrent mutation, interrupted writes/removals, hostile environment, unexpected descriptors, and unchanged-outside-target rejection.
- [x] Lifecycle fixtures cover setup, activation decisions, update, protocol mismatch, menu collision/modification, disablement, plugin removal, uninstall, purge, every cross-scope interruption, and supported re-add/reinstall recovery.
- [x] Packaging checks validate recipes, source signature/checksum behavior, unprivileged builds, dependencies, generated policy/package content, ownership, modes, and package reset behavior without changing the CI host.
- [x] Sleep calls, Polkit, package operations, shared user state, and destructive lifecycle actions are intercepted by exact public-boundary fixtures; untrusted contributions cannot access reusable privilege or publication credentials.
- [x] Stable check identifiers and evidence prove deterministic results, safe rerun, and no change outside owned scopes without asserting helper internals or free-form diagnostic wording.

**Completion evidence:** Commit `5e1de28` (`test: complete helper and lifecycle merge gates`) adds public helper process-gate cases `HBR-CHK-HELPER-001` through `HBR-CHK-HELPER-004`, packaging gates `HBR-CHK-PACKAGING-001` through `HBR-CHK-PACKAGING-003`, and an uninstall disablement interruption fixture. Focused lifecycle, packaging, JavaScript, shell, and `git diff --check` validation passed. The two-axis review against `997d3b4` found no standards or ticket-scope findings.

**Validation constraints:** `npm test` reaches the existing Quickshell-hosted gate, which reports that `/run/user/1000` and Wayland/X11 are unavailable in this headless environment; the disposable lifecycle and packaging gates pass independently. `cargo test --locked --features test-support --test helper_merge_gate --test apply_process` and `cargo fmt --all -- --check` could not run because rustup has no configured Rust toolchain. No real sleep, Polkit authorization, package/plugin operation, shared user mutation, destructive host operation, publication, merge, push, or worker delegation was performed.
