#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
shell_files=(
  "$root"/tests/*.sh
  "$root"/lifecycle/status
  "$root"/lifecycle/uninstall
  "$root"/packaging/hibermachy-helper.install
)

printf '%s\n' 'HBR-CHK-STATIC-001 JSON, shell, and whitespace validation'
node -e 'for (const file of process.argv.slice(1)) JSON.parse(require("fs").readFileSync(file))' \
  "$root/package.json" "$root/plugin/manifest.json" "$root/manifest.json"
for file in "${shell_files[@]}"; do
  bash -n "$file"
done
if rg -n '[[:blank:]]+$' "$root/plugin" "$root/src" "$root/lifecycle" "$root/packaging" "$root/tests" "$root/verification"; then
  printf '%s\n' 'HBR-CHK-STATIC-001 FAILED: trailing whitespace' >&2
  exit 1
fi

printf '%s\n' 'HBR-CHK-STATIC-002 lifecycle JavaScript parses without executing host operations'
for file in "$root/lifecycle/install" "$root/lifecycle/remove" "$root/lifecycle/production.mjs" "$root/plugin/bin/policy-readback.cjs" "$root/plugin/bin/hibermachy-policy-readback"; do
  node --check "$file"
done

printf '%s\n' 'HBR-CHK-STATIC-005 production process paths are absolute and test overrides are gated'
rg -q 'command: \[root.capabilityProbePath\]' "$root/plugin/Service.qml"
rg -Fq 'Qt.resolvedUrl("bin/hibermachy-sleep-capability-probe")' "$root/plugin/Service.qml"
node --check "$root/plugin/bin/native-probe-lib.cjs"
node --check "$root/plugin/bin/hibermachy-contract-probe"
node --check "$root/plugin/bin/hibermachy-sleep-capability-probe"
rg -q 'command: \["/usr/bin/omarchy-toggle-idle"' "$root/plugin/Service.qml"
rg -q 'sleepRequestProcess.command = \["/usr/bin/systemctl"' "$root/plugin/Service.qml"
rg -q 'helperPath: \(testMode && Quickshell.env\("HBR_POLICY_HELPER_PATH"\)' "$root/plugin/Service.qml"
rg -q 'helperLauncherPath: \(testMode && Quickshell.env\("HBR_POLICY_HELPER_LAUNCHER"\)' "$root/plugin/Service.qml"
rg -q 'effectivePolicyReaderPath: \(testMode && Quickshell.env\("HBR_EFFECTIVE_POLICY_READER"\)' "$root/plugin/Service.qml"
rg -q 'contractProbePath: \(testMode && Quickshell.env\("HBR_CONTRACT_PROBE"\)' "$root/plugin/Service.qml"
rg -q 'configHome: \(testMode && Quickshell.env\("XDG_CONFIG_HOME"\)' "$root/plugin/Service.qml"
if rg -n 'command: \["(systemctl|loginctl|omarchy-toggle-idle)"' "$root/plugin/Service.qml"; then
  printf '%s\n' 'HBR-CHK-STATIC-005 FAILED: production process path is not absolute' >&2
  exit 1
fi
if rg -n 'command: \["/bin/sh"' "$root/plugin/Service.qml"; then
  printf '%s\n' 'HBR-CHK-STATIC-005 FAILED: shell process launch is prohibited' >&2
  exit 1
fi

printf '%s\n' 'HBR-CHK-STATIC-006 Requested/Effective policy comparison announces non-visually like its neighbors'
announce_handler='onTextChanged: function(value) { if (visible && Accessible.announce) Accessible.announce(value, Accessible.Polite) }'
announce_count=$(rg -Fc "$announce_handler" "$root/plugin/Panel.qml" || true)
if [[ ${announce_count:-0} -ne 3 ]]; then
  printf '%s\n' "HBR-CHK-STATIC-006 FAILED: expected 3 Accessible.announce onTextChanged handlers (status summary, action result, requested/effective comparison), found ${announce_count:-0}" >&2
  exit 1
fi
if ! rg -A1 -F 'Accessible.name: "Requested and effective system policy and latest request result"' "$root/plugin/Panel.qml" | rg -Fq "$announce_handler"; then
  printf '%s\n' 'HBR-CHK-STATIC-006 FAILED: Requested/Effective comparison text lacks a matching Accessible.announce onTextChanged handler' >&2
  exit 1
fi

if command -v shellcheck >/dev/null 2>&1; then
  printf '%s\n' 'HBR-CHK-STATIC-003 shellcheck'
  shellcheck --shell=bash "${shell_files[@]}"
else
  printf '%s\n' 'HBR-ENV-LIMIT shellcheck not installed'
fi

qmlformat_path=
if command -v qmlformat >/dev/null 2>&1; then
  qmlformat_path=$(command -v qmlformat)
elif [[ -x /usr/lib/qt6/bin/qmlformat ]]; then
  qmlformat_path=/usr/lib/qt6/bin/qmlformat
fi
if [[ -n "$qmlformat_path" ]]; then
  printf '%s\n' 'HBR-CHK-STATIC-004 qmlformat QML parse validation (not a formatting check)'
  for file in "$root"/plugin/*.qml; do
    "$qmlformat_path" "$file" >/dev/null
  done
else
  printf '%s\n' 'HBR-ENV-LIMIT qmlformat not installed; QML parse validation unavailable'
fi
