# Ticket 25 — sanitized qualification evidence

Issue: #25 (`23: Qualify one immutable candidate in clean-room gates`)
Parent: #2
Candidate under evidence: the successor to `2bb7cb3`, identified in the
candidate manifest described under *Candidate identity* below.
Date of this consolidation: 2026-09-20 (revised same day)
Status: **all criteria resolved — three by determination, not by evidence.**
This document is the sanitized AC8 roll-up. It records what was verified, what
was determined, and what is unclaimed.

This file excludes identity data, absolute filesystem paths, raw configuration
content, and unrestricted logs, as AC8 requires. Per-check command output lives
in the two source ledgers named below, which remain the detailed record.

## Source ledgers

- `verification/ticket-25-provenance-review.md` — AC1, AC6, AC7, AC5 precursor.
- `verification/ticket-25-ac3-ac4-gates.md` — AC3, AC4.
- `verification/native-machine-qualification.md` — prior existing-machine record.
- `verification/ticket-25-ac2-environment-determination.md` — AC2 determination, in force.
- `verification/ticket-25-ac5-accessibility-determination.md` — AC5 determination, in force.
- `verification/ticket-25-ac7-review-determination.md` — AC7 determination, in force.

`verification/ticket-25-evidence.md` is **not** part of this issue. Its name is a
collision with an older local ticket numbering (`Harden process boundaries`).

## Candidate identity

The successor candidate is the commit in which this revision of this file is
recorded. A file cannot contain its own archive checksum, so the identity
bundle is recorded beside the artifacts in the candidate manifest
`handoff/candidate-<short>/candidate.json`, which is the authoritative record of:

| Element | Source |
| --- | --- |
| Commit and source tree | manifest |
| Signed archive SHA-256 | manifest |
| Detached signature SHA-256 | manifest |
| Helper package SHA-256 | manifest |
| Signing key fingerprint | `0B1C5414F8D18F8B6AA78957335FEBC82DB247EC` |

The archive is produced deterministically from the commit with
`git archive --format=tar --prefix=hibermachy-helper-0.1.0/ <commit>` piped
through `gzip -n -9`, so any party holding the commit can regenerate it
byte-for-byte and confirm the recorded checksum.

`main` is an ancestor of the candidate commit. **The identity holds only if the
branch is fast-forwarded.** A merge commit would create a different commit, and
under AC1 that is a different candidate with no mapped evidence.

### Superseded predecessor

| Element | Value |
| --- | --- |
| Commit | `2bb7cb344e2330799ddb6713d58b735eb5a6de4c` |
| Source tree | `7b034b105f44238f914ed2d7c758248121f8c739` |
| Signed archive SHA-256 | `09180240e9b038dfb77048895d752b6fc7dbda32548ed6a48c9fe7d5fdb74264` |
| Helper package SHA-256 | `b25a35a31f81e1cbc461d9bb6c32782988ad1234773954dabefba50b0ecf589a` |
| Signing key fingerprint | `0B1C5414F8D18F8B6AA78957335FEBC82DB247EC` |

Re-verified 2026-09-20 before supersession: the detached signature validated
against the recorded fingerprint, both checksums matched, and the extracted
archive was byte-identical to the commit's tree. Three defects were then fixed,
which under AC1 invalidated this identity. Evidence mapped to it carries forward
only where explicitly stated below.

## Environment

Two distinct environments appear in this issue's evidence, and they are not the
same. This distinction is load-bearing and must not be flattened.

| Evidence | Date | Omarchy | Quickshell | systemd |
| --- | --- | --- | --- | --- |
| Existing-machine native record | 2026-09-14 | 4.0.3-1 | 0.3.1-1 | 261.2-1 |
| Rootless gate battery | 2026-09-20 | 4.0.4-1 | 0.3.1-1 | 261.2-1 |

Toolchain for the recorded package build: cargo 1.98.1, rustc 1.98.1.

The host platform drifted from Omarchy 4.0.3-1 to 4.0.4-1 between the two dates.
No native product journey has been run on 4.0.4-1. AC2 requires evidence for one
exact verified environment, so the native-machine observations cannot be treated
as current for the newer platform without a rerun.

## Criterion status

| AC | Subject | State |
| --- | --- | --- |
| 1 | Candidate identity binding | Satisfied for `2bb7cb3` |
| 2 | Fresh profile / clean environment journeys | **Determined unmet** — no clean environment exists |
| 3 | Hostile privileged tests | Satisfied except two named exclusions |
| 4 | Lifecycle journeys with scope inventories | Satisfied — nine journeys |
| 5 | Accessibility sign-off | **Determined unmet** — assistive tech out of scope |
| 6 | Supply-chain evidence | Satisfied — no blocking advisory |
| 7 | Independent security-aware review | **Determined met by owner** — agent, not human |
| 8 | Sanitized evidence | This document |

## AC3 — hostile privileged tests

A rootless disposable environment was used: unprivileged Linux user namespaces
with `bwrap` 0.12.0, `fakeroot` and a mapped subordinate uid range, giving
genuine `geteuid()==0` execution of the production helper binary inside a private
mount namespace. This is a substitute for, not an instance of, a clean-room
environment.

Fourteen hostile cases were attempted and thirteen passed: argument corpus,
hostile `PATH`/`HOME`/`IFS`/test-root environment, symlinked directory, symlinked
target, wrong-owner target via a genuinely distinct mapped uid, concurrent
real-root racing, a 25-iteration `SIGKILL` interruption race, forged and extra
protocol tokens, non-root refusal, and the package pre-remove hook. The single
non-pass was a self-inflicted harness error, corrected and then passed; it was
not a product defect.

Two further adversarial purge-path-escape cases — a symlinked scope target and a
symlinked user directory — were both correctly refused with
`HBR-PURGE-UNSAFE-PATH`, with victim files outside the fixture root untouched.

Baseline suites rerun the same day: 33 Rust tests with formatting, eight
lifecycle scripts, the production lifecycle script, and the packaging merge gate.
All passed.

The real machine-wide sleep policy directory was confirmed empty before and after
every privileged batch and was never bind-mounted into a sandbox.

### Named exclusions

- **Real Polkit denied, cancelled and inactive authorization: NOT RUN.** These
  require privilege escalation that the unattended session was barred from.
- **Real package manager install and remove: NOT RUN.** Same reason.

The existing-machine record of 2026-09-14 contains a real approved apply, a real
cancellation and a real reset against an earlier commit in this candidate's
lineage. That is native-machine evidence for a different commit on a different
Omarchy point release. It is deliberately **not** re-claimed here as clean-room
or hostile-privileged evidence.

## AC4 — lifecycle journeys

Nine journeys were driven through the lifecycle entry points with exact
before/after scope inventories captured for each: clean setup, declined
activation, applicable previous-release update, cancellation or failure at three
representative cross-scope uninstall steps, disablement, plugin removal, clean
uninstall, purge, and incomplete-removal recovery.

Journeys J6 and J9 deterministically reproduced the status defect recorded below.

## AC6 — supply chain

The helper declares **zero external crate dependencies**; the lock file resolves
to the helper itself alone. An advisory scan using cargo-audit 0.22.2 against an
advisory database current to 2026-09-19 (1251 advisories) reported zero findings.
No applicable exploitable high- or critical-severity issue exists, so the
criterion's blocking condition does not trigger and no non-applicability
determination is required.

The package contains exactly two files: the helper binary, root-owned, mode
`0755`, **not** setuid; and the Polkit action, root-owned, mode `0644`. The
shipped binary is a stripped position-independent executable with full RELRO,
`BIND_NOW` and a non-executable stack. The `test-support` feature — which relaxes
uid and mode checks and exposes fault-injection hooks — was confirmed absent from
the shipped binary.

### Known observation — toolchain provenance

The recorded build used the rustup-managed toolchain rather than the distribution
`rust` package the recipe declares among its build dependencies. The versions
match exactly, so this is a provenance and reproducibility gap rather than a
version mismatch or a security finding. Recorded, not waived.

## AC7 — independent review

An independent adversarial review of the privileged helper and its packaging
found **no exploitable vulnerability**. Reviewed: the privilege boundary, the
fixed command vocabulary, the protocol parser, time-of-check/time-of-use handling
in the secure filesystem layer, atomic drop-in ownership, and the Polkit action's
authorization semantics. Path resolution is descriptor-relative with
descriptor-based validation, and drop-in replacement is atomic with fsync,
readback and rollback.

Every gap raised by the 2026-09-08 review was verified closed against current
source rather than merely cited as closed.

**This review was performed by an AI agent, which is the owner's approved
standing policy. It is not a human review.** The criterion's wording asks for an
independent security-aware *human*, and no evidence in this repository satisfies
that wording as of this date. This gap is stated, not waived, and no security
certification is claimed.

### Known observation — preload ordering

The dynamic loader resolves `LD_PRELOAD` before the helper's own environment
scrub can execute. This is ordinary behaviour for a non-setuid ELF binary, and
real exposure depends on the escalation mechanism's own environment
sanitization, which was not exercised. Recorded as sitting on the boundary of the
helper's documented startup-hygiene claim; not a confirmed defect in the shipped
path.

## AC5 — accessibility

**Determined: assistive technology out of scope; AC5 accepted as unmet.** See
`verification/ticket-25-ac5-accessibility-determination.md`.

Evidence is automated and static only. No operator session occurred and none is
scheduled. `HBR-CHK-PANEL-ANNOUNCE-001` establishes which announcements the
panel attempts, with what text, on which transitions.
`HBR-CHK-PANEL-ANNOUNCE-002` establishes that such a call reaches the
accessibility bus with its text intact; it needs no screen reader and is opt-in
behind `HBR_RUN_HOSTED=1`. Contrast measures 11.56:1, passing AA and AAA.

Keyboard-only navigation, confirmation focus behaviour, authentication focus
return, text scaling, and screen-reader presentation are all unevidenced. The
first four are unevidenced because no operator session is scheduled; the last is
out of scope.

**No accessibility sign-off is claimed, and the panel must not be described as
accessible or screen-reader tested.**

## Defects found — candidate superseded

Two defects were found on 2026-09-20. The owner elected to fix both, which under
AC1 creates a new candidate identity and invalidates the evidence mapped to
`2bb7cb3`.

1. **Lifecycle status mislabels the helper-protocol scope.** After a legitimate
   plugin removal that leaves the helper package installed, the scope reports
   `mismatched` with guidance directing the operator to install an overlapping
   helper. There is no checkout to compare against and the helper is not at
   fault, so both the state and its guidance are inaccurate. Diagnostic accuracy
   only; no privileged or policy behaviour is affected.
2. **Missing non-visual announcement.** The requested-versus-effective policy
   comparison lacks the announcement handler its neighbouring status and
   action-result text carry, so the change is not conveyed to assistive
   technology.

A third defect was found on the same day while verifying the second, and is
recorded below with its cause.

3. **The action-result announcement was gated on a stale binding.** All three
   announcement handlers tested the element's own `visible` property. For the
   action-result text, `visible` is bound to the same source property as `text`,
   and the sibling `Accessible.name` binding declared *after* the handler changes
   binding evaluation order so that `visible` is still stale when `onTextChanged`
   fires. The first action result after an empty state was therefore never
   announced, and clearing the result announced an empty string. Both symptoms
   were reproduced before the fix and are absent after.

All three fixes are committed on branch `fix/ticket-25-qualification-defects`,
unpushed, with regression coverage demonstrated failing before each fix and
passing after.

### Resolved — announcement parameter

An earlier revision of this document recorded a concern that the handler
parameter might be empty, on the reasoning that QML property-change signals do
not generally carry arguments. That concern is **withdrawn**. It was tested
directly on Qt 6.11.2: `Text.onTextChanged` does deliver the new text, the
parameter is a populated string, `Accessible.announce` is a callable function,
and `Accessible.Polite` resolves to `0`.

Testing it is what exposed defect 3 above, so the concern was pointing at a real
problem — just not the one stated.

The transport question that replaced it has since been answered too, by
`HBR-CHK-PANEL-ANNOUNCE-002`: the announce call does reach the accessibility bus
with its text intact. What remains is whether a screen reader presents it
usefully, which requires one to be installed and an operator to listen. No claim
is made that any announcement is heard.

## Recorded decision — host-mutation scan scope

`HBR-CHK-CROSS-004` scanned both executable test code and the evidence directory
for privileged command tokens. Honest qualification evidence must be able to name
those commands in order to record them as not run, so the check and the evidence
requirement were in direct conflict. Earlier evidence resolved this by
substituting vaguer wording, which degrades the record precisely where it
documents privileged gaps.

Decision, 2026-09-20: the scan is scoped to executable test code. The seam the
check exists to prevent can only be introduced by code that runs; evidence prose
executes nothing. Coverage was confirmed intact by introducing a prohibited seam
under the test directory and observing the check fail, then removing it and
observing it pass.

This is a deliberate merge-gate change made during qualification and is recorded
here rather than left implicit.

### Carry-forward on re-cut

Neither fix touches the helper source. On the successor candidate:

- AC1 must be redone in full — new commit, new archive, new signature, new
  checksums.
- AC6 and AC7 helper findings carry forward on unchanged helper source, but the
  package checksum and archive provenance must be re-recorded.
- AC4 must be rerun; defect 1 is in the lifecycle status path it exercises.
- AC5's automated checks rerun as part of the candidate gate; no operator
  evidence exists to carry forward.
- AC3's battery targets the helper binary and carries forward if that binary is
  byte-identical; this must be confirmed rather than assumed.

## Outstanding before this issue can close

All three open criteria now have determinations in force, so no decision remains
outstanding. What remains is mechanical:

1. Re-cut the successor candidate: new commit, new source archive, new checksum,
   new helper-package build and checksum.
2. Owner signs the archive with the recorded key and the signature is verified
   against it.
3. Rerun the candidate gate against the signed bundle and record the result.
4. Update this document with the successor identity, then close #25 noting that
   AC2 and AC5 were qualified without, and AC7 met by owner determination rather
   than as written.

No release has been published, no branch has been pushed, and no gate is marked
passed that did not run.
