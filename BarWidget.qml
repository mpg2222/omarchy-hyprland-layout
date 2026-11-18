import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "io.github.aishag80g-stack.hyprland-layout"

  readonly property string pluginsDir: Quickshell.env("HOME") + "/.config/omarchy/plugins/"
  readonly property string cli: pluginsDir + root.moduleName + "/bin/omarchy-hyprland-layout"
  // Look'n'Feel lives in this menu instead of its own bar icon. Its panel is
  // loaded from its own plugin folder when that plugin is installed.
  readonly property string lookFeelQml: "file://" + pluginsDir + "meperdonas.looknfeel/Panel.qml"

  property bool popupOpen: false
  property string layoutName: ""
  property var workspaceRows: []
  property string barHeight: ""
  property var displays: []      // live screens from `displays`
  property var draft: []         // arrangement being edited
  property bool draftDirty: false

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  function saveLayout() {
    var name = layoutName.trim()
    if (!/^[A-Za-z0-9._-]+$/.test(name)) {
      notify("Use letters, numbers, dot, dash, or underscore for the layout name.")
      return
    }
    saveProc.command = [cli, "save", name]
    saveProc.running = true
    popupOpen = false
  }

  function refreshAll() {
    workspaceRows = []
    if (!workspacesProc.running) workspacesProc.running = true
    if (!barHeightProc.running) barHeightProc.running = true
    if (!displaysProc.running) displaysProc.running = true
  }

  function restoreWorkspace(id) {
    restoreWorkspaceProc.command = [cli, "restore-last", "--workspace", String(id)]
    restoreWorkspaceProc.running = true
    popupOpen = false
  }

  function barCommand(args) {
    if (barProc.running) return
    barProc.command = [cli, "bar"].concat(args)
    barProc.running = true
  }

  function notify(message) {
    notifyProc.command = ["omarchy-notification-send", "-g", "󱂬", message]
    notifyProc.running = true
  }

  function openLookFeel() {
    if (!lookFeel.item) { notify("Look'n'Feel plugin is not installed."); return }
    popupOpen = false
    lookFeel.item.toggle()
    if (lookFeel.item.opened && typeof lookFeel.item.refresh === "function") lookFeel.item.refresh()
  }

  // ------------------------------------------------------------ displays
  function screenLabel(d) {
    if (d.internal) return "Laptop"
    var parts = String(d.desc).split(" ")
    if (parts.length < 2) return d.name
    var serial = parts[parts.length - 1]
    return parts[parts.length - 2] + " …" + serial.slice(-4)
  }

  function copyScreens(list) {
    var out = []
    for (var i = 0; i < list.length; i++) {
      var d = list[i]
      out.push({ name: d.name, desc: d.desc, x: d.x, y: d.y, w: d.w, h: d.h,
                 scale: d.scale, transform: d.transform, internal: d.internal })
    }
    return out
  }

  // Snap a dragged screen's edges/centre to the other screens' edges.
  function snapAxis(pos, size, others, key, sizeKey, threshold) {
    var best = pos, bestDist = threshold
    for (var i = 0; i < others.length; i++) {
      var o = others[i]
      var lo = o[key], hi = o[key] + o[sizeKey]
      var cands = [lo, hi, lo - size, hi - size, lo + (o[sizeKey] - size) / 2]
      for (var c = 0; c < cands.length; c++) {
        var dist = Math.abs(cands[c] - pos)
        if (dist < bestDist) { bestDist = dist; best = cands[c] }
      }
    }
    return Math.round(best)
  }

  function moveScreen(index, lx, ly) {
    var next = copyScreens(draft)
    var me = next[index]
    var others = next.filter(function(_, i) { return i !== index })
    var threshold = Math.max(me.w, me.h) * 0.12
    me.x = snapAxis(lx, me.w, others, "x", "w", threshold)
    me.y = snapAxis(ly, me.h, others, "y", "h", threshold)
    draft = next
    draftDirty = true
  }

  function applyDisplays() {
    if (applyProc.running || draft.length === 0) return
    var payload = draft.map(function(d) {
      return { desc: d.desc, name: d.name, x: d.x, y: d.y, scale: d.scale, transform: d.transform }
    })
    applyProc.command = [cli, "displays", "apply", JSON.stringify(payload)]
    applyProc.running = true
  }

  // ------------------------------------------------------------ processes
  Process {
    id: restoreProc
    command: [root.cli, "restore-last"]
    onExited: function(exitCode) {
      if (exitCode !== 0) root.notify("Could not restore the last layout.")
    }
  }

  Process {
    id: restoreWorkspaceProc
    onExited: function(exitCode) {
      if (exitCode !== 0) root.notify("Could not restore that desktop.")
    }
  }

  Process {
    id: saveProc
    onExited: function(exitCode) {
      if (exitCode !== 0) root.notify("Could not save the layout.")
      else root.refreshAll()
    }
  }

  Process {
    id: workspacesProc
    command: [root.cli, "workspaces-last"]
    stdout: StdioCollector {
      id: workspacesOut
      onStreamFinished: {
        var rows = []
        var lines = String(workspacesOut.text || "").trim().split("\n")
        for (var i = 0; i < lines.length; i++) {
          var parts = lines[i].split("\t")
          if (parts.length !== 2 || !/^-?\d+$/.test(parts[0]) || !/^\d+$/.test(parts[1])) continue
          rows.push({ id: parts[0], count: parts[1] })
        }
        root.workspaceRows = rows
      }
    }
  }

  Process {
    id: barHeightProc
    command: [root.cli, "bar", "height"]
    stdout: StdioCollector {
      id: barHeightOut
      onStreamFinished: root.barHeight = String(barHeightOut.text || "").trim()
    }
  }

  Process {
    id: barProc
    onExited: function(exitCode) {
      if (exitCode !== 0) root.notify("Could not change the bar size.")
      barHeightProc.running = true
    }
  }

  Process {
    id: displaysProc
    command: [root.cli, "displays"]
    stdout: StdioCollector {
      id: displaysOut
      onStreamFinished: {
        try {
          var list = JSON.parse(String(displaysOut.text || "[]"))
          root.displays = list
          root.draft = root.copyScreens(list)
          root.draftDirty = false
        } catch (e) {
          root.displays = []
          root.draft = []
        }
      }
    }
  }

  Process {
    id: applyProc
    onExited: function(exitCode) {
      root.notify(exitCode === 0 ? "Display arrangement saved." : "Could not arrange the displays.")
      displaysProc.running = true
    }
  }

  Process { id: notifyProc }

  // ------------------------------------------------------------ bar icon
  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󱂬"
    tooltipText: "Restore last layout — right-click for layouts, displays, bar size and look'n'feel"
    onPressed: function(b) {
      if (b === Qt.RightButton) {
        root.popupOpen = !root.popupOpen
        if (root.popupOpen) root.refreshAll()
      } else if (!restoreProc.running) {
        restoreProc.running = true
      }
    }
  }

  // Hidden host for the Look'n'Feel panel: zero width and clipped, so only its
  // popup (its own window) ever shows, anchored at this icon.
  Item {
    x: button.width / 2
    width: 0
    height: button.height
    clip: true
    Loader {
      id: lookFeel
      width: 0
      height: parent.height
      source: root.lookFeelQml
      onLoaded: item.bar = Qt.binding(function() { return root.bar })
    }
  }

  // ------------------------------------------------------------ menu
  PopupCard {
    id: popup
    anchorItem: button
    bar: root.bar
    owner: root
    open: root.popupOpen
    contentWidth: popup.fittedContentWidth(Style.space(360))
    contentHeight: popup.fittedContentHeight(actions.implicitHeight)

    Column {
      id: actions
      anchors.fill: parent
      spacing: Style.space(8)

      Text {
        textFormat: Text.PlainText
        text: "Saved desktop layouts"
        color: root.bar.foreground
        font.family: root.bar.fontFamily
        font.pixelSize: Style.font.subtitle
        font.bold: true
      }

      TextField {
        id: nameField
        width: parent.width
        placeholderText: "Layout name"
        text: root.layoutName
        color: root.bar.foreground
        font.family: root.bar.fontFamily
        font.pixelSize: Style.font.body
        selectByMouse: true
        onTextChanged: root.layoutName = text
        onAccepted: root.saveLayout()
        background: BorderSurface {
          color: "transparent"
          borderSpec: Border.controlSpec("normal", root.bar.foreground, Color.accent)
          radius: Style.cornerRadius
        }
      }

      Button {
        text: "Save desktops, displays and bar size"
        leftAlign: true
        enabled: !saveProc.running
        onClicked: root.saveLayout()
      }

      Button {
        text: "Restore all desktops"
        leftAlign: true
        enabled: !restoreProc.running
        onClicked: {
          root.popupOpen = false
          restoreProc.running = true
        }
      }

      Text {
        textFormat: Text.PlainText
        text: "Restore one desktop"
        color: root.bar.foreground
        font.family: root.bar.fontFamily
        font.pixelSize: Style.font.bodySmall
        visible: root.workspaceRows.length > 0
      }

      Repeater {
        model: root.workspaceRows
        Button {
          required property var modelData
          text: "Desktop " + modelData.id + " (" + modelData.count + " windows)"
          leftAlign: true
          enabled: !restoreWorkspaceProc.running
          onClicked: root.restoreWorkspace(modelData.id)
        }
      }

      Text {
        textFormat: Text.PlainText
        text: "Save a layout first to restore individual desktops."
        color: Qt.darker(root.bar.foreground, 1.4)
        font.family: root.bar.fontFamily
        font.pixelSize: Style.font.bodySmall
        visible: root.workspaceRows.length === 0
      }

      // ---------------------------------------------------- displays
      Text {
        textFormat: Text.PlainText
        text: "Displays — drag to arrange"
        color: root.bar.foreground
        font.family: root.bar.fontFamily
        font.pixelSize: Style.font.subtitle
        font.bold: true
        topPadding: Style.space(6)
      }

      Item {
        id: arranger
        width: parent.width
        height: Style.space(170)
        visible: root.draft.length > 0

        readonly property real minX: { var m = Infinity; for (var i = 0; i < root.draft.length; i++) m = Math.min(m, root.draft[i].x); return isFinite(m) ? m : 0 }
        readonly property real minY: { var m = Infinity; for (var i = 0; i < root.draft.length; i++) m = Math.min(m, root.draft[i].y); return isFinite(m) ? m : 0 }
        readonly property real spanW: { var m = 1; for (var i = 0; i < root.draft.length; i++) m = Math.max(m, root.draft[i].x + root.draft[i].w - minX); return m }
        readonly property real spanH: { var m = 1; for (var i = 0; i < root.draft.length; i++) m = Math.max(m, root.draft[i].y + root.draft[i].h - minY); return m }
        // Leave room around the set so a screen can be dragged to any side.
        readonly property real k: Math.min(width / (spanW * 1.5), height / (spanH * 1.5))
        readonly property real offX: (width - spanW * k) / 2
        readonly property real offY: (height - spanH * k) / 2

        Rectangle {
          anchors.fill: parent
          color: "transparent"
          border.color: Qt.rgba(1, 1, 1, 0.12)
          radius: Style.cornerRadius
        }

        Repeater {
          model: root.draft
          Rectangle {
            id: screenRect
            required property var modelData
            required property int index
            x: arranger.offX + (modelData.x - arranger.minX) * arranger.k
            y: arranger.offY + (modelData.y - arranger.minY) * arranger.k
            width: Math.max(8, modelData.w * arranger.k)
            height: Math.max(8, modelData.h * arranger.k)
            radius: 3
            color: dragArea.drag.active ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(1, 1, 1, 0.10)
            border.color: Color.accent
            border.width: 1

            Text {
              anchors.centerIn: parent
              width: parent.width - 4
              horizontalAlignment: Text.AlignHCenter
              elide: Text.ElideRight
              textFormat: Text.PlainText
              text: root.screenLabel(screenRect.modelData)
              color: root.bar.foreground
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.caption
            }

            MouseArea {
              id: dragArea
              anchors.fill: parent
              cursorShape: Qt.SizeAllCursor
              drag.target: screenRect
              drag.threshold: 2
              onReleased: {
                var lx = (screenRect.x - arranger.offX) / arranger.k + arranger.minX
                var ly = (screenRect.y - arranger.offY) / arranger.k + arranger.minY
                if (Math.abs(lx - screenRect.modelData.x) < 1 && Math.abs(ly - screenRect.modelData.y) < 1) return
                root.moveScreen(screenRect.index, lx, ly)
              }
            }
          }
        }
      }

      Row {
        spacing: Style.space(6)
        visible: root.draft.length > 0
        Button {
          text: applyProc.running ? "Applying…" : "Apply arrangement"
          enabled: root.draftDirty && !applyProc.running
          onClicked: root.applyDisplays()
        }
        Button {
          text: "Undo"
          enabled: root.draftDirty && !applyProc.running
          onClicked: { root.draft = root.copyScreens(root.displays); root.draftDirty = false }
        }
      }

      // ---------------------------------------------------- bar size
      Text {
        textFormat: Text.PlainText
        text: "Top bar size" + (root.barHeight !== "" ? "  ·  " + root.barHeight + " px" : "")
        color: root.bar.foreground
        font.family: root.bar.fontFamily
        font.pixelSize: Style.font.subtitle
        font.bold: true
        topPadding: Style.space(6)
      }

      Row {
        spacing: Style.space(6)
        Button { text: "Smaller"; enabled: !barProc.running; onClicked: root.barCommand(["grow", "-5"]) }
        Button { text: "Larger";  enabled: !barProc.running; onClicked: root.barCommand(["grow", "5"]) }
        Button { text: "Default"; enabled: !barProc.running; onClicked: root.barCommand(["reset"]) }
      }

      // ---------------------------------------------------- look'n'feel
      Button {
        text: "Look'n'Feel (gaps, borders, blur, opacity)…"
        leftAlign: true
        visible: lookFeel.status === Loader.Ready
        onClicked: root.openLookFeel()
      }
    }
  }
}
