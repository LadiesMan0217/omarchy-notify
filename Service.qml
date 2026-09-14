import QtQuick
import Quickshell
import Quickshell.Io

// A private archive of snapshots already persisted by omarchy.notifications.
// It is not a notification daemon and never writes to Omarchy's state tree.
Item {
  id: root
  property var shell: null
  property string omarchyPath: ""
  property var entries: []
  property double lastSeen: 0
  property bool loaded: false
  readonly property int unread: {
    var count = 0
    for (var i = 0; i < entries.length; ++i) if (Number(entries[i].timestamp) > lastSeen) ++count
    return count
  }
  readonly property string tool: Qt.resolvedUrl("bin/omarchy-notify-store").toString().replace(/^file:\/\//, "")

  function command(args) { return [tool].concat(args) }
  function has(key) {
    for (var i = 0; i < entries.length; ++i) if (entries[i].key === key) return true
    return false
  }
  function absorb(line) {
    var row
    try { row = JSON.parse(line) } catch (e) { return }
    if (!row || !row.key || has(row.key)) return
    entries = [row].concat(entries)
  }
  function markSeen() { lastSeen = Date.now() }
  function remove(key) {
    entries = entries.filter(function(row) { return row.key !== key })
    Quickshell.execDetached(command(["remove", String(key)]))
  }
  function clear() {
    entries = []
    Quickshell.execDetached(command(["clear"]))
  }

  Process {
    id: watcher
    command: root.command(["watch"])
    running: true
    stdout: SplitParser { onRead: function(line) { root.absorb(line) } }
  }
  Process {
    id: loader
    command: root.command(["list"])
    running: true
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          var data = JSON.parse(text)
          if (Array.isArray(data)) { root.entries = data; root.loaded = true }
        } catch (e) {}
      }
    }
  }
}
