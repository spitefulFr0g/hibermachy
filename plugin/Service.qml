import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: root

  readonly property var statusSnapshot: ({
    pluginActivation: "active",
    automaticPolicyEnablement: "disabled",
    automaticStagedSleepReadiness: "not-ready",
    reasonCode: "HBR-AUTO-001"
  })

  function status(): string {
    return JSON.stringify(statusSnapshot)
  }

  IpcHandler {
    target: "dev.hibermachy"

    function status(): string {
      return root.status()
    }
  }
}
