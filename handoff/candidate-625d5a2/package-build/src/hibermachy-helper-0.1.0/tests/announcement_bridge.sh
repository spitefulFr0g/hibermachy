#!/usr/bin/env bash
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)

# HBR-CHK-PANEL-ANNOUNCE-002 establishes that a QML Accessible.announce call is
# delivered to the accessibility bus as an object:announcement event carrying the
# announced text. It covers the transport only. That the panel calls announce with
# the right values at the right times is HBR-CHK-PANEL-ANNOUNCE-001; that a screen
# reader then speaks it is an attended check and is not claimed here.
#
# Requires a live Wayland or X11 session, so it is opt-in and never runs by default.
if [[ "${HBR_RUN_HOSTED:-0}" != 1 ]]; then
  printf '%s\n' 'HBR-ENV-LIMIT HBR-CHK-PANEL-ANNOUNCE-002 not requested: set HBR_RUN_HOSTED=1 to include it'
  exit 0
fi
if ! command -v qml6 >/dev/null 2>&1; then
  printf '%s\n' 'HBR-ENV-LIMIT HBR-CHK-PANEL-ANNOUNCE-002 not run: no qml6 runtime is available'
  exit 0
fi
if ! python3 -c 'import gi; gi.require_version("Atspi","2.0"); from gi.repository import Atspi' 2>/dev/null; then
  printf '%s\n' 'HBR-ENV-LIMIT HBR-CHK-PANEL-ANNOUNCE-002 not run: no Atspi introspection bindings are available'
  exit 0
fi
platform=""
if [[ -n "${WAYLAND_DISPLAY:-}" && -S "${XDG_RUNTIME_DIR:-}/${WAYLAND_DISPLAY}" ]]; then
  platform=wayland
elif [[ -n "${DISPLAY:-}" ]] && command -v xdpyinfo >/dev/null 2>&1 && xdpyinfo >/dev/null 2>&1; then
  platform=xcb
else
  printf '%s\n' 'HBR-ENV-LIMIT HBR-CHK-PANEL-ANNOUNCE-002 not run: no usable display socket is available'
  exit 0
fi

fixture=$(mktemp -d "${TMPDIR:-/tmp}/hibermachy-announce-bridge-XXXXXX")
trap 'rm -rf "$fixture"' EXIT
phrase="Hibermachy announcement bridge $$"

cat > "$fixture/listen.py" <<'PY'
import sys, gi
gi.require_version('Atspi', '2.0')
from gi.repository import Atspi, GLib
wanted = sys.argv[1]
def on_event(e):
    if e.type == 'object:announcement' and e.any_data == wanted:
        print('MATCHED', flush=True)
        Atspi.event_quit()
Atspi.init()
listener = Atspi.EventListener.new(on_event)
listener.register('object:announcement')
print('LISTENING', flush=True)
GLib.timeout_add_seconds(int(sys.argv[2]), lambda: Atspi.event_quit())
Atspi.event_main()
PY

cat > "$fixture/probe.qml" <<QML
import QtQuick
import QtQuick.Window
Window {
  width: 240; height: 120; visible: true; title: "hibermachy-announce-bridge"
  Text { id: t; anchors.centerIn: parent; text: "probe"; Accessible.name: "Latest action result: " + text }
  Timer { interval: 1200; running: true; onTriggered: t.Accessible.announce("$phrase", Accessible.Polite) }
  Timer { interval: 4000; running: true; onTriggered: Qt.exit(0) }
}
QML

python3 "$fixture/listen.py" "$phrase" 14 > "$fixture/listen.log" 2>&1 &
listener_pid=$!
for _ in $(seq 40); do grep -q LISTENING "$fixture/listen.log" 2>/dev/null && break; sleep 0.25; done
QT_QPA_PLATFORM="$platform" QT_LINUX_ACCESSIBILITY_ALWAYS_ON=1 QT_ACCESSIBILITY=1 \
  qml6 "$fixture/probe.qml" >/dev/null 2>&1 || true
wait "$listener_pid" 2>/dev/null || true

if ! grep -q MATCHED "$fixture/listen.log"; then
  printf '%s\n' 'HBR-CHK-PANEL-ANNOUNCE-002 FAILED: no object:announcement carrying the announced text reached the accessibility bus' >&2
  cat "$fixture/listen.log" >&2
  exit 1
fi
printf '%s\n' "HBR-CHK-PANEL-ANNOUNCE-002 Accessible.announce reached the accessibility bus on $platform with the announced text intact"
