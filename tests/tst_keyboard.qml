import QtQuick
import QtTest
import qs.Ui

TestCase {
  id: testCase
  name: "WidgetKeyboard"
  when: windowShown
  width: 320
  height: 240

  PanelKeyCatcher {
    id: catcher
    anchors.fill: parent
  }

  SignalSpy { id: moveSpy; target: catcher; signalName: "moveRequested" }
  SignalSpy { id: activateSpy; target: catcher; signalName: "activateRequested" }
  SignalSpy { id: closeSpy; target: catcher; signalName: "closeRequested" }
  SignalSpy { id: tabSpy; target: catcher; signalName: "tabRequested" }

  function init() {
    moveSpy.clear()
    activateSpy.clear()
    closeSpy.clear()
    tabSpy.clear()
    catcher.blocked = false
    catcher.forceActiveFocus()
    tryCompare(catcher, "activeFocus", true)
  }

  function test_arrow_navigation() {
    keyClick(Qt.Key_Right)
    compare(moveSpy.count, 1)
    compare(moveSpy.signalArguments[0][0], 1)
    compare(moveSpy.signalArguments[0][1], 0)

    keyClick(Qt.Key_Up)
    compare(moveSpy.count, 2)
    compare(moveSpy.signalArguments[1][0], 0)
    compare(moveSpy.signalArguments[1][1], -1)
  }

  function test_activate_close_and_tab() {
    keyClick(Qt.Key_Return)
    compare(activateSpy.count, 1)
    keyClick(Qt.Key_Escape)
    compare(closeSpy.count, 1)
    keyClick(Qt.Key_Tab)
    compare(tabSpy.count, 1)
    compare(tabSpy.signalArguments[0][0], 1)
  }

  function test_blocked_forwards_without_panel_actions() {
    catcher.blocked = true
    keyClick(Qt.Key_Right)
    keyClick(Qt.Key_Return)
    keyClick(Qt.Key_Escape)
    compare(moveSpy.count, 0)
    compare(activateSpy.count, 0)
    compare(closeSpy.count, 0)
  }
}
