import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "dev.hibermachy"
  ipcTarget: "dev.hibermachy"
  manageIpc: false

  property var service: null
  property var anchorItem: null
  readonly property var statusSnapshot: service ? service.statusSnapshot : null
  property bool draftAutomaticPolicyEnabled: false
  property int draftIdleDelaySeconds: 1800
  property int draftBaseRevision: 0
  property bool draftDirty: false
  property int draftHibernateDelaySeconds: 7200
  property bool draftHibernateOnAcPower: false
  property bool systemDraftDirty: false
  property string confirmationKind: ""
  property string confirmationMessage: ""
  property string actionResult: ""
  readonly property bool testMode: Quickshell.env("HBR_TEST_MODE") === "1"
  property bool clipboardPending: false
  property bool clipboardTimedOut: false
  property string clipboardPayload: ""
  property string testCopiedDiagnostics: ""
  property Item focusBeforeConfirmation: null
  property int focusBeforeIndex: -1
  property int lastRestoredFocusIndex: -1
  property int focusIndex: 0
  property var focusTargets: []

  function open(payloadJson) {
    refresh()
    controller.show()
    var payload = null
    try { payload = JSON.parse(payloadJson || "{}") } catch (_) {}
    if (payload && payload.action === "confirm-staged-sleep") beginManualConfirmation()
  }
  function refresh() {
    if (!service || !service.policySnapshot) return
    if (!draftDirty) {
      draftAutomaticPolicyEnabled = service.policySnapshot.automaticPolicyEnabled
      draftIdleDelaySeconds = service.policySnapshot.idleDelaySeconds
      draftBaseRevision = service.policySnapshot.revision
    }
    if (!systemDraftDirty) {
      draftHibernateDelaySeconds = service.systemPolicyDraft.hibernateDelaySeconds
      draftHibernateOnAcPower = service.systemPolicyDraft.hibernateOnAcPower
    }
  }
  function editAutomaticPolicyEnabled(enabled) { draftAutomaticPolicyEnabled = enabled; draftDirty = true }
  function editIdleDelaySeconds(seconds) { draftIdleDelaySeconds = seconds; draftDirty = true }
  function editSystemPolicy(delaySeconds, onAcPower) {
    draftHibernateDelaySeconds = delaySeconds
    draftHibernateOnAcPower = onAcPower
    systemDraftDirty = true
  }
  function chooseIdlePreset(seconds) { editIdleDelaySeconds(seconds) }
  function chooseHibernatePreset(seconds) { editSystemPolicy(seconds, draftHibernateOnAcPower) }
  function formatDuration(seconds) {
    if (seconds % 3600 === 0) return (seconds / 3600) + " hour" + (seconds === 3600 ? "" : "s")
    if (seconds % 60 === 0) return (seconds / 60) + " minute" + (seconds === 60 ? "" : "s")
    return seconds + " seconds"
  }
  function policyText(policy) {
    if (!policy) return "not set"
    return formatDuration(policy.hibernateDelaySeconds) + ", plugged in " + (policy.hibernateOnAcPower ? "yes" : "no")
  }
  function systemPolicyMutationMessage(reasonCode) {
    if (reasonCode === "HBR-SYSTEM-POLICY-AUTH-CANCELLED") return "Cancelled. No system policy was changed."
    if (reasonCode === "HBR-SYSTEM-POLICY-UNAVAILABLE") return "Authentication is unavailable. No system policy was changed."
    if (reasonCode === "HBR-SYSTEM-POLICY-SUBMITTED") return "Request submitted for authentication."
    if (reasonCode === "HBR-SYSTEM-POLICY-READBACK-PENDING") return "Request accepted. Verifying the current policy."
    if (reasonCode === "HBR-SYSTEM-POLICY-APPLIED") return "Policy applied."
    if (reasonCode === "HBR-SYSTEM-POLICY-DIFFERS") return "Policy applied, but an administrator policy takes precedence."
    if (reasonCode === "HBR-SYSTEM-POLICY-RESET") return "Requested policy reset."
    if (reasonCode === "HBR-SYSTEM-POLICY-WRITE-FAILED") return "Request failed. No policy change was confirmed."
    if (reasonCode === "HBR-SYSTEM-POLICY-READBACK-INDETERMINATE") return "The request could not be verified."
    return "No request has been made."
  }
  function saveDraft() {
    if (!service) return
    var receipt = JSON.parse(service.saveUserPolicy(JSON.stringify({ baseRevision: draftBaseRevision,
      automaticPolicyEnabled: draftAutomaticPolicyEnabled, idleDelaySeconds: draftIdleDelaySeconds })))
    actionResult = receipt.reasonCode
    if (receipt.accepted) draftBaseRevision += 1
    draftDirty = !receipt.accepted
  }
  function ask(kind, message) {
    var activeIndex = focusTargets.findIndex(function(target) { return target && target.activeFocus })
    focusBeforeIndex = activeIndex >= 0 ? activeIndex : focusIndex
    focusBeforeConfirmation = activeIndex >= 0 ? focusTargets[activeIndex] : keyCatcher
    confirmationKind = kind
    confirmationMessage = message + " Press Escape or choose Cancel to leave it unchanged."
  }
  function restoreFocus() {
    var target = focusBeforeConfirmation || keyCatcher
    if (focusBeforeIndex >= 0) focusIndex = focusBeforeIndex
    lastRestoredFocusIndex = focusIndex
    focusBeforeConfirmation = null
    focusBeforeIndex = -1
    Qt.callLater(function() { if (target) target.forceActiveFocus() })
  }

  function accessibilityJourney(): string {
    if (!focusTargets.length) return JSON.stringify({ accepted: false, reasonCode: "HBR-PANEL-FOCUS-UNAVAILABLE" })
    var start = focusIndex
    moveFocus(1)
    var forward = focusIndex !== start
    moveFocus(-1)
    var reverse = focusIndex === start
    ask("reset-history", "Test cancellation: retained history remains unchanged.")
    var confirmationOpened = confirmationKind === "reset-history"
    var confirmationControls = confirmation.cancelAccessibleName === "Cancel"
      && confirmation.confirmAccessibleName === "Confirm"
    moveConfirmationSelection(-1)
    activateConfirmationSelection()
    var accessibleNames = [automaticToggle.Accessible.name, saveButton.Accessible.name,
      applyButton.Accessible.name, manualButton.Accessible.name].every(function(name) { return String(name).length > 0 })
    var wasDirty = draftDirty
    editIdleDelaySeconds(draftIdleDelaySeconds)
    var dirtyState = draftDirty
    draftDirty = wasDirty
    var authStart = focusIndex
    service.setSystemPolicyFixture('{"authorization":"cancelled"}')
    service.editSystemPolicyDraft(draftHibernateDelaySeconds, draftHibernateOnAcPower)
    ask("apply", "Test authentication cancellation leaves requested policy unchanged.")
    confirmAction()
    var authenticationCancellation = false
    try { authenticationCancellation = JSON.parse(actionResult).reasonCode === "HBR-SYSTEM-POLICY-AUTH-CANCELLED" }
    catch (error) { authenticationCancellation = false }
    service.setSystemPolicyFixture('{"authorization":"authorized"}')
    return JSON.stringify({ accepted: true, forward: forward, reverse: reverse,
      confirmationOpened: confirmationOpened, cancellationClosed: confirmationKind === "",
      confirmationControls: confirmationControls,
      focusRestored: lastRestoredFocusIndex === start, accessibleNames: accessibleNames,
      dirtyState: dirtyState, disabledState: !saveButton.enabled,
      statusAnnouncement: !!(statusSnapshot && statusSnapshot.statusAnnouncement),
      nonColorStatus: statusSummary.indexOf("Automatic staged sleep:") >= 0,
      authenticationCancellation: authenticationCancellation,
      authenticationFocusRestored: lastRestoredFocusIndex === authStart,
      scaledLayout: Style.space(32),
      contrastRoles: Color.foreground !== Color.background && Color.foreground !== Color.muted })
  }
  function cancelConfirmation() {
    confirmationKind = ""
    restoreFocus()
  }
  function confirmAction() {
    var kind = confirmationKind
    confirmationKind = ""
    if (!service) return
    if (kind === "manual") actionResult = service.requestStagedSleep()
    else if (kind === "apply") actionResult = service.applySystemPolicy()
    else if (kind === "reset-system") actionResult = service.resetSystemPolicy()
    else if (kind === "reset-policy") actionResult = service.resetUserPolicy()
    else if (kind === "reset-history") actionResult = service.resetHistory()
    else if (kind === "diagnostics") copyDiagnosticsToClipboard()
    if (kind === "reset-policy") draftDirty = false
    if (kind === "reset-system") systemDraftDirty = false
    restoreFocus()
  }
  function copyDiagnosticsToClipboard() {
    if (!service || clipboardPending || clipboardProcess.running) return
    clipboardPayload = service.copyDiagnostics()
    testCopiedDiagnostics = ""
    clipboardTimedOut = false
    clipboardPending = true
    actionResult = "Copying diagnostics…"
    clipboardProcess.stdinEnabled = true
    clipboardProcess.running = true
  }

  Process {
    id: clipboardProcess
    command: root.testMode ? ["/usr/bin/cat"] : ["/usr/bin/wl-copy", "--type", "text/plain;charset=utf-8"]
    stdout: StdioCollector { id: clipboardOutput; waitForEnd: true }
    onStarted: {
      write(root.clipboardPayload)
      root.clipboardPayload = ""
      stdinEnabled = false
    }
    onExited: function(exitCode, exitStatus) {
      root.clipboardPending = false
      root.clipboardPayload = ""
      if (exitCode === 0 && exitStatus === 0 && !root.clipboardTimedOut) {
        if (root.testMode) root.testCopiedDiagnostics = clipboardOutput.text
        root.actionResult = root.testMode ? "Diagnostics copy verified (test)." : "Diagnostics copied."
      } else root.actionResult = "Could not copy diagnostics."
    }
  }

  Timer {
    interval: 10000
    running: root.clipboardPending
    onTriggered: {
      root.clipboardTimedOut = true
      root.clipboardPayload = ""
      root.actionResult = "Could not copy diagnostics."
      // Keep retries disabled until a started process has actually exited.
      if (clipboardProcess.running) clipboardProcess.running = false
      else root.clipboardPending = false
    }
  }

  function moveConfirmationSelection(delta) {
    if (confirmationKind !== "") confirmation.moveSelection(delta)
  }
  function activateConfirmationSelection() {
    if (confirmationKind !== "") confirmation.activateSelected()
  }
  function beginManualConfirmation() {
    if (!statusSnapshot || statusSnapshot.manualStagedSleepReadiness !== "ready") return
    ask("manual", statusSnapshot.manualConfirmationMessage)
  }
  function reviewAndConfirmSystemPolicy() {
    if (!service) return
    var draft = JSON.parse(service.editSystemPolicyDraft(draftHibernateDelaySeconds, draftHibernateOnAcPower))
    if (!draft.accepted) { actionResult = draft.reasonCode; return }
    var review = JSON.parse(service.reviewSystemPolicy())
    if (!review.accepted) { actionResult = review.reasonCode; return }
    ask("apply", "Apply the machine-wide system policy: hibernate after " + formatDuration(draftHibernateDelaySeconds)
      + ", hibernate while plugged in " + (draftHibernateOnAcPower ? "enabled" : "disabled") + ".")
  }
  function moveFocus(delta) {
    if (confirmationKind !== "" || !focusTargets.length) return
    focusIndex = (focusIndex + delta + focusTargets.length) % focusTargets.length
    focusTargets[focusIndex].forceActiveFocus()
  }
  onStatusSnapshotChanged: refresh()

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root
    bar: root.bar
    open: root.opened
    contentWidth: fittedContentWidth(Style.space(440))
    contentHeight: fittedContentHeight(content.implicitHeight, Style.space(640))
    focusTarget: keyCatcher

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onMoveRequested: function(dx, dy) {
        if (root.confirmationKind !== "") root.moveConfirmationSelection(dy !== 0 ? dy : dx)
        else if (dy !== 0) root.moveFocus(dy)
        if (dx !== 0) flickable.contentX = Math.max(0, flickable.contentX + dx * Style.space(24))
      }
      onTabRequested: function(direction) {
        if (root.confirmationKind !== "") root.moveConfirmationSelection(direction)
        else root.moveFocus(direction)
      }
      onActivateRequested: {
        if (root.confirmationKind !== "") {
          root.activateConfirmationSelection()
        } else if (root.focusTargets[root.focusIndex]) {
          var target = root.focusTargets[root.focusIndex]
          if (typeof target.clicked === "function") target.clicked()
          else target.forceActiveFocus()
        }
      }
      onCloseRequested: root.confirmationKind !== "" ? root.cancelConfirmation() : root.close()
    }

    Flickable {
      id: flickable
      anchors.fill: parent
      anchors.margins: panel.padding
      clip: true
      contentWidth: width
      contentHeight: content.implicitHeight
      boundsBehavior: Flickable.StopAtBounds
      flickableDirection: Flickable.VerticalFlick
      interactive: contentHeight > height

      Column {
        id: content
        width: flickable.width
        spacing: Style.space(14)

        PanelHero {
          width: parent.width
          title: "Sleep & Hibernation"
          meta: root.heroStatus
          detail: root.statusSnapshot ? root.statusSnapshot.pluginActivation : "unavailable"
          Accessible.name: "Hibermachy operational readiness"
        }
        Text {
          width: parent.width
          textFormat: Text.PlainText
          text: root.heroExplanation
          color: Color.foreground
          font.family: Style.font.family
          font.pixelSize: Style.font.body
          wrapMode: Text.WordWrap
          Accessible.name: text
        }
        PanelSeparator { width: parent.width }
        PanelSectionHeader { text: "Automatic staged sleep" }

        Toggle {
          id: automaticToggle
          width: parent.width
          label: "Enable automatic staged sleep"
          description: "User intent is saved separately from plugin activation."
          checked: root.draftAutomaticPolicyEnabled
          onClicked: root.editAutomaticPolicyEnabled(!root.draftAutomaticPolicyEnabled)
          Accessible.name: label
          Accessible.checked: checked
        }
        Text {
          width: parent.width
          textFormat: Text.PlainText
          text: "Idle delay: " + root.formatDuration(root.draftIdleDelaySeconds) + (root.draftDirty ? " (unsaved draft)" : "")
          color: Color.foreground
          font.family: Style.font.family
          font.pixelSize: Style.font.body
          wrapMode: Text.WordWrap
        }
        Row {
          width: parent.width
          spacing: Style.space(8)
          Button { id: idleFive; text: "5 min"; focusable: true; bordered: true; onClicked: root.chooseIdlePreset(300); Accessible.name: "Set idle delay to 5 minutes" }
          Button { id: idleThirty; text: "30 min"; focusable: true; bordered: true; onClicked: root.chooseIdlePreset(1800); Accessible.name: "Set idle delay to 30 minutes" }
          Button { id: idleHour; text: "1 hour"; focusable: true; bordered: true; onClicked: root.chooseIdlePreset(3600); Accessible.name: "Set idle delay to 1 hour" }
        }
        NumberField {
          id: idleNumber
          width: parent.width
          label: "Idle delay (exact whole seconds)"
          value: root.draftIdleDelaySeconds
          from: 300
          to: 86400
          stepSize: 1
          onModified: function(value) { root.editIdleDelaySeconds(value) }
          Accessible.name: "Idle delay in whole seconds"
        }
        Button {
          id: saveButton
          text: "Save automatic policy"
          bordered: true
          focusable: true
          enabled: root.draftDirty
          onClicked: root.saveDraft()
          Accessible.name: "Save automatic staged sleep policy"
          Accessible.description: enabled ? "Enabled" : "Disabled"
        }

        PanelSeparator { width: parent.width }
        PanelSectionHeader { text: "System policy" }
        Text {
          width: parent.width
          textFormat: Text.PlainText
          text: "Machine-wide hibernate delay and AC behavior affect every user and caller. Changes remain a draft until authenticated Apply."
          color: Color.foreground
          font.family: Style.font.family
          font.pixelSize: Style.font.body
          wrapMode: Text.WordWrap
        }
        Row {
          width: parent.width
          spacing: Style.space(8)
          Button { id: hibernateFifteen; text: "15 min"; focusable: true; bordered: true; onClicked: root.chooseHibernatePreset(900); Accessible.name: "Set hibernate delay to 15 minutes" }
          Button { id: hibernateHour; text: "1 hour"; focusable: true; bordered: true; onClicked: root.chooseHibernatePreset(3600); Accessible.name: "Set hibernate delay to 1 hour" }
          Button { id: hibernateTwoHours; text: "2 hours"; focusable: true; bordered: true; onClicked: root.chooseHibernatePreset(7200); Accessible.name: "Set hibernate delay to 2 hours" }
        }
        NumberField {
          id: hibernateNumber
          width: parent.width
          label: "Hibernate delay (exact whole seconds)"
          value: root.draftHibernateDelaySeconds
          from: 900
          to: 604800
          stepSize: 1
          onModified: function(value) { root.editSystemPolicy(value, root.draftHibernateOnAcPower) }
          Accessible.name: "Machine-wide hibernate delay in whole seconds"
        }
        Toggle {
          id: acToggle
          width: parent.width
          label: "Hibernate while plugged in"
          description: "System-wide draft; disabled by default."
          checked: root.draftHibernateOnAcPower
          onClicked: root.editSystemPolicy(root.draftHibernateDelaySeconds, !root.draftHibernateOnAcPower)
          Accessible.name: label
          Accessible.checked: checked
        }
        Button {
          id: applyButton
          text: "Review and apply system policy"
          bordered: true
          focusable: true
          enabled: root.systemDraftDirty && root.statusSnapshot && root.statusSnapshot.systemPolicyReadinessReasonCode === "HBR-CONTRACT-READY"
          onClicked: root.reviewAndConfirmSystemPolicy()
          Accessible.name: "Review and apply machine-wide system policy"
          Accessible.description: enabled ? "Enabled" : "Disabled"
        }
        Button {
          id: resetSystemButton
          text: "Reset requested system policy"
          bordered: true
          focusable: true
          enabled: root.statusSnapshot && root.statusSnapshot.requestedSystemPolicy !== null
          onClicked: root.ask("reset-system", "Reset only Hibermachy's requested system policy; user policy and plugin activation remain unchanged.")
          Accessible.name: "Reset requested system policy"
          Accessible.description: enabled ? "Enabled" : "Disabled"
        }

        PanelSeparator { width: parent.width }
        PanelSectionHeader { text: "Current status" }
        Text {
          width: parent.width
          textFormat: Text.PlainText
          text: root.statusSummary
          color: Color.foreground
          font.family: Style.font.family
          font.pixelSize: Style.font.body
          wrapMode: Text.WordWrap
          Accessible.name: "Current operational status: " + text
          onTextChanged: function(value) { if (visible && Accessible.announce) Accessible.announce(value, Accessible.Polite) }
        }
        Text {
          width: parent.width
          textFormat: Text.PlainText
          text: root.statusSnapshot ? "Requested: " + root.policyText(root.statusSnapshot.requestedSystemPolicy)
            + "\nEffective: " + root.policyText(root.statusSnapshot.effectiveSystemPolicy)
            + "\nProvenance: " + (root.statusSnapshot.systemPolicyProvenance || []).join(", ")
            + "\nLatest system policy request result: " + root.systemPolicyMutationMessage(root.statusSnapshot.lastSystemPolicyMutationResult) : "Status unavailable."
          color: Color.foreground
          font.family: Style.font.family
          font.pixelSize: Style.font.bodySmall
          wrapMode: Text.WordWrap
          Accessible.name: "Requested and effective system policy and latest request result"
        }
        PanelSeparator { width: parent.width }
        PanelSectionHeader { text: "Manual action" }
        Button {
          id: manualButton
          text: root.manualActionText
          bordered: true
          focusable: true
          enabled: root.statusSnapshot && root.statusSnapshot.manualStagedSleepReadiness === "ready"
          onClicked: root.beginManualConfirmation()
          Accessible.name: manualActionText
          Accessible.description: enabled ? "Enabled" : "Disabled"
        }
        Text {
          width: parent.width
          visible: root.actionResult !== ""
          textFormat: Text.PlainText
          text: root.actionResult
          color: Color.foreground
          font.family: Style.font.family
          font.pixelSize: Style.font.bodySmall
          wrapMode: Text.WordWrap
          onTextChanged: function(value) { if (visible && Accessible.announce) Accessible.announce(value, Accessible.Polite) }
          Accessible.name: "Latest action result: " + text
        }
        Button {
          id: resetPolicyButton
          text: "Reset invalid user policy"
          bordered: true
          focusable: true
          enabled: root.statusSnapshot && root.statusSnapshot.reasonCode.indexOf("HBR-POLICY-") === 0
          onClicked: root.ask("reset-policy", "Reset invalid user policy to disabled automatic staged sleep and a 30 minute idle delay.")
          Accessible.name: "Reset invalid user policy"
          Accessible.description: enabled ? "Enabled" : "Disabled"
        }
        Button {
          id: resetHistoryButton
          text: "Reset outcome history"
          bordered: true
          focusable: true
          enabled: root.statusSnapshot && root.statusSnapshot.outcomeHistoryCount > 0
          onClicked: root.ask("reset-history", "Delete retained outcome history. This does not change live readiness or policy.")
          Accessible.name: "Reset retained outcome history"
          Accessible.description: enabled ? "Enabled" : "Disabled"
        }
        Button {
          id: diagnosticsButton
          text: "Copy sanitized diagnostics"
          bordered: true
          focusable: true
          enabled: root.statusSnapshot && root.statusSnapshot.diagnosticsReadiness !== "not-ready" && !root.clipboardPending && !clipboardProcess.running
          onClicked: root.ask("diagnostics", "Copy sanitized diagnostics to the clipboard. No data is transmitted.")
          Accessible.name: "Copy sanitized diagnostics"
          Accessible.description: enabled ? "Enabled; excludes private data and unrestricted logs" : "Disabled"
        }
      }
    }

    AccessibleConfirmDialog {
      id: confirmation
      anchors.fill: parent
      opened: root.confirmationKind !== ""
      message: root.confirmationMessage
      z: 10
      onCanceled: root.cancelConfirmation()
      onConfirmed: root.confirmAction()
    }
  }

  readonly property string heroStatus: {
    return statusSnapshot ? statusSnapshot.heroStatus : "Status unavailable"
  }
  readonly property string heroExplanation: statusSnapshot ? statusSnapshot.heroExplanation
    + " Automatic: " + statusSnapshot.automaticStagedSleepReadiness + " · Manual: " + statusSnapshot.manualStagedSleepReadiness
    + " · System policy: " + statusSnapshot.systemPolicyReadiness + " · Diagnostics: " + statusSnapshot.diagnosticsReadiness
    : "No readiness snapshot is available."
  readonly property string statusSummary: statusSnapshot ? "Automatic staged sleep: " + statusSnapshot.automaticStagedSleepReadiness
    + " (" + statusSnapshot.automaticBlockerReasonCode + ")\nManual staged sleep: " + statusSnapshot.manualStagedSleepReadiness
    + " — " + statusSnapshot.sleepExecutabilitySummary
    + "\nStay Awake: " + statusSnapshot.stayAwake + "; re-arm: " + (statusSnapshot.rearmRequired ? "required" : "armed")
    + "\nActive blocker: " + (statusSnapshot.activeBlocker === "none" ? "none (automation paused)" : statusSnapshot.activeBlocker) : "Status unavailable."
  readonly property string manualActionText: statusSnapshot && statusSnapshot.manualConfirmationKind === "suspend-fallback"
    ? "Confirm manual Suspend fallback" : "Confirm Suspend then Hibernate"

  Component.onCompleted: {
    focusTargets = [automaticToggle, idleFive, idleThirty, idleHour, idleNumber.field, saveButton,
      hibernateFifteen, hibernateHour, hibernateTwoHours, hibernateNumber.field, acToggle,
      applyButton, resetSystemButton, manualButton, resetPolicyButton, resetHistoryButton, diagnosticsButton]
    refresh()
  }

  IpcHandler {
    enabled: Quickshell.env("HBR_TEST_MODE") === "1"
    target: "dev.hibermachy.panel-test"
    function manualConfirmationState(): string {
      return JSON.stringify({ kind: root.confirmationKind, message: root.confirmationMessage })
    }
    function cancelManualConfirmation(): void { root.cancelConfirmation() }
    function accessibilityJourney(): string { return root.accessibilityJourney() }
    function startDiagnosticsCopy(): void { root.copyDiagnosticsToClipboard() }
    function diagnosticsCopyState(): string {
      return JSON.stringify({ pending: root.clipboardPending, result: root.actionResult,
        copiedText: root.testCopiedDiagnostics })
    }
  }
}
