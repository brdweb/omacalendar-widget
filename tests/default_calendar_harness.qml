import QtQuick
import Quickshell
import "../components" as Components

ShellRoot {
  FloatingWindow {
    visible: true
    implicitWidth: 480
    implicitHeight: 420

    Components.EventEditor {
      id: editor
      width: 460
      calendars: [
        { id: "first", accountId: "account", name: "First", enabled: true, readOnly: false },
        { id: "preferred", accountId: "account", name: "Preferred", enabled: true, readOnly: false }
      ]
      defaultCalendarId: "preferred"
    }
  }

  Timer {
    interval: 250
    running: true
    onTriggered: {
      editor.reset()
      if (editor.selectedCalendarId !== "preferred") {
        console.error("DEFAULT_CALENDAR_TEST_FAIL: new event did not use the default")
        Qt.quit()
        return
      }
      editor.event = { calendarId: "first", title: "Existing" }
      editor.reset()
      if (editor.selectedCalendarId !== "first") {
        console.error("DEFAULT_CALENDAR_TEST_FAIL: existing event lost its calendar")
        Qt.quit()
        return
      }
      console.log("DEFAULT_CALENDAR_TEST_PASS")
      Qt.quit()
    }
  }
}
