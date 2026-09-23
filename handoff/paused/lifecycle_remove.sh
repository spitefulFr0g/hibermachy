#!/usr/bin/env bash
set -euo pipefail

command_path="$(cd "$(dirname "$0")/.." && pwd)/lifecycle/remove"
root=$(mktemp -d "${TMPDIR:-/tmp}/hibermachy-remove-XXXXXX")
trap 'rm -rf "$root"' EXIT

seed() {
  rm -rf "$root"/*
  mkdir -p "$root/plugin" "$root/helper" "$root/user" "$root/etc/systemd/sleep.conf.d"
  printf '%s\n' '{"schemaVersion":1,"id":"dev.hibermachy","version":"0.1.0","protocol":{"min":1,"max":1},"kinds":["service","panel"]}' > "$root/plugin/manifest.json"
  printf '%s\n' '{"enabled":true}' > "$root/activation.json"
  printf '%s\n' 'owner=alice' > "$root/installation-owner"
  printf '%s\n' 'package=hibermachy-helper version=0.1.0' > "$root/helper/package"
  printf '%s\n' 'owner=pacman' > "$root/helper/package.owner"
  printf '%s\n' 'protocol-min=1 protocol-max=1' > "$root/helper/protocol"
  printf '%s\n' '{"schemaVersion":1,"revision":1,"automaticPolicyEnablement":false,"idleDelaySeconds":1800}' > "$root/user/config.json"
  printf '%s\n' '{"version":1}' > "$root/user/state.json"
  printf '%s\n' '# Managed by Hibermachy. Do not edit.' '[Sleep]' 'HibernateDelaySec=3600s' 'HibernateOnACPower=no' > "$root/etc/systemd/sleep.conf.d/90-hibermachy.conf"
  printf '%s\n' 'owner=system' 'mode=600' 'links=1' > "$root/etc/systemd/sleep.conf.d/90-hibermachy.conf.owner"
  printf '%s\n' '{"setup.hibermachy":{"managedBy":"hibermachy"},"system.hibermachy-staged-sleep":{"managedBy":"hibermachy"}}' > "$root/menu.jsonc"
}

assert_warnings() {
  node -e 'const x=JSON.parse(process.argv[1]); if (!Array.isArray(x.warnings) || !x.warnings.some(w => w.includes("not Hibermachy uninstall")) || !x.warnings.some(w => w.includes("Machine-wide requested system policy remains effective"))) process.exit(1)' "$1"
}

seed
printf '%s\n' 'accepted=true confirmation=explicit' > "$root/quattro-disable"
disabled=$($command_path disable --root "$root")
node -e 'const x=JSON.parse(process.argv[1]); if (x.kind!=="accepted" || x.operation!=="disable" || x.activation!=="disabled" || x.policyMutation!==false || x.inventory.scopes.checkout.state!=="compatible") process.exit(1)' "$disabled"
assert_warnings "$disabled"
[[ $(jq -r .enabled "$root/activation.json") == false ]]
[[ -e "$root/plugin/manifest.json" && -e "$root/helper/package" && -e "$root/user/config.json" && -e "$root/etc/systemd/sleep.conf.d/90-hibermachy.conf" ]]

seed
printf '%s\n' 'accepted=true confirmation=explicit' > "$root/quattro-disable"
printf '%s\n' 'accepted=true confirmation=explicit disabled=true' > "$root/quattro-remove"
removed=$($command_path remove --root "$root")
node -e 'const x=JSON.parse(process.argv[1]); if (x.kind!=="accepted" || x.operation!=="plugin-removal" || x.inventory.scopes.checkout.state!=="missing" || x.policyMutation!==false) process.exit(1)' "$removed"
assert_warnings "$removed"
[[ ! -e "$root/plugin" && -e "$root/helper/package" && -e "$root/user/config.json" && -e "$root/etc/systemd/sleep.conf.d/90-hibermachy.conf" ]]

seed
printf '%s\n' 'accepted=false confirmation=cancelled' > "$root/quattro-disable"
set +e; cancelled=$($command_path disable --root "$root" 2>&1); code=$?; set -e
[[ $code -ne 0 ]]
node -e 'const x=JSON.parse(process.argv[1]); if (x.kind!=="declined" || x.operation!=="disable" || x.activation!=="enabled" || x.nativeDelegation!=="quattro" || x.policyMutation!==false || !x.inventory.scopes.requested_system_policy || x.inventory.scopes.checkout.state!=="compatible" || !x.warnings.some(w => w.includes("not Hibermachy uninstall"))) process.exit(1)' "$cancelled"
[[ $(jq -r .enabled "$root/activation.json") == true ]]

seed
printf '%s\n' 'accepted=true confirmation=explicit' > "$root/quattro-disable"
printf '%s\n' 'accepted=true confirmation=explicit disabled=true partial=true' > "$root/quattro-remove"
set +e; partial=$($command_path remove --root "$root" 2>&1); code=$?; set -e
[[ $code -ne 0 ]]
node -e 'const x=JSON.parse(process.argv[1]); if (x.kind!=="partial" || x.operation!=="plugin-removal" || x.activation!=="disabled" || x.nativeDelegation!=="quattro" || x.policyMutation!==false || x.inventory.scopes.checkout.state!=="compatible" || x.inventory.scopes.helper_package.state!=="compatible" || x.inventory.scopes.requested_system_policy.state!=="compatible" || !x.warnings.some(w => w.includes("not Hibermachy uninstall")) || !x.warnings.some(w => w.includes("incomplete"))) process.exit(1)' "$partial"
[[ -e "$root/plugin/manifest.json" && $(jq -r .enabled "$root/activation.json") == false ]]

printf '%s\n' 'HBR-CHK-LIFECYCLE-008 disable/remove preserve scopes, warnings, cancellation, and partial recovery'
