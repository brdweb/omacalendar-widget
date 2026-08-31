import QtQuick
import Quickshell

ShellRoot {
  Loader {
    active: true
    source: Quickshell.env("OMACALENDAR_WIDGET_ENTRY")
  }
}
