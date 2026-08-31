import QtQuick
import Quickshell
import ".." as Oma

ShellRoot {
  id: root

  component TestBar: QtObject {
    required property string position
    property bool vertical: position === "left" || position === "right"
    property int barSize: 40
    property color foreground: "#eeeeee"
    property color barForeground: foreground
    property color urgent: "#ff5555"
    property string fontFamily: "monospace"
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

  TestBar { id: topBar; position: "top" }
  TestBar { id: bottomBar; position: "bottom" }
  TestBar { id: leftBar; position: "left" }
  TestBar { id: rightBar; position: "right" }

  Item {
    Oma.BarWidget {
      id: topWidget
      bar: topBar
      settings: ({ format: "yyyy", socketPath: "/tmp/omacalendar-widget-layout-no-service" })
    }
    Oma.BarWidget {
      id: bottomWidget
      bar: bottomBar
      settings: ({ socketPath: "/tmp/omacalendar-widget-layout-no-service" })
    }
    Oma.BarWidget {
      id: leftWidget
      bar: leftBar
      settings: ({ socketPath: "/tmp/omacalendar-widget-layout-no-service" })
    }
    Oma.BarWidget {
      id: rightWidget
      bar: rightBar
      settings: ({ socketPath: "/tmp/omacalendar-widget-layout-no-service" })
    }
  }

  function fail(message) {
    console.error("LAYOUT_TEST_FAIL: " + message)
    Qt.quit()
  }

  function widgetButton(widget) {
    for (var index = 0; index < widget.children.length; index++) {
      var child = widget.children[index]
      if (child && typeof child.triggerPress === "function") return child
    }
    return null
  }

  function widgetPanel(widget) {
    for (var index = 0; index < widget.children.length; index++) {
      var child = widget.children[index]
      if (child && child.item && "bodyViewportHeight" in child.item) return child.item
    }
    return null
  }

  Timer {
    interval: 250
    running: true
    onTriggered: {
      var horizontal = [topWidget, bottomWidget]
      var vertical = [leftWidget, rightWidget]
      for (var horizontalIndex = 0; horizontalIndex < horizontal.length; horizontalIndex++) {
        var horizontalWidget = horizontal[horizontalIndex]
        if (horizontalWidget.vertical || horizontalWidget.implicitWidth <= 0
            || horizontalWidget.implicitHeight !== horizontalWidget.bar.barSize) {
          root.fail("top/bottom bar geometry is invalid")
          return
        }
      }
      for (var verticalIndex = 0; verticalIndex < vertical.length; verticalIndex++) {
        var verticalWidget = vertical[verticalIndex]
        if (!verticalWidget.vertical || verticalWidget.implicitWidth !== verticalWidget.bar.barSize
            || verticalWidget.implicitHeight <= 0) {
          root.fail("left/right bar geometry is invalid")
          return
        }
      }

      topWidget.now = new Date(2026, 7, 29, 12, 0, 0)
      if (topWidget.timeText !== "2026") {
        root.fail("inline settings did not update the bar format")
        return
      }

      topWidget.settings = ({ format: "MM", socketPath: "/tmp/omacalendar-widget-layout-no-service" })
      if (topWidget.timeText !== "08") {
        root.fail("live inline-setting reload did not update the bar")
        return
      }

      var topButton = root.widgetButton(topWidget)
      var topPanel = root.widgetPanel(topWidget)
      if (!topPanel || topPanel.bodyViewportHeight <= 0
          || topPanel.bodyContentHeight > topPanel.bodyViewportHeight + 1) {
        root.fail("initial month view clips calendar rows")
        return
      }
      topBar.barForeground = "#11aa44"
      if (!topButton || String(topButton.foreground).toLowerCase() !== "#11aa44") {
        root.fail("live host-theme foreground did not propagate")
        return
      }

      // Simulates moving a live bar to another edge. The widget must switch
      // axis from the host binding without being recreated.
      topBar.position = "left"
      if (!topWidget.vertical || topWidget.implicitWidth !== topBar.barSize) {
        root.fail("live edge change did not update the widget axis")
        return
      }

      console.log("LAYOUT_TEST_PASS")
      Qt.quit()
    }
  }
}
