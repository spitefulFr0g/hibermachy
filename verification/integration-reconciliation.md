# Integration reconciliation

This record supersedes the integration and candidate-readiness claims for
`8e8592b`. Earlier ticket evidence remains historical; it does not qualify this
changed source tree. The authoritative work is tracked by
[Close traceability and cross-seam merge verification](https://github.com/spitefulFr0g/hibermachy/issues/24).

## Corrections

- Restored diagnostics export, rejected-history recovery, notifications, and
  diagnostics regression coverage omitted from the assembled candidate.
- Allowlisted exported persisted values and derived safe notification copy.
- Made the panel copy the sanitized export through a fixed clipboard command;
  hosted verification substitutes a harmless pipe consumer.
- Restored update receipts and update/removal regression coverage, including
  cancellation, partial removal, retained-policy warnings and safe reruns.
- Fixed the accelerated test's response-field and retention-limit assertions.
  The 2,000-transition soak exercises real persistence; it does not bypass it.
- Replaced nonexistent production capability/contract commands with bundled,
  read-only probes. Real boot identity precedes history recovery in production.
- Corrected the public package repository and generated package metadata.
- Made negative gate assertions actually fail, checked every shell script,
  validated Node separately, checked generated metadata and removed a
  production Rust warning.

## Production completion

- Added a root manifest accepted by the installed public Omarchy validator;
  its relative entry points load the existing plugin directory.
- Added operator lifecycle dispatch through native Omarchy commands and the
  package manager, with injected command adapters restricted to explicit tests.
- Added ordered effective-policy readback with separate owned-policy recognition,
  administrator provenance and periodic/status-triggered refresh. The parser
  follows systemd's [sleep configuration](https://github.com/systemd/systemd/blob/main/src/shared/sleep-config.c).
- Newly written policy files are root-owned mode 0644 so the desktop can read
  public configuration. Only root can write them. Legacy mode 0600 remains
  recognized for reset/update; unfamiliar metadata is still refused.
- Added typed logind/systemd observation before dispatch. A command's successful
  exit alone cannot produce Completed. The observer requires a matching new
  unit job and sleep entry/resume evidence; missing evidence is indeterminate.
- Corrected history retry intervals to 1, 5, 30 seconds, then five minutes.

The plugin's runtime needs Node.js, Python 3 with PyGObject/Gio, Quickshell,
Wayland clipboard utilities and Omarchy's public plugin interfaces. Observer
startup failure disarms dispatch. Installing the helper alone does not establish
plugin runtime readiness.

The integration branch consolidates repairs to the assembled implementation
under issue #24, following the owner's instruction to finish the whole project.
Earlier per-ticket implementation branches are preserved as historical evidence.
This is an explicit workflow exception; issue closure still waits for reviewed
merge, and release gates remain separate.

## Verification in progress

The focused default hosted journey passed before the final native-probe wiring;
the full matrix and final-tree verification are still in progress. Scoped native
probe, lifecycle, static, generated-metadata and Rust checks have passed during
implementation. These intermediate checks are not a final candidate pass.
Independent standards/spec reviews must finish before integration closeout.

ShellCheck 0.11.0 was obtained from its official upstream release and verified
against the published asset SHA-256:
`8c3be12b05d5c177a04c29e3c78ce89ac86f1595681cab149b65b97c4e227198`.
QML parsing uses the installed Qt formatter's supported stdout interface; this
is explicitly a parse check, not a claim of canonical formatting.

## Release boundary

No real sleep, host-policy change, package installation, signed-source release,
or hardware qualification is claimed by this record. Clean-room native,
privileged authorization/lifecycle, accessibility and attended hardware evidence
remain required for a newly frozen candidate after integration.
