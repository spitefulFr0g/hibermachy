#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
matrix="$root/verification/requirement-matrix.md"
components="$root/verification/component-gate-map.md"

[[ -s "$matrix" && -s "$components" ]]
header=$(sed -n 's/^| ID | Requirement.*$/ok/p' "$matrix")
[[ "$header" == ok ]]
rows=$(awk -F'|' '/^\| HBR-REQ-[0-9]{3} / { count += 1; id=$2; gsub(/[[:space:]]/, "", id); if (id != sprintf("HBR-REQ-%03d", count)) exit 2 } END { print count }' "$matrix")
[[ "$rows" == 76 ]]
if ! awk -F'|' '/^\| HBR-REQ-[0-9]{3} / { if (NF != 8) exit 1; for (field = 2; field <= 7; field += 1) { value = $field; gsub(/[[:space:]]/, "", value); if (value == "") exit 1 } }' "$matrix"; then
  printf '%s\n' 'HBR-CHK-TRACEABILITY-001 FAILED: a requirement row is incomplete' >&2
  exit 1
fi
if ! awk -F'|' '/^\| HBR-REQ-[0-9]{3} / { for (field = 2; field <= 7; field += 1) { value = $field; gsub(/^[[:space:]]+|[[:space:]]+$/, "", value); if (tolower(value) ~ /^(tbd|unknown|missing|todo)$/) exit 1 } }' "$matrix"; then
  printf '%s\n' 'HBR-CHK-TRACEABILITY-001 FAILED: a requirement row contains a placeholder' >&2
  exit 1
fi
for path in plugin/Service.qml plugin/Panel.qml plugin/AccessibleConfirmDialog.qml plugin/manifest.json src/main.rs src/secure_fs.rs build.rs lifecycle/install lifecycle/remove lifecycle/status lifecycle/uninstall packaging/PKGBUILD packaging/.SRCINFO tests/fixtures verification; do
  [[ -e "$root/$path" ]]
done
for gate in HBR-CHK-PANEL HBR-CHK-HELPER HBR-CHK-LIFECYCLE HBR-CHK-PACKAGING HBR-CHK-FIXTURE HBR-CHK-SOAK HBR-CHK-STATIC; do
  rg -q "$gate" "$root"/tests "$root"/verification
done
printf '%s\n' 'HBR-CHK-TRACEABILITY-001 all 76 normative requirements have ordered complete rows'
printf '%s\n' 'HBR-CHK-TRACEABILITY-002 component map covers shipped source, artifacts, packaging, fixtures, and release evidence'
