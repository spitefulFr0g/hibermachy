# Ticket 25 — AC7 independent review determination

Issue: #25 (`23: Qualify one immutable candidate in clean-room gates`)
Drafted: 2026-09-20
Status: **determined 2026-09-20.** The sign-off block at the end is complete
and this determination is in force.

## The criterion

> An independent security-aware human reviews the privileged helper and
> packaging before daily use, and the evidence makes no unsupported security,
> accessibility, maintenance, version, or hardware certification claim.

The criterion has two halves. The second half — that the evidence makes no
unsupported claim — is satisfied and is not at issue here. The first half
specifies a **human** reviewer.

## What was actually performed

An independent adversarial review of the privileged helper and its packaging was
performed by an AI agent working from the source rather than from prior review
records. It covered the privilege boundary, the fixed command vocabulary, the
protocol parser, time-of-check/time-of-use handling in the secure filesystem
layer, atomic drop-in ownership, and the Polkit action's authorization
semantics. It found no exploitable vulnerability, and verified every gap raised
by the 2026-09-08 review as closed against current source rather than citing it
as closed.

Two observations were recorded rather than waived: `LD_PRELOAD` resolves before
the helper's own environment scrub can run, which is ordinary behaviour for a
non-setuid ELF binary and whose real exposure depends on the escalation
mechanism's environment sanitization; and the recorded build used the
rustup-managed toolchain rather than the distribution `rust` package the recipe
declares, a provenance gap at matching versions.

Agent review is the owner's approved standing policy for this project and
predates this issue. That policy is not in question. What is in question is
whether it satisfies a criterion whose wording names a human.

## Why the wording matters here

This is a privileged helper invoked through `pkexec` with administrator
authentication, which writes machine-wide systemd sleep policy. It is the one
component in the project where a missed flaw has consequences beyond the
plugin's own function. The criterion singled out human review for that reason,
and the distinction should not be dissolved by observing that the agent review
was thorough — it was, and thoroughness is not the property the criterion asks
for.

Agent review and human review fail differently. An agent will not notice that a
construct is unusual for reasons outside the source it was given, will not push
back on the threat model itself, and cannot be held accountable for the
judgement. Whether that difference is material at this project's scale is the
owner's call, not the reviewer's.

## The determination to be made

The owner must choose one, and the choice must be recorded here:

- **A — Accept agent review as satisfying AC7 for this release.** The evidence
  must continue to state plainly that no human review occurred, and no security
  certification may be claimed. The criterion is recorded as met by owner
  determination, not as met as written.
- **B — Record AC7 as unmet and qualify without it.** The release ships with an
  openly unmet criterion. Functionally similar to A in what the user sees;
  differs in whether the project claims the criterion is closed.
- **C — Obtain a human review before daily use.** Satisfies the criterion as
  written. Requires finding a security-aware reviewer willing to look at a
  privileged helper and its Polkit action.

Note that the helper source is unchanged by the defect fixes on
`fix/ticket-25-qualification-defects`. If C is chosen, the review performed
against `2bb7cb3`'s helper carries forward to the successor candidate on
confirmation that the helper binary is byte-identical.

## Sign-off

```
Determination:  A  (agent review satisfies AC7 for this release)
Rationale:      Agent review is the owner's approved standing policy and
                predates this issue. The review was adversarial, source-based,
                and verified prior findings closed rather than citing them.
                The human wording remains unmet and is stated, not glossed.
Owner:          spitefulFr0g
Date:           2026-09-20
```

Recorded from the owner's explicit instruction during the 2026-09-20 working
session. This is a determination entry, not a cryptographic signature.

**In force.** AC7 is recorded as met by owner determination, not as met as
written. No human review occurred and no security certification is claimed.
