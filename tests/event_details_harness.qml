import QtQuick
import Quickshell
import "../components" as Components

ShellRoot {
  id: testRoot
  property int saveCount: 0

  FloatingWindow {
    visible: true
    implicitWidth: 480
    implicitHeight: 520

    Components.EventEditor {
      id: editor
      width: 460
      calendars: [
        { id: "writer", accountId: "local", name: "Writable", enabled: true, readOnly: false },
        { id: "reader", accountId: "feed", name: "Subscribed", enabled: true, readOnly: true }
      ]
      event: ({
        id: "read-only-event",
        calendarId: "reader",
        title: "Imported meeting",
        location: "Conference room",
        notes: "Details remain visible",
        start: "2026-09-20T14:00:00.000Z",
        end: "2026-09-20T15:00:00.000Z",
        readOnly: true
      })
      onSaveRequested: testRoot.saveCount++
    }
  }

  Timer {
    interval: 250
    running: true
    onTriggered: {
      editor.reset()
      if (!editor.readOnly || editor.selectedCalendarId !== "reader"
          || !editor.selectedCalendar || editor.selectedCalendar.name !== "Subscribed") {
        console.error("EVENT_DETAILS_TEST_FAIL: read-only source was not preserved")
        Qt.quit()
        return
      }
      editor.submit()
      if (testRoot.saveCount !== 0) {
        console.error("EVENT_DETAILS_TEST_FAIL: read-only event emitted a save")
        Qt.quit()
        return
      }
      console.log("EVENT_DETAILS_TEST_PASS")
      Qt.quit()
    }
  }
}
