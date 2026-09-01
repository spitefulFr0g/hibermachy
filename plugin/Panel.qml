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

  function open() {
    refresh()
    controller.show()
  }

  function refresh() {}

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
    }
  }
}
