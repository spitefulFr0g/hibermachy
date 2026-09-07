#!/usr/bin/env bash
set -euo pipefail

if [[ "${HIBERMACHY_MATRIX_CASE:-}" != '1' ]]; then
  env HIBERMACHY_MATRIX_CASE=1 HIBERMACHY_TEST_PANEL_KEYS=1 HIBERMACHY_EXPECTED_KIND=accepted HIBERMACHY_EXPECTED_MODE=suspend-then-hibernate HIBERMACHY_EXPECTED_OUTCOME=Completed "$0"
  env HIBERMACHY_MATRIX_CASE=1 HIBERMACHY_SIM_STAGED_SLEEP=0 HIBERMACHY_EXPECTED_KIND=accepted HIBERMACHY_EXPECTED_MODE=suspend HIBERMACHY_EXPECTED_OUTCOME=Degraded "$0"
  env HIBERMACHY_MATRIX_CASE=1 HIBERMACHY_SIM_EVIDENCE=early-wake HIBERMACHY_EXPECTED_KIND=accepted HIBERMACHY_EXPECTED_MODE=suspend-then-hibernate HIBERMACHY_EXPECTED_OUTCOME=Completed HIBERMACHY_EXPECTED_OUTCOME_REASON=HBR-SLEEP-EARLY-WAKE "$0"
  env HIBERMACHY_MATRIX_CASE=1 HIBERMACHY_SIM_EVIDENCE=unit-failure HIBERMACHY_EXPECTED_KIND=accepted HIBERMACHY_EXPECTED_MODE=suspend-then-hibernate HIBERMACHY_EXPECTED_OUTCOME=Failed HIBERMACHY_EXPECTED_EVIDENCE=typed-unit-result "$0"
  env HIBERMACHY_MATRIX_CASE=1 HIBERMACHY_SIM_EVIDENCE=missing HIBERMACHY_EXPECTED_KIND=accepted HIBERMACHY_EXPECTED_MODE=suspend-then-hibernate HIBERMACHY_EXPECTED_OUTCOME=Indeterminate HIBERMACHY_EXPECTED_EVIDENCE=missing-typed-evidence "$0"
  env HIBERMACHY_MATRIX_CASE=1 HIBERMACHY_SIM_EVIDENCE=contradictory HIBERMACHY_EXPECTED_KIND=accepted HIBERMACHY_EXPECTED_MODE=suspend-then-hibernate HIBERMACHY_EXPECTED_OUTCOME=Indeterminate HIBERMACHY_EXPECTED_EVIDENCE=contradictory-typed-evidence "$0"
  env HIBERMACHY_MATRIX_CASE=1 HIBERMACHY_SIM_STAGED_SLEEP=0 HIBERMACHY_SIM_SUSPEND=0 HIBERMACHY_EXPECTED_KIND=refused HIBERMACHY_EXPECTED_REASON=HBR-SLEEP-NOT-EXECUTABLE "$0"
  env HIBERMACHY_MATRIX_CASE=1 HIBERMACHY_SIM_SYSTEM_INHIBITED=1 HIBERMACHY_EXPECTED_KIND=refused HIBERMACHY_EXPECTED_REASON=HBR-SLEEP-SYSTEM-INHIBITED "$0"
  env HIBERMACHY_MATRIX_CASE=1 HIBERMACHY_SIM_OBSERVATION_FAILURE=1 HIBERMACHY_EXPECTED_KIND=failed HIBERMACHY_EXPECTED_REASON=HBR-SLEEP-OBSERVATION-FAILED "$0"
  env HIBERMACHY_MATRIX_CASE=1 HIBERMACHY_SIM_LATCH_FAILURE=1 HIBERMACHY_EXPECTED_KIND=failed HIBERMACHY_EXPECTED_REASON=HBR-HISTORY-REARM-PERSISTENCE-FAILED "$0"
  env HIBERMACHY_MATRIX_CASE=1 HIBERMACHY_SIM_OPEN_ATTEMPT_FAILURE=1 HIBERMACHY_EXPECTED_KIND=failed HIBERMACHY_EXPECTED_REASON=HBR-HISTORY-ATTEMPT-PERSISTENCE-FAILED "$0"
  env HIBERMACHY_MATRIX_CASE=1 HIBERMACHY_SIM_HISTORY_FAILURE=1 HIBERMACHY_EXPECTED_KIND=accepted HIBERMACHY_EXPECTED_MODE=suspend-then-hibernate HIBERMACHY_EXPECTED_OUTCOME=Completed HIBERMACHY_EXPECT_HISTORY_HEALTH=degraded "$0"
  env HIBERMACHY_MATRIX_CASE=1 HIBERMACHY_SIM_SUPPRESSION_REASON=HBR-IDLE-STAY-AWAKE HIBERMACHY_EXPECT_SUPPRESSED=1 "$0"
  env HIBERMACHY_MATRIX_CASE=1 HIBERMACHY_SEED_OPEN_BOOT=prior-boot HIBERMACHY_EXPECT_BOOT_CHANGE=1 "$0"
  env HIBERMACHY_MATRIX_CASE=1 HIBERMACHY_SEED_HISTORY=300 HIBERMACHY_EXPECTED_KIND=accepted HIBERMACHY_EXPECTED_MODE=suspend-then-hibernate HIBERMACHY_EXPECT_HISTORY_COUNT=256 "$0"
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
  sleep 0.2
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
mkdir -p "$test_root/.local/state/hibermachy"
if [[ -n "${HIBERMACHY_SEED_OPEN_BOOT:-}" ]]; then
  node -e '
    const fs = require("fs");
    const bootId = process.argv[2];
    fs.writeFileSync(process.argv[1], JSON.stringify({
      schemaVersion: 1,
      openAttempt: { attemptId: "prior-attempt", origin: "manual", selectedMode: "suspend-then-hibernate", bootId },
      terminalOutcomes: [], suppressionSummaries: [], notificationFingerprints: []
    }, null, 2) + "\n");
  ' "$test_root/.local/state/hibermachy/outcomes.json" "$HIBERMACHY_SEED_OPEN_BOOT"
fi
if [[ -n "${HIBERMACHY_SEED_HISTORY:-}" ]]; then
  node -e '
    const fs = require("fs");
    const count = Number(process.argv[2]);
    const outcomes = Array.from({length: count}, (_, i) => ({
      wallTime: new Date(Date.now() - i * 1000).toISOString(), outcome: "Suppressed"
    }));
    fs.writeFileSync(process.argv[1], JSON.stringify({schemaVersion: 1, openAttempt: null,
      terminalOutcomes: outcomes, suppressionSummaries: [], notificationFingerprints: []}, null, 2) + "\n");
  ' "$test_root/.local/state/hibermachy/outcomes.json" "$HIBERMACHY_SEED_HISTORY"
fi
cp -R plugin "$test_root/.config/omarchy/plugins/$plugin_id"
printf '%s\n' '{"version":1,"plugins":[]}' > "$test_root/.config/omarchy/shell.json"

launch_host() {
  HOME="$test_root" OMARCHY_PATH=/usr/share/omarchy quickshell --path /usr/share/omarchy/shell --no-color > "$test_root/host.log" 2>&1 &
  host_pid=$!
}
launch_host

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
  for retry in 1 2 3; do
    kill "$host_pid" 2>/dev/null || true
    wait "$host_pid" 2>/dev/null || true
    sleep 0.5
    launch_host
    host_ready=false
    for _ in $(seq 1 50); do
      if call shell ping >/dev/null 2>&1 && call shell listPlugins >/dev/null 2>&1; then
        host_ready=true
        break
      fi
      sleep 0.1
    done
    [[ "$host_ready" == true ]] && break
  done
fi
if [[ "$host_ready" != true ]]; then exit 1; fi
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

if [[ "${HIBERMACHY_EXPECT_BOOT_CHANGE:-}" == '1' ]]; then
  printf '%s\n' 'HBR-CHK-OUTCOME-007 boot change finalizes open attempt without replay'
  node -e '
    const status = JSON.parse(process.argv[1]);
    const outcome = status.outcomeHistory.at(-1);
    if (status.openAttempt !== null || !status.rearmRequired || status.executionInProgress) process.exit(1);
    if (!outcome || outcome.outcome !== "Indeterminate" || outcome.reasonCode !== "HBR-SLEEP-BOOT-CHANGED") process.exit(1);
    if (status.simulatedSleepSubmissionCount !== 0 || outcome.details.requestReplayed !== false) process.exit(1);
  ' "$status"
  exit 0
fi

if [[ "${HIBERMACHY_EXPECT_SUPPRESSED:-}" == '1' ]]; then
  printf '%s\n' 'HBR-CHK-OUTCOME-008 automatic suppression stays distinct and coalesced'
  node -e '
    const status = JSON.parse(process.argv[1]);
    const outcome = status.outcomeHistory.at(-1);
    if (!outcome || outcome.outcome !== "Suppressed" || outcome.origin !== "automatic") process.exit(1);
    if (status.suppressionSummaries.length !== 1 || status.suppressionSummaries[0].count !== 1) process.exit(1);
    if (status.simulatedSleepSubmissionCount !== 0) process.exit(1);
  ' "$status"
  exit 0
fi

printf '%s\n' 'HBR-CHK-MANUAL-001 public manual request accepts simulated staged sleep'
receipt=$(call "$plugin_id" requestStagedSleep)
node -e '
  const receipt = JSON.parse(process.argv[1]);
  const expectedKind = process.argv[2];
  const expectedMode = process.argv[3];
  const expectedReason = process.argv[4];
  if (receipt.kind !== expectedKind) process.exit(1);
  const expectedAttempt = process.env.HIBERMACHY_EXPECT_HISTORY_COUNT ? "manual-301" : "manual-1";
  if (expectedMode && (receipt.attemptId !== expectedAttempt || receipt.selectedMode !== expectedMode)) process.exit(1);
  if (expectedReason && receipt.reasonCode !== expectedReason) process.exit(1);
' "$receipt" "$HIBERMACHY_EXPECTED_KIND" "${HIBERMACHY_EXPECTED_MODE:-}" "${HIBERMACHY_EXPECTED_REASON:-}"
if [[ -n "${HIBERMACHY_EXPECT_HISTORY_COUNT:-}" ]]; then
  printf '%s\n' 'HBR-CHK-OUTCOME-009 durable history retains exactly 256 terminal outcomes'
  node -e '
    const history = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"));
    if (history.terminalOutcomes.length !== 256 || history.openAttempt !== null) process.exit(1);
  ' "$test_root/.local/state/hibermachy/outcomes.json"
fi
status=$(status_json)
node -e '
  const status = JSON.parse(process.argv[1]);
  const expectedKind = process.argv[2];
  const expectedMode = process.argv[3];
  const expectedBusy = process.argv[4] === "1";
  const forbidden = ["stagedSleepExecutable", "hibernateExecutable", "suspendExecutable", "systemSleepInhibited"];
  if (forbidden.some((field) => Object.hasOwn(status, field))) process.exit(1);
  const expectedConfirmation = expectedBusy ? "unavailable" : ((process.env.HIBERMACHY_SIM_LATCH_FAILURE === "1" || process.env.HIBERMACHY_SIM_OPEN_ATTEMPT_FAILURE === "1") ? "staged-sleep" : expectedKind === "accepted")
    ? (expectedMode === "suspend" ? "suspend-fallback" : "staged-sleep")
    : "unavailable";
  if (status.manualConfirmationKind !== expectedConfirmation) process.exit(1);
  const expectedAttempt = process.env.HIBERMACHY_EXPECT_HISTORY_COUNT ? "manual-301" : "manual-1";
  if (expectedKind === "accepted" && (status.lastSubmission.attemptId !== expectedAttempt || status.lastSubmission.selectedMode !== expectedMode || status.simulatedSleepSubmissionCount !== 1)) process.exit(1);
  if (expectedKind !== "accepted" && (status.lastSubmission !== null || status.simulatedSleepSubmissionCount !== 0)) process.exit(1);
  const expectedOutcome = process.argv[5];
  if (expectedOutcome) {
    const expectedCount = Number(process.argv[10] || 1);
    if (status.openAttempt !== null || status.outcomeHistoryCount !== expectedCount) process.exit(1);
    const outcome = status.outcomeHistory.at(-1);
    if (outcome.outcome !== expectedOutcome || outcome.evidenceLevel !== (process.argv[6] || "typed-transaction-return")) process.exit(1);
    if (outcome.requestedMode !== "suspend-then-hibernate" || outcome.selectedMode !== expectedMode) process.exit(1);
    if (outcome.operation !== "staged-sleep" || outcome.origin !== "manual" || outcome.phase !== "outcome-reconciliation") process.exit(1);
    if (outcome.details.hibernationConfirmed !== false) process.exit(1);
    if (outcome.details.evidenceSubscribedBeforeEnqueue !== true || outcome.details.evidencePhases.join(",") !== "entry,resume,transaction-return") process.exit(1);
    if (!outcome.eventId || !outcome.correlationId || !outcome.bootId || !outcome.serviceGeneration || outcome.schemaVersion !== 1) process.exit(1);
    if (process.argv[7] && outcome.reasonCode !== process.argv[7]) process.exit(1);
  }
  if (process.argv[8] && status.historyHealth !== process.argv[8]) process.exit(1);
' "$status" "$HIBERMACHY_EXPECTED_KIND" "${HIBERMACHY_EXPECTED_MODE:-}" "${HIBERMACHY_EXPECT_BUSY:-}" "${HIBERMACHY_EXPECTED_OUTCOME:-}" "${HIBERMACHY_EXPECTED_EVIDENCE:-}" "${HIBERMACHY_EXPECTED_OUTCOME_REASON:-}" "${HIBERMACHY_EXPECT_HISTORY_HEALTH:-}" "${HIBERMACHY_EXPECT_HISTORY_COUNT:-}"

if [[ "${HIBERMACHY_EXPECT_BUSY:-}" == '1' ]]; then
  printf '%s\n' 'HBR-CHK-MANUAL-002 concurrent request receives typed busy refusal'
  busy_receipt=$(call "$plugin_id" requestStagedSleep)
  node -e '
    const receipt = JSON.parse(process.argv[1]);
    if (receipt.kind !== "refused" || receipt.reasonCode !== "HBR-SLEEP-BUSY") process.exit(1);
  ' "$busy_receipt"

  printf '%s\n' 'HBR-CHK-OUTCOME-006 reload finalizes open attempt without replay'
  call shell setPluginEnabled "$plugin_id" false | grep -qx 'ok'
  call shell setPluginEnabled "$plugin_id" true | grep -qx 'ok'
  status=$(status_json)
  node -e '
    const status = JSON.parse(process.argv[1]);
    if (status.executionInProgress || status.openAttempt !== null || !status.rearmRequired) process.exit(1);
    const outcome = status.outcomeHistory.at(-1);
    if (outcome.outcome !== "Indeterminate" || outcome.reasonCode !== "HBR-SLEEP-SERVICE-RECREATED") process.exit(1);
    if (outcome.details.requestReplayed !== false || outcome.details.liveStateRestored !== false) process.exit(1);
    if (status.simulatedSleepSubmissionCount !== 0) process.exit(1);
  ' "$status"
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
