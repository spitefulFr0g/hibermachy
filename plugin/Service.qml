import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: root

  readonly property string configHome: Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config"
  readonly property string policyDirectory: configHome + "/hibermachy"
  readonly property string policyPath: policyDirectory + "/user-policy.json"
  readonly property int maximumPolicyBytes: 16384
  property bool directoryReady: false
  property bool initialLoadComplete: false
  property bool policyAccepted: false
  property bool mutationBusy: false
  property var policySnapshot: null
  property var pendingPolicy: null
  property string lastObservedPolicyText: ""
  property bool persistenceFailureLatched: false
  property string policyReasonCode: "HBR-POLICY-LOADING"
  property var systemPolicyDraft: ({
    hibernateDelaySeconds: 7200,
    hibernateOnAcPower: false,
    scope: "machine-wide"
  })
  property var requestedSystemPolicy: null
  property var effectiveSystemPolicy: null
  property var systemPolicyProvenance: []
  property string systemPolicyReasonCode: "HBR-SYSTEM-POLICY-UNAPPLIED"
  property bool systemPolicyBusy: false
  property var systemPolicyFixture: ({
    authorization: Quickshell.env("HBR_TEST_MODE") === "1" ? "authorized" : "unavailable",
    helper: Quickshell.env("HBR_TEST_MODE") === "1" ? "accepted" : "unavailable",
    readback: Quickshell.env("HBR_TEST_MODE") === "1" ? "available" : "unavailable",
    effective: null,
    provenance: []
  })

  readonly property var statusSnapshot: ({
    pluginActivation: "active",
    automaticPolicyEnablement: policyAccepted && policySnapshot && policySnapshot.automaticPolicyEnabled ? "enabled" : "disabled",
    automaticStagedSleepReadiness: "not-ready",
    reasonCode: policyReasonCode,
    userPolicy: policySnapshot,
    systemPolicyDraft: systemPolicyDraft,
    requestedSystemPolicy: requestedSystemPolicy,
    effectiveSystemPolicy: effectiveSystemPolicy,
    systemPolicyProvenance: systemPolicyProvenance,
    systemPolicyReasonCode: systemPolicyReasonCode,
    systemPolicyReadiness: systemPolicyReasonCode === "HBR-SYSTEM-POLICY-APPLIED" ? "ready" : "not-ready"
  })

  function safeDefaults(revision) {
    return { version: 1, revision: revision, automaticPolicyEnabled: false, idleDelaySeconds: 1800 }
  }

  function ownKeys(value) { return Object.keys(value).sort().join(",") }

  function isValidIdleDelaySeconds(value) {
    return Number.isSafeInteger(value) && value >= 300 && value <= 86400
  }

  function hasDuplicateKeys(raw) {
    var matches = raw.match(/"(?:\\.|[^"\\])*"\s*:/g) || []
    var seen = ({})
    for (var index = 0; index < matches.length; index++) {
      var token = matches[index].replace(/\s*:$/, "")
      var key = JSON.parse(token)
      if (seen[key]) return true
      seen[key] = true
    }
    return false
  }

  function validateDocument(raw, bytes) {
    if (raw.length === 0) return { absent: true }
    if (bytes && bytes.byteLength > maximumPolicyBytes) return { error: "HBR-POLICY-SIZE" }
    if (bytes && bytes.byteLength >= 3) {
      var octets = new Uint8Array(bytes)
      if (octets[0] === 0xEF && octets[1] === 0xBB && octets[2] === 0xBF) return { error: "HBR-POLICY-ENCODING" }
    }
    if (raw.charCodeAt(0) === 0xFEFF || raw.indexOf("\uFFFD") !== -1) return { error: "HBR-POLICY-ENCODING" }
    try {
      if (unescape(encodeURIComponent(raw)).length > maximumPolicyBytes) return { error: "HBR-POLICY-SIZE" }
    } catch (error) { return { error: "HBR-POLICY-ENCODING" } }

    var value
    try { value = JSON.parse(raw) } catch (error) { return { error: "HBR-POLICY-MALFORMED" } }
    if (hasDuplicateKeys(raw)) return { error: "HBR-POLICY-DUPLICATE-KEY" }
    if (!value || Array.isArray(value) || typeof value !== "object") return { error: "HBR-POLICY-TYPE" }
    if (ownKeys(value) !== "automaticPolicyEnabled,idleDelaySeconds,revision,version") return { error: "HBR-POLICY-KEYS" }
    if (value.version !== 1) return { error: "HBR-POLICY-SCHEMA" }
    if (!Number.isSafeInteger(value.revision) || value.revision < 1) return { error: "HBR-POLICY-REVISION" }
    if (typeof value.automaticPolicyEnabled !== "boolean") return { error: "HBR-POLICY-AUTOMATIC" }
    if (!isValidIdleDelaySeconds(value.idleDelaySeconds)) return { error: "HBR-POLICY-IDLE-DELAY" }
    return { policy: value }
  }

  function canonical(policy) {
    return JSON.stringify({ version: 1, revision: policy.revision,
      automaticPolicyEnabled: policy.automaticPolicyEnabled, idleDelaySeconds: policy.idleDelaySeconds }, null, 2) + "\n"
  }

  function reject(reasonCode) {
    policyAccepted = false
    policyReasonCode = reasonCode
  }

  function replacePolicy(policy) {
    persistenceFailureLatched = false
    mutationBusy = true
    pendingPolicy = policy
    policyFile.setText(canonical(policy))
    return !mutationBusy && policyAccepted && policySnapshot && policySnapshot.revision === policy.revision
  }

  function finishReplacement() {
    if (!pendingPolicy) return
    policySnapshot = pendingPolicy
    lastObservedPolicyText = canonical(pendingPolicy)
    pendingPolicy = null
    policyAccepted = true
    policyReasonCode = policySnapshot.automaticPolicyEnabled ? "HBR-POLICY-ENABLED" : "HBR-POLICY-DISABLED"
    mutationBusy = false
  }

  function failReplacement() {
    pendingPolicy = null
    mutationBusy = false
    persistenceFailureLatched = true
    reject("HBR-POLICY-PERSISTENCE")
  }

  function loadPolicy(raw, bytes) {
    lastObservedPolicyText = String(raw)
    var result = validateDocument(String(raw), bytes)
    if (result.absent) {
      if (!initialLoadComplete) {
        initialLoadComplete = true
        replacePolicy(safeDefaults(1))
      } else reject("HBR-POLICY-ABSENT")
      return
    }
    initialLoadComplete = true
    if (result.error) {
      reject(result.error)
      return
    }
    if (mutationBusy) return

    var loaded = result.policy
    if (policySnapshot) {
      if (loaded.revision !== policySnapshot.revision) {
        reject("HBR-POLICY-REVISION-CONFLICT")
        return
      }
      if (loaded.automaticPolicyEnabled !== policySnapshot.automaticPolicyEnabled || loaded.idleDelaySeconds !== policySnapshot.idleDelaySeconds) {
        var revision = nextRevision()
        if (revision === null) {
          reject("HBR-POLICY-REVISION-EXHAUSTED")
          return
        }
        replacePolicy({ version: 1, revision: revision,
          automaticPolicyEnabled: loaded.automaticPolicyEnabled, idleDelaySeconds: loaded.idleDelaySeconds })
        return
      }
    }
    if (String(raw) !== canonical(loaded)) {
      replacePolicy(loaded)
      return
    }
    policySnapshot = loaded
    policyAccepted = true
    policyReasonCode = loaded.automaticPolicyEnabled ? "HBR-POLICY-ENABLED" : "HBR-POLICY-DISABLED"
  }

  function currentReceipt(accepted, reasonCode) {
    return JSON.stringify({ accepted: accepted, reasonCode: reasonCode, policy: policySnapshot })
  }

  function nextRevision() {
    if (!policySnapshot || !Number.isSafeInteger(policySnapshot.revision)) return 1
    return policySnapshot.revision < Number.MAX_SAFE_INTEGER ? policySnapshot.revision + 1 : null
  }

  function saveUserPolicy(requestJson) {
    if (mutationBusy || !policyAccepted || !policySnapshot) return currentReceipt(false, "HBR-POLICY-UNAVAILABLE")
    var request
    try { request = JSON.parse(String(requestJson)) } catch (error) { return currentReceipt(false, "HBR-POLICY-MUTATION-MALFORMED") }
    if (!request || Array.isArray(request) || typeof request !== "object" || ownKeys(request) !== "automaticPolicyEnabled,baseRevision,idleDelaySeconds")
      return currentReceipt(false, "HBR-POLICY-MUTATION-INVALID")
    if (!Number.isSafeInteger(request.baseRevision) || request.baseRevision !== policySnapshot.revision)
      return currentReceipt(false, "HBR-POLICY-STALE")
    if (typeof request.automaticPolicyEnabled !== "boolean" || !isValidIdleDelaySeconds(request.idleDelaySeconds))
      return currentReceipt(false, "HBR-POLICY-MUTATION-INVALID")
    var revision = nextRevision()
    if (revision === null) return currentReceipt(false, "HBR-POLICY-REVISION-EXHAUSTED")
    var saved = replacePolicy({ version: 1, revision: revision,
      automaticPolicyEnabled: request.automaticPolicyEnabled, idleDelaySeconds: request.idleDelaySeconds })
    return currentReceipt(saved, saved ? "HBR-POLICY-SAVED" : "HBR-POLICY-PERSISTENCE")
  }

  function resetUserPolicy() {
    if (mutationBusy) return currentReceipt(false, "HBR-POLICY-UNAVAILABLE")
    var revision = nextRevision()
    if (revision === null) return currentReceipt(false, "HBR-POLICY-REVISION-EXHAUSTED")
    var reset = replacePolicy(safeDefaults(revision))
    return currentReceipt(reset, reset ? "HBR-POLICY-RESET" : "HBR-POLICY-PERSISTENCE")
  }

  function status(): string { return JSON.stringify(statusSnapshot) }
  function userPolicy(): string { return JSON.stringify(policySnapshot || {}) }

  function systemPolicyReceipt(accepted, reasonCode, extra) {
    var receipt = { accepted: accepted, reasonCode: reasonCode,
      requestedSystemPolicy: requestedSystemPolicy, effectiveSystemPolicy: effectiveSystemPolicy,
      systemPolicyProvenance: systemPolicyProvenance }
    if (extra) for (var key in extra) receipt[key] = extra[key]
    return JSON.stringify(receipt)
  }

  function validSystemPolicy(policy) {
    return policy && Number.isSafeInteger(policy.hibernateDelaySeconds)
      && policy.hibernateDelaySeconds >= 900 && policy.hibernateDelaySeconds <= 604800
      && typeof policy.hibernateOnAcPower === "boolean"
  }

  function editSystemPolicyDraft(delaySeconds, onAcPower) {
    var next = { hibernateDelaySeconds: delaySeconds, hibernateOnAcPower: onAcPower,
      scope: "machine-wide" }
    if (!validSystemPolicy(next)) return systemPolicyReceipt(false, "HBR-SYSTEM-POLICY-INVALID-DRAFT")
    systemPolicyDraft = next
    return systemPolicyReceipt(true, "HBR-SYSTEM-POLICY-DRAFT-UPDATED")
  }

  function reviewSystemPolicy() {
    if (!validSystemPolicy(systemPolicyDraft)) return systemPolicyReceipt(false, "HBR-SYSTEM-POLICY-INVALID-DRAFT")
    return systemPolicyReceipt(true, "HBR-SYSTEM-POLICY-REVIEW", { pair: systemPolicyDraft,
      review: "The authenticated mutation will replace both machine-wide values together." })
  }

  function applySystemPolicy() {
    if (systemPolicyBusy) return systemPolicyReceipt(false, "HBR-SYSTEM-POLICY-BUSY")
    if (!validSystemPolicy(systemPolicyDraft)) return systemPolicyReceipt(false, "HBR-SYSTEM-POLICY-INVALID-DRAFT")
    systemPolicyBusy = true
    var fixture = systemPolicyFixture || {}
    var authorization = fixture.authorization || "authorized"
    if (authorization === "unavailable") {
      systemPolicyBusy = false
      systemPolicyReasonCode = "HBR-SYSTEM-POLICY-UNAVAILABLE"
      return systemPolicyReceipt(false, "HBR-SYSTEM-POLICY-UNAVAILABLE")
    }
    if (authorization === "cancelled") {
      systemPolicyBusy = false
      systemPolicyReasonCode = "HBR-SYSTEM-POLICY-AUTH-CANCELLED"
      return systemPolicyReceipt(false, "HBR-SYSTEM-POLICY-AUTH-CANCELLED")
    }
    if (authorization === "denied") {
      systemPolicyBusy = false
      systemPolicyReasonCode = "HBR-SYSTEM-POLICY-AUTH-DENIED"
      return systemPolicyReceipt(false, "HBR-SYSTEM-POLICY-AUTH-DENIED")
    }
    if (fixture.helper && fixture.helper !== "accepted") {
      systemPolicyBusy = false
      systemPolicyReasonCode = "HBR-SYSTEM-POLICY-HELPER-REJECTED"
      return systemPolicyReceipt(false, "HBR-SYSTEM-POLICY-HELPER-REJECTED")
    }
    if (fixture.write === "failed") {
      systemPolicyBusy = false
      systemPolicyReasonCode = "HBR-SYSTEM-POLICY-WRITE-FAILED"
      return systemPolicyReceipt(false, "HBR-SYSTEM-POLICY-WRITE-FAILED")
    }
    if (fixture.readback === "unavailable") {
      systemPolicyBusy = false
      systemPolicyReasonCode = "HBR-SYSTEM-POLICY-READBACK-INDETERMINATE"
      return systemPolicyReceipt(false, "HBR-SYSTEM-POLICY-READBACK-INDETERMINATE")
    }
    var requested = { hibernateDelaySeconds: systemPolicyDraft.hibernateDelaySeconds,
      hibernateOnAcPower: systemPolicyDraft.hibernateOnAcPower, scope: "machine-wide" }
    var readback = fixture.readbackPolicy || requested
    if (fixture.readback === "contradictory")
      readback = { hibernateDelaySeconds: requested.hibernateDelaySeconds + 1,
        hibernateOnAcPower: requested.hibernateOnAcPower }
    if (readback.hibernateDelaySeconds !== requested.hibernateDelaySeconds
      || readback.hibernateOnAcPower !== requested.hibernateOnAcPower) {
      systemPolicyBusy = false
      systemPolicyReasonCode = "HBR-SYSTEM-POLICY-READBACK-CONTRADICTORY"
      return systemPolicyReceipt(false, "HBR-SYSTEM-POLICY-READBACK-CONTRADICTORY")
    }
    requestedSystemPolicy = requested
    effectiveSystemPolicy = fixture.effective || requested
    systemPolicyProvenance = fixture.provenance || []
    systemPolicyReasonCode = effectiveSystemPolicy.hibernateDelaySeconds === requested.hibernateDelaySeconds
      && effectiveSystemPolicy.hibernateOnAcPower === requested.hibernateOnAcPower
      ? "HBR-SYSTEM-POLICY-APPLIED" : "HBR-SYSTEM-POLICY-DIFFERS"
    systemPolicyBusy = false
    return systemPolicyReceipt(true, systemPolicyReasonCode, { pair: requested })
  }

  function resetSystemPolicy() {
    if (systemPolicyBusy) return systemPolicyReceipt(false, "HBR-SYSTEM-POLICY-BUSY")
    var fixture = systemPolicyFixture || {}
    systemPolicyBusy = true
    if (fixture.authorization === "unavailable") {
      systemPolicyBusy = false
      return systemPolicyReceipt(false, "HBR-SYSTEM-POLICY-UNAVAILABLE")
    }
    if (fixture.authorization === "cancelled") {
      systemPolicyBusy = false
      return systemPolicyReceipt(false, "HBR-SYSTEM-POLICY-AUTH-CANCELLED")
    }
    if (fixture.authorization === "denied") {
      systemPolicyBusy = false
      return systemPolicyReceipt(false, "HBR-SYSTEM-POLICY-AUTH-DENIED")
    }
    if (fixture.helper && fixture.helper !== "accepted") {
      systemPolicyBusy = false
      return systemPolicyReceipt(false, "HBR-SYSTEM-POLICY-HELPER-REJECTED")
    }
    if (fixture.write === "failed") {
      systemPolicyBusy = false
      return systemPolicyReceipt(false, "HBR-SYSTEM-POLICY-WRITE-FAILED")
    }
    if (fixture.readback === "unavailable") {
      systemPolicyBusy = false
      return systemPolicyReceipt(false, "HBR-SYSTEM-POLICY-READBACK-INDETERMINATE")
    }
    requestedSystemPolicy = null
    effectiveSystemPolicy = null
    systemPolicyProvenance = []
    systemPolicyReasonCode = "HBR-SYSTEM-POLICY-RESET"
    systemPolicyBusy = false
    return systemPolicyReceipt(true, "HBR-SYSTEM-POLICY-RESET")
  }

  function setSystemPolicyFixture(fixtureJson) {
    if (Quickshell.env("HBR_TEST_MODE") !== "1") return systemPolicyReceipt(false, "HBR-SYSTEM-POLICY-UNAVAILABLE")
    try { systemPolicyFixture = JSON.parse(String(fixtureJson)) }
    catch (error) { return systemPolicyReceipt(false, "HBR-SYSTEM-POLICY-FIXTURE-MALFORMED") }
    return systemPolicyReceipt(true, "HBR-SYSTEM-POLICY-FIXTURE-SET")
  }

  Process {
    id: ensurePolicyDirectory
    command: ["mkdir", "-p", root.policyDirectory]
    onExited: function(exitCode) {
      if (exitCode !== 0) {
        root.initialLoadComplete = true
        root.reject("HBR-POLICY-PERSISTENCE")
        return
      }
      root.directoryReady = true
      policyFile.reload()
    }
  }

  FileView {
    id: policyFile
    path: root.policyPath
    blockWrites: true
    watchChanges: true
    atomicWrites: true
    printErrors: false
    onLoaded: root.loadPolicy(text(), data())
    onLoadFailed: function() { if (root.directoryReady && !root.initialLoadComplete) root.loadPolicy("") }
    onSaved: root.finishReplacement()
    onSaveFailed: function() { root.failReplacement() }
    onFileChanged: reload()
  }

  Timer {
    interval: 100
    repeat: true
    running: root.directoryReady
    onTriggered: {
      if (root.mutationBusy || root.persistenceFailureLatched) return
      var raw = policyFile.text()
      if (raw !== root.lastObservedPolicyText) root.loadPolicy(raw, policyFile.data())
    }
  }

  Component.onCompleted: ensurePolicyDirectory.running = true

  IpcHandler {
    target: "dev.hibermachy"
    function status(): string { return root.status() }
    function userPolicy(): string { return root.userPolicy() }
    function saveUserPolicy(requestJson: string): string { return root.saveUserPolicy(requestJson) }
    function resetUserPolicy(): string { return root.resetUserPolicy() }
    function systemPolicy(): string { return JSON.stringify(root.statusSnapshot) }
    function editSystemPolicyDraft(delaySeconds: int, onAcPower: bool): string { return root.editSystemPolicyDraft(delaySeconds, onAcPower) }
    function reviewSystemPolicy(): string { return root.reviewSystemPolicy() }
    function applySystemPolicy(): string { return root.applySystemPolicy() }
    function resetSystemPolicy(): string { return root.resetSystemPolicy() }
    function setSystemPolicyFixture(fixtureJson: string): string { return root.setSystemPolicyFixture(fixtureJson) }
    function requestManualStagedSleep(): string { return JSON.stringify({ simulated: true, policyChanged: false }) }
  }
}
