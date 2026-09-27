#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
fixture=$(mktemp -d)
trap 'rm -rf "$fixture"' EXIT
fixture_home="$fixture/home"
bin="$fixture/bin"
policy="$fixture/90-hibermachy.conf"
plugin="$fixture_home/.config/omarchy/plugins/dev.hibermachy"
menu="$fixture_home/.config/omarchy/extensions/omarchy-menu.jsonc"
mkdir -p "$bin" "$plugin/plugin/bin" "$fixture_home/.config/omarchy/extensions" "$fixture_home/.config/hibermachy" "$fixture_home/.local/state/hibermachy"

cp "$root/manifest.json" "$plugin/manifest.json"
cp "$root/plugin/Service.qml" "$plugin/plugin/Service.qml"
cp "$root/plugin/Panel.qml" "$plugin/plugin/Panel.qml"
printf '{"plugins":[{"id":"dev.hibermachy"}]}\n' > "$fixture_home/.config/omarchy/shell.json"
printf '{}\n' > "$menu"
node --input-type=module -e 'const { reconcileMenu } = await import(process.argv[1]); reconcileMenu(process.argv[2])' "$root/lifecycle/menu.mjs" "$menu"
printf '%s\n' '# Managed by Hibermachy. Do not edit.' '[Sleep]' 'HibernateDelaySec=900s' 'HibernateOnACPower=no' > "$policy"

cat > "$bin/node" <<'EOF'
#!/usr/bin/env bash
if [[ $1 == --version ]]; then printf '%s\n' 'v26.8.1'; fi
exit 0
EOF
cat > "$bin/python3" <<'EOF'
#!/usr/bin/env bash
if [[ $1 == --version ]]; then printf '%s\n' 'Python 3.14.0'; else [[ $1 == -c ]]; fi
exit 0
EOF
cat > "$bin/hibermachy-policy-helper" <<'EOF'
#!/usr/bin/env bash
[[ $1 == probe ]]
printf '%s\n' 'release=0.1.0 protocol-min=1 protocol-max=1'
EOF
cat > "$plugin/plugin/bin/hibermachy-policy-readback" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' '{"requested":{"hibernateDelaySeconds":900,"hibernateOnAcPower":false},"effective":{"hibernateDelaySeconds":900,"hibernateOnAcPower":false},"provenance":["/etc/systemd/sleep.conf.d/90-hibermachy.conf"]}'
EOF
cat > "$plugin/plugin/bin/hibermachy-contract-probe" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' '{"compatible":true,"majorVersion":4,"omarchyVersion":"4.0.3"}'
EOF
cat > "$plugin/plugin/bin/hibermachy-sleep-capability-probe" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' 'CanSuspend=yes' 'CanHibernate=yes' 'CanSuspendThenHibernate=yes' 'BlockInhibited=' 'BootId=01234567-89ab-cdef-0123-456789abcdef'
EOF
chmod 755 "$bin"/* "$plugin/plugin/bin"/*

envbase=(HBR_LIFECYCLE_TEST_MODE=1 HIBERMACHY_LIFECYCLE_HOME="$fixture_home" HIBERMACHY_LIFECYCLE_COMMAND_DIR="$bin" HIBERMACHY_LIFECYCLE_POLICY="$policy")
status=$(env "${envbase[@]}" node "$root/lifecycle/production.mjs" status)
node -e '
  const result=JSON.parse(process.argv[1]), s=result.scopes;
  for (const key of ["checkout","activation","menu_contribution","helper_package","requested_system_policy","effective_system_policy","runtime_dependencies","live_readiness","user_configuration","outcome_history"]) if (!s[key]) process.exit(1);
  for (const key of ["checkout","activation","helper_package","requested_system_policy","effective_system_policy","runtime_dependencies","live_readiness","user_configuration","outcome_history"]) if (s[key].state!=="compatible") process.exit(1);
  if (s.activation.enabled!==true || s.helper_package.release!=="0.1.0") process.exit(1);
' "$status"

cat > "$bin/hibermachy-policy-helper" <<'EOF'
#!/usr/bin/env bash
touch "$(dirname "$0")/helper-executed"
exit 99
EOF
chmod 775 "$bin/hibermachy-policy-helper"
status=$(env "${envbase[@]}" node "$root/lifecycle/production.mjs" status)
node -e '
  const s=JSON.parse(process.argv[1]).scopes;
  if (s.helper_package.state!=="modified") process.exit(1);
' "$status"
[[ ! -e "$bin/helper-executed" ]]

cat > "$plugin/plugin/bin/hibermachy-policy-readback" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' '{"requested":null,"effective":{"hibernateDelaySeconds":3600000,"hibernateOnAcPower":true},"provenance":["/etc/systemd/sleep.conf.d/20-admin.conf"]}'
EOF
chmod 755 "$plugin/plugin/bin/hibermachy-policy-readback"
status=$(env "${envbase[@]}" node "$root/lifecycle/production.mjs" status)
node -e '
  const s=JSON.parse(process.argv[1]).scopes;
  if (s.requested_system_policy.state!=="compatible" || s.effective_system_policy.state!=="compatible") process.exit(1);
' "$status"

cat > "$plugin/plugin/bin/hibermachy-contract-probe" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' '{"compatible":true,"majorVersion":4,"omarchyVersion":"development"}'
EOF
chmod 755 "$plugin/plugin/bin/hibermachy-contract-probe"
status=$(env "${envbase[@]}" node "$root/lifecycle/production.mjs" status)
node -e '
  const s=JSON.parse(process.argv[1]).scopes;
  if (s.live_readiness.state!=="incomplete") process.exit(1);
' "$status"

rm "$bin/hibermachy-policy-helper"
status=$(env "${envbase[@]}" node "$root/lifecycle/production.mjs" status)
node -e '
  const s=JSON.parse(process.argv[1]).scopes;
  if (s.helper_package.state!=="missing" || s.checkout.state!=="compatible" || s.activation.state!=="compatible" || s.activation.enabled!==true || s.live_readiness.state!=="incomplete") process.exit(1);
' "$status"

printf '%s\n' 'HBR-CHK-LIFECYCLE-INVENTORY-001 independent production inventory scopes use bounded adapter-gated probes'
