pragma ComponentBehavior: Bound

import QtQuick
import qs.Commons
import qs.Ui
import "../CalendarModel.js" as Model

Item {
  id: root

  property var event: null
  property var calendars: []
  property date selectedDate: new Date()
  property string defaultCalendarId: ""
  property color foreground: Color.foreground
  property int calendarIndex: 0
  property bool allDay: false
  property string guestNotificationPolicy: "none"

  signal saveRequested(var draft, string guestPolicy)
  signal cancelRequested()
  signal openInAppRequested()

  readonly property bool editing: event !== null
  readonly property var writableCalendars: Model.writableCalendars(calendars)
  readonly property var selectedCalendar: writableCalendars.length
    ? writableCalendars[Math.max(0, Math.min(calendarIndex, writableCalendars.length - 1))] : null
  readonly property string selectedCalendarId: String(selectedCalendar && selectedCalendar.id || "")
  readonly property string sourceCalendarId: String(event && event.calendarId || "")

  function calendarAccountId(calendarId) {
    for (var index = 0; index < writableCalendars.length; index++) {
      if (String(writableCalendars[index].id) === String(calendarId))
        return String(writableCalendars[index].accountId || "")
    }
    return ""
  }

  function canSelectCalendar(calendar) {
    if (!editing || String(calendar.id) === sourceCalendarId) return true
    // A compact edit can safely make a same-account move. Cross-account moves
    // have a separate create-then-delete transaction and require desktop
    // confirmation, so do not silently send one from this selector.
    var sourceAccount = calendarAccountId(sourceCalendarId)
    var targetAccount = String(calendar.accountId || "")
    return sourceAccount !== "" && targetAccount !== "" && sourceAccount === targetAccount
  }

  Keys.priority: Keys.BeforeItem
  Keys.onEscapePressed: function(event) {
    root.cancelRequested()
    event.accepted = true
  }

  function formatLocal(date) {
    return Qt.formatDateTime(date, "yyyy-MM-dd HH:mm")
  }

  function parseLocal(value) {
    var match = String(value || "").trim().match(/^(\d{4})-(\d{2})-(\d{2})(?:[ T](\d{2}):(\d{2}))?$/)
    if (!match) return null
    var year = Number(match[1])
    var month = Number(match[2]) - 1
    var day = Number(match[3])
    var hour = Number(match[4] || 0)
    var minute = Number(match[5] || 0)
    var date = new Date(year, month, day, hour, minute, 0, 0)
    if (isNaN(date.getTime()) || date.getFullYear() !== year || date.getMonth() !== month
        || date.getDate() !== day || date.getHours() !== hour || date.getMinutes() !== minute)
      return null
    return date
  }

  function reset() {
    var sourceStart = Model.eventStart(event)
    var start = sourceStart || new Date(selectedDate.getFullYear(), selectedDate.getMonth(), selectedDate.getDate(), new Date().getHours() + 1, 0, 0, 0)
    var sourceEnd = Model.eventEnd(event)
    var end = sourceEnd || new Date(start.getTime() + 3600000)
    titleField.text = event ? String(event.title || event.summary || "") : ""
    locationField.text = event ? String(event.location || "") : ""
    notesField.text = event ? String(event.notes || event.description || "") : ""
    allDay = !!(event && event.allDay)
    startField.text = allDay ? Model.dateKey(start) : formatLocal(start)
    endField.text = allDay ? Model.dateKey(end) : formatLocal(end)
    guestNotificationPolicy = "none"
    calendarIndex = 0
    var sourceCalendar = String(event && event.calendarId || defaultCalendarId || "")
    for (var index = 0; index < writableCalendars.length; index++) {
      if (String(writableCalendars[index].id) === sourceCalendar) calendarIndex = index
    }
    validationLabel.text = ""
    Qt.callLater(function() { titleField.forceActiveFocus() })
  }

  function cycleCalendar() {
    if (writableCalendars.length === 0) return
    for (var offset = 1; offset <= writableCalendars.length; offset++) {
      var next = (calendarIndex + offset) % writableCalendars.length
      if (canSelectCalendar(writableCalendars[next])) {
        calendarIndex = next
        validationLabel.text = ""
        return
      }
    }
    if (editing)
      validationLabel.text = "Cross-account moves require confirmation in the desktop app"
  }

  function cycleGuestPolicy() {
    var policies = ["none", "all", "externalOnly"]
    guestNotificationPolicy = policies[(policies.indexOf(guestNotificationPolicy) + 1) % policies.length]
  }

  function toggleAllDay() {
    var start = parseLocal(startField.text)
    var end = parseLocal(endField.text)
    if (!start) start = new Date(selectedDate.getFullYear(), selectedDate.getMonth(), selectedDate.getDate(), 9, 0, 0, 0)
    if (!end || end <= start) end = new Date(start.getTime() + 3600000)
    allDay = !allDay
    if (allDay) {
      startField.text = Model.dateKey(start)
      var exclusiveEnd = new Date(end.getFullYear(), end.getMonth(), end.getDate(), 12, 0, 0, 0)
      // All-day end dates are exclusive. A timed event wholly within one day
      // must therefore become a one-day all-day event, not an invalid equal
      // start/end date.
      if (Model.dateKey(exclusiveEnd) <= Model.dateKey(start)) exclusiveEnd = Model.addDays(start, 1)
      endField.text = Model.dateKey(exclusiveEnd)
    } else {
      startField.text = formatLocal(new Date(start.getFullYear(), start.getMonth(), start.getDate(), 9, 0, 0, 0))
      endField.text = formatLocal(new Date(start.getFullYear(), start.getMonth(), start.getDate(), 10, 0, 0, 0))
    }
  }

  function submit() {
    var start = parseLocal(startField.text)
    var end = parseLocal(endField.text)
    if (!titleField.text.trim()) {
      validationLabel.text = "A title is required"
      titleField.forceActiveFocus()
      return
    }
    if (!selectedCalendar) {
      validationLabel.text = "No writable calendar is available"
      return
    }
    if (!start || !end || end <= start) {
      validationLabel.text = "Enter a valid end after the start"
      startField.forceActiveFocus()
      return
    }
    var draft = {
      calendarId: String(selectedCalendar.id),
      title: titleField.text.trim(),
      location: locationField.text.trim(),
      notes: notesField.text,
      allDay: allDay
    }
    if (allDay) {
      draft.startDate = Model.dateKey(start)
      draft.endDate = Model.dateKey(end)
    } else {
      draft.start = start.toISOString()
      draft.end = end.toISOString()
      draft.timeMode = "zoned"
    }
    saveRequested(draft, guestNotificationPolicy)
  }

  implicitHeight: editorColumn.implicitHeight

  Column {
    id: editorColumn
    width: parent.width
    spacing: Style.space(7)

    Row {
      width: parent.width

      Text {
        width: parent.width - cancelButton.implicitWidth
        anchors.verticalCenter: parent.verticalCenter
        text: root.editing ? "Edit event" : "New event"
        color: root.foreground
        font.family: Style.font.family
        font.pixelSize: Style.font.title
        font.bold: true
      }

      Button {
        id: cancelButton
        text: "Cancel"
        foreground: root.foreground
        focusable: true
        onClicked: root.cancelRequested()
      }
    }

    TextField {
      id: titleField
      width: parent.width
      placeholderText: "Title"
      foreground: root.foreground
      Accessible.name: "Event title"
      Keys.onEscapePressed: root.cancelRequested()
    }

    TextField {
      id: locationField
      width: parent.width
      placeholderText: "Location or meeting link"
      foreground: root.foreground
      Accessible.name: "Event location"
      Keys.onEscapePressed: root.cancelRequested()
    }

    TextField {
      id: notesField
      width: parent.width
      placeholderText: "Notes"
      foreground: root.foreground
      Accessible.name: "Event notes"
      Keys.onEscapePressed: root.cancelRequested()
    }

    Row {
      width: parent.width
      spacing: Style.space(6)

      Button {
        text: root.allDay ? "All day" : "Timed"
        selected: root.allDay
        foreground: root.foreground
        focusable: true
        onClicked: {
          root.toggleAllDay()
        }
      }

      TextField {
        id: startField
        width: Math.max(Style.space(100), (parent.width - parent.children[0].implicitWidth - parent.spacing * 2) / 2)
        placeholderText: root.allDay ? "YYYY-MM-DD" : "YYYY-MM-DD HH:mm"
        foreground: root.foreground
        Accessible.name: "Event start"
        Keys.onEscapePressed: root.cancelRequested()
      }

      TextField {
        id: endField
        width: startField.width
        placeholderText: root.allDay ? "YYYY-MM-DD" : "YYYY-MM-DD HH:mm"
        foreground: root.foreground
        Accessible.name: "Event end"
        Keys.onEscapePressed: root.cancelRequested()
      }
    }

    Button {
      width: parent.width
      text: root.selectedCalendar ? "Calendar · " + String(root.selectedCalendar.name || "Calendar") : "No writable calendar"
      leftAlign: true
      foreground: root.foreground
      focusable: true
      enabled: root.writableCalendars.length > 0
      onClicked: root.cycleCalendar()
    }

    Text {
      visible: root.editing && root.writableCalendars.some(function(calendar) {
        return String(calendar.id) !== root.sourceCalendarId && !root.canSelectCalendar(calendar)
      })
      width: parent.width
      text: "Cross-account moves require desktop confirmation"
      color: Qt.darker(root.foreground, 1.4)
      font.family: Style.font.family
      font.pixelSize: Style.font.bodySmall
      wrapMode: Text.WordWrap
    }

    Button {
      width: parent.width
      text: "Guest updates · " + (root.guestNotificationPolicy === "none" ? "Do not send" : root.guestNotificationPolicy === "all" ? "Send to all" : "External guests only")
      leftAlign: true
      foreground: root.foreground
      focusable: true
      onClicked: root.cycleGuestPolicy()
    }

    Text {
      id: validationLabel
      width: parent.width
      visible: text !== ""
      color: Color.urgent
      font.family: Style.font.family
      font.pixelSize: Style.font.bodySmall
      wrapMode: Text.WordWrap
    }

    Row {
      width: parent.width
      spacing: Style.space(8)

      Button {
        width: (parent.width - parent.spacing) / 2
        text: root.editing ? "Save" : "Create"
        foreground: root.foreground
        selected: true
        focusable: true
        enabled: root.writableCalendars.length > 0
        onClicked: root.submit()
      }

      Button {
        width: (parent.width - parent.spacing) / 2
        text: "More options in app"
        foreground: root.foreground
        focusable: true
        onClicked: root.openInAppRequested()
      }
    }
  }
}
