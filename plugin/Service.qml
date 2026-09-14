import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Item {
  id: root

  // Test mode is an explicit fixture seam used only by the hosted merge gate.
  // Production path and executable selection never consult test overrides.
  readonly property bool testMode: Quickshell.env("HBR_TEST_MODE") === "1"
  readonly property string stateDirectory: String((testMode && Quickshell.env("HIBERMACHY_STATE_DIR")) || Quickshell.env("HOME") + "/.local/state/hibermachy")
  readonly property string historyPath: stateDirectory + "/outcomes.json"
  readonly property string historyArchivePath: stateDirectory + "/outcomes.rejected.json"
  readonly property string journalPath: stateDirectory + "/diagnostics.jsonl"
  readonly property string latchPath: stateDirectory + "/rearm-latch.json"
  property string bootId: testMode ? String(Quickshell.env("HIBERMACHY_SIM_BOOT_ID") || "simulated-boot") : ""
  property var historyAwaitingBoot: null
  readonly property string serviceGeneration: "service-" + Date.now() + "-" + Math.floor(Math.random() * 1000000)
  readonly property int entryEvidenceWindowMs: Math.max(30000, Number((testMode && Quickshell.env("HIBERMACHY_SIM_INHIBITOR_DELAY_MS")) || 0) + 10000)
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
  property bool historyReplacementBlocked: false
  property string rejectedHistoryText: ""
  property bool journalHealthy: true
  property int journalSequence: 0
  readonly property var retryScheduleMs: [1000, 5000, 30000, 300000]
  property int historyRetryAttempt: 0
  property int nextAttemptNumber: 1
  property int nextEventNumber: 1
  property int simulatedSleepSubmissionCount: 0
  property var lastSubmission: null
  property var testClockMs: testMode && Quickshell.env("HBR_TEST_CLOCK_START_MS") ? Number(Quickshell.env("HBR_TEST_CLOCK_START_MS")) : null
  property var liveSleepCapabilities: null
  property bool sleepCapabilityProbeHealthy: false
  property var lastObservation: observeSleepExecutability()
  property var historyDocument: emptyHistory()
  property var evidenceSubscription: null
  readonly property string configHome: (testMode && Quickshell.env("XDG_CONFIG_HOME")) || Quickshell.env("HOME") + "/.config"
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
  property var systemPolicyFixture: ({ authorization: testMode ? "authorized" : "unavailable" })
  readonly property string helperPath: (testMode && Quickshell.env("HBR_POLICY_HELPER_PATH")) || "/usr/libexec/hibermachy-policy-helper"
  readonly property string helperLauncherPath: (testMode && Quickshell.env("HBR_POLICY_HELPER_LAUNCHER")) || "/usr/bin/pkexec"
  readonly property string effectivePolicyReaderPath: (testMode && Quickshell.env("HBR_EFFECTIVE_POLICY_READER")) || decodeURIComponent(String(Qt.resolvedUrl("bin/hibermachy-policy-readback")).replace(/^file:\/\//, ""))
  readonly property string contractProbePath: (testMode && Quickshell.env("HBR_CONTRACT_PROBE")) || decodeURIComponent(String(Qt.resolvedUrl("bin/hibermachy-contract-probe")).replace(/^file:\/\//, ""))
  readonly property string capabilityProbePath: decodeURIComponent(String(Qt.resolvedUrl("bin/hibermachy-sleep-capability-probe")).replace(/^file:\/\//, ""))
  readonly property string evidenceObserverPath: decodeURIComponent(String(Qt.resolvedUrl("bin/hibermachy-sleep-evidence-observer")).replace(/^file:\/\//, ""))
  property bool contractProbeComplete: false
  property var contractSnapshot: null
  property bool evidenceObserverReady: testMode
  property string evidenceObserverAttemptId: ""
  property bool evidenceDispatchStarted: false

  readonly property var statusSnapshot: ({
    pluginActivation: "active",
    schemaVersion: 1,
    envelopeVersion: 1,
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
    historyReplacementBlocked: historyReplacementBlocked,
    openAttempt: historyDocument.openAttempt,
    outcomeHistory: historyDocument.terminalOutcomes.slice(-20),
    outcomeHistoryCount: historyDocument.terminalOutcomes.length,
    suppressionSummaries: historyDocument.suppressionSummaries,
    notificationFingerprints: historyDocument.notificationFingerprints,
    notifications: historyDocument.notifications,
    journalHealth: journalHealthy ? "healthy" : "degraded",
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
    return { schemaVersion: 1, envelopeVersion: 1, openAttempt: null, terminalOutcomes: [],
      suppressionSummaries: [], notificationFingerprints: [], notifications: [] }
  }

  function contractReasonCode(operation): string {
    if (!contractProbeComplete) return "HBR-CONTRACT-PREFLIGHT-PENDING"
    if (!contractSnapshot || !operationContractReady(operation)) {
      if (operation === "manual") return "HBR-CONTRACT-INCOMPATIBLE-MANUAL"
      if (operation === "system-policy") return "HBR-CONTRACT-INCOMPATIBLE-SYSTEM-POLICY"
      if (operation === "diagnostics") return "HBR-CONTRACT-INCOMPATIBLE-DIAGNOSTICS"
      return "HBR-CONTRACT-INCOMPATIBLE-AUTOMATIC"
    }
    return "HBR-CONTRACT-READY"
  }

  function operationContractReady(operation): bool {
    if (!contractSnapshot || !contractSnapshot.observations) return false
    var required = operation === "manual"
      ? ["shellReady", "pluginDiscovery", "pluginActivation", "manifestSchema", "ipcFeatures", "qmlFeatures", "logind"]
      : operation === "system-policy"
        ? ["shellReady", "pluginDiscovery", "pluginActivation", "manifestSchema", "ipcFeatures", "qmlFeatures", "helperProtocol", "systemPolicy"]
      : operation === "diagnostics"
        ? ["shellReady", "pluginDiscovery", "pluginActivation", "manifestSchema", "ipcFeatures", "qmlFeatures", "userPolicy"]
        : ["shellReady", "pluginDiscovery", "pluginActivation", "manifestSchema", "ipcFeatures", "qmlFeatures", "idleMonitor", "helperProtocol", "userPolicy", "systemPolicy", "logind"]
    return required.every(function(key) { return contractSnapshot.observations[key] === true })
      && ((operation !== "automatic" && operation !== "status") || contractSnapshot.majorVersion === 4)
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

  function knownReasonCode(reasonCode): bool {
    var code = String(reasonCode || "")
    return [
      "HBR-SLEEP-TRANSACTION-RETURNED", "HBR-SLEEP-UNIT-FAILED", "HBR-SLEEP-LOCK-FAILED",
      "HBR-SLEEP-SUSPEND-FALLBACK", "HBR-SLEEP-EVIDENCE-MISSING", "HBR-SLEEP-EVIDENCE-CONTRADICTORY",
      "HBR-SLEEP-EARLY-WAKE", "HBR-SLEEP-ENQUEUE-PENDING", "HBR-SLEEP-ACCEPTED", "HBR-SLEEP-AUTOMATIC-SUPPRESSED",
      "HBR-SLEEP-BOOT-CHANGED", "HBR-SLEEP-SERVICE-RECREATED", "HBR-SLEEP-OBSERVATION-FAILED",
      "HBR-SLEEP-SYSTEM-INHIBITED", "HBR-SLEEP-NOT-EXECUTABLE", "HBR-SLEEP-BUSY",
      "HBR-AUTOMATIC-DISABLED", "HBR-AUTOMATIC-READY", "HBR-IDLE-MONITOR-UNAVAILABLE",
      "HBR-COMPOSITOR-IDLE-INHIBITED", "HBR-STAY-AWAKE-ENABLED", "HBR-FRESH-ACTIVITY-REQUIRED",
      "HBR-HISTORY-REARM-PERSISTENCE-FAILED", "HBR-HISTORY-ATTEMPT-PERSISTENCE-FAILED",
      "HBR-HISTORY-ACTIVE-ATTEMPT", "HBR-HISTORY-RESET", "HBR-HISTORY-PERSISTENCE",
      "HBR-HISTORY-ARCHIVE-FAILED", "HBR-DIAGNOSTICS-READY", "HBR-DIAGNOSTICS-DEGRADED",
      "HBR-DIAGNOSTICS-HISTORY-PENDING", "HBR-POLICY-PERSISTENCE", "HBR-POLICY-SAVED",
      "HBR-POLICY-RESET", "HBR-POLICY-UNAVAILABLE", "HBR-SYSTEM-POLICY-APPLIED",
      "HBR-SYSTEM-POLICY-DIFFERS", "HBR-SYSTEM-POLICY-RESET", "HBR-SYSTEM-POLICY-SUBMITTED",
      "HBR-SYSTEM-POLICY-READBACK-INDETERMINATE", "HBR-SYSTEM-POLICY-READBACK-CONTRADICTORY",
      "HBR-CONTRACT-READY", "HBR-CONTRACT-PREFLIGHT-PENDING", "HBR-CONTRACT-PREFLIGHT-FAILED",
      "HBR-CONTRACT-INCOMPATIBLE-AUTOMATIC", "HBR-CONTRACT-INCOMPATIBLE-MANUAL",
      "HBR-CONTRACT-INCOMPATIBLE-DIAGNOSTICS", "HBR-CONTRACT-INCOMPATIBLE-SYSTEM-POLICY", "HBR-MANUAL-READY"
    ].indexOf(code) >= 0
  }

  function safeHumanCopy(outcome, reasonCode): string {
    if (!knownReasonCode(reasonCode)) return "The service recorded an additional diagnostic outcome."
    if (outcome === "Suppressed") return "Automatic staged sleep was suppressed."
    if (outcome === "Refused") return "The sleep request was refused safely."
    if (outcome === "Degraded") return "The request completed using a safe fallback."
    if (outcome === "Failed") return "The sleep request failed before completion was established."
    if (outcome === "Indeterminate") return "The result could not be determined without replaying the request."
    if (outcome === "Completed") return "The observable sleep transaction returned; hibernation is not confirmed."
    return "The service recorded a diagnostic outcome."
  }

  function safeReasonIdentity(reasonCode): string {
    var code = String(reasonCode || "")
    return knownReasonCode(code) ? code : "HBR-DIAGNOSTICS-UNKNOWN-REASON"
  }

  function sanitizedProvenance(values): var {
    return (values || []).map(function(value) {
      var text = String(value || "")
      if (text === "/etc/systemd/sleep.conf.d/90-hibermachy.conf") return "hibermachy-owned-policy"
      if (text.indexOf("/etc/systemd/") === 0) return "administrator-system-policy"
      return "other-policy-source"
    })
  }

  function safeEnum(value, allowed, fallback): string {
    var text = String(value || "")
    return allowed.indexOf(text) >= 0 ? text : fallback
  }

  function sanitizedOutcome(value): var {
    value = value && typeof value === "object" ? value : ({})
    return { schemaVersion: 1, envelopeVersion: 1, operation: "staged-sleep",
      phase: safeEnum(value.phase, ["eligibility-evaluation", "request-enqueue", "outcome-reconciliation"], "unknown"),
      outcome: safeEnum(value.outcome, ["Suppressed", "Refused", "Degraded", "Failed", "Indeterminate", "Completed"], "unknown"),
      reasonCode: safeReasonIdentity(value.reasonCode),
      evidenceLevel: safeEnum(value.evidenceLevel, ["typed-eligibility", "typed-capability", "typed-transaction-return", "typed-unit-result", "typed-lock-result", "missing-typed-evidence", "contradictory-typed-evidence", "recovered-after-boot", "recovered-after-service-recreation", "none"], "none"),
      requestedMode: "suspend-then-hibernate",
      selectedMode: safeEnum(value.selectedMode, ["suspend-then-hibernate", "suspend", "none"], "none"),
      hibernationConfirmed: value.details && value.details.hibernationConfirmed === true }
  }

  function copyDiagnostics(): string {
    var outcomes = (historyDocument.terminalOutcomes || []).slice(-20).map(sanitizedOutcome)
    var value = { schemaVersion: 1, envelopeVersion: 1, format: "hibermachy-diagnostics-v1",
      componentVersions: { service: "1", protocol: "1", plugin: "1" },
      readiness: { automatic: automaticReadiness(), manual: manualReadiness(lastObservation),
        systemPolicy: statusSnapshot.systemPolicyReadiness, diagnostics: diagnosticsReadiness() },
      policy: policySnapshot ? { automaticPolicyEnabled: policySnapshot.automaticPolicyEnabled,
        idleDelaySeconds: policySnapshot.idleDelaySeconds, revision: policySnapshot.revision } : null,
      systemPolicy: { requested: requestedSystemPolicy ? { hibernateDelaySeconds: requestedSystemPolicy.hibernateDelaySeconds,
          hibernateOnAcPower: requestedSystemPolicy.hibernateOnAcPower } : null,
        effective: effectiveSystemPolicy ? { hibernateDelaySeconds: effectiveSystemPolicy.hibernateDelaySeconds,
          hibernateOnAcPower: effectiveSystemPolicy.hibernateOnAcPower } : null,
        provenance: sanitizedProvenance(systemPolicyProvenance) },
      capabilities: lastObservation ? { stagedSleepExecutable: !!lastObservation.stagedSleepExecutable,
        suspendExecutable: !!lastObservation.suspendExecutable, hibernateExecutable: !!lastObservation.hibernateExecutable,
        systemSleepInhibited: !!lastObservation.systemSleepInhibited, observationFailed: !!lastObservation.observationFailed } : null,
      history: { health: historyHealthy ? "healthy" : "degraded", replacementBlocked: historyReplacementBlocked,
        outcomeCount: outcomes.length, outcomes: outcomes },
      journal: { health: journalHealthy ? "healthy" : "degraded" },
      notifications: (historyDocument.notifications || []).slice(-20).map(function(item) {
        item = item && typeof item === "object" ? item : ({})
        var outcome = safeEnum(item.outcome, ["Suppressed", "Refused", "Degraded", "Failed", "Indeterminate", "Completed"], "unknown")
        var reasonCode = safeReasonIdentity(item.reasonCode)
        return { outcome: outcome, reasonCode: reasonCode, humanCopy: safeHumanCopy(outcome, reasonCode) }
      }) }
    return JSON.stringify(value, null, 2) + "\n"
  }

  function retryDelayMs(attempt): int {
    return retryScheduleMs[Math.min(Math.max(0, attempt), retryScheduleMs.length - 1)]
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
    if (!stayAwakeKnown) return "HBR-STAY-AWAKE-UNKNOWN"
    if (stayAwakeEnabled) return "HBR-STAY-AWAKE-ENABLED"
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
    if (!requestedSystemPolicy || !effectiveSystemPolicy || !["HBR-SYSTEM-POLICY-APPLIED", "HBR-SYSTEM-POLICY-DIFFERS"].includes(systemPolicyReasonCode)) return "not-ready"
    if (!idleMonitorHealthy || compositorIdleInhibited || !stayAwakeKnown || stayAwakeEnabled) return "not-ready"
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

  property var testActivityFixture: testMode ? ({ idle: false, inhibited: false }) : null
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
    if (!testMode) return result("refused", "HBR-TEST-FIXTURE-UNAVAILABLE", {})
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
    if (!testMode) return fallback
    var value = String(Quickshell.env(name) || "").toLowerCase()
    if (value === "1" || value === "true" || value === "yes") return true
    if (value === "0" || value === "false" || value === "no") return false
    return fallback
  }

  function observeSleepExecutability(): var {
    if (!testMode) {
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
    return JSON.stringify(Object.assign({ schemaVersion: 1, envelopeVersion: 1,
      kind: kind, reasonCode: reasonCode }, details || {}))
  }

  function setClockFixture(fixtureJson): string {
    if (!testMode) return result("refused", "HBR-TEST-FIXTURE-UNAVAILABLE", {})
    try {
      var fixture = JSON.parse(String(fixtureJson))
      if (!fixture || !Number.isSafeInteger(fixture.nowMs) || fixture.nowMs < 0) throw new Error("clock")
      testClockMs = fixture.nowMs
      return result("accepted", "HBR-TEST-CLOCK-SET", { nowMs: testClockMs })
    } catch (error) { return result("refused", "HBR-TEST-CLOCK-MALFORMED", {}) }
  }

  function runAcceleratedSoak(transitions: int): string {
    if (!testMode) return result("refused", "HBR-TEST-FIXTURE-UNAVAILABLE", {})
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
      if (receipt.kind === "accepted") {
        accepted += 1
        if (attemptIds[receipt.attemptId]) duplicateAttempt = true
        attemptIds[receipt.attemptId] = true
      } else refused += 1
      maxHistory = Math.max(maxHistory, (historyDocument.terminalOutcomes || []).length)
      maxNotifications = Math.max(maxNotifications, (historyDocument.notifications || []).length)
      if (index === 0 || index % 100 === 99 || index === count - 1)
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
  function clockNowMs(): var { return testClockMs === null ? Date.now() : testClockMs }
  function nowWallTime(): string { return new Date(clockNowMs()).toISOString() }

  function eventEnvelope(attemptId, origin, selectedMode, phase, outcome, reasonCode, evidenceLevel, details): var {
    var eventId = "event-" + nextEventNumber++
    return {
      schemaVersion: 1, envelopeVersion: 1, eventId: eventId, correlationId: attemptId || eventId, attemptId: attemptId,
      wallTime: nowWallTime(), monotonicTimeMs: clockNowMs(), bootId: bootId,
      serviceGeneration: serviceGeneration, origin: origin, operation: "staged-sleep", phase: phase,
      outcome: outcome, reasonCode: safeReasonIdentity(reasonCode), requestedMode: "suspend-then-hibernate",
      selectedMode: selectedMode || "none", evidenceLevel: evidenceLevel, details: details || {}
    }
  }

  function validOutcomeEntry(value): bool {
    return value && typeof value === "object" && typeof value.wallTime === "string"
      && typeof value.phase === "string" && typeof value.outcome === "string"
      && typeof value.reasonCode === "string" && typeof value.evidenceLevel === "string"
      && typeof value.requestedMode === "string" && typeof value.selectedMode === "string"
      && value.details && typeof value.details === "object"
  }

  function validNotification(value): bool {
    return value && typeof value === "object" && typeof value.outcome === "string"
      && typeof value.reasonCode === "string" && typeof value.humanCopy === "string"
  }

  function validHistory(value): bool {
    return value && value.schemaVersion === 1 && Array.isArray(value.terminalOutcomes)
      && Array.isArray(value.suppressionSummaries) && Array.isArray(value.notificationFingerprints)
      && value.terminalOutcomes.every(validOutcomeEntry)
      && (value.notifications === undefined || (Array.isArray(value.notifications) && value.notifications.every(validNotification)))
      && (value.openAttempt === null || typeof value.openAttempt === "object")
  }

  function loadBootIdentity(raw): void {
    if (testMode) return
    var identity = String(raw || "").trim().toLowerCase()
    if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/.test(identity)) {
      historyHealthy = false
      return
    }
    bootId = identity
    if (historyAwaitingBoot !== null) {
      var pending = historyAwaitingBoot
      historyAwaitingBoot = null
      loadHistory(pending)
    }
  }

  function loadHistory(raw): void {
    if (historyLoaded) return
    if (!bootId) {
      historyAwaitingBoot = String(raw || "")
      return
    }
    if (simulatedBoolean("HIBERMACHY_SIM_HISTORY_FAILURE", false)) {
      historyHealthy = false
      historyLoaded = true
      return
    }
    if (String(raw || "").trim() !== "") {
      try {
        var parsed = JSON.parse(raw)
        if (!validHistory(parsed)) throw new Error("unsupported history schema")
        parsed.envelopeVersion = parsed.envelopeVersion || 1
        parsed.notifications = parsed.notifications || []
        historyDocument = parsed
      } catch (error) {
        historyHealthy = false
        historyReplacementBlocked = true
        rejectedHistoryText = String(raw)
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
    if (!bootId || historyAwaitingBoot !== null || historyReplacementBlocked) return false
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
      subscribedBeforeEnqueue: testMode || evidenceObserverReady,
      signals: testMode ? ["PrepareForSleep", "UnitResult", "TransactionReturn"] : ["PrepareForSleep", "JobRemoved", "PropertiesChanged"],
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
    next.notifications = next.notifications || []
    next.openAttempt = null
    next.terminalOutcomes.push(envelope)
    next.terminalOutcomes = trimHistory(next.terminalOutcomes)
    next.suppressionSummaries = next.suppressionSummaries.slice(-32)
    if (envelope.outcome === "Completed") {
      next.notificationFingerprints = []
      next.notifications = []
    } else if (envelope.outcome === "Failed" || envelope.outcome === "Indeterminate" || envelope.outcome === "Degraded") {
      var fingerprint = envelope.outcome + ":" + envelope.reasonCode
      var shouldNotify = envelope.outcome === "Degraded" || envelope.origin === "automatic"
      if (shouldNotify && next.notificationFingerprints.indexOf(fingerprint) < 0) {
        next.notificationFingerprints.push(fingerprint)
        var notification = { schemaVersion: 1, envelopeVersion: 1, outcome: envelope.outcome,
          reasonCode: envelope.reasonCode, humanCopy: safeHumanCopy(envelope.outcome, envelope.reasonCode) }
        next.notifications.push(notification)
        sendNotification(notification)
      }
    }
    next.notificationFingerprints = next.notificationFingerprints.slice(-64)
    next.notifications = next.notifications.slice(-20)
    historyDocument = next
    appendJournal(envelope)
    persistHistory()
  }

  function appendJournal(envelope): void {
    journalSequence += 1
    if (testMode && simulatedBoolean("HIBERMACHY_SIM_JOURNAL_FAILURE", false)) {
      journalHealthy = false
      return
    }
    if (testMode) {
      journalHealthy = true
      return
    }
    var entry = sanitizedOutcome(envelope)
    entry.sequence = journalSequence
    journalHealthy = true
    journalFile.setText(JSON.stringify(entry) + "\n")
  }

  function sendNotification(notification): void {
    if (testMode) return
    notificationProcess.command = ["/usr/share/omarchy/bin/omarchy-notification-send", "Hibermachy", notification.humanCopy]
    notificationProcess.running = true
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
    var rawReason = testMode ? Quickshell.env("HIBERMACHY_SIM_SUPPRESSION_REASON") : ""
    var reason = safeReasonIdentity(rawReason || "")
    if (reason === "HBR-DIAGNOSTICS-UNKNOWN-REASON" && !rawReason) return
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

  function recordPreSubmissionOutcome(origin, kind, reasonCode): string {
    appendTerminal(eventEnvelope(null, origin, "none", "eligibility-evaluation",
      kind === "failed" ? "Failed" : "Refused", reasonCode, "typed-capability", {}))
    executionInProgress = false
    return result(kind, reasonCode, {})
  }

  function evidenceResult(selectionPath): var {
    var scenario = String((testMode && Quickshell.env("HIBERMACHY_SIM_EVIDENCE")) || "completed")
    if (selectionPath === "suspend-fallback") return { outcome: "Degraded", reason: "HBR-SLEEP-SUSPEND-FALLBACK", evidence: "typed-transaction-return" }
    if (scenario === "unit-failure") return { outcome: "Failed", reason: "HBR-SLEEP-UNIT-FAILED", evidence: "typed-unit-result" }
    if (scenario === "lock-failure") return { outcome: "Failed", reason: "HBR-SLEEP-LOCK-FAILED", evidence: "typed-lock-result" }
    if (scenario === "early-wake") return { outcome: "Completed", reason: "HBR-SLEEP-EARLY-WAKE", evidence: "typed-transaction-return" }
    if (scenario === "missing") return { outcome: "Indeterminate", reason: "HBR-SLEEP-EVIDENCE-MISSING", evidence: "missing-typed-evidence" }
    if (scenario === "contradictory") return { outcome: "Indeterminate", reason: "HBR-SLEEP-EVIDENCE-CONTRADICTORY", evidence: "contradictory-typed-evidence" }
    if (scenario === "pending" || simulatedBoolean("HIBERMACHY_SIM_HOLD_BUSY", false)) return null
    return { outcome: "Completed", reason: "HBR-SLEEP-TRANSACTION-RETURNED", evidence: "typed-transaction-return" }
  }

  function finishObservedAttempt(event): void {
    if (!executionInProgress || !lastSubmission || !event || event.attemptId !== lastSubmission.attemptId) return
    var outcome = safeEnum(event.outcome, ["Failed", "Indeterminate", "Completed"], "Indeterminate")
    var reason = safeReasonIdentity(event.reasonCode)
    var evidence = safeEnum(event.evidenceLevel,
      ["typed-transaction-return", "typed-unit-result", "missing-typed-evidence", "contradictory-typed-evidence"],
      "missing-typed-evidence")
    appendTerminal(eventEnvelope(lastSubmission.attemptId, lastSubmission.origin, lastSubmission.selectedMode,
      "outcome-reconciliation", outcome, reason, evidence, {
        hibernationConfirmed: false, evidenceObserver: true, freeFormJournalUsedForState: false
      }))
    evidenceObserverAttemptId = ""
    evidenceDispatchStarted = false
    executionInProgress = false
  }

  function dispatchObservedSleepRequest(): void {
    if (!executionInProgress || !lastSubmission || !evidenceObserverAttemptId
      || evidenceObserverAttemptId !== lastSubmission.attemptId || evidenceDispatchStarted) return
    evidenceArmTimer.stop()
    evidenceDispatchStarted = true
    lastSubmission.evidenceSubscribedBeforeEnqueue = true
    sleepRequestProcess.command = ["/usr/bin/systemctl", lastSubmission.selectedMode === "suspend" ? "suspend" : "suspend-then-hibernate"]
    sleepRequestProcess.running = true
  }

  function handleEvidenceObserverLine(line): void {
    var event = null
    try { event = JSON.parse(String(line || "")) } catch (error) { event = null }
    if (!event || typeof event !== "object") return
    if (event.kind === "readiness") {
      evidenceObserverReady = event.ready === true
      return
    }
    if (event.kind === "attempt-armed" && event.attemptId === evidenceObserverAttemptId) {
      dispatchObservedSleepRequest()
      return
    }
    if (event.kind === "terminal") finishObservedAttempt(event)
  }

  function policyReceipt(accepted, reasonCode, extra): string {
    var value = { schemaVersion: 1, envelopeVersion: 1, accepted: accepted, reasonCode: reasonCode,
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

  function policyTopLevelKeys(raw): var {
    var text = String(raw || ""), keys = [], depth = 0, index = 0
    while (index < text.length) {
      var character = text[index]
      if (character === '"') {
        var start = index++
        while (index < text.length) {
          if (text[index] === "\\") { index += 2; continue }
          if (text[index++] === '"') break
        }
        var literal = text.slice(start, index)
        while (index < text.length && /\s/.test(text[index])) index += 1
        if (depth === 1 && text[index] === ":") keys.push(JSON.parse(literal))
        continue
      }
      if (character === "{") depth += 1
      else if (character === "}") depth -= 1
      index += 1
    }
    return keys
  }

  function loadUserPolicy(raw, bytes): void {
    lastObservedPolicyText = String(raw || "")
    if ((bytes && bytes.byteLength > 16384) || String(raw).length > 16384) { policyAccepted = false; policyReasonCode = "HBR-POLICY-SIZE"; return }
    if (bytes && bytes.byteLength >= 3) {
      var octets = new Uint8Array(bytes)
      if (octets[0] === 0xEF && octets[1] === 0xBB && octets[2] === 0xBF) { policyAccepted = false; policyReasonCode = "HBR-POLICY-ENCODING"; return }
    }
    if (String(raw).charCodeAt(0) === 0xFEFF || String(raw).indexOf("\uFFFD") >= 0) { policyAccepted = false; policyReasonCode = "HBR-POLICY-ENCODING"; return }
    if (policyWriteInFlight) return
    if (String(raw || "").trim() === "") {
      policyAccepted = false
      policyReasonCode = "HBR-POLICY-MALFORMED"
      return
    }
    var keys
    try { keys = policyTopLevelKeys(raw) } catch (error) { keys = null }
    var requiredKeys = ["version", "revision", "automaticPolicyEnabled", "idleDelaySeconds"]
    if (keys && keys.some(function(key, index) { return keys.indexOf(key) !== index })) {
      policyAccepted = false
      policyReasonCode = "HBR-POLICY-DUPLICATE-KEY"
      return
    }
    if (!keys || keys.length !== 4 || requiredKeys.some(function(key) { return keys.indexOf(key) < 0 })) {
      policyAccepted = false; policyReasonCode = "HBR-POLICY-KEYS"; return
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
        if (value.revision === Number.MAX_SAFE_INTEGER) {
          policyAccepted = false; policyReasonCode = "HBR-POLICY-REVISION-EXHAUSTED"; return
        }
        value.revision += 1
      }
      var canonical = JSON.stringify({ version: 1, revision: value.revision,
        automaticPolicyEnabled: value.automaticPolicyEnabled, idleDelaySeconds: value.idleDelaySeconds }, null, 2) + "\n"
      if (String(raw) !== canonical) {
        pendingUserPolicy = value
        policyWriteInFlight = true
        policyAccepted = false
        Qt.callLater(function() { policyFile.setText(canonical) })
        return
      }
      policySnapshot = value
      policyReasonCode = !policyDirectoryWritable ? "HBR-POLICY-PERSISTENCE"
        : (value.automaticPolicyEnabled ? "HBR-POLICY-ENABLED" : "HBR-POLICY-DISABLED")
      if (policyChanged) requireFreshActivity()
    } catch (error) {
      policyAccepted = false
      policyReasonCode = "HBR-POLICY-MALFORMED"
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
      policy: policySnapshot })
  }

  function resetUserPolicy(): string {
    if (policyWriteInFlight) return JSON.stringify({ accepted: false, reasonCode: "HBR-POLICY-UNAVAILABLE", policy: policySnapshot })
    if (policySnapshot && policySnapshot.revision === Number.MAX_SAFE_INTEGER)
      return JSON.stringify({ accepted: false, reasonCode: "HBR-POLICY-REVISION-EXHAUSTED", policy: policySnapshot })
    pendingUserPolicy = { version: 1, revision: (policySnapshot ? policySnapshot.revision + 1 : 1), automaticPolicyEnabled: false, idleDelaySeconds: 1800 }
    policyWriteInFlight = true
    policyFile.setText(JSON.stringify(pendingUserPolicy, null, 2) + "\n")
    var saved = policyFile.waitForJob()
    return JSON.stringify({ accepted: saved, reasonCode: saved ? "HBR-POLICY-RESET" : "HBR-POLICY-PERSISTENCE", policy: policySnapshot })
  }

  function resetHistory(): string {
    if (executionInProgress || historyDocument.openAttempt) {
      return result("refused", "HBR-HISTORY-ACTIVE-ATTEMPT", { accepted: false })
    }
    if (historyReplacementBlocked) {
      historyArchiveFile.setText(rejectedHistoryText)
      if (!historyArchiveFile.waitForJob()) return result("failed", "HBR-HISTORY-ARCHIVE-FAILED", { accepted: false })
      historyReplacementBlocked = false
      rejectedHistoryText = ""
    }
    historyDocument = emptyHistory()
    rearmRequired = true
    freshActivityObserved = false
    historyHealthy = true
    historyLoaded = true
    nextAttemptNumber = 1
    nextEventNumber = 1
    if (!persistHistory(false)) return result("failed", "HBR-HISTORY-PERSISTENCE", { accepted: false })
    return result("accepted", "HBR-HISTORY-RESET", { accepted: true })
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
    if (!testMode) return policyReceipt(false, "HBR-SYSTEM-POLICY-UNAVAILABLE")
    try { systemPolicyFixture = JSON.parse(String(fixtureJson)) }
    catch (error) { return policyReceipt(false, "HBR-SYSTEM-POLICY-FIXTURE-MALFORMED") }
    return policyReceipt(true, "HBR-SYSTEM-POLICY-FIXTURE-SET")
  }

  function applySystemPolicy(): string {
    if (contractReadiness("system-policy") !== "ready") return policyReceipt(false, contractReasonCode("system-policy"))
    if (!validSystemPolicy(systemPolicyDraft)) return policyReceipt(false, "HBR-SYSTEM-POLICY-INVALID-DRAFT")
    if (systemPolicyBusy) return policyReceipt(false, "HBR-SYSTEM-POLICY-BUSY")
    var fixture = testMode ? (systemPolicyFixture || {}) : {}
    if (fixture.busy) return policyReceipt(false, "HBR-SYSTEM-POLICY-BUSY")
    if (fixture.authorization === "cancelled") return policyReceipt(false, "HBR-SYSTEM-POLICY-AUTH-CANCELLED")
    if (fixture.authorization === "denied") return policyReceipt(false, "HBR-SYSTEM-POLICY-AUTH-DENIED")
    if (fixture.authorization === "unavailable") return policyReceipt(false, "HBR-SYSTEM-POLICY-UNAVAILABLE")
    if (fixture.helper && fixture.helper !== "accepted") return policyReceipt(false, "HBR-SYSTEM-POLICY-HELPER-REJECTED")
    if (fixture.write === "failed") return policyReceipt(false, "HBR-SYSTEM-POLICY-WRITE-FAILED")
    if (fixture.readback === "unavailable") return policyReceipt(false, "HBR-SYSTEM-POLICY-READBACK-INDETERMINATE")
    var requested = { hibernateDelaySeconds: systemPolicyDraft.hibernateDelaySeconds,
      hibernateOnAcPower: systemPolicyDraft.hibernateOnAcPower, scope: "machine-wide" }
    if (!testMode) {
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
    if (!testMode) {
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
    if (!bootId) return result("failed", "HBR-DIAGNOSTICS-HISTORY-PENDING", { operation: "staged-sleep" })
    if (contractReadiness(origin === "manual" ? "manual" : "automatic") !== "ready")
      return result("failed", contractReasonCode(origin === "manual" ? "manual" : "automatic"), { operation: "staged-sleep" })
    if (origin === "automatic" && automaticReadiness() !== "ready") return result("refused", "HBR-SLEEP-AUTOMATIC-SUPPRESSED", {})
    executionInProgress = true
    var observation = observeSleepExecutability()
    lastObservation = observation
    if (observation.observationFailed) return recordPreSubmissionOutcome(origin, "failed", "HBR-SLEEP-OBSERVATION-FAILED")
    if (observation.systemSleepInhibited) return recordPreSubmissionOutcome(origin, "refused", "HBR-SLEEP-SYSTEM-INHIBITED")

    var selectedMode = ""
    var selectionPath = ""
    if (observation.stagedSleepExecutable && (!contractSnapshot || !contractSnapshot.observations
      || contractSnapshot.observations.helperProtocol === true)) {
      selectedMode = "suspend-then-hibernate"
      selectionPath = "staged-sleep"
    } else if (observation.suspendExecutable) {
      selectedMode = "suspend"
      selectionPath = "suspend-fallback"
    } else return recordPreSubmissionOutcome(origin, "refused", "HBR-SLEEP-NOT-EXECUTABLE")

    if ((!testMode && (!evidenceObserverReady || !evidenceObserverProcess.running))
      || (testMode && !simulatedBoolean("HIBERMACHY_SIM_OBSERVER_READY", true)))
      return recordPreSubmissionOutcome(origin, "failed", "HBR-SLEEP-OBSERVATION-FAILED")

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

    if (!testMode) {
      lastSubmission.simulated = false
      evidenceObserverAttemptId = attemptId
      evidenceDispatchStarted = false
      evidenceObserverProcess.write(JSON.stringify({ type: "attempt-submitted", attemptId: attemptId, selectedMode: selectedMode }) + "\n")
      evidenceArmTimer.restart()
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
    if (!testMode && !systemPolicyBusy && !initialPolicyProbe.running && !effectivePolicyProcess.running) initialPolicyProbe.running = true
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
    command: [root.capabilityProbePath]
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
    id: evidenceObserverProcess
    command: [root.evidenceObserverPath]
    stdinEnabled: true
    stdout: SplitParser { onRead: function(line) { root.handleEvidenceObserverLine(line) } }
    onExited: function(exitCode) {
      root.evidenceObserverReady = false
      if (!root.executionInProgress || !root.lastSubmission || root.testMode) return
      root.finishObservedAttempt({ attemptId: root.lastSubmission.attemptId, outcome: root.evidenceDispatchStarted ? "Indeterminate" : "Failed",
        reasonCode: "HBR-SLEEP-OBSERVATION-FAILED", evidenceLevel: "missing-typed-evidence" })
    }
  }

  Timer {
    id: evidenceArmTimer
    interval: 2000
    repeat: false
    onTriggered: root.finishObservedAttempt({ attemptId: root.evidenceObserverAttemptId, outcome: "Failed",
      reasonCode: "HBR-SLEEP-OBSERVATION-FAILED", evidenceLevel: "missing-typed-evidence" })
  }

  Process {
    id: sleepRequestProcess
    onExited: function(exitCode) {
      var attempt = root.lastSubmission
      if (!attempt || !root.executionInProgress || exitCode === 0) return
      root.finishObservedAttempt({ attemptId: attempt.attemptId, outcome: "Failed",
        reasonCode: "HBR-SLEEP-UNIT-FAILED", evidenceLevel: "typed-unit-result" })
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
    command: ["/usr/bin/omarchy-toggle-idle", "status"]
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
    running: !root.testMode
    onTriggered: if (!stayAwakeProbe.running) stayAwakeProbe.running = true
  }

  Timer {
    interval: 250
    repeat: true
    running: !root.testMode
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
      if (!root.testMode) {
        root.systemPolicyReasonCode = "HBR-SYSTEM-POLICY-READBACK-PENDING"
        effectivePolicyProcess.running = true
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
    id: notificationProcess
  }

  function loadSystemPolicyReadback(text, exitCode) {
    var previousPolicy = JSON.stringify([requestedSystemPolicy, effectiveSystemPolicy, systemPolicyReasonCode])
    var observed = null
    try { observed = JSON.parse(text) } catch (_) {}
    effectiveSystemPolicy = null
    systemPolicyProvenance = []
    if (exitCode !== 0 || !observed || observed.indeterminate) {
      requestedSystemPolicy = null
      systemPolicyReasonCode = "HBR-SYSTEM-POLICY-READBACK-INDETERMINATE"
      return
    }
    requestedSystemPolicy = observed.requested && validSystemPolicy(observed.requested) ? observed.requested : null
    var effective = observed.effective
    if (effective && typeof effective.hibernateDelaySeconds === "number" && isFinite(effective.hibernateDelaySeconds)
        && effective.hibernateDelaySeconds >= 0 && typeof effective.hibernateOnAcPower === "boolean")
      effectiveSystemPolicy = effective
    systemPolicyProvenance = Array.isArray(observed.provenance) ? observed.provenance : []
    if (!requestedSystemPolicy) systemPolicyReasonCode = systemPolicyMutation === "reset" ? "HBR-SYSTEM-POLICY-RESET" : "HBR-SYSTEM-POLICY-NOT-READY"
    else if (!effectiveSystemPolicy) systemPolicyReasonCode = "HBR-SYSTEM-POLICY-READBACK-INDETERMINATE"
    else systemPolicyReasonCode = systemPolicyMatches(effectiveSystemPolicy, requestedSystemPolicy)
      ? "HBR-SYSTEM-POLICY-APPLIED" : "HBR-SYSTEM-POLICY-DIFFERS"
    if (previousPolicy !== JSON.stringify([requestedSystemPolicy, effectiveSystemPolicy, systemPolicyReasonCode])) requireFreshActivity()
  }

  Timer {
    interval: 5000
    repeat: true
    running: !root.testMode
    onTriggered: if (!root.systemPolicyBusy && !initialPolicyProbe.running && !effectivePolicyProcess.running) initialPolicyProbe.running = true
  }

  Process {
    id: effectivePolicyProcess
    command: [root.effectivePolicyReaderPath]
    stdout: StdioCollector { id: effectivePolicyStdout; waitForEnd: true }
    onExited: function(exitCode) {
      root.loadSystemPolicyReadback(effectivePolicyStdout.text, exitCode)
      root.systemPolicyMutation = ""
      root.systemPolicyBusy = false
    }
  }

  Process {
    id: initialPolicyProbe
    command: [root.effectivePolicyReaderPath]
    stdout: StdioCollector { id: initialPolicyStdout; waitForEnd: true }
    onExited: function(exitCode) { root.loadSystemPolicyReadback(initialPolicyStdout.text, exitCode) }
  }

  FileView {
    id: policyFile
    path: root.policyPath
    atomicWrites: true
    watchChanges: true
    printErrors: false
    onLoaded: root.loadUserPolicy(text(), data())
    onLoadFailed: function(error) {
      if (error === FileViewError.FileNotFound && !root.policySnapshot && !root.policyWriteInFlight) {
        root.pendingUserPolicy = { version: 1, revision: 1, automaticPolicyEnabled: false, idleDelaySeconds: 1800 }
        root.policyWriteInFlight = true
        root.policyAccepted = false
        Qt.callLater(function() { if (root.pendingUserPolicy) policyFile.setText(JSON.stringify(root.pendingUserPolicy, null, 2) + "\n") })
      } else {
        root.policyAccepted = false
        root.policyReasonCode = error === FileViewError.FileNotFound ? "HBR-POLICY-MISSING" : "HBR-POLICY-PERSISTENCE"
      }
    }
    onSaved: {
      var changed = root.automaticPolicyChanged(root.policySnapshot, root.pendingUserPolicy)
      if (root.pendingUserPolicy) {
        root.policySnapshot = root.pendingUserPolicy
        root.policyAccepted = true
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
    command: ["/usr/bin/stat", "-c", "%a", root.policyDirectory]
    stdout: StdioCollector { id: policyPermissionStdout; waitForEnd: true }
    onExited: function(exitCode) {
      var mode = String(policyPermissionStdout.text || "").trim()
      root.policyDirectoryWritable = exitCode === 0 && /^(2|3|6|7)/.test(mode)
      if (exitCode !== 0 && root.policyAccepted) root.policyReasonCode = "HBR-POLICY-PERSISTENCE"
    }
  }

  FileView {
    id: bootIdentityFile
    path: root.testMode ? "" : "/proc/sys/kernel/random/boot_id"
    printErrors: false
    onLoaded: root.loadBootIdentity(text())
    onLoadFailed: { if (!root.testMode) root.historyHealthy = false }
  }

  FileView {
    id: historyFile
    path: root.historyPath
    atomicWrites: true
    printErrors: false
    onLoaded: root.loadHistory(text())
    onLoadFailed: root.loadHistory("")
  }

  Timer {
    id: historyRetryTimer
    interval: root.retryDelayMs(root.historyRetryAttempt)
    repeat: true
    running: root.historyLoaded && !root.historyHealthy && !root.historyReplacementBlocked

    onTriggered: {
      root.historyRetryAttempt = Math.min(root.historyRetryAttempt + 1, root.retryScheduleMs.length - 1)
      if (root.persistHistory(false)) {
        root.historyHealthy = true
        root.historyRetryAttempt = 0
      }
    }
  }

  FileView {
    id: historyArchiveFile
    path: root.historyArchivePath
    atomicWrites: true
    printErrors: false
  }

  FileView {
    id: journalFile
    path: root.journalPath
    atomicWrites: true
    printErrors: false
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
    if (root.testMode) idleMonitorHealthy = true
    contractProbe.running = true
    if (!root.testMode) {
      bootIdentityFile.reload()
      sleepCapabilityProbe.running = true
      evidenceObserverProcess.running = true
    }
    if (!root.testMode) initialPolicyProbe.running = true
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
    function copyDiagnostics(): string { return root.copyDiagnostics() }
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
