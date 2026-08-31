pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import Quickshell
import qs.Commons
import qs.Ui
import "CalendarModel.js" as Model
import "components" as Components

Panel {
  id: root
  moduleName: "org.omacalendar.widget"
  ipcTarget: "org.omacalendar.widget"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  property alias client: daemonClient
  readonly property var barIdentity: hostWidget || root
  readonly property color contentForeground: bar ? bar.foreground : Color.foreground
  readonly property string contentFontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property real bodyViewportHeight: panelScroll.height
  readonly property real bodyContentHeight: panelScroll.contentHeight

  property date today: new Date()
  property date selectedDate: new Date()
  property int viewYear: selectedDate.getFullYear()
  property int viewMonth: selectedDate.getMonth()
  property int selectedEventIndex: -1
  property bool editorVisible: false
  property var editingEvent: null
  property string searchQuery: ""
  property bool searching: false
  property string selectedCalendarSetId: ""
  property string selectedCalendarId: ""
  property bool calendarSelectorOpen: false
  property string viewMode: "month"
  property int agendaAnchorRevision: 0
  property string recurrenceScope: "series"
  property string guestNotificationPolicy: "none"

  readonly property var snapshot: daemonClient.snapshot || ({})
  readonly property var calendars: Array.isArray(snapshot.calendars) ? snapshot.calendars : []
  readonly property var calendarSets: Array.isArray(snapshot.calendarSets) ? snapshot.calendarSets : []
  readonly property var selectableCalendars: Model.writableCalendars(calendars)
  readonly property var allEvents: Array.isArray(snapshot.events) ? snapshot.events : []
  readonly property var displayedEvents: Model.eventsForCalendar(allEvents, selectedCalendarId)
  readonly property var marks: Model.eventMarks(displayedEvents)
  readonly property string selectedDateKey: Model.dateKey(selectedDate)
  readonly property var visibleEvents: searchQuery.trim() !== ""
    ? Model.filteredEvents(displayedEvents, searchQuery)
    : Model.eventsForDate(displayedEvents, selectedDateKey)
  readonly property var selectedEvent: selectedEventIndex >= 0 && selectedEventIndex < visibleEvents.length
    ? visibleEvents[selectedEventIndex] : null
  readonly property var upNext: Model.hasEvent(snapshot.upNext) ? snapshot.upNext : null
  readonly property bool hasCachedSnapshot: Number(snapshot.revision || 0) > 0
  readonly property int weekStart: Model.normalizedWeekStart(setting("weekStart", null), Qt.locale().firstDayOfWeek)
  // IPC 2 snapshots compute this against a fixed window around now, so browsing
  // another month cannot make the bar/popup lose the actual current event.
  // Keep the local derivation as a compatibility fallback for older daemons.
  readonly property var currentEvent: snapshot.currentEvent !== undefined
    ? (Model.hasEvent(snapshot.currentEvent) ? snapshot.currentEvent : null)
    : Model.currentEvent(allEvents, today)
  readonly property date weekViewStart: {
    var offset = (selectedDate.getDay() - weekStart + 7) % 7
    return Model.addDays(selectedDate, -offset)
  }
  readonly property var agendaViewEvents: {
    var source = searchQuery.trim() !== ""
      ? Model.filteredEvents(displayedEvents, searchQuery) : displayedEvents
    return Model.agendaTimelineEvents(source)
  }
  readonly property int agendaAnchorIndex: Model.agendaAnchorIndex(agendaViewEvents, selectedDate)

  readonly property string selectedCalendarName: {
    if (!selectedCalendarId) return "All Calendars"
    for (var index = 0; index < selectableCalendars.length; index++) {
      if (String(selectableCalendars[index].id) === selectedCalendarId)
        return String(selectableCalendars[index].name || "Calendar")
    }
    return "All Calendars"
  }

  function open() {
    root.controller.show()
    root.refresh()
    Qt.callLater(function() {
      if (root.opened) root.setCenterHoverRevealSuppressed(true)
    })
  }

  function close() {
    root.setCenterHoverRevealSuppressed(false)
    root.editorVisible = false
    root.calendarSelectorOpen = false
    root.searching = false
    root.searchQuery = ""
    searchTimer.stop()
    root.controller.hide()
  }

  function toggle() {
    if (root.opened) root.close()
    else root.open()
  }

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.barIdentity, direction)
    return false
  }

  function setCenterHoverRevealSuppressed(value) {
    if (root.bar && "centerHoverRevealSuppressed" in root.bar)
      root.bar.centerHoverRevealSuppressed = value
  }

  function rangeSelection() {
    var rangeStart
    var rangeEnd
    if (viewMode === "agenda") {
      rangeStart = Model.addDays(selectedDate, -60)
      rangeEnd = Model.addDays(selectedDate, 180)
    } else {
      rangeStart = new Date(viewYear, viewMonth, 1, 0, 0, 0, 0)
      rangeStart.setDate(rangeStart.getDate() - 7)
      rangeEnd = new Date(viewYear, viewMonth + 1, 1, 0, 0, 0, 0)
      rangeEnd.setDate(rangeEnd.getDate() + 7)
    }
    return {
      start: rangeStart.toISOString(),
      end: rangeEnd.toISOString(),
      selectedDate: selectedDateKey,
      searchQuery: searchQuery.trim(),
      calendarSetId: selectedCalendarSetId
    }
  }

  function refresh() {
    daemonClient.refreshSnapshot(rangeSelection())
  }

  function moveMonth(delta) {
    var next = Model.stepMonth(viewYear, viewMonth, delta)
    viewYear = next.year
    viewMonth = next.month
    selectedDate = new Date(viewYear, viewMonth, 1, 12, 0, 0, 0)
    selectedEventIndex = -1
    refresh()
  }

  function selectDate(value) {
    selectedDate = value
    viewYear = value.getFullYear()
    viewMonth = value.getMonth()
    selectedEventIndex = visibleEvents.length ? 0 : -1
    refresh()
  }

  function goToToday() {
    selectDate(new Date())
    agendaAnchorRevision++
  }

  function setViewMode(mode) {
    var next = String(mode || "month")
    if (next === "agenda" && viewMode !== "agenda") {
      selectedDate = new Date(today.getFullYear(), today.getMonth(), today.getDate(), 12, 0, 0, 0)
      viewYear = selectedDate.getFullYear()
      viewMonth = selectedDate.getMonth()
    }
    viewMode = next
    editorVisible = false
    selectedEventIndex = -1
    refresh()
  }

  function moveCursor(dx, dy) {
    if (dx !== 0) {
      selectDate(Model.addDays(selectedDate, dx))
      return
    }
    if (dy !== 0 && visibleEvents.length > 0) {
      selectedEventIndex = Math.max(0, Math.min(visibleEvents.length - 1,
        (selectedEventIndex < 0 ? 0 : selectedEventIndex) + dy))
    }
  }

  function beginCreate() {
    viewMode = "month"
    editingEvent = null
    editorVisible = true
    Qt.callLater(eventEditor.reset)
  }

  function beginEdit(event) {
    viewMode = "month"
    editingEvent = event
    editorVisible = true
    recurrenceScope = event && (event.recurring || event.recurrenceRule) ? "this" : "series"
    Qt.callLater(eventEditor.reset)
  }

  function finishEditing() {
    editorVisible = false
    Qt.callLater(function() {
      if (root.opened) keyCatcher.forceActiveFocus()
    })
  }

  function cycleRecurrenceScope() {
    var candidate = editorVisible ? editingEvent : selectedEvent
    var movingCalendars = editorVisible && editingEvent
      && String(eventEditor.selectedCalendarId || "") !== String(editingEvent.calendarId || "")
    var values = ["this"]
    if (!movingCalendars && futureScopeSupportedForEvent(candidate)) values.push("future")
    values.push("series")
    if (values.indexOf(recurrenceScope) < 0) recurrenceScope = values[0]
    recurrenceScope = values[(values.indexOf(recurrenceScope) + 1) % values.length]
  }

  function calendarForId(calendarId) {
    for (var index = 0; index < calendars.length; index++) {
      if (String(calendars[index].id) === String(calendarId || "")) return calendars[index]
    }
    return null
  }

  function futureScopeSupportedForEvent(event) {
    var calendar = calendarForId(event && event.calendarId)
    var capabilities = calendar && calendar.capabilities || ({})
    return capabilities.thisAndFuture === true
  }

  function cycleGuestNotificationPolicy() {
    var values = ["none", "all", "externalOnly"]
    guestNotificationPolicy = values[(values.indexOf(guestNotificationPolicy) + 1) % values.length]
  }

  function removeSelected() {
    if (!selectedEvent || selectedEvent.readOnly) return
    daemonClient.removeEvent(selectedEvent, recurrenceScope, guestNotificationPolicy, function(result, error) {
      if (!error) {
        selectedEventIndex = -1
      }
    })
  }

  function openEvent(event) {
    if (!event || !event.id) return
    openDesktop("event/" + encodeURIComponent(String(event.id)))
  }

  function joinEvent(event) {
    var url = Model.meetingUrl(event)
    if (url) Quickshell.execDetached(["xdg-open", url])
  }

  function openDesktop(path) {
    root.close()
    Qt.callLater(function() { daemonClient.openDeepLink(path) })
  }

  function respond(response) {
    if (!selectedEvent) return
    daemonClient.respondToEvent(selectedEvent, response, recurrenceScope, "all")
  }

  function selectCalendar(id) {
    selectedCalendarId = String(id || "")
    selectedEventIndex = -1
    calendarSelectorOpen = false
  }

  function movePeriod(delta) {
    if (viewMode === "month") {
      moveMonth(delta)
      return
    }
    selectDate(Model.addDays(selectedDate,
      delta * (viewMode === "day" || viewMode === "agenda" ? 1 : 7)))
  }

  onVisibleEventsChanged: {
    if (visibleEvents.length === 0) selectedEventIndex = -1
    else if (selectedEventIndex >= visibleEvents.length) selectedEventIndex = visibleEvents.length - 1
  }
  onSelectableCalendarsChanged: {
    if (!selectedCalendarId) return
    var stillAvailable = selectableCalendars.some(function(calendar) {
      return String(calendar.id) === selectedCalendarId
    })
    if (!stillAvailable) selectedCalendarId = ""
  }
  onSelectedEventChanged: {
    guestNotificationPolicy = "none"
    recurrenceScope = selectedEvent && (selectedEvent.recurring || selectedEvent.recurrenceRule)
      ? "this" : "series"
  }

  Connections {
    target: daemonClient
    function onSnapshotUpdated() {
      var active = daemonClient.snapshot.activeCalendarSet
      if (active && active.id) root.selectedCalendarSetId = String(active.id)
      else if (active && typeof active === "string") root.selectedCalendarSetId = String(active)
      if (root.selectedEventIndex < 0 && root.visibleEvents.length > 0) root.selectedEventIndex = 0
    }
  }

  OmaCalendarClient {
    id: daemonClient
    pollIntervalMs: {
      var seconds = Number(root.setting("refreshSeconds", 60))
      return Math.max(15, isFinite(seconds) ? seconds : 60) * 1000
    }
    socketPath: {
      var configured = String(root.setting("socketPath", ""))
      if (configured) return configured
      var runtime = Quickshell.env("XDG_RUNTIME_DIR")
      return runtime ? runtime + "/omacalendar/daemon.sock" : ""
    }
  }

  Timer {
    id: searchTimer
    interval: 300
    onTriggered: root.refresh()
  }

  SystemClock {
    id: systemClock
    precision: SystemClock.Minutes
    onDateChanged: {
      var oldKey = Model.dateKey(root.today)
      root.today = date
      if (oldKey !== Model.dateKey(date)) root.refresh()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    centerOnBar: true
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(760))
    contentHeight: panel.fittedContentHeight(
      Math.max(Style.space(420),
        contentColumn.implicitHeight + footerRow.implicitHeight + Style.space(18)),
      Style.space(620))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: searchField.activeFocus || root.editorVisible
      onMoveRequested: function(dx, dy) { root.moveCursor(dx, dy) }
      onActivateRequested: {
        if (root.selectedEvent) root.openEvent(root.selectedEvent)
      }
      onCloseRequested: {
        if (root.calendarSelectorOpen) root.calendarSelectorOpen = false
        else root.close()
      }
      onDeleteRequested: root.removeSelected()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(text) {
        if (text === "n" || text === "N") root.beginCreate()
        else if (text === "s" || text === "S" || text === "/") {
          root.searching = true
          Qt.callLater(function() { searchField.forceActiveFocus() })
        } else if (text === "r" || text === "R") root.refresh()
        else if (text === "t" || text === "T") root.goToToday()
        else if (text === "c" || text === "C") root.calendarSelectorOpen = !root.calendarSelectorOpen
        else if (text === "1") root.setViewMode("month")
        else if (text === "2") root.setViewMode("day")
        else if (text === "3") root.setViewMode("week")
        else if (text === "4") root.setViewMode("agenda")
        else if (text === "[") root.moveMonth(-1)
        else if (text === "]") root.moveMonth(1)
        else if (text === "e" || text === "E") {
          if (root.selectedEvent) root.beginEdit(root.selectedEvent)
        }
      }

      Shortcut {
        sequences: ["Delete"]
        enabled: root.opened && !root.editorVisible && !searchField.activeFocus
        onActivated: root.removeSelected()
      }

      Shortcut {
        sequences: ["Ctrl+N"]
        enabled: root.opened && !root.editorVisible && !searchField.activeFocus
        onActivated: root.beginCreate()
      }

      Shortcut {
        sequences: ["Ctrl+F"]
        enabled: root.opened && !root.editorVisible && !searchField.activeFocus
        onActivated: {
          root.searching = true
          Qt.callLater(function() { searchField.forceActiveFocus() })
        }
      }

      Shortcut {
        sequences: ["Ctrl+Z"]
        enabled: root.opened && !root.editorVisible && !searchField.activeFocus && daemonClient.undoToken !== ""
        onActivated: daemonClient.undo()
      }

      Flickable {
        id: panelScroll
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: footerSeparator.top
        anchors.bottomMargin: Style.space(8)
        contentWidth: contentColumn.width
        contentHeight: contentColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height || contentWidth > width

        Column {
          id: contentColumn
          width: Math.max(panelScroll.width, Style.space(700))
          spacing: Style.space(10)

          Row {
            width: parent.width

            Column {
              width: parent.width - headerActions.implicitWidth
              spacing: Style.space(2)

              Text {
                width: parent.width
                text: Qt.formatDate(root.selectedDate, "dddd, MMMM d")
                color: root.contentForeground
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.title
                font.bold: true
                elide: Text.ElideRight
              }

              Text {
                width: parent.width
                visible: root.currentEvent !== null
                text: root.currentEvent
                  ? "NOW · " + Model.eventTitle(root.currentEvent) + " · " + Model.upNextLabel(root.currentEvent, root.today)
                  : ""
                color: Color.accent
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
                font.letterSpacing: 1
                elide: Text.ElideRight
              }

              Text {
                width: parent.width
                text: root.upNext
                  ? "UP NEXT · " + Model.eventTitle(root.upNext) + " · " + Model.upNextLabel(root.upNext, root.today)
                  : "NO UPCOMING EVENTS"
                color: Qt.darker(root.contentForeground, 1.4)
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
                font.letterSpacing: 1
                elide: Text.ElideRight
              }
            }

            Row {
              id: headerActions
              spacing: Style.space(4)

              PanelActionButton {
                iconText: "󰑓"
                tooltipText: "Refresh"
                foreground: root.contentForeground
                focusable: true
                enabled: daemonClient.connectionState === "ready" && daemonClient.supports("sync.all")
                onClicked: daemonClient.syncNow()
              }

              PanelActionButton {
                iconText: "󰋜"
                tooltipText: "Open OmaCalendar"
                foreground: root.contentForeground
                focusable: true
                onClicked: root.openDesktop("")
              }
            }
          }

          BorderSurface {
            visible: daemonClient.undoToken !== ""
            width: parent.width
            implicitHeight: visible ? undoRow.implicitHeight + Style.space(10) : 0
            color: Style.selectedFillFor(root.contentForeground, Color.accent)
            borderSpec: Border.controlSpec("normal", root.contentForeground, Color.accent)
            radius: Style.cornerRadius

            Row {
              id: undoRow
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.leftMargin: Style.space(10)
              anchors.rightMargin: Style.space(6)
              anchors.verticalCenter: parent.verticalCenter

              Text {
                width: parent.width - undoButton.implicitWidth
                anchors.verticalCenter: parent.verticalCenter
                text: daemonClient.undoLabel || "Event deleted"
                color: root.contentForeground
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.body
              }

              Button {
                id: undoButton
                text: "Undo"
                selected: true
                foreground: root.contentForeground
                focusable: true
                onClicked: daemonClient.undo()
              }
            }
          }

          Column {
            width: parent.width
            spacing: Style.space(4)

            Button {
              width: parent.width
              text: root.selectedCalendarName + (root.calendarSelectorOpen ? "  ▴" : "  ▾")
              leftAlign: true
              foreground: root.contentForeground
              selected: root.calendarSelectorOpen || root.selectedCalendarId !== ""
              focusable: true
              onClicked: root.calendarSelectorOpen = !root.calendarSelectorOpen
            }

            Flickable {
              visible: root.calendarSelectorOpen
              width: parent.width
              height: visible ? Math.min(calendarOptions.implicitHeight, Style.space(210)) : 0
              contentHeight: calendarOptions.implicitHeight
              clip: true
              boundsBehavior: Flickable.StopAtBounds
              ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

              Column {
                id: calendarOptions
                width: parent.width
                spacing: Style.space(3)

                Button {
                  width: parent.width
                  text: "All Calendars"
                  leftAlign: true
                  foreground: root.contentForeground
                  selected: root.selectedCalendarId === ""
                  focusable: true
                  onClicked: root.selectCalendar("")
                }

                Repeater {
                  model: root.selectableCalendars

                  Button {
                    required property var modelData
                    width: calendarOptions.width
                    text: String(modelData.name || "Calendar")
                    leftAlign: true
                    foreground: root.contentForeground
                    selected: String(modelData.id) === root.selectedCalendarId
                    focusable: true
                    onClicked: root.selectCalendar(modelData.id)
                  }
                }
              }
            }
          }

          Row {
            visible: root.searching
            width: parent.width
            spacing: Style.space(5)

            TextField {
              id: searchField
              width: parent.width - clearSearchButton.implicitWidth - closeSearchButton.implicitWidth - parent.spacing * 2
              placeholderText: "Search events, locations, notes, or guests"
              foreground: root.contentForeground
              text: root.searchQuery
              Accessible.name: "Search calendar"
              onTextChanged: {
                root.searchQuery = text
                searchTimer.restart()
              }
              Keys.onEscapePressed: function(event) {
                text = ""
                root.searching = false
                keyCatcher.forceActiveFocus()
                event.accepted = true
              }
              Keys.onReturnPressed: {
                root.refresh()
                keyCatcher.forceActiveFocus()
              }
            }

            Button {
              id: clearSearchButton
              text: "Clear"
              foreground: root.contentForeground
              focusable: true
              enabled: searchField.text !== ""
              onClicked: {
                searchField.text = ""
                searchField.forceActiveFocus()
              }
            }

            Button {
              id: closeSearchButton
              text: "Close"
              foreground: root.contentForeground
              focusable: true
              onClicked: {
                searchField.text = ""
                root.searching = false
                keyCatcher.forceActiveFocus()
              }
            }
          }

          Row {
            width: parent.width
            spacing: Style.space(5)

            Button {
              text: "‹"
              foreground: root.contentForeground
              focusable: true
              onClicked: root.movePeriod(-1)
            }

            Repeater {
              model: [
                { id: "month", label: "Month" },
                { id: "day", label: "Day" },
                { id: "week", label: "Week" },
                { id: "agenda", label: "Agenda" }
              ]

              Button {
                required property var modelData
                text: modelData.label
                selected: root.viewMode === modelData.id
                foreground: root.contentForeground
                focusable: true
                onClicked: {
                  root.setViewMode(modelData.id)
                }
              }
            }

            Item {
              width: Math.max(0, parent.width - parent.children.reduce(function(total, child) {
                return total + (child === this || !child.visible ? 0 : child.implicitWidth)
              }, 0) - parent.spacing * 6)
              height: 1
            }

            Button {
              text: "+ New"
              foreground: root.contentForeground
              focusable: true
              enabled: daemonClient.supports("events.create")
              onClicked: root.beginCreate()
            }

            Button {
              text: "›"
              foreground: root.contentForeground
              focusable: true
              onClicked: root.movePeriod(1)
            }
          }

          Row {
            visible: root.viewMode === "month"
            width: parent.width
            spacing: Style.space(18)

            Components.MonthGrid {
              id: monthGrid
              year: root.viewYear
              month: root.viewMonth
              today: root.today
              selectedDate: root.selectedDate
              weekStart: root.weekStart
              marks: root.marks
              foreground: root.contentForeground
              fontFamily: root.contentFontFamily
              onDateSelected: function(value) { root.selectDate(value) }
              onMonthRequested: function(delta) { root.moveMonth(delta) }
            }

            PanelSeparator {
              width: Math.max(1, Style.normalBorderWidth)
              height: Math.max(monthGrid.implicitHeight, agendaColumn.implicitHeight)
              foreground: root.contentForeground
            }

            Column {
              id: agendaColumn
              width: Math.max(Style.space(350), parent.width - monthGrid.width - parent.spacing * 2 - 1)
              spacing: Style.space(7)

              Components.EventEditor {
                id: eventEditor
                visible: root.editorVisible
                width: parent.width
                height: visible ? implicitHeight : 0
                event: root.editingEvent
                calendars: root.calendars
                selectedDate: root.selectedDate
                defaultCalendarId: String(root.snapshot.defaultCalendarId || "")
                foreground: root.contentForeground
                onSelectedCalendarIdChanged: {
                  if (root.editorVisible && root.editingEvent
                      && String(selectedCalendarId || "")
                         !== String(root.editingEvent.calendarId || "")
                      && root.recurrenceScope === "future")
                    root.recurrenceScope = "this"
                }
                onCancelRequested: root.finishEditing()
                onOpenInAppRequested: {
                  if (root.editingEvent) root.openEvent(root.editingEvent)
                  else root.openDesktop("new")
                }
                onSaveRequested: function(draft, guestPolicy) {
                  if (root.editingEvent) {
                    var sourceCalendarId = String(root.editingEvent.calendarId || "")
                    var targetCalendarId = String(draft.calendarId || "")
                    var save = sourceCalendarId !== "" && targetCalendarId !== ""
                      && sourceCalendarId !== targetCalendarId
                      ? daemonClient.moveEvent : daemonClient.updateEvent
                    save(root.editingEvent, draft, root.recurrenceScope, guestPolicy, function(result, error) {
                      if (!error) root.finishEditing()
                    })
                  } else {
                    daemonClient.createEvent(draft, guestPolicy, function(result, error) {
                      if (!error) root.finishEditing()
                    })
                  }
                }
              }

              Column {
                visible: !root.editorVisible
                width: parent.width
                spacing: Style.space(6)

                Row {
                  width: parent.width

                  PanelSectionHeader {
                    width: parent.width
                    text: root.searchQuery.trim() !== "" ? "SEARCH RESULTS" : "AGENDA"
                    foreground: root.contentForeground
                    fontFamily: root.contentFontFamily
                  }

                }

                Components.AgendaList {
                  width: parent.width
                  height: Style.space(225)
                  events: root.visibleEvents
                  calendars: root.calendars
                  selectedIndex: root.selectedEventIndex
                  foreground: root.contentForeground
                  fontFamily: root.contentFontFamily
                  onEventClicked: function(index, event) {
                    root.selectedEventIndex = index
                    if (event && event.readOnly) root.openEvent(event)
                    else root.beginEdit(event)
                  }
                  onJoinClicked: function(event) { root.joinEvent(event) }
                }
              }
            }
          }

          Components.CompactTimeline {
            visible: root.viewMode === "day" || root.viewMode === "week"
            width: parent.width
            height: visible ? Style.space(330) : 0
            startDate: root.viewMode === "week" ? root.weekViewStart : root.selectedDate
            dayCount: root.viewMode === "week" ? 7 : 1
            events: root.searchQuery.trim() !== ""
              ? Model.filteredEvents(root.displayedEvents, root.searchQuery) : root.displayedEvents
            calendars: root.calendars
            foreground: root.contentForeground
            fontFamily: root.contentFontFamily
            onEventClicked: function(event) {
              if (event && event.readOnly) root.openEvent(event)
              else root.beginEdit(event)
            }
          }

          Column {
            visible: root.viewMode === "agenda"
            width: parent.width
            height: visible ? Style.space(330) : 0
            spacing: Style.space(6)

            PanelSectionHeader {
              width: parent.width
              text: root.searchQuery.trim() !== "" ? "SEARCH RESULTS" : "UPCOMING AGENDA"
              foreground: root.contentForeground
              fontFamily: root.contentFontFamily
            }

            Components.AgendaList {
              width: parent.width
              height: parent.height - Style.space(30)
              events: root.agendaViewEvents
              calendars: root.calendars
              selectedIndex: -1
              showDate: true
              active: root.viewMode === "agenda"
              anchorIndex: root.agendaAnchorIndex
              anchorToken: root.selectedDateKey + "|" + root.selectedCalendarId + "|"
                + root.searchQuery + "|" + root.agendaAnchorRevision
              foreground: root.contentForeground
              fontFamily: root.contentFontFamily
              onEventClicked: function(index, event) {
                root.selectedEventIndex = index
                if (event && event.readOnly) root.openEvent(event)
                else root.beginEdit(event)
              }
              onJoinClicked: function(event) { root.joinEvent(event) }
            }
          }

        }
      }

      PanelSeparator {
        id: footerSeparator
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: footerRow.top
        anchors.bottomMargin: Style.space(8)
        foreground: root.contentForeground
      }

      Row {
        id: footerRow
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        spacing: Style.space(5)

        Button {
          text: "Today"
          foreground: root.contentForeground
          focusable: true
          onClicked: root.goToToday()
        }

        Button {
          text: root.searching ? "Close search" : "Search"
          foreground: root.contentForeground
          focusable: true
          onClicked: {
            root.searching = !root.searching
            if (root.searching) Qt.callLater(function() { searchField.forceActiveFocus() })
            else {
              searchField.text = ""
              keyCatcher.forceActiveFocus()
            }
          }
        }

        Item {
          width: Math.max(0, parent.width - parent.children.reduce(function(total, child) {
            return total + (child === this || !child.visible ? 0 : child.implicitWidth)
          }, 0) - parent.spacing * 3)
          height: Math.max(1, Style.normalBorderWidth)
        }

        Button {
          text: "Accounts"
          foreground: root.contentForeground
          focusable: true
          onClicked: root.openDesktop("settings/accounts")
        }
      }
    }
  }
}
