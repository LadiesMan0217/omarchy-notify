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
  property var nativeNotificationService: null
  readonly property var resolvedNativeService: {
    if (nativeNotificationService) return nativeNotificationService
    if (hostWidget && typeof hostWidget.resolveNativeNotificationService === "function") {
      return hostWidget.resolveNativeNotificationService()
    }
    try {
      if (bar && bar.shell && typeof bar.shell.serviceFor === "function") {
        return bar.shell.serviceFor("omarchy.notifications")
      }
    } catch (e) {}
    return null
  }
  readonly property string omarchyPath: Quickshell.env("OMARCHY_PATH") || "/usr/share/omarchy"
  readonly property var barIdentity: hostWidget || root
  readonly property bool serviceAvailable: notificationService !== null && notificationService.loaded === true
  readonly property bool dnd: false
  property string query: ""
  property bool searchMode: false
  property int selectedIndex: 0
  property bool helpOpen: false
  property var rows: []

  function refreshRows() {
    rows = Logic.rowsFromEntries(notificationService ? notificationService.entries : [], query, false,
      notificationService ? notificationService.lastSeen : 0)
    if (selectedIndex >= rows.length) selectedIndex = Math.max(0, rows.length - 1)
    if (rows.length === 0) selectedIndex = 0
    Qt.callLater(function() { if (rows.length > 0) list.positionViewAtIndex(selectedIndex, ListView.Contain) })
  }
  function open() {
    selectedIndex = 0
    searchMode = false
    query = ""
    refreshRows()
    controller.show()
  }
  function close() {
    // Fechar a gaveta confirma as entradas vistas nesta abertura.
    if (notificationService && typeof notificationService.markSeen === "function") notificationService.markSeen()
    helpOpen = false
    searchMode = false
    query = ""
    controller.hide()
  }
  function toggle() { opened ? close() : open() }
  function move(delta) {
    if (rows.length === 0) return
    selectedIndex = Math.max(0, Math.min(rows.length - 1, selectedIndex + delta))
    list.positionViewAtIndex(selectedIndex, ListView.Contain)
  }
  function dismissSelected() {
    if (!rows.length || !notificationService || typeof notificationService.remove !== "function") return
    notificationService.remove(rows[selectedIndex].key)
    refreshRows()
  }
  function clearAll() {
    if (!notificationService || typeof notificationService.clear !== "function") return
    notificationService.clear()
    refreshRows()
  }
  function activateSelected() {
    if (selectedIndex < 0 || selectedIndex >= rows.length) return
    activateNotification(rows[selectedIndex])
  }
  function activateByKey(key) {
    if (!key) return false
    var targetKey = String(key).trim()
    if (!rows || rows.length === 0) refreshRows()
    for (var i = 0; i < rows.length; i++) {
      if (rows[i] && rows[i].key === targetKey) {
        selectedIndex = i
        activateNotification(rows[i])
        return true
      }
    }
    return false
  }
  function activateNotification(row) {
    if (!row) return

    var nativeService = root.resolvedNativeService
    var liveIndex = -1

    if (nativeService && nativeService.popupModel) {
      liveIndex = Logic.findLivePopupIndex(nativeService.popupModel, row)
    }

    if (liveIndex >= 0 && nativeService && typeof nativeService.invokePopupDefault === "function") {
      // Caso 1 — existe popup nativo vivo correspondente
      nativeService.invokePopupDefault(liveIndex)
      root.close()
      return
    }

    // Caso 2 — não existe mais popup vivo. Fallback seguro para focar o aplicativo/janela existente
    var appName = row.app ? String(row.app).trim() : ""
    if (Logic.isWhatsAppUrl(row.linkUrl)) {
      appName = "whatsapp"
    }
    if (appName.length > 0) {
      Quickshell.execDetached([
        root.omarchyPath + "/bin/omarchy-hyprland-focus-app",
        appName
      ])
      root.close()
      return
    }

    // Caso 3 — nenhum desses caminhos estiver disponível. Fallback para URL sanitizada (exceto WhatsApp)
    if (row.linkUrl && !Logic.isWhatsAppUrl(row.linkUrl)) {
      Qt.openUrlExternally(row.linkUrl)
      root.close()
      return
    }

    root.close()
  }
  function toggleDnd() {
    if (notificationService && typeof notificationService.setDoNotDisturb === "function") notificationService.setDoNotDisturb(!dnd)
  }
  function focusSearch() {
    searchMode = true
    Qt.callLater(function() { search.forceActiveFocus(); search.selectAll() })
  }
  function exitSearch() {
    query = ""
    searchMode = false
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }
  function handleEscape() {
    if (searchMode) exitSearch()
    else close()
  }

  onQueryChanged: refreshRows()
  onNotificationServiceChanged: refreshRows()
  onOpenedChanged: if (opened) Qt.callLater(function() { keyCatcher.forceActiveFocus(); refreshRows() })

  Connections {
    target: root.notificationService
    function onEntriesChanged() { root.refreshRows() }
    function onLoadedChanged() { root.refreshRows() }
  }

  // O Quattro não tem drawer pronto. Este PanelWindow fica estreito de
  // propósito: desktop e gaveta continuam visíveis ao mesmo tempo.
  PanelWindow {
    id: panel
    screen: root.anchorItem ? root.anchorItem.QsWindow.window.screen : null
    visible: root.opened || drawer.x < width
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "omarchy-notify-drawer"
    WlrLayershell.layer: WlrLayer.Overlay
    // Garante foco de teclado quando a gaveta abre por IPC.
    WlrLayershell.keyboardFocus: root.opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    anchors {
      top: true
      bottom: true
      left: true
      right: true
    }

    MouseArea {
      anchors.fill: parent
      onClicked: root.close()
    }

    BorderSurface {
      id: drawer
      width: Math.min(Style.space(440), panel.width)
      readonly property int topInset: root.bar && root.bar.position === "top" ? root.bar.barSize + Style.gapsOut : Style.gapsOut
      readonly property int bottomInset: root.bar && root.bar.position === "bottom" ? root.bar.barSize + Style.gapsOut : Style.gapsOut
      y: topInset
      height: Math.max(1, panel.height - topInset - bottomInset)
      x: root.opened ? panel.width - width : panel.width
      color: Color.popups.background
      borderSpec: Border.surfaceSpec("popups", "border", Color.popups.border, Math.max(1, Style.space(1)))
      radius: Style.cornerRadius

      Behavior on x {
        NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
      }

      MouseArea { anchors.fill: parent; onClicked: {} }

      PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      anchors.margins: Style.spacing.popupPadding
      blocked: root.searchMode
      onMoveRequested: function(dx, dy) { if (dy) root.move(dy) }
      onActivateRequested: root.activateSelected()
      onDeleteRequested: root.dismissSelected()
      onCloseRequested: root.handleEscape()
      onTabRequested: function(direction) {}
      onTextKey: function(t) {
        if (t === "g") { root.selectedIndex = 0; list.positionViewAtBeginning() }
        else if (t === "G") { root.selectedIndex = Math.max(0, root.rows.length - 1); list.positionViewAtEnd() }
        else if (t === "d") root.dismissSelected()
        else if (t === "x") root.dismissSelected()
        else if (t === "C") root.clearAll()
        else if (t === "/") root.focusSearch()
        else if (t === "D") root.toggleDnd()
        else if (t === "?") root.helpOpen = !root.helpOpen
      }

      ColumnLayout {
        id: content
        anchors.fill: parent
        spacing: Style.space(10)

        RowLayout {
          Layout.fillWidth: true
          Text { text: "NOTIFICATIONS"; color: root.barForeground; font.family: root.bar ? root.bar.fontFamily : Style.font.family; font.pixelSize: Style.font.title; font.bold: true; font.letterSpacing: 1 }
          Item { Layout.fillWidth: true }
          Text { text: "clear all"; color: Qt.darker(root.barForeground, 1.45); font.family: root.bar ? root.bar.fontFamily : Style.font.family; font.pixelSize: Style.font.bodySmall
            MouseArea { anchors.fill: parent; anchors.margins: -Style.space(4); onClicked: root.clearAll() } }
          Text { text: root.rows.length; color: Qt.darker(root.barForeground, 1.35); font.family: root.bar ? root.bar.fontFamily : Style.font.family; font.pixelSize: Style.font.body }
          Text { text: root.dnd ? "DND" : ""; color: root.dnd ? Color.accent : "transparent"; font.family: root.bar ? root.bar.fontFamily : Style.font.family; font.pixelSize: Style.font.bodySmall }
          Text { text: "×"; color: root.barForeground; font.family: root.bar ? root.bar.fontFamily : Style.font.family; font.pixelSize: Style.font.title
            MouseArea { anchors.fill: parent; onClicked: root.close() } }
        }

        TextField {
          id: search
          Layout.fillWidth: true
          Layout.preferredHeight: visible ? implicitHeight : 0
          visible: root.searchMode
          placeholderText: "Search notifications"
          text: root.query
          foreground: root.barForeground
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          onTextEdited: root.query = text
          Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Down) {
              root.move(1)
              event.accepted = true
            } else if (event.key === Qt.Key_Up) {
              root.move(-1)
              event.accepted = true
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
              root.activateSelected()
              event.accepted = true
            } else if (event.key === Qt.Key_Escape) {
              root.exitSearch()
              event.accepted = true
            }
          }
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
              MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: root.selectedIndex = index
                onClicked: {
                  root.selectedIndex = index
                  root.activateSelected()
                }
              }
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
                  Text { visible: !Logic.localImageSource(modelData.image); text: modelData.appIcon ? "●" : ""; color: Color.accent; font.pixelSize: Style.font.bodySmall; textFormat: Text.PlainText }
                  Text { text: modelData.app || "Notification"; color: Qt.darker(root.barForeground, 1.35); font.family: root.bar ? root.bar.fontFamily : Style.font.family; font.pixelSize: Style.font.bodySmall; textFormat: Text.PlainText }
                  Text { text: "  " + modelData.relativeTime; color: Qt.darker(root.barForeground, 1.55); font.family: root.bar ? root.bar.fontFamily : Style.font.family; font.pixelSize: Style.font.bodySmall; textFormat: Text.PlainText }
                  Text { visible: !!modelData.linkUrl; text: " ↗"; color: root.selectedIndex === index ? root.barForeground : Qt.darker(root.barForeground, 1.45); font.family: root.bar ? root.bar.fontFamily : Style.font.family; font.pixelSize: Style.font.bodySmall; textFormat: Text.PlainText }
                }
                Text { width: parent.width; text: modelData.summary; elide: Text.ElideRight; color: root.barForeground; font.family: root.bar ? root.bar.fontFamily : Style.font.family; font.pixelSize: Style.font.body; font.bold: true; textFormat: Text.PlainText }
                Text { visible: modelData.body.length > 0; width: parent.width; text: modelData.body; wrapMode: Text.Wrap; maximumLineCount: 2; elide: Text.ElideRight; color: Qt.darker(root.barForeground, 1.35); font.family: root.bar ? root.bar.fontFamily : Style.font.family; font.pixelSize: Style.font.bodySmall; textFormat: Text.PlainText }
              }
            }
          }
          Column {
            anchors.centerIn: parent
            visible: !root.serviceAvailable || root.rows.length === 0
            spacing: Style.space(7)
            Text { anchors.horizontalCenter: parent.horizontalCenter; text: ""; color: Qt.darker(root.barForeground, 1.45); font.family: root.bar ? root.bar.fontFamily : Style.font.family; font.pixelSize: Style.font.display }
            Text { anchors.horizontalCenter: parent.horizontalCenter; text: !root.serviceAvailable ? "Loading notification archive…" : root.query ? "No notifications match your search" : "No notifications"; color: Qt.darker(root.barForeground, 1.35); font.family: root.bar ? root.bar.fontFamily : Style.font.family; font.pixelSize: Style.font.body }
          }
        }

        Text { Layout.fillWidth: true; visible: root.helpOpen; wrapMode: Text.Wrap; text: "Enter open · j/k or ↑/↓ move · g/G first/last · d/x dismiss · C clear all · / search · Esc close"; color: Qt.darker(root.barForeground, 1.4); font.family: root.bar ? root.bar.fontFamily : Style.font.family; font.pixelSize: Style.font.bodySmall }
        Text { Layout.fillWidth: true; text: "Enter open · j/k move · x dismiss · C clear all · / search · ? help · Esc close"; color: Qt.darker(root.barForeground, 1.65); font.family: root.bar ? root.bar.fontFamily : Style.font.family; font.pixelSize: Style.font.bodySmall }
      }
      }
    }
  }
}
