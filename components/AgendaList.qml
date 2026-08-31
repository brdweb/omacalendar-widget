pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import qs.Commons
import qs.Ui
import "../CalendarModel.js" as Model

Item {
  id: root

  property var events: []
  property var calendars: []
  property int selectedIndex: -1
  property color foreground: Color.foreground
  property string fontFamily: Style.font.family
  property bool showDate: false
  property bool active: false
  property int anchorIndex: -1
  property string anchorToken: ""
  property bool autoPositionEnabled: true
  property alias contentY: eventList.contentY

  signal eventClicked(int index, var event)
  signal joinClicked(var event)

  readonly property int rowHeight: Style.space(48)
  readonly property real scrollPosition: eventList.contentY
  readonly property real viewportHeight: eventList.height
  readonly property real timelineContentHeight: eventList.contentHeight
  readonly property int timelineCount: eventList.count
  implicitHeight: Math.max(emptyLabel.implicitHeight, Math.min(8, events.length) * rowHeight)

  function positionAtAnchor() {
    if (!active || !autoPositionEnabled || anchorIndex < 0 || events.length === 0) return
    Qt.callLater(function() {
      if (!root.active || !root.autoPositionEnabled) return
      eventList.positionViewAtIndex(root.anchorIndex, ListView.Beginning)
    })
  }

  onEventsChanged: positionAtAnchor()
  onAnchorIndexChanged: positionAtAnchor()
  onAnchorTokenChanged: {
    autoPositionEnabled = true
    positionAtAnchor()
  }
  onActiveChanged: {
    if (active) {
      autoPositionEnabled = true
      positionAtAnchor()
    }
  }
  Component.onCompleted: positionAtAnchor()

  Text {
    id: emptyLabel
    visible: root.events.length === 0
    anchors.centerIn: parent
    text: "Nothing scheduled"
    color: Qt.darker(root.foreground, 1.45)
    font.family: root.fontFamily
    font.pixelSize: Style.font.body
  }

  ListView {
    id: eventList
    anchors.fill: parent
    visible: root.events.length > 0
    model: root.events
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    interactive: contentHeight > height
    onContentHeightChanged: root.positionAtAnchor()
    onCountChanged: root.positionAtAnchor()
    onHeightChanged: root.positionAtAnchor()
    onMovementStarted: root.autoPositionEnabled = false
    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

    delegate: Rectangle {
      id: eventRow
      required property var modelData
      required property int index
      width: ListView.view.width
      height: root.rowHeight
      radius: Style.cornerRadius
      color: index === root.selectedIndex
        ? Style.selectedFillFor(root.foreground, Color.accent)
        : rowMouse.containsMouse
          ? Style.hoverFillFor(root.foreground, Color.accent)
          : "transparent"

      Accessible.role: Accessible.Button
      Accessible.name: Model.eventTitle(modelData) + ", " + Model.timeLabel(modelData, Qt.locale())

      Rectangle {
        anchors.left: parent.left
        anchors.leftMargin: Style.space(2)
        anchors.verticalCenter: parent.verticalCenter
        width: Style.space(3)
        height: parent.height - Style.space(12)
        radius: width / 2
        color: Model.calendarColor(eventRow.modelData, root.calendars, Color.accent)
      }

      Column {
        anchors.left: parent.left
        anchors.leftMargin: Style.space(12)
        anchors.right: joinButton.visible ? joinButton.left : parent.right
        anchors.rightMargin: Style.space(8)
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(1)

        Text {
          width: parent.width
          text: Model.eventTitle(eventRow.modelData)
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          font.bold: eventRow.index === root.selectedIndex
          elide: Text.ElideRight
        }

        Text {
          width: parent.width
          text: {
            var label = root.showDate
              ? Model.agendaTimeLabel(eventRow.modelData, Qt.locale(), new Date())
              : Model.timeLabel(eventRow.modelData, Qt.locale())
            var values = [label]
            if (eventRow.modelData.location) values.push(String(eventRow.modelData.location))
            if (eventRow.modelData.pending) values.push("Pending")
            else if (eventRow.modelData.failed) values.push("Failed")
            return values.filter(function(value) { return value !== "" }).join(" · ")
          }
          color: eventRow.modelData.failed ? Color.urgent : Qt.darker(root.foreground, 1.4)
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
          elide: Text.ElideRight
        }
      }

      PanelActionButton {
        id: joinButton
        visible: Model.meetingUrl(eventRow.modelData) !== ""
        anchors.right: parent.right
        anchors.rightMargin: Style.space(4)
        anchors.verticalCenter: parent.verticalCenter
        iconText: "󰍉"
        tooltipText: "Join meeting"
        foreground: root.foreground
        focusable: true
        onClicked: root.joinClicked(eventRow.modelData)
      }

      MouseArea {
        id: rowMouse
        anchors.left: parent.left
        anchors.right: joinButton.visible ? joinButton.left : parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.eventClicked(eventRow.index, eventRow.modelData)
      }
    }
  }
}
