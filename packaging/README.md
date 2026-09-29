# Helper package release contract

`hibermachy-helper` is a source package, not a prebuilt root binary. A
maintainer publishes an immutable versioned source archive and detached
signature, then replaces `__RELEASE_SHA512__`,
`__RELEASE_SIGNATURE_SHA512__`, and `__RELEASE_SIGNING_KEY__` in `PKGBUILD`
with the exact release and detached-signature checksums and long-form OpenPGP
fingerprint. `makepkg` verifies both checksums and the signature before
compiling as the unprivileged package user.

The repository recipe retains those placeholders to prevent accidentally
building an unverified checkout. Each release attaches a separate recipe
(`hibermachy-helper-<version>-recipe.tar.gz`) filled with the signed archive's
checksums and the release signing-key fingerprint. Verify the fingerprint
independently before trusting the included public key. Neither source nor
signature integrity is skipped.

Since v0.1.2 the recipe is consumed by `lifecycle/install setup|update --recipe
<absolute directory>`, run from the extracted signed source (see the
[install instructions](../README.md#install)). Before building, the lifecycle
command refuses a recipe that still holds placeholders, names another signing
key, or belongs to another version. After `makepkg --verifysource` it requires
that the extracted source and the plugin checkout's release tag have the same
Git tree as the signed archive. It then pins the checkout to that tag and runs
`makepkg --syncdeps --install --cleanbuild` in a temporary directory under
`~/.cache/hibermachy`, never inside the plugin checkout.

The [public exposure audit](../verification/2026-09-27-public-exposure-audit.md)
records that the already-published v0.1.0 source archive also contains historical
planning, handoff builds, and local machine test evidence. Signature verification
authenticates those exact published bytes; it does not screen archive contents.
Review the audit before installing or redistributing this version. Any corrected
source archive needs a new version and its own signed release assets.

The package installs exactly one executable and one Polkit declaration. It does
not create or apply the systemd policy. The running plugin cannot invoke
`makepkg`, pacman, or this package's removal hook. Package removal repeats the
helper's recognized-policy reset, but a failure is reported by the helper and
does not claim that pacman aborted.
