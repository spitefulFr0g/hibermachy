#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)

printf '%s\n' 'HBR-CHK-STATIC-001 JSON, shell, and whitespace validation'
node -e 'for (const file of process.argv.slice(1)) JSON.parse(require("fs").readFileSync(file))' \
  "$root/package.json" "$root/plugin/manifest.json"
bash -n "$root"/tests/*.sh "$root"/lifecycle/* "$root"/packaging/hibermachy-helper.install
if rg -n '[[:blank:]]+$' "$root/plugin" "$root/src" "$root/lifecycle" "$root/packaging" "$root/tests" "$root/verification"; then
  printf '%s\n' 'HBR-CHK-STATIC-001 FAILED: trailing whitespace' >&2
  exit 1
fi

printf '%s\n' 'HBR-CHK-STATIC-002 lifecycle JavaScript parses without executing host operations'
for file in "$root/lifecycle/install" "$root/lifecycle/remove"; do
  node --check "$file"
done

printf '%s\n' 'HBR-CHK-STATIC-005 production process paths are absolute and test overrides are gated'
rg -q 'command: \["/usr/bin/loginctl"' "$root/plugin/Service.qml"
rg -q 'command: \["/usr/bin/omarchy-toggle-idle"' "$root/plugin/Service.qml"
rg -q 'sleepRequestProcess.command = \["/usr/bin/systemctl"' "$root/plugin/Service.qml"
rg -q 'helperPath: \(testMode && Quickshell.env\("HBR_POLICY_HELPER_PATH"\)' "$root/plugin/Service.qml"
rg -q 'helperLauncherPath: \(testMode && Quickshell.env\("HBR_POLICY_HELPER_LAUNCHER"\)' "$root/plugin/Service.qml"
rg -q 'effectivePolicyReaderPath: \(testMode && Quickshell.env\("HBR_EFFECTIVE_POLICY_READER"\)' "$root/plugin/Service.qml"
rg -q 'contractProbePath: \(testMode && Quickshell.env\("HBR_CONTRACT_PROBE"\)' "$root/plugin/Service.qml"
rg -q 'configHome: \(testMode && Quickshell.env\("XDG_CONFIG_HOME"\)' "$root/plugin/Service.qml"
! rg -n 'command: \["(systemctl|loginctl|omarchy-toggle-idle)"' "$root/plugin/Service.qml"
! rg -n 'command: \["/bin/sh"' "$root/plugin/Service.qml"

if command -v shellcheck >/dev/null 2>&1; then
  printf '%s\n' 'HBR-CHK-STATIC-003 shellcheck'
  shellcheck "$root"/tests/*.sh "$root"/lifecycle/* "$root"/packaging/hibermachy-helper.install
else
  printf '%s\n' 'HBR-ENV-LIMIT shellcheck not installed'
fi

if command -v qmlformat >/dev/null 2>&1; then
  printf '%s\n' 'HBR-CHK-STATIC-004 qmlformat'
  qmlformat --check "$root"/plugin/*.qml
else
  printf '%s\n' 'HBR-ENV-LIMIT qmlformat not installed; hosted QML gate remains required'
fi
