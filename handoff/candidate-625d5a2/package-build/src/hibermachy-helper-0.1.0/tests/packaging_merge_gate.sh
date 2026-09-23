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
if grep -Fq 'auth_admin_keep' "$policy"; then
  printf '%s\n' 'HBR-CHK-PACKAGING-002 FAILED: persistent administrator authorization is prohibited' >&2
  exit 1
fi
if grep -Fq 'SKIP' "$pkg"; then
  printf '%s\n' 'HBR-CHK-PACKAGING-001 FAILED: package build cannot be skipped' >&2
  exit 1
fi
if grep -Fq 'rm -rf' "$install"; then
  printf '%s\n' 'HBR-CHK-PACKAGING-003 FAILED: package reset must remain narrow' >&2
  exit 1
fi

printf '%s\n' 'HBR-CHK-PACKAGING-001 immutable source and unprivileged build contract'
printf '%s\n' 'HBR-CHK-PACKAGING-002 generated policy, ownership, and mode contract'
printf '%s\n' 'HBR-CHK-PACKAGING-003 package reset is narrow and non-blocking'

if command -v makepkg >/dev/null 2>&1; then
  printf '%s\n' 'HBR-CHK-PACKAGING-004 .SRCINFO matches makepkg --printsrcinfo'
  generated_srcinfo=$(mktemp)
  trap 'rm -f "$generated_srcinfo"' EXIT
  (
    cd "$root/packaging"
    makepkg --printsrcinfo >"$generated_srcinfo"
  )
  diff -u "$root/packaging/.SRCINFO" "$generated_srcinfo"
  rm -f "$generated_srcinfo"
  trap - EXIT
else
  printf '%s\n' 'HBR-ENV-LIMIT makepkg not installed; .SRCINFO consistency validation unavailable'
fi
