# Ticket 26 sanitized evidence record

**Disposition:** template — the attended gate has NOT been run
**Candidate commit:** `625d5a22c57d7ab0f792330a3bb7eaa0880f7304`
**Candidate tree:** `8f3e33a03b1609d2957c63367a4a9c471b6e4ef6`
**Source archive SHA-256:** `1eb0a56ca3cff03012884ef7cb7e8dc0c659b8b8db4ccf39d52a0fb75b3a9e5f`
**Signing fingerprint:** `0B1C5414F8D18F8B6AA78957335FEBC82DB247EC`
**Agent pre-flight date / time zone:** 2026-09-20 / America/Denver
**Operator / date / time zone:** NOT RUN

This file is the committed template. A run of
`handoff/attended-release-625d5a2.sh` produces a populated copy under its own
timestamped run directory; that populated copy is what gets reviewed, sanitized
and published. Blank never means pass.

## Determinations carried forward from issue #25

| Criterion | Determination |
| --- | --- |
| AC2 clean environment | accepted unmet; no clean environment exists |
| AC5 accessibility | assistive technology out of scope; accepted unmet |
| AC7 independent review | met by owner determination; agent, not human |

This release is not clean-room qualified, not accessibility certified, not
security certified, and claims no general version or hardware support.

## Prerequisites

| Gate | Result | Evidence / exact identity / rerun cause |
| --- | --- | --- |
| Candidate identity verification | PASS | `HBR-T26-IDENTITY PASS`; commit, tree and archive SHA-256 matched the bound values in the agent checkout on 2026-09-20. Not signed-public-source evidence. |
| Test fixtures and simulation variables absent | NOT RUN | checked at run time by the attended script |
| Signed source archive and detached signature | NOT RUN | |
| Unprivileged package build and inspection | NOT RUN | |
| Current applicable advisory review | NOT RUN | |
| Clean-room native/hosted journeys | ACCEPTED UNMET | AC2 determination; no clean environment exists |
| Accessibility sign-off | OUT OF SCOPE | AC5 determination; assistive technology removed from scope |
| Independent review | MET BY DETERMINATION | AC7 determination; agent, not human |

## Hibernation pre-flight (non-sleeping)

| Check | Result | Evidence |
| --- | --- | --- |
| Kernel supports hibernation | PASS | `/sys/power/state` = `freeze mem disk` (2026-09-20 pre-flight) |
| Resume device configured | PASS | `/sys/power/resume` = `253:0`, offset `1882657` |
| Hibernation image fits available swap | PASS | image limit ~3.0 GiB against a wholly free 7.7 GiB swapfile |
| zram does not capture the hibernation image | PASS | target selected by `resume=`, not swap priority; swapfile unused |
| logind CanHibernate / CanSuspend / CanSuspendThenHibernate | PASS | all `yes` by read-only D-Bus query; no sleep initiated |
| Built initramfs contents inspected | NOT RUN | `/boot` requires root; resume hook declared and boot-time resume attempt observed, but the built image was not inspected |
| User-session freeze overridden by vendor drop-in | NOT RUN | recorded as an environment condition; see preflight-findings.md |
| Staged-sleep unit previously exercised here | NOT RUN | `systemd-suspend-then-hibernate.service` has never run on this machine |

## Initial-state inventory and arm

| Item | Result | Sanitized evidence |
| --- | --- | --- |
| Save-work warning acknowledged | NOT RUN | |
| Initial policy, configuration and inventories captured | NOT RUN | |
| Unrelated sentinels captured | NOT RUN | |
| Non-sleeping capability detection confirmed | NOT RUN | |
| External session checkpoint established | NOT RUN | |
| Exact arm statement and timestamp | NOT RUN | |

## Separate attended cases

| Case | Result | Attempt/reason and external observation |
| --- | --- | --- |
| Stay Awake suppression | NOT RUN | |
| Compositor-inhibitor suppression | NOT RUN | |
| System-inhibitor refusal | NOT RUN | |
| Fresh-activity re-arm | NOT RUN | |
| Reload while latched | NOT RUN | no merge-gate coverage for the same-boot path |
| Deliberate suspend fallback | NOT RUN | |
| Early wake | NOT RUN | no merge-gate coverage |
| Ordinary suspend and lid behaviour unchanged | NOT RUN | |

## Consecutive staged-sleep / hibernation / resume cycles

| Cycle | Origin / power case | Pre-sleep checkpoint | External powered-down observation | Same-session resume | Typed corroboration | Result |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | NOT RUN | NOT RUN | NOT RUN | NOT RUN | NOT RUN | NOT RUN |
| 2 | NOT RUN | NOT RUN | NOT RUN | NOT RUN | NOT RUN | NOT RUN |
| 3 | NOT RUN | NOT RUN | NOT RUN | NOT RUN | NOT RUN | NOT RUN |

**Consecutive count:** 0
**Automatic / manual / AC-deferral coverage:** NOT RUN / NOT RUN / NOT RUN
**Anomalies, investigation, and rerun causes:** none observed, because not run.

## Restoration and promotion

| Check | Result | Evidence |
| --- | --- | --- |
| Initial owned policy and configuration restored | NOT RUN | |
| Unrelated state unchanged | NOT RUN | |
| Pre-promotion identity recheck | NOT RUN | |
| Sanitized record reviewed for publication | NOT RUN | |
| Unchanged candidate promoted | NOT RUN | |
| Public metadata / artifact / checksum / download smoke checks | NOT RUN | |
| Lifecycle discovery smoke check | NOT RUN | |

**Final decision:** BLOCKED — the attended hardware gate has not been run and
nothing has been published.
