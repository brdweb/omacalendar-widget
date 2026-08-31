function pad(value) {
  return value < 10 ? "0" + value : String(value)
}

function dateKey(date) {
  if (!(date instanceof Date) || isNaN(date.getTime())) return ""
  return date.getFullYear() + "-" + pad(date.getMonth() + 1) + "-" + pad(date.getDate())
}

function parseDate(value) {
  if (value instanceof Date) return new Date(value.getTime())
  var raw = String(value || "")
  if (/^\d{4}-\d{2}-\d{2}$/.test(raw)) {
    var fields = raw.split("-")
    return new Date(Number(fields[0]), Number(fields[1]) - 1, Number(fields[2]), 12, 0, 0, 0)
  }
  var parsed = new Date(raw)
  return isNaN(parsed.getTime()) ? null : parsed
}

function addDays(date, amount) {
  var result = new Date(date.getFullYear(), date.getMonth(), date.getDate(), 12, 0, 0, 0)
  result.setDate(result.getDate() + amount)
  return result
}

function stepMonth(year, month, delta) {
  var date = new Date(year, month + delta, 1, 12, 0, 0, 0)
  return { year: date.getFullYear(), month: date.getMonth() }
}

function normalizedWeekStart(value, fallback) {
  var numeric = Number(value)
  if (numeric >= 0 && numeric <= 6) return Math.floor(numeric)
  // Qt uses Sunday=0 in JavaScript dates, while Locale firstDayOfWeek uses
  // Sunday=7. Normalize either representation to the JavaScript convention.
  numeric = Number(fallback)
  if (numeric === 7) return 0
  if (numeric >= 1 && numeric <= 6) return Math.floor(numeric)
  return 1
}

function writableCalendars(calendars) {
  var input = Array.isArray(calendars) ? calendars : []
  return input.filter(function(calendar) {
    return calendar && calendar.writable !== false && calendar.readOnly !== true
  })
}

function eventsForCalendar(events, calendarId) {
  var input = Array.isArray(events) ? events : []
  var selected = String(calendarId || "")
  if (!selected) return input.slice()
  return input.filter(function(event) {
    return event && String(event.calendarId || "") === selected
  })
}

function agendaTimelineEvents(events) {
  var result = (Array.isArray(events) ? events : []).filter(function(event) {
    return eventStart(event) !== null
  }).slice()
  result.sort(function(left, right) {
    var leftStart = eventStart(left)
    var rightStart = eventStart(right)
    var leftDay = dateKey(leftStart)
    var rightDay = dateKey(rightStart)
    if (leftDay !== rightDay) return leftDay < rightDay ? -1 : 1
    if (!!left.allDay !== !!right.allDay) return left.allDay ? -1 : 1
    var timeDifference = leftStart.getTime() - rightStart.getTime()
    if (timeDifference !== 0) return timeDifference
    return eventTitle(left).localeCompare(eventTitle(right))
  })
  return result
}

function agendaAnchorIndex(events, selectedDate) {
  var date = selectedDate instanceof Date && !isNaN(selectedDate.getTime())
    ? selectedDate : new Date()
  var key = dateKey(date)
  var input = Array.isArray(events) ? events : []
  for (var index = 0; index < input.length; index++) {
    var start = eventStart(input[index])
    if (start && dateKey(start) >= key) return index
  }
  return input.length ? input.length - 1 : -1
}

function agendaTimeLabel(event, locale, referenceDate) {
  var start = eventStart(event)
  if (!start) return ""
  var reference = referenceDate instanceof Date ? referenceDate : new Date()
  var day = dateKey(start) === dateKey(reference)
    ? "Today" : Qt.formatDate(start, "ddd, MMM d")
  return day + " · " + timeLabel(event, locale)
}

function upcomingEvents(events, selectedDate, limit) {
  var date = selectedDate instanceof Date && !isNaN(selectedDate.getTime())
    ? selectedDate : new Date()
  var cutoff = new Date(date.getFullYear(), date.getMonth(), date.getDate(), 0, 0, 0, 0)
  var cutoffTime = cutoff.getTime()
  var cutoffKey = dateKey(cutoff)
  var result = agendaTimelineEvents(events).filter(function(event) {
    if (event && event.allDay) {
      if (event.endDate) return String(event.endDate).slice(0, 10) > cutoffKey
      return String(event.startDate || "").slice(0, 10) >= cutoffKey
    }
    var start = eventStart(event)
    var end = eventEnd(event)
    if (end) return end.getTime() > cutoffTime
    return start && start.getTime() >= cutoffTime
  })
  var maximum = Math.max(0, Number(limit || result.length))
  return result.slice(0, maximum)
}

function monthGrid(year, month, weekStart, today, selected, marks) {
  var first = new Date(year, month, 1, 12, 0, 0, 0)
  var offset = (first.getDay() - weekStart + 7) % 7
  var cursor = addDays(first, -offset)
  var todayKey = dateKey(today)
  var selectedKey = dateKey(selected)
  var result = []
  for (var index = 0; index < 42; index++) {
    var key = dateKey(cursor)
    result.push({
      date: new Date(cursor.getTime()),
      key: key,
      day: cursor.getDate(),
      inMonth: cursor.getMonth() === month,
      today: key === todayKey,
      selected: key === selectedKey,
      eventCount: marks && marks[key] ? Number(marks[key]) : 0
    })
    cursor = addDays(cursor, 1)
  }
  return result
}

function eventStart(event) {
  if (!event) return null
  if (event.allDay) return parseDate(event.startDate)
  return parseDate(event.start || event.startUtc || event.startDateTime)
}

function eventEnd(event) {
  if (!event) return null
  if (event.allDay) return parseDate(event.endDate)
  return parseDate(event.end || event.endUtc || event.endDateTime)
}

function eventDateKey(event) {
  if (!event) return ""
  if (event.allDay && event.startDate) return String(event.startDate).slice(0, 10)
  return dateKey(eventStart(event))
}

function occursOn(event, key) {
  if (!event || !key) return false
  var day = parseDate(key)
  var start = eventStart(event)
  var end = eventEnd(event)
  if (!day || !start) return false
  var dayStart = new Date(day.getFullYear(), day.getMonth(), day.getDate(), 0, 0, 0, 0)
  var dayEnd = new Date(dayStart.getTime())
  dayEnd.setDate(dayEnd.getDate() + 1)
  if (!end || end.getTime() <= start.getTime()) end = new Date(start.getTime() + 1)
  return start.getTime() < dayEnd.getTime() && end.getTime() > dayStart.getTime()
}

function eventsForDate(events, key) {
  var result = []
  var input = Array.isArray(events) ? events : []
  for (var index = 0; index < input.length; index++) {
    if (occursOn(input[index], key)) result.push(input[index])
  }
  result.sort(function(left, right) {
    if (!!left.allDay !== !!right.allDay) return left.allDay ? -1 : 1
    var leftStart = eventStart(left)
    var rightStart = eventStart(right)
    return (leftStart ? leftStart.getTime() : 0) - (rightStart ? rightStart.getTime() : 0)
  })
  return result
}

function eventMarks(events) {
  var result = {}
  var input = Array.isArray(events) ? events : []
  for (var index = 0; index < input.length; index++) {
    var event = input[index]
    var start = eventStart(event)
    if (!start) continue
    var end = eventEnd(event)
    if (!end || end <= start) end = addDays(start, 1)
    var cursor = new Date(start.getFullYear(), start.getMonth(), start.getDate(), 12, 0, 0, 0)
    var last = new Date(end.getFullYear(), end.getMonth(), end.getDate(), 12, 0, 0, 0)
    // End dates for all-day events are exclusive. Timed events ending after
    // midnight still mark their final day.
    if (event.allDay || (end.getHours() === 0 && end.getMinutes() === 0 && end.getSeconds() === 0))
      last = addDays(last, -1)
    var guard = 0
    while (cursor <= last && guard++ < 370) {
      var key = dateKey(cursor)
      result[key] = (result[key] || 0) + 1
      cursor = addDays(cursor, 1)
    }
  }
  return result
}

function timelineLayout(events, startDate, dayCount) {
  var result = []
  var source = Array.isArray(events) ? events : []
  var count = Math.max(1, Number(dayCount || 1))
  for (var dayIndex = 0; dayIndex < count; dayIndex++) {
    var day = addDays(startDate, dayIndex)
    var key = dateKey(day)
    var timed = []
    for (var index = 0; index < source.length; index++) {
      var event = source[index]
      if (!event || event.allDay || !occursOn(event, key)) continue
      var start = eventStart(event)
      var end = eventEnd(event)
      if (!start) continue
      var dayStart = new Date(day.getFullYear(), day.getMonth(), day.getDate(), 0, 0, 0, 0)
      var dayEnd = addDays(dayStart, 1)
      var clippedStart = Math.max(start.getTime(), dayStart.getTime())
      var clippedEnd = Math.min(end ? end.getTime() : clippedStart + 1800000, dayEnd.getTime())
      timed.push({
        event: event,
        startMinute: (clippedStart - dayStart.getTime()) / 60000,
        endMinute: Math.max((clippedEnd - dayStart.getTime()) / 60000,
                            (clippedStart - dayStart.getTime()) / 60000 + 20)
      })
    }
    timed.sort(function(left, right) {
      return left.startMinute - right.startMinute || right.endMinute - left.endMinute
    })

    var activeEnds = []
    var cluster = []
    function finishCluster() {
      var columns = Math.max(1, activeEnds.length)
      for (var clusterIndex = 0; clusterIndex < cluster.length; clusterIndex++) {
        cluster[clusterIndex].columns = columns
        result.push(cluster[clusterIndex])
      }
      activeEnds = []
      cluster = []
    }

    for (var timedIndex = 0; timedIndex < timed.length; timedIndex++) {
      var item = timed[timedIndex]
      var anyActive = false
      for (var activeIndex = 0; activeIndex < activeEnds.length; activeIndex++) {
        if (activeEnds[activeIndex] > item.startMinute) anyActive = true
      }
      if (!anyActive && cluster.length > 0) finishCluster()
      var column = 0
      while (column < activeEnds.length && activeEnds[column] > item.startMinute) column++
      if (column === activeEnds.length) activeEnds.push(item.endMinute)
      else activeEnds[column] = item.endMinute
      cluster.push({
        event: item.event,
        dayIndex: dayIndex,
        column: column,
        columns: 1,
        startMinute: item.startMinute,
        endMinute: item.endMinute
      })
    }
    if (cluster.length > 0) finishCluster()
  }
  return result
}

function timeLabel(event, locale) {
  if (!event) return ""
  if (event.allDay) return "ALL DAY"
  var start = eventStart(event)
  if (!start) return ""
  return start.toLocaleTimeString(locale || Qt.locale(), Locale.ShortFormat)
}

function durationLabel(milliseconds) {
  if (!isFinite(milliseconds)) return ""
  var minutes = Math.round(milliseconds / 60000)
  if (minutes <= 0) return "now"
  if (minutes < 60) return "in " + minutes + "m"
  var hours = Math.floor(minutes / 60)
  var remainder = minutes % 60
  if (hours < 24) return "in " + hours + "h" + (remainder ? " " + remainder + "m" : "")
  var days = Math.floor(hours / 24)
  return "in " + days + "d"
}

function upNextLabel(event, now) {
  if (!event) return "No upcoming events"
  if (event.allDay) return "All day"
  var start = eventStart(event)
  var end = eventEnd(event)
  var current = now instanceof Date ? now : new Date()
  if (start && end && current >= start && current < end) return "Now"
  return start ? durationLabel(start.getTime() - current.getTime()) : ""
}

function currentEvent(events, now) {
  var current = now instanceof Date ? now : new Date()
  var matches = (Array.isArray(events) ? events : []).filter(function(event) {
    if (event && event.allDay) return false
    var start = eventStart(event)
    var end = eventEnd(event)
    return start && end && start <= current && current < end
  })
  matches.sort(function(left, right) {
    return eventEnd(left).getTime() - eventEnd(right).getTime()
  })
  return matches.length ? matches[0] : null
}

function syncSummary(status) {
  var result = {
    authRequired: false,
    error: false,
    syncing: false,
    stale: false,
    retrying: false,
    message: ""
  }

  function visit(value, depth) {
    if (!value || depth > 8) return
    if (Array.isArray(value)) {
      for (var arrayIndex = 0; arrayIndex < value.length; arrayIndex++)
        visit(value[arrayIndex], depth + 1)
      return
    }
    if (typeof value !== "object") return

    var state = String(value.state || "").toLowerCase()
    if (state === "reauthorization_required" || state === "authentication_required"
        || state === "auth_required") result.authRequired = true
    else if (state === "error" || state === "unavailable") result.error = true
    else if (state === "retry_wait") result.retrying = true
    else if (state === "syncing" || state === "refreshing" || state === "sending"
        || state === "authorizing") result.syncing = true
    else if (state === "stale") result.stale = true

    if (value.stale === true) result.stale = true
    if (!result.message) result.message = String(value.errorMessage || value.message || "")
    for (var key in value) {
      if (key !== "errorMessage" && key !== "message" && key !== "state")
        visit(value[key], depth + 1)
    }
  }

  visit(status, 0)
  return result
}

function meetingUrl(event) {
  if (!event) return ""
  var direct = String(event.meetingUrl || "")
  if (/^https:\/\//i.test(direct)) return direct
  var haystack = [event.url, event.location, event.description].join(" ")
  var match = haystack.match(/https:\/\/[^\s<>\"]+/i)
  return match ? match[0].replace(/[),.;]+$/, "") : ""
}

function filteredEvents(events, query) {
  var normalized = String(query || "").trim().toLowerCase()
  if (!normalized) return Array.isArray(events) ? events.slice(0) : []
  var input = Array.isArray(events) ? events : []
  return input.filter(function(event) {
    var attendees = Array.isArray(event.attendees) ? event.attendees.map(function(item) {
      return String(item.name || item.email || "")
    }).join(" ") : ""
    var text = [event.title, event.summary, event.location, event.notes, event.description, attendees].join(" ").toLowerCase()
    return text.indexOf(normalized) !== -1
  })
}

function eventTitle(event) {
  return String(event && (event.title || event.summary) || "Untitled event")
}

// `widget.snapshot` represents an absent current/up-next event as an empty
// object so its JSON shape remains stable. QML treats that object as truthy,
// therefore presentation code must use this predicate rather than a raw
// truthiness check before showing an event affordance.
function hasEvent(event) {
  return !!event && typeof event === "object" && String(event.id || "").trim() !== ""
}

function calendarColor(event, calendars, fallback) {
  if (event && event.color) return String(event.color)
  var input = Array.isArray(calendars) ? calendars : []
  for (var index = 0; index < input.length; index++) {
    if (String(input[index].id) === String(event && event.calendarId || ""))
      return String(input[index].color || fallback)
  }
  return fallback
}

function clientMutationId() {
  return "widget-" + Date.now().toString(36) + "-" + Math.floor(Math.random() * 0x100000000).toString(36)
}
