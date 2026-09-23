# Candidate packaging checkpoint — 2026-09-14 UTC

Status: locally built, unqualified, unpublished.

The frozen source SHA-256 and detached signature were verified against the
owner-selected fingerprint. An external PKGBUILD substitutes source/signature
SHA-512 checksums and that fingerprint without changing the signed archive.
`makepkg --verifysource`, `makepkg --printsrcinfo`, and an unprivileged
`makepkg --noconfirm --cleanbuild` completed successfully using local signed inputs.
No package was installed. Artifact and recipe digests are in candidate.json.

Archive inspection confirms root:root ownership, directories mode 0755,
helper /usr/libexec/hibermachy-policy-helper mode 0755, and Polkit action
mode 0644. Runtime dependencies are glibc and polkit; build dependency is rust.
Build uses cargo --release --locked. Makepkg 7.1.0 and fakeroot 1.37.2 were used.

Observation: host makepkg debug defaults emitted a gdb-add-index message that
no debugging symbols were present and produced a separate debug package. The
helper package build exited successfully. This is recorded rather than treated
as a clean qualification pass. The debug package is not a selected release asset.

Outstanding: clean disposable environment and native/privileged/lifecycle tests,
accessibility sign-off, current advisory review, public immutable qualification
inputs, final recipe delivery/discovery verification, and attended hardware tests.
The signed archive retains template packaging sentinels; the usable external
recipe must be delivered and exercised by the release lifecycle before promotion.
Existing host-build and hosted test results do not establish these remaining gates.
