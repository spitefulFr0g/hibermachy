#!/usr/bin/env bash
set -euo pipefail

if [[ "${HIBERMACHY_MATRIX_CASE:-}" != '1' ]]; then
  env HIBERMACHY_MATRIX_CASE=1 HIBERMACHY_EXPECTED_KIND=accepted HIBERMACHY_EXPECTED_MODE=suspend-then-hibernate "$0"
  env HIBERMACHY_MATRIX_CASE=1 HIBERMACHY_SIM_STAGED_SLEEP=0 HIBERMACHY_EXPECTED_KIND=accepted HIBERMACHY_EXPECTED_MODE=suspend "$0"
  env HIBERMACHY_MATRIX_CASE=1 HIBERMACHY_SIM_STAGED_SLEEP=0 HIBERMACHY_SIM_SUSPEND=0 HIBERMACHY_EXPECTED_KIND=refused "$0"
  env HIBERMACHY_MATRIX_CASE=1 HIBERMACHY_SIM_SYSTEM_INHIBITED=1 HIBERMACHY_EXPECTED_KIND=refused "$0"
  env HIBERMACHY_MATRIX_CASE=1 HIBERMACHY_SIM_OBSERVATION_FAILURE=1 HIBERMACHY_EXPECTED_KIND=failed "$0"
  env HIBERMACHY_MATRIX_CASE=1 HIBERMACHY_SIM_CONTRACT=missing HIBERMACHY_EXPECTED_KIND=failed "$0"
  env HIBERMACHY_MATRIX_CASE=1 HIBERMACHY_SIM_CONTRACT=later HIBERMACHY_EXPECTED_KIND=accepted HIBERMACHY_EXPECTED_MODE=suspend-then-hibernate "$0"
  env HIBERMACHY_MATRIX_CASE=1 HIBERMACHY_SIM_EVIDENCE=unit-failure HIBERMACHY_EXPECTED_KIND=accepted "$0"
  env HIBERMACHY_MATRIX_CASE=1 HIBERMACHY_SIM_EVIDENCE=missing HIBERMACHY_EXPECTED_KIND=accepted "$0"
  env HIBERMACHY_MATRIX_CASE=1 HIBERMACHY_SIM_SUPPRESSION_REASON=HBR-IDLE-STAY-AWAKE "$0"
  env HIBERMACHY_MATRIX_CASE=1 HIBERMACHY_SEED_OPEN_BOOT=prior-boot "$0"
  exit 0
fi

plugin_id='dev.hibermachy'
printf '%s\n' 'HBR-CHK-PANEL-001 native panel exposes the accessible single-sheet contract'
rg -q 'Flickable' plugin/Panel.qml
rg -q 'PanelHero' plugin/Panel.qml
rg -q 'Automatic staged sleep' plugin/Panel.qml
rg -q 'System policy' plugin/Panel.qml
rg -q 'Current status' plugin/Panel.qml
rg -q 'Accessible\.name' plugin/Panel.qml
rg -q 'Accessible\.description' plugin/Panel.qml
! rg -q 'Accessible\.enabled' plugin/Panel.qml
rg -q 'Style\.space' plugin/Panel.qml
rg -q 'Color\.foreground' plugin/Panel.qml
rg -q 'Accessible\.announce' plugin/Panel.qml
rg -q 'ConfirmDialog' plugin/Panel.qml
rg -q 'PanelKeyCatcher' plugin/Panel.qml
rg -q 'resetHistory' plugin/Panel.qml
rg -q 'heroStatus' plugin/Service.qml
rg -q 'editSystemPolicyDraft' plugin/Panel.qml
rg -q 'onTabRequested' plugin/Panel.qml
rg -q 'onCloseRequested' plugin/Panel.qml
rg -q 'focusBeforeConfirmation' plugin/Panel.qml
rg -q 'accessibilityJourney' plugin/Panel.qml
rg -q 'sleepExecutabilitySummary' plugin/Service.qml
! rg -q 'automaticReadiness\(|manualReadiness\(|suspendFallbackAvailable\(' plugin/Panel.qml
! rg -q 'systemctl|helperPath|effectivePolicyReaderPath|contractProbePath' plugin/Panel.qml
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
  # IdleMonitor owns a Wayland object; let the disposable compositor/runtime
  # finish releasing it before the next matrix case starts.
  sleep 0.5
  chmod 700 "${policy_path%/*}" 2>/dev/null || true
  rm -rf "$test_root"
  exit "$status"
}
trap cleanup EXIT

mkdir -p "$test_root/.config/omarchy/plugins"
mkdir -p "$test_root/.local/state/hibermachy"
if [[ -n "${HIBERMACHY_SEED_OPEN_BOOT:-}" ]]; then
  node -e 'const fs=require("fs"); fs.writeFileSync(process.argv[1], JSON.stringify({schemaVersion:1,openAttempt:{attemptId:"prior-attempt",origin:"manual",selectedMode:"suspend-then-hibernate",bootId:process.argv[2]},terminalOutcomes:[],suppressionSummaries:[],notificationFingerprints:[]})+"\n")' "$test_root/.local/state/hibermachy/outcomes.json" "$HIBERMACHY_SEED_OPEN_BOOT"
fi
cp -R plugin "$test_root/.config/omarchy/plugins/$plugin_id"
printf '%s\n' '{"version":1,"plugins":[]}' > "$test_root/.config/omarchy/shell.json"

helper_fixture="$test_root/helper-fixture"
effective_fixture="$test_root/effective-policy-fixture"
contract_fixture="$test_root/contract-probe-fixture"
cat > "$helper_fixture" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ "$1" == apply ]]; then
  printf 'requested-delay-seconds=%s requested-hibernate-on-ac=%s\n' "$2" "$3"
elif [[ "$1" == reset ]]; then
  exit 0
elif [[ "$2" == apply ]]; then
  printf 'requested-delay-seconds=%s requested-hibernate-on-ac=%s\n' "$3" "$4"
elif [[ "$2" == reset ]]; then
  exit 0
else
  exit 1
fi
EOF
cat > "$effective_fixture" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' '/etc/systemd/sleep.conf.d/90-hibermachy.conf' '[Sleep]' 'HibernateDelaySec=9000s' 'HibernateOnACPower=no'
EOF
chmod 700 "$helper_fixture" "$effective_fixture"
cat > "$contract_fixture" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ "${HIBERMACHY_SIM_CONTRACT:-}" == missing ]]; then
  printf '%s\n' '{"compatible":false,"majorVersion":4,"shellReady":true,"pluginDiscovery":false}'
elif [[ "${HIBERMACHY_SIM_CONTRACT:-}" == later ]]; then
  printf '%s\n' '{"compatible":true,"laterVersion":true,"majorVersion":4,"shellReady":true,"pluginDiscovery":true,"pluginActivation":true,"manifestSchema":true,"ipcFeatures":true,"qmlFeatures":true,"idleMonitor":true,"helperProtocol":true,"userPolicy":true,"systemPolicy":true,"logind":true}'
else
  printf '%s\n' '{"compatible":true,"majorVersion":4,"shellReady":true,"pluginDiscovery":true,"pluginActivation":true,"manifestSchema":true,"ipcFeatures":true,"qmlFeatures":true,"idleMonitor":true,"helperProtocol":true,"userPolicy":true,"systemPolicy":true,"logind":true}'
fi
EOF
chmod 700 "$contract_fixture"

HOME="$test_root" XDG_CONFIG_HOME="$test_root/xdg-config" HBR_TEST_MODE=1 HBR_CONTRACT_PROBE="$contract_fixture" HBR_POLICY_HELPER_PATH="$helper_fixture" HBR_POLICY_HELPER_LAUNCHER="$helper_fixture" HBR_EFFECTIVE_POLICY_READER="$effective_fixture" OMARCHY_PATH=/usr/share/omarchy quickshell --path /usr/share/omarchy/shell --no-color > "$test_root/host.log" 2>&1 &
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

assert_system_policy_draft() {
  node -e '
    const status = JSON.parse(process.argv[1]);
    const draft = status.systemPolicyDraft;
    if (!draft || draft.hibernateDelaySeconds !== 7200 || draft.hibernateOnAcPower !== false
      || draft.scope !== "machine-wide" || status.requestedSystemPolicy !== null
      || status.effectiveSystemPolicy !== null) process.exit(1);
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
printf '%s\n' 'HBR-CHK-PANEL-002 panel summon and cancellation return through the hosted shell seam'
call shell summon "$plugin_id" '{}' >/dev/null
journey=$(call dev.hibermachy.panel-test accessibilityJourney)
node -e 'const j=JSON.parse(process.argv[1]); if (!j.accepted || !j.forward || !j.reverse || !j.confirmationOpened || !j.cancellationClosed || !j.focusRestored || !j.accessibleNames || !j.dirtyState || !j.disabledState || !j.statusAnnouncement || !j.nonColorStatus) process.exit(1)' "$journey"
call shell hide "$plugin_id"
printf '%s\n' 'HBR-CHK-PLUGIN-002 activation remains inert'
assert_disabled_status "$status"
printf '%s\n' 'HBR-CHK-READINESS-001 readiness operations remain independent and live state is exposed'
expected_manual='ready'
if [[ "${HIBERMACHY_SIM_CONTRACT:-}" == missing \
  || "${HIBERMACHY_SIM_SYSTEM_INHIBITED:-0}" == 1 \
  || "${HIBERMACHY_SIM_OBSERVATION_FAILURE:-0}" == 1 \
  || ("${HIBERMACHY_SIM_STAGED_SLEEP:-1}" == 0 && "${HIBERMACHY_SIM_SUSPEND:-1}" == 0) ]]; then
  expected_manual='not-ready'
fi
node -e '
  const s = JSON.parse(process.argv[1]);
  const keys = ["automaticStagedSleepReadiness", "manualStagedSleepReadiness", "systemPolicyReadiness", "diagnosticsReadiness", "sleepExecutability", "activeBlocker"];
  if (keys.some((key) => !(key in s))) process.exit(1);
  if (!s.sleepExecutability || typeof s.sleepExecutability.observationFailed !== "boolean") process.exit(1);
  if (s.automaticStagedSleepReadiness !== "not-ready" || s.manualStagedSleepReadiness !== process.argv[2]) process.exit(1);
' "$status" "$expected_manual"
printf '%s\n' 'HBR-CHK-SYSTEM-001 system policy starts as an independent unpersisted draft'
assert_system_policy_draft "$status"

if [[ "${HIBERMACHY_SIM_CONTRACT:-}" == missing ]]; then
  printf '%s\n' 'HBR-CHK-CONTRACT-001 incompatible contracts close only affected operations'
  node -e 'const s=JSON.parse(process.argv[1]); if(s.contractReadiness!=="not-ready"||s.contractReasonCode!=="HBR-CONTRACT-INCOMPATIBLE-AUTOMATIC")process.exit(1)' "$status"
  receipt=$(call "$plugin_id" requestStagedSleep)
  node -e 'const r=JSON.parse(process.argv[1]); if(r.kind!=="failed"||r.reasonCode!=="HBR-CONTRACT-INCOMPATIBLE-MANUAL")process.exit(1)' "$receipt"
  receipt=$(call "$plugin_id" applySystemPolicy)
  node -e 'const r=JSON.parse(process.argv[1]); if(r.accepted||r.reasonCode!=="HBR-CONTRACT-INCOMPATIBLE-SYSTEM-POLICY")process.exit(1)' "$receipt"
  exit 0
fi

if [[ "${HIBERMACHY_SIM_CONTRACT:-}" == later ]]; then
  printf '%s\n' 'HBR-CHK-CONTRACT-002 later verified feature probes remain usable'
  node -e 'const s=JSON.parse(process.argv[1]); if(s.contractReadiness!=="ready"||s.contractSnapshot.laterVersion!==true)process.exit(1)' "$status"
  exit 0
fi

printf '%s\n' 'HBR-CHK-SYSTEM-002 apply reviews and commits the complete pair'
call "$plugin_id" editSystemPolicyDraft 9000 false | node -e 'const r=JSON.parse(require("fs").readFileSync(0)); if (!r.accepted) process.exit(1)'
call "$plugin_id" reviewSystemPolicy | node -e 'const r=JSON.parse(require("fs").readFileSync(0)); if (!r.accepted || r.pair.hibernateDelaySeconds!==9000 || r.pair.hibernateOnAcPower!==false) process.exit(1)'
call "$plugin_id" setSystemPolicyFixture '{"authorization":"authorized","helper":"accepted","readback":"available","effective":{"hibernateDelaySeconds":9000,"hibernateOnAcPower":false},"provenance":["/etc/systemd/sleep.conf.d/90-hibermachy.conf"]}' >/dev/null
receipt=$(call "$plugin_id" applySystemPolicy)
node -e 'const r=JSON.parse(process.argv[1]); if (!r.accepted || r.reasonCode!=="HBR-SYSTEM-POLICY-SUBMITTED") process.exit(1)' "$receipt"
for _ in $(seq 1 50); do
  status=$(status_json)
  if node -e 'const s=JSON.parse(process.argv[1]); if (s.systemPolicyReasonCode!=="HBR-SYSTEM-POLICY-APPLIED") process.exit(1)' "$status"; then break; fi
  sleep 0.1
done
node -e 'const s=JSON.parse(process.argv[1]); if (!s.requestedSystemPolicy || !s.effectiveSystemPolicy || s.systemPolicyProvenance.length!==1) process.exit(1)' "$status"

printf '%s\n' 'HBR-CHK-SYSTEM-003 authentication cancellation does not replay or mutate requested policy'
call "$plugin_id" setSystemPolicyFixture '{"authorization":"cancelled","helper":"accepted","readback":"available"}' >/dev/null
receipt=$(call "$plugin_id" applySystemPolicy)
node -e 'const r=JSON.parse(process.argv[1]); if (r.accepted || r.reasonCode!=="HBR-SYSTEM-POLICY-AUTH-CANCELLED") process.exit(1)' "$receipt"
status=$(status_json)
node -e 'const s=JSON.parse(process.argv[1]); if (s.requestedSystemPolicy.hibernateDelaySeconds!==9000) process.exit(1)' "$status"

printf '%s\n' 'HBR-CHK-SYSTEM-004 denial, helper, write, and readback failures remain typed and non-replaying'
for fixture in \
  '{"authorization":"denied","helper":"accepted"}' \
  '{"authorization":"fixture","helper":"rejected"}' \
  '{"authorization":"fixture","helper":"accepted","write":"failed"}' \
  '{"authorization":"fixture","helper":"accepted","readback":"contradictory"}' \
  '{"authorization":"fixture","helper":"accepted","readback":"unavailable"}'; do
  call "$plugin_id" setSystemPolicyFixture "$fixture" >/dev/null
  receipt=$(call "$plugin_id" applySystemPolicy)
  node -e 'const r=JSON.parse(process.argv[1]); if (r.accepted) process.exit(1)' "$receipt"
done

printf '%s\n' 'HBR-CHK-SYSTEM-005 administrator precedence is effective-policy difference, not write failure'
call "$plugin_id" setSystemPolicyFixture '{"authorization":"fixture","helper":"accepted","readbackPolicy":{"hibernateDelaySeconds":9000,"hibernateOnAcPower":false},"effective":{"hibernateDelaySeconds":3600,"hibernateOnAcPower":true},"provenance":["/etc/systemd/sleep.conf.d/99-administrator.conf"]}' >/dev/null
receipt=$(call "$plugin_id" applySystemPolicy)
node -e 'const r=JSON.parse(process.argv[1]); if (!r.accepted || r.reasonCode!=="HBR-SYSTEM-POLICY-DIFFERS") process.exit(1)' "$receipt"
status=$(status_json)
node -e 'const s=JSON.parse(process.argv[1]); if (s.effectiveSystemPolicy.hibernateDelaySeconds!==3600 || s.systemPolicyProvenance[0]!=="/etc/systemd/sleep.conf.d/99-administrator.conf") process.exit(1)' "$status"

printf '%s\n' 'HBR-CHK-SYSTEM-006 only one privileged mutation is in flight'
call "$plugin_id" setSystemPolicyFixture '{"authorization":"authorized","helper":"accepted","busy":true}' >/dev/null
second=$(call "$plugin_id" applySystemPolicy)
node -e 'const r=JSON.parse(process.argv[1]); if (r.reasonCode!=="HBR-SYSTEM-POLICY-BUSY") process.exit(1)' "$second"
call "$plugin_id" setSystemPolicyFixture '{"authorization":"authorized","helper":"accepted"}' >/dev/null
first=$(call "$plugin_id" applySystemPolicy)
for _ in $(seq 1 50); do
  status=$(status_json)
  if node -e 'const s=JSON.parse(process.argv[1]); if (s.systemPolicyReasonCode!=="HBR-SYSTEM-POLICY-APPLIED") process.exit(1)' "$status"; then break; fi
  sleep 0.1
done

printf '%s\n' 'HBR-CHK-SYSTEM-007 reset is narrow and leaves effective administrator policy visible'
call "$plugin_id" setSystemPolicyFixture '{"authorization":"fixture","helper":"accepted"}' >/dev/null
receipt=$(call "$plugin_id" resetSystemPolicy)
node -e 'const r=JSON.parse(process.argv[1]); if (!r.accepted || r.reasonCode!=="HBR-SYSTEM-POLICY-RESET") process.exit(1)' "$receipt"
status=$(status_json)
node -e 'const s=JSON.parse(process.argv[1]); if (s.requestedSystemPolicy!==null || s.effectiveSystemPolicy!==null) process.exit(1)' "$status"

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

printf '%s\n' 'HBR-CHK-AUTO-001 automatic staged sleep waits for fresh activity after enablement'
if [[ "${HIBERMACHY_EXPECTED_KIND:-accepted}" == accepted \
  && "${HIBERMACHY_SIM_CONTRACT:-}" != missing \
  && "${HIBERMACHY_SIM_SYSTEM_INHIBITED:-0}" != 1 \
  && "${HIBERMACHY_SIM_OBSERVATION_FAILURE:-0}" != 1 \
  && ("${HIBERMACHY_SIM_STAGED_SLEEP:-1}" != 0 || "${HIBERMACHY_SIM_SUSPEND:-1}" != 0) ]]; then
call "$plugin_id" editSystemPolicyDraft 9000 false >/dev/null
call "$plugin_id" setSystemPolicyFixture '{"authorization":"fixture","helper":"accepted","effective":{"hibernateDelaySeconds":9000,"hibernateOnAcPower":false}}' >/dev/null
call "$plugin_id" applySystemPolicy >/dev/null
for _ in $(seq 1 20); do
  status=$(status_json)
  if node -e 'const s=JSON.parse(process.argv[1]); process.exit(s.systemPolicyReadiness==="ready" ? 0 : 1)' "$status"; then break; fi
  sleep 0.1
done
call "$plugin_id" setStayAwakeFixture '{"enabled":false}' >/dev/null
call "$plugin_id" setActivityFixture '{"idle":true}' >/dev/null
sleep 0.3
status=$(status_json)
node -e 'const s=JSON.parse(process.argv[1]); if (s.simulatedSleepSubmissionCount!==0 || s.rearmRequired!==true) process.exit(1)' "$status"
call "$plugin_id" setActivityFixture '{"idle":false}' >/dev/null
call "$plugin_id" setActivityFixture '{"idle":true}' >/dev/null
for _ in $(seq 1 20); do
  status=$(status_json)
  if node -e 'const s=JSON.parse(process.argv[1]); process.exit(s.simulatedSleepSubmissionCount===1 ? 0 : 1)' "$status"; then break; fi
  sleep 0.1
done
node -e 'const s=JSON.parse(process.argv[1]); if (s.lastSubmission.origin!=="automatic" || s.lastSubmission.selectedMode!==process.argv[2]) process.exit(1)' "$status" "${HIBERMACHY_EXPECTED_MODE:-suspend-then-hibernate}"

printf '%s\n' 'HBR-CHK-AUTO-002 Stay Awake and compositor inhibitors suppress without submission'
call "$plugin_id" setActivityFixture '{"idle":false}' >/dev/null
call "$plugin_id" setStayAwakeFixture '{"enabled":true}' >/dev/null
call "$plugin_id" setActivityFixture '{"idle":true}' >/dev/null
sleep 0.3
status=$(status_json)
node -e 'const s=JSON.parse(process.argv[1]); if (s.simulatedSleepSubmissionCount!==1 || s.stayAwake!=="on") { console.error(JSON.stringify(s)); process.exit(1) }' "$status"
call "$plugin_id" setStayAwakeFixture '{"enabled":false}' >/dev/null
call "$plugin_id" setActivityFixture '{"idle":false}' >/dev/null
call "$plugin_id" setActivityFixture '{"idle":true,"inhibited":true}' >/dev/null
sleep 0.3
status=$(status_json)
node -e 'const s=JSON.parse(process.argv[1]); if (s.simulatedSleepSubmissionCount!==1 || !s.compositorIdleInhibited) { console.error(JSON.stringify(s)); process.exit(1) }' "$status"

printf '%s\n' 'HBR-CHK-AUTO-003 manual request remains available while automatic latch is set'
call "$plugin_id" setActivityFixture '{"idle":false}' >/dev/null
receipt=$(call "$plugin_id" requestStagedSleep)
node -e 'const r=JSON.parse(process.argv[1]); if (r.kind!=="accepted") process.exit(1)' "$receipt"
status=$(status_json)
node -e 'const s=JSON.parse(process.argv[1]); if (s.simulatedSleepSubmissionCount!==2 || !s.rearmRequired) process.exit(1)' "$status"
fi

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
for _ in $(seq 1 20); do
  status=$(status_json)
  if node -e 'const s=JSON.parse(process.argv[1]); process.exit(s.reasonCode==="HBR-POLICY-PERSISTENCE" ? 0 : 1)' "$status"; then break; fi
  sleep 0.1
done
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

printf '%s\n' 'HBR-CHK-DIAGNOSTICS-001 history reset is explicit, bounded, and does not mutate live policy'
receipt=$(call "$plugin_id" resetHistory)
node -e 'const r=JSON.parse(process.argv[1]); if (!r.accepted || r.reasonCode!=="HBR-HISTORY-RESET") process.exit(1)' "$receipt"
status=$(status_json)
node -e 'const s=JSON.parse(process.argv[1]); if (s.outcomeHistoryCount!==0 || s.automaticPolicyEnablement!=="disabled" || !s.rearmRequired) process.exit(1)' "$status"

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
