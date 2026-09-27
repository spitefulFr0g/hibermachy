#!/usr/bin/env bash
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
fixture=$(mktemp -d)
trap 'rm -rf "$fixture"' EXIT
mkdir -p "$fixture/fake" "$fixture/.config/hibermachy" "$fixture/.local/state/hibermachy"
# Replace only the platform transport. All policy and event handlers are real.
sed 's/import Quickshell.Wayland/import "fake"/' "$root/plugin/Service.qml" > "$fixture/Service.qml"
printf '%s\n' '{"version":1,"revision":1,"automaticPolicyEnabled":true,"idleDelaySeconds":300}' > "$fixture/.config/hibermachy/user-policy.json"
cat > "$fixture/fake/Registry.js" <<'JS'
.pragma library
var monitors = []
var inhibited = false
function input() {
  // A long-delay monitor already active emits no extra signal on input.
  for (var m of monitors) if (m.enabled) {
    // Hyprland's zero-timeout notification never emits resumed on input.
    if (m.timeout === 0) { m.isIdle = true; continue }
    // Each modeled input follows a pause longer than the activity interval.
    if (m.timeout < 1) m.isIdle = true
    m.isIdle = false
  }
}
function deadline() {
  for (var m of monitors) if (m.enabled) m.isIdle = !inhibited || !m.respectInhibitors
}
function setInhibited(value) {
  inhibited = value
  for (var m of monitors) if (m.enabled && m.respectInhibitors) m.isIdle = !value
}
JS
cat > "$fixture/fake/IdleMonitor.qml" <<'QML'
import QtQuick
import "Registry.js" as Registry
QtObject {
  property bool enabled: true
  property real timeout: 0
  property bool respectInhibitors: true
  property bool isIdle: false
  Component.onCompleted: Registry.monitors.push(this)
}
QML
cat > "$fixture/shell.qml" <<'QML'
import QtQuick
import Quickshell
import Quickshell.Io
import "fake/Registry.js" as Registry
Scope {
  id: test
  property var failures: []
  function check(ok, message) { if (!ok) failures.push(message) }
  Service { id: service; testActivityFixture: null }
  FileView { id: result; path: Quickshell.env("HOME") + "/result.json" }
  Timer {
    interval: 800; running: true
    onTriggered: {
      var observations = {compatible:true,majorVersion:4,shellReady:true,pluginDiscovery:true,
        pluginActivation:true,manifestSchema:true,ipcFeatures:true,qmlFeatures:true,idleMonitor:true,
        helperProtocol:true,userPolicy:true,systemPolicy:true,logind:true}
      service.loadContractProbe(JSON.stringify(observations), 0)
      service.requestedSystemPolicy = {hibernateDelaySeconds:900,hibernateOnAcPower:true}
      service.effectiveSystemPolicy = service.requestedSystemPolicy
      service.systemPolicyReasonCode = "HBR-SYSTEM-POLICY-APPLIED"
      service.setStayAwakeFixture('{"enabled":false}')
      service.requireFreshActivity()
      test.check(service.policyAccepted, "fixture policy must be loaded")
      test.check(service.simulatedSleepSubmissionCount === 0, "startup cannot submit sleep")
      Registry.deadline()
      test.check(service.simulatedSleepSubmissionCount === 0, "idle without fresh input must remain disarmed")
      Registry.input()
      test.check(!service.rearmRequired, "fresh input arms the production monitor path")
      Registry.setInhibited(true)
      Registry.deadline()
      test.check(service.compositorIdleInhibited &&
        service.automaticReadinessReason() === "HBR-COMPOSITOR-IDLE-INHIBITED",
        "production idle monitors must report a compositor inhibitor")
      test.check(service.simulatedSleepSubmissionCount === 0,
        "inhibitor must suppress an armed automatic request through the idle deadline")
      service.requireFreshActivity()
      Registry.setInhibited(false)
      test.check(!service.compositorIdleInhibited,
        "releasing the compositor inhibitor must clear its blocker")
      // Removing an idle state due to inhibition is not fresh physical input.
      for (var m of Registry.monitors) if (m.respectInhibitors) m.isIdle = false
      test.check(service.rearmRequired, "inhibitor changes cannot manufacture activity")
      // Signing in while the long-delay monitor is already active must re-arm.
      Registry.input()
      test.check(!service.rearmRequired && service.freshActivityObserved,
        "fresh input while deadline monitor is active must re-arm")
      test.check(service.simulatedSleepSubmissionCount === 0, "fresh input cannot itself submit sleep")
      // A routine status poll is not an idle request, even when policy is ready.
      service.observeFreshActivity()
      var before = service.simulatedSleepSubmissionCount
      service.finishAutomaticEvaluation(false, false)
      test.check(service.simulatedSleepSubmissionCount === before, "status poll must not submit sleep")
      service.observeFreshActivity()
      before = service.simulatedSleepSubmissionCount
      Registry.deadline()
      test.check(service.simulatedSleepSubmissionCount === before + 1, "fresh input then deadline submits once")
      service.finishAutomaticEvaluation(false, false)
      test.check(service.simulatedSleepSubmissionCount === before + 1, "later polling cannot duplicate request")
      test.check(service.rearmRequired, "completed attempt requires new activity")
      // Input cancels an evaluation whose asynchronous inhibitor read is pending.
      service.automaticEvaluationInProgress = true
      Registry.input()
      test.check(!service.automaticEvaluationInProgress, "input cancels pending evaluation")
      before = service.simulatedSleepSubmissionCount
      service.finishAutomaticEvaluation(false, false)
      test.check(service.simulatedSleepSubmissionCount === before, "active state invalidates pending evaluation")
      // Stay Awake suppresses idle requests; a later poll turning it off does not
      // manufacture input. Real input and the next idle interval recover.
      service.requireFreshActivity()
      service.finishAutomaticEvaluation(false, false)
      test.check(service.rearmRequired, "Stay Awake polling cannot manufacture fresh input")
      service.setStayAwakeFixture('{"enabled":true}')
      Registry.input()
      Registry.deadline()
      test.check(service.simulatedSleepSubmissionCount === before, "Stay Awake suppresses deadline")
      service.setStayAwakeFixture('{"enabled":false}')
      Registry.input()
      Registry.deadline()
      test.check(service.simulatedSleepSubmissionCount === before + 1, "input after allowing idle recovers")
      result.setText(JSON.stringify({failures:test.failures}) + "\n")
    }
  }
}
QML
# The test-mode service cannot request real sleep or mutate privileged policy.
HOME="$fixture" XDG_CONFIG_HOME="$fixture/.config" HBR_TEST_MODE=1 HBR_CONTRACT_PROBE=/usr/bin/true \
  timeout 3 quickshell -p "$fixture/shell.qml" --no-color > "$fixture/log" 2>&1 || [[ $? == 124 ]]
if [[ ! -f $fixture/result.json ]]; then cat "$fixture/log"; exit 1; fi
node - "$fixture/result.json" <<'JS'
const fs = require('node:fs');
const result = JSON.parse(fs.readFileSync(process.argv[2]));
for (const failure of result.failures) console.error('FAIL:', failure);
if (result.failures.length) process.exit(1);
console.log('HBR-CHK-AUTO-ACTIVITY-001 real QML handlers re-arm from input and submit only after idle');
JS
