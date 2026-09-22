import QtQuick
import QtTest
import "../CalendarModel.js" as Model

TestCase {
  name: "CalendarModel"

  function test_dateKeyUsesLocalCalendarDate() {
    compare(Model.dateKey(new Date(2026, 7, 28, 23, 30)), "2026-08-28")
    compare(Model.dateKey(null), "")
  }

  function test_monthGridAlwaysContainsSixWeeks() {
    var grid = Model.monthGrid(2026, 7, 1, new Date(2026, 7, 28), new Date(2026, 7, 28), {})
    compare(grid.length, 42)
    compare(grid[0].key, "2026-07-27")
    compare(grid[32].key, "2026-08-28")
    verify(grid[32].today)
    verify(grid[32].selected)
  }

  function test_writableCalendarsExcludeReadOnlySelections() {
    var choices = Model.writableCalendars([
      { id: "writer", writable: true, readOnly: false },
      { id: "reader", writable: false, readOnly: true },
      { id: "legacy-reader", readOnly: true },
      { id: "legacy-writer", readOnly: false }
    ])
    compare(choices.length, 2)
    compare(choices[0].id, "writer")
    compare(choices[1].id, "legacy-writer")
  }

  function test_calendarFilterAndAgendaOrdering() {
    var events = [
      { id: "future-all-day", calendarId: "work", title: "Future holiday", allDay: true,
        startDate: "2026-09-03", endDate: "2026-09-04" },
      { id: "same-day-all-day", calendarId: "work", title: "Tuesday holiday", allDay: true,
        startDate: "2026-09-01", endDate: "2026-09-02" },
      { id: "today-timed", calendarId: "home", title: "Today meeting", allDay: false,
        start: "2026-08-30T17:00:00Z", end: "2026-08-30T18:00:00Z" },
      { id: "same-day-timed", calendarId: "work", title: "Tuesday meeting", allDay: false,
        start: "2026-09-01T13:00:00Z", end: "2026-09-01T14:00:00Z" },
      { id: "already-ended", calendarId: "home", title: "Yesterday", allDay: true,
        startDate: "2026-08-29", endDate: "2026-08-30" }
    ]
    var work = Model.eventsForCalendar(events, "work")
    compare(work.length, 3)
    verify(work.every(function(event) { return event.calendarId === "work" }))
    compare(Model.eventsForCalendar(events, "").length, events.length)

    var timeline = Model.agendaTimelineEvents(events)
    compare(timeline.length, 5)
    compare(timeline[0].id, "already-ended")
    compare(timeline[1].id, "today-timed")
    compare(Model.agendaAnchorIndex(timeline, new Date(2026, 7, 30, 12, 0, 0)), 1)
    verify(Model.agendaTimeLabel(timeline[1], Qt.locale(),
      new Date(2026, 7, 30, 12, 0, 0)).indexOf("Today · ") === 0)

    var agenda = Model.upcomingEvents(events, new Date(2026, 7, 30, 12, 0, 0), 10)
    compare(agenda.length, 4)
    compare(agenda[0].id, "today-timed")
    compare(agenda[1].id, "same-day-all-day")
    compare(agenda[2].id, "same-day-timed")
    compare(agenda[3].id, "future-all-day")
  }

  function test_eventsForDateIncludesCrossMidnightEvents() {
    var events = [
      { id: "overnight", title: "Overnight", start: "2026-08-28T23:00:00", end: "2026-08-29T01:00:00" },
      { id: "other", title: "Other", start: "2026-08-30T10:00:00", end: "2026-08-30T11:00:00" }
    ]
    compare(Model.eventsForDate(events, "2026-08-28").length, 1)
    compare(Model.eventsForDate(events, "2026-08-29")[0].id, "overnight")
  }

  function test_allDayEndDateIsExclusiveForDateSelection() {
    var event = { id: "holiday", allDay: true,
      startDate: "2026-08-28", endDate: "2026-08-30" }
    compare(Model.eventsForDate([event], "2026-08-28").length, 1)
    compare(Model.eventsForDate([event], "2026-08-29").length, 1)
    compare(Model.eventsForDate([event], "2026-08-30").length, 0)
    var noEnd = { id: "one-day", allDay: true, startDate: "2026-08-28" }
    compare(Model.eventsForDate([noEnd], "2026-08-28").length, 1)
    compare(Model.eventsForDate([noEnd], "2026-08-29").length, 0)
  }

  function test_allDayEqualStartAndEndDateIsOneDay() {
    // Some subscribed sources (e.g. a sports schedule feed) report a
    // single-day all-day event with startDate === endDate instead of this
    // app's own exclusive next-day endDate. It must still resolve to one day.
    var event = { id: "game", allDay: true,
      startDate: "2026-09-26", endDate: "2026-09-26" }
    compare(Model.eventsForDate([event], "2026-09-26").length, 1)
    compare(Model.eventsForDate([event], "2026-09-25").length, 0)
    compare(Model.eventsForDate([event], "2026-09-27").length, 0)
  }

  function test_invalidDateOnlyValuesAreRejected() {
    verify(Model.parseDate("2026-02-30") === null)
    verify(Model.parseDate("2026-13-01") === null)
    verify(Model.parseDate("2025-02-29") === null)
    compare(Model.dateKey(Model.parseDate("2024-02-29")), "2024-02-29")
  }

  function test_allDayEndDateIsExclusiveForMarks() {
    var marks = Model.eventMarks([
      { allDay: true, startDate: "2026-08-28", endDate: "2026-08-30" }
    ])
    compare(marks["2026-08-28"], 1)
    compare(marks["2026-08-29"], 1)
    verify(marks["2026-08-30"] === undefined)
  }

  function test_timelineLayoutShrinksOverlapsAndSeparatesDays() {
    var layout = Model.timelineLayout([
      { id: "one", start: "2026-08-30T09:00:00-04:00", end: "2026-08-30T11:00:00-04:00" },
      { id: "two", start: "2026-08-30T09:30:00-04:00", end: "2026-08-30T10:30:00-04:00" },
      { id: "three", start: "2026-08-30T10:00:00-04:00", end: "2026-08-30T12:00:00-04:00" },
      { id: "later", start: "2026-08-30T14:00:00-04:00", end: "2026-08-30T15:00:00-04:00" },
      { id: "tuesday", start: "2026-09-01T13:00:00-04:00", end: "2026-09-01T14:00:00-04:00" }
    ], new Date(2026, 7, 30, 12, 0, 0), 7)
    compare(layout.length, 5)
    compare(layout[0].columns, 3)
    compare(layout[1].columns, 3)
    compare(layout[2].columns, 3)
    compare(layout[3].columns, 1)
    compare(layout[4].dayIndex, 2)
  }

  function test_timelineUsesWallClockMinutes() {
    compare(Model.wallClockMinutes(new Date(2026, 2, 8, 3, 15, 30)), 195.5)
    compare(Model.wallClockMinutes(new Date(2026, 10, 1, 2, 45, 0)), 165)
  }

  function test_searchCoversPresentationFields() {
    var events = [
      { title: "Design review", location: "Studio", attendees: [{ email: "person@example.test" }] },
      { title: "Lunch", location: "Cafe" }
    ]
    compare(Model.filteredEvents(events, "studio").length, 1)
    compare(Model.filteredEvents(events, "person@example").length, 1)
    compare(Model.filteredEvents(events, "missing").length, 0)
  }

  function test_searchAndColorsIgnoreMalformedDtoEntries() {
    var events = [null, "bad", { title: "Valid", attendees: [null, "bad", { email: "safe@example.test" }] }]
    compare(Model.filteredEvents(events, "safe@example").length, 1)
    compare(Model.filteredEvents(events, "valid").length, 1)
    compare(Model.calendarColor({ calendarId: "missing" }, [null, "bad", {}], "fallback"), "fallback")
  }

  function test_meetingUrlPrefersPresentationField() {
    compare(Model.meetingUrl({ meetingUrl: "https://meet.example.test/room" }), "https://meet.example.test/room")
    compare(Model.meetingUrl({ description: "Join https://video.example.test/abc)." }), "https://video.example.test/abc")
    compare(Model.meetingUrl({ meetingUrl: "javascript:alert(1)" }), "")
    compare(Model.meetingUrl({ meetingUrl: "https://user:secret@meet.example.test/room" }), "")
    compare(Model.meetingUrl({ meetingUrl: "https://meet.example.test/room\nnext" }), "")
    compare(Model.meetingUrl({ meetingUrl: "https:///missing-host" }), "")
  }

  function test_emptySnapshotEventIsNotPresentedAsAnEvent() {
    verify(!Model.hasEvent(null))
    verify(!Model.hasEvent({}))
    verify(!Model.hasEvent({ id: "" }))
    verify(Model.hasEvent({ id: "event-1" }))
  }

  function test_findEventByIdentityReconcilesRecurringOccurrences() {
    var events = [
      { id: "series", recurrenceId: "first", title: "Updated first" },
      { id: "series", recurrenceId: "second", title: "Updated second" }
    ]
    compare(Model.findEventByIdentity(events, { id: "series", recurrenceId: "second" }).title,
      "Updated second")
    verify(Model.findEventByIdentity(events, { id: "deleted", recurrenceId: "first" }) === null)
    verify(Model.findEventByIdentity([null, "bad"], { id: "series" }) === null)
  }

  function test_upNextLabels() {
    var now = new Date("2026-08-28T12:00:00Z")
    compare(Model.upNextLabel({ start: "2026-08-28T12:30:00Z", end: "2026-08-28T13:00:00Z" }, now), "in 30m")
    compare(Model.upNextLabel({ start: "2026-08-28T11:30:00Z", end: "2026-08-28T12:30:00Z" }, now), "Now")
    compare(Model.upNextLabel(null, now), "No upcoming events")
  }

  function test_currentEventSelectsTheSoonestEndingActiveEvent() {
    var now = new Date("2026-08-28T12:00:00Z")
    var current = Model.currentEvent([
      { id: "later", start: "2026-08-28T11:00:00Z", end: "2026-08-28T13:30:00Z" },
      { id: "first", start: "2026-08-28T11:30:00Z", end: "2026-08-28T12:30:00Z" },
      { id: "future", start: "2026-08-28T13:00:00Z", end: "2026-08-28T14:00:00Z" }
    ], now)
    compare(current.id, "first")
  }

  function test_syncSummaryFindsNestedProviderStates() {
    var summary = Model.syncSummary({
      google: { accounts: { a: { state: "reauthorization_required", errorMessage: "Sign in again" } } },
      caldav: { accounts: { b: { state: "syncing" } } },
      ics: { subscriptions: [{ state: "stale", stale: true }] }
    })
    verify(summary.authRequired)
    verify(summary.syncing)
    verify(summary.stale)
    compare(summary.message, "Sign in again")
  }
}
