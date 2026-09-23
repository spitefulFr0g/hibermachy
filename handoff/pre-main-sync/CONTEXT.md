# Hibermachy

Hibermachy adds an automatic staged-sleep policy to Omarchy while preserving Omarchy's existing idle and power behavior.

## Language

**Suspend**:
A low-power state that keeps the running session in memory for fast resume.
_Avoid_: Sleep

**Hibernate**:
A powered-off state that preserves the running session on disk for later restoration.

**Staged sleep**:
A power-saving sequence that suspends first and transitions to hibernation if the system remains suspended long enough.
_Avoid_: Sleep then hibernate, hybrid sleep

**Idle delay**:
The period without user activity before Hibermachy initiates staged sleep.
_Avoid_: Sleep time, suspend timer

**Hibernate delay**:
The period spent suspended before staged sleep transitions to hibernation.
_Avoid_: Hibernate time, total idle time

**Automatic staged sleep**:
Staged sleep initiated when the idle delay expires. Stay Awake and idle inhibitors suppress it.

**Manual staged sleep**:
Staged sleep explicitly requested by the user. It bypasses Stay Awake and compositor idle inhibition but continues to honor system sleep inhibitors.

**Plugin activation**:
Whether Omarchy loads Hibermachy's runtime. This is distinct from whether automatic staged sleep is enabled.

**Plugin removal**:
Removal of Hibermachy's user-owned plugin checkout. It is not a complete Hibermachy uninstall and does not imply removal of other Hibermachy artifacts or policy.

**Hibermachy uninstall**:
Coordinated removal of Hibermachy's system policy, privileged helper, menu contribution, and plugin checkout while retaining user configuration and state.
_Avoid_: Plugin removal

**Hibermachy purge**:
A Hibermachy uninstall that also removes Hibermachy user configuration and state.
_Avoid_: Clean uninstall

**Installation owner**:
The single Omarchy desktop user whose Hibermachy installation manages the machine-wide Hibermachy policy. Independent multi-user Hibermachy installations on one machine are outside v1.
_Avoid_: Primary user

**Automatic-policy enablement**:
The user's choice to allow automatic staged sleep. Disabling it leaves manual staged sleep available while the plugin remains active.
_Avoid_: Plugin enablement

**User policy**:
The user-scoped durable intent comprising automatic-policy enablement and idle delay.

**Requested system policy**:
The hibernate delay and AC-power behavior Hibermachy has asked the system to apply.

**Privileged policy helper**:
A separately installed, root-owned program that runs only for one authenticated system-policy mutation and then exits. It may apply or reset Hibermachy's requested system policy; it never initiates sleep.
_Avoid_: Hibernation helper, sleep helper

**Effective system policy**:
The hibernate delay and AC-power behavior that results after all system configuration and administrator overrides are reconciled.

**Sleep executability**:
Whether staged sleep, hibernation, or suspend can be performed at the present moment, including platform support, authorization, and inhibitors. This is runtime state, not configuration.

**Operational readiness**:
Whether one specific Hibermachy operation—automatic staged sleep, manual staged sleep, system-policy mutation, or diagnostics—is usable now. Hibermachy has no single global health state.

**Verified environment**:
An exact Omarchy, Quickshell, and systemd version combination on which a Hibermachy release candidate completed its applicable verification gates. It records test evidence, not a promise of compatibility, maintenance, or support.
_Avoid_: Supported baseline, supported version

**Unverified environment**:
An environment whose exact version combination has not completed release verification. Hibermachy may operate there when required runtime contracts pass, without implying compatibility or support.
_Avoid_: Unsupported environment

**Contract incompatibility**:
A missing or mismatched required runtime contract that makes an affected Hibermachy operation fail closed. It is observed incompatibility, not an inference from an unverified version number alone.
_Avoid_: Unsupported version

**Staged-sleep attempt**:
An automatic or manual staged-sleep request that proceeds past suppression checks. Acceptance by systemd is progress within an attempt, not proof that the attempt completed.

**Staged-sleep outcome**:
The observed result of evaluating or attempting staged sleep: suppressed, refused, degraded, failed, indeterminate, or completed. Only failed denotes a positively established fault; completed means the observable system sleep transaction returned successfully, not that hibernation was confirmed.

**Outcome history**:
A bounded record of prior staged-sleep outcomes retained for diagnosis. It never represents current live state.
