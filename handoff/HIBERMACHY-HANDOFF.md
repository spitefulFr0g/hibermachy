> Current update: the owner authorized testing on this development machine.
> Native testing found two defects, so candidate fb55239 is superseded for release.
> See local-machine-test/README.md for the current installation and recovery state.
> The helper and menu are now installed; automatic staged sleep remains disabled.

# Hibermachy checkpoint

Implementation is merged in [PR #27](https://github.com/spitefulFr0g/hibermachy/pull/27).
GitHub implementation issues #3–#24 are closed. The parent specification #2 stays
open for release qualification #25 and attended hardware/promotion #26.

## Saved source and verification

- Local `main` and remote `main`: `78fdd8e7e1a783596fc5d0ad36fa101f1c0a2d08`.
- Frozen tested implementation: `fb5523990f7f1c6cb8ee69d424d54c0e84e167d6`.
- All ordinary candidate gates and 29 Rust tests pass; optimized build passes.
- Full hosted matrix: 17 scenarios pass, including 2,000 transitions with real
  persistence and simulated sleep. Independent reviews have no blocking findings.
- Evidence: `verification/integration-reconciliation.md` and
  `verification/review-integration.md`.
- Earlier local planning commits are preserved on branch
  `planning-before-integration-20260913`. Historical scratch files are preserved.
- The old pause snapshot remains in `handoff/PAUSED.md` for historical recovery.

## Remaining release work

Issue #25 is assigned to the owner for clean-room qualification. The owner
signed the frozen archive locally; its checksum and signature have been verified
against the selected fingerprint. No private key export or key backup was made.

Archive: `handoff/candidate-fb55239/hibermachy-helper-0.1.0.tar.gz`.
SHA-256: `09f631648227b641da4d696589bd5bb932fda32bf174b9c70adabb9de0a1470e`.
Its public checkpoint metadata is in the adjacent `candidate.json`.

The signed inputs passed makepkg verification and an unprivileged package build.
Package hash and recipe hashes are recorded in candidate.json; contents, ownership
and modes were inspected. See candidate-fb55239/PACKAGING-CHECKPOINT.md.

Next: complete the clean-room native,
privileged and accessibility gates, then perform the attended hardware gate.
No real sleep, machine-policy mutation, package installation, hardware
qualification or release publication was performed in this integration session.
Do not run the old ticket-24 release wizard; it remains deliberately disabled
because it references a superseded candidate.

## Release identity

Repository: `git@github.com:spitefulFr0g/hibermachy.git`.
SSH push key: `~/.ssh/github` (successfully used for the integration push).
GPG signing fingerprint: `0B1C5414F8D18F8B6AA78957335FEBC82DB247EC`.
GPG keyring: `~/.gnupg`. The SSH key authenticates pushes; the GPG key signs
release artifacts.
