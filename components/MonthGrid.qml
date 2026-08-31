pragma ComponentBehavior: Bound

import QtQuick
import qs.Commons
import qs.Ui
import "../CalendarModel.js" as Model

Item {
  id: root

  property int year: new Date().getFullYear()
  property int month: new Date().getMonth()
  property date today: new Date()
  property date selectedDate: new Date()
  property int weekStart: 1
  property var marks: ({})
  property color foreground: Color.foreground
  property string fontFamily: Style.font.family

  signal dateSelected(date value)
  signal monthRequested(int delta)

  readonly property var cells: Model.monthGrid(year, month, weekStart, today, selectedDate, marks)
  readonly property var weekdays: {
    var values = []
    for (var offset = 0; offset < 7; offset++) values.push((weekStart + offset) % 7)
    return values
  }
  readonly property real cellWidth: Style.space(38)
  readonly property real cellHeight: Style.space(34)
  readonly property real spacing: Style.space(2)

  implicitWidth: cellWidth * 7 + spacing * 6
  implicitHeight: monthHeader.implicitHeight + Style.space(8) + weekdayRow.implicitHeight + Style.space(4) + dayGrid.implicitHeight

  Row {
    id: monthHeader
    width: parent.width

    Button {
      text: "󰅁"
      tooltipText: "Previous month"
      foreground: root.foreground
      focusable: true
      onClicked: root.monthRequested(-1)
    }

    Text {
      width: Math.max(0, parent.width - parent.children[0].implicitWidth - parent.children[2].implicitWidth)
      anchors.verticalCenter: parent.verticalCenter
      horizontalAlignment: Text.AlignHCenter
      text: Qt.formatDate(new Date(root.year, root.month, 1), "MMMM yyyy")
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.title
      font.bold: true
    }

    Button {
      text: "󰅂"
      tooltipText: "Next month"
      foreground: root.foreground
      focusable: true
      onClicked: root.monthRequested(1)
    }
  }

  Row {
    id: weekdayRow
    anchors.top: monthHeader.bottom
    anchors.topMargin: Style.space(8)
    spacing: root.spacing

    Repeater {
      model: root.weekdays

      Text {
        required property int modelData
        width: root.cellWidth
        text: String(Qt.locale("en_US").dayName(modelData === 0 ? 7 : modelData, Locale.NarrowFormat)).toUpperCase()
        horizontalAlignment: Text.AlignHCenter
        color: Qt.darker(root.foreground, 1.45)
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        font.bold: true
      }
    }
  }

  Grid {
    id: dayGrid
    anchors.top: weekdayRow.bottom
    anchors.topMargin: Style.space(4)
    columns: 7
    columnSpacing: root.spacing
    rowSpacing: root.spacing

    Repeater {
      model: root.cells

      Rectangle {
        id: dayCell
        required property var modelData
        width: root.cellWidth
        height: root.cellHeight
        radius: Style.cornerRadius
        color: modelData.selected
          ? Style.selectedFillFor(root.foreground, Color.accent)
          : dayMouse.containsMouse
            ? Style.hoverFillFor(root.foreground, Color.accent)
            : "transparent"
        border.width: modelData.today ? Math.max(1, Style.normalBorderWidth) : 0
        border.color: Color.accent
        opacity: modelData.inMonth ? 1 : 0.42

        Accessible.role: Accessible.Button
        Accessible.name: Qt.formatDate(modelData.date, "dddd, MMMM d, yyyy")
          + (modelData.eventCount ? ", " + modelData.eventCount + " event" + (modelData.eventCount === 1 ? "" : "s") : "")

        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          anchors.verticalCenter: parent.verticalCenter
          anchors.verticalCenterOffset: dayCell.modelData.eventCount ? -Style.space(3) : 0
          text: dayCell.modelData.day
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          font.bold: dayCell.modelData.today || dayCell.modelData.selected
        }

        Row {
          visible: dayCell.modelData.eventCount > 0
          anchors.horizontalCenter: parent.horizontalCenter
          anchors.bottom: parent.bottom
          anchors.bottomMargin: Style.space(4)
          spacing: Style.space(2)

          Repeater {
            model: Math.min(3, dayCell.modelData.eventCount)
            Rectangle {
              width: Style.space(3)
              height: width
              radius: width / 2
              color: Color.accent
            }
          }
        }

        MouseArea {
          id: dayMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: root.dateSelected(dayCell.modelData.date)
        }
      }
    }
  }
}
