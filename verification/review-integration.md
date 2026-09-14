# Integration review

## Scope

Independent Standards and Spec reviews compared `76691cc` with `c7eaaf8`.
Subsequent targeted reviews checked the update handoff and user-policy
persistence corrections. Issue #2 is the normative specification; issue #24
owns integration closeout. Qualification and attended hardware testing are
separate release gates, not results claimed by these reviews.

## Standards

No hard documented-standard violations were found. The consolidated integration
branch follows the owner's explicit instruction to finish the assembled project;
the exception to per-ticket branches is documented in integration-reconciliation.
The two chosen menu labels follow the explicit product specification.

Two non-blocking maintainability observations remain: the QML service combines
several runtime responsibilities, and the historical fixture dispatcher combines
several fixture responsibilities. Neither is a requirement failure.

## Spec

The reviews identified and prompted corrections to native installation layout,
production lifecycle dispatch, typed sleep evidence, effective-policy ordering,
strict policy keys, protocol overlap, menu confirmation, rerunnable uninstall,
artifact-absence verification, and transfer to the updated lifecycle interface.
The updated interface is invoked from the installed checkout and builds its
recipe; the original bootstrap process cannot continue building an old tree.

An earlier recommendation to adopt a differing external policy revision was
rejected on direct comparison with the specification's Configuration and state
ownership section. A semantic external edit must retain the current revision;
the service persists it as the next revision. Differing revisions remain
conflicts. The final implementation also waits for confirmed persistence before
advertising a new revision, including initialization and reset.

The FileView integration follows its documented completion signals and
[typed read failures](https://quickshell.org/docs/v0.3.0/types/Quickshell.Io/FileViewError/).
Writes initiated from a FileView signal are deferred until that signal returns;
otherwise the native operation lifecycle can drop completion delivery.

## Validation boundary

The ordinary candidate gates pass, including 29 Rust tests. The full hosted
matrix passes all 17 scenarios, including the 2,000-transition persistence soak,
on frozen implementation `fb5523990f7f1c6cb8ee69d424d54c0e84e167d6`.
The update handoff and corrected external-revision handling received targeted
independent review; no blocking findings remain. No real sleep, authenticated host
mutation, release signature or clean-room qualification is established here.
