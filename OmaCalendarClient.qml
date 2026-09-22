pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import "CalendarModel.js" as Model

Item {
  id: root

  readonly property int protocolMajor: 2
  readonly property int minimumProtocolMinor: 0
  readonly property int maximumFrameBytes: 1024 * 1024
  readonly property int maximumPendingRequests: 32
  readonly property int maximumTitleLength: 1024
  readonly property int maximumLocationLength: 4096
  readonly property int maximumNotesLength: 65536

  property string socketPath: {
    var runtime = Quickshell.env("XDG_RUNTIME_DIR")
    return runtime ? runtime + "/omacalendar/daemon.sock" : ""
  }
  property string connectionState: "connecting"
  property string stateDetail: "Connecting to OmaCalendar…"
  property var serverInfo: ({})
  property var methods: []
  property var snapshot: ({
    revision: 0,
    status: {},
    activeCalendarSet: null,
    calendarSets: [],
    calendars: [],
    events: [],
    currentEvent: null,
    upNext: null,
    conflicts: [],
    operations: []
  })
  property double revision: Number(snapshot.revision || 0)
  readonly property bool stale: connectionState !== "ready" || cacheStale || !!snapshot.stale
  property bool connecting: connectionState === "connecting" || connectionState === "negotiating"
  property bool cacheStale: true
  property bool needsBaseline: true
  property bool forceNextSnapshot: false
  property bool snapshotRefreshQueued: false
  property string activeSnapshotRequest: ""
  property int pollIntervalMs: 60000
  property int retryAttempt: 0
  property int requestCounter: 0
  property var pending: ({})
  property var lastSelection: ({})
  property string snapshotQueryKey: ""
  property string lastActionError: ""
  property string undoToken: ""
  property string undoLabel: ""
  property string activeMutationId: ""
  property string transportFailureDetail: ""
  property string receiveBuffer: ""

  signal snapshotUpdated()
  signal actionSucceeded(string action, var result)
  signal actionFailed(string action, string message)

  function supports(method) {
    return Array.isArray(methods) && methods.indexOf(method) !== -1
  }

  function _setState(next, detail) {
    stateDetail = String(detail || "")
    connectionState = next
  }

  function _object(value) {
    return value !== null && typeof value === "object" && !Array.isArray(value)
  }

  function _pendingCount() {
    return Object.keys(pending).length
  }

  function _validId(value) {
    return typeof value === "string" && value.trim() !== "" && value.length <= 512
  }

  function _validObjectArray(value, maximum) {
    if (!Array.isArray(value) || value.length > maximum) return false
    for (var index = 0; index < value.length; index++)
      if (!_object(value[index])) return false
    return true
  }

  function _validEventDto(event) {
    if (!_object(event) || !_validId(event.id) || !_validId(event.calendarId)) return false
    if (String(event.title || "").length > maximumTitleLength
        || String(event.location || "").length > maximumLocationLength
        || String(event.notes || "").length > maximumNotesLength)
      return false
    if (event.attendees !== undefined && !_validObjectArray(event.attendees, 500)) return false
    var start = Model.eventStart(event)
    var end = Model.eventEnd(event)
    if (start === null || end === null) return false
    // Some subscribed all-day sources (e.g. sports schedule feeds) report a
    // single-day event with startDate === endDate instead of the exclusive
    // next-day endDate this app's own calendars use elsewhere. Treat that as
    // a valid one-day event rather than rejecting the whole snapshot over it.
    return event.allDay ? end >= start : end > start
  }

  function _validateSnapshot(value) {
    if (!_object(value) || !isFinite(Number(value.revision)) || Number(value.revision) < 0)
      return false
    if (!_validObjectArray(value.calendarSets, 100)
        || !_validObjectArray(value.calendars, 500)
        || !_validObjectArray(value.events, 1000)
        || !_validObjectArray(value.invitations, 100)
        || !_validObjectArray(value.conflicts, 500)
        || !_validObjectArray(value.operations, 100))
      return false
    for (var calendarIndex = 0; calendarIndex < value.calendars.length; calendarIndex++)
      if (!_validId(value.calendars[calendarIndex].id)) return false
    for (var eventIndex = 0; eventIndex < value.events.length; eventIndex++)
      if (!_validEventDto(value.events[eventIndex])) return false
    for (var keyIndex = 0; keyIndex < 2; keyIndex++) {
      var key = keyIndex === 0 ? "currentEvent" : "upNext"
      var event = value[key]
      if (event !== undefined && event !== null && Object.keys(event).length > 0
          && !_validEventDto(event)) return false
    }
    return true
  }

  function _validEnum(value, values) {
    return values.indexOf(String(value || "")) !== -1
  }

  function _validateDraft(draft) {
    if (!_object(draft) || !_validId(String(draft.calendarId || "")))
      return "A valid calendar is required"
    if (!String(draft.title || "").trim() || String(draft.title).length > maximumTitleLength)
      return "The event title is missing or too long"
    if (String(draft.location || "").length > maximumLocationLength
        || String(draft.notes || "").length > maximumNotesLength)
      return "The event details are too long"
    var start = Model.eventStart(draft)
    var end = Model.eventEnd(draft)
    if (!start || !end || end <= start) return "The event dates are invalid"
    return ""
  }

  function _validatePatch(patch) {
    if (!_object(patch)) return "The event changes are invalid"
    if (patch.title !== undefined && String(patch.title).length > maximumTitleLength)
      return "The event title is too long"
    if (String(patch.location || "").length > maximumLocationLength
        || String(patch.notes || "").length > maximumNotesLength)
      return "The event details are too long"
    if (patch.start !== undefined || patch.startDate !== undefined
        || patch.end !== undefined || patch.endDate !== undefined) {
      var start = Model.eventStart(patch)
      var end = Model.eventEnd(patch)
      if (!start || !end || end <= start) return "The event dates are invalid"
    }
    return ""
  }

  function _validateMutation(method, payload) {
    if (!_object(payload) || !_validId(String(payload.clientMutationId || "")))
      return "The mutation identifier is invalid"
    var guestMethods = ["events.create", "events.update", "events.remove", "events.move", "events.respond"]
    if (guestMethods.indexOf(method) !== -1
        && !_validEnum(payload.guestNotificationPolicy, ["none", "all", "externalOnly"]))
      return "The guest notification policy is invalid"
    if (method.indexOf("events.") === 0 && method !== "events.undo") {
      if (!_validEnum(payload.recurrenceScope, ["series", "occurrence", "future"]))
        return "The recurrence scope is invalid"
      if (method !== "events.create"
          && (!_object(payload.eventRef) || !_validId(String(payload.eventRef.eventId || ""))))
        return "The event reference is invalid"
    }
    if (method === "events.create") return _validateDraft(payload.draft)
    if (method === "events.move") return _validateDraft(payload.draft)
    if (method === "events.update") return _validatePatch(payload.patch)
    if (method === "events.respond"
        && !_validEnum(payload.response, ["accepted", "tentative", "declined"]))
      return "The invitation response is invalid"
    if (method === "calendarSets.activate" && !_validId(String(payload.calendarSetId || "")))
      return "The calendar set is invalid"
    if (method === "operations.retry"
        && (!isFinite(payload.operationId) || payload.operationId <= 0 || Math.floor(payload.operationId) !== payload.operationId))
      return "The operation is invalid"
    if (method === "events.undo" && !_validId(String(payload.undoToken || "")))
      return "The undo token is invalid"
    return ""
  }

  function connectNow() {
    retryTimer.stop()
    if (!socketPath) {
      _setState("missing", "XDG_RUNTIME_DIR is unavailable")
      return
    }
    if (socket.connected) {
      if (connectionState === "ready") refreshSnapshot(lastSelection, true)
      else _negotiate()
      return
    }
    _setState("connecting", "Connecting to OmaCalendar…")
    socket.connected = true
  }

  function _scheduleReconnect() {
    if (connectionState === "incompatible") return
    retryAttempt = Math.min(retryAttempt + 1, 6)
    retryTimer.interval = Math.min(30000, 1000 * Math.pow(2, retryAttempt - 1))
    retryTimer.restart()
  }

  function _request(method, params, callback, timeoutMs) {
    if (!socket.connected) {
      if (callback) callback(null, { code: "daemon_unavailable", message: "OmaCalendar service is unavailable", retryable: true })
      return ""
    }
    if (_pendingCount() >= maximumPendingRequests) {
      if (callback) callback(null, { code: "too_many_requests", message: "Too many calendar requests are pending", retryable: true })
      return ""
    }
    requestCounter++
    var id = "widget-" + Date.now().toString(36) + "-" + requestCounter
    var encoded
    try {
      encoded = JSON.stringify({
        id: id,
        protocolMajor: protocolMajor,
        method: method,
        params: params || {}
      }) + "\n"
    } catch (error) {
      if (callback) callback(null, { code: "invalid_request", message: "The calendar request could not be encoded", retryable: false })
      return ""
    }
    if (_utf8Size(encoded) > maximumFrameBytes) {
      if (callback) callback(null, { code: "request_too_large", message: "The calendar request is too large", retryable: false })
      return ""
    }
    var next = {}
    for (var key in pending) next[key] = pending[key]
    next[id] = {
      method: method,
      callback: callback,
      deadline: Date.now() + Number(timeoutMs || 5000)
    }
    pending = next
    socket.write(encoded)
    socket.flush()
    return id
  }

  function _utf8Size(value) {
    var text = String(value || "")
    var bytes = 0
    for (var index = 0; index < text.length; index++) {
      var code = text.charCodeAt(index)
      if (code <= 0x7f) bytes += 1
      else if (code <= 0x7ff) bytes += 2
      else if (code >= 0xd800 && code <= 0xdbff && index + 1 < text.length
          && text.charCodeAt(index + 1) >= 0xdc00 && text.charCodeAt(index + 1) <= 0xdfff) {
        bytes += 4
        index++
      } else bytes += 3
      if (bytes > maximumFrameBytes) return bytes
    }
    return bytes
  }

  function _takePending(id) {
    var item = pending[id]
    if (!item) return null
    var next = {}
    for (var key in pending) if (key !== id) next[key] = pending[key]
    pending = next
    return item
  }

  function _failPending(code, message) {
    var current = pending
    pending = ({})
    for (var id in current) {
      var item = current[id]
      if (item.callback) item.callback(null, { code: code, message: message, retryable: true })
    }
  }

  function _receive(raw) {
    if (_utf8Size(raw) > maximumFrameBytes) {
      transportFailureDetail = "The daemon sent an oversized response"
      _setState("error", transportFailureDetail)
      socket.connected = false
      return
    }
    var message
    try {
      message = JSON.parse(String(raw))
    } catch (error) {
      transportFailureDetail = "The daemon sent invalid JSON"
      _setState("error", transportFailureDetail)
      socket.connected = false
      return
    }
    if (!_object(message)) {
      transportFailureDetail = "The daemon sent an invalid response"
      _setState("error", transportFailureDetail)
      socket.connected = false
      return
    }
    if (message.event) {
      _handleNotification(String(message.event), message.data || {})
      return
    }
    var item = _takePending(String(message.id || ""))
    if (!item || !item.callback) return
    item.callback(message.result === undefined ? null : message.result, message.error || null)
  }

  function _receiveChunk(data) {
    receiveBuffer += String(data || "")
    var newline = receiveBuffer.indexOf("\n")
    while (newline !== -1) {
      var frame = receiveBuffer.slice(0, newline)
      receiveBuffer = receiveBuffer.slice(newline + 1)
      if (frame !== "") _receive(frame)
      if (!socket.connected) return
      newline = receiveBuffer.indexOf("\n")
    }
    if (_utf8Size(receiveBuffer) > maximumFrameBytes) {
      transportFailureDetail = "The daemon sent an oversized response"
      receiveBuffer = ""
      _setState("error", transportFailureDetail)
      socket.connected = false
    }
  }

  function _handleNotification(event, data) {
    var syncStatusChanged = event === "sync.statusChanged" || event === "sync.changed"
    var relevant = event === "widget.changed" || event === "events.changed" || event === "calendars.changed"
      || event === "calendarSets.changed"
      || event === "conflicts.changed" || event === "operations.changed"
      || syncStatusChanged
    if (!relevant) return

    // Sync state is maintained outside the database revision. A conditional
    // snapshot could therefore report `unchanged` while its syncing, auth, or
    // offline presentation status has changed. Always request a full snapshot
    // for the daemon's authoritative event (and the legacy alias).
    if (syncStatusChanged) {
      forceNextSnapshot = true
      notificationRefresh.restart()
      return
    }

    var incomingRevision = Number(data && data.revision || 0)
    if (incomingRevision && incomingRevision <= revision && !needsBaseline) return
    if (needsBaseline || (incomingRevision && incomingRevision > revision + 1))
      forceNextSnapshot = true
    notificationRefresh.restart()
  }

  function _negotiate() {
    _setState("negotiating", "Checking OmaCalendar compatibility…")
    _request("system.info", {}, function(result, error) {
      if (error) {
        if (error.code === "protocol_mismatch" || error.code === "unsupported_protocol"
            || error.code === "incompatible_protocol") {
          _setState("incompatible", "OmaCalendar IPC 2 is required")
          socket.connected = false
        } else {
          _setState("error", String(error.message || "Compatibility check failed"))
          socket.connected = false
        }
        return
      }
      var major = Number(result && result.protocolMajor)
      var minor = Number(result && result.protocolMinor)
      if (!isFinite(major) || !isFinite(minor)) {
        _setState("incompatible", "The daemon did not report a valid IPC version")
        socket.connected = false
        return
      }
      if (major !== protocolMajor || minor < minimumProtocolMinor) {
        _setState("incompatible", "Daemon protocol " + major + "." + minor + " is incompatible; this widget needs 2.0+")
        socket.connected = false
        return
      }
      serverInfo = result || {}
      methods = Array.isArray(result.methods) ? result.methods : []
      if (!supports("widget.snapshot")) {
        _setState("incompatible", "The daemon does not provide widget.snapshot")
        socket.connected = false
        return
      }
      retryAttempt = 0
      needsBaseline = true
      cacheStale = true
      snapshotQueryKey = ""
      forceNextSnapshot = true
      _setState("ready", "Connected")
      if (supports("system.subscribe")) {
        _request("system.subscribe", { topics: ["widget", "events", "calendars", "calendarSets", "conflicts", "operations", "sync"], sinceRevision: revision }, function(result, subscribeError) {
          if (subscribeError) {
            root.stateDetail = "Live updates unavailable; polling for changes"
            root.forceNextSnapshot = true
            return
          }
          var subscribedRevision = Number(result && result.revision || 0)
          if (subscribedRevision && subscribedRevision > root.revision + 1)
            root.forceNextSnapshot = true
        })
      }
      refreshSnapshot(lastSelection, true)
    })
  }

  function _finishSnapshotRequest() {
    activeSnapshotRequest = ""
    if (!snapshotRefreshQueued) return
    snapshotRefreshQueued = false
    Qt.callLater(function() {
      if (root.connectionState === "ready") root.refreshSnapshot(root.lastSelection)
    })
  }

  function _snapshotError(message, retryFull) {
    cacheStale = true
    stateDetail = String(message || "Could not refresh calendar")
    if (retryFull) forceNextSnapshot = true
  }

  function refreshSnapshot(selection, forceFull) {
    if (selection) lastSelection = selection
    if (connectionState !== "ready" || !supports("widget.snapshot")) return
    var requestFull = forceFull === true || forceNextSnapshot || needsBaseline
    if (activeSnapshotRequest !== "") {
      snapshotRefreshQueued = true
      if (requestFull) forceNextSnapshot = true
      return
    }
    var params = {}
    for (var key in lastSelection) params[key] = lastSelection[key]
    var queryKey = JSON.stringify(lastSelection)
    if (!requestFull && revision > 0 && queryKey === snapshotQueryKey) params.sinceRevision = revision
    if (requestFull) forceNextSnapshot = false
    activeSnapshotRequest = _request("widget.snapshot", params, function(result, error) {
      if (error) {
        root._snapshotError(error.message, requestFull)
        root._finishSnapshotRequest()
        return
      }
      if (!result || typeof result !== "object") {
        root._snapshotError("The daemon returned an invalid calendar snapshot", requestFull)
        root._finishSnapshotRequest()
        return
      }
      var incomingRevision = Number(result.revision)
      if (!isFinite(incomingRevision) || incomingRevision < 0) {
        root._snapshotError("The daemon returned an invalid snapshot revision", requestFull)
        root._finishSnapshotRequest()
        return
      }
      if (result.unchanged === true) {
        if (requestFull || root.needsBaseline) {
          root._snapshotError("The daemon returned no baseline after reconnecting", true)
          root._finishSnapshotRequest()
          return
        }
        if (incomingRevision < root.revision) {
          root._snapshotError("Ignored an out-of-order calendar snapshot", true)
          root._finishSnapshotRequest()
          return
        }
        if (incomingRevision > root.revision) {
          var retained = {}
          for (var retainedKey in root.snapshot) retained[retainedKey] = root.snapshot[retainedKey]
          retained.revision = incomingRevision
          root.snapshot = retained
          root.snapshotUpdated()
        }
        root.snapshotQueryKey = queryKey
        root.cacheStale = !!root.snapshot.stale
        root.stateDetail = root.snapshot.stale ? "Showing cached events" : "Connected"
        root._finishSnapshotRequest()
        return
      }
      if (!root.needsBaseline && incomingRevision < root.revision) {
        root._snapshotError("Ignored an out-of-order calendar snapshot", true)
        root._finishSnapshotRequest()
        return
      }
      if (!root._validateSnapshot(result)) {
        root._snapshotError("The daemon returned an invalid calendar snapshot", requestFull)
        root._finishSnapshotRequest()
        return
      }
      root.snapshot = result
      root.snapshotQueryKey = queryKey
      root.needsBaseline = false
      root.cacheStale = !!result.stale
      root.stateDetail = result.stale ? "Showing cached events" : "Connected"
      root.snapshotUpdated()
      root._finishSnapshotRequest()
    }, 10000)
  }

  function _mutation(method, params, action, callback) {
    if (activeMutationId !== "") {
      var busy = "A calendar change is already in progress"
      lastActionError = busy
      actionFailed(action, busy)
      if (callback) callback(null, { code: "mutation_in_progress", message: busy, retryable: true })
      return
    }
    if (!supports(method)) {
      var unsupported = "This daemon does not support " + method
      lastActionError = unsupported
      actionFailed(action, unsupported)
      return
    }
    var payload = params || {}
    if (!payload.clientMutationId) payload.clientMutationId = Model.clientMutationId()
    var validationError = _validateMutation(method, payload)
    if (validationError) {
      lastActionError = validationError
      actionFailed(action, validationError)
      if (callback) callback(null, { code: "invalid_params", message: validationError, retryable: false })
      return
    }
    activeMutationId = payload.clientMutationId
    lastActionError = ""
    _request(method, payload, function(result, error) {
      if (activeMutationId === payload.clientMutationId) activeMutationId = ""
      if (error) {
        lastActionError = String(error.message || "Action failed")
        actionFailed(action, lastActionError)
        if (callback) callback(null, error)
        return
      }
      if (result && result.undoToken) {
        undoToken = String(result.undoToken)
        undoLabel = String(result.undoLabel || "Undo delete")
        undoExpiry.restart()
      }
      actionSucceeded(action, result || {})
      if (callback) callback(result || {}, null)
      notificationRefresh.restart()
    }, 15000)
  }

  function _recurrenceScope(scope) {
    var value = String(scope || "series")
    if (value === "this" || value === "this_occurrence") return "occurrence"
    if (value === "this_and_future") return "future"
    if (value === "entire_series") return "series"
    return value
  }

  function _eventReference(event) {
    var reference = { eventId: String(event && event.id || "") }
    // IPC accepts recurrenceId, not the widget's older occurrenceStart alias.
    // The daemon's presentation DTO currently exposes the latter, so retain it
    // as a compatibility source until recurrenceId is provided directly.
    var recurrenceId = String(event && (event.recurrenceId || event.occurrenceId
      || event.occurrenceStart) || "")
    if (recurrenceId) reference.recurrenceId = recurrenceId
    return reference
  }

  function createEvent(draft, guestPolicy, callback) {
    _mutation("events.create", {
      expectedLocalRevision: 0,
      recurrenceScope: "series",
      guestNotificationPolicy: guestPolicy || "none",
      draft: draft
    }, "create", callback)
  }

  function updateEvent(event, patch, scope, guestPolicy, callback) {
    _mutation("events.update", {
      expectedLocalRevision: Number(event.localRevision || 0),
      eventRef: _eventReference(event),
      recurrenceScope: _recurrenceScope(scope),
      guestNotificationPolicy: guestPolicy || "none",
      patch: patch
    }, "update", callback)
  }

  function removeEvent(event, scope, guestPolicy, callback) {
    _mutation("events.remove", {
      expectedLocalRevision: Number(event.localRevision || 0),
      eventRef: _eventReference(event),
      recurrenceScope: _recurrenceScope(scope),
      guestNotificationPolicy: guestPolicy || "none"
    }, "remove", callback)
  }

  function moveEvent(event, draft, scope, guestPolicy, callback) {
    _mutation("events.move", {
      expectedLocalRevision: Number(event.localRevision || 0),
      eventRef: _eventReference(event),
      targetCalendarId: String(draft.calendarId || ""),
      draft: draft,
      recurrenceScope: _recurrenceScope(scope),
      guestNotificationPolicy: guestPolicy || "none",
      // Cross-account moves are deliberately handed to the desktop app, which
      // obtains explicit confirmation before enqueueing its create-then-delete
      // transaction. This compact surface only sends same-account moves.
      confirmedCrossProvider: false
    }, "move", callback)
  }

  function respondToEvent(event, response, scope, guestPolicy, callback) {
    _mutation("events.respond", {
      expectedLocalRevision: Number(event.localRevision || 0),
      eventRef: _eventReference(event),
      recurrenceScope: _recurrenceScope(scope || "this"),
      guestNotificationPolicy: guestPolicy || "all",
      response: response
    }, "respond", callback)
  }

  function activateCalendarSet(id) {
    _mutation("calendarSets.activate", { calendarSetId: String(id) }, "activate-calendar-set")
  }

  function retryOperation(id) {
    _mutation("operations.retry", { operationId: Number(id) }, "retry-operation")
  }

  function syncNow() {
    if (!supports("sync.all")) {
      lastActionError = "This daemon does not support sync.all"
      actionFailed("sync", lastActionError)
      return
    }
    _request("sync.all", {}, function(result, error) {
      if (error) {
        lastActionError = String(error.message || "Sync could not start")
        actionFailed("sync", lastActionError)
        return
      }
      actionSucceeded("sync", result || {})
      notificationRefresh.restart()
    }, 15000)
  }

  function undo() {
    if (!undoToken) return
    var token = undoToken
    undoToken = ""
    undoExpiry.stop()
    _mutation("events.undo", { undoToken: token }, "undo")
  }

  function openDeepLink(path) {
    var suffix = String(path || "")
    if (suffix.charAt(0) === "/") suffix = suffix.slice(1)
    Quickshell.execDetached(["uwsm-app", "--", "omacalendar", "omacalendar://" + suffix])
  }

  Socket {
    id: socket
    path: root.socketPath
    parser: SplitParser {
      // Receive raw chunks so an unterminated peer frame cannot grow inside
      // SplitParser beyond the widget's own frame limit.
      splitMarker: ""
      onRead: function(data) { root._receiveChunk(data) }
    }
    onConnectionStateChanged: {
      if (connected) {
        root.needsBaseline = true
        root.cacheStale = true
        root.forceNextSnapshot = true
        root._negotiate()
      } else {
        root.receiveBuffer = ""
        root.methods = []
        root.serverInfo = ({})
        root.needsBaseline = true
        root.cacheStale = true
        root.forceNextSnapshot = true
        root._failPending("daemon_unavailable", "OmaCalendar service disconnected")
        if (root.connectionState !== "incompatible") {
          var detail = root.transportFailureDetail || (root.snapshot && root.snapshot.revision ? "Service unavailable; showing the last snapshot" : "OmaCalendar service is not running")
          root.transportFailureDetail = ""
          root._setState("missing", detail)
          root._scheduleReconnect()
        }
      }
    }
    onError: {
      if (root.connectionState !== "incompatible") {
        var detail = root.transportFailureDetail || (root.snapshot && root.snapshot.revision ? "Service unavailable; showing the last snapshot" : "OmaCalendar service is not running")
        root.transportFailureDetail = ""
        root._setState("missing", detail)
        // A failed connect does not always produce a second connected-state
        // transition in Quickshell. Re-arm here as well as from the normal
        // disconnect path so a daemon that starts after the widget can still
        // be discovered without reopening the shell.
        root._scheduleReconnect()
      }
    }
  }

  Timer {
    id: retryTimer
    interval: 1000
    onTriggered: root.connectNow()
  }

  Timer {
    id: notificationRefresh
    interval: 120
    onTriggered: root.refreshSnapshot(root.lastSelection)
  }

  Timer {
    interval: Math.max(15000, root.pollIntervalMs)
    repeat: true
    running: root.connectionState === "ready"
    onTriggered: root.refreshSnapshot(root.lastSelection)
  }

  Timer {
    id: timeoutSweep
    interval: 500
    repeat: true
    running: true
    onTriggered: {
      var now = Date.now()
      var expired = []
      for (var id in root.pending) if (Number(root.pending[id].deadline) <= now) expired.push(id)
      for (var index = 0; index < expired.length; index++) {
        var item = root._takePending(expired[index])
        if (item && item.callback) item.callback(null, { code: "timeout", message: item.method + " timed out", retryable: true })
      }
    }
  }

  Timer {
    id: undoExpiry
    interval: 10000
    onTriggered: {
      root.undoToken = ""
      root.undoLabel = ""
    }
  }

  Component.onCompleted: connectNow()
}
