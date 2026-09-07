#!/usr/bin/env bash
set -euo pipefail

command_path="$(cd "$(dirname "$0")/.." && pwd)/lifecycle/status"
fixture_root=$(mktemp -d "${TMPDIR:-/tmp}/hibermachy-lifecycle-XXXXXX")
trap 'rm -rf "$fixture_root"' EXIT

assert_scope() {
  local document=$1 scope=$2 expected=$3
  jq -e --arg scope "$scope" --arg expected "$expected" \
    '.scopes[$scope].state == $expected' <<<"$document" >/dev/null
}

assert_meaning() {
  local document=$1 meaning=$2
  jq -e --arg meaning "$meaning" '.glossary | index($meaning) != null' <<<"$document" >/dev/null
}

clean=$("$command_path" status --root "$fixture_root")
printf '%s\n' 'HBR-CHK-LIFECYCLE-001 clean independent inventory'
for scope in checkout activation menu_contribution helper_package helper_protocol automatic_policy_enablement user_configuration_state requested_system_policy owned_target; do
  assert_scope "$clean" "$scope" missing
done
jq -e '.installationOwner.state == "unrecognized"' <<<"$clean" >/dev/null
assert_meaning "$clean" 'plugin removal removes only the user-owned checkout'
assert_meaning "$clean" 'Hibermachy uninstall removes executable artifacts but retains user configuration and state'
assert_meaning "$clean" 'Hibermachy purge additionally removes retained user configuration and state'

mkdir -p "$fixture_root/plugin" "$fixture_root/user" "$fixture_root/etc/systemd/sleep.conf.d" "$fixture_root/helper"
printf '%s\n' '{"schemaVersion":1,"id":"dev.hibermachy","version":"0.1.0","protocol":{"min":1,"max":1},"kinds":["service","panel"]}' > "$fixture_root/plugin/manifest.json"
printf '%s\n' 'owner=alice' > "$fixture_root/installation-owner"
printf '%s\n' '{"enabled":false}' > "$fixture_root/activation.json"
printf '%s\n' '// unrelated JSONC comment
{"entries":[{"id":"setup.hibermachy","managedBy":"hibermachy","label":"Sleep & Hibernation","action":"open"},{"id":"system.hibermachy-staged-sleep","managedBy":"hibermachy","label":"Suspend then Hibernate","action":"requestStagedSleep"}]}' > "$fixture_root/menu.json"
printf '%s\n' 'package=hibermachy-helper version=0.1.0' > "$fixture_root/helper/package"
printf '%s\n' 'owner=pacman' > "$fixture_root/helper/package.owner"
printf '%s\n' 'protocol-min=1 protocol-max=1' > "$fixture_root/helper/protocol"
printf '%s\n' '{"schemaVersion":1,"revision":1,"automaticPolicyEnablement":false,"idleDelaySeconds":1800}' > "$fixture_root/user/config.json"
printf '%s\n' '{"version":1}' > "$fixture_root/user/state.json"
printf '%s\n' '# Managed by Hibermachy. Do not edit.
[Sleep]
HibernateDelaySec=3600s
HibernateOnACPower=no
' > "$fixture_root/etc/systemd/sleep.conf.d/90-hibermachy.conf"
printf '%s\n' 'owner=system
mode=600
links=1' > "$fixture_root/etc/systemd/sleep.conf.d/90-hibermachy.conf.owner"

complete=$("$command_path" status --root "$fixture_root")
printf '%s\n' 'HBR-CHK-LIFECYCLE-002 complete inventory'
for scope in checkout activation menu_contribution helper_package helper_protocol automatic_policy_enablement user_configuration_state requested_system_policy owned_target; do
  assert_scope "$complete" "$scope" compatible
done
jq -e '.installationOwner.state == "identified" and .installationOwner.artifacts == "user-owned" and .scopes.requested_system_policy.ownership == "machine-wide" and .scopes.owned_target.ownership == "machine-wide"' <<<"$complete" >/dev/null
jq -e '.scopes.activation.enabled == false' <<<"$complete" >/dev/null
jq -e '.scopes.automatic_policy_enablement.state == "compatible" and .scopes.automatic_policy_enablement.automaticPolicyEnablement == false' <<<"$complete" >/dev/null

printf '%s\n' '{"enabled":true}' > "$fixture_root/activation.json"
active=$("$command_path" status --root "$fixture_root")
jq -e '.scopes.activation.state == "compatible" and .scopes.activation.enabled == true' <<<"$active" >/dev/null

printf '%s\n' 'protocol-min=9 protocol-max=9' > "$fixture_root/helper/protocol"
version_mismatch=$("$command_path" status --root "$fixture_root")
jq -e '.scopes.helper_protocol.state == "mismatched" and .scopes.helper_protocol.helperReleaseVersion == "0.1.0" and .scopes.helper_protocol.checkoutReleaseVersion == "0.1.0"' <<<"$version_mismatch" >/dev/null
printf '%s\n' 'protocol-min=1 protocol-max=1' > "$fixture_root/helper/protocol"

printf '%s\n' 'HBR-CHK-LIFECYCLE-005 named partial inventories'
rm -rf "$fixture_root/plugin"
plugin_removed=$("$command_path" status --root "$fixture_root")
assert_scope "$plugin_removed" checkout missing
assert_scope "$plugin_removed" helper_package compatible
assert_scope "$plugin_removed" requested_system_policy compatible
assert_scope "$plugin_removed" user_configuration_state compatible
assert_scope "$plugin_removed" automatic_policy_enablement compatible

rm "$fixture_root/helper/package" "$fixture_root/helper/protocol"
helper_only=$("$command_path" status --root "$fixture_root")
assert_scope "$helper_only" helper_package missing
assert_scope "$helper_only" helper_protocol missing
assert_scope "$helper_only" requested_system_policy compatible

rm "$fixture_root/etc/systemd/sleep.conf.d/90-hibermachy.conf"
policy_only=$("$command_path" status --root "$fixture_root")
assert_scope "$policy_only" requested_system_policy missing
assert_scope "$policy_only" user_configuration_state compatible

printf '%s\n' 'HBR-CHK-LIFECYCLE-003 independently reports partial and actionable states'
printf '%s\n' 'protocol-min=9 protocol-max=9' > "$fixture_root/helper/protocol"
printf '%s\n' 'administrator-owned content' > "$fixture_root/etc/systemd/sleep.conf.d/90-hibermachy.conf"
printf '%s\n' '{"entries":[{"id":"setup.hibermachy","label":"user-owned collision"}]}' > "$fixture_root/menu.json"
partial=$("$command_path" status --root "$fixture_root")
assert_scope "$partial" checkout missing
assert_scope "$partial" helper_package missing
assert_scope "$partial" helper_protocol mismatched
assert_scope "$partial" menu_contribution colliding
assert_scope "$partial" requested_system_policy unrecognized
jq -e '.scopes.owned_target.state == "unrecognized"' <<<"$partial" >/dev/null
jq -e '.scopes.helper_protocol.helperProtocolMin == 9 and .scopes.helper_protocol.helperProtocolMax == 9 and .scopes.helper_protocol.checkoutProtocolMin == null and .scopes.helper_protocol.checkoutProtocolMax == null' <<<"$partial" >/dev/null
jq -e '(.scopes.checkout.recovery | length > 0) and (.scopes.menu_contribution.recovery | length > 0) and (.scopes.requested_system_policy.recovery | length > 0)' <<<"$partial" >/dev/null

mkdir -p "$fixture_root/plugin"
ln -s missing-manifest "$fixture_root/plugin/manifest.json"
inaccessible=$("$command_path" status --root "$fixture_root")
assert_scope "$inaccessible" checkout inaccessible
rm -rf "$fixture_root/plugin"
printf '%s\n' '{"entries":[{"id":"setup.hibermachy","managedBy":"hibermachy","label":"Changed by user","action":"open"}]}' > "$fixture_root/menu.json"
modified=$("$command_path" status --root "$fixture_root")
assert_scope "$modified" menu_contribution modified
ln -s menu.json "$fixture_root/menu-link.json"
rm "$fixture_root/menu.json"
mv "$fixture_root/menu-link.json" "$fixture_root/menu.json"
symlink_menu=$("$command_path" status --root "$fixture_root")
assert_scope "$symlink_menu" menu_contribution inaccessible
rm "$fixture_root/menu.json"
rm "$fixture_root/user/state.json"
incomplete=$("$command_path" status --root "$fixture_root")
assert_scope "$incomplete" user_configuration_state incomplete

printf '%s\n' 'HBR-CHK-LIFECYCLE-004 retained data and named lifecycle meanings'
jq -e '(.scopes.user_configuration_state.state == "incomplete") and ((.scopes.user_configuration_state.recovery | length) > 0)' <<<"$incomplete" >/dev/null
assert_meaning "$partial" 'plugin activation is distinct from automatic-policy enablement'
