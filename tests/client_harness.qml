import QtQuick
import Quickshell
import ".."
import "../CalendarModel.js" as Model

Item {
  id: root

  property string scenario: Quickshell.env("OMACALENDAR_TEST_SCENARIO") || "happy"
  property int phase: 0
  property bool sawMissingWithCache: false
  property bool sawDuplicateRejected: false
  property bool sawInvalidTaskRejected: false
  property bool sawServiceMissing: false

  function fail(message) {
    console.error("CLIENT_TEST_FAIL [" + scenario + "]: " + message)
    Qt.quit()
  }

  function pass() {
    console.log("CLIENT_TEST_PASS [" + scenario + "]")
    Qt.quit()
  }

  function validBaseline(client) {
    return client.revision === 7 && client.snapshot.events.length === 1
      && client.snapshot.events[0].title === "Fixture event"
      && client.snapshot.currentEvent.title === "Current fixture"
  }

  OmaCalendarClient {
    id: client
    socketPath: Quickshell.env("OMACALENDAR_TEST_SOCKET")
    pollIntervalMs: 15000
  }

  Connections {
    target: client

    function onConnectionStateChanged() {
      if (client.connectionState === "missing") root.sawServiceMissing = true
      if (root.scenario === "invalid-response" && client.connectionState === "missing") {
        if (client.stateDetail.indexOf("invalid response") === -1)
          root.fail("non-object JSON response was not rejected")
        else root.pass()
        return
      }
      if (root.scenario === "oversized-frame" && client.connectionState === "missing") {
        if (client.stateDetail.indexOf("oversized response") === -1)
          root.fail("oversized unterminated frame did not report its transport failure")
        else root.pass()
        return
      }
      if (root.scenario === "incompatible" && client.connectionState === "incompatible") {
        if (client.stateDetail.indexOf("incompatible") === -1) {
          root.fail("protocol mismatch did not explain the incompatibility")
          return
        }
        root.pass()
        return
      }

      if ((root.scenario === "offline" || root.scenario === "restart")
          && client.connectionState === "missing" && root.phase >= 1) {
        if (!root.validBaseline(client) || !client.stale) {
          root.fail("disconnect did not retain and mark the last snapshot stale")
          return
        }
        root.sawMissingWithCache = true
        if (root.scenario === "offline") root.pass()
      }
    }

    function onStateDetailChanged() {
      if (root.scenario === "invalid-snapshot"
          && client.stateDetail.indexOf("invalid calendar snapshot") !== -1)
        root.pass()
    }

    function onSnapshotUpdated() {
      if (client.connectionState !== "ready") {
        root.fail("snapshot arrived outside the ready state")
        return
      }
      if (!client.supports("widget.snapshot") || !client.supports("events.create")) {
        root.fail("capabilities were not negotiated")
        return
      }

      if (root.scenario === "late-start") {
        if (!root.sawServiceMissing) root.fail("the first connection unexpectedly found the daemon")
        else if (!root.validBaseline(client)) root.fail("late-start baseline was invalid")
        else root.pass()
        return
      }

      if (root.scenario === "ipc-2-1") {
        if (client.tasksSupported || client.taskLists.length !== 0 || client.tasks.length !== 0) {
          root.fail("an IPC 2.1 daemon was treated as offering tasks")
        } else if (client.stateDetail.indexOf("Live updates unavailable") !== -1) {
          root.fail("the widget subscribed an IPC 2.1 daemon to the tasks topic")
        } else {
          root.pass()
        }
        return
      }

      if (root.scenario === "all-day-single-day") {
        var gameEvent = client.snapshot.events.find(function(event) {
          return event.id === "game-1"
        })
        if (!gameEvent) {
          root.fail("single-day all-day event was dropped from the snapshot")
        } else {
          root.pass()
        }
        return
      }

      if (root.scenario === "gap") {
        if (client.revision === 7 && root.phase === 0) {
          if (!root.validBaseline(client)) root.fail("gap baseline was invalid")
          else root.phase = 1
          return
        }
        if (client.revision === 10 && root.phase === 1) {
          if (client.snapshot.events[0].title !== "Gap recovered") {
            root.fail("full recovery snapshot was not installed")
            return
          }
          root.pass()
        }
        return
      }

      if (root.scenario === "restart") {
        if (client.revision === 7 && root.phase === 0) {
          if (!root.validBaseline(client)) root.fail("restart baseline was invalid")
          else root.phase = 1
          return
        }
        if (client.revision === 9 && root.phase === 1) {
          if (!root.sawMissingWithCache) {
            root.fail("reconnect skipped the observable cached-offline state")
            return
          }
          if (client.snapshot.events[0].title !== "Restart recovered" || client.stale) {
            root.fail("restarted daemon did not replace the stale baseline")
            return
          }
          root.pass()
        }
        return
      }

      if (root.scenario === "offline") {
        if (root.phase === 0) {
          if (!root.validBaseline(client)) root.fail("offline baseline was invalid")
          else root.phase = 1
        }
        return
      }

      if (root.scenario === "mutation-contract") {
        if (root.phase !== 0 || !root.validBaseline(client)) return
        root.phase = 1
        client.updateEvent({
          id: "event-1",
          localRevision: 7,
          occurrenceStart: "2026-08-28T13:00:00Z"
        }, { title: "Updated from widget" }, "this", "none")
        return
      }

      if (root.scenario === "duplicate-mutation") {
        if (root.phase !== 0 || !root.validBaseline(client)) return
        root.phase = 1
        var draft = {
          calendarId: "local",
          title: "Created once",
          start: "2026-08-28T15:00:00Z",
          end: "2026-08-28T16:00:00Z",
          allDay: false
        }
        client.createEvent(draft, "none")
        client.createEvent(draft, "none")
        return
      }

      if (root.scenario === "sync-status") {
        if (client.revision !== 7) {
          root.fail("sync-only status changes unexpectedly changed the database revision")
          return
        }
        var status = client.snapshot.status || {}
        if (root.phase === 0 && client.snapshot.events[0].title === "Sync baseline"
            && status.online === true && status.syncing === false) {
          root.phase = 1
        } else if (root.phase === 1 && client.snapshot.events[0].title === "Sync started"
                   && status.syncing === true) {
          root.phase = 2
        } else if (root.phase === 2 && client.snapshot.events[0].title === "Sync finished"
                   && status.syncing === false && status.lastSyncResult === "ok") {
          root.phase = 3
        } else if (root.phase === 3 && client.snapshot.events[0].title === "Authentication required"
                   && status.reauthorizationRequired === true) {
          root.phase = 4
        } else if (root.phase === 4 && client.snapshot.events[0].title === "Provider offline"
                   && status.online === false && status.offline === true) {
          root.pass()
        } else {
          root.fail("sync.statusChanged did not install the expected full status snapshot in phase " + root.phase)
        }
        return
      }

      if ((root.scenario !== "happy" && root.scenario !== "fragmented") || root.phase !== 0) return
      if (!root.validBaseline(client)) {
        root.fail("snapshot presentation data was not decoded")
        return
      }
      root.phase = 1
      client.createEvent({
        calendarId: "local",
        title: "Created from widget",
        start: "2026-08-28T15:00:00Z",
        end: "2026-08-28T16:00:00Z",
        allDay: false
      }, "none")
    }

    function onTasksUpdated() {
      if (root.scenario !== "tasks") return
      var ids = client.tasks.map(function(task) { return task.id })
      if (root.phase === 0) {
        if (ids.join(",") !== "task-overdue,task-shared,task-undated,task-hidden") {
          root.fail("paged task read was incomplete: " + ids.join(","))
          return
        }
        var rows = Model.taskRows(client.tasks, client.taskLists, "2026-08-28")
        var shown = rows.filter(function(row) { return row.kind === "task" })
          .map(function(row) { return row.task.id })
        if (shown.join(",") !== "task-overdue,task-shared,task-undated") {
          root.fail("disabled task lists were not left out: " + shown.join(","))
          return
        }
        root.phase = 1
        client.createTask("   ", "local-tasks", "")
        if (!root.sawInvalidTaskRejected) {
          root.fail("a blank task title reached the daemon")
          return
        }
        client.setTaskCompleted(client.tasks[0], true)
      } else if (root.phase === 2) {
        if (ids.indexOf("task-overdue") !== -1) return
        root.phase = 3
        client.createTask("Created task", "local-tasks", "")
      } else if (root.phase === 4) {
        if (ids.indexOf("task-created") !== -1) root.pass()
      }
    }

    function onActionSucceeded(action, result) {
      if (root.scenario === "tasks") {
        if (root.phase === 1 && action === "complete-task") root.phase = 2
        else if (root.phase === 3 && action === "create-task") root.phase = 4
        return
      }
      if (root.scenario === "duplicate-mutation" && action === "create") {
        if (!root.sawDuplicateRejected) root.fail("second create was not rejected while the first was pending")
        else root.pass()
        return
      }
      if (root.scenario === "mutation-contract") {
        if (root.phase === 1 && action === "update") {
          root.phase = 2
          client.respondToEvent({
            id: "event-1",
            localRevision: 7,
            occurrenceStart: "2026-08-28T13:00:00Z"
          }, "accepted", "this", "all")
        } else if (root.phase === 2 && action === "respond") {
          root.phase = 3
          client.moveEvent({
            id: "event-1",
            localRevision: 7,
            occurrenceStart: "2026-08-28T13:00:00Z"
          }, {
            calendarId: "local-2",
            title: "Moved from widget",
            start: "2026-08-28T13:00:00Z",
            end: "2026-08-28T14:00:00Z"
          }, "this", "none")
        } else if (root.phase === 3 && action === "move") {
          root.phase = 4
          client.removeEvent({
            id: "event-1",
            localRevision: 7,
            occurrenceStart: "2026-08-28T13:00:00Z"
          }, "this", "none")
        } else if (root.phase === 4 && action === "remove") {
          root.phase = 5
          client.activateCalendarSet("set-all")
        } else if (root.phase === 5 && action === "activate-calendar-set") {
          root.phase = 6
          client.retryOperation("42")
        } else if (root.phase === 6 && action === "retry-operation") {
          root.pass()
        }
        return
      }
      if (root.scenario !== "happy" && root.scenario !== "fragmented") return
      if (root.phase === 1 && action === "create") {
        root.phase = 2
        client.removeEvent({ id: "event-1", localRevision: 3 }, "series", "none")
      } else if (root.phase === 2 && action === "remove") {
        if (client.undoToken !== "undo-fixture") {
          root.fail("delete did not expose the undo token")
          return
        }
        root.phase = 3
        client.undo()
      } else if (root.phase === 3 && action === "undo") {
        root.phase = 4
        root.pass()
      }
    }

    function onActionFailed(action, message) {
      if (root.scenario === "tasks" && root.phase === 1 && action === "create-task"
          && message.indexOf("missing") !== -1) {
        root.sawInvalidTaskRejected = true
        return
      }
      if (root.scenario === "duplicate-mutation" && action === "create"
          && message.indexOf("already in progress") !== -1) {
        root.sawDuplicateRejected = true
        return
      }
      root.fail(action + ": " + message)
    }
  }

  Timer {
    interval: 12000
    running: true
    onTriggered: root.fail("timed out in phase " + root.phase + " (" + client.connectionState + ")")
  }
}
