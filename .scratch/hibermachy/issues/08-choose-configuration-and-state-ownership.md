# Choose configuration and state ownership

Type: grilling
Status: resolved
Blocked by: 04, 05, 07

## Question

Which layer owns each Hibermachy setting and runtime state, how are user-scoped and system-wide values reconciled, and what invariants govern enablement, AC power, unavailable hibernation, manual wake, reload, and concurrent changes?

## Answer

Hibermachy uses distinct owners for activation, durable intent, effective system policy, and live state:

- Omarchy owns **plugin activation** through Hibermachy's presence in `~/.config/omarchy/shell.json`. Hibermachy does not store policy inline there because Quattro 4.0.1 exposes no public reactive settings interface for a `service` + `panel` plugin.
- A versioned Hibermachy document under `$XDG_CONFIG_HOME/hibermachy/` owns the user-scoped **automatic-policy enablement** and **idle delay**. The long-lived service is its sole writer; the panel and IPC clients submit mutations to the service.
- The root-owned `/etc/systemd/sleep.conf.d/90-hibermachy.conf` owns Hibermachy's **requested system policy**: **hibernate delay** as `HibernateDelaySec=` and **Hibernate while plugged in** as `HibernateOnACPower=`. Those values have no duplicate authoritative copy in user configuration.
- Ordered systemd configuration owns the **effective system policy**. Hibermachy reads back both its requested values and the final effective values with source provenance. A successful helper write may therefore coexist with an administrator override; Hibermachy reports that mismatch, identifies the overriding source when possible, and never rewrites or fights it.
- systemd owns every active suspend-then-hibernate interval. Changes made while a cycle is underway apply only to the next request and require no daemon or logind reload.
- logind owns live **sleep executability**, inhibitor, external-power, and sleep-transaction observations. Hibermachy always re-queries these facts; it never restores them from persisted snapshots.
- The coordinator owns its current execution-gate state in memory. The only reload-surviving runtime state is a versioned re-arm latch under `$XDG_RUNTIME_DIR/hibermachy/`; durable outcome history, if any, is left to **Define failure handling and observability** and may never masquerade as current state.

The configuration and state invariants are:

- Plugin activation, automatic-policy enablement, and manual staged sleep are independent. Disabling automatic staged sleep stops idle-triggered requests but does not unload the plugin, erase system-wide policy, or disable the explicit manual action.
- User-policy saves and authenticated system-policy applies are separate commit domains. Each reports its own revision, success, cancellation, conflict, or failure; the UI must never present partial success as one atomic save.
- User-config mutations include the base revision. The service serializes them, atomically replaces a validated document, advances its durable revision only after confirmed persistence, and rejects stale mutations with the current snapshot. A valid external edit becomes a new revision; a missing, malformed, out-of-range, or newer-schema document disarms automatic staged sleep rather than retaining hidden last-known-good values. Manual staged sleep remains available.
- Only one privileged helper request may be in flight. A concurrent apply/reset receives a deterministic busy or conflict result instead of queuing stale intent. The helper's own fixed target remains atomically written and protected by the previously resolved ownership checks.
- `HibernateOnACPower=no` uses systemd's semantics directly for both automatic and manual staged sleep: on a battery-equipped machine, it remains suspended while AC is connected and begins the hibernate countdown only after AC is disconnected. The policy is system-wide and affects every suspend-then-hibernate caller; Hibermachy does not add a competing AC timer or special-case its manual action.
- Every request rechecks capabilities. If hibernation is unavailable, Hibermachy preserves user intent and requested system policy, falls back to ordinary suspend when possible, and resumes staged behavior automatically when capability returns. A held inhibitor is a transient refusal, not configuration loss or proof that hibernation is unavailable.
- The re-arm latch is set before issuing either automatic or manual sleep. A failed request may clear it once failure is known; a request that enters sleep keeps it set after return. Manual wake ends that systemd cycle, and automatic staged sleep cannot run again until the idle monitor observes fresh user activity. Manual requests remain available while latched.
- Service recreation, plugin reload, invalid configuration, and any valid change that enables automation or shortens the idle delay require fresh user activity before automatic staged sleep re-arms. Reload reconstructs durable intent, reads fresh effective policy, re-queries live state, and never recreates an in-memory hibernate countdown or stale busy state.

Exact first-run defaults, schemas, accepted ranges, units, and migration rules are a newly visible decision captured by **Choose configuration defaults and validation rules**.

Research asset: [`docs/research/configuration-and-state-ownership-constraints.md`](../../../docs/research/configuration-and-state-ownership-constraints.md).

## Comments

Resolved with the user over three grilling rounds. The user accepted every recommended ownership and invariant, then confirmed the consolidated model as shared understanding.
