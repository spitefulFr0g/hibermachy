import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: root

  property bool executionInProgress: false
  property int nextAttemptNumber: 1
  property int simulatedSleepSubmissionCount: 0
  property var lastSubmission: null
  property var lastObservation: observeSleepExecutability()

  readonly property var statusSnapshot: ({
    pluginActivation: "active",
    automaticPolicyEnablement: "disabled",
    automaticStagedSleepReadiness: "not-ready",
    manualStagedSleepReadiness: manualReadiness(lastObservation),
    manualConfirmationKind: confirmationKind(lastObservation),
    manualConfirmationMessage: confirmationMessage(lastObservation),
    reasonCode: "HBR-AUTO-001",
    executionInProgress: executionInProgress,
    simulatedSleepSubmissionCount: simulatedSleepSubmissionCount,
    lastSubmission: lastSubmission
  })

  function simulatedBoolean(name, fallback): bool {
    var value = String(Quickshell.env(name) || "").toLowerCase()
    if (value === "1" || value === "true" || value === "yes") return true
    if (value === "0" || value === "false" || value === "no") return false
    return fallback
  }

  function observeSleepExecutability(): var {
    return {
      stagedSleepExecutable: simulatedBoolean("HIBERMACHY_SIM_STAGED_SLEEP", true),
      hibernateExecutable: simulatedBoolean("HIBERMACHY_SIM_HIBERNATE", true),
      suspendExecutable: simulatedBoolean("HIBERMACHY_SIM_SUSPEND", true),
      systemSleepInhibited: simulatedBoolean("HIBERMACHY_SIM_SYSTEM_INHIBITED", false),
      observationFailed: simulatedBoolean("HIBERMACHY_SIM_OBSERVATION_FAILURE", false)
    }
  }

  function manualReadiness(observation): string {
    if (executionInProgress) return "busy"
    if (observation.observationFailed || observation.systemSleepInhibited) return "not-ready"
    return observation.stagedSleepExecutable || observation.suspendExecutable ? "ready" : "not-ready"
  }

  function confirmationKind(observation): string {
    if (manualReadiness(observation) !== "ready") return "unavailable"
    return observation.stagedSleepExecutable ? "staged-sleep" : "suspend-fallback"
  }

  function confirmationMessage(observation): string {
    var consequence = confirmationKind(observation) === "suspend-fallback"
      ? "This will request ordinary suspend because staged sleep is not currently executable."
      : "This will request staged sleep: suspend first, then hibernate if the system remains suspended."
    return consequence + " Manual use bypasses Stay Awake and compositor idle inhibition, but system sleep inhibitors remain enforced."
  }

  function result(kind, reasonCode, details): string {
    return JSON.stringify(Object.assign({ kind: kind, reasonCode: reasonCode }, details || {}))
  }

  function finishWithoutSubmission(kind, reasonCode): string {
    executionInProgress = false
    return result(kind, reasonCode, {})
  }

  function requestStagedSleep(): string {
    return _coordinateStagedSleep("manual")
  }

  function _coordinateStagedSleep(origin): string {
    if (executionInProgress)
      return result("refused", "HBR-SLEEP-BUSY", {})

    executionInProgress = true
    var observation = observeSleepExecutability()
    lastObservation = observation

    if (observation.observationFailed) {
      return finishWithoutSubmission("failed", "HBR-SLEEP-OBSERVATION-FAILED")
    }
    if (observation.systemSleepInhibited) {
      return finishWithoutSubmission("refused", "HBR-SLEEP-SYSTEM-INHIBITED")
    }

    var selectedMode = ""
    var selectionPath = ""
    if (observation.stagedSleepExecutable) {
      selectedMode = "suspend-then-hibernate"
      selectionPath = "staged-sleep"
    } else if (observation.suspendExecutable) {
      selectedMode = "suspend"
      selectionPath = "suspend-fallback"
    } else {
      return finishWithoutSubmission("refused", "HBR-SLEEP-NOT-EXECUTABLE")
    }

    var attemptId = "manual-" + nextAttemptNumber
    nextAttemptNumber += 1
    lastSubmission = {
      attemptId: attemptId,
      origin: origin,
      requestedMode: "suspend-then-hibernate",
      selectedMode: selectedMode,
      selectionPath: selectionPath,
      simulated: true
    }
    simulatedSleepSubmissionCount += 1

    if (!simulatedBoolean("HIBERMACHY_SIM_HOLD_BUSY", false))
      executionInProgress = false

    return result("accepted", "HBR-SLEEP-ACCEPTED", {
      attemptId: attemptId,
      selectedMode: selectedMode,
      selectionPath: selectionPath
    })
  }

  function status(): string {
    lastObservation = observeSleepExecutability()
    return JSON.stringify(statusSnapshot)
  }

  IpcHandler {
    target: "dev.hibermachy"

    function status(): string {
      return root.status()
    }

    function requestStagedSleep(): string {
      return root.requestStagedSleep()
    }
  }
}
