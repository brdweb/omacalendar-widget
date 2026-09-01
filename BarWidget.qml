pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Commons
import qs.Ui
import "CalendarModel.js" as Model

BarWidget {
  id: root
  moduleName: "org.omacalendar.widget"

  property date now: new Date()
  readonly property string privacy: String(setting("barPrivacy", "full"))
  readonly property string configuredFormat: vertical
    ? String(setting("verticalFormat", "HH\n—\nmm"))
    : String(setting("format", "ddd HH:mm"))
  readonly property bool showUpNext: setting("showUpNext", true) === true
  readonly property bool showCountdown: setting("showCountdown", true) === true
  readonly property var client: panelLoader.item ? panelLoader.item.client : null
  readonly property var rawUpNext: client && client.snapshot ? client.snapshot.upNext : null
  readonly property var upNext: Model.hasEvent(rawUpNext) ? rawUpNext : null
  readonly property string timeText: Qt.formatDateTime(now, configuredFormat)
  readonly property string eventTitle: privacy === "hidden" || !upNext ? "" : Model.eventTitle(upNext)
  readonly property string countdown: showCountdown && upNext ? Model.upNextLabel(upNext, now) : ""
  readonly property string meetingUrl: Model.meetingUrl(upNext)
  readonly property string horizontalText: {
    var values = [timeText]
    if (showUpNext && eventTitle) values.push(eventTitle)
    if (showUpNext && countdown) values.push(countdown)
    return values.join("  ·  ")
  }
  readonly property var verticalLines: timeText.split("\n")

  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false
  readonly property real openPanelIndicatorWidth: button.labelWidth
  readonly property real openPanelIndicatorHeight: Math.max(Style.space(10), Math.round(Style.bar.iconSlot * 0.55))

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
  }

  function open() { if (panelLoader.item) panelLoader.item.open() }
  function close() { if (panelLoader.item) panelLoader.item.close() }
  function togglePanel() { if (panelLoader.item) panelLoader.item.toggle() }
  function closeForPopoutSwitch() { if (panelLoader.item) panelLoader.item.closeForPopoutSwitch() }
  function refresh() { if (panelLoader.item) panelLoader.item.refresh() }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

  SystemClock {
    id: clock
    precision: SystemClock.Minutes
    onDateChanged: root.now = date
  }

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.vertical ? "" : root.horizontalText
    labelVisible: !root.vertical
    hasVisualContent: root.vertical ? root.verticalLines.length > 0 : text !== ""
    fixedHeight: root.vertical ? root.verticalLines.length * Style.bar.iconSlot : -1
    horizontalMargin: 8.75
    verticalPadding: 8.75
    tooltipText: root.upNext
      ? (root.privacy === "hidden" ? (root.countdown || "Upcoming event") : Model.eventTitle(root.upNext))
      : "Open OmaCalendar"
    active: false
    Accessible.role: Accessible.Button
    Accessible.name: tooltipText

    onPressed: function(button) {
      if (button === Qt.RightButton) Quickshell.execDetached(["xdg-open", "omacalendar://"])
      else if (button === Qt.MiddleButton) root.refresh()
      else root.togglePanel()
    }

    Column {
      visible: root.vertical
      anchors.fill: parent

      Repeater {
        model: root.verticalLines
        OpticalGlyph {
          required property string modelData
          width: button.width
          height: Style.bar.iconSlot
          text: modelData
          fontFamily: button.fontFamily
          fontSize: modelData.length > 3 ? button.fontSize * 0.9 : button.fontSize
          color: button.foreground
        }
      }
    }

    Rectangle {
      visible: !root.vertical && root.meetingUrl !== ""
      anchors.right: parent.right
      anchors.rightMargin: Style.space(4)
      anchors.top: parent.top
      anchors.topMargin: Style.space(4)
      width: Style.space(5)
      height: width
      radius: width / 2
      color: Color.accent
    }
  }
}
