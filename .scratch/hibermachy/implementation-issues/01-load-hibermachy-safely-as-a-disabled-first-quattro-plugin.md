# 01: Load Hibermachy safely as a disabled-first Quattro plugin

**Parent spec:** [Architect Hibermachy for Omarchy Quattro](../spec.md)

**What to build:** A public Quattro plugin that loads a long-lived Hibermachy service and native panel, exposes one coherent read-only status snapshot, and remains inert when automatic staged sleep has not been configured.

**Blocked by:** None (can start immediately).

**Status:** complete

**Commit:** `ec315a1 feat: add disabled-first Hibermachy Quattro plugin`

**Validation evidence:** `npm test` passed. It runs the disposable Quattro-hosted lifecycle seam with an isolated temporary home and the public Quattro IPC contracts. Stable checks `HBR-CHK-PLUGIN-001` through `HBR-CHK-PLUGIN-006` cover disabled-first discovery, explicit activation while automatic staged sleep remains disabled, summon/hide, reload/recreation, disablement, and recreation after re-enablement; the test does not perform real sleep or privileged host mutation.

**Code-review evidence:** Standards review reported 0 findings. Spec review found the initial structural test and lifecycle ordering incomplete; the implementation replaced the structural test with the hosted seam, starts disabled, explicitly activates, and verifies the inert snapshot after reload and recreation. A final review found the missing stable check identifiers; `HBR-CHK-PLUGIN-001` through `HBR-CHK-PLUGIN-006` were then added.

- [x] Quattro can discover, activate, reload, summon, disable, and recreate the service-and-panel plugin through documented public contracts.
- [x] The initial panel and status snapshot distinguish plugin activation from automatic-policy enablement and report that no automatic power action is ready.
- [x] Loading, activating, opening, refreshing, reloading, or disabling the plugin cannot submit sleep, write system policy, or duplicate Omarchy's locking behavior.
- [x] The plugin declares no same-id bar widget and does not depend on private idle objects, private Stay Awake storage, private shell mutation APIs, or an `omarchy.idle` clone.
- [x] A disposable Quattro-hosted test seam verifies the behavior without real sleep or privileged host mutation and assigns stable check identifiers to this slice.
