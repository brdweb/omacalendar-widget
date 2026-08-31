#!/usr/bin/env python3
"""Serve a deterministic, presentation-only snapshot for preview capture."""

from __future__ import annotations

import json
import os
import signal
import socket
import sys
from typing import Any


METHODS = [
    "system.info",
    "system.subscribe",
    "widget.snapshot",
    "events.create",
    "events.update",
    "events.move",
    "events.remove",
    "events.undo",
    "events.respond",
    "calendarSets.activate",
    "sync.all",
]


def event(
    event_id: str,
    calendar_id: str,
    title: str,
    start: str,
    end: str,
    **extra: Any,
) -> dict[str, Any]:
    value: dict[str, Any] = {
        "id": event_id,
        "localRevision": 1,
        "calendarId": calendar_id,
        "title": title,
        "start": start,
        "end": end,
    }
    value.update(extra)
    return value


def preview_snapshot() -> dict[str, Any]:
    events = [
        {
            "id": "release-milestone",
            "localRevision": 1,
            "calendarId": "projects",
            "title": "Release milestone",
            "allDay": True,
            "startDate": "2026-08-31",
            "endDate": "2026-09-01",
        },
        event(
            "design-review",
            "projects",
            "Design review",
            "2026-08-31T09:00:00-04:00",
            "2026-08-31T10:00:00-04:00",
            location="Studio A",
        ),
        event(
            "product-planning",
            "projects",
            "Product planning",
            "2026-08-31T11:00:00-04:00",
            "2026-08-31T12:00:00-04:00",
        ),
        event(
            "focus-block",
            "personal",
            "Focus block",
            "2026-08-31T14:00:00-04:00",
            "2026-08-31T15:30:00-04:00",
        ),
        event(
            "weekly-sync",
            "projects",
            "Weekly sync",
            "2026-09-01T10:00:00-04:00",
            "2026-09-01T10:30:00-04:00",
            recurring=True,
        ),
        event(
            "coffee-walk",
            "personal",
            "Coffee walk",
            "2026-09-03T08:30:00-04:00",
            "2026-09-03T09:00:00-04:00",
        ),
        event(
            "project-demo",
            "projects",
            "Project demo",
            "2026-09-08T13:00:00-04:00",
            "2026-09-08T14:00:00-04:00",
        ),
        event(
            "deep-work",
            "personal",
            "Deep work",
            "2026-09-16T09:00:00-04:00",
            "2026-09-16T11:00:00-04:00",
        ),
        event(
            "roadmap-review",
            "projects",
            "Roadmap review",
            "2026-09-24T15:00:00-04:00",
            "2026-09-24T16:00:00-04:00",
        ),
    ]
    current = event(
        "current-preview",
        "projects",
        "Design review",
        "2026-08-31T10:00:00-04:00",
        "2026-08-31T10:45:00-04:00",
    )
    upcoming = event(
        "up-next-preview",
        "projects",
        "Product planning",
        "2026-08-31T11:00:00-04:00",
        "2026-08-31T12:00:00-04:00",
    )
    return {
        "revision": 1,
        "generatedAt": "2026-08-31T14:15:00Z",
        "stale": False,
        "status": {"online": True, "syncing": False},
        "activeCalendarSet": {"id": "all", "name": "All Calendars"},
        "calendarSets": [{"id": "all", "name": "All Calendars"}],
        "defaultCalendarId": "projects",
        "calendars": [
            {
                "id": "projects",
                "name": "Projects",
                "color": "#7aa2f7",
                "writable": True,
            },
            {
                "id": "personal",
                "name": "Personal",
                "color": "#9ece6a",
                "writable": True,
            },
        ],
        "events": events,
        "currentEvent": current,
        "upNext": upcoming,
        "invitations": [],
        "conflicts": [],
        "operations": [],
    }


def frame(payload: dict[str, Any]) -> bytes:
    return (json.dumps(payload, separators=(",", ":")) + "\n").encode("utf-8")


def response(request_id: Any, result: Any) -> bytes:
    return frame({"id": request_id, "result": result})


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit("usage: fake_preview_daemon.py SOCKET_PATH")

    socket_path = sys.argv[1]
    try:
        os.unlink(socket_path)
    except FileNotFoundError:
        pass

    server = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    server.bind(socket_path)
    os.chmod(socket_path, 0o600)
    server.listen(1)

    def stop(_signum: int, _frame: object) -> None:
        server.close()
        try:
            os.unlink(socket_path)
        except FileNotFoundError:
            pass
        raise SystemExit(0)

    signal.signal(signal.SIGINT, stop)
    signal.signal(signal.SIGTERM, stop)

    snapshot = preview_snapshot()
    while True:
        connection, _ = server.accept()
        with connection, connection.makefile("rb") as stream:
            for line in stream:
                message = json.loads(line)
                method = message.get("method")
                if method == "system.info":
                    result: Any = {
                        "server": "omacalendard-preview-fixture",
                        "protocolMajor": 2,
                        "protocolMinor": 0,
                        "methods": METHODS,
                    }
                elif method == "system.subscribe":
                    result = {"subscribed": True, "revision": 1}
                elif method == "widget.snapshot":
                    result = snapshot
                elif method == "sync.all":
                    result = {"started": True}
                else:
                    result = {"ok": True}
                try:
                    connection.sendall(response(message.get("id"), result))
                except (BrokenPipeError, ConnectionResetError):
                    break


if __name__ == "__main__":
    main()
