#!/usr/bin/env bash
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
fixture=$(mktemp -d)
trap 'rm -rf "$fixture"' EXIT
mkdir -p "$fixture/.config/hibermachy" "$fixture/.local/state/hibermachy"
cp "$root/plugin/Service.qml" "$fixture/Service.qml"
# Drive the production evidence-observer terminal handler, not the test-mode
# evidenceResult simulator, for each selection path.
cat > "$fixture/shell.qml" <<'QML'
import QtQuick
import Quickshell
import Quickshell.Io
Scope {
  id: test
  property var failures: []
  function check(ok, message) { if (!ok) failures.push(message) }
  function observe(attemptId, selectedMode, selectionPath, outcome, reasonCode, evidenceLevel) {
    service.executionInProgress = true
    service.lastSubmission = { attemptId: attemptId, origin: "manual", requestedMode: "suspend-then-hibernate",
      selectedMode: selectedMode, selectionPath: selectionPath, simulated: false }
    service.handleEvidenceObserverLine(JSON.stringify({ schemaVersion: 1, envelopeVersion: 1, kind: "terminal",
      attemptId: attemptId, selectedMode: selectedMode, outcome: outcome, reasonCode: reasonCode,
      evidenceLevel: evidenceLevel, details: { hibernationConfirmed: false } }))
    var history = service.historyDocument.terminalOutcomes
    return history[history.length - 1]
  }
  Service { id: service }
  FileView { id: result; path: Quickshell.env("HOME") + "/result.json" }
  Timer {
    interval: 500; running: true
    onTriggered: {
      var fallback = test.observe("manual-1", "suspend", "suspend-fallback",
        "Completed", "HBR-SLEEP-TRANSACTION-RETURNED", "typed-transaction-return")
      test.check(fallback.outcome === "Degraded", "returned suspend fallback must be Degraded, got " + fallback.outcome)
      test.check(fallback.reasonCode === "HBR-SLEEP-SUSPEND-FALLBACK",
        "returned suspend fallback must report HBR-SLEEP-SUSPEND-FALLBACK, got " + fallback.reasonCode)
      test.check(fallback.selectedMode === "suspend", "fallback keeps selected mode suspend")
      test.check(fallback.details.hibernationConfirmed === false, "fallback never claims hibernation")
      test.check(!service.executionInProgress, "fallback terminal ends execution")

      var failed = test.observe("manual-2", "suspend", "suspend-fallback",
        "Failed", "HBR-SLEEP-UNIT-FAILED", "typed-unit-result")
      test.check(failed.outcome === "Failed" && failed.reasonCode === "HBR-SLEEP-UNIT-FAILED",
        "failed fallback keeps its typed failure")

      var missing = test.observe("manual-3", "suspend", "suspend-fallback",
        "Indeterminate", "HBR-SLEEP-EVIDENCE-MISSING", "missing-typed-evidence")
      test.check(missing.outcome === "Indeterminate" && missing.reasonCode === "HBR-SLEEP-EVIDENCE-MISSING",
        "missing fallback evidence stays Indeterminate")

      var staged = test.observe("manual-4", "suspend-then-hibernate", "staged-sleep",
        "Completed", "HBR-SLEEP-TRANSACTION-RETURNED", "typed-transaction-return")
      test.check(staged.outcome === "Completed" && staged.reasonCode === "HBR-SLEEP-TRANSACTION-RETURNED",
        "returned staged sleep stays Completed")
      result.setText(JSON.stringify({ failures: test.failures }) + "\n")
    }
  }
}
QML
HOME="$fixture" XDG_CONFIG_HOME="$fixture/.config" HBR_TEST_MODE=1 HBR_CONTRACT_PROBE=/usr/bin/true \
  timeout 3 quickshell -p "$fixture/shell.qml" --no-color > "$fixture/log" 2>&1 || [[ $? == 124 ]]
if [[ ! -f $fixture/result.json ]]; then cat "$fixture/log"; exit 1; fi
node - "$fixture/result.json" <<'JS'
const fs = require('node:fs');
const result = JSON.parse(fs.readFileSync(process.argv[2]));
for (const failure of result.failures) console.error('FAIL:', failure);
if (result.failures.length) process.exit(1);
console.log('HBR-CHK-OBSERVED-FALLBACK-001 production observer path reports returned suspend fallback as Degraded');
JS
