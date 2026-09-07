#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
pkg="$root/packaging/PKGBUILD"
policy="$root/packaging/org.hibermachy.policy-helper.policy"
install="$root/packaging/hibermachy-helper.install"

bash -n "$install"
grep -Fq "sha512sums=('__RELEASE_SHA512__' '__RELEASE_SIGNATURE_SHA512__')" "$pkg"
grep -Fq "validpgpkeys=('__RELEASE_SIGNING_KEY__')" "$pkg"
grep -Fq 'cargo build --release --locked' "$pkg"
grep -Fq '/usr/libexec/hibermachy-policy-helper' "$pkg"
grep -Fq '/usr/share/polkit-1/actions/org.hibermachy.policy-helper.policy' "$pkg"
grep -Fq '<allow_any>no</allow_any>' "$policy"
grep -Fq '<allow_inactive>no</allow_inactive>' "$policy"
grep -Fq '<allow_active>auth_admin</allow_active>' "$policy"
! grep -Fq 'auth_admin_keep' "$policy"
! grep -Fq 'SKIP' "$pkg"
! grep -Fq 'rm -rf' "$install"

printf '%s\n' 'HBR-CHK-PACKAGING-001 immutable source and unprivileged build contract'
printf '%s\n' 'HBR-CHK-PACKAGING-002 generated policy, ownership, and mode contract'
printf '%s\n' 'HBR-CHK-PACKAGING-003 package reset is narrow and non-blocking'
