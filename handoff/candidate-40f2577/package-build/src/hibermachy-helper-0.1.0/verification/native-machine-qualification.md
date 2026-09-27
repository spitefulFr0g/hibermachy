# Existing-machine qualification findings

Issue #25 remains open. On 2026-09-14 the owner chose the existing development
machine because no disposable test target was available. These observations do
not satisfy clean-room or hostile privileged qualification.

Environment: Omarchy 4.0.3-1, Quickshell 0.3.1-1, systemd 261.2-1.
A private before-state inventory and configuration backup are retained locally.
No raw configuration or identity-bearing logs are included here.

## Native observations

- Native add, manifest validation and disabled-first discovery passed.
- Activation exposed status IPC; disabling removed that IPC target. Re-enabling
  recreated it. Automatic staged sleep stayed disabled throughout.
- User-policy save and readback passed for idle delay 1800 → 1801 → 1800 seconds,
  with automatic policy false and zero staged-sleep submissions.
- The owner confirmed the native panel is visible and readable. This is not
  keyboard-only or assistive-technology accessibility sign-off.
- Authenticated installation of the locally built helper package succeeded.
  Package-manager integrity inspection reported zero altered files; the installed
  helper reports release 0.1.0 and protocol range 1–1.
- Managed menu entries were reconciled. No system policy was applied and no
  real suspend or hibernation was initiated at this checkpoint.

## Findings and candidate disposition

The signed fb55239 source archive is preserved but cannot be promoted unchanged.
Native testing found that the activation probe required `listPlugins.active`,
which Omarchy defines only for selected bar plugins. Enabled service/panel
plugins correctly report false. The regression reproduces that native response,
fails before the fix and passes afterward; absent, disabled and bar-only entries
remain rejected. An independent agent checked the fix against the installed
shell implementation and reported no blocker. All ordinary merge gates passed.
Live status after a completed disable/re-enable confirms activation=true.

A second live reproduction returned HBR-SYSTEM-POLICY-UNAVAILABLE before launching
Polkit: production apply consulted the test fixture's authorization default.
The fixture is now consulted only in test mode. A regression evaluating the real
QML function fails on the old code and passes with the correction. After a shell
restart (plugin-only reload retained stale compiled QML), the native call returned
HBR-SYSTEM-POLICY-SUBMITTED and launched real authentication. The request ended
without creating policy; operator confirmation of cancellation remains pending.
This checkpoint claims no authorized apply pass.

A full hosted-matrix rerun was interrupted intentionally after detecting that a
concurrent fixture using the same shell path can attract native IPC calls.
The interrupted run is not a pass. Subsequent native probes targeted the actual
desktop process explicitly. Hosted and native tests must run separately.

Remaining qualification includes authenticated apply/reset and cancellation,
complete lifecycle journeys, accessibility, isolated hostile privileged checks,
clean-environment evidence or an explicit requirements decision, final immutable
source/recipe delivery, and attended hardware cycles. No release is published.
