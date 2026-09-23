# 06: Submit a confirmed manual staged-sleep request

**Parent spec:** [Architect Hibermachy for Omarchy Quattro](../spec.md)

**What to build:** A deliberate manual action in the panel and public IPC passes through one private execution gate, chooses the safest currently executable sleep mode, and returns without holding the caller across sleep.

**Blocked by:** 01: Load Hibermachy safely as a disabled-first Quattro plugin.

**Status:** complete

**Claim (2026-09-04):** Claimed by `impl/06-manual-sleep-recovery` after
dependency ticket 01 became available at `ec315a1677acfc24d1de41f1c3338d409225a93b`.
The prior worktree-base blocker is resolved.

**Completed (2026-09-04):** Implemented and committed as
`d3fad754c7e32cea1ff64977f7b8898c8a61bfe6` (`feat: submit confirmed manual staged sleep`).

**Test evidence:** `npm test` passed the complete Quattro-hosted simulated matrix:
staged-sleep acceptance, suspend fallback, neither-mode refusal, system-inhibitor
refusal, observation failure, deterministic busy refusal, keyboard cancellation,
and keyboard confirmation. `bash -n tests/quattro-hosted-plugin.sh` and
`git diff --check ec315a1677acfc24d1de41f1c3338d409225a93b...HEAD` also passed.
No live sleep or host system-policy mutation was performed.

**Review evidence:** Two-axis review against
`ec315a1677acfc24d1de41f1c3338d409225a93b` completed after fixes. Standards:
pass, 0 findings. Spec: pass, 0 findings.

- [x] The only public mutating sleep command is always manual; callers cannot spoof automatic origin, choose a mode, inspect inhibitors independently, or bypass the coordinator.
- [x] Confirmation describes staged sleep or suspend fallback, the bypass of Stay Awake and compositor idle inhibition, and continued enforcement of system sleep inhibitors.
- [x] Every request freshly queries staged-sleep, hibernate, suspend, and system-inhibitor state, selects staged sleep when executable, otherwise selects ordinary suspend when executable, and submits nothing when neither is executable.
- [x] Requests use normal systemd operations without inhibitor override, userspace hibernate timers, RTC manipulation, a separate lock command, or changes to normal Suspend and laptop-lid behavior.
- [x] Concurrent execution receives a deterministic typed busy refusal and no request is queued for later execution.
- [x] The public call returns a typed refusal or failure, or an accepted receipt containing an attempt identifier and selected mode; caller disconnect neither cancels nor retries acceptance.
- [x] Manual use remains independent of plugin automation policy, creates no user configuration, applies no system policy, and is verified through simulated sleep submission at the Quattro-hosted public seam.
