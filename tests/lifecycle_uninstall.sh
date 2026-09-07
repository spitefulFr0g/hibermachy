#!/usr/bin/env bash
set -euo pipefail

command_path="$(cd "$(dirname "$0")/.." && pwd)/lifecycle/install"
root=$(mktemp -d "${TMPDIR:-/tmp}/hibermachy-uninstall-XXXXXX")
trap 'rm -rf "$root"' EXIT

seed() {
  rm -f "$root/lifecycle-events" "$root/interrupt"
  rm -rf "$root/plugin" "$root/helper" "$root/user" "$root/etc" "$root/menu.jsonc" "$root/menu.json"
  mkdir -p "$root/plugin" "$root/helper" "$root/user" "$root/etc/systemd/sleep.conf.d"
  printf '%s\n' '{"schemaVersion":1,"id":"dev.hibermachy","version":"0.1.0","protocol":{"min":1,"max":1},"kinds":["service","panel"]}' > "$root/plugin/manifest.json"
  printf '%s\n' 'owner=alice' > "$root/installation-owner"
  printf '%s\n' '{"enabled":true}' > "$root/activation.json"
  printf '%s\n' 'package=hibermachy-helper version=0.1.0' > "$root/helper/package"
  printf '%s\n' 'owner=pacman' > "$root/helper/package.owner"
  printf '%s\n' 'protocol-min=1 protocol-max=1' > "$root/helper/protocol"
  printf '%s\n' '{"schemaVersion":1,"revision":2,"automaticPolicyEnablement":true,"idleDelaySeconds":1800}' > "$root/user/config.json"
  printf '%s\n' '{"version":1,"outcomes":[{"outcome":"completed"}]}' > "$root/user/state.json"
  printf '%s\n' '# Managed by Hibermachy. Do not edit.' '[Sleep]' 'HibernateDelaySec=3600s' 'HibernateOnACPower=no' > "$root/etc/systemd/sleep.conf.d/90-hibermachy.conf"
  printf '%s\n' 'owner=system
mode=600
links=1' > "$root/etc/systemd/sleep.conf.d/90-hibermachy.conf.owner"
  cat > "$root/menu.jsonc" <<'EOF'
// Preserve this comment and unrelated entries.
{
  "unrelated": {"label":"Keep me"},
  "setup.hibermachy": {"managedBy":"hibermachy","label":"Sleep & Hibernation"},
  "system.hibermachy-staged-sleep": {"managedBy":"hibermachy","label":"Suspend then Hibernate"}
}
EOF
  printf '%s\n' 'authorization=accepted reset=success' > "$root/policy-reset"
  printf '%s\n' 'success=true' > "$root/native-disable"
  printf '%s\n' 'success=true authorization=interactive' > "$root/package-remove"
}

assert_refused() {
  local expected=$1
  set +e
  result=$("$command_path" uninstall --root "$root" 2>&1)
  code=$?
  set -e
  [[ $code -ne 0 ]] && [[ $result == *"$expected"* ]]
}

seed
clean=$("$command_path" uninstall --root "$root")
node -e 'const x=JSON.parse(process.argv[1]); if (x.kind!=="accepted" || x.policyReset!=="verified-absent" || x.helper!=="removed" || x.checkout!=="removed" || !x.retained.userConfiguration || !x.retained.outcomeHistory || x.scope.indexOf("machine-wide")<0) process.exit(1)' "$clean"
[[ ! -e "$root/etc/systemd/sleep.conf.d/90-hibermachy.conf" && ! -e "$root/helper/package" && ! -e "$root/plugin" ]]
[[ $(cat "$root/activation.json") == '{"enabled":false}' ]]
[[ $(grep -v '^menu-' "$root/lifecycle-events" | paste -sd, -) == 'disable,policy-reset-authenticated,policy-reset-verified-absent,package-removal-requested,package-removed,checkout-removed' ]]
grep -q 'Preserve this comment' "$root/menu.jsonc"
grep -q 'unrelated' "$root/menu.jsonc"
! grep -q 'hibermachy' "$root/menu.jsonc"
rerun=$("$(cd "$(dirname "$0")/.." && pwd)/lifecycle/uninstall" --root "$root")
node -e 'const x=JSON.parse(process.argv[1]); if (x.kind!=="accepted" || x.policyReset!=="verified-absent" || x.menu!=="unchanged") process.exit(1)' "$rerun"

seed
printf '%s\n' 'authorization=cancelled reset=success' > "$root/policy-reset"
assert_refused HBR-SYSTEM-POLICY-AUTH-CANCELLED
[[ -e "$root/helper/package" && -e "$root/plugin" && -e "$root/etc/systemd/sleep.conf.d/90-hibermachy.conf" ]]

seed
printf '%s\n' 'authorization=denied reset=success' > "$root/policy-reset"
assert_refused HBR-SYSTEM-POLICY-AUTH-DENIED
[[ -e "$root/helper/package" && -e "$root/plugin" && -e "$root/etc/systemd/sleep.conf.d/90-hibermachy.conf" ]]

seed
printf '%s\n' 'authorization=accepted reset=refused' > "$root/policy-reset"
assert_refused HBR-SYSTEM-POLICY-RESET-FAILED
[[ -e "$root/helper/package" && -e "$root/plugin" && -e "$root/etc/systemd/sleep.conf.d/90-hibermachy.conf" ]]

seed
printf '%s\n' 'authorization=accepted reset=success' > "$root/policy-reset"
printf '%s\n' 'administrator-owned content' > "$root/etc/systemd/sleep.conf.d/90-hibermachy.conf"
assert_refused HBR-SYSTEM-POLICY-RESET-REFUSED
[[ -e "$root/helper/package" && -e "$root/plugin" ]]

seed
printf '%s\n' 'success=false authorization=interactive' > "$root/package-remove"
assert_refused HBR-PACKAGE-REMOVE-FAILED
[[ ! -e "$root/etc/systemd/sleep.conf.d/90-hibermachy.conf" && -e "$root/helper/package" && -e "$root/plugin" ]]

seed
printf '%s\n' 'success=true authorization=interactive' > "$root/package-remove"
printf '%s\n' 'after=menu' > "$root/interrupt"
assert_refused HBR-LIFECYCLE-INTERRUPTED
[[ ! -e "$root/etc/systemd/sleep.conf.d/90-hibermachy.conf" && ! -e "$root/helper/package" && -e "$root/plugin" ]]

seed
printf '%s\n' '{"setup.hibermachy":{"managedBy":"other"}}' > "$root/menu.jsonc"
assert_refused HBR-MENU-MANAGED-MODIFIED
[[ ! -e "$root/etc/systemd/sleep.conf.d/90-hibermachy.conf" && ! -e "$root/helper/package" && -e "$root/plugin" ]]

seed
rm "$root/plugin/manifest.json"
missing_checkout=$("$command_path" uninstall --root "$root")
node -e 'const x=JSON.parse(process.argv[1]); if (x.kind!=="accepted" || x.checkout!=="removed") process.exit(1)' "$missing_checkout"
[[ -e "$root/user/config.json" && -e "$root/user/state.json" ]]

printf '%s\n' 'HBR-CHK-LIFECYCLE-007 uninstall reset-before-removal, fail-closed journeys, retention, and rerun'
