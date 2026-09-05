#!/usr/bin/env bash
set -euo pipefail

plugin_id='dev.hibermachy'
test_root=$(mktemp -d "${TMPDIR:-/tmp}/hibermachy-quattro-host-XXXXXX")
policy_path="$test_root/xdg-config/hibermachy/user-policy.json"
host_pid=''

cleanup() {
  local status=$?
  if (( status != 0 )) && [[ -f "$test_root/host.log" ]]; then
    sed -n '1,240p' "$test_root/host.log" >&2
  fi
  if [[ -n "$host_pid" ]] && kill -0 "$host_pid" 2>/dev/null; then
    kill "$host_pid" || true
    wait "$host_pid" 2>/dev/null || true
  fi
  chmod 700 "${policy_path%/*}" 2>/dev/null || true
  rm -rf "$test_root"
  exit "$status"
}
trap cleanup EXIT

mkdir -p "$test_root/.config/omarchy/plugins"
cp -R plugin "$test_root/.config/omarchy/plugins/$plugin_id"
printf '%s\n' '{"version":1,"plugins":[]}' > "$test_root/.config/omarchy/shell.json"

HOME="$test_root" XDG_CONFIG_HOME="$test_root/xdg-config" OMARCHY_PATH=/usr/share/omarchy quickshell --path /usr/share/omarchy/shell --no-color > "$test_root/host.log" 2>&1 &
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
  printf 'last policy: %s\nlast status: %s\nfile: ' "$result" "$(call "$plugin_id" status 2>/dev/null || true)" >&2
  sed -n '1,40p' "$policy_path" >&2 || true
  return 1
}

user_policy_json() {
  local result=''
  for _ in $(seq 1 50); do
    result=$(call "$plugin_id" userPolicy 2>/dev/null || true)
    if [[ "$result" == *'"revision"'* ]]; then
      printf '%s\n' "$result"
      return 0
    fi
    sleep 0.1
  done
  return 1
}

assert_safe_user_policy() {
  node -e '
    const policy = JSON.parse(process.argv[1]);
    if (policy.version !== 1 || policy.revision !== 1 || policy.automaticPolicyEnabled !== false || policy.idleDelaySeconds !== 1800) process.exit(1);
  ' "$1"
}

assert_receipt() {
  node -e '
    const receipt = JSON.parse(process.argv[1]);
    if (receipt.accepted !== (process.argv[2] === "true") || receipt.reasonCode !== process.argv[3]) process.exit(1);
  ' "$1" "$2" "$3"
}

wait_for_policy() {
  local revision=$1 enabled=$2 delay=$3 result=''
  for _ in $(seq 1 50); do
    result=$(user_policy_json)
    if node -e '
      const p = JSON.parse(process.argv[1]);
      if (p.revision !== Number(process.argv[2]) || p.automaticPolicyEnabled !== (process.argv[3] === "true") || p.idleDelaySeconds !== Number(process.argv[4])) process.exit(1);
    ' "$result" "$revision" "$enabled" "$delay"; then
      printf '%s\n' "$result"
      return 0
    fi
    sleep 0.1
  done
  printf 'last policy: %s\nlast status: %s\nfile: ' "$result" "$(call "$plugin_id" status 2>/dev/null || true)" >&2
  sed -n '1,40p' "$policy_path" >&2 || true
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

printf '%s\n' 'HBR-CHK-POLICY-001 first load persists safe defaults'
policy=$(user_policy_json)
assert_safe_user_policy "$policy"
node -e '
  const fs = require("fs");
  const policy = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
  if (policy.version !== 1 || policy.revision !== 1 || policy.automaticPolicyEnabled !== false || policy.idleDelaySeconds !== 1800) process.exit(1);
' "$policy_path"

printf '%s\n' 'HBR-CHK-POLICY-002 saves exact whole-second drafts and rejects stale revisions'
receipt=$(call "$plugin_id" saveUserPolicy '{"baseRevision":1,"automaticPolicyEnabled":true,"idleDelaySeconds":301}')
assert_receipt "$receipt" true HBR-POLICY-SAVED
policy=$(wait_for_policy 2 true 301)
receipt=$(call "$plugin_id" saveUserPolicy '{"baseRevision":1,"automaticPolicyEnabled":false,"idleDelaySeconds":1800}')
assert_receipt "$receipt" false HBR-POLICY-STALE

printf '%s\n' 'HBR-CHK-POLICY-003 accepts both idle-delay bounds'
call "$plugin_id" saveUserPolicy '{"baseRevision":2,"automaticPolicyEnabled":true,"idleDelaySeconds":300}' >/dev/null
wait_for_policy 3 true 300 >/dev/null
call "$plugin_id" saveUserPolicy '{"baseRevision":3,"automaticPolicyEnabled":true,"idleDelaySeconds":86400}' >/dev/null
wait_for_policy 4 true 86400 >/dev/null

# V1 is Hibermachy's first shipped user-policy schema, so there is no older
# migration path to execute. This permanent V1 fixture and the newer-schema
# fixture below document that migration non-applicability at the hosted seam.
printf '%s\n' 'HBR-CHK-POLICY-004 first-schema fixture canonicalizes as a new revision (pre-V1 migration N/A)'
printf '%s' '{ "idleDelaySeconds": 721, "automaticPolicyEnabled": false, "revision": 4, "version": 1 }' > "$policy_path"
wait_for_policy 5 false 721 >/dev/null
node -e '
  const fs = require("fs");
  const actual = fs.readFileSync(process.argv[1], "utf8");
  const expected = "{\n  \"version\": 1,\n  \"revision\": 5,\n  \"automaticPolicyEnabled\": false,\n  \"idleDelaySeconds\": 721\n}\n";
  if (actual !== expected) { console.error("canonical mismatch:\n" + JSON.stringify(actual)); process.exit(1); }
' "$policy_path"

printf '%s\n' 'HBR-CHK-POLICY-005 differing external revision conflicts without repair'
conflict='{"version":1,"revision":6,"automaticPolicyEnabled":false,"idleDelaySeconds":721}'
printf '%s' "$conflict" > "$policy_path"
sleep 0.3
[[ $(<"$policy_path") == "$conflict" ]]
status=$(status_json)
node -e 'const s=JSON.parse(process.argv[1]); if (s.reasonCode!=="HBR-POLICY-REVISION-CONFLICT") process.exit(1)' "$status"

printf '%s\n' 'HBR-CHK-POLICY-006 malformed policy stays untouched and disarmed until reset'
printf '%s' '{"version":1,"revision":5,"automaticPolicyEnabled":true}' > "$policy_path"
sleep 0.3
before=$(sha256sum "$policy_path")
call shell summon "$plugin_id" '{}'
call shell hide "$plugin_id"
call "$plugin_id" requestManualStagedSleep >/dev/null
after=$(sha256sum "$policy_path")
[[ "$before" == "$after" ]]
status=$(status_json)
node -e '
  const status = JSON.parse(process.argv[1]);
  if (status.automaticPolicyEnablement !== "disabled" || status.reasonCode !== "HBR-POLICY-KEYS") process.exit(1);
' "$status"
receipt=$(call "$plugin_id" resetUserPolicy)
assert_receipt "$receipt" true HBR-POLICY-RESET
wait_for_policy 6 false 1800 >/dev/null

printf '%s\n' 'HBR-CHK-POLICY-007 rejects invalid and newer migration fixtures without repair'
for invalid in \
  '{"version":2,"revision":6,"automaticPolicyEnabled":true,"idleDelaySeconds":1800}' \
  '{"version":1,"revision":6,"automaticPolicyEnabled":true,"idleDelaySeconds":299}' \
  '{"version":1,"revision":6,"automaticPolicyEnabled":true,"idleDelaySeconds":86401,"unknown":1}'; do
  printf '%s' "$invalid" > "$policy_path"
  sleep 0.2
  [[ $(<"$policy_path") == "$invalid" ]]
done
duplicate='{"version":1,"revision":6,"revision":6,"automaticPolicyEnabled":false,"idleDelaySeconds":1800}'
printf '%s' "$duplicate" > "$policy_path"
sleep 0.2
[[ $(<"$policy_path") == "$duplicate" ]]
status=$(status_json)
node -e 'const s=JSON.parse(process.argv[1]); if (s.reasonCode!=="HBR-POLICY-DUPLICATE-KEY") process.exit(1)' "$status"
call "$plugin_id" resetUserPolicy >/dev/null
wait_for_policy 7 false 1800 >/dev/null

printf '%s\n' 'HBR-CHK-POLICY-008 deterministic property samples reject invalid mutation values'
for invalid_request in \
  '{"baseRevision":7,"automaticPolicyEnabled":false,"idleDelaySeconds":-1}' \
  '{"baseRevision":7,"automaticPolicyEnabled":false,"idleDelaySeconds":300.5}' \
  '{"baseRevision":7,"automaticPolicyEnabled":"false","idleDelaySeconds":1800}' \
  '{"baseRevision":7,"automaticPolicyEnabled":false,"idleDelaySeconds":9007199254740992}'; do
  receipt=$(call "$plugin_id" saveUserPolicy "$invalid_request")
  assert_receipt "$receipt" false HBR-POLICY-MUTATION-INVALID
done
property_seed=1701
for _ in $(seq 1 24); do
  property_seed=$(( (property_seed * 1103515245 + 12345) & 2147483647 ))
  invalid_delay=$((86401 + property_seed))
  receipt=$(call "$plugin_id" saveUserPolicy "{\"baseRevision\":7,\"automaticPolicyEnabled\":false,\"idleDelaySeconds\":$invalid_delay}")
  assert_receipt "$receipt" false HBR-POLICY-MUTATION-INVALID
done

printf '%s\n' 'HBR-CHK-POLICY-009 concurrent mutations serialize at one revision'
call "$plugin_id" saveUserPolicy '{"baseRevision":7,"automaticPolicyEnabled":true,"idleDelaySeconds":700}' > "$test_root/receipt-a" &
receipt_a_pid=$!
call "$plugin_id" saveUserPolicy '{"baseRevision":7,"automaticPolicyEnabled":true,"idleDelaySeconds":701}' > "$test_root/receipt-b" &
receipt_b_pid=$!
wait "$receipt_a_pid" "$receipt_b_pid"
node -e '
  const fs = require("fs");
  const receipts = ["receipt-a", "receipt-b"].map(name => JSON.parse(fs.readFileSync(process.argv[1] + "/" + name, "utf8")));
  if (receipts.filter(r => r.accepted).length !== 1 || receipts.filter(r => !r.accepted).length !== 1) process.exit(1);
' "$test_root"
for expected_delay in 700 701; do
  if wait_for_policy 8 true "$expected_delay" >/dev/null 2>&1; then break; fi
done
policy=$(user_policy_json)
node -e 'const p=JSON.parse(process.argv[1]); if (p.revision!==8 || ![700,701].includes(p.idleDelaySeconds)) process.exit(1)' "$policy"

printf '%s\n' 'HBR-CHK-POLICY-010 byte and UTF-8 failures stay untouched and disarm automation'
node -e 'require("fs").writeFileSync(process.argv[1], Buffer.alloc(16385, 0x20))' "$policy_path"
sleep 0.3
status=$(status_json)
node -e 'const s=JSON.parse(process.argv[1]); if (s.reasonCode!=="HBR-POLICY-SIZE" || s.automaticPolicyEnablement!=="disabled") process.exit(1)' "$status"
node -e 'require("fs").writeFileSync(process.argv[1], Buffer.from([0xff]))' "$policy_path"
sleep 0.3
status=$(status_json)
node -e 'const s=JSON.parse(process.argv[1]); if (s.reasonCode!=="HBR-POLICY-ENCODING" || s.automaticPolicyEnablement!=="disabled") process.exit(1)' "$status"
printf '\357\273\277%s' '{"version":1,"revision":8,"automaticPolicyEnabled":false,"idleDelaySeconds":1800}' > "$policy_path"
sleep 0.3
status=$(status_json)
node -e 'const s=JSON.parse(process.argv[1]); if (s.reasonCode!=="HBR-POLICY-ENCODING") process.exit(1)' "$status"
call "$plugin_id" resetUserPolicy >/dev/null
wait_for_policy 9 false 1800 >/dev/null

printf '%s\n' 'HBR-CHK-POLICY-011 atomic replacement failure preserves the current snapshot'
chmod 500 "${policy_path%/*}"
receipt=$(call "$plugin_id" saveUserPolicy '{"baseRevision":9,"automaticPolicyEnabled":true,"idleDelaySeconds":900}')
assert_receipt "$receipt" false HBR-POLICY-PERSISTENCE
sleep 0.3
policy=$(user_policy_json)
node -e 'const p=JSON.parse(process.argv[1]); if (p.revision!==9 || p.automaticPolicyEnabled!==false) process.exit(1)' "$policy"
status=$(status_json)
node -e 'const s=JSON.parse(process.argv[1]); if (s.reasonCode!=="HBR-POLICY-PERSISTENCE" || s.automaticPolicyEnablement!=="disabled") process.exit(1)' "$status"
chmod 700 "${policy_path%/*}"
call "$plugin_id" resetUserPolicy >/dev/null
wait_for_policy 10 false 1800 >/dev/null

printf '%s\n' 'HBR-CHK-POLICY-012 revision exhaustion returns the current snapshot'
call shell setPluginEnabled "$plugin_id" false | grep -qx 'ok'
printf '%s\n' '{"version":1,"revision":9007199254740991,"automaticPolicyEnabled":false,"idleDelaySeconds":1800}' > "$policy_path"
call shell setPluginEnabled "$plugin_id" true | grep -qx 'ok'
wait_for_policy 9007199254740991 false 1800 >/dev/null
receipt=$(call "$plugin_id" saveUserPolicy '{"baseRevision":9007199254740991,"automaticPolicyEnabled":true,"idleDelaySeconds":1800}')
assert_receipt "$receipt" false HBR-POLICY-REVISION-EXHAUSTED
node -e 'const r=JSON.parse(process.argv[1]); if (r.policy.revision!==Number.MAX_SAFE_INTEGER) process.exit(1)' "$receipt"
receipt=$(call "$plugin_id" resetUserPolicy)
assert_receipt "$receipt" false HBR-POLICY-REVISION-EXHAUSTED

printf '%s\n' 'HBR-CHK-PLUGIN-003 summon and hide'
call shell summon "$plugin_id" '{}' >/dev/null
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
