#!/usr/bin/env bash
set -euo pipefail

command_path="$(cd "$(dirname "$0")/.." && pwd)/lifecycle/install"
status_path="$(cd "$(dirname "$0")/.." && pwd)/lifecycle/status"
fixture_root=$(mktemp -d "${TMPDIR:-/tmp}/hibermachy-update-XXXXXX")
trap 'rm -rf "$fixture_root"' EXIT

make_fixture() {
  rm -rf "$fixture_root"/*
  mkdir -p "$fixture_root/plugin" "$fixture_root/etc/systemd/sleep.conf.d"
  printf '%s\n' '{"schemaVersion":1,"id":"dev.hibermachy","version":"0.1.0","protocol":{"min":1,"max":1},"kinds":["service","panel"]}' > "$fixture_root/plugin/manifest.json"
  printf '%s\n' 'compatible=true' > "$fixture_root/quattro-contract"
  printf '%s\n' 'reviewed=true' > "$fixture_root/native-plugin-review"
  printf '%s\n' 'reviewed=true' > "$fixture_root/native-plugin-update"
  printf '%s\n' '{"schemaVersion":1,"id":"dev.hibermachy","version":"0.2.0","protocol":{"min":1,"max":1},"kinds":["service","panel"]}' > "$fixture_root/updated-plugin-manifest.json"
  printf '%s\n' 'success=true user=unprivileged source=immutable signature=valid checksum=valid' > "$fixture_root/helper-build"
  printf '%s\n' 'success=true authorization=interactive' > "$fixture_root/package-install"
  printf '%s\n' 'compatible=true' > "$fixture_root/probes"
  printf '%s\n' 'compatible=true' > "$fixture_root/protocol-probe"
  printf '%s\n' '{' '  "unrelated":{"label":"Keep"}' '}' > "$fixture_root/menu.jsonc"
  printf '%s\n' "{\"enabled\":$1}" > "$fixture_root/activation.json"
}

assert_update_success() {
  local result=$1 expected_activation=$2
  node -e 'const x=JSON.parse(process.argv[1]); if (x.kind!=="accepted" || x.operation!=="update" || x.activation!==process.argv[2] || x.policyMutation!==false || x.automaticAcceptance!==false || x.helper!=="upgraded" || x.menu!=="reconciled" || x.probes!=="rerun") process.exit(1)' "$result" "$expected_activation"
}

make_fixture true
active=$($command_path update --root "$fixture_root")
assert_update_success "$active" enabled
[[ $(jq -r .enabled "$fixture_root/activation.json") == true ]]
[[ ! -e "$fixture_root/update-intent.json" ]]
[[ $(jq -r .version "$fixture_root/plugin/manifest.json") == 0.2.0 ]]
[[ $(sed -n 's/^package=hibermachy-helper version=//p' "$fixture_root/helper/package") == 0.2.0 ]]
jq -e '."setup.hibermachy".managedBy == "hibermachy" and ."system.hibermachy-staged-sleep".managedBy == "hibermachy"' < <(sed -E 's@//[^"].*$@@' "$fixture_root/menu.jsonc") >/dev/null
rerun=$($command_path update --root "$fixture_root")
assert_update_success "$rerun" enabled
[[ $(jq -r .enabled "$fixture_root/activation.json") == true ]]

make_fixture false
disabled=$($command_path update --root "$fixture_root")
assert_update_success "$disabled" disabled
[[ $(jq -r .enabled "$fixture_root/activation.json") == false ]]

make_fixture true
rm "$fixture_root/native-plugin-update"
set +e; interrupted=$($command_path update --root "$fixture_root" 2>&1); code=$?; set -e
[[ $code -ne 0 && $interrupted == *'HBR-NATIVE-UPDATE-REVIEW-REQUIRED'* ]]
[[ $(jq -r .enabled "$fixture_root/activation.json") == false ]]
jq -e '.priorActivation == "enabled" and .phase == "disabled"' "$fixture_root/update-intent.json" >/dev/null
status=$($status_path status --root "$fixture_root")
jq -e '.lifecycle.operation == "update" and .lifecycle.phase == "disabled"' <<<"$status" >/dev/null
printf '%s\n' 'reviewed=true' > "$fixture_root/native-plugin-update"
resumed=$($command_path update --root "$fixture_root")
assert_update_success "$resumed" enabled

make_fixture true
printf '%s\n' 'reviewed=true autoAccept=true' > "$fixture_root/native-plugin-update"
set +e; auto_accept=$($command_path update --root "$fixture_root" 2>&1); code=$?; set -e
[[ $code -ne 0 && $auto_accept == *'HBR-NATIVE-UPDATE-AUTO-ACCEPT'* ]]
[[ $(jq -r .enabled "$fixture_root/activation.json") == false ]]

make_fixture true
printf '%s\n' 'success=true user=unprivileged source=immutable signature=invalid checksum=valid' > "$fixture_root/helper-build"
set +e; helper_failure=$($command_path update --root "$fixture_root" 2>&1); code=$?; set -e
[[ $code -ne 0 && $helper_failure == *'HBR-HELPER-BUILD-FAILED'* ]]
[[ $(jq -r .enabled "$fixture_root/activation.json") == false ]]

make_fixture true
printf '%s\n' 'success=true authorization=cancelled' > "$fixture_root/package-install"
set +e; package_cancel=$($command_path update --root "$fixture_root" 2>&1); code=$?; set -e
[[ $code -ne 0 && $package_cancel == *'HBR-PACKAGE-INSTALL-FAILED'* ]]
[[ $(jq -r .enabled "$fixture_root/activation.json") == false ]]

make_fixture true
printf '%s\n' '{"setup.hibermachy":{"managedBy":"other"}}' > "$fixture_root/menu.jsonc"
set +e; menu_conflict=$($command_path update --root "$fixture_root" 2>&1); code=$?; set -e
[[ $code -ne 0 && $menu_conflict == *'HBR-MENU-ID-COLLISION'* ]]
[[ $(jq -r .enabled "$fixture_root/activation.json") == false ]]

make_fixture true
printf '%s\n' 'compatible=false' > "$fixture_root/probes"
set +e; probe_failure=$($command_path update --root "$fixture_root" 2>&1); code=$?; set -e
[[ $code -ne 0 && $probe_failure == *'HBR-INTEGRATION-PROBES-INCOMPLETE'* ]]
[[ $(jq -r .enabled "$fixture_root/activation.json") == false ]]

make_fixture true
printf '%s\n' 'compatible=false' > "$fixture_root/protocol-probe"
set +e; protocol_failure=$($command_path update --root "$fixture_root" 2>&1); code=$?; set -e
[[ $code -ne 0 && $protocol_failure == *'HBR-PROTOCOL-MISMATCH'* ]]
[[ $(jq -r .enabled "$fixture_root/activation.json") == false ]]

printf '%s\n' 'HBR-CHK-LIFECYCLE-007 update intent, partial completion, and safe rerun'
