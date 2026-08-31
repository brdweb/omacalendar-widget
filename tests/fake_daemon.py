#!/usr/bin/env python3
"""Stateful IPC 2 fixtures for the QML socket-client contract tests."""

from __future__ import annotations

import json
import os
import signal
import socket
import sys
import time
from dataclasses import dataclass
from typing import Any


def frame(payload: dict[str, Any]) -> bytes:
    return (json.dumps(payload, separators=(",", ":")) + "\n").encode()


def response(request_id: object, result: object = None, error: object = None) -> bytes:
    payload: dict[str, object] = {"id": request_id}
    if error is not None:
        payload["error"] = error
    else:
        payload["result"] = result
    return frame(payload)


def snapshot(
    revision: int,
    title: str = "Fixture event",
    stale: bool = False,
    status: dict[str, Any] | None = None,
) -> dict[str, Any]:
    return {
        "revision": revision,
        "generatedAt": "2026-08-28T12:00:00Z",
        "stale": stale,
        "status": status if status is not None else {"online": not stale},
        "activeCalendarSet": {"id": "set-all", "name": "All"},
        "calendarSets": [{"id": "set-all", "name": "All"}],
        "calendars": [
            {
                "id": "local",
                "name": "Local",
                "color": "#7aa2f7",
                "writable": True,
            }
        ],
        "events": [
            {
                "id": "event-1",
                "localRevision": revision,
                "calendarId": "local",
                "title": title,
                "start": "2026-08-28T13:00:00Z",
                "end": "2026-08-28T14:00:00Z",
            }
        ],
        "currentEvent": {
            "id": "current-event",
            "calendarId": "local",
            "title": "Current fixture",
            "start": "2026-08-28T11:30:00Z",
            "end": "2026-08-28T12:30:00Z",
        },
        "upNext": {
            "id": "event-1",
            "calendarId": "local",
            "title": title,
            "start": "2026-08-28T13:00:00Z",
            "end": "2026-08-28T14:00:00Z",
        },
        "invitations": [],
        "conflicts": [],
        "operations": [],
    }


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
    "reminders.snooze",
    "reminders.dismiss",
]


@dataclass
class Reply:
    result: object = None
    error: object = None
    notification: dict[str, Any] | None = None
    close_connection: bool = False


class Fixture:
    def __init__(self, scenario: str) -> None:
        self.scenario = scenario
        self.connection_number = 0
        self.snapshot_number = 0

    def reply(self, message: dict[str, Any]) -> Reply:
        if message.get("protocolMajor") != 2:
            return Reply(error={
                "code": "incompatible_protocol",
                "message": "IPC 2 required",
                "retryable": False,
            })

        method = message.get("method")
        if method == "system.info":
            major = 3 if self.scenario == "incompatible" else 2
            return Reply(result={
                "server": "omacalendard-test",
                "protocolMajor": major,
                "protocolMinor": 0,
                "methods": METHODS,
            })

        if method == "system.subscribe":
            revision = 9 if self.scenario == "restart" and self.connection_number > 1 else 7
            return Reply(result={"subscribed": True, "revision": revision})

        if method == "widget.snapshot":
            self.snapshot_number += 1
            params = message.get("params", {})

            if self.scenario == "sync-status":
                if self.snapshot_number > 1 and "sinceRevision" in params:
                    return Reply(error={
                        "code": "fixture_failure",
                        "message": "sync status refresh incorrectly used the database revision",
                        "retryable": False,
                    })
                states = [
                    ({"online": True, "syncing": False}, "Sync baseline"),
                    ({"online": True, "syncing": True}, "Sync started"),
                    ({"online": True, "syncing": False, "lastSyncResult": "ok"}, "Sync finished"),
                    ({"online": True, "reauthorizationRequired": True}, "Authentication required"),
                    ({"online": False, "offline": True}, "Provider offline"),
                ]
                index = min(self.snapshot_number - 1, len(states) - 1)
                status, title = states[index]
                notification = None
                if index + 1 < len(states):
                    notification = {"event": "sync.statusChanged", "data": {}}
                return Reply(
                    result=snapshot(7, title, status=status),
                    notification=notification,
                )

            if self.scenario == "gap":
                if self.snapshot_number == 1:
                    return Reply(
                        result=snapshot(7),
                        notification={"event": "widget.changed", "data": {"revision": 10}},
                    )
                if "sinceRevision" in params:
                    return Reply(error={
                        "code": "fixture_failure",
                        "message": "revision gap was not recovered with a full snapshot",
                        "retryable": False,
                    })
                return Reply(result=snapshot(10, "Gap recovered"))

            if self.scenario == "restart":
                if self.connection_number == 1:
                    return Reply(result=snapshot(7), close_connection=True)
                if "sinceRevision" in params:
                    return Reply(error={
                        "code": "fixture_failure",
                        "message": "reconnect did not request a fresh baseline",
                        "retryable": False,
                    })
                return Reply(result=snapshot(9, "Restart recovered"))

            if self.scenario == "offline":
                return Reply(result=snapshot(7), close_connection=True)

            if params.get("sinceRevision") == 7:
                return Reply(result={"unchanged": True, "revision": 7})
            return Reply(result=snapshot(7))

        if method == "events.create":
            params = message.get("params", {})
            if not params.get("clientMutationId") or "guestNotificationPolicy" not in params:
                return Reply(error={
                    "code": "invalid_params",
                    "message": "mutation metadata required",
                    "retryable": False,
                })
            return Reply(result={"event": {"id": "created-event"}})

        if method == "events.remove":
            if self.scenario == "mutation-contract":
                self._check_recurring_mutation(message)
                return Reply(result={"removed": True})
            return Reply(result={
                "undoToken": "undo-fixture",
                "undoLabel": "Undo fixture delete",
            })

        if method in {"events.update", "events.respond"}:
            if self.scenario == "mutation-contract":
                self._check_recurring_mutation(message)
            return Reply(result={"ok": True})

        if method == "events.move":
            if self.scenario == "mutation-contract":
                self._check_recurring_mutation(message)
                params = message.get("params", {})
                if (
                    params.get("targetCalendarId") != "local-2"
                    or params.get("draft", {}).get("calendarId") != "local-2"
                    or params.get("confirmedCrossProvider") is not False
                ):
                    return self._invalid("same-account move envelope was malformed")
            return Reply(result={"moved": True})

        if method == "calendarSets.activate":
            params = message.get("params", {})
            if self.scenario == "mutation-contract" and (
                not params.get("clientMutationId") or params.get("calendarSetId") != "set-all"
            ):
                return self._invalid("calendar-set activation omitted mutation metadata")
            return Reply(result={"activeId": params.get("calendarSetId")})

        if method == "reminders.snooze":
            params = message.get("params", {})
            if self.scenario == "mutation-contract" and (
                not params.get("clientMutationId") or params.get("reminderId") != "42"
                or params.get("minutes") != 10
            ):
                return self._invalid("snooze envelope was malformed")
            return Reply(result={"snoozed": True})

        if method == "reminders.dismiss":
            params = message.get("params", {})
            if self.scenario == "mutation-contract" and (
                not params.get("clientMutationId") or params.get("reminderId") != "42"
            ):
                return self._invalid("dismiss envelope was malformed")
            return Reply(result={"dismissed": True})

        if method == "events.undo":
            return Reply(result={"restored": True})

        return Reply(error={
            "code": "method_not_found",
            "message": "Unknown method",
            "retryable": False,
        })

    @staticmethod
    def _invalid(message: str) -> Reply:
        return Reply(error={"code": "invalid_params", "message": message, "retryable": False})

    def _check_recurring_mutation(self, message: dict[str, Any]) -> Reply | None:
        params = message.get("params", {})
        reference = params.get("eventRef", {})
        if (
            not params.get("clientMutationId")
            or params.get("recurrenceScope") != "occurrence"
            or reference.get("eventId") != "event-1"
            or reference.get("recurrenceId") != "2026-08-28T13:00:00Z"
            or "occurrenceStart" in reference
        ):
            raise ValueError("recurring mutation did not use the IPC recurrence contract")
        return None


def bind_server(socket_path: str) -> socket.socket:
    try:
        os.unlink(socket_path)
    except FileNotFoundError:
        pass
    server = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    server.bind(socket_path)
    os.chmod(socket_path, 0o600)
    server.listen(1)
    return server


def main() -> None:
    socket_path = sys.argv[1]
    scenario = sys.argv[2] if len(sys.argv) > 2 else "happy"
    fixture = Fixture(scenario)
    server = bind_server(socket_path)

    def stop(_signum: int, _frame: object) -> None:
        server.close()
        try:
            os.unlink(socket_path)
        except FileNotFoundError:
            pass
        raise SystemExit(0)

    signal.signal(signal.SIGTERM, stop)
    signal.signal(signal.SIGINT, stop)

    while True:
        connection, _ = server.accept()
        fixture.connection_number += 1
        close_connection = False
        with connection:
            with connection.makefile("rb") as stream:
                for line in stream:
                    try:
                        message = json.loads(line)
                        reply = fixture.reply(message)
                        connection.sendall(response(message.get("id"), reply.result, reply.error))
                        if reply.notification is not None:
                            connection.sendall(frame(reply.notification))
                        if reply.close_connection:
                            close_connection = True
                            connection.shutdown(socket.SHUT_RDWR)
                            break
                    except (BrokenPipeError, ConnectionResetError):
                        break

        if not close_connection:
            continue

        server.close()
        try:
            os.unlink(socket_path)
        except FileNotFoundError:
            pass

        if scenario == "offline":
            while True:
                time.sleep(30)

        # Leave the endpoint absent long enough to exercise a failed retry,
        # then recreate it as a restarted daemon on the same path.
        time.sleep(1.3)
        server = bind_server(socket_path)


if __name__ == "__main__":
    main()
