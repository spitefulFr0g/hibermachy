#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)

/usr/bin/python3 - "$root" <<'PY'
import importlib.util
import pathlib
import sys
import runpy
from gi.repository import GLib

root = pathlib.Path(sys.argv[1])
spec = importlib.util.spec_from_file_location("evidence_core", root / "plugin/bin/evidence_core.py")
core = importlib.util.module_from_spec(spec)
spec.loader.exec_module(core)

# Exercise the actual Gio adapter with a real nested GLib Variant. Recursive
# unpacking must happen once, including scalar service properties.
sys.path.insert(0, str(root / "plugin/bin"))
transport = runpy.run_path(str(root / "plugin/bin/hibermachy-sleep-evidence-observer"))
observer_object = transport["Observer"].__new__(transport["Observer"])
transport_events = []
observer_object.state = core.EvidenceState(transport_events.append, lambda: 0, 30000)
observer_object.state.submit("typed-transport", "suspend")
observer_object.state.arm(0)
variant = GLib.Variant("(sa{sv}as)", ("org.freedesktop.systemd1.Unit", {"Job": GLib.Variant("(uo)", (99, "/job/99"))}, []))
observer_object._properties_changed(None, None, transport["UNIT_PATHS"]["systemd-suspend.service"], None, None, variant, None)
assert observer_object.state.attempt["jobId"] == 99

clock = [0]
events = []
state = core.EvidenceState(events.append, lambda: clock[0], 30000)
assert state.submit("attempt-1", "suspend-then-hibernate")
assert state.arm(0)
state.unit_job_started("systemd-suspend-then-hibernate.service", 12, "/job/12")
state.prepare_for_sleep(True)
clock[0] = 100
state.prepare_for_sleep(False)
state.job_removed("systemd-suspend-then-hibernate.service", "done", 12)
assert events[-1]["kind"] == "terminal"
assert events[-1]["outcome"] == "Completed"
assert events[-1]["details"]["hibernationConfirmed"] is False

events.clear()
clock[0] = 0
state = core.EvidenceState(events.append, lambda: clock[0], 30000)
assert state.submit("attempt-2", "suspend")
assert state.arm(0)
clock[0] = 30000
state.tick()
assert events[-1]["outcome"] == "Indeterminate"
assert events[-1]["reasonCode"] == "HBR-SLEEP-EVIDENCE-MISSING"

events.clear()
clock[0] = 0
state = core.EvidenceState(events.append, lambda: clock[0], 30000)
assert state.submit("attempt-3", "suspend")
assert state.arm(0)
state.prepare_for_sleep(False)
assert events[-1]["outcome"] == "Indeterminate"
assert events[-1]["reasonCode"] == "HBR-SLEEP-EVIDENCE-CONTRADICTORY"

events.clear()
state = core.EvidenceState(events.append, lambda: clock[0], 30000)
assert state.submit("attempt-4", "suspend")
assert state.arm(0)
state.unit_job_started("systemd-suspend.service", 13, "/job/13")
state.job_removed("systemd-suspend.service", "failed", 13)
assert events[-1]["outcome"] == "Failed"
assert events[-1]["reasonCode"] == "HBR-SLEEP-UNIT-FAILED"
PY

coproc observer { "$root/plugin/bin/hibermachy-sleep-evidence-observer"; }
IFS= read -r -t 5 readiness <&"${observer[0]}"
# shellcheck disable=SC2154 # Bash creates this PID variable for named coprocesses.
observer_pid=$observer_PID
trap 'kill "$observer_pid" 2>/dev/null || true' EXIT
printf '%s\n' '{"type":"attempt-submitted","attemptId":"read-only-check","selectedMode":"suspend"}' >&"${observer[1]}"
IFS= read -r -t 5 armed <&"${observer[0]}"
printf '%s' "$armed" | /usr/bin/python3 -c 'import json,sys; assert json.load(sys.stdin)["kind"] == "attempt-armed"'
kill "$observer_pid" 2>/dev/null || true
wait "$observer_pid" 2>/dev/null || true
printf '%s' "$readiness" | /usr/bin/python3 -c '
import json, sys
value = json.load(sys.stdin)
assert value["kind"] == "readiness" and value["ready"] is True
assert value["subscriptions"] == {"logindPrepareForSleep": True, "systemdJobRemoved": True, "systemdPropertiesChanged": True, "systemdManagerSubscribe": True}
'

printf '%s\n' 'HBR-CHK-EVIDENCE-001 typed state transitions and live read-only D-Bus subscriptions'
