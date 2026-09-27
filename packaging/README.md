# Helper package release contract

`hibermachy-helper` is a source package, not a prebuilt root binary. A
maintainer publishes an immutable versioned source archive and detached
signature on the GitHub release, then pins `PKGBUILD` to the exact release and
detached-signature SHA-512 checksums and the long-form OpenPGP fingerprint. `makepkg` verifies both checksums and the signature before
compiling as the unprivileged package user.

v0.1.0 is pinned to `git archive` of `625d5a2` signed by
`0B1C5414F8D18F8B6AA78957335FEBC82DB247EC`. The public key is shipped as
`packaging/keys/pgp/0B1C5414F8D18F8B6AA78957335FEBC82DB247EC.asc`; import it
(`gpg --import packaging/keys/pgp/*.asc`) before `makepkg` so signature
verification can run. Neither source nor signature integrity is skipped.

The package installs exactly one executable and one Polkit declaration. It does
not create or apply the systemd policy. The running plugin cannot invoke
`makepkg`, pacman, or this package's removal hook. Package removal repeats the
helper's recognized-policy reset, but a failure is reported by the helper and
does not claim that pacman aborted.
