# Choose the plugin runtime architecture

Type: grilling
Status: resolved
Blocked by: 04, 05

## Question

Should Hibermachy extend, replace, or coordinate with Quattro's built-in idle service, and what smallest runtime interface keeps idle detection, Stay Awake, inhibitors, locking, and systemd staged sleep coherent?

## Answer

Hibermachy coordinates with Quattro; it neither extends nor replaces `omarchy.idle`. Its main plugin contains a long-lived `service` and a settings `panel`. The service owns an independent Quickshell `IdleMonitor` with `respectInhibitors: true` and a private, deep staged-sleep coordinator. The panel and menu remain thin adapters and never invoke `systemctl`, inspect inhibitors, or choose fallback behavior themselves.

The coordinator has two entry paths into one execution gate:

- Idle expiry is an internal automatic request. Immediately before acting, it checks Omarchy's public Stay Awake status. Wayland idle inhibitors suppress the monitor through `respectInhibitors`; Stay Awake suppresses the final request.
- The public `requestStagedSleep()` command is an explicit manual request. It bypasses Stay Awake and compositor idle inhibition because the user deliberately requested the action, but it does not bypass system/logind sleep inhibitors.

Both paths use the same capability and fallback policy. If logind reports `CanSuspendThenHibernate=yes`, the coordinator requests `systemctl suspend-then-hibernate`. Otherwise, if `CanSuspend=yes`, it requests ordinary suspend and reports the degraded result. If neither operation is available, it does nothing and reports why. It never passes an inhibitor-override flag.

Hibermachy does not issue a separate lock command. Omarchy's existing pre-suspend lock integration remains the sole owner of locking for logind sleep transitions, avoiding duplicate lock calls and ordering races. Systemd owns the suspended interval and eventual hibernation; the Quickshell service does not maintain a second hibernate timer.

The v1 sleep-control surface contains only:

- one mutating IPC command, `requestStagedSleep()`, whose caller cannot select or spoof the request origin; and
- one read-only status snapshot for the panel and diagnostics, containing coordinator state, reason, and detected sleep capabilities.

Idle expiry, capability selection, Stay Awake evaluation, and fallback remain private. Configuration mutation and persistence are specified separately by the configuration-and-state ticket, not added as alternate sleep-control commands. A Quattro plugin reload recreates the service and monitor from durable configuration; it cannot disturb a suspend-to-hibernate interval already delegated to systemd.

Because the idle monitor is independent, lock-screen or screensaver-generated activity can shift its deadline slightly relative to Omarchy's built-in idle cycle. V1 accepts and documents that bounded timing drift rather than coupling to private idle objects or copying `omarchy.idle`. Exact cross-service alignment would require a future public Omarchy hook.
