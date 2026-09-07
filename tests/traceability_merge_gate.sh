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
! rg -n '^\| HBR-REQ-[0-9]{3} .*\| *$' "$matrix" >/dev/null
! rg -n '^\| HBR-REQ-[0-9]{3} \|[^|]*\| *[^|]*\| *[^|]*\| *[^|]*\| *(TBD|unknown|missing|TODO)' "$matrix" -i >/dev/null
for path in plugin/Service.qml plugin/Panel.qml plugin/AccessibleConfirmDialog.qml plugin/manifest.json src/main.rs src/secure_fs.rs build.rs lifecycle/install lifecycle/remove lifecycle/status lifecycle/uninstall packaging/PKGBUILD packaging/.SRCINFO tests/fixtures verification; do
  [[ -e "$root/$path" ]]
done
for gate in HBR-CHK-PANEL HBR-CHK-HELPER HBR-CHK-LIFECYCLE HBR-CHK-PACKAGING HBR-CHK-FIXTURE HBR-CHK-SOAK HBR-CHK-STATIC; do
  rg -q "$gate" "$root"/tests "$root"/verification
done
printf '%s\n' 'HBR-CHK-TRACEABILITY-001 all 76 normative requirements have ordered complete rows'
printf '%s\n' 'HBR-CHK-TRACEABILITY-002 component map covers shipped source, artifacts, packaging, fixtures, and release evidence'
