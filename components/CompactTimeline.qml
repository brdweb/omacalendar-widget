pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import qs.Commons
import "../CalendarModel.js" as Model

Item {
  id: root

  property date startDate: new Date()
  property int dayCount: 1
  property var events: []
  property var calendars: []
  property color foreground: Color.foreground
  property string fontFamily: Style.font.family
  property real hourHeight: Style.space(42)
  readonly property real gutterWidth: Style.space(42)
  readonly property real dayWidth: Math.max(Style.space(82), (width - gutterWidth) / dayCount)
  readonly property var layoutItems: Model.timelineLayout(events, startDate, dayCount)

  signal eventClicked(var event)

  implicitHeight: Style.space(310)

  function dayAt(index) {
    return Model.addDays(startDate, index)
  }

  function allDayFor(index) {
    return Model.eventsForDate(events, Model.dateKey(dayAt(index))).filter(function(event) {
      return event && event.allDay
    })
  }

  function hasAllDayEvents() {
    for (var index = 0; index < dayCount; index++) {
      if (allDayFor(index).length > 0) return true
    }
    return false
  }

  Row {
    id: dayHeaders
    x: root.gutterWidth
    width: parent.width - x
    height: Style.space(30)

    Repeater {
      model: root.dayCount

      Text {
        required property int index
        width: root.dayWidth
        height: dayHeaders.height
        text: Qt.formatDate(root.dayAt(index), root.dayCount === 1 ? "dddd, MMM d" : "ddd d")
        color: Model.dateKey(root.dayAt(index)) === Model.dateKey(new Date())
          ? Color.accent : root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        font.bold: true
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
      }
    }
  }

  Row {
    id: allDayBand
    x: root.gutterWidth
    anchors.top: dayHeaders.bottom
    width: parent.width - x
    height: root.hasAllDayEvents() ? Style.space(28) : 0
    clip: true

    Repeater {
      model: root.dayCount

      Rectangle {
        required property int index
        readonly property var dayEvents: root.allDayFor(index)
        width: root.dayWidth
        height: allDayBand.height
        color: dayEvents.length > 0
          ? Style.selectedFillFor(root.foreground, Color.accent) : "transparent"
        border.width: dayEvents.length > 0 ? Math.max(1, Style.normalBorderWidth) : 0
        border.color: Color.accent
        radius: Style.cornerRadius

        Text {
          anchors.fill: parent
          anchors.margins: Style.space(4)
          text: parent.dayEvents.length > 0
            ? Model.eventTitle(parent.dayEvents[0])
              + (parent.dayEvents.length > 1 ? " +" + (parent.dayEvents.length - 1) : "")
            : ""
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          elide: Text.ElideRight
          verticalAlignment: Text.AlignVCenter
        }

        MouseArea {
          anchors.fill: parent
          enabled: parent.dayEvents.length > 0
          cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
          onClicked: root.eventClicked(parent.dayEvents[0])
        }
      }
    }
  }

  Flickable {
    id: timelineScroll
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: allDayBand.bottom
    anchors.bottom: parent.bottom
    contentHeight: root.hourHeight * 24
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

    Component.onCompleted: {
      var currentHour = new Date().getHours()
      contentY = Math.max(0, Math.min(contentHeight - height,
        (currentHour - 1) * root.hourHeight))
    }

    Repeater {
      model: 24

      Item {
        id: hourRow
        required property int index
        x: 0
        y: index * root.hourHeight
        width: timelineScroll.width
        height: root.hourHeight

        Text {
          width: root.gutterWidth - Style.space(5)
          text: Qt.formatTime(new Date(2000, 0, 1, hourRow.index, 0), "h ap")
          color: Qt.darker(root.foreground, 1.4)
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          horizontalAlignment: Text.AlignRight
        }

        Rectangle {
          x: root.gutterWidth
          y: 0
          width: parent.width - x
          height: Math.max(1, Style.normalBorderWidth)
          color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.16)
        }
      }
    }

    Repeater {
      model: root.dayCount + 1

      Rectangle {
        required property int index
        x: root.gutterWidth + index * root.dayWidth
        width: Math.max(1, Style.normalBorderWidth)
        height: timelineScroll.contentHeight
        color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.16)
      }
    }

    Repeater {
      model: root.layoutItems

      Rectangle {
        required property var modelData
        readonly property real availableWidth: root.dayWidth - Style.space(4)
        readonly property real eventWidth: availableWidth / Math.max(1, modelData.columns)
        x: root.gutterWidth + modelData.dayIndex * root.dayWidth + Style.space(2)
          + modelData.column * eventWidth
        y: modelData.startMinute / 60 * root.hourHeight + Style.space(1)
        width: Math.max(Style.space(24), eventWidth - Style.space(2))
        height: Math.max(Style.space(22),
          (modelData.endMinute - modelData.startMinute) / 60 * root.hourHeight - Style.space(2))
        radius: Style.cornerRadius
        color: Style.selectedFillFor(root.foreground,
          Model.calendarColor(modelData.event, root.calendars, Color.accent))
        border.width: Math.max(1, Style.normalBorderWidth)
        border.color: Model.calendarColor(modelData.event, root.calendars, Color.accent)
        clip: true

        Text {
          anchors.fill: parent
          anchors.margins: Style.space(4)
          text: Model.eventTitle(parent.modelData.event) + "\n"
            + Model.timeLabel(parent.modelData.event, Qt.locale())
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          font.bold: true
          wrapMode: Text.Wrap
          elide: Text.ElideRight
        }

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: root.eventClicked(parent.modelData.event)
        }
      }
    }
  }
}
