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
