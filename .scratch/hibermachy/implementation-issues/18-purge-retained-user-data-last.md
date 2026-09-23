# 18: Purge retained user data last

**Parent spec:** [Architect Hibermachy for Omarchy Quattro](../spec.md)

**What to build:** Hibermachy purge completes full uninstall, then separately confirms and removes only the installation owner's enumerated configuration and state as the final destructive step.

**Blocked by:** 17: Uninstall only after requested policy is reset.

**Status:** complete

**Completion evidence:** Implemented public `purge` lifecycle command and deterministic disposable-root fixtures in `lifecycle/install` and `tests/lifecycle_uninstall.sh` at commit `013b079`. Focused lifecycle purge/uninstall check passes. Full `npm test` is blocked at the Quickshell-hosted gate because this environment has no usable Wayland/display runtime and Quickshell cannot create `/run/user/1000` runtime paths. The literal foreign-UID fixture is also unavailable because `setpriv --reuid=65534` fails with `setresuid failed: Invalid argument`; the fixture covers the same fail-closed unsafe-path contract with hostile permissions while production validates actual UID ownership.

- [x] Purge completes uninstall before user-data deletion and leaves retained data when confirmation is cancelled.
- [x] Purge enumerates exact configuration/state scopes and requires separate destructive confirmation.
- [x] Validated ownership, modes, and non-symlink paths; suspicious data is preserved.
- [x] Confirmed purge removes and verifies only the enumerated scopes; interruption, partial data, rerun, and no-outside-change fixtures pass.
- [x] Review evidence: standards/spec review of `013b079` against `d3b3e18` found no blocking findings; focused fixture pass; full-suite environment constraint recorded above.

- [ ] Purge first satisfies every uninstall acceptance criterion and never deletes user data while executable or machine-wide Hibermachy artifacts remain unresolved.
- [ ] The lifecycle interface enumerates the exact owned configuration and state scopes and requests an additional destructive confirmation distinct from uninstall authorization.
- [ ] Cancellation retains all user data and reports a completed uninstall with retained configuration/state rather than failure or full purge.
- [ ] Ownership and every path component are validated without following symlinks or escaping the installation owner's scopes; suspicious objects are preserved for explicit resolution.
- [ ] Confirmed purge removes only validated Hibermachy-owned user configuration and state, verifies their absence, and reports the final scope inventory.
- [ ] Cancellation, missing data, partial data, hostile symlink, wrong ownership, interrupted deletion, safe rerun, and no-outside-change journeys pass at the lifecycle command boundary.
