#!/usr/bin/env bash
set -euo pipefail

command_path="$(cd "$(dirname "$0")/.." && pwd)/lifecycle/install"
fixture_root="$(mktemp -d "${TMPDIR:-/tmp}/hibermachy-install-XXXXXX")"
trap 'rm -rf "$fixture_root"' EXIT

mkdir -p "$fixture_root/plugin" "$fixture_root/etc/systemd/sleep.conf.d"
printf '%s\n' '{"schemaVersion":1,"id":"dev.hibermachy","version":"0.1.0","protocol":{"min":1,"max":1},"kinds":["service","panel"]}' > "$fixture_root/plugin/manifest.json"
printf '%s\n' 'compatible=true' > "$fixture_root/quattro-contract"
printf '%s\n' 'reviewed=true' > "$fixture_root/native-plugin-review"
printf '%s\n' 'success=true user=unprivileged' > "$fixture_root/helper-build"
printf '%s\n' 'success=true authorization=interactive' > "$fixture_root/package-install"
printf '%s\n' 'compatible=true' > "$fixture_root/probes"
cat > "$fixture_root/menu.jsonc" <<'EOF'
// Keep this comment and the unrelated entry order.
{
  "unrelated.before": {"label":"Before"},
  // Keep this entry in place.
  "unrelated.after": {"label":"After"}
}
EOF
printf '%s\n' 'requested-policy-must-remain-untouched' > "$fixture_root/etc/systemd/sleep.conf.d/90-hibermachy.conf"

set +e
rm "$fixture_root/native-plugin-review"
missing_review=$("$command_path" setup --root "$fixture_root" 2>&1)
missing_review_code=$?
set -e
[[ $missing_review_code -ne 0 ]]
[[ $missing_review == *'HBR-LIFECYCLE-NATIVE-REVIEW-REQUIRED'* ]]
[[ ! -e "$fixture_root/activation.json" ]]

printf '%s\n' 'reviewed=true' > "$fixture_root/native-plugin-review"
setup=$("$command_path" setup --root "$fixture_root")
node -e 'const x=JSON.parse(process.argv[1]); if (x.kind!=="accepted" || x.activation!=="disabled" || x.menu!=="reconciled" || x.policyMutation!==false) process.exit(1)' "$setup"
[[ $(jq -r .enabled "$fixture_root/activation.json") == false ]]
[[ $(cat "$fixture_root/etc/systemd/sleep.conf.d/90-hibermachy.conf") == requested-policy-must-remain-untouched ]]
grep -q 'Keep this comment' "$fixture_root/menu.jsonc"
grep -q 'unrelated.before' "$fixture_root/menu.jsonc"
grep -q 'unrelated.after' "$fixture_root/menu.jsonc"
jq -e '[to_entries[].key] == ["unrelated.before","unrelated.after","setup.hibermachy","system.hibermachy-staged-sleep"]' < <(sed -E 's@//[^"].*$@@' "$fixture_root/menu.jsonc") >/dev/null
jq -e '."setup.hibermachy".aliases | index("sleep") and index("hibernate") and index("Hibermachy")' < <(sed -E 's@//[^"].*$@@' "$fixture_root/menu.jsonc") >/dev/null

before=$(sha256sum "$fixture_root/menu.jsonc" | cut -d' ' -f1)
rerun=$("$command_path" setup --root "$fixture_root")
after=$(sha256sum "$fixture_root/menu.jsonc" | cut -d' ' -f1)
[[ $before == "$after" ]]
node -e 'const x=JSON.parse(process.argv[1]); if (x.menu!=="unchanged" || x.activation!=="disabled") process.exit(1)' "$rerun"

declined=$("$command_path" activate --root "$fixture_root" --decline)
node -e 'const x=JSON.parse(process.argv[1]); if (x.kind!=="declined" || x.activation!=="disabled") process.exit(1)' "$declined"
later=$("$command_path" activate --root "$fixture_root" --confirm)
node -e 'const x=JSON.parse(process.argv[1]); if (x.kind!=="accepted" || x.activation!=="enabled") process.exit(1)' "$later"

printf '%s\n' '{"setup.hibermachy":{"managedBy":"other"}}' > "$fixture_root/menu.jsonc"
set +e; collision=$("$command_path" setup --root "$fixture_root" 2>&1); collision_code=$?; set -e
[[ $collision_code -ne 0 && $collision == *'HBR-MENU-ID-COLLISION'* ]]

printf '%s\n' '{"setup.hibermachy":{"managedBy":"hibermachy","label":"Changed"}}' > "$fixture_root/menu.jsonc"
set +e; modified=$("$command_path" setup --root "$fixture_root" 2>&1); modified_code=$?; set -e
[[ $modified_code -ne 0 && $modified == *'HBR-MENU-MANAGED-MODIFIED'* ]]

printf '%s\n' '{"setup.hibermachy":[' > "$fixture_root/menu.jsonc"
set +e; malformed=$("$command_path" setup --root "$fixture_root" 2>&1); malformed_code=$?; set -e
[[ $malformed_code -ne 0 && $malformed == *'HBR-MENU-MALFORMED'* ]]

printf '%s\n' 'HBR-CHK-LIFECYCLE-006 disabled-first setup, safe rerun, and menu fixtures'
