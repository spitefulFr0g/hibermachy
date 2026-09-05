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
  property bool confirmationOpen: false
  property string manualRequestResult: ""

  readonly property string confirmationMessage: statusSnapshot ? statusSnapshot.manualConfirmationMessage : "Manual staged sleep is unavailable."

  function open() {
    refresh()
    controller.show()
  }

  function refresh() {
    if (service) service.status()
  }

  function beginConfirmation() {
    refresh()
    if (statusSnapshot && statusSnapshot.manualStagedSleepReadiness === "ready")
      confirmationOpen = true
  }

  function cancelConfirmation() {
    confirmationOpen = false
  }

  function submitConfirmedRequest() {
    confirmationOpen = false
    manualRequestResult = service
      ? service.requestStagedSleep()
      : JSON.stringify({ kind: "failed", reasonCode: "HBR-SLEEP-SERVICE-UNAVAILABLE" })
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: fittedContentWidth(Style.space(420))
    contentHeight: fittedContentHeight(content.implicitHeight)

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
