pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Commons
import "../.." as Oma

ShellRoot {
  id: root

  readonly property string socketPath: Quickshell.env("OMACALENDAR_PREVIEW_SOCKET")
  readonly property string screenName: Quickshell.env("OMACALENDAR_PREVIEW_SCREEN")
  readonly property var previewScreen: {
    for (var index = 0; index < Quickshell.screens.length; index++) {
      if (Quickshell.screens[index].name === screenName) return Quickshell.screens[index]
    }
    return null
  }
  property int attempts: 0

  component PreviewBar: QtObject {
    property string position: "top"
    property bool vertical: false
    property int barSize: 40
    property color foreground: "#c9d1d9"
    property color barForeground: foreground
    property color urgent: "#f7768e"
    property string fontFamily: "Noto Sans"
    property bool foregroundAnimationEnabled: false
    property var activePopout: null
    property bool centerHoverRevealSuppressed: false
    property var clickTargets: []

    function registerClickTarget(target) {
      if (clickTargets.indexOf(target) === -1) clickTargets = clickTargets.concat([target])
    }
    function unregisterClickTarget(target) {
      clickTargets = clickTargets.filter(function(item) { return item !== target })
    }
    function showTooltip(target, text) {}
    function hideTooltip(target) {}
    function moduleWidgets(moduleName) { return [] }
    function requestPopout(owner) { activePopout = owner }
    function releasePopout(owner) { if (activePopout === owner) activePopout = null }
    function switchPanelFrom(owner, direction) { return false }
  }

  PreviewBar { id: previewBar }

  // Quickshell exposes PanelWindow at runtime through its Wayland backend;
  // the static QML type description marks the backend-provided type abstract.
  // qmllint disable uncreatable-type
  PanelWindow {
    id: hostWindow
    screen: root.previewScreen
    visible: true
    color: "#0b0f14"
    implicitHeight: 40
    anchors {
      top: true
      left: true
      right: true
    }

    Item {
      id: anchor
      x: 380
      y: 0
      width: 40
      height: 40
    }

    Oma.Panel {
      id: calendarPanel
      bar: previewBar
      anchorItem: anchor
      settings: ({
        weekStart: 1,
        refreshSeconds: 60,
        socketPath: root.socketPath
      })
    }
  }
  // qmllint enable uncreatable-type

  function fail(message) {
    console.error("PREVIEW_CAPTURE_FAIL: " + message)
    Qt.quit()
  }

  function applyFixtureTheme() {
    // Color.qml reads the installed user's theme path by design. Re-apply the
    // stock fallback palette and empty shell overrides inside this synthetic
    // harness so the committed capture does not depend on workstation state.
    Color.foreground = "#cacccc"
    Color.background = "#101315"
    Color.accent = "#7aa2f7"
    Color.urgent = "#a55555"
    Color.muted = "#707880"
    Color.loadShell("")
    Color.loadUserShell("")
  }

  Component.onCompleted: {
    applyFixtureTheme()
    calendarPanel.today = new Date(2026, 7, 31, 10, 15, 0, 0)
    calendarPanel.selectedDate = new Date(2026, 7, 31, 12, 0, 0, 0)
    calendarPanel.viewYear = 2026
    calendarPanel.viewMonth = 7
    calendarPanel.viewMode = "month"
    calendarPanel.open()
  }

  Timer {
    interval: 100
    repeat: true
    running: true
    onTriggered: {
      root.attempts++
      if (!calendarPanel.client || calendarPanel.client.connectionState !== "ready"
          || Number(calendarPanel.snapshot.revision || 0) < 1 || !calendarPanel.opened) {
        if (root.attempts >= 100) root.fail(
          "widget did not become ready (state="
          + (calendarPanel.client ? calendarPanel.client.connectionState : "no-client")
          + ", detail=" + (calendarPanel.client ? calendarPanel.client.stateDetail : "")
          + ", socket=" + (calendarPanel.client ? calendarPanel.client.socketPath : "")
          + ", revision=" + Number(calendarPanel.snapshot.revision || 0)
          + ", opened=" + calendarPanel.opened + ")")
        return
      }

      // Give bindings and the opening animation two more render cycles after
      // the synthetic snapshot reaches the real Panel.qml instance.
      running = false
      root.applyFixtureTheme()
      settleTimer.start()
    }
  }

  Timer {
    id: settleTimer
    interval: 300
    onTriggered: {
      root.applyFixtureTheme()
      console.log("PREVIEW_RENDER_READY")
    }
  }
}
