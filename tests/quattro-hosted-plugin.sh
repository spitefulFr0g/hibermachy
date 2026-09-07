#!/usr/bin/env bash
set -euo pipefail

plugin_id='dev.hibermachy'
test_root=$(mktemp -d "${TMPDIR:-/tmp}/hibermachy-quattro-host-XXXXXX")
host_pid=''

cleanup() {
  if [[ -n "$host_pid" ]] && kill -0 "$host_pid" 2>/dev/null; then
    kill "$host_pid" || true
    wait "$host_pid" 2>/dev/null || true
  fi
  rm -rf "$test_root"
}
trap cleanup EXIT

mkdir -p "$test_root/.config/omarchy/plugins"
cp -R plugin "$test_root/.config/omarchy/plugins/$plugin_id"
printf '%s\n' '{"version":1,"plugins":[]}' > "$test_root/.config/omarchy/shell.json"

HOME="$test_root" OMARCHY_PATH=/usr/share/omarchy quickshell --path /usr/share/omarchy/shell --no-color > "$test_root/host.log" 2>&1 &
host_pid=$!

call() {
  quickshell ipc --pid "$host_pid" call -- "$@"
}

plugins_json() {
  local result=''
  for _ in $(seq 1 50); do
    result=$(call shell listPlugins 2>/dev/null || true)
    if [[ "$result" == \[* ]]; then
      printf '%s\n' "$result"
      return 0
    fi
    sleep 0.1
  done
  return 1
}

status_json() {
  local result=''
  for _ in $(seq 1 50); do
    result=$(call "$plugin_id" status 2>/dev/null || true)
    if [[ "$result" == \{* ]]; then
      printf '%s\n' "$result"
      return 0
    fi
    sleep 0.1
  done
  return 1
}

assert_disabled_status() {
  node -e '
    const status = JSON.parse(process.argv[1]);
    if (status.pluginActivation !== "active" || status.automaticPolicyEnablement !== "disabled" || status.automaticStagedSleepReadiness !== "not-ready") process.exit(1);
  ' "$1"
}

for _ in $(seq 1 50); do
  if call shell ping >/dev/null 2>&1 && call shell listPlugins >/dev/null 2>&1; then break; fi
  sleep 0.1
done
call shell ping | grep -qx 'ok'

plugins=$(plugins_json)
printf '%s\n' 'HBR-CHK-PLUGIN-001 disabled-first discovery'
node -e '
  const plugins = JSON.parse(process.argv[1]);
  const plugin = plugins.find((entry) => entry.id === "dev.hibermachy");
  if (!plugin || plugin.enabled !== false) process.exit(1);
' "$plugins"

call shell setPluginEnabled "$plugin_id" true | grep -qx 'ok'
status=$(status_json)
printf '%s\n' 'HBR-CHK-PLUGIN-002 activation remains inert'
assert_disabled_status "$status"

printf '%s\n' 'HBR-CHK-PLUGIN-003 summon and hide'
call shell summon "$plugin_id" '{}'
call shell hide "$plugin_id"
call shell rescanPlugins
plugins=$(plugins_json)
status=$(status_json)
printf '%s\n' 'HBR-CHK-PLUGIN-004 reload recreates inert service'
assert_disabled_status "$status"
call shell setPluginEnabled "$plugin_id" false | grep -qx 'ok'
plugins=$(plugins_json)
printf '%s\n' 'HBR-CHK-PLUGIN-005 disable removes activation'
node -e '
  const plugin = JSON.parse(process.argv[1]).find((entry) => entry.id === "dev.hibermachy");
  if (!plugin || plugin.enabled !== false) process.exit(1);
' "$plugins"
call shell setPluginEnabled "$plugin_id" true | grep -qx 'ok'

status=$(status_json)
printf '%s\n' 'HBR-CHK-PLUGIN-006 recreation remains inert'
assert_disabled_status "$status"
