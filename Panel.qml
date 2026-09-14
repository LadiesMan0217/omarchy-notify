import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Ui
import "NotificationLogic.js" as Logic

Panel {
  id: root
  moduleName: "caio.omarchy-notify"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  property var notificationService: null
  readonly property var barIdentity: hostWidget || root
  readonly property var sourceModel: notificationService && "popupModel" in notificationService
    ? notificationService.popupModel : null
  readonly property bool serviceAvailable: sourceModel && typeof sourceModel.count === "number"
    && typeof sourceModel.get === "function"
  readonly property bool dnd: notificationService && notificationService.doNotDisturb === true
  property int tab: 0 // 0 active/unread; 1 replayed history
  property string query: ""
  property int selectedIndex: 0
  property bool helpOpen: false
  property var rows: []

  function refreshRows() {
    rows = Logic.rowsFromModel(sourceModel, query)
    if (selectedIndex >= rows.length) selectedIndex = Math.max(0, rows.length - 1)
    if (rows.length === 0) selectedIndex = 0
    Qt.callLater(function() { if (rows.length > 0) list.positionViewAtIndex(selectedIndex, ListView.Contain) })
  }
  function open() { refreshRows(); controller.show() }
  function close() { helpOpen = false; controller.hide() }
  function toggle() { opened ? close() : open() }
  function setTab(value) {
    var next = value === 1 ? 1 : 0
    if (tab === next) return
    tab = next
    selectedIndex = 0
    if (tab === 1 && notificationService && typeof notificationService.showRecentHistory === "function") notificationService.showRecentHistory()
    refreshRows()
  }
  function move(delta) {
    if (rows.length === 0) return
    selectedIndex = Math.max(0, Math.min(rows.length - 1, selectedIndex + delta))
    list.positionViewAtIndex(selectedIndex, ListView.Contain)
  }
  function dismissSelected() {
    if (!rows.length || !notificationService || typeof notificationService.dismissPopup !== "function") return
    notificationService.dismissPopup(rows[selectedIndex].serviceIndex)
    refreshRows()
  }
  function activateSelected() {
    if (!rows.length || !notificationService || typeof notificationService.invokePopupDefault !== "function") return
    notificationService.invokePopupDefault(rows[selectedIndex].serviceIndex)
    refreshRows()
  }
  function toggleDnd() {
    if (notificationService && typeof notificationService.setDoNotDisturb === "function") notificationService.setDoNotDisturb(!dnd)
  }
  function focusSearch() { search.forceActiveFocus(); search.selectAll() }
  function handleEscape() {
    if (search.activeFocus) { query = ""; keyCatcher.forceActiveFocus() }
    else close()
  }

  onQueryChanged: refreshRows()
  onSourceModelChanged: refreshRows()
  onOpenedChanged: if (opened) Qt.callLater(function() { keyCatcher.forceActiveFocus(); refreshRows() })

  Connections {
    target: root.sourceModel
    function onCountChanged() { root.refreshRows() }
    function onDataChanged() { root.refreshRows() }
  }

  // Quattro 4.0.3 has KeyboardPanel for bar-attached popovers, but no drawer
  // primitive. This is intentionally a narrow PanelWindow, not a full-screen
  // modal: the desktop stays interactive and visible beside the center.
  PanelWindow {
    id: panel
    screen: root.anchorItem ? root.anchorItem.QsWindow.window.screen : null
    width: Math.min(Style.space(440), screen ? screen.width : Style.space(440))
    visible: root.opened || drawer.x < width
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "omarchy-notify-drawer"
    WlrLayershell.layer: WlrLayer.Overlay
    // The brief exclusive mapping makes an IPC-opened drawer keyboard-ready.
    WlrLayershell.keyboardFocus: root.opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    anchors {
      top: true
      bottom: true
      right: true
      topMargin: root.bar && root.bar.position === "top" ? root.bar.barSize + Style.gapsOut : Style.gapsOut
      bottomMargin: root.bar && root.bar.position === "bottom" ? root.bar.barSize + Style.gapsOut : Style.gapsOut
    }

    BorderSurface {
      id: drawer
      width: panel.width
      height: panel.height
      x: root.opened ? 0 : panel.width
      color: Color.popups.background
      borderSpec: Border.surfaceSpec("popups", "border", Color.popups.border, Math.max(1, Style.space(1)))
      radius: Style.cornerRadius

      Behavior on x {
        NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
      }

      PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      anchors.margins: Style.spacing.popupPadding
      blocked: search.activeFocus
      onMoveRequested: function(dx, dy) { if (dy) root.move(dy); else if (dx) root.setTab(root.tab + dx) }
      onActivateRequested: root.activateSelected()
      onDeleteRequested: root.dismissSelected()
      onCloseRequested: root.handleEscape()
      onTabRequested: function(direction) { root.setTab(root.tab + direction) }
      onTextKey: function(t) {
        if (t === "g") { root.selectedIndex = 0; list.positionViewAtBeginning() }
        else if (t === "G") { root.selectedIndex = Math.max(0, root.rows.length - 1); list.positionViewAtEnd() }
        else if (t === "d") root.dismissSelected()
        else if (t === "x") root.dismissSelected()
        else if (t === "/") root.focusSearch()
        else if (t === "D") root.toggleDnd()
        else if (t === "?") root.helpOpen = !root.helpOpen
      }

      ColumnLayout {
        id: content
        width: parent.width
        spacing: Style.space(10)

        RowLayout {
          Layout.fillWidth: true
          Text { text: "NOTIFICATIONS"; color: root.barForeground; font.family: root.bar ? root.bar.fontFamily : Style.font.family; font.pixelSize: Style.font.title; font.bold: true; font.letterSpacing: 1 }
          Item { Layout.fillWidth: true }
          Text { text: root.rows.length; color: Qt.darker(root.barForeground, 1.35); font.family: root.bar ? root.bar.fontFamily : Style.font.family; font.pixelSize: Style.font.body }
          Text { text: root.dnd ? "DND" : ""; color: root.dnd ? Color.accent : "transparent"; font.family: root.bar ? root.bar.fontFamily : Style.font.family; font.pixelSize: Style.font.bodySmall }
          Text { text: "×"; color: root.barForeground; font.family: root.bar ? root.bar.fontFamily : Style.font.family; font.pixelSize: Style.font.title
            MouseArea { anchors.fill: parent; onClicked: root.close() } }
        }

        TextField {
          id: search
          Layout.fillWidth: true
          placeholderText: "Search notifications  /"
          text: root.query
          foreground: root.barForeground
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          onTextEdited: root.query = text
          Keys.onPressed: function(event) { if (event.key === Qt.Key_Escape) { root.handleEscape(); event.accepted = true } }
        }

        RowLayout {
          Layout.fillWidth: true
          Repeater {
            model: ["Unread", "History"]
            delegate: Text {
              required property string modelData
              required property int index
              text: modelData
              color: root.tab === index ? root.barForeground : Qt.darker(root.barForeground, 1.55)
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.body
              font.bold: root.tab === index
              MouseArea { anchors.fill: parent; anchors.margins: -Style.space(5); onClicked: root.setTab(index) }
            }
          }
          Item { Layout.fillWidth: true }
          Text { text: root.dnd ? "DND ON" : "DND OFF"; color: Qt.darker(root.barForeground, 1.4); font.family: root.bar ? root.bar.fontFamily : Style.font.family; font.pixelSize: Style.font.bodySmall
            MouseArea { anchors.fill: parent; anchors.margins: -Style.space(4); onClicked: root.toggleDnd() } }
        }

        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Qt.darker(root.barForeground, 1.8) }

        Item {
          Layout.fillWidth: true
          Layout.fillHeight: true
          Layout.preferredHeight: Style.space(350)
          ListView {
            id: list
            anchors.fill: parent
            clip: true
            model: root.serviceAvailable ? root.rows : []
            spacing: Style.space(5)
            delegate: Rectangle {
              required property var modelData
              required property int index
              width: list.width
              height: card.implicitHeight + Style.space(14)
              radius: Math.min(Style.cornerRadius, Style.space(5))
              color: root.selectedIndex === index ? Style.hoverFillFor(root.barForeground, Color.accent) : "transparent"
              border.width: root.selectedIndex === index ? 1 : 0
              border.color: Qt.darker(root.barForeground, 1.5)
              MouseArea { anchors.fill: parent; hoverEnabled: true; onEntered: root.selectedIndex = index; onClicked: root.activateSelected() }
              Column {
                id: card
                anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                anchors.margins: Style.space(8)
                spacing: Style.space(3)
                Row {
                  width: parent.width
                  Image {
                    visible: Logic.localImageSource(modelData.image).length > 0
                    width: Style.space(14); height: width
                    source: Logic.localImageSource(modelData.image)
                    sourceSize.width: Math.round(width * 2)
                    sourceSize.height: Math.round(height * 2)
                    fillMode: Image.PreserveAspectFit
                  }
                  Text { visible: !Logic.localImageSource(modelData.image); text: modelData.appIcon ? "●" : ""; color: Color.accent; font.pixelSize: Style.font.bodySmall }
                  Text { text: modelData.app || "Notification"; color: Qt.darker(root.barForeground, 1.35); font.family: root.bar ? root.bar.fontFamily : Style.font.family; font.pixelSize: Style.font.bodySmall }
                  Text { text: "  " + modelData.relativeTime; color: Qt.darker(root.barForeground, 1.55); font.family: root.bar ? root.bar.fontFamily : Style.font.family; font.pixelSize: Style.font.bodySmall }
                }
                Text { width: parent.width; text: modelData.summary; elide: Text.ElideRight; color: root.barForeground; font.family: root.bar ? root.bar.fontFamily : Style.font.family; font.pixelSize: Style.font.body; font.bold: true }
                Text { visible: modelData.body.length > 0; width: parent.width; text: modelData.body; wrapMode: Text.Wrap; maximumLineCount: 2; elide: Text.ElideRight; color: Qt.darker(root.barForeground, 1.35); font.family: root.bar ? root.bar.fontFamily : Style.font.family; font.pixelSize: Style.font.bodySmall }
              }
            }
          }
          Column {
            anchors.centerIn: parent
            visible: !root.serviceAvailable || root.rows.length === 0
            spacing: Style.space(7)
            Text { anchors.horizontalCenter: parent.horizontalCenter; text: !root.serviceAvailable ? "󰂚" : ""; color: Qt.darker(root.barForeground, 1.45); font.family: root.bar ? root.bar.fontFamily : Style.font.family; font.pixelSize: Style.font.display }
            Text { anchors.horizontalCenter: parent.horizontalCenter; text: !root.serviceAvailable ? "Notification service unavailable" : root.query ? "No notifications match your search" : root.tab === 0 ? "No unread notifications" : "No recent notifications"; color: Qt.darker(root.barForeground, 1.35); font.family: root.bar ? root.bar.fontFamily : Style.font.family; font.pixelSize: Style.font.body }
            Text { visible: !root.serviceAvailable; anchors.horizontalCenter: parent.horizontalCenter; text: "Omarchy does not expose notification entries to third-party widgets."; color: Qt.darker(root.barForeground, 1.65); font.family: root.bar ? root.bar.fontFamily : Style.font.family; font.pixelSize: Style.font.bodySmall }
          }
        }

        Text { Layout.fillWidth: true; visible: root.helpOpen; wrapMode: Text.Wrap; text: "j/k or ↑/↓ move · g/G first/last · Enter open · d/x dismiss · / search · Tab or h/l tabs · D DND · Esc close"; color: Qt.darker(root.barForeground, 1.4); font.family: root.bar ? root.bar.fontFamily : Style.font.family; font.pixelSize: Style.font.bodySmall }
      }
      }
    }
  }
}
