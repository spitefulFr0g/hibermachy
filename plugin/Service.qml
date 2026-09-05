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

  readonly property var statusSnapshot: ({
    pluginActivation: "active",
    automaticPolicyEnablement: policyAccepted && policySnapshot && policySnapshot.automaticPolicyEnabled ? "enabled" : "disabled",
    automaticStagedSleepReadiness: "not-ready",
    reasonCode: policyReasonCode,
    userPolicy: policySnapshot
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
    function requestManualStagedSleep(): string { return JSON.stringify({ simulated: true, policyChanged: false }) }
  }
}
