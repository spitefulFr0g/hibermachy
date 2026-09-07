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
  property bool confirmationOpen: false
  property string manualRequestResult: ""

  readonly property string confirmationMessage: statusSnapshot ? statusSnapshot.manualConfirmationMessage : "Manual staged sleep is unavailable."

  function open() {
    refresh()
    controller.show()
  }

  function refresh() {
    if (draftDirty || !service || !service.policySnapshot) return
    draftAutomaticPolicyEnabled = service.policySnapshot.automaticPolicyEnabled
    draftIdleDelaySeconds = service.policySnapshot.idleDelaySeconds
    draftBaseRevision = service.policySnapshot.revision
    if (!systemDraftDirty) {
      draftHibernateDelaySeconds = service.systemPolicyDraft.hibernateDelaySeconds
      draftHibernateOnAcPower = service.systemPolicyDraft.hibernateOnAcPower
    }
  }

  function editAutomaticPolicyEnabled(enabled) {
    draftAutomaticPolicyEnabled = enabled
    draftDirty = true
  }

  function editIdleDelaySeconds(seconds) {
    draftIdleDelaySeconds = seconds
    draftDirty = true
  }

  function saveDraft() {
    if (!service) return JSON.stringify({ accepted: false, reasonCode: "HBR-POLICY-UNAVAILABLE" })
    var receipt = JSON.parse(service.saveUserPolicy(JSON.stringify({
      baseRevision: draftBaseRevision,
      automaticPolicyEnabled: draftAutomaticPolicyEnabled,
      idleDelaySeconds: draftIdleDelaySeconds
    })))
    if (receipt.accepted) {
      draftBaseRevision += 1
    }
    draftDirty = !receipt.accepted
    return JSON.stringify(receipt)
  }

  function editSystemPolicy(delaySeconds, onAcPower) {
    draftHibernateDelaySeconds = delaySeconds
    draftHibernateOnAcPower = onAcPower
    systemDraftDirty = true
  }

  function reviewSystemPolicy() {
    if (!service) return JSON.stringify({ accepted: false, reasonCode: "HBR-SYSTEM-POLICY-UNAVAILABLE" })
    return service.editSystemPolicyDraft(draftHibernateDelaySeconds, draftHibernateOnAcPower)
      && service.reviewSystemPolicy()
  }

  function applySystemPolicy() {
    if (!service) return JSON.stringify({ accepted: false, reasonCode: "HBR-SYSTEM-POLICY-UNAVAILABLE" })
    var draftReceipt = JSON.parse(service.editSystemPolicyDraft(draftHibernateDelaySeconds, draftHibernateOnAcPower))
    if (!draftReceipt.accepted) return JSON.stringify(draftReceipt)
    var review = JSON.parse(service.reviewSystemPolicy())
    if (!review.accepted) return JSON.stringify(review)
    var receipt = JSON.parse(service.applySystemPolicy())
    if (receipt.accepted) systemDraftDirty = false
    return JSON.stringify(receipt)
  }

  function resetSystemPolicy() {
    if (!service) return JSON.stringify({ accepted: false, reasonCode: "HBR-SYSTEM-POLICY-UNAVAILABLE" })
    return service.resetSystemPolicy()
  }

  function beginConfirmation() {
    refresh()
    if (statusSnapshot && statusSnapshot.manualStagedSleepReadiness === "ready") confirmationOpen = true
  }

  function cancelConfirmation() { confirmationOpen = false }

  function submitConfirmedRequest() {
    confirmationOpen = false
    manualRequestResult = service ? service.requestStagedSleep()
      : JSON.stringify({ kind: "failed", reasonCode: "HBR-SLEEP-SERVICE-UNAVAILABLE" })
  }

  onStatusSnapshotChanged: refresh()

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root
    bar: root.bar
    open: root.opened
    contentWidth: fittedContentWidth(Style.space(420))
    contentHeight: fittedContentHeight(content.implicitHeight)
    focusTarget: keyCatcher

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onMoveRequested: function(dx, dy) {
        if (root.confirmationOpen && (dx !== 0 || dy !== 0))
          confirmation.selectedIndex = confirmation.selectedIndex === 0 ? 1 : 0
      }
      onTabRequested: function(direction) {
        if (root.confirmationOpen)
          confirmation.selectedIndex = confirmation.selectedIndex === 0 ? 1 : 0
      }
      onActivateRequested: {
        if (!root.confirmationOpen) root.beginConfirmation()
        else if (confirmation.selectedIndex === 0) root.cancelConfirmation()
        else root.submitConfirmedRequest()
      }
      onCloseRequested: {
        if (root.confirmationOpen) root.cancelConfirmation()
        else root.close()
      }
    }

    Column {
      id: content
      width: parent.width
      spacing: Style.space(14)

      PanelHero {
        width: parent.width
        title: "Hibermachy"
        meta: root.statusSnapshot ? "Plugin " + root.statusSnapshot.pluginActivation : "Status unavailable"
        detail: root.statusSnapshot ? "Automatic policy " + root.statusSnapshot.automaticPolicyEnablement : ""
      }

      PanelSeparator { width: parent.width }

      PanelSectionHeader {
        text: "Automatic staged sleep"
      }

      Toggle {
        width: parent.width
        label: "Enable automatic staged sleep"
        description: "Keep this as a draft until Save automatic policy is pressed."
        checked: root.draftAutomaticPolicyEnabled
        onClicked: root.editAutomaticPolicyEnabled(!root.draftAutomaticPolicyEnabled)
      }

      NumberField {
        label: "Idle delay (seconds)"
        value: root.draftIdleDelaySeconds
        from: 300
        to: 86400
        stepSize: 1
        onModified: function(value) { root.editIdleDelaySeconds(value) }
      }

      Button {
        text: "Save automatic policy"
        bordered: true
        focusable: true
        enabled: root.draftDirty
        onClicked: root.saveDraft()
      }

      Text {
        width: parent.width
        textFormat: Text.PlainText
        text: root.statusSnapshot
          ? "Not ready: automatic staged sleep is " + root.statusSnapshot.automaticPolicyEnablement + "."
          : "Status is unavailable."
        color: Color.foreground
        font.family: Style.font.family
        font.pixelSize: Style.font.body
        wrapMode: Text.WordWrap
      }

      PanelSeparator { width: parent.width }

      PanelSectionHeader { text: "System policy" }

      Button {
        width: parent.width
        text: "Suspend then Hibernate"
        enabled: root.statusSnapshot && root.statusSnapshot.manualStagedSleepReadiness === "ready"
        bordered: true
        onClicked: root.beginConfirmation()
      }

      Text {
        width: parent.width
        visible: root.manualRequestResult.length > 0
        textFormat: Text.PlainText
        text: root.manualRequestResult
        color: Color.foreground
        font.family: Style.font.family
        font.pixelSize: Style.font.body
        wrapMode: Text.WordWrap
      }

      Text {
        width: parent.width
        textFormat: Text.PlainText
        text: "Machine-wide: hibernate delay and hibernation while plugged in affect every user and suspend-then-hibernate caller. Changes remain a draft until authenticated Apply system policy."
        color: Color.foreground
        font.family: Style.font.family
        font.pixelSize: Style.font.body
        wrapMode: Text.WordWrap
      }

      NumberField {
        label: "Hibernate delay (seconds)"
        value: root.draftHibernateDelaySeconds
        from: 900
        to: 604800
        stepSize: 1
        onModified: function(value) { root.editSystemPolicy(value, root.draftHibernateOnAcPower) }
      }

      Toggle {
        width: parent.width
        label: "Hibernate while plugged in"
        description: "Machine-wide system policy draft."
        checked: root.draftHibernateOnAcPower
        onClicked: root.editSystemPolicy(root.draftHibernateDelaySeconds, !root.draftHibernateOnAcPower)
      }

      Button {
        text: "Apply system policy"
        bordered: true
        focusable: true
        enabled: root.systemDraftDirty
        onClicked: root.applySystemPolicy()
      }

      Button {
        text: "Reset requested system policy"
        bordered: true
        focusable: true
        enabled: root.statusSnapshot && root.statusSnapshot.requestedSystemPolicy !== null
        onClicked: root.resetSystemPolicy()
      }

      Text {
        width: parent.width
        textFormat: Text.PlainText
        text: root.statusSnapshot
          ? "Requested: " + JSON.stringify(root.statusSnapshot.requestedSystemPolicy)
            + "\nEffective: " + JSON.stringify(root.statusSnapshot.effectiveSystemPolicy)
            + "\n" + root.statusSnapshot.systemPolicyReasonCode
          : "System policy unavailable."
        color: Color.foreground
        font.family: Style.font.family
        font.pixelSize: Style.font.body
        wrapMode: Text.WordWrap
      }

      Text {
        width: parent.width
        textFormat: Text.PlainText
        text: "Draft: " + (root.draftAutomaticPolicyEnabled ? "enabled" : "disabled")
          + ", idle delay " + root.draftIdleDelaySeconds + " seconds"
          + (root.draftDirty ? " (unsaved)" : "")
        color: Color.foreground
        font.family: Style.font.family
        font.pixelSize: Style.font.body
        wrapMode: Text.WordWrap
      }
    }

    ConfirmDialog {
      id: confirmation
      anchors.fill: parent
      opened: root.confirmationOpen
      message: root.confirmationMessage
      confirmText: "Request staged sleep"
      z: 10
      onCanceled: root.cancelConfirmation()
      onConfirmed: root.submitConfirmedRequest()
    }
  }
}
