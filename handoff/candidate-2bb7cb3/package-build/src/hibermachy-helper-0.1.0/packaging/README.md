# Helper package release contract

`hibermachy-helper` is a source package, not a prebuilt root binary. A
maintainer publishes an immutable versioned source archive and detached
signature, then replaces `__RELEASE_SHA512__`,
`__RELEASE_SIGNATURE_SHA512__`, and `__RELEASE_SIGNING_KEY__` in `PKGBUILD`
with the exact release and detached-signature checksums and long-form OpenPGP
fingerprint. `makepkg` verifies both checksums and the signature before
compiling as the unprivileged package user.

Those values intentionally remain placeholders until a real release signing
identity exists. This checkout does not publish an artifact or claim a signing
identity. Neither source nor signature integrity is skipped.

The package installs exactly one executable and one Polkit declaration. It does
not create or apply the systemd policy. The running plugin cannot invoke
`makepkg`, pacman, or this package's removal hook. Package removal repeats the
helper's recognized-policy reset, but a failure is reported by the helper and
does not claim that pacman aborted.
