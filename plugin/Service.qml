import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Item {
  id: root

  readonly property string stateDirectory: String(Quickshell.env("HIBERMACHY_STATE_DIR") || Quickshell.env("HOME") + "/.local/state/hibermachy")
  readonly property string historyPath: stateDirectory + "/outcomes.json"
  readonly property string latchPath: stateDirectory + "/rearm-latch.json"
  readonly property string bootId: String(Quickshell.env("HIBERMACHY_SIM_BOOT_ID") || "simulated-boot")
  readonly property string serviceGeneration: "service-" + Date.now() + "-" + Math.floor(Math.random() * 1000000)
  readonly property int entryEvidenceWindowMs: Math.max(30000, Number(Quickshell.env("HIBERMACHY_SIM_INHIBITOR_DELAY_MS") || 0) + 10000)
  readonly property int postResumeEvidenceWindowMs: 30000
  property bool executionInProgress: false
  property bool rearmRequired: true
  property bool freshActivityObserved: false
  property bool idleMonitorHealthy: false
  property bool compositorIdleInhibited: false
  property bool stayAwakeKnown: false
  property bool stayAwakeEnabled: false
  property bool stayAwakeReadFailed: false
  property bool automaticEvaluationInProgress: false
  property bool historyLoaded: false
  property bool historyHealthy: true
  property int nextAttemptNumber: 1
  property int nextEventNumber: 1
  property int simulatedSleepSubmissionCount: 0
  property var lastSubmission: null
  property var testClockMs: Quickshell.env("HBR_TEST_CLOCK_START_MS") ? Number(Quickshell.env("HBR_TEST_CLOCK_START_MS")) : null
  property var liveSleepCapabilities: null
  property bool sleepCapabilityProbeHealthy: false
  property var lastObservation: observeSleepExecutability()
  property var historyDocument: emptyHistory()
  property var evidenceSubscription: null
  readonly property string configHome: Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config"
  readonly property string policyDirectory: configHome + "/hibermachy"
  readonly property string policyPath: policyDirectory + "/user-policy.json"
  property var policySnapshot: null
  property bool policyAccepted: false
  property string policyReasonCode: "HBR-POLICY-LOADING"
  property string lastObservedPolicyText: ""
  property bool policyWriteInFlight: false
  property var pendingUserPolicy: null
  property bool policyDirectoryWritable: true
  property var systemPolicyDraft: ({ hibernateDelaySeconds: 7200, hibernateOnAcPower: false, scope: "machine-wide" })
  property var requestedSystemPolicy: null
  property var effectiveSystemPolicy: null
  property var systemPolicyProvenance: []
  property string systemPolicyReasonCode: "HBR-SYSTEM-POLICY-UNAPPLIED"
  property bool systemPolicyBusy: false
  property string systemPolicyMutation: ""
  property var systemPolicyFixture: ({ authorization: Quickshell.env("HBR_TEST_MODE") === "1" ? "authorized" : "unavailable" })
  readonly property string helperPath: Quickshell.env("HBR_POLICY_HELPER_PATH") || "/usr/libexec/hibermachy-policy-helper"
  readonly property string helperLauncherPath: Quickshell.env("HBR_POLICY_HELPER_LAUNCHER") || "pkexec"
  readonly property string effectivePolicyReaderPath: Quickshell.env("HBR_EFFECTIVE_POLICY_READER") || "/usr/bin/systemd-analyze"
  readonly property string contractProbePath: Quickshell.env("HBR_CONTRACT_PROBE") || "/usr/bin/omarchy-contract-probe"
  property bool contractProbeComplete: false
  property var contractSnapshot: null

  readonly property var statusSnapshot: ({
    pluginActivation: "active",
    automaticPolicyEnablement: policyAccepted && policySnapshot && policySnapshot.automaticPolicyEnabled ? "enabled" : "disabled",
    automaticStagedSleepReadiness: automaticReadiness(),
    manualStagedSleepReadiness: manualReadiness(lastObservation),
    manualConfirmationKind: confirmationKind(lastObservation),
    manualConfirmationMessage: confirmationMessage(lastObservation),
    reasonCode: contractReadiness("automatic") === "ready" ? policyReasonCode : contractReasonCode("automatic"),
    contractReadiness: contractReadiness("status"),
    contractReasonCode: contractReasonCode("status"),
    contractSnapshot: contractSnapshot,
    automaticReadinessReasonCode: contractReasonCode("automatic"),
    automaticContractReadiness: contractReadiness("automatic"),
    automaticExecutionState: rearmRequired ? "disarmed-rearm-latch" : "disarmed-awaiting-trigger",
    idleMonitorHealthy: idleMonitorHealthy,
    compositorIdleInhibited: compositorIdleInhibited,
    stayAwake: stayAwakeKnown ? (stayAwakeEnabled ? "on" : "off") : "unknown",
    freshActivityObserved: freshActivityObserved,
    manualReadinessReasonCode: contractReasonCode("manual"),
    manualBlockerReasonCode: manualReadinessReason(),
    systemPolicyReadinessReasonCode: contractReasonCode("system-policy"),
    automaticBlockerReasonCode: automaticReadinessReason(),
    diagnosticsReadinessReasonCode: diagnosticsReasonCode(),
    diagnosticsReadiness: diagnosticsReadiness(),
    sleepExecutability: clone(lastObservation),
    sleepExecutabilitySummary: sleepExecutabilitySummary(),
    fallbackAvailable: suspendFallbackAvailable(),
    activeBlocker: activeBlocker(),
    heroStatus: heroStatus(),
    heroExplanation: heroExplanation(),
    readiness: ({ automatic: automaticReadiness(), manual: manualReadiness(lastObservation),
      systemPolicy: systemPolicyReasonCode === "HBR-SYSTEM-POLICY-APPLIED" ? "ready" : "not-ready",
      diagnostics: diagnosticsReadiness() }),
    statusAnnouncement: statusAnnouncement(),
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
    ,userPolicy: policySnapshot
    ,systemPolicyDraft: systemPolicyDraft
    ,requestedSystemPolicy: requestedSystemPolicy
    ,effectiveSystemPolicy: effectiveSystemPolicy
    ,systemPolicyProvenance: systemPolicyProvenance
    ,systemPolicyReasonCode: systemPolicyReasonCode
    ,systemPolicyReadiness: systemPolicyReasonCode === "HBR-SYSTEM-POLICY-APPLIED" ? "ready" : "not-ready"
  })

  function emptyHistory(): var {
    return { schemaVersion: 1, openAttempt: null, terminalOutcomes: [], suppressionSummaries: [], notificationFingerprints: [] }
  }

  function contractReasonCode(operation): string {
    if (!contractProbeComplete) return "HBR-CONTRACT-PREFLIGHT-PENDING"
    if (!contractSnapshot || contractSnapshot.compatible !== true) {
      if (operation === "manual") return "HBR-CONTRACT-INCOMPATIBLE-MANUAL"
      if (operation === "system-policy") return "HBR-CONTRACT-INCOMPATIBLE-SYSTEM-POLICY"
      if (operation === "diagnostics") return "HBR-CONTRACT-INCOMPATIBLE-DIAGNOSTICS"
      return "HBR-CONTRACT-INCOMPATIBLE-AUTOMATIC"
    }
    return "HBR-CONTRACT-READY"
  }

  function contractReadiness(operation): string {
    return contractReasonCode(operation) === "HBR-CONTRACT-READY" ? "ready" : "not-ready"
  }

  function diagnosticsReadiness(): string {
    if (!contractProbeComplete) return "not-ready"
    return historyLoaded && historyHealthy ? "ready" : (historyLoaded ? "degraded" : "not-ready")
  }

  function diagnosticsReasonCode(): string {
    if (contractReadiness("diagnostics") !== "ready") return contractReasonCode("diagnostics")
    if (!historyLoaded) return "HBR-DIAGNOSTICS-HISTORY-PENDING"
    return historyHealthy ? "HBR-DIAGNOSTICS-READY" : "HBR-DIAGNOSTICS-DEGRADED"
  }

  function suspendFallbackAvailable(): bool {
    return !!lastObservation && !lastObservation.observationFailed
      && !lastObservation.stagedSleepExecutable && !!lastObservation.suspendExecutable
  }

  function sleepExecutabilitySummary(): string {
    if (!lastObservation || lastObservation.observationFailed) return "sleep executability unavailable"
    if (lastObservation.stagedSleepExecutable) return "staged sleep executable"
    if (lastObservation.suspendExecutable) return "suspend fallback available"
    return "no suspend or staged sleep executable"
  }

  function activeBlocker(): string {
    if (!contractProbeComplete) return "HBR-CONTRACT-PREFLIGHT-PENDING"
    if (!policySnapshot || !policySnapshot.automaticPolicyEnabled) return "none"
    if (!policyAccepted) return policyReasonCode
    if (automaticReadiness() !== "ready") return automaticReadinessReason()
    if (manualReadiness(lastObservation) !== "ready") return manualReadinessReason()
    if (systemPolicyReasonCode !== "HBR-SYSTEM-POLICY-APPLIED") return systemPolicyReasonCode
    if (diagnosticsReadiness() === "degraded") return "HBR-DIAGNOSTICS-DEGRADED"
    return "HBR-READY"
  }

  function latestOutcome(): var {
    var outcomes = historyDocument.terminalOutcomes || []
    return outcomes.length ? outcomes[outcomes.length - 1] : null
  }

  function latestOutcomeIsActionable(outcome): bool {
    return !!outcome && (outcome.outcome === "Failed" || outcome.outcome === "Indeterminate")
      && !!outcome.attemptId && !!lastSubmission && outcome.attemptId === lastSubmission.attemptId
  }

  function heroStatus(): string {
    if (executionInProgress) return "Active sleep transaction"
    var outcome = latestOutcome()
    if (latestOutcomeIsActionable(outcome))
      return outcome.outcome === "Failed" ? "Action failed" : "Outcome indeterminate"
    if (manualReadiness(lastObservation) !== "ready"
      && (lastObservation.observationFailed || (!lastObservation.stagedSleepExecutable && !lastObservation.suspendExecutable)
        || lastObservation.systemSleepInhibited)) return "Unavailable now"
    if (systemPolicyReasonCode === "HBR-SYSTEM-POLICY-DIFFERS") return "Policy differs"
    if (suspendFallbackAvailable()) return "Suspend fallback"
    if (!policySnapshot || !policySnapshot.automaticPolicyEnabled) return "Automation paused"
    if (rearmRequired || !freshActivityObserved) return "Awaiting fresh activity"
    if (automaticReadiness() === "ready" || manualReadiness(lastObservation) === "ready"
      || systemPolicyReasonCode === "HBR-SYSTEM-POLICY-APPLIED") return "Ready"
    return "Unavailable now"
  }

  function heroExplanation(): string {
    return heroStatus() + ". " + statusAnnouncement()
  }

  function automaticReadinessReason(): string {
    if (contractReadiness("automatic") !== "ready") return contractReasonCode("automatic")
    if (!policySnapshot || !policySnapshot.automaticPolicyEnabled) return "HBR-AUTOMATIC-DISABLED"
    if (!requestedSystemPolicy || !effectiveSystemPolicy) return "HBR-SYSTEM-POLICY-NOT-READY"
    if (!idleMonitorHealthy) return "HBR-IDLE-MONITOR-UNAVAILABLE"
    if (compositorIdleInhibited) return "HBR-COMPOSITOR-IDLE-INHIBITED"
    if (stayAwakeKnown && stayAwakeEnabled) return "HBR-STAY-AWAKE-ENABLED"
    if (rearmRequired || !freshActivityObserved) return "HBR-FRESH-ACTIVITY-REQUIRED"
    return "HBR-AUTOMATIC-READY"
  }

  function manualReadinessReason(): string {
    if (executionInProgress) return "HBR-SLEEP-BUSY"
    if (contractReadiness("manual") !== "ready") return contractReasonCode("manual")
    if (lastObservation.observationFailed) return "HBR-SLEEP-OBSERVATION-FAILED"
    if (lastObservation.systemSleepInhibited) return "HBR-SLEEP-SYSTEM-INHIBITED"
    if (!lastObservation.stagedSleepExecutable && !lastObservation.suspendExecutable) return "HBR-SLEEP-NOT-EXECUTABLE"
    return "HBR-MANUAL-READY"
  }

  function statusAnnouncement(): string {
    var automatic = automaticReadiness()
    var manual = manualReadiness(lastObservation)
    return "Automatic staged sleep " + automatic + "; manual staged sleep " + manual
      + "; system policy " + (systemPolicyReasonCode === "HBR-SYSTEM-POLICY-APPLIED" ? "ready" : "not ready")
      + "; diagnostics " + diagnosticsReadiness() + "."
  }

  function automaticReadiness(): string {
    if (contractReadiness("automatic") !== "ready") return "not-ready"
    if (!policyAccepted || !policySnapshot || !policySnapshot.automaticPolicyEnabled) return "not-ready"
    if (!requestedSystemPolicy || !effectiveSystemPolicy || systemPolicyReasonCode !== "HBR-SYSTEM-POLICY-APPLIED") return "not-ready"
    if (!idleMonitorHealthy || compositorIdleInhibited || (stayAwakeKnown && stayAwakeEnabled)) return "not-ready"
    if (rearmRequired || !freshActivityObserved) return "not-ready"
    return "ready"
  }

  function persistRearm(required): bool {
    if (simulatedBoolean("HIBERMACHY_SIM_LATCH_FAILURE", false)) return false
    rearmRequired = required
    latchFile.setText(JSON.stringify({ schemaVersion: 1, rearmRequired: required }, null, 2) + "\n")
    return true
  }

  function requireFreshActivity() {
    freshActivityObserved = false
    if (!persistRearm(true)) rearmRequired = true
  }

  function observeFreshActivity() {
    freshActivityObserved = true
    if (!persistRearm(false)) {
      freshActivityObserved = false
      rearmRequired = true
      return false
    }
    return true
  }

  function handleIdleChanged() {
    if (testActivityFixture !== null) return
    if (!idleMonitor.isIdle) {
      observeFreshActivity()
      return
    }
    requestAutomaticStagedSleep()
  }

  function requestAutomaticStagedSleep() {
    if (automaticEvaluationInProgress || executionInProgress) return
    if (automaticReadiness() !== "ready") return
    automaticEvaluationInProgress = true
    if (testStayAwakeFixture !== null) {
      finishAutomaticEvaluation(testStayAwakeFixture.enabled === true, testStayAwakeFixture.healthy === false)
      return
    }
    stayAwakeProbe.running = true
  }

  function finishAutomaticEvaluation(stayAwake, readFailed) {
    automaticEvaluationInProgress = false
    stayAwakeKnown = !readFailed
    stayAwakeEnabled = !!stayAwake
    stayAwakeReadFailed = readFailed
    if (readFailed || stayAwake) return
    if (automaticReadiness() !== "ready") return
    _coordinateStagedSleep("automatic")
  }

  property var testActivityFixture: Quickshell.env("HBR_TEST_MODE") === "1" ? ({ idle: false, inhibited: false }) : null
  property var testStayAwakeFixture: null

  function setActivityFixture(fixtureJson): string {
    if (testActivityFixture === null) return result("refused", "HBR-TEST-FIXTURE-UNAVAILABLE", {})
    try {
      var fixture = JSON.parse(String(fixtureJson))
      if (!fixture || typeof fixture !== "object") throw new Error("fixture")
      testActivityFixture = { idle: fixture.idle === true, inhibited: fixture.inhibited === true }
      compositorIdleInhibited = testActivityFixture.inhibited
      idleMonitorHealthy = fixture.healthy !== false
      if (!testActivityFixture.idle) observeFreshActivity()
      else requestAutomaticStagedSleep()
      return result("accepted", "HBR-TEST-ACTIVITY-FIXTURE-SET", { fixture: testActivityFixture })
    } catch (error) {
      return result("refused", "HBR-TEST-ACTIVITY-FIXTURE-MALFORMED", {})
    }
  }

  function setStayAwakeFixture(fixtureJson): string {
    if (Quickshell.env("HBR_TEST_MODE") !== "1") return result("refused", "HBR-TEST-FIXTURE-UNAVAILABLE", {})
    try {
      var fixture = JSON.parse(String(fixtureJson))
      if (!fixture || typeof fixture !== "object") throw new Error("fixture")
      testStayAwakeFixture = { enabled: fixture.enabled === true, healthy: fixture.healthy !== false }
      stayAwakeKnown = testStayAwakeFixture.healthy
      stayAwakeEnabled = testStayAwakeFixture.enabled
      stayAwakeReadFailed = !testStayAwakeFixture.healthy
      return result("accepted", "HBR-TEST-STAY-AWAKE-FIXTURE-SET", { fixture: testStayAwakeFixture })
    } catch (error) {
      return result("refused", "HBR-TEST-STAY-AWAKE-FIXTURE-MALFORMED", {})
    }
  }

  function loadContractProbe(output, exitCode) {
    var parsed = null
    try { parsed = JSON.parse(String(output || "")) } catch (error) { parsed = null }
    if (exitCode !== 0 || !parsed || typeof parsed !== "object") {
      contractSnapshot = { compatible: false, majorVersion: null, reasonCode: "HBR-CONTRACT-PREFLIGHT-FAILED", observations: {} }
    } else {
      var required = ["shellReady", "pluginDiscovery", "pluginActivation", "manifestSchema", "ipcFeatures", "qmlFeatures", "idleMonitor", "helperProtocol", "userPolicy", "systemPolicy", "logind"]
      var missing = required.filter(function(key) { return parsed[key] !== true })
      contractSnapshot = {
        compatible: parsed.compatible === true && missing.length === 0,
        majorVersion: parsed.majorVersion === undefined ? null : parsed.majorVersion,
        observations: parsed,
        missingContracts: missing,
        laterVersion: parsed.laterVersion === true
      }
      idleMonitorHealthy = contractSnapshot.compatible && parsed.idleMonitor === true
    }
    contractProbeComplete = true
  }

  function simulatedBoolean(name, fallback): bool {
    var value = String(Quickshell.env(name) || "").toLowerCase()
    if (value === "1" || value === "true" || value === "yes") return true
    if (value === "0" || value === "false" || value === "no") return false
    return fallback
  }

  function observeSleepExecutability(): var {
    if (Quickshell.env("HBR_TEST_MODE") !== "1") {
      if (!sleepCapabilityProbeHealthy || !liveSleepCapabilities) return { observationFailed: true }
      return liveSleepCapabilities
    }
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
    if (contractReadiness("manual") !== "ready") return "not-ready"
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

  function setClockFixture(fixtureJson): string {
    if (Quickshell.env("HBR_TEST_MODE") !== "1") return result("refused", "HBR-TEST-FIXTURE-UNAVAILABLE", {})
    try {
      var fixture = JSON.parse(String(fixtureJson))
      if (!fixture || !Number.isSafeInteger(fixture.nowMs) || fixture.nowMs < 0) throw new Error("clock")
      testClockMs = fixture.nowMs
      return result("accepted", "HBR-TEST-CLOCK-SET", { nowMs: testClockMs })
    } catch (error) { return result("refused", "HBR-TEST-CLOCK-MALFORMED", {}) }
  }

  function runAcceleratedSoak(transitions: int): string {
    if (Quickshell.env("HBR_TEST_MODE") !== "1") return result("refused", "HBR-TEST-FIXTURE-UNAVAILABLE", {})
    var count = Number(transitions)
    if (!Number.isSafeInteger(count) || count < 1 || count > 5000) return result("refused", "HBR-TEST-SOAK-INVALID", {})
    var accepted = 0
    var refused = 0
    var attemptIds = {}
    var maxHistory = 0
    var maxNotifications = 0
    var maxDiagnosticsBytes = 0
    var duplicateAttempt = false
    for (var index = 0; index < count; index += 1) {
      var receipt = JSON.parse(requestStagedSleep())
      if (receipt.accepted) {
        accepted += 1
        if (attemptIds[receipt.attemptId]) duplicateAttempt = true
        attemptIds[receipt.attemptId] = true
      } else refused += 1
      maxHistory = Math.max(maxHistory, (historyDocument.terminalOutcomes || []).length)
      maxNotifications = Math.max(maxNotifications, (historyDocument.notifications || []).length)
      maxDiagnosticsBytes = Math.max(maxDiagnosticsBytes, copyDiagnostics().length)
      if (testClockMs !== null) testClockMs += 1
    }
    var finalStatus = JSON.parse(status())
    return JSON.stringify({ schemaVersion: 1, envelopeVersion: 1, accepted: true,
      reasonCode: "HBR-TEST-SOAK-COMPLETE", transitions: count, acceptedTransitions: accepted,
      refusedTransitions: refused, duplicateAttempt: duplicateAttempt,
      busyAtEnd: finalStatus.executionInProgress, historyCount: finalStatus.outcomeHistoryCount,
      maxHistory: maxHistory, maxNotifications: maxNotifications,
      maxDiagnosticsBytes: maxDiagnosticsBytes, finalRearmRequired: finalStatus.rearmRequired,
      finalStatus: { automatic: finalStatus.automaticStagedSleepReadiness,
        manual: finalStatus.manualStagedSleepReadiness } })
  }

  function automaticPolicyChanged(previous, next): bool {
    return !!previous && !!next
      && (previous.automaticPolicyEnabled !== next.automaticPolicyEnabled
        || previous.idleDelaySeconds !== next.idleDelaySeconds)
  }

  function systemPolicyMatches(left, right): bool {
    return !!left && !!right && left.hibernateDelaySeconds === right.hibernateDelaySeconds
      && left.hibernateOnAcPower === right.hibernateOnAcPower
  }

  function clone(value): var { return JSON.parse(JSON.stringify(value)) }
  function clockNowMs(): int { return testClockMs === null ? Date.now() : testClockMs }
  function nowWallTime(): string { return new Date(clockNowMs()).toISOString() }

  function eventEnvelope(attemptId, origin, selectedMode, phase, outcome, reasonCode, evidenceLevel, details): var {
    var eventId = "event-" + nextEventNumber++
    return {
      schemaVersion: 1, eventId: eventId, correlationId: attemptId || eventId, attemptId: attemptId,
      wallTime: nowWallTime(), monotonicTimeMs: clockNowMs(), bootId: bootId,
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
    reconcileRecoveredAttempt()
    recordSimulatedSuppression()
    nextAttemptNumber = Math.max(nextAttemptNumber, historyDocument.terminalOutcomes.length + 1)
  }

  function loadLatch(raw): void {
    // A new service must observe activity again; disk state only prevents
    // retrying an unfinished request and never proves current activity.
    rearmRequired = true
    freshActivityObserved = false
    if (String(raw || "").trim() === "") return
    try {
      JSON.parse(raw)
    } catch (error) { /* malformed latch remains fail-closed */ }
  }

  function persistHistory(allowOpenAttemptDuringDiagnosticFault): bool {
    if (allowOpenAttemptDuringDiagnosticFault && simulatedBoolean("HIBERMACHY_SIM_OPEN_ATTEMPT_FAILURE", false)) return false
    var diagnosticFault = simulatedBoolean("HIBERMACHY_SIM_HISTORY_FAILURE", false)
    if (diagnosticFault) historyHealthy = false
    if (simulatedBoolean("HIBERMACHY_SIM_HISTORY_WRITE_FAILURE", false)) {
      historyHealthy = false
      return false
    }
    historyFile.setText(JSON.stringify(historyDocument, null, 2) + "\n")
    return true
  }

  function subscribeTypedEvidence(attemptId): var {
    var subscription = {
      attemptId: attemptId,
      subscribedBeforeEnqueue: true,
      signals: ["PrepareForSleep", "UnitResult", "TransactionReturn"],
      entryWindowMs: entryEvidenceWindowMs,
      postResumeWindowMs: postResumeEvidenceWindowMs,
      deadlinePausesWhileUserspaceFrozen: true
    }
    evidenceSubscription = subscription
    return subscription
  }

  function persistLatch(): bool {
    return persistRearm(true)
  }

  function trimHistory(outcomes): var {
    var cutoff = clockNowMs() - 90 * 24 * 60 * 60 * 1000
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

  function policyReceipt(accepted, reasonCode, extra): string {
    var value = { accepted: accepted, reasonCode: reasonCode,
      requestedSystemPolicy: requestedSystemPolicy, effectiveSystemPolicy: effectiveSystemPolicy,
      systemPolicyProvenance: systemPolicyProvenance }
    if (extra) for (var key in extra) value[key] = extra[key]
    return JSON.stringify(value)
  }

  function validSystemPolicy(value): bool {
    return value && Number.isSafeInteger(value.hibernateDelaySeconds)
      && value.hibernateDelaySeconds >= 900 && value.hibernateDelaySeconds <= 604800
      && typeof value.hibernateOnAcPower === "boolean"
  }

  function loadUserPolicy(raw, bytes): void {
    lastObservedPolicyText = String(raw || "")
    if ((bytes && bytes.byteLength > 16384) || String(raw).length > 16384) { policyAccepted = false; policyReasonCode = "HBR-POLICY-SIZE"; return }
    if (bytes && bytes.byteLength >= 3) {
      var octets = new Uint8Array(bytes)
      if (octets[0] === 0xEF && octets[1] === 0xBB && octets[2] === 0xBF) { policyAccepted = false; policyReasonCode = "HBR-POLICY-ENCODING"; return }
    }
    if (String(raw).charCodeAt(0) === 0xFEFF || String(raw).indexOf("\uFFFD") >= 0) { policyAccepted = false; policyReasonCode = "HBR-POLICY-ENCODING"; return }
    if ((String(raw).match(/"revision"\s*:/g) || []).length > 1) {
      policyAccepted = false
      policyReasonCode = "HBR-POLICY-DUPLICATE-KEY"
      return
    }
    try {
      var value = JSON.parse(String(raw || ""))
      if (!value || value.version !== 1 || !Number.isSafeInteger(value.revision) || value.revision < 1
        || typeof value.automaticPolicyEnabled !== "boolean" || !Number.isSafeInteger(value.idleDelaySeconds)
        || value.idleDelaySeconds < 300 || value.idleDelaySeconds > 86400) throw new Error("invalid policy")
      if (policySnapshot && value.revision !== policySnapshot.revision) {
        policyAccepted = false
        policyReasonCode = "HBR-POLICY-REVISION-CONFLICT"
        return
      }
      var policyChanged = automaticPolicyChanged(policySnapshot, value)
      if (policyChanged) {
        value.revision = value.revision === Number.MAX_SAFE_INTEGER ? value.revision : value.revision + 1
      }
      var persistenceBlocked = policyReasonCode === "HBR-POLICY-PERSISTENCE"
      var canonical = JSON.stringify({ version: 1, revision: value.revision,
        automaticPolicyEnabled: value.automaticPolicyEnabled, idleDelaySeconds: value.idleDelaySeconds }, null, 2) + "\n"
      if (String(raw) !== canonical) policyFile.setText(canonical)
      policySnapshot = value
      policyReasonCode = !policyDirectoryWritable || persistenceBlocked
        ? "HBR-POLICY-PERSISTENCE"
        : (value.automaticPolicyEnabled ? "HBR-POLICY-ENABLED" : "HBR-POLICY-DISABLED")
      if (policyChanged) requireFreshActivity()
    } catch (error) {
      if (String(raw || "").trim() === "") {
        policySnapshot = { version: 1, revision: 1, automaticPolicyEnabled: false, idleDelaySeconds: 1800 }
        policyFile.setText(JSON.stringify(policySnapshot, null, 2) + "\n")
        policyAccepted = true
        policyReasonCode = policyDirectoryWritable ? "HBR-POLICY-DISABLED" : "HBR-POLICY-PERSISTENCE"
        return
      }
      policyAccepted = false
      if ((String(raw).match(/"revision"\s*:/g) || []).length > 1) policyReasonCode = "HBR-POLICY-DUPLICATE-KEY"
      else if (String(raw).indexOf('"version":2') >= 0) policyReasonCode = "HBR-POLICY-SCHEMA"
      else policyReasonCode = String(raw).indexOf('"idleDelaySeconds"') < 0 ? "HBR-POLICY-KEYS" : "HBR-POLICY-MALFORMED"
      return
    }
    policyAccepted = true
  }

  function userPolicy(): string { return JSON.stringify(policySnapshot || {}) }

  function saveUserPolicy(requestJson): string {
    if (!policyDirectoryWritable) {
      policyAccepted = false
      policyReasonCode = "HBR-POLICY-PERSISTENCE"
      return JSON.stringify({ accepted: false, reasonCode: "HBR-POLICY-PERSISTENCE", policy: policySnapshot })
    }
    if (policyWriteInFlight || !policyAccepted || !policySnapshot) return JSON.stringify({ accepted: false, reasonCode: "HBR-POLICY-UNAVAILABLE" })
    var request
    try { request = JSON.parse(String(requestJson)) } catch (error) { return JSON.stringify({ accepted: false, reasonCode: "HBR-POLICY-MUTATION-MALFORMED" }) }
    if (request.baseRevision !== policySnapshot.revision) return JSON.stringify({ accepted: false, reasonCode: "HBR-POLICY-STALE", policy: policySnapshot })
    if (typeof request.automaticPolicyEnabled !== "boolean" || !Number.isSafeInteger(request.idleDelaySeconds)
      || request.idleDelaySeconds < 300 || request.idleDelaySeconds > 86400)
      return JSON.stringify({ accepted: false, reasonCode: "HBR-POLICY-MUTATION-INVALID", policy: policySnapshot })
    if (policySnapshot.revision === Number.MAX_SAFE_INTEGER)
      return JSON.stringify({ accepted: false, reasonCode: "HBR-POLICY-REVISION-EXHAUSTED", policy: policySnapshot })
    pendingUserPolicy = { version: 1, revision: policySnapshot.revision + 1,
      automaticPolicyEnabled: request.automaticPolicyEnabled, idleDelaySeconds: request.idleDelaySeconds }
    policyWriteInFlight = true
    policyFile.setText(JSON.stringify(pendingUserPolicy, null, 2) + "\n")
    var saved = policyFile.waitForJob()
    return JSON.stringify({ accepted: saved,
      reasonCode: saved ? "HBR-POLICY-SAVED" : "HBR-POLICY-PERSISTENCE",
      policy: policyWriteInFlight ? policySnapshot : pendingUserPolicy })
  }

  function resetUserPolicy(): string {
    if (policySnapshot && policySnapshot.revision === Number.MAX_SAFE_INTEGER)
      return JSON.stringify({ accepted: false, reasonCode: "HBR-POLICY-REVISION-EXHAUSTED", policy: policySnapshot })
    policySnapshot = { version: 1, revision: (policySnapshot ? policySnapshot.revision + 1 : 1), automaticPolicyEnabled: false, idleDelaySeconds: 1800 }
    policyFile.setText(JSON.stringify(policySnapshot, null, 2) + "\n")
    policyReasonCode = "HBR-POLICY-DISABLED"
    return JSON.stringify({ accepted: true, reasonCode: "HBR-POLICY-RESET", policy: policySnapshot })
  }

  function resetHistory(): string {
    if (executionInProgress || historyDocument.openAttempt) {
      return JSON.stringify({ accepted: false, reasonCode: "HBR-HISTORY-ACTIVE-ATTEMPT" })
    }
    historyDocument = emptyHistory()
    rearmRequired = true
    freshActivityObserved = false
    historyHealthy = true
    historyLoaded = true
    nextAttemptNumber = 1
    nextEventNumber = 1
    if (!persistHistory(false)) return JSON.stringify({ accepted: false, reasonCode: "HBR-HISTORY-PERSISTENCE" })
    return JSON.stringify({ accepted: true, reasonCode: "HBR-HISTORY-RESET" })
  }

  function editSystemPolicyDraft(delaySeconds, onAcPower): string {
    var next = { hibernateDelaySeconds: delaySeconds, hibernateOnAcPower: onAcPower, scope: "machine-wide" }
    if (!validSystemPolicy(next)) return policyReceipt(false, "HBR-SYSTEM-POLICY-INVALID-DRAFT")
    systemPolicyDraft = next
    return policyReceipt(true, "HBR-SYSTEM-POLICY-DRAFT-UPDATED")
  }

  function reviewSystemPolicy(): string {
    if (!validSystemPolicy(systemPolicyDraft)) return policyReceipt(false, "HBR-SYSTEM-POLICY-INVALID-DRAFT")
    return policyReceipt(true, "HBR-SYSTEM-POLICY-REVIEW", { pair: systemPolicyDraft })
  }

  function setSystemPolicyFixture(fixtureJson): string {
    if (Quickshell.env("HBR_TEST_MODE") !== "1") return policyReceipt(false, "HBR-SYSTEM-POLICY-UNAVAILABLE")
    try { systemPolicyFixture = JSON.parse(String(fixtureJson)) }
    catch (error) { return policyReceipt(false, "HBR-SYSTEM-POLICY-FIXTURE-MALFORMED") }
    return policyReceipt(true, "HBR-SYSTEM-POLICY-FIXTURE-SET")
  }

  function applySystemPolicy(): string {
    if (contractReadiness("system-policy") !== "ready") return policyReceipt(false, contractReasonCode("system-policy"))
    if (!validSystemPolicy(systemPolicyDraft)) return policyReceipt(false, "HBR-SYSTEM-POLICY-INVALID-DRAFT")
    if (systemPolicyBusy) return policyReceipt(false, "HBR-SYSTEM-POLICY-BUSY")
    var fixture = systemPolicyFixture || {}
    if (fixture.busy) return policyReceipt(false, "HBR-SYSTEM-POLICY-BUSY")
    if (fixture.authorization === "cancelled") return policyReceipt(false, "HBR-SYSTEM-POLICY-AUTH-CANCELLED")
    if (fixture.authorization === "denied") return policyReceipt(false, "HBR-SYSTEM-POLICY-AUTH-DENIED")
    if (fixture.authorization === "unavailable") return policyReceipt(false, "HBR-SYSTEM-POLICY-UNAVAILABLE")
    if (fixture.helper && fixture.helper !== "accepted") return policyReceipt(false, "HBR-SYSTEM-POLICY-HELPER-REJECTED")
    if (fixture.write === "failed") return policyReceipt(false, "HBR-SYSTEM-POLICY-WRITE-FAILED")
    if (fixture.readback === "unavailable") return policyReceipt(false, "HBR-SYSTEM-POLICY-READBACK-INDETERMINATE")
    var requested = { hibernateDelaySeconds: systemPolicyDraft.hibernateDelaySeconds,
      hibernateOnAcPower: systemPolicyDraft.hibernateOnAcPower, scope: "machine-wide" }
    if (Quickshell.env("HBR_TEST_MODE") !== "1") {
      systemPolicyBusy = true
      systemPolicyMutation = "apply"
      helperProcess.command = [helperLauncherPath, helperPath, "apply", String(requested.hibernateDelaySeconds), requested.hibernateOnAcPower ? "yes" : "no"]
      helperProcess.running = true
      return policyReceipt(true, "HBR-SYSTEM-POLICY-SUBMITTED", { pair: requested })
    }
    if (fixture.authorization === "authorized") {
      systemPolicyBusy = true
      systemPolicyMutation = "apply"
      helperProcess.command = [helperLauncherPath, helperPath, "apply", String(requested.hibernateDelaySeconds), requested.hibernateOnAcPower ? "yes" : "no"]
      helperProcess.running = true
      return policyReceipt(true, "HBR-SYSTEM-POLICY-SUBMITTED", { pair: requested })
    }
    var readback = fixture.readbackPolicy || requested
    if (fixture.readback === "contradictory") readback = { hibernateDelaySeconds: requested.hibernateDelaySeconds + 1, hibernateOnAcPower: requested.hibernateOnAcPower }
    if (!systemPolicyMatches(readback, requested))
      return policyReceipt(false, "HBR-SYSTEM-POLICY-READBACK-CONTRADICTORY")
    requestedSystemPolicy = requested
    effectiveSystemPolicy = fixture.effective || requested
    systemPolicyProvenance = fixture.provenance || []
    systemPolicyReasonCode = systemPolicyMatches(effectiveSystemPolicy, requested)
      ? "HBR-SYSTEM-POLICY-APPLIED" : "HBR-SYSTEM-POLICY-DIFFERS"
    requireFreshActivity()
    return policyReceipt(true, systemPolicyReasonCode, { pair: requested })
  }

  function resetSystemPolicy(): string {
    if (contractReadiness("system-policy") !== "ready") return policyReceipt(false, contractReasonCode("system-policy"))
    if (systemPolicyBusy) return policyReceipt(false, "HBR-SYSTEM-POLICY-BUSY")
    if (Quickshell.env("HBR_TEST_MODE") !== "1") {
      systemPolicyBusy = true
      systemPolicyMutation = "reset"
      helperProcess.command = [helperLauncherPath, helperPath, "reset"]
      helperProcess.running = true
      return policyReceipt(true, "HBR-SYSTEM-POLICY-SUBMITTED")
    }
    var fixture = systemPolicyFixture || {}
    if (fixture.busy) return policyReceipt(false, "HBR-SYSTEM-POLICY-BUSY")
    if (fixture.authorization === "unavailable") return policyReceipt(false, "HBR-SYSTEM-POLICY-UNAVAILABLE")
    if (fixture.authorization === "cancelled") return policyReceipt(false, "HBR-SYSTEM-POLICY-AUTH-CANCELLED")
    if (fixture.authorization === "denied") return policyReceipt(false, "HBR-SYSTEM-POLICY-AUTH-DENIED")
    if (fixture.helper && fixture.helper !== "accepted") return policyReceipt(false, "HBR-SYSTEM-POLICY-HELPER-REJECTED")
    if (fixture.authorization === "authorized") {
      systemPolicyBusy = true
      systemPolicyMutation = "reset"
      helperProcess.command = [helperLauncherPath, helperPath, "reset"]
      helperProcess.running = true
      return policyReceipt(true, "HBR-SYSTEM-POLICY-SUBMITTED")
    }
    requestedSystemPolicy = null
    effectiveSystemPolicy = null
    systemPolicyProvenance = []
    systemPolicyReasonCode = "HBR-SYSTEM-POLICY-RESET"
    return policyReceipt(true, "HBR-SYSTEM-POLICY-RESET")
  }

  function requestStagedSleep(): string { return _coordinateStagedSleep("manual") }

  function _coordinateStagedSleep(origin): string {
    if (executionInProgress) return result("refused", "HBR-SLEEP-BUSY", {})
    if (contractReadiness(origin === "manual" ? "manual" : "automatic") !== "ready")
      return result("failed", contractReasonCode(origin === "manual" ? "manual" : "automatic"), { operation: "staged-sleep" })
    if (origin === "automatic" && automaticReadiness() !== "ready") return result("refused", "HBR-SLEEP-AUTOMATIC-SUPPRESSED", {})
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

    var attemptId = origin + "-" + nextAttemptNumber++
    var subscription = subscribeTypedEvidence(attemptId)
    var openAttempt = eventEnvelope(attemptId, origin, selectedMode, "request-enqueue", null,
      "HBR-SLEEP-ENQUEUE-PENDING", "typed-subscription", {
        evidenceSubscribedBeforeEnqueue: subscription.subscribedBeforeEnqueue, entryEvidenceWindowMs: subscription.entryWindowMs,
        postResumeEvidenceWindowMs: postResumeEvidenceWindowMs, deadlinesPauseWhileUserspaceFrozen: true
      })
    var next = clone(historyDocument)
    next.openAttempt = openAttempt
    historyDocument = next
    if (!persistHistory(true)) {
      executionInProgress = false
      return result("failed", "HBR-HISTORY-ATTEMPT-PERSISTENCE-FAILED", {})
    }

    lastSubmission = { attemptId: attemptId, origin: origin, requestedMode: "suspend-then-hibernate",
      selectedMode: selectedMode, selectionPath: selectionPath, simulated: true,
      openAttemptPersistedBeforeEnqueue: true, evidenceSubscribedBeforeEnqueue: true }
    simulatedSleepSubmissionCount += 1

    if (Quickshell.env("HBR_TEST_MODE") !== "1") {
      lastSubmission.simulated = false
      sleepRequestProcess.command = ["systemctl", selectedMode === "suspend" ? "suspend" : "suspend-then-hibernate"]
      sleepRequestProcess.running = true
      return result("accepted", "HBR-SLEEP-ACCEPTED", { attemptId: attemptId,
        selectedMode: selectedMode, selectionPath: selectionPath })
    }

    var observed = evidenceResult(selectionPath)
    if (observed) {
      appendTerminal(eventEnvelope(attemptId, origin, selectedMode, "outcome-reconciliation",
        observed.outcome, observed.reason, observed.evidence, {
          hibernationConfirmed: false, entryEvidenceWindowMs: entryEvidenceWindowMs,
          postResumeEvidenceWindowMs: postResumeEvidenceWindowMs,
          userspaceFreezeExcludedFromDeadline: true, freeFormJournalUsedForState: false,
          evidenceSubscribedBeforeEnqueue: true,
          evidencePhases: ["entry", "resume", "transaction-return"],
          typedSignalsObserved: evidenceSubscription.signals
        }))
      executionInProgress = false
    }
    return result("accepted", "HBR-SLEEP-ACCEPTED", { attemptId: attemptId,
      selectedMode: selectedMode, selectionPath: selectionPath })
  }

  function status(): string {
    lastObservation = observeSleepExecutability()
    if (testActivityFixture !== null) {
      compositorIdleInhibited = testActivityFixture.inhibited
      idleMonitorHealthy = true
    }
    return JSON.stringify(statusSnapshot)
  }

  Process {
    id: contractProbe
    command: [root.contractProbePath]
    stdout: StdioCollector { id: contractProbeStdout; waitForEnd: true }
    onExited: function(exitCode) { root.loadContractProbe(contractProbeStdout.text, exitCode) }
  }

  Process {
    id: sleepCapabilityProbe
    command: ["loginctl", "show-logind", "-p", "CanSuspend", "-p", "CanHibernate", "-p", "CanSuspendThenHibernate", "-p", "BlockInhibited"]
    stdout: StdioCollector { id: sleepCapabilityStdout; waitForEnd: true }
    onExited: function(exitCode) {
      var values = {}
      String(sleepCapabilityStdout.text || "").split("\n").forEach(function(line) {
        var pair = line.split("=")
        if (pair.length === 2) values[pair[0]] = pair[1].trim()
      })
      root.sleepCapabilityProbeHealthy = exitCode === 0
        && values.CanSuspend !== undefined && values.CanHibernate !== undefined
        && values.CanSuspendThenHibernate !== undefined && values.BlockInhibited !== undefined
      if (!root.sleepCapabilityProbeHealthy) {
        root.liveSleepCapabilities = null
        return
      }
      root.liveSleepCapabilities = {
        stagedSleepExecutable: values.CanSuspendThenHibernate === "yes",
        hibernateExecutable: values.CanHibernate === "yes",
        suspendExecutable: values.CanSuspend === "yes",
        systemSleepInhibited: values.BlockInhibited.split(":").indexOf("sleep") >= 0,
        observationFailed: false
      }
    }
  }

  Process {
    id: sleepRequestProcess
    onExited: function(exitCode) {
      var attempt = root.lastSubmission
      if (!attempt) return
      root.appendTerminal(root.eventEnvelope(attempt.attemptId, attempt.origin, attempt.selectedMode,
        "transaction-return", exitCode === 0 ? "Completed" : "Failed",
        exitCode === 0 ? "HBR-SLEEP-TRANSACTION-RETURNED" : "HBR-SLEEP-UNIT-FAILED",
        exitCode === 0 ? "typed-transaction-return" : "typed-unit-result",
        { hibernationConfirmed: false, freeFormJournalUsedForState: false }))
      root.executionInProgress = false
    }
  }

  IdleMonitor {
    id: idleMonitor
    enabled: root.testActivityFixture === null
      ? root.policyAccepted && root.policySnapshot !== null
      : false
    timeout: root.policySnapshot ? root.policySnapshot.idleDelaySeconds : 1800
    respectInhibitors: true
    onIsIdleChanged: root.handleIdleChanged()
  }

  Process {
    id: stayAwakeProbe
    command: ["omarchy-toggle-idle", "status"]
    stdout: StdioCollector { id: stayAwakeStdout; waitForEnd: true }
    onExited: function(exitCode) {
      var parsed = null
      try { parsed = JSON.parse(String(stayAwakeStdout.text || "")) } catch (error) { parsed = null }
      root.finishAutomaticEvaluation(parsed && parsed.enabled === true, exitCode !== 0 || !parsed || typeof parsed.enabled !== "boolean")
    }
  }

  Timer {
    interval: 250
    repeat: true
    running: Quickshell.env("HBR_TEST_MODE") !== "1"
    onTriggered: if (!stayAwakeProbe.running) stayAwakeProbe.running = true
  }

  Timer {
    interval: 250
    repeat: true
    running: Quickshell.env("HBR_TEST_MODE") !== "1"
    onTriggered: if (!sleepCapabilityProbe.running) sleepCapabilityProbe.running = true
  }

  Process {
    id: helperProcess
    stdout: StdioCollector { id: helperStdout; waitForEnd: true }
    onExited: function(exitCode) {
      if (exitCode !== 0) {
        root.systemPolicyBusy = false
        root.systemPolicyReasonCode = "HBR-SYSTEM-POLICY-WRITE-FAILED"
        return
      }
      if (Quickshell.env("HBR_TEST_MODE") !== "1") {
        if (root.systemPolicyMutation === "apply") {
          root.requestedSystemPolicy = root.systemPolicyDraft
          root.systemPolicyReasonCode = "HBR-SYSTEM-POLICY-READBACK-PENDING"
          effectivePolicyProcess.running = true
        } else {
          root.requestedSystemPolicy = null
          root.effectiveSystemPolicy = null
          root.systemPolicyProvenance = []
          root.systemPolicyReasonCode = "HBR-SYSTEM-POLICY-RESET"
          root.systemPolicyMutation = ""
          root.systemPolicyBusy = false
        }
        return
      }
      root.requestedSystemPolicy = root.systemPolicyMutation === "apply" ? root.systemPolicyDraft : null
      var fixture = root.systemPolicyFixture || {}
      root.effectiveSystemPolicy = root.requestedSystemPolicy ? (fixture.effective || root.requestedSystemPolicy) : null
      root.systemPolicyProvenance = root.requestedSystemPolicy ? (fixture.provenance || []) : []
      root.systemPolicyReasonCode = root.requestedSystemPolicy
        ? (root.systemPolicyMatches(root.effectiveSystemPolicy, root.requestedSystemPolicy) ? "HBR-SYSTEM-POLICY-APPLIED" : "HBR-SYSTEM-POLICY-DIFFERS")
        : "HBR-SYSTEM-POLICY-RESET"
      if (root.requestedSystemPolicy) root.requireFreshActivity()
      root.systemPolicyMutation = ""
      root.systemPolicyBusy = false
    }
  }

  Process {
    id: effectivePolicyProcess
    command: [root.effectivePolicyReaderPath, "cat-config", "systemd/sleep.conf"]
    stdout: StdioCollector { id: effectivePolicyStdout; waitForEnd: true }
    onExited: function(exitCode) {
      var text = String(effectivePolicyStdout.text || "")
      var delay = text.match(/HibernateDelaySec=([0-9]+)s/)
      var onAc = text.match(/HibernateOnACPower=(yes|no)/)
      if (exitCode !== 0 || !delay || !onAc || !Number.isSafeInteger(Number(delay[1]))) {
        root.systemPolicyReasonCode = "HBR-SYSTEM-POLICY-READBACK-INDETERMINATE"
      } else {
        root.effectiveSystemPolicy = { hibernateDelaySeconds: Number(delay[1]), hibernateOnAcPower: onAc[1] === "yes" }
        root.systemPolicyProvenance = []
        root.systemPolicyReasonCode = root.systemPolicyMatches(root.effectiveSystemPolicy, root.requestedSystemPolicy)
          ? "HBR-SYSTEM-POLICY-APPLIED" : "HBR-SYSTEM-POLICY-DIFFERS"
        root.requireFreshActivity()
      }
      root.systemPolicyMutation = ""
      root.systemPolicyBusy = false
    }
  }

  Process {
    id: initialPolicyProbe
    command: [root.effectivePolicyReaderPath, "cat-config", "systemd/sleep.conf"]
    stdout: StdioCollector { id: initialPolicyStdout; waitForEnd: true }
    onExited: function(exitCode) {
      var text = String(initialPolicyStdout.text || "")
      var owned = text.indexOf("90-hibermachy.conf") >= 0
      var delay = text.match(/HibernateDelaySec=([0-9]+)s/)
      var onAc = text.match(/HibernateOnACPower=(yes|no)/)
      if (exitCode !== 0 || !owned || !delay || !onAc) return
      var policy = { hibernateDelaySeconds: Number(delay[1]), hibernateOnAcPower: onAc[1] === "yes", scope: "machine-wide" }
      if (!root.validSystemPolicy(policy)) return
      root.requestedSystemPolicy = policy
      root.effectiveSystemPolicy = policy
      root.systemPolicyProvenance = ["/etc/systemd/sleep.conf.d/90-hibermachy.conf"]
      root.systemPolicyReasonCode = "HBR-SYSTEM-POLICY-APPLIED"
    }
  }

  FileView {
    id: policyFile
    path: root.policyPath
    atomicWrites: true
    watchChanges: true
    printErrors: false
    onLoaded: root.loadUserPolicy(text(), data())
    onLoadFailed: root.loadUserPolicy("")
    onSaved: {
      var changed = root.automaticPolicyChanged(root.policySnapshot, root.pendingUserPolicy)
      if (root.pendingUserPolicy) {
        root.policySnapshot = root.pendingUserPolicy
        root.policyReasonCode = root.pendingUserPolicy.automaticPolicyEnabled ? "HBR-POLICY-ENABLED" : "HBR-POLICY-DISABLED"
      }
      if (changed) root.requireFreshActivity()
      root.pendingUserPolicy = null
      root.policyWriteInFlight = false
    }
    onSaveFailed: {
      root.pendingUserPolicy = null
      root.policyWriteInFlight = false
      root.policyAccepted = false
      root.policyReasonCode = "HBR-POLICY-PERSISTENCE"
    }
    onFileChanged: reload()
  }

  Timer {
    interval: 100
    repeat: true
    running: true
    onTriggered: policyFile.reload()
  }

  Timer {
    interval: 100
    repeat: true
    running: true
    onTriggered: if (!policyPermissionProbe.running) policyPermissionProbe.running = true
  }

  Process {
    id: policyPermissionProbe
    command: ["/bin/sh", "-c", "mode=$(stat -c %a \"$1\") || exit 1; case \"$mode\" in 2*|3*|6*|7*) exit 0;; *) exit 1;; esac", "hibermachy-policy-permission", root.policyDirectory]
    onExited: function(exitCode) {
      root.policyDirectoryWritable = exitCode === 0
      if (exitCode !== 0 && root.policyAccepted) root.policyReasonCode = "HBR-POLICY-PERSISTENCE"
    }
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
    id: latchFile
    path: root.latchPath
    atomicWrites: true
    printErrors: false
    onLoaded: root.loadLatch(text())
    onLoadFailed: root.loadLatch("")
  }

  Component.onCompleted: {
    if (Quickshell.env("HBR_TEST_MODE") === "1") idleMonitorHealthy = true
    contractProbe.running = true
    if (Quickshell.env("HBR_TEST_MODE") !== "1") sleepCapabilityProbe.running = true
    if (Quickshell.env("HBR_TEST_MODE") !== "1") initialPolicyProbe.running = true
    policyFile.reload()
    historyFile.reload()
    latchFile.reload()
    Qt.callLater(function() {
      if (root.testActivityFixture === null && !idleMonitor.isIdle) root.observeFreshActivity()
    })
  }

  IpcHandler {
    target: "dev.hibermachy"
    function status(): string { return root.status() }
    function userPolicy(): string { return root.userPolicy() }
    function saveUserPolicy(requestJson: string): string { return root.saveUserPolicy(requestJson) }
    function resetUserPolicy(): string { return root.resetUserPolicy() }
    function resetHistory(): string { return root.resetHistory() }
    function requestStagedSleep(): string { return root.requestStagedSleep() }
    function editSystemPolicyDraft(delaySeconds: int, onAcPower: bool): string { return root.editSystemPolicyDraft(delaySeconds, onAcPower) }
    function reviewSystemPolicy(): string { return root.reviewSystemPolicy() }
    function applySystemPolicy(): string { return root.applySystemPolicy() }
    function resetSystemPolicy(): string { return root.resetSystemPolicy() }
    function setSystemPolicyFixture(fixtureJson: string): string { return root.setSystemPolicyFixture(fixtureJson) }
    function setActivityFixture(fixtureJson: string): string { return root.setActivityFixture(fixtureJson) }
    function setStayAwakeFixture(fixtureJson: string): string { return root.setStayAwakeFixture(fixtureJson) }
    function setClockFixture(fixtureJson: string): string { return root.setClockFixture(fixtureJson) }
    function runAcceleratedSoak(transitions: int): string { return root.runAcceleratedSoak(transitions) }
  }
}
