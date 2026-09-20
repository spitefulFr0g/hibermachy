#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
status=0
run_gate() {
  local name=$1 command=$2
  printf '%s\n' "HBR-CANDIDATE-$name START"
  if bash -c "$command"; then
    printf '%s\n' "HBR-CANDIDATE-$name PASS"
  else
    printf '%s\n' "HBR-CANDIDATE-$name FAIL"
    status=1
  fi
}

run_gate TRACEABILITY "$root/tests/traceability_merge_gate.sh"
run_gate CROSS_SEAM "$root/tests/cross_seam_merge_gate.sh"
run_gate STATIC "$root/tests/static_merge_gate.sh"
run_gate PANEL_ANNOUNCEMENT "$root/tests/panel_announcement.sh"
run_gate ANNOUNCEMENT_BRIDGE "$root/tests/announcement_bridge.sh"
run_gate POLICY_READBACK "$root/tests/policy_readback.sh"
run_gate EVIDENCE_OBSERVER "$root/tests/evidence_observer.sh"
run_gate SYSTEM_POLICY_DISPATCH "$root/tests/system_policy_dispatch.sh"
run_gate LIFECYCLE_MENU "$root/tests/lifecycle_menu.sh"
run_gate LIFECYCLE_PRODUCTION "$root/tests/lifecycle_production.sh"
run_gate LIFECYCLE_INVENTORY "$root/tests/lifecycle_inventory_production.sh"
run_gate NATIVE_PROBES "$root/tests/native_probes.sh"
run_gate PACKAGING "$root/tests/packaging_merge_gate.sh"
run_gate LIFECYCLE_STATUS "$root/tests/lifecycle_status.sh"
run_gate LIFECYCLE_INSTALL "$root/tests/lifecycle_install.sh"
run_gate LIFECYCLE_UPDATE "$root/tests/lifecycle_update.sh"
run_gate LIFECYCLE_REMOVE "$root/tests/lifecycle_remove.sh"
run_gate LIFECYCLE_UNINSTALL "$root/tests/lifecycle_uninstall.sh"
run_gate LIFECYCLE_RECOVERY "$root/tests/lifecycle_recovery.sh"

if command -v cargo >/dev/null 2>&1 && rustup toolchain list 2>/dev/null | grep -Eq '^[^[:space:]]+.*\((active|default|installed)'; then
  run_gate RUST "cargo test --locked --features test-support --test helper_merge_gate --test apply_process --test packaging_contract"
  run_gate RUST_FORMAT "cargo fmt --all -- --check"
else
  printf '%s\n' 'HBR-ENV-LIMIT Rust gates not run: no configured Rust toolchain is available'
fi

if [[ "${HBR_RUN_HOSTED:-0}" == 1 ]] && (
  { [[ -n "${WAYLAND_DISPLAY:-}" ]] && [[ -S "${XDG_RUNTIME_DIR:-}/$WAYLAND_DISPLAY" ]]; } ||
  { command -v xdpyinfo >/dev/null 2>&1 && [[ -n "${DISPLAY:-}" ]] && xdpyinfo >/dev/null 2>&1; }
); then
  run_gate QUATTRO_HOSTED "$root/tests/quattro-hosted-plugin.sh"
elif [[ "${HBR_RUN_HOSTED:-0}" != 1 ]]; then
  printf '%s\n' 'HBR-ENV-LIMIT Quattro-hosted gate not requested: set HBR_RUN_HOSTED=1 to include it'
else
  printf '%s\n' 'HBR-ENV-LIMIT Quattro-hosted gate not run: no usable Wayland/X11 display socket and runtime directory are available'
fi

if (( status != 0 )); then
  printf '%s\n' 'HBR-CANDIDATE-GATE FAILED: project-controlled gate failure' >&2
  exit 1
fi
printf '%s\n' 'HBR-CANDIDATE-GATE PASS: feasible ordinary gates passed; environmental limits are explicit above'
