#!/usr/bin/env bash
set -euo pipefail

command_path="$(cd "$(dirname "$0")/.." && pwd)/lifecycle/install"
root=$(mktemp -d "${TMPDIR:-/tmp}/hibermachy-recovery-XXXXXX")
trap 'rm -rf "$root"' EXIT

mkdir -p "$root/plugin" "$root/etc/systemd/sleep.conf.d"
printf '%s\n' '{"schemaVersion":1,"id":"dev.hibermachy","version":"0.1.0","protocol":{"min":1,"max":1},"kinds":["service","panel"]}' > "$root/plugin/manifest.json"
printf '%s\n' '{"enabled":true}' > "$root/activation.json"
printf '%s\n' 'reviewed=true' > "$root/native-plugin-update"
printf '%s\n' '{"schemaVersion":1,"id":"dev.hibermachy","version":"0.2.0","protocol":{"min":1,"max":1},"kinds":["service","panel"]}' > "$root/updated-plugin-manifest.json"
printf '%s\n' 'success=true user=unprivileged source=immutable signature=valid checksum=valid' > "$root/helper-build"
printf '%s\n' 'success=true authorization=interactive' > "$root/package-install"
printf '%s\n' 'compatible=true' > "$root/protocol-probe"
printf '%s\n' 'compatible=true' > "$root/probes"
printf '%s\n' '{' '  "unrelated": {}' '}' > "$root/menu.jsonc"
printf '%s\n' 'after=update-menu' > "$root/interrupt"

set +e
failed=$("$command_path" update --root "$root" 2>&1)
failed_code=$?
set -e
[[ $failed_code -ne 0 && $failed == *'HBR-LIFECYCLE-INTERRUPTED'* ]]
jq -e '.operation == "update" and .phase == "menu-reconciled"' "$root/lifecycle-state.json" >/dev/null
[[ $(jq -r .enabled "$root/activation.json") == false ]]

rm "$root/interrupt"
recovered=$("$command_path" update --root "$root")
node -e 'const x=JSON.parse(process.argv[1]); if (x.kind!=="accepted" || x.operation!=="update" || x.activation!=="enabled") process.exit(1)' "$recovered"
[[ $(jq -r .enabled "$root/activation.json") == true ]]
[[ ! -e "$root/update-intent.json" ]]
printf '%s\n' 'HBR-CHK-LIFECYCLE-009 durable interrupted-update continuation'
