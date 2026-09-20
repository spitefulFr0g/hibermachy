#!/usr/bin/env bash
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
panel="$root/plugin/Panel.qml"

# HBR-CHK-PANEL-ANNOUNCE-001 lifts the shipped status and action-result Text elements
# out of Panel.qml verbatim and drives them through real QML binding evaluation. Only
# the theme singletons and the announcement sink are substituted, so declaration order
# — which determines whether sibling bindings are current when onTextChanged fires —
# is preserved exactly. Whether Accessible.announce reaches assistive technology is an
# attended check and is not claimed here.
if ! command -v qml6 >/dev/null 2>&1; then
  printf '%s\n' 'HBR-ENV-LIMIT HBR-CHK-PANEL-ANNOUNCE-001 not run: no qml6 runtime is available'
  exit 0
fi

lift() {
  awk -v marker="$1" '
    /^ *Text \{$/ { depth = index($0, "T"); n = 0; hit = 0 }
    depth { block[n++] = $0; if (index($0, marker)) hit = 1 }
    depth && $0 == sprintf("%*s}", depth - 1, "") {
      if (hit) { for (i = 0; i < n; i++) print block[i]; exit }
      depth = 0
    }
  ' "$panel" |
    sed -e 's/Color\.foreground/"black"/g' -e 's/Style\.font\.family/"sans"/g' \
        -e 's/Style\.font\.bodySmall/12/g' -e 's/Style\.font\.body/14/g' \
        -e 's/Accessible\.announce/recorder.announce/g' -e 's/Accessible\.Polite/0/g'
}
status_text=$(lift 'Current operational status: ')
result_text=$(lift 'Latest action result: ')
for block in "$status_text" "$result_text"; do
  if [[ -z "$block" ]] || ! grep -q 'onTextChanged' <<<"$block" || grep -q 'Style\.\|Color\.' <<<"$block"; then
    printf '%s\n' 'HBR-CHK-PANEL-ANNOUNCE-001 FAILED: could not lift both announcing Text elements from Panel.qml' >&2
    exit 1
  fi
done

fixture=$(mktemp -d "${TMPDIR:-/tmp}/hibermachy-panel-announce-XXXXXX")
trap 'rm -rf "$fixture"' EXIT
{
  printf '%s\n' 'import QtQuick' 'Item {' '  id: root' '  width: 400; height: 400'
  printf '%s\n' '  property string actionResult: ""' '  property string statusSummary: "Ready."'
  printf '%s\n' '  property var statusSnapshot: null' '  property bool panelOpen: true' '  visible: panelOpen'
  printf '%s\n' '  function policyText(p) { return "none" }' '  function systemPolicyMutationMessage(r) { return "none" }'
  printf '%s\n' '  QtObject { id: recorder; property var log: []; function announce(t, p) { recorder.log.push(String(t)) } }'
  printf '%s\n' '  Column { width: parent.width'
  printf '%s\n' "$status_text" "$result_text" '  }'
  printf '%s\n' '  function settle(fn) { Qt.callLater(function() { Qt.callLater(fn) }) }'
  printf '%s\n' '  function report(label) { console.log(label + "=" + JSON.stringify(recorder.log)); recorder.log = [] }'
  printf '%s\n' '  Component.onCompleted: settle(function() { recorder.log = []'
  printf '%s\n' '    root.actionResult = "Requested."; settle(function() { report("T1")'
  printf '%s\n' '    root.actionResult = "Failed."; settle(function() { report("T2")'
  printf '%s\n' '    root.actionResult = ""; settle(function() { report("T3")'
  printf '%s\n' '    root.panelOpen = false; root.statusSummary = "Hidden."; settle(function() { report("T4")'
  printf '%s\n' '    Qt.exit(0) }) }) }) }) })'
  printf '%s\n' '}'
} > "$fixture/probe.qml"

observed=$(QT_QPA_PLATFORM=offscreen QT_ASSUME_STDERR_HAS_CONSOLE=1 qml6 "$fixture/probe.qml" 2>&1 | sed -n 's/^qml: \(T[0-9]=.*\)$/\1/p')
expected='T1=["Requested."]
T2=["Failed."]
T3=[]
T4=[]'
if [[ "$observed" != "$expected" ]]; then
  printf '%s\n' 'HBR-CHK-PANEL-ANNOUNCE-001 FAILED: announcement control flow is wrong' >&2
  printf '%s\n' '--- expected ---' "$expected" '--- observed ---' "$observed" >&2
  exit 1
fi
printf '%s\n' 'HBR-CHK-PANEL-ANNOUNCE-001 first result announced, repeat announced, clear silent, hidden panel silent'
