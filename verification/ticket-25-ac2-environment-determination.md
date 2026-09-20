# Ticket 25 — AC2 environment determination

Issue: #25 (`23: Qualify one immutable candidate in clean-room gates`)
Drafted: 2026-09-20
Status: **draft — unsigned.** This document records a determination the owner
must make. It is prepared, not made. Nothing below is in force until the
sign-off block at the end is completed.

## The criterion

> A fresh user profile and clean verified environment exercise native discovery,
> disabled-first setup, activation/disable/reload, panel, menu, IPC, inhibitors,
> policy persistence, helper protocol, real Polkit cancellation/authorization,
> readback, administrator override, journals, diagnostics, and teardown.

## What is actually available

No clean verified environment exists for this project. The owner has no virtual
machine, no spare machine, and no second Quattro installation. `sudo` on the
development host prompts for a password, so an unattended process cannot create
a privileged container; `docker` is installed but its daemon is inactive and not
usable without escalation, and `systemd-nspawn` has the same barrier.

What was used instead is a rootless disposable environment: unprivileged Linux
user namespaces with `bwrap` 0.12.0, `fakeroot`, and a mapped subordinate uid
range. This gives genuine `geteuid()==0` execution of the production helper
binary inside a private mount namespace. It is a real privilege context for the
helper's own logic and a real filesystem isolation boundary. It is **not** a
clean verified environment, and it cannot produce a real Polkit dialog, a real
package-manager transaction, a real journal, or a fresh Quattro user profile.

## The second gap — platform drift

| Evidence | Date | Omarchy | Quickshell | systemd |
| --- | --- | --- | --- | --- |
| Existing-machine native record | 2026-09-14 | 4.0.3-1 | 0.3.1-1 | 261.2-1 |
| Rootless gate battery | 2026-09-20 | 4.0.4-1 | 0.3.1-1 | 261.2-1 |

The existing-machine record of 2026-09-14 contains the only real Polkit
authorization, real cancellation and real `pacman` install evidence this project
has. It was taken on Omarchy 4.0.3-1. The host is now 4.0.4-1.

AC2 asks for evidence bound to *one exact verified environment*. Two separate
things therefore disqualify that record from closing AC2: it was taken on the
owner's live development machine rather than a clean one, and it was taken on a
platform version that is no longer the one under test.

## What is consequently unclaimed

The following are **NOT RUN** for this candidate and are not inferred from any
other record:

- Fresh user profile discovery and disabled-first setup on a clean installation.
- Real Polkit authorization, cancellation, denial, and inactive-authorization
  paths on 4.0.4-1.
- Real package-manager install and remove on 4.0.4-1.
- Journal inspection and administrator-override behaviour on a clean host.
- Teardown observed against a clean baseline rather than against a host that has
  carried development state throughout.

## The determination to be made

The owner must choose one, and the choice must be recorded here rather than
implied by proceeding:

- **A — Accept the gap and qualify without AC2.** Release notes and evidence
  must state that no clean-environment qualification was performed, and must not
  describe the rootless battery as clean-room. The release makes no claim of
  verified behaviour on any installation other than the one tested.
- **B — Re-run the existing-machine journeys on 4.0.4-1 and accept those.** This
  closes the drift gap but not the clean-environment gap. Cheaper than A is
  honest about; still not AC2 as written.
- **C — Obtain a clean environment and satisfy AC2 as written.** Requires
  hardware or virtualization the project does not currently have.

Option A is the only one reachable without new hardware. It is also the only one
that leaves the criterion openly unmet rather than partially papered over, which
is consistent with how this project has treated every other shortfall.

## Sign-off

```
Determination:  ______   (A / B / C)
Rationale:      ____________________________________________
Owner:          ____________________________________________
Date:           ____________________________________________
```

Until this block is completed, AC2 is open and no clean-room qualification is
claimed anywhere in this repository.
