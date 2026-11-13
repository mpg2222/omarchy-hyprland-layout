import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "io.github.aishag80g-stack.hyprland-layout"

  readonly property string cli: Quickshell.env("HOME") + "/.config/omarchy/plugins/" + root.moduleName + "/bin/omarchy-hyprland-layout"
  property bool popupOpen: false
  property string layoutName: ""
  property var workspaceRows: []

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

  function loadWorkspaces() {
    workspaceRows = []
    if (!workspacesProc.running) workspacesProc.running = true
  }

  function restoreWorkspace(id) {
    restoreWorkspaceProc.command = [cli, "restore-last", "--workspace", String(id)]
    restoreWorkspaceProc.running = true
    popupOpen = false
  }

  function notify(message) {
    notifyProc.command = ["omarchy-notification-send", "-g", "󱂬", message]
    notifyProc.running = true
  }

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
      else root.loadWorkspaces()
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

  Process { id: notifyProc }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󱂬"
    tooltipText: "Restore last layout — right-click for save and desktop options"
    onPressed: function(b) {
      if (b === Qt.RightButton) {
        root.popupOpen = !root.popupOpen
        if (root.popupOpen) root.loadWorkspaces()
      } else if (!restoreProc.running) {
        restoreProc.running = true
      }
    }
  }

  PopupCard {
    id: popup
    anchorItem: button
    bar: root.bar
    owner: root
    open: root.popupOpen
    contentWidth: popup.fittedContentWidth(Style.space(320))
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
        text: "Save all desktops on this monitor"
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
    }
  }
}
