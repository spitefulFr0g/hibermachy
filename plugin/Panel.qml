import QtQuick
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
  property Item focusBeforeConfirmation: null
  property int focusIndex: 0
  property var focusTargets: []

  function open() { refresh(); controller.show() }
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
  function saveDraft() {
    if (!service) return
    var receipt = JSON.parse(service.saveUserPolicy(JSON.stringify({ baseRevision: draftBaseRevision,
      automaticPolicyEnabled: draftAutomaticPolicyEnabled, idleDelaySeconds: draftIdleDelaySeconds })))
    actionResult = receipt.reasonCode
    if (receipt.accepted) draftBaseRevision += 1
    draftDirty = !receipt.accepted
  }
  function ask(kind, message) {
    focusBeforeConfirmation = focusTargets.length ? focusTargets[focusIndex] : keyCatcher
    confirmationKind = kind
    confirmationMessage = message + " Press Escape or choose Cancel to leave it unchanged."
  }
  function restoreFocus() {
    var target = focusBeforeConfirmation || keyCatcher
    focusBeforeConfirmation = null
    Qt.callLater(function() { if (target) target.forceActiveFocus() })
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
    if (kind === "reset-policy") draftDirty = false
    if (kind === "reset-system") systemDraftDirty = false
    restoreFocus()
  }
  function beginManualConfirmation() {
    if (!statusSnapshot || statusSnapshot.manualStagedSleepReadiness !== "ready") return
    ask("manual", statusSnapshot.manualConfirmationMessage)
  }
  function reviewAndConfirmSystemPolicy() {
    if (!service) return
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
        if (dy !== 0) root.moveFocus(dy)
        if (dx !== 0) flickable.contentX = Math.max(0, flickable.contentX + dx * Style.space(24))
      }
      onTabRequested: function(direction) { root.moveFocus(direction) }
      onActivateRequested: {
        if (root.confirmationKind !== "") {
          if (confirmation.selectedIndex === 0) root.cancelConfirmation()
          else root.confirmAction()
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
          Accessible.enabled: enabled
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
          Accessible.enabled: enabled
        }
        Button {
          id: resetSystemButton
          text: "Reset requested system policy"
          bordered: true
          focusable: true
          enabled: root.statusSnapshot && root.statusSnapshot.requestedSystemPolicy !== null
          onClicked: root.ask("reset-system", "Reset only Hibermachy's requested system policy; user policy and plugin activation remain unchanged.")
          Accessible.name: "Reset requested system policy"
          Accessible.enabled: enabled
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
          Accessible.liveRegion: Accessible.Polite
        }
        Text {
          width: parent.width
          textFormat: Text.PlainText
          text: root.statusSnapshot ? "Requested: " + root.policyText(root.statusSnapshot.requestedSystemPolicy)
            + "\nEffective: " + root.policyText(root.statusSnapshot.effectiveSystemPolicy)
            + "\nProvenance: " + (root.statusSnapshot.systemPolicyProvenance || []).join(", ") : "Status unavailable."
          color: Color.foreground
          font.family: Style.font.family
          font.pixelSize: Style.font.bodySmall
          wrapMode: Text.WordWrap
          Accessible.name: "Requested and effective system policy"
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
          Accessible.enabled: enabled
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
          Accessible.liveRegion: Accessible.Polite
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
          Accessible.enabled: enabled
        }
        Button {
          id: resetHistoryButton
          text: "Reset outcome history"
          bordered: true
          focusable: true
          enabled: root.statusSnapshot && root.statusSnapshot.outcomeHistoryCount > 0
          onClicked: root.ask("reset-history", "Delete retained outcome history. This does not change live readiness or policy.")
          Accessible.name: "Reset retained outcome history"
          Accessible.enabled: enabled
        }
      }
    }

    ConfirmDialog {
      id: confirmation
      anchors.fill: parent
      opened: root.confirmationKind !== ""
      message: root.confirmationMessage
      cancelText: "Cancel"
      confirmText: "Confirm"
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
    + " — " + (statusSnapshot.sleepExecutability.stagedSleepExecutable ? "staged sleep executable" : (statusSnapshot.fallbackAvailable ? "suspend fallback available" : "no suspend fallback"))
    + "\nStay Awake: " + statusSnapshot.stayAwake + "; re-arm: " + (statusSnapshot.rearmRequired ? "required" : "armed")
    + "\nActive blocker: " + (statusSnapshot.activeBlocker === "none" ? "none (automation paused)" : statusSnapshot.activeBlocker) : "Status unavailable."
  readonly property string manualActionText: statusSnapshot && statusSnapshot.manualConfirmationKind === "suspend-fallback"
    ? "Confirm manual Suspend fallback" : "Confirm Suspend then Hibernate"

  Component.onCompleted: {
    focusTargets = [automaticToggle, idleFive, idleThirty, idleHour, idleNumber.field, saveButton,
      hibernateFifteen, hibernateHour, hibernateTwoHours, hibernateNumber.field, acToggle,
      applyButton, resetSystemButton, manualButton, resetPolicyButton, resetHistoryButton]
    refresh()
  }
}
