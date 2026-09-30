import QtQuick
import Quickshell
import ".." as Oma

ShellRoot {
  id: root

  property int phase: 0

  component TestBar: QtObject {
    property string position: "top"
    property bool vertical: false
    property int barSize: 40
    property color foreground: "#eeeeee"
    property color barForeground: foreground
    property color urgent: "#ff5555"
    property string fontFamily: "monospace"
    property bool foregroundAnimationEnabled: false
    property var activePopout: null
    property bool centerHoverRevealSuppressed: false
    property var clickTargets: []

    function setCenterHoverRevealSuppressed(value) { centerHoverRevealSuppressed = !!value }
    function registerClickTarget(target) {
      if (clickTargets.indexOf(target) === -1) clickTargets = clickTargets.concat([target])
    }
    function unregisterClickTarget(target) {
      clickTargets = clickTargets.filter(function(item) { return item !== target })
    }
    function showTooltip(target, text) {}
    function hideTooltip(target) {}
    function moduleWidgets(moduleName) { return [] }
    function requestPopout(owner) { activePopout = owner }
    function releasePopout(owner) { if (activePopout === owner) activePopout = null }
    function switchPanelFrom(owner, direction) { return false }
  }

  TestBar { id: bar }

  Item {
    Oma.BarWidget {
      id: widget
      bar: bar
      settings: ({ socketPath: Quickshell.env("OMACALENDAR_TEST_SOCKET") })
    }
  }

  function fail(message) {
    console.error("TASKS_PANEL_TEST_FAIL: " + message)
    Qt.quit()
  }

  function panel() {
    for (var index = 0; index < widget.children.length; index++) {
      var child = widget.children[index]
      if (child && child.item && "bodyViewportHeight" in child.item) return child.item
    }
    return null
  }

  function taskIds(target) {
    return target.openTasks.map(function(task) { return task.id }).join(",")
  }

  Connections {
    target: root.panel() ? root.panel().client : null
    function onActionFailed(action, message) {
      root.fail(action + ": " + message)
    }
  }

  Timer {
    interval: 100
    repeat: true
    running: true
    onTriggered: {
      var target = root.panel()
      if (!target || target.client.tasks.length === 0) return

      if (root.phase === 0) {
        if (!target.tasksAvailable) {
          root.fail("an IPC 2.2 daemon did not enable the Tasks view")
          return
        }
        target.setViewMode("tasks")
        if (target.viewMode !== "tasks") {
          root.fail("the Tasks view did not open")
          return
        }
        if (root.taskIds(target) !== "task-overdue,task-shared,task-undated") {
          root.fail("unexpected open tasks: " + root.taskIds(target))
          return
        }
        if (target.selectedTaskIndex !== 0 || target.dueTaskCount !== 2) {
          root.fail("task selection or due count is wrong")
          return
        }
        if (target.newTaskListId !== "local-tasks" || !target.canAddTask) {
          root.fail("new tasks do not go to the device list")
          return
        }
        root.phase = 1
        return
      }

      if (root.phase === 1) {
        // Wait for the view to lay out before measuring it.
        if (target.bodyContentHeight > target.bodyViewportHeight + 1) {
          root.fail("the Tasks view clips the panel body")
          return
        }
        target.moveCursor(0, 1)
        if (target.selectedTask.id !== "task-shared") {
          root.fail("arrow keys did not move the task selection")
          return
        }
        // The shared list is read-only: completing it must not reach the
        // daemon, whose fixture rejects any envelope but task-overdue's.
        target.completeSelectedTask()
        if (target.client.activeMutationId !== "") {
          root.fail("a read-only task was sent for completion")
          return
        }
        target.moveCursor(0, -1)
        target.completeSelectedTask()
        root.phase = 2
        return
      }

      if (root.phase === 2 && root.taskIds(target) === "task-shared,task-undated") {
        if (target.selectedTask.id !== "task-shared") {
          root.fail("selection did not move to the next task after completion")
          return
        }
        console.log("TASKS_PANEL_TEST_PASS")
        Qt.quit()
      }
    }
  }

  Timer {
    interval: 10000
    running: true
    onTriggered: root.fail("timed out in phase " + root.phase)
  }
}
