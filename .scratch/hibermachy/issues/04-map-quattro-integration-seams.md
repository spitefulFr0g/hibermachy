# Map Quattro integration seams

Type: research
Status: resolved
Blocked by:

## Question

Which documented Omarchy 4.0.1 Quattro plugin, shell configuration, menu-extension, IPC, idle-monitoring, inhibitor, and reload seams can Hibermachy safely depend on, and which tempting seams are private or unstable?

## Answer

Use a main third-party plugin with `service` and `panel` kinds, a public Quickshell `IdleMonitor` with `respectInhibitors: true`, a final public `omarchy toggle idle status` check, panel summon through `omarchy-shell`, plugin-owned IPC, and explicit user menu-extension rows. Do not distribute an `omarchy.idle` clone or depend on private idle objects, the Stay Awake state-file path, `bar.shell`, or private shell mutation methods.

Quattro has no public subscription to the built-in idle cycle, so an independent monitor is the stable v1 seam; exact screensaver-aware timing would require an upstream contract or private adapter. Global plugin reload destroys and recreates all plugin objects, so durable state must be persisted and the suspended interval delegated to systemd. A same-id bar widget cannot be removed while keeping its service enabled, so the main plugin should remain `service` + `panel` and use the accepted Super+Space entry points.

Research context: branch `research/quattro-integration-seams`, commit `e2ac62d`, report `docs/research/quattro-integration-seams.md`.
