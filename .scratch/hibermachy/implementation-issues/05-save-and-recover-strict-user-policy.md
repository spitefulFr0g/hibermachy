# 05: Save and recover strict user policy

**Parent spec:** [Architect Hibermachy for Omarchy Quattro](../spec.md)

**What to build:** The service and single-sheet panel own an unprivileged, revisioned user-policy commit domain for automatic-policy enablement and idle delay, with safe defaults and explicit recovery.

**Blocked by:** 01: Load Hibermachy safely as a disabled-first Quattro plugin.

**Status:** complete

## Completion record (2026-09-04)

- Commit: `63c26020f0870095734acbfe2b7dc15ec16b6c74` (`feat: save and recover strict user policy`).
- Review base: `ec315a1677acfc24d1de41f1c3338d409225a93b`; `git log <base>..HEAD --oneline` contains only the ticket commit and `git diff <base>...HEAD --check` passes.
- Test evidence: `npm test` passes the real Quattro-hosted service/panel suite in an isolated `HOME` and `XDG_CONFIG_HOME`. Checks cover safe first persistence, canonical V1 handling, strict 16-KiB/UTF-8/BOM/key/type/integer/bounds validation, drafts and saves, stale and exhausted revisions, external edits/conflicts, deterministic property samples, concurrent clients, atomic-write failure, explicit reset, reload, and non-mutating simulated manual sleep. No live sleep or host system-policy mutation occurs.
- Migration evidence: V1 is the first shipped user-policy schema, so pre-V1 migration is not applicable. Permanent V1 and newer-schema fixtures verify canonical current-schema handling and fail-closed preservation.
- Two-axis review: Standards pass with 0 hard violations and 0 judgment-call findings; Spec pass with 0 missing/partial, incorrect, or scope-creep findings after review fixes.

## Superseded blocker record (2026-09-04)

Ticket 05 cannot begin its required vertical TDD work at the confirmed public
Quattro-hosted panel/service mutation seam. This worktree is at
`884209903765d5690fc932968c884bc53139dfaf` and contains only `README.md`;
the completed ticket-01 implementation is commit
`ec315a1677acfc24d1de41f1c3338d409225a93b` on
`impl/01-load-hibermachy-disabled-first`, which is not an ancestor of this
branch. Its required plugin service, panel, manifest, package script, and
Quattro-hosted test seam are therefore unavailable here.

The ticket instruction explicitly prohibits merge and cherry-pick, so bringing
that prerequisite into this branch would exceed ticket 05's scope. No ticket-05
code, tests, mutation, or configuration repair was performed. Validation,
two-axis review, and a ticket-scoped implementation commit are unavailable
until the worktree is rebased or otherwise prepared with ticket 01.

## Evidence (2026-09-04)

- Seam decision: the spec's already-confirmed Quattro-hosted product boundary
  (real plugin service and panel, observing public durable-policy/status
  behavior) is the relevant ticket-05 seam. It is absent from this worktree.
- Validation preflight: `git rev-parse --verify
  884209903765d5690fc932968c884bc53139dfaf^{commit}` resolved; the required
  `package.json`, `plugin/Service.qml`, and
  `tests/quattro-hosted-plugin.sh` are all absent. No focused or full suite can
  be selected without inventing the ticket-01 harness.
- Code-review preflight: `git diff
  884209903765d5690fc932968c884bc53139dfaf...HEAD` is empty and
  `git log 884209903765d5690fc932968c884bc53139dfaf..HEAD --oneline` has no
  commits. Per the required two-axis review procedure, review stops before
  sub-reviewers when the comparison diff is empty; there is no ticket-05 diff
  to assess.
- Commit evidence: no ticket-scoped implementation commit was created because
  the prerequisite branch is unavailable under the stated no-merge/no-
  cherry-pick constraint.

- [x] First service load of absent user policy atomically persists revision 1 with automatic staged sleep disabled and a 1,800-second idle delay, and automation remains disarmed until persistence succeeds.
- [x] The complete version-1 document enforces its byte, encoding, exact-key, type, integer, revision, and 300-through-86,400-second bounds and is written canonically only after full validation.
- [x] The panel holds automatic-policy and idle-delay edits as a draft, preserves valid custom whole-second durations exactly, and saves them without authentication or any system-policy mutation.
- [x] Mutations carry a base revision, serialize through the service, advance the advertised revision only after durable replacement, and return the current snapshot when stale or exhausted.
- [x] Valid external semantic edits become a new canonical revision; conflicting revisions, malformed documents, invalid fields, and unknown or newer schemas remain untouched and disarm automatic execution.
- [x] Explicit reset replaces rejected user policy with safe disabled defaults using the correct next known revision, while merely opening the panel or requesting manual staged sleep never creates or repairs configuration.
- [x] Boundary, property, migration-fixture, concurrency, atomic-write-failure, external-edit, and revision-conflict tests exercise the public panel/service mutation seam rather than private implementation state.
