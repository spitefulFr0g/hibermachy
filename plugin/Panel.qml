import QtQuick
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "dev.hibermachy"
  ipcTarget: "dev.hibermachy"

  property var service: null
  property var anchorItem: null

  readonly property var statusSnapshot: service ? service.statusSnapshot : null
  property bool draftAutomaticPolicyEnabled: false
  property int draftIdleDelaySeconds: 1800
  property int draftBaseRevision: 0
  property bool draftDirty: false

  function open() {
    refresh()
    controller.show()
  }

  function refresh() {
    if (draftDirty || !service || !service.policySnapshot) return
    draftAutomaticPolicyEnabled = service.policySnapshot.automaticPolicyEnabled
    draftIdleDelaySeconds = service.policySnapshot.idleDelaySeconds
    draftBaseRevision = service.policySnapshot.revision
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

  onStatusSnapshotChanged: refresh()

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root
    bar: root.bar
    open: root.opened
    contentWidth: fittedContentWidth(Style.space(420))
    contentHeight: fittedContentHeight(content.implicitHeight)

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
  }
}
