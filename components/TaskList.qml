pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import qs.Commons
import qs.Ui
import "../CalendarModel.js" as Model

Item {
  id: root

  // Rows from Model.taskRows: group headers followed by their tasks.
  property var rows: []
  property string selectedTaskId: ""
  property date today: new Date()
  property bool busy: false
  property bool actionsEnabled: true
  property color foreground: Color.foreground
  property string fontFamily: Style.font.family

  signal completeRequested(var task)
  signal taskClicked(var task)

  readonly property int rowHeight: Style.space(44)
  readonly property int headerHeight: Style.space(26)
  readonly property int taskCount: rows.filter(function(row) { return row.kind === "task" }).length

  function positionAtSelected() {
    for (var index = 0; index < rows.length; index++) {
      if (rows[index].kind === "task" && String(rows[index].task.id) === selectedTaskId) {
        taskList.positionViewAtIndex(index, ListView.Contain)
        return
      }
    }
  }

  onSelectedTaskIdChanged: Qt.callLater(positionAtSelected)

  Text {
    textFormat: Text.PlainText
    id: emptyLabel
    visible: root.taskCount === 0
    anchors.centerIn: parent
    text: "No open tasks"
    color: Qt.darker(root.foreground, 1.45)
    font.family: root.fontFamily
    font.pixelSize: Style.font.body
  }

  ListView {
    id: taskList
    anchors.fill: parent
    visible: root.taskCount > 0
    model: root.rows
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    interactive: contentHeight > height
    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

    delegate: Item {
      id: row
      required property var modelData
      required property int index
      readonly property bool header: modelData.kind === "header"
      readonly property var task: header ? null : modelData.task
      readonly property bool selected: !header && String(task.id) === root.selectedTaskId
      readonly property bool overdue: modelData.group === "overdue"
      width: ListView.view.width
      height: header ? root.headerHeight : root.rowHeight

      Text {
        textFormat: Text.PlainText
        visible: row.header
        anchors.left: parent.left
        anchors.leftMargin: Style.space(2)
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Style.space(4)
        text: row.header ? row.modelData.label + " · " + row.modelData.count : ""
        color: row.modelData.key === "overdue" ? Color.urgent : Qt.darker(root.foreground, 1.4)
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        font.bold: true
        font.letterSpacing: 1
      }

      Rectangle {
        visible: !row.header
        anchors.fill: parent
        radius: Style.cornerRadius
        color: row.selected
          ? Style.selectedFillFor(root.foreground, Color.accent)
          : rowMouse.containsMouse
            ? Style.hoverFillFor(root.foreground, Color.accent)
            : "transparent"

        Accessible.role: Accessible.Button
        Accessible.name: row.header ? "" : String(row.task.title || "Untitled task")

        Rectangle {
          anchors.left: parent.left
          anchors.leftMargin: Style.space(2)
          anchors.verticalCenter: parent.verticalCenter
          width: Style.space(3)
          height: parent.height - Style.space(12)
          radius: width / 2
          color: row.header ? "transparent" : (row.modelData.color || Color.accent)
        }

        PanelActionButton {
          id: completeButton
          anchors.left: parent.left
          anchors.leftMargin: Style.space(8)
          anchors.verticalCenter: parent.verticalCenter
          iconText: "󰄱"
          tooltipText: row.modelData.readOnly ? "This list is read-only" : "Mark complete"
          foreground: root.foreground
          focusable: true
          enabled: root.actionsEnabled && !root.busy && !row.header && !row.modelData.readOnly
          onClicked: root.completeRequested(row.task)
        }

        Column {
          anchors.left: completeButton.right
          anchors.leftMargin: Style.space(6)
          anchors.right: parent.right
          anchors.rightMargin: Style.space(8)
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.space(1)

          Text {
            textFormat: Text.PlainText
            width: parent.width
            text: row.header ? "" : String(row.task.title || "Untitled task")
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
            font.bold: row.selected
            elide: Text.ElideRight
          }

          Text {
            textFormat: Text.PlainText
            width: parent.width
            visible: text !== ""
            text: {
              if (row.header) return ""
              var values = [Model.taskDueLabel(row.task, root.today, Qt.locale())]
              if (row.task.dirty) values.push("Syncing")
              return values.filter(function(value) { return value !== "" }).join(" · ")
            }
            color: row.overdue ? Color.urgent : Qt.darker(root.foreground, 1.4)
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            elide: Text.ElideRight
          }
        }

        MouseArea {
          id: rowMouse
          anchors.left: completeButton.right
          anchors.right: parent.right
          anchors.top: parent.top
          anchors.bottom: parent.bottom
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: root.taskClicked(row.task)
        }
      }
    }
  }
}
