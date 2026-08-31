import QtQuick
import Quickshell
import "../components" as Components

ShellRoot {
  id: root
  property int phase: 0
  property int anchorRevision: 0

  FloatingWindow {
    visible: true
    implicitWidth: 360
    implicitHeight: 160

    Components.AgendaList {
      id: agenda
      width: 360
      height: 160
      active: true
      showDate: true
      anchorIndex: 4
      anchorToken: "2026-08-30|" + root.anchorRevision
      events: [
        { id: "past-1", title: "Past one", start: "2026-08-28T09:00:00Z", end: "2026-08-28T10:00:00Z" },
        { id: "past-2", title: "Past two", start: "2026-08-29T09:00:00Z", end: "2026-08-29T10:00:00Z" },
        { id: "past-3", title: "Past three", start: "2026-08-29T11:00:00Z", end: "2026-08-29T12:00:00Z" },
        { id: "past-4", title: "Past four", start: "2026-08-29T13:00:00Z", end: "2026-08-29T14:00:00Z" },
        { id: "today", title: "Today", start: "2026-08-30T09:00:00Z", end: "2026-08-30T10:00:00Z" },
        { id: "future-1", title: "Future one", start: "2026-08-31T09:00:00Z", end: "2026-08-31T10:00:00Z" },
        { id: "future-2", title: "Future two", start: "2026-09-01T09:00:00Z", end: "2026-09-01T10:00:00Z" },
        { id: "future-3", title: "Future three", start: "2026-09-02T09:00:00Z", end: "2026-09-02T10:00:00Z" }
      ]
    }
  }

  Timer {
    interval: 200
    running: true
    repeat: true
    onTriggered: {
      var expected = agenda.anchorIndex * agenda.rowHeight
      if (root.phase === 1) {
        if (agenda.scrollPosition !== expected) {
          console.error("AGENDA_TEST_FAIL: Today did not re-center the agenda; actual="
            + agenda.scrollPosition + " expected=" + expected)
          Qt.quit()
          return
        }
        console.log("AGENDA_TEST_PASS")
        Qt.quit()
        return
      }
      if (agenda.scrollPosition !== expected || agenda.scrollPosition <= 0) {
        console.error("AGENDA_TEST_FAIL: today was not positioned at the top; actual="
          + agenda.scrollPosition + " expected=" + expected
          + " viewport=" + agenda.viewportHeight
          + " content=" + agenda.timelineContentHeight
          + " count=" + agenda.timelineCount
          + " active=" + agenda.active
          + " auto=" + agenda.autoPositionEnabled)
        Qt.quit()
        return
      }
      agenda.autoPositionEnabled = false
      agenda.contentY = 0
      if (agenda.scrollPosition !== 0) {
        console.error("AGENDA_TEST_FAIL: could not scroll into earlier dates")
        Qt.quit()
        return
      }
      agenda.contentY = agenda.rowHeight * 5
      if (agenda.scrollPosition <= expected) {
        console.error("AGENDA_TEST_FAIL: could not scroll into later dates")
        Qt.quit()
        return
      }
      root.phase = 1
      root.anchorRevision++
    }
  }
}
