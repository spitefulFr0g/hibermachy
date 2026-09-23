#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
manifest="$root/plugin/manifest.json"

printf '%s\n' 'HBR-CHK-CROSS-001 product, helper, and lifecycle share protocol 1'
jq -e '(.kinds | sort == ["panel","service"])' "$manifest" >/dev/null
rg -q 'PROTOCOL_MIN: u16 = 1' "$root/src/main.rs"
rg -q 'protocol-min=1 protocol-max=1' "$root/lifecycle/install" "$root/tests/helper_merge_gate.rs"

printf '%s\n' 'HBR-CHK-CROSS-002 public event, outcome, reason, and lifecycle envelopes are typed'
for token in schemaVersion envelopeVersion correlationId attemptId selectedMode evidenceLevel; do
  rg -q "$token" "$root/plugin/Service.qml"
done
for token in HBR-SLEEP-SYSTEM-INHIBITED HBR-SLEEP-SUSPEND-FALLBACK HBR-SLEEP-EVIDENCE-MISSING HBR-SLEEP-BOOT-CHANGED; do
  rg -q "$token" "$root/plugin/Service.qml"
done
for token in HBR-LIFECYCLE-MISSING HBR-LIFECYCLE-INTERRUPTED HBR-SYSTEM-POLICY-AUTH-CANCELLED; do
  rg -q "$token" "$root/lifecycle" "$root/tests"
done

printf '%s\n' 'HBR-CHK-CROSS-003 lifecycle inventory joins helper protocol and machine policy without a new test API'
fixture=$(mktemp -d "${TMPDIR:-/tmp}/hibermachy-cross-seam-XXXXXX")
trap 'rm -rf "$fixture"' EXIT
mkdir -p "$fixture/plugin" "$fixture/helper" "$fixture/user" "$fixture/etc/systemd/sleep.conf.d"
printf '%s\n' '{"schemaVersion":1,"id":"dev.hibermachy","version":"0.1.0","protocol":{"min":1,"max":1},"kinds":["service","panel"]}' > "$fixture/plugin/manifest.json"
printf '%s\n' 'owner=alice' > "$fixture/installation-owner"
printf '%s\n' 'protocol-min=1 protocol-max=1' > "$fixture/helper/protocol"
printf '%s\n' 'package=hibermachy-helper version=0.1.0' > "$fixture/helper/package"
printf '%s\n' '{"schemaVersion":1,"revision":1,"automaticPolicyEnablement":false,"idleDelaySeconds":1800}' > "$fixture/user/config.json"
printf '%s\n' '{"version":1}' > "$fixture/user/state.json"
printf '%s\n' '# Managed by Hibermachy. Do not edit.' '[Sleep]' 'HibernateDelaySec=3600s' 'HibernateOnACPower=no' > "$fixture/etc/systemd/sleep.conf.d/90-hibermachy.conf"
printf '%s\n' 'owner=system' 'mode=600' 'links=1' > "$fixture/etc/systemd/sleep.conf.d/90-hibermachy.conf.owner"
status=$("$root/lifecycle/status" status --root "$fixture")
jq -e '.scopes.helper_protocol.state == "compatible" and .scopes.requested_system_policy.state == "compatible" and .scopes.owned_target.state == "compatible"' <<<"$status" >/dev/null

printf '%s\n' 'HBR-CHK-CROSS-004 merge verification contains no real sleep, host mutation, package destruction, or fourth implementation seam'
# Scanned over executable test code only. Evidence prose under verification/ must be
# free to name privileged commands to record them as not run; markdown executes nothing.
if rg -n --glob '!cross_seam_merge_gate.sh' 'systemctl( |$)|pkexec|sudo |pacman( |$)|rm -rf /|loginctl suspend|loginctl hibernate' "$root/tests"; then
  printf '%s\n' 'HBR-CHK-CROSS-004 FAILED: prohibited host mutation seam found' >&2
  exit 1
fi
[[ $(rg -c 'target: "dev\.hibermachy"' "$root/plugin/Service.qml") == 1 ]]
