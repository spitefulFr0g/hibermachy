# Hibermachy requirement verification matrix

This matrix is the release-gate index for the 76 normative user stories in
`.scratch/hibermachy/spec.md`. `OBS` is used only where the requirement is a
bounded claim about an external platform or an attended gate; it is not a
substitute for a missing automated check. The merge gate rejects an unchecked
or ambiguous row.

| ID | Requirement | Gate layer | Applicability | Required environment | Expected evidence |
| --- | --- | --- | --- | --- | --- |
| HBR-REQ-001 | Automatic staged sleep follows idle then suspended intervals | product | always | disposable Quattro/Wayland | public receipt and selected submission |
| HBR-REQ-002 | Idle and hibernate delays are described as sequential periods | product | always | disposable Quattro/Wayland | panel text and status snapshot |
| HBR-REQ-003 | First activation leaves automation disabled | product/lifecycle | always | disposable profile | activation and policy fixtures |
| HBR-REQ-004 | Automatic enablement is independent of plugin activation | product/lifecycle | always | disposable profile | status and lifecycle inventory |
| HBR-REQ-005 | Disabling automation preserves other policy values | product | always | disposable Quattro/Wayland | durable policy readback |
| HBR-REQ-006 | Automatic requests respect compositor idle inhibitors | product | always | disposable Quattro/Wayland | refusal receipt |
| HBR-REQ-007 | Automatic requests respect Stay Awake | product | always | disposable Quattro/Wayland | suppression reason |
| HBR-REQ-008 | Manual requests bypass Stay Awake and compositor inhibition | product | always | disposable Quattro/Wayland | accepted manual receipt |
| HBR-REQ-009 | Manual requests honor system sleep inhibitors | product | always | disposable Quattro/Wayland | refusal receipt |
| HBR-REQ-010 | Ordinary suspend and lid behavior remain unchanged | product/hardware | always | disposable Quattro + attended machine | unchanged adapter and hardware evidence |
| HBR-REQ-011 | Omarchy remains the sole pre-suspend lock owner | product | always | disposable Quattro/Wayland | no lock command and typed evidence |
| HBR-REQ-012 | Manual action is present in the System submenu | product | always | disposable Quattro/Wayland | public menu inventory |
| HBR-REQ-013 | Settings are present in the Setup submenu | product | always | disposable Quattro/Wayland | public menu inventory |
| HBR-REQ-014 | Both menu entries have sleep/hibernate search terms | product/lifecycle | always | disposable profile | menu fixture aliases |
| HBR-REQ-015 | Stale menu entries hide when service is unavailable | lifecycle/product | always | disposable profile | removal inventory |
| HBR-REQ-016 | Panel is a compact native Quattro sheet | product/accessibility | always | disposable Quattro/Wayland | hosted panel journey |
| HBR-REQ-017 | Keyboard operates panel, confirmation, and cancellation | accessibility | always | disposable Quattro/Wayland | keyboard journey |
| HBR-REQ-018 | Status remains semantic under scaling and contrast | accessibility | always | disposable Quattro/Wayland | high-contrast scaled journey |
| HBR-REQ-019 | Draft edits commit only from their owning section | product | always | disposable Quattro/Wayland | mutation receipts |
| HBR-REQ-020 | User policy saves need no authentication | product | always | disposable Quattro/Wayland | accepted unprivileged save |
| HBR-REQ-021 | System-wide hibernate settings are clearly labeled | product/accessibility | always | disposable Quattro/Wayland | panel status |
| HBR-REQ-022 | Every system mutation needs fresh authentication | helper/lifecycle | always | disposable VM | authorization fixture |
| HBR-REQ-023 | Apply review shows delay and AC behavior together | product/helper | always | disposable Quattro + helper fixture | review envelope |
| HBR-REQ-024 | Authentication cancellation preserves requested policy | helper/lifecycle | always | disposable VM | cancellation inventory |
| HBR-REQ-025 | Reset removes only recognized requested policy | helper/lifecycle | always | disposable VM | outside-target sentinel |
| HBR-REQ-026 | Manual staged sleep requires confirmation | product/accessibility | always | disposable Quattro/Wayland | confirmation journey |
| HBR-REQ-027 | Confirmation identifies staged or suspend fallback | product/accessibility | always | disposable Quattro/Wayland | confirmation text |
| HBR-REQ-028 | Presets and custom durations preserve valid values | product | always | disposable Quattro/Wayland | policy readback |
| HBR-REQ-029 | Hibernation on AC is disabled by default | product/helper | always | disposable profile + helper fixture | default policy evidence |
| HBR-REQ-030 | Missing or invalid system policy leaves intent not ready | product | always | disposable Quattro/Wayland | readiness snapshot |
| HBR-REQ-031 | Automation requires fresh activity after re-arm events | product | always | disposable Quattro/Wayland | controlled activity journey |
| HBR-REQ-032 | Manual actions remain available while latch is set | product | always | disposable Quattro/Wayland | manual receipt and status |
| HBR-REQ-033 | Hibernation unavailability preserves intent and policy | product | always | disposable Quattro/Wayland | fallback status |
| HBR-REQ-034 | Suspend fallback is used when staged sleep is unavailable | product | always | disposable Quattro/Wayland | selected mode |
| HBR-REQ-035 | Hibernation unavailability gives native remediation guidance | product | always | disposable Quattro/Wayland | readiness guidance |
| HBR-REQ-036 | No request is made when no mode is executable | product | always | disposable Quattro/Wayland | zero submission count |
| HBR-REQ-037 | Later administrator policy remains authoritative | helper | always | disposable VM | effective readback provenance |
| HBR-REQ-038 | Requested and effective policy are distinct | product/helper | always | disposable Quattro + helper fixture | status comparison |
| HBR-REQ-039 | Capabilities and inhibitors are re-observed live | product | always | disposable Quattro/Wayland | observation transitions |
| HBR-REQ-040 | Mid-cycle changes apply only to the next request | product | always | disposable Quattro/Wayland | active-cycle receipt |
| HBR-REQ-041 | Revision conflicts reject stale panel mutations | product | always | disposable Quattro/Wayland | stale revision receipt |
| HBR-REQ-042 | Invalid/newer policy is preserved and fails closed | product | always | disposable Quattro/Wayland | permanent policy fixtures |
| HBR-REQ-043 | Explicit reset recovers invalid user policy | product | always | disposable Quattro/Wayland | reset receipt and defaults |
| HBR-REQ-044 | Migrations are explicit, sequential, and intent-preserving | product | always | disposable Quattro/Wayland | schema fixtures |
| HBR-REQ-045 | Manual sleep has no configuration side effect | product | always | disposable Quattro/Wayland | policy hash before/after |
| HBR-REQ-046 | Panel and diagnostics use one coherent snapshot | product | always | disposable Quattro/Wayland | matching public snapshots |
| HBR-REQ-047 | IPC manual request returns immediately | product | always | disposable Quattro/Wayland | typed receipt |
| HBR-REQ-048 | Accepted receipt identifies attempt and mode | product | always | disposable Quattro/Wayland | receipt correlation fields |
| HBR-REQ-049 | Outcomes distinguish suppression/refusal/degradation/failure/indeterminate/completed | product | always | disposable Quattro/Wayland | event envelopes |
| HBR-REQ-050 | Successful transaction is not hibernation confirmation | product | always | disposable Quattro/Wayland | evidence level |
| HBR-REQ-051 | Sleep and privileged mutations are never replayed | product/helper | always | disposable Quattro + VM | reload/recovery fixtures |
| HBR-REQ-052 | Suppression is quiet and faults are deduplicated | product | always | disposable Quattro/Wayland | notification fingerprints |
| HBR-REQ-053 | Outcome history is bounded and not live state | product | always | disposable Quattro/Wayland | accelerated soak bounds |
| HBR-REQ-054 | Diagnostics are sanitized and deterministic | product | always | disposable Quattro/Wayland | redaction assertions |
| HBR-REQ-055 | Four readiness surfaces report independently | product | always | disposable Quattro/Wayland | status readiness fields |
| HBR-REQ-056 | Reload finalizes open attempts indeterminate and retains latch | product | always | disposable Quattro/Wayland | reload journey |
| HBR-REQ-057 | Prior-boot open attempts are indeterminate | product | always | disposable Quattro/Wayland | seeded history fixture |
| HBR-REQ-058 | First install preserves review warning and disables plugin | lifecycle | always | disposable profile | setup inventory |
| HBR-REQ-059 | Helper build uses immutable signed source and package manager | packaging/lifecycle | always | disposable Arch fixture | packaging contract |
| HBR-REQ-060 | Activation follows lifecycle and compatibility probes | lifecycle | always | disposable profile | activation journey |
| HBR-REQ-061 | Installation never applies system policy | lifecycle | always | disposable profile | untouched policy sentinel |
| HBR-REQ-062 | Helper/plugin versions require protocol overlap | helper/lifecycle | always | disposable fixtures | mismatch inventory |
| HBR-REQ-063 | Lifecycle inventories every independent scope | lifecycle | always | disposable profile | status JSON |
| HBR-REQ-064 | Lifecycle operations are safe to rerun after partial failure | lifecycle | always | disposable profile | interruption and rerun |
| HBR-REQ-065 | Disablement, removal, and uninstall remain distinct | lifecycle | always | disposable profile | scope outcomes |
| HBR-REQ-066 | Uninstall resets policy before helper or checkout removal | lifecycle/helper | always | disposable profile | ordered event envelope |
| HBR-REQ-067 | Purge is separately confirmed and enumerates data | lifecycle | always | disposable profile | purge scopes |
| HBR-REQ-068 | Colliding or modified menu entries are preserved | lifecycle | always | disposable profile | unchanged menu fixture |
| HBR-REQ-069 | Reinstall-then-reset recovery is supported | lifecycle/helper | always | disposable profile | recovery journey |
| HBR-REQ-070 | One installation owner and machine-wide policy are disclosed | lifecycle | always | disposable profile | status glossary |
| HBR-REQ-071 | Ordinary verification simulates sleep and privileged writes | cross-seam | always | ordinary CI | no-host-mutation gate |
| HBR-REQ-072 | Every normative requirement has named traceability | traceability | always | ordinary CI | this matrix and gate output |
| HBR-REQ-073 | One immutable candidate runs clean-room gates | candidate | candidate release | clean disposable environment | candidate digest and gate record |
| HBR-REQ-074 | Product failures and intermittency block promotion | candidate | candidate release | clean disposable environment | zero-failure gate record |
| HBR-REQ-075 | Attended hardware confirms physical hibernation | hardware | release only | designated battery machine | external checkpoint evidence |
| HBR-REQ-076 | Evidence records exact versions without support/certification claims | release | release only | candidate record | versioned sanitized record |
