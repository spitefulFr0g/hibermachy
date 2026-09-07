import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: root

  readonly property string stateDirectory: String(Quickshell.env("HIBERMACHY_STATE_DIR") || Quickshell.env("HOME") + "/.local/state/hibermachy")
  readonly property string historyPath: stateDirectory + "/outcomes.json"
  readonly property string openAttemptPath: stateDirectory + "/open-attempt.json"
  readonly property string latchPath: stateDirectory + "/rearm-latch.json"
  readonly property string bootId: String(Quickshell.env("HIBERMACHY_SIM_BOOT_ID") || "simulated-boot")
  readonly property string serviceGeneration: "service-" + Date.now() + "-" + Math.floor(Math.random() * 1000000)
  readonly property int entryEvidenceWindowMs: Math.max(30000, Number(Quickshell.env("HIBERMACHY_SIM_INHIBITOR_DELAY_MS") || 0) + 10000)
  readonly property int postResumeEvidenceWindowMs: 30000
  property bool executionInProgress: false
  property bool rearmRequired: false
  property bool historyLoaded: false
  property bool historyHealthy: true
  property int nextAttemptNumber: 1
  property int nextEventNumber: 1
  property int simulatedSleepSubmissionCount: 0
  property var lastSubmission: null
  property var lastObservation: observeSleepExecutability()
  property var historyDocument: emptyHistory()

  readonly property var statusSnapshot: ({
    pluginActivation: "active",
    automaticPolicyEnablement: "disabled",
    automaticStagedSleepReadiness: "not-ready",
    manualStagedSleepReadiness: manualReadiness(lastObservation),
    manualConfirmationKind: confirmationKind(lastObservation),
    manualConfirmationMessage: confirmationMessage(lastObservation),
    reasonCode: "HBR-AUTO-001",
    executionInProgress: executionInProgress,
    rearmRequired: rearmRequired,
    historyLoaded: historyLoaded,
    historyHealth: historyHealthy ? "healthy" : "degraded",
    openAttempt: historyDocument.openAttempt,
    outcomeHistory: historyDocument.terminalOutcomes.slice(-20),
    outcomeHistoryCount: historyDocument.terminalOutcomes.length,
    suppressionSummaries: historyDocument.suppressionSummaries,
    notificationFingerprints: historyDocument.notificationFingerprints,
    simulatedSleepSubmissionCount: simulatedSleepSubmissionCount,
    lastSubmission: lastSubmission
  })

  function emptyHistory(): var {
    return { schemaVersion: 1, openAttempt: null, terminalOutcomes: [], suppressionSummaries: [], notificationFingerprints: [] }
  }

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

  function clone(value): var { return JSON.parse(JSON.stringify(value)) }
  function nowWallTime(): string { return new Date().toISOString() }

  function eventEnvelope(attemptId, origin, selectedMode, phase, outcome, reasonCode, evidenceLevel, details): var {
    var eventId = "event-" + nextEventNumber++
    return {
      schemaVersion: 1, eventId: eventId, correlationId: attemptId || eventId, attemptId: attemptId,
      wallTime: nowWallTime(), monotonicTimeMs: Date.now(), bootId: bootId,
      serviceGeneration: serviceGeneration, origin: origin, operation: "staged-sleep", phase: phase,
      outcome: outcome, reasonCode: reasonCode, requestedMode: "suspend-then-hibernate",
      selectedMode: selectedMode || "none", evidenceLevel: evidenceLevel, details: details || {}
    }
  }

  function validHistory(value): bool {
    return value && value.schemaVersion === 1 && Array.isArray(value.terminalOutcomes)
      && Array.isArray(value.suppressionSummaries) && Array.isArray(value.notificationFingerprints)
      && (value.openAttempt === null || typeof value.openAttempt === "object")
  }

  function loadHistory(raw): void {
    if (historyLoaded) return
    if (simulatedBoolean("HIBERMACHY_SIM_HISTORY_FAILURE", false)) {
      historyHealthy = false
      historyLoaded = true
      openAttemptFile.reload()
      return
    }
    if (String(raw || "").trim() !== "") {
      try {
        var parsed = JSON.parse(raw)
        if (!validHistory(parsed)) throw new Error("unsupported history schema")
        historyDocument = parsed
      } catch (error) {
        historyHealthy = false
        historyLoaded = true
        return
      }
    }
    historyLoaded = true
    openAttemptFile.reload()
    reconcileRecoveredAttempt()
    recordSimulatedSuppression()
    nextAttemptNumber = Math.max(nextAttemptNumber, historyDocument.terminalOutcomes.length + 1)
  }

  function loadLatch(raw): void {
    if (String(raw || "").trim() === "") return
    try {
      var parsed = JSON.parse(raw)
      rearmRequired = parsed.schemaVersion === 1 && parsed.rearmRequired === true
    } catch (error) { rearmRequired = true }
  }

  function persistHistory(): bool {
    if (!historyHealthy || simulatedBoolean("HIBERMACHY_SIM_HISTORY_FAILURE", false)) {
      historyHealthy = false
      return false
    }
    historyFile.setText(JSON.stringify(historyDocument, null, 2) + "\n")
    return true
  }

  function persistOpenAttempt(attempt): void {
    openAttemptFile.setText(JSON.stringify({ schemaVersion: 1, openAttempt: attempt }, null, 2) + "\n")
  }

  function loadOpenAttempt(raw): void {
    if (!raw || String(raw).trim() === "") return
    try {
      var parsed = JSON.parse(raw)
      if (parsed.schemaVersion !== 1 || !parsed.openAttempt) return
      if (!historyDocument.openAttempt) historyDocument.openAttempt = parsed.openAttempt
      if (historyLoaded && historyDocument.openAttempt) reconcileRecoveredAttempt()
    } catch (error) { historyHealthy = false }
  }

  function persistLatch(): bool {
    if (simulatedBoolean("HIBERMACHY_SIM_LATCH_FAILURE", false)) return false
    rearmRequired = true
    latchFile.setText(JSON.stringify({ schemaVersion: 1, rearmRequired: true }, null, 2) + "\n")
    return true
  }

  function trimHistory(outcomes): var {
    var cutoff = Date.now() - 90 * 24 * 60 * 60 * 1000
    return outcomes.filter(function(entry) {
      var timestamp = Date.parse(entry.wallTime)
      return !isNaN(timestamp) && timestamp >= cutoff
    }).slice(-256)
  }

  function appendTerminal(envelope): void {
    var next = clone(historyDocument)
    next.openAttempt = null
    next.terminalOutcomes.push(envelope)
    next.terminalOutcomes = trimHistory(next.terminalOutcomes)
    next.suppressionSummaries = next.suppressionSummaries.slice(-32)
    if (envelope.outcome === "Failed" || envelope.outcome === "Indeterminate" || envelope.outcome === "Degraded") {
      var fingerprint = envelope.outcome + ":" + envelope.reasonCode
      if (next.notificationFingerprints.indexOf(fingerprint) < 0) next.notificationFingerprints.push(fingerprint)
    }
    next.notificationFingerprints = next.notificationFingerprints.slice(-64)
    historyDocument = next
    persistHistory()
    persistOpenAttempt(null)
  }

  function reconcileRecoveredAttempt(): void {
    var open = historyDocument.openAttempt
    if (!open) return
    rearmRequired = true
    var reasonCode = open.bootId !== bootId ? "HBR-SLEEP-BOOT-CHANGED" : "HBR-SLEEP-SERVICE-RECREATED"
    appendTerminal(eventEnvelope(open.attemptId, open.origin, open.selectedMode, "outcome-reconciliation",
      "Indeterminate", reasonCode, "service-boundary", { requestReplayed: false, liveStateRestored: false }))
    executionInProgress = false
  }

  function recordSimulatedSuppression(): void {
    var reason = String(Quickshell.env("HIBERMACHY_SIM_SUPPRESSION_REASON") || "")
    if (!reason) return
    var next = clone(historyDocument)
    var summaries = next.suppressionSummaries
    var last = summaries.length ? summaries[summaries.length - 1] : null
    if (last && last.reasonCode === reason) last.count += 1
    else summaries.push({ reasonCode: reason, count: 1, lastObservedAt: nowWallTime() })
    next.suppressionSummaries = summaries.slice(-32)
    historyDocument = next
    appendTerminal(eventEnvelope(null, "automatic", "none", "eligibility-evaluation",
      "Suppressed", reason, "typed-eligibility", {}))
  }

  function recordPreSubmissionOutcome(kind, reasonCode): string {
    appendTerminal(eventEnvelope(null, "manual", "none", "eligibility-evaluation",
      kind === "failed" ? "Failed" : "Refused", reasonCode, "typed-capability", {}))
    executionInProgress = false
    return result(kind, reasonCode, {})
  }

  function evidenceResult(selectionPath): var {
    var scenario = String(Quickshell.env("HIBERMACHY_SIM_EVIDENCE") || "completed")
    if (selectionPath === "suspend-fallback") return { outcome: "Degraded", reason: "HBR-SLEEP-SUSPEND-FALLBACK", evidence: "typed-transaction-return" }
    if (scenario === "unit-failure") return { outcome: "Failed", reason: "HBR-SLEEP-UNIT-FAILED", evidence: "typed-unit-result" }
    if (scenario === "early-wake") return { outcome: "Completed", reason: "HBR-SLEEP-EARLY-WAKE", evidence: "typed-transaction-return" }
    if (scenario === "missing") return { outcome: "Indeterminate", reason: "HBR-SLEEP-EVIDENCE-MISSING", evidence: "missing-typed-evidence" }
    if (scenario === "contradictory") return { outcome: "Indeterminate", reason: "HBR-SLEEP-EVIDENCE-CONTRADICTORY", evidence: "contradictory-typed-evidence" }
    if (scenario === "pending" || simulatedBoolean("HIBERMACHY_SIM_HOLD_BUSY", false)) return null
    return { outcome: "Completed", reason: "HBR-SLEEP-TRANSACTION-RETURNED", evidence: "typed-transaction-return" }
  }

  function requestStagedSleep(): string { return _coordinateStagedSleep("manual") }

  function _coordinateStagedSleep(origin): string {
    if (executionInProgress) return result("refused", "HBR-SLEEP-BUSY", {})
    executionInProgress = true
    var observation = observeSleepExecutability()
    lastObservation = observation
    if (observation.observationFailed) return recordPreSubmissionOutcome("failed", "HBR-SLEEP-OBSERVATION-FAILED")
    if (observation.systemSleepInhibited) return recordPreSubmissionOutcome("refused", "HBR-SLEEP-SYSTEM-INHIBITED")

    var selectedMode = ""
    var selectionPath = ""
    if (observation.stagedSleepExecutable) {
      selectedMode = "suspend-then-hibernate"
      selectionPath = "staged-sleep"
    } else if (observation.suspendExecutable) {
      selectedMode = "suspend"
      selectionPath = "suspend-fallback"
    } else return recordPreSubmissionOutcome("refused", "HBR-SLEEP-NOT-EXECUTABLE")

    if (!persistLatch()) {
      executionInProgress = false
      return result("failed", "HBR-HISTORY-REARM-PERSISTENCE-FAILED", {})
    }

    var attemptId = "manual-" + nextAttemptNumber++
    var openAttempt = eventEnvelope(attemptId, origin, selectedMode, "request-enqueue", null,
      "HBR-SLEEP-ENQUEUE-PENDING", "typed-subscription", {
        evidenceSubscribedBeforeEnqueue: true, entryEvidenceWindowMs: entryEvidenceWindowMs,
        postResumeEvidenceWindowMs: postResumeEvidenceWindowMs, deadlinesPauseWhileUserspaceFrozen: true
      })
    var next = clone(historyDocument)
    next.openAttempt = openAttempt
    historyDocument = next
    persistOpenAttempt(openAttempt)
    persistHistory()

    lastSubmission = { attemptId: attemptId, origin: origin, requestedMode: "suspend-then-hibernate",
      selectedMode: selectedMode, selectionPath: selectionPath, simulated: true,
      openAttemptPersistedBeforeEnqueue: true, evidenceSubscribedBeforeEnqueue: true }
    simulatedSleepSubmissionCount += 1

    var observed = evidenceResult(selectionPath)
    if (observed) {
      appendTerminal(eventEnvelope(attemptId, origin, selectedMode, "outcome-reconciliation",
        observed.outcome, observed.reason, observed.evidence, {
          hibernationConfirmed: false, entryEvidenceWindowMs: entryEvidenceWindowMs,
          postResumeEvidenceWindowMs: postResumeEvidenceWindowMs,
          userspaceFreezeExcludedFromDeadline: true, freeFormJournalUsedForState: false,
          evidenceSubscribedBeforeEnqueue: true,
          evidencePhases: ["entry", "resume", "transaction-return"]
        }))
      executionInProgress = false
    }
    return result("accepted", "HBR-SLEEP-ACCEPTED", { attemptId: attemptId,
      selectedMode: selectedMode, selectionPath: selectionPath })
  }

  function status(): string {
    lastObservation = observeSleepExecutability()
    return JSON.stringify(statusSnapshot)
  }

  FileView {
    id: historyFile
    path: root.historyPath
    atomicWrites: true
    printErrors: false
    onLoaded: root.loadHistory(text())
    onLoadFailed: root.loadHistory("")
  }

  FileView {
    id: openAttemptFile
    path: root.openAttemptPath
    atomicWrites: true
    printErrors: false
    onLoaded: root.loadOpenAttempt(text())
    onLoadFailed: root.loadOpenAttempt("")
  }

  FileView {
    id: latchFile
    path: root.latchPath
    atomicWrites: true
    printErrors: false
    onLoaded: root.loadLatch(text())
    onLoadFailed: root.loadLatch("")
  }

  Component.onCompleted: {
    historyFile.reload()
    latchFile.reload()
  }

  IpcHandler {
    target: "dev.hibermachy"
    function status(): string { return root.status() }
    function requestStagedSleep(): string { return root.requestStagedSleep() }
  }
}
