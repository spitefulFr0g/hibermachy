import QtQuick
import qs.Commons
import qs.Ui

Item {
  id: root

  property bool opened: false
  property string message: ""
  property int selectedIndex: 1
  readonly property string cancelAccessibleName: cancelButton.Accessible.name
  readonly property string confirmAccessibleName: confirmButton.Accessible.name

  signal canceled()
  signal confirmed()

  function moveSelection(delta) {
    selectedIndex = (selectedIndex + delta + 2) % 2;
    var target = selectedIndex === 0 ? cancelButton : confirmButton
    target.forceActiveFocus()
  }
  function activateSelected() {
    if (selectedIndex === 0) canceled()
    else confirmed()
  }

  visible: opened
  Accessible.name: "Confirmation"
  Accessible.description: message + " Choose Cancel or Confirm."

  onOpenedChanged: {
    if (opened) Qt.callLater(function() { confirmButton.forceActiveFocus() })
  }

  Rectangle {
    anchors.fill: parent
    color: Util.alpha(Color.background, 0.7)

    MouseArea { anchors.fill: parent; onClicked: root.canceled() }

    BorderSurface {
      id: card
      width: Math.min(parent.width - Style.space(32), Style.space(370))
      height: card.contentTopInset + card.contentBottomInset + messageText.implicitHeight + Style.space(20) + Style.space(34)
      anchors.centerIn: parent
      color: Color.background
      borderSpec: Border.flat(Color.accent, Style.normalBorderWidth)
      padding: Style.space(18)
      radius: Style.cornerRadius

      MouseArea { anchors.fill: parent; onClicked: {} }

      Item {
        anchors.fill: parent
        anchors.topMargin: card.contentTopInset
        anchors.rightMargin: card.contentRightInset
        anchors.bottomMargin: card.contentBottomInset
        anchors.leftMargin: card.contentLeftInset

        Text {
          id: messageText
          textFormat: Text.PlainText
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.top: parent.top
          text: root.message
          color: Color.foreground
          font.family: Style.font.family
          font.pixelSize: Style.font.title
          wrapMode: Text.WordWrap
          Accessible.name: text
        }

        Row {
          anchors.right: parent.right
          anchors.bottom: parent.bottom
          spacing: Style.space(10)

          Button {
            id: cancelButton
            text: "Cancel"
            width: Style.space(88)
            focusable: true
            bordered: true
            selected: root.selectedIndex === 0
            onClicked: root.canceled()
            Accessible.name: "Cancel"
            Accessible.description: "Leave the requested action unchanged."
          }
          Button {
            id: confirmButton
            text: "Confirm"
            width: Style.space(88)
            focusable: true
            bordered: true
            selected: root.selectedIndex === 1
            onClicked: root.confirmed()
            Accessible.name: "Confirm"
            Accessible.description: root.message
          }
        }
      }
    }
  }
}
