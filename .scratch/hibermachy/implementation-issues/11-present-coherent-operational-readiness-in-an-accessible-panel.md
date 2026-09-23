# 11: Present coherent operational readiness in an accessible panel

**Parent spec:** [Architect Hibermachy for Omarchy Quattro](../spec.md)

**What to build:** A compact native single-sheet panel consumes the service's coherent snapshot and makes every working, blocked, fallback, draft, confirmation, and recovery path understandable and operable.

**Blocked by:** 10: Trigger automatic staged sleep only after fresh activity.

**Status:** complete

- [x] The panel follows the approved hero, Automatic staged sleep, System policy, Current status, and secondary manual-action hierarchy with native Quattro styling and vertical scrolling.
- [x] Automatic, manual, system-policy, and diagnostics readiness are shown independently; the hero applies the approved precedence without turning disabled automation or diagnostic degradation into global failure.
- [x] User intent, requested system policy, effective system policy and provenance, current sleep executability, Stay Awake, fallback, re-arm state, and active blocker remain distinct.
- [x] Friendly idle-delay and hibernate-delay presets are offered, while valid custom whole-second values remain exact and are not rewritten merely by opening the panel.
- [x] Manual, apply, reset, invalid-policy reset, and history-reset confirmations state their actual consequence and cancellation path without bypassing ownership or safety boundaries.
- [x] Forward and reverse keyboard navigation, focus restoration, Escape and cancellation, dirty and disabled states, authentication return, accessible names/states, status announcements, enlarged scaling, contrast variation, and non-color distinctions are verifiable.
- [x] Hosted journeys prove the panel and adapters never reimplement eligibility, fallback selection, inhibitor evaluation, evidence reconciliation, or system-policy writes outside their owning service/helper modules.

## Implementation evidence

- Final commits: `ee6db5eefc077d548b0fbbba9ea4e7af0aab1d1d` and `0e827b68c215b1838276426c0917655995a21c66`, based on `b8b9e19dc80c21863f018eae1d131b2de597aa8e`.
- Hosted validation passed: `QT_QPA_PLATFORM=wayland WAYLAND_DISPLAY=wayland-1 XDG_RUNTIME_DIR=/run/user/1000 npm test` (full normal, fallback/inhibitor/outcome, and high-contrast 1.5x matrix).
- AT-facing hosted validation passed: `HIBERMACHY_MATRIX_CASE=1 HBR_TEST_THEME=high-contrast HBR_TEST_SCALE=1.5 QT_LINUX_ACCESSIBILITY_ALWAYS_ON=1 QT_QPA_PLATFORM=wayland WAYLAND_DISPLAY=wayland-1 XDG_RUNTIME_DIR=/run/user/1000 npm run test:quattro-hosted`.
- Affected Rust validation passed with temporary toolchain/fixture scope: `env RUSTUP_HOME=/tmp/hibermachy-rustup-final CARGO_HOME=/tmp/hibermachy-cargo-final HIBERMACHY_TEST_ROOT=/tmp/hibermachy-policy-root cargo fmt --all -- --check` and `... cargo test --features test-support`: 20 `apply_process` tests and 4 `packaging_contract` tests passed. Generated `target/` and fixture state were removed afterward.
- `git diff --check` and `bash -n tests/quattro-hosted-plugin.sh` passed. `qmlformat`/`qmllint` were not installed in the host; the hosted Quattro runtime loaded every QML path and the matrix passed.
- Hosted proof covers native focusable confirmation controls, keyboard selection/cancellation, focus restoration, Accessible names/descriptions/announcements, enlarged scaling, high contrast, non-color status text, and service/helper-owned readiness, fallback, inhibitor, evidence, and privileged-write seams. No real sleep, package operation, or live policy mutation was performed.
- Two-axis review evidence: Standards review reported no actionable findings. Spec review identified confirmation keyboard/focus/AT gaps; those were fixed in `0e827b6`, then the targeted journey, full matrix, accessibility-bridge run, Rust suite, and final diff checks passed. The final worktree is clean.
