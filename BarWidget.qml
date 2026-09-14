import QtQuick
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "caio.omarchy-notify"

  // O serviço do manifesto não sobe junto do widget. O leitor fica aqui para
  // acompanhar a vida útil da barra.
  readonly property var notificationService: archiveService
  readonly property int unreadCount: notificationService ? Number(notificationService.unread || 0) : 0
  readonly property bool dnd: false
  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  function injectPanel() {
    var panel = panelLoader.item
    if (!panel) return
    panel.bar = root.bar
    panel.settings = root.settings
    panel.anchorItem = button
    panel.hostWidget = root
    panel.notificationService = root.notificationService
  }
  function open() { if (panelLoader.item) panelLoader.item.open() }
  function close() { if (panelLoader.item) panelLoader.item.close() }
  function toggle() { if (panelLoader.item) panelLoader.item.toggle() }
  function closeForPopoutSwitch() { if (panelLoader.item) panelLoader.item.closeForPopoutSwitch() }
  function toggleDnd() {}

  Service {
    id: archiveService
  }

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()
  onNotificationServiceChanged: injectPanel()

  Loader {
    id: panelLoader
    active: true
    visible: false
    source: Qt.resolvedUrl("Panel.qml")
    onLoaded: { root.injectPanel(); Qt.callLater(root.injectPanel) }
  }

  IpcHandler {
    target: root.moduleName
    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.toggle() }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    labelVisible: false
    // Sem label, o WidgetButton esconderia o sino.
    hasVisualContent: true
    tooltipText: root.dnd ? "Do Not Disturb" : root.unreadCount === 0 ? "No notifications"
      : root.unreadCount === 1 ? "1 unread notification" : root.unreadCount + " unread notifications"

    onPressed: function(button) {
      if (button === Qt.RightButton) root.toggleDnd()
      else if (button === Qt.LeftButton) root.toggle()
    }

    Item {
      anchors.centerIn: parent
      width: Style.bar.iconSlot
      height: Style.bar.iconSlot
      Text {
        anchors.centerIn: parent
        text: root.dnd ? "󰂛" : root.unreadCount > 0 ? "" : ""
        color: root.dnd ? Qt.darker(button.foreground, 1.45) : root.unreadCount > 0 ? button.activeColor : button.foreground
        font.family: button.fontFamily
        font.pixelSize: Style.font.title
      }
      Rectangle {
        visible: root.unreadCount > 0
        anchors.right: parent.right
        anchors.top: parent.top
        width: Math.max(Style.space(12), badgeText.implicitWidth + Style.space(6))
        height: Style.space(12)
        radius: height / 2
        color: button.activeColor
        Text {
          id: badgeText
          anchors.centerIn: parent
          text: root.unreadCount > 99 ? "99+" : root.unreadCount
          color: Color.background
          font.family: button.fontFamily
          font.bold: true
          font.pixelSize: Style.font.bodySmall * 0.75
        }
      }
    }
  }
}
