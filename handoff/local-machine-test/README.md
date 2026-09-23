> Current result: approved reset PASSED. The temporary policy file is removed;
> requested/effective policy is absent and automatic staged sleep remains off.
> Apply/readback, cancellation with unchanged policy, and approved reset passed.
> Earlier cleanup-pending entries below are historical. No real sleep occurred.

# Existing-machine testing checkpoint

The owner authorized tests on the current development machine. This is not
clean-room evidence. Private before-state files are in before/; do not publish
raw configuration. Initially no Hibermachy artifacts or policy existed.

## Current state

- Code branch: fix/native-service-activation; tip6596986; draft PR28.
- Corrected helper package from signed source40f2577 is installed and verified:
  package integrity reports zero altered files; installed binary SHA-256 is
  be889db04d2d4f7730d329e38c7886bddb967d1866293ba304a0e0a90568c22a.
- Native checkout is on6596986 and activated after restart.
- Managed menu entries exist; automatic policy is disabled.
- Approved apply succeeded: requested/effective7200 seconds and AC hibernation false.
  The root-owned policy file exists with mode0644. No staged-sleep request was made.
- Before-state snapshots are private under before/. Old candidates are preserved.

## Evidence

Native discovery, manifest validation, disabled-first installation, activation,
disable/IPC disappearance, reactivation, and disabled user-policy save/restore
passed. The owner confirms the panel is visible/readable and approved a read-only
helper authentication dialog. Earlier apply requests were either refused before
authentication or approved but failed because the policy directory was absent.
Neither is a cancellation pass.

Four native defects were corrected: service activation/bar flag confusion;
production fixture authorization guard; missing final policy directory; and
cancellation reporting. Independent reviews and focused regressions pass.
Source40f2577 passed all ordinary gates/33 Rust tests and all17 hosted scenarios,
including2000 transitions. It is signed and its package built unprivileged with
source signature/checksum validation. Panel-only tip6596986 uses the same helper;
its focused tests pass and a hosted panel rerun is now in progress.

One earlier hosted rerun was interrupted because concurrent same-path fixture
instances interfere with native command routing. Do not run hosted and native
operations concurrently. Later full40f2577 matrix passed normally.

## Next and recovery

Finish focused panel run, update native checkout to6596986, restart shell, verify
automation remains off, then test real approved apply/readback/reset and explicit
cancellation. Save sanitized outcomes. Do not initiate suspend without attended
arming. Clean-room, hostile privileged, accessibility and hardware gates remain.

Recovery begins with `omarchy plugin disable dev.hibermachy`. Use reviewed
lifecycle uninstall for helper/policy/menu/checkout removal; retain user state
unless explicitly purging. Compare before-state before restoration and never
blindly overwrite shared shell/menu files. Old release wizards remain disabled.

Latest live test: updated Panel hosted journey passed. Real approved apply/readback
passed. A reset authentication request is pending; the owner has been instructed
to CANCEL it. Verify lastSystemPolicyMutationResult AUTH-CANCELLED and unchanged
hash against policy-before-cancel.sha256, then request an APPROVED reset to remove
the test policy. Until then policy7200/no remains installed; automation stays off.

Cancellation test PASSED: owner explicitly cancelled; service reported
AUTH-CANCELLED and the policy SHA-256 stayed unchanged. Cleanup resets were then
requested for approval, but also returned AUTH-CANCELLED. No reset is currently
pending. Owner feedback on the latest dialogs is pending. Temporary7200/no policy
still exists and must be removed via an approved helper reset; automation is off.
Do not claim restored policy or reset success. No real sleep request was made.
