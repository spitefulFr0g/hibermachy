#!/usr/bin/env bash
set -euo pipefail

if [[ "${HIBERMACHY_MATRIX_CASE:-}" != '1' ]]; then
  env HIBERMACHY_MATRIX_CASE=1 HIBERMACHY_TEST_PANEL_KEYS=1 HIBERMACHY_EXPECTED_KIND=accepted HIBERMACHY_EXPECTED_MODE=suspend-then-hibernate "$0"
  env HIBERMACHY_MATRIX_CASE=1 HIBERMACHY_SIM_STAGED_SLEEP=0 HIBERMACHY_EXPECTED_KIND=accepted HIBERMACHY_EXPECTED_MODE=suspend "$0"
  env HIBERMACHY_MATRIX_CASE=1 HIBERMACHY_SIM_STAGED_SLEEP=0 HIBERMACHY_SIM_SUSPEND=0 HIBERMACHY_EXPECTED_KIND=refused HIBERMACHY_EXPECTED_REASON=HBR-SLEEP-NOT-EXECUTABLE "$0"
  env HIBERMACHY_MATRIX_CASE=1 HIBERMACHY_SIM_SYSTEM_INHIBITED=1 HIBERMACHY_EXPECTED_KIND=refused HIBERMACHY_EXPECTED_REASON=HBR-SLEEP-SYSTEM-INHIBITED "$0"
  env HIBERMACHY_MATRIX_CASE=1 HIBERMACHY_SIM_OBSERVATION_FAILURE=1 HIBERMACHY_EXPECTED_KIND=failed HIBERMACHY_EXPECTED_REASON=HBR-SLEEP-OBSERVATION-FAILED "$0"
  env HIBERMACHY_MATRIX_CASE=1 HIBERMACHY_SIM_HOLD_BUSY=1 HIBERMACHY_EXPECTED_KIND=accepted HIBERMACHY_EXPECTED_MODE=suspend-then-hibernate HIBERMACHY_EXPECT_BUSY=1 "$0"
  exit 0
fi

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

on_exit() {
  local test_status=$?
  if [[ "$test_status" -ne 0 && -f "$test_root/host.log" ]]; then
    sleep 0.5
    sed -n '1,240p' "$test_root/host.log" >&2
  fi
  cleanup
  exit "$test_status"
}
trap on_exit EXIT

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

host_ready=false
for _ in $(seq 1 50); do
  if call shell ping >/dev/null 2>&1 && call shell listPlugins >/dev/null 2>&1; then
    host_ready=true
    break
  fi
  sleep 0.1
done
if [[ "$host_ready" != true ]]; then
  exit 1
fi
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

printf '%s\n' 'HBR-CHK-MANUAL-001 public manual request accepts simulated staged sleep'
receipt=$(call "$plugin_id" requestStagedSleep)
node -e '
  const receipt = JSON.parse(process.argv[1]);
  const expectedKind = process.argv[2];
  const expectedMode = process.argv[3];
  const expectedReason = process.argv[4];
  if (receipt.kind !== expectedKind) process.exit(1);
  if (expectedMode && (receipt.attemptId !== "manual-1" || receipt.selectedMode !== expectedMode)) process.exit(1);
  if (expectedReason && receipt.reasonCode !== expectedReason) process.exit(1);
' "$receipt" "$HIBERMACHY_EXPECTED_KIND" "${HIBERMACHY_EXPECTED_MODE:-}" "${HIBERMACHY_EXPECTED_REASON:-}"
status=$(status_json)
node -e '
  const status = JSON.parse(process.argv[1]);
  const expectedKind = process.argv[2];
  const expectedMode = process.argv[3];
  const expectedBusy = process.argv[4] === "1";
  const forbidden = ["stagedSleepExecutable", "hibernateExecutable", "suspendExecutable", "systemSleepInhibited"];
  if (forbidden.some((field) => Object.hasOwn(status, field))) process.exit(1);
  const expectedConfirmation = expectedBusy ? "unavailable" : expectedKind === "accepted"
    ? (expectedMode === "suspend" ? "suspend-fallback" : "staged-sleep")
    : "unavailable";
  if (status.manualConfirmationKind !== expectedConfirmation) process.exit(1);
  if (expectedKind === "accepted" && (status.lastSubmission.attemptId !== "manual-1" || status.lastSubmission.selectedMode !== expectedMode || status.simulatedSleepSubmissionCount !== 1)) process.exit(1);
  if (expectedKind !== "accepted" && (status.lastSubmission !== null || status.simulatedSleepSubmissionCount !== 0)) process.exit(1);
' "$status" "$HIBERMACHY_EXPECTED_KIND" "${HIBERMACHY_EXPECTED_MODE:-}" "${HIBERMACHY_EXPECT_BUSY:-}"

if [[ "${HIBERMACHY_EXPECT_BUSY:-}" == '1' ]]; then
  printf '%s\n' 'HBR-CHK-MANUAL-002 concurrent request receives typed busy refusal'
  busy_receipt=$(call "$plugin_id" requestStagedSleep)
  node -e '
    const receipt = JSON.parse(process.argv[1]);
    if (receipt.kind !== "refused" || receipt.reasonCode !== "HBR-SLEEP-BUSY") process.exit(1);
  ' "$busy_receipt"
fi

if [[ "${HIBERMACHY_TEST_PANEL_KEYS:-}" == '1' ]]; then
  printf '%s\n' 'HBR-CHK-MANUAL-003 keyboard cancellation submits nothing'
  call shell summon "$plugin_id" '{}'
  sleep 0.2
  wtype -k Return
  wtype -k Escape
  status=$(status_json)
  node -e '
    const status = JSON.parse(process.argv[1]);
    if (status.simulatedSleepSubmissionCount !== 1) process.exit(1);
  ' "$status"

  printf '%s\n' 'HBR-CHK-MANUAL-004 keyboard confirmation submits through coordinator'
  wtype -k Return
  wtype -k Return
  status=$(status_json)
  node -e '
    const status = JSON.parse(process.argv[1]);
    if (status.simulatedSleepSubmissionCount !== 2 || status.lastSubmission.attemptId !== "manual-2") process.exit(1);
  ' "$status"
  call shell hide "$plugin_id"
fi

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
