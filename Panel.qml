import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "magnushj.modem"
  ipcTarget: "magnushj.modem"
  manageIpc: false

  property var info: ({ present: false })
  property bool toggling: false
  property string lastError: ""

  readonly property string helperPath: String(Qt.resolvedUrl("status.sh")).replace(/^file:\/\//, "")
  readonly property int refreshIntervalSec: Math.max(5, parseInt(String(setting("refreshIntervalSec", 15)), 10) || 15)

  readonly property bool connected: info.present === true && info.state === "connected"
  readonly property bool registered: info.present === true && ["registered", "connected", "connecting"].indexOf(info.state) !== -1
  readonly property int signal: info.signal || 0

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  function techLabel() {
    var tech = info.tech || []
    if (tech.indexOf("5gnr") !== -1) return "5G"
    if (tech.indexOf("lte") !== -1) return "LTE"
    if (tech.indexOf("hspa") !== -1 || tech.indexOf("hspa-plus") !== -1 || tech.indexOf("umts") !== -1) return "3G"
    if (tech.length > 0) return "2G"
    return ""
  }

  function signalGlyph() {
    if (!info.present || info.power !== "on") return "󰞃"
    if (!registered) return "󰢿"
    if (signal >= 60) return "󰢾"
    if (signal >= 30) return "󰢽"
    return "󰢼"
  }

  function stateText() {
    if (!info.present) return "No modem found"
    if (info.power !== "on") return "Radio off"
    if (connected) return "Connected"
    if (info.state === "connecting") return "Connecting…"
    if (info.state === "registered") return "Registered, not connected"
    if (info.state === "searching") return "Searching for network"
    return String(info.state || "Unknown")
  }

  function refresh() {
    if (statusProcess.running) return
    statusProcess.running = true
  }

  function toggleConnection() {
    if (toggling || !info.connection) return
    lastError = ""
    toggling = true
    toggleProcess.command = ["nmcli", "connection", info.connectionActive ? "down" : "up", "id", info.connection]
    toggleProcess.running = true
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  Component.onCompleted: refresh()
  onOpenedChanged: if (opened) refresh()

  Timer {
    interval: (root.opened ? 3 : root.refreshIntervalSec) * 1000
    running: true
    repeat: true
    onTriggered: root.refresh()
  }

  Process {
    id: statusProcess
    command: ["bash", root.helperPath]
    stdout: StdioCollector {
      id: statusOut
      waitForEnd: true
    }
    onExited: function(exitCode) {
      if (exitCode !== 0) return
      try { root.info = JSON.parse(String(statusOut.text || "").trim() || "{}") }
      catch (e) { root.info = { present: false } }
    }
  }

  Process {
    id: toggleProcess
    command: []
    stderr: StdioCollector {
      id: toggleErr
      waitForEnd: true
    }
    onExited: function(exitCode) {
      root.toggling = false
      if (exitCode !== 0) root.lastError = String(toggleErr.text || "nmcli failed").trim().split("\n").pop()
      root.refresh()
    }
  }

  IpcHandler {
    target: root.ipcTarget
    function open(): void { root.open() }
    function close(): void { root.close() }
    function toggle(): void { root.toggle() }
    function refresh(): string { root.refresh(); return "ok" }
    function toggleConnection(): string { root.toggleConnection(); return "ok" }
    function status(): string { return JSON.stringify(root.info) }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.signalGlyph()
    opacity: root.connected ? 1.0 : 0.55
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.RightButton) root.toggleConnection()
      else root.toggle()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(340))
    contentHeight: panel.fittedContentHeight(column.implicitHeight, Style.space(420))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onActivateRequested: root.toggleConnection()
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(t) {
        if (t === "r" || t === "R") root.refresh()
        else if (t === "c" || t === "C") root.toggleConnection()
      }

      Column {
        id: column
        width: parent.width
        spacing: Style.space(12)

        PanelHero {
          id: hero
          width: parent.width
          title: root.info.operator ? root.info.operator + (root.techLabel() ? "  " + root.techLabel() : "") : "Mobile broadband"
          meta: root.stateText()
          foreground: root.foreground
          fontFamily: root.fontFamily
          iconOpacity: root.connected ? 1.0 : 0.5
          iconComponent: Component {
            Text {
              text: root.signalGlyph()
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.display
            }
          }
          trailingControl: Component {
            ToggleSwitch {
              visible: !!root.info.connection
              checked: !!root.info.connectionActive
              busy: root.toggling
              hasCursor: false
              foreground: hero.foreground
              onToggled: root.toggleConnection()
            }
          }
        }

        Text {
          textFormat: Text.PlainText
          visible: root.lastError !== ""
          width: parent.width
          text: root.lastError
          color: root.urgent
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
          wrapMode: Text.WordWrap
        }

        PanelSeparator {
          visible: root.info.present === true
          foreground: root.foreground
        }

        Column {
          visible: root.info.present === true
          width: parent.width
          spacing: Style.spacing.labelGap

          InfoPair { label: "Signal"; value: root.signal + " %" }
          InfoPair { label: "Network"; value: (root.info.tech || []).join(" + ").toUpperCase() || "—" }
          InfoPair { label: "Registration"; value: root.info.registration || "—" }
          InfoPair { label: "Connection"; value: root.info.connection || "None configured" }
          InfoPair { label: "Modem"; value: root.info.model || "—" }
        }
      }
    }
  }

  component InfoPair: Row {
    property string label: ""
    property string value: ""

    width: parent.width
    spacing: Style.space(8)

    Text {
      textFormat: Text.PlainText
      text: label
      color: root.foreground
      opacity: 0.6
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
    }
    Item { width: Math.max(0, parent.width - parent.children[0].implicitWidth - parent.children[2].implicitWidth - parent.spacing * 2); height: 1 }
    Text {
      textFormat: Text.PlainText
      text: value
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
      elide: Text.ElideRight
    }
  }
}
