#!/usr/bin/env bash
set -euo pipefail

command_path="$(cd "$(dirname "$0")/.." && pwd)/lifecycle/install"
root=$(mktemp -d "${TMPDIR:-/tmp}/hibermachy-uninstall-XXXXXX")
trap 'rm -rf "$root"' EXIT

seed() {
  rm -f "$root/lifecycle-events" "$root/lifecycle-state.json" "$root/interrupt" "$root/native-plugin-add" "$root/recovered-plugin-manifest.json" "$root/helper-build"
  rm -rf "${root:?}/plugin" "${root:?}/helper" "${root:?}/user" "${root:?}/etc" "${root:?}/menu.jsonc" "${root:?}/menu.json"
  mkdir -p "$root/plugin" "$root/helper" "$root/user" "$root/etc/systemd/sleep.conf.d"
  printf '%s\n' '{"schemaVersion":1,"id":"dev.hibermachy","version":"0.1.0","protocol":{"min":1,"max":1},"kinds":["service","panel"]}' > "$root/plugin/manifest.json"
  printf '%s\n' 'owner=alice' > "$root/installation-owner"
  printf '%s\n' '{"enabled":true}' > "$root/activation.json"
  printf '%s\n' 'package=hibermachy-helper version=0.1.0' > "$root/helper/package"
  printf '%s\n' 'owner=pacman' > "$root/helper/package.owner"
  printf '%s\n' 'protocol-min=1 protocol-max=1' > "$root/helper/protocol"
  printf '%s\n' '{"schemaVersion":1,"revision":2,"automaticPolicyEnablement":true,"idleDelaySeconds":1800}' > "$root/user/config.json"
  printf '%s\n' '{"version":1,"outcomes":[{"outcome":"completed"}]}' > "$root/user/state.json"
  chmod 600 "$root/user/config.json" "$root/user/state.json"
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

assert_purge_refused() {
  local expected=$1
  set +e
  result=$($command_path purge --root "$root" --confirm-purge 2>&1)
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
if grep -q 'hibermachy' "$root/menu.jsonc"; then
  printf '%s\n' 'HBR-CHK-LIFECYCLE-009 FAILED: managed menu entries remain after uninstall' >&2
  exit 1
fi
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
printf '%s\n' 'authorization=accepted reset=success' > "$root/policy-reset"
printf '%s\n' 'after=disable' > "$root/interrupt"
assert_refused HBR-LIFECYCLE-INTERRUPTED
[[ $(cat "$root/activation.json") == '{"enabled":false}' ]]
[[ -e "$root/etc/systemd/sleep.conf.d/90-hibermachy.conf" && -e "$root/helper/package" && -e "$root/plugin" ]]

seed
printf '%s\n' '{"setup.hibermachy":{"managedBy":"other"}}' > "$root/menu.jsonc"
assert_refused HBR-MENU-MANAGED-MODIFIED
[[ ! -e "$root/etc/systemd/sleep.conf.d/90-hibermachy.conf" && ! -e "$root/helper/package" && -e "$root/plugin" ]]

seed
rm "$root/plugin/manifest.json"
missing_checkout=$("$command_path" uninstall --root "$root")
node -e 'const x=JSON.parse(process.argv[1]); if (x.kind!=="accepted" || x.checkout!=="removed") process.exit(1)' "$missing_checkout"
[[ -e "$root/user/config.json" && -e "$root/user/state.json" ]]

seed
retained=$("$command_path" purge --root "$root" --cancel-purge)
node -e 'const x=JSON.parse(process.argv[1]); if (x.kind!=="accepted" || x.operation!=="uninstall" || x.purge!=="retained" || !x.retained.userConfiguration || !x.retained.outcomeHistory || !Array.isArray(x.purgeScopes) || x.purgeScopes.length!==2) process.exit(1)' "$retained"
[[ -e "$root/user/config.json" && -e "$root/user/state.json" && ! -e "$root/plugin" && ! -e "$root/helper/package" ]]

seed
set +e
needs_confirmation=$("$command_path" purge --root "$root" 2>&1)
needs_confirmation_code=$?
set -e
[[ $needs_confirmation_code -ne 0 && $needs_confirmation == *'HBR-PURGE-CONFIRMATION-REQUIRED'* ]]
[[ -e "$root/user/config.json" && -e "$root/user/state.json" && ! -e "$root/plugin" && ! -e "$root/helper/package" ]]

seed
purged=$("$command_path" purge --root "$root" --confirm-purge)
node -e 'const x=JSON.parse(process.argv[1]); if (x.kind!=="accepted" || x.operation!=="purge" || x.purge!=="removed" || x.finalInventory.userConfiguration!=="absent" || x.finalInventory.outcomeHistory!=="absent" || x.purgeScopes.length!==2) process.exit(1)' "$purged"
[[ ! -e "$root/user/config.json" && ! -e "$root/user/state.json" ]]
[[ -e "$root/activation.json" && $(cat "$root/activation.json") == '{"enabled":false}' ]]
rerun_purge=$("$command_path" purge --root "$root" --confirm-purge)
node -e 'const x=JSON.parse(process.argv[1]); if (x.kind!=="accepted" || x.purge!=="removed" || x.finalInventory.userConfiguration!=="absent") process.exit(1)' "$rerun_purge"

seed
mkdir -p "$root/outside"
printf '%s\n' 'outside sentinel' > "$root/outside/sentinel"
rm "$root/user/config.json"
ln -s "$root/outside/sentinel" "$root/user/config.json"
assert_purge_refused HBR-PURGE-UNSAFE-PATH
[[ -L "$root/user/config.json" && -e "$root/outside/sentinel" && -e "$root/user/state.json" ]]

seed
chmod 773 "$root/user"
rm "$root/user/state.json"
printf '%s\n' '{"version":1}' > "$root/user/state.json"
chmod 666 "$root/user/state.json"
chmod 755 "$root/user"
assert_purge_refused HBR-PURGE-UNSAFE-PATH
[[ -e "$root/user/config.json" && -e "$root/user/state.json" ]]

seed
printf '%s\n' 'after=purge-config' > "$root/interrupt"
assert_purge_refused HBR-LIFECYCLE-INTERRUPTED
[[ ! -e "$root/user/config.json" && -e "$root/user/state.json" ]]

seed
rm "$root/user/state.json"
purged_partial=$("$command_path" purge --root "$root" --confirm-purge)
node -e 'const x=JSON.parse(process.argv[1]); if (x.kind!=="accepted" || x.purge!=="removed" || x.finalInventory.outcomeHistory!=="absent") process.exit(1)' "$purged_partial"
[[ ! -e "$root/user/config.json" && ! -e "$root/user/state.json" ]]

printf '%s\n' 'HBR-CHK-LIFECYCLE-007 uninstall reset-before-removal, fail-closed journeys, retention, and rerun'

seed
rm -rf "$root/plugin"
printf '%s\n' 'accepted=true reviewed=true disabled=true' > "$root/native-plugin-add"
printf '%s\n' '{"schemaVersion":1,"id":"dev.hibermachy","version":"0.1.0","protocol":{"min":1,"max":1},"kinds":["service","panel"]}' > "$root/recovered-plugin-manifest.json"
recovered_checkout=$("$command_path" uninstall --recover --root "$root")
node -e 'const x=JSON.parse(process.argv[1]); if (x.kind!=="accepted" || x.recovery.checkout!=="re-added" || x.checkout!=="removed") process.exit(1)' "$recovered_checkout"
[[ ! -e "$root/plugin" && ! -e "$root/helper/package" && ! -e "$root/etc/systemd/sleep.conf.d/90-hibermachy.conf" ]]

seed
rm "$root/helper/package" "$root/helper/package.owner" "$root/helper/protocol"
printf '%s\n' 'success=true user=unprivileged source=immutable signature=valid checksum=valid' > "$root/helper-build"
printf '%s\n' 'success=true authorization=interactive' > "$root/package-install"
recovered_helper=$("$command_path" uninstall --recover --root "$root")
node -e 'const x=JSON.parse(process.argv[1]); if (x.kind!=="accepted" || x.recovery.helper!=="reinstalled" || x.helper!=="removed") process.exit(1)' "$recovered_helper"
[[ ! -e "$root/helper/package" && ! -e "$root/etc/systemd/sleep.conf.d/90-hibermachy.conf" ]]

seed
rm -rf "$root/plugin"
set +e
unresolved=$("$command_path" uninstall --recover --root "$root" 2>&1)
unresolved_code=$?
set -e
[[ $unresolved_code -ne 0 && $unresolved == *'HBR-RECOVERY-NATIVE-ADD-REQUIRED'* ]]
[[ -e "$root/etc/systemd/sleep.conf.d/90-hibermachy.conf" && -e "$root/helper/package" ]]

seed
printf '%s\n' 'protocol-min=9 protocol-max=9' > "$root/helper/protocol"
set +e
mismatch=$("$command_path" uninstall --recover --root "$root" 2>&1)
mismatch_code=$?
set -e
[[ $mismatch_code -ne 0 && $mismatch == *'HBR-RECOVERY-PROTOCOL-MISMATCH'* ]]
[[ -e "$root/helper/package" && -e "$root/plugin" && -e "$root/etc/systemd/sleep.conf.d/90-hibermachy.conf" ]]

printf '%s\n' 'HBR-CHK-LIFECYCLE-008 partial recovery re-add, helper reinstall, refusal, and protocol preservation'
