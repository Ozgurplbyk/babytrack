from __future__ import annotations

import hashlib
import json
import sqlite3
import time
from datetime import datetime, timedelta, timezone
from pathlib import Path
from threading import Lock
from typing import Any

# Swift Date default JSON encoding is seconds since Apple reference date (2001-01-01).
APPLE_REFERENCE = datetime(2001, 1, 1, tzinfo=timezone.utc)


class EventSyncStore:
    CURRENT_SCHEMA_VERSION = 2

    def __init__(
        self,
        db_path: Path,
        *,
        default_event_retention_days: int = 365,
        retention_sweep_interval_sec: int = 3600,
    ):
        self.db_path = db_path
        self.default_event_retention_days = max(int(default_event_retention_days), 1)
        self.retention_sweep_interval_sec = max(int(retention_sweep_interval_sec), 60)
        self._last_retention_sweep_unix = 0
        self._lock = Lock()
        self._ensure_schema()

    def _connect(self) -> sqlite3.Connection:
        conn = sqlite3.connect(str(self.db_path))
        conn.row_factory = sqlite3.Row
        return conn

    @staticmethod
    def _table_columns(conn: sqlite3.Connection, table: str) -> set[str]:
        rows = conn.execute(f"PRAGMA table_info({table});").fetchall()
        return {str(row[1]) for row in rows}

    @staticmethod
    def _get_schema_version(conn: sqlite3.Connection) -> int:
        row = conn.execute(
            "SELECT value FROM sync_schema_meta WHERE key = 'schema_version';"
        ).fetchone()
        if not row:
            return 0
        try:
            return int(row[0])
        except (TypeError, ValueError):
            return 0

    @staticmethod
    def _set_schema_version(conn: sqlite3.Connection, version: int) -> None:
        conn.execute(
            """
            INSERT INTO sync_schema_meta (key, value)
            VALUES ('schema_version', ?)
            ON CONFLICT(key) DO UPDATE SET value = excluded.value;
            """,
            (str(version),),
        )

    @staticmethod
    def _ensure_nonce_guard_table(conn: sqlite3.Connection) -> None:
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS sync_nonce_guard (
                device_id TEXT NOT NULL,
                nonce_hash TEXT NOT NULL,
                first_seen_unix INTEGER NOT NULL,
                PRIMARY KEY (device_id, nonce_hash)
            );
            """
        )
        conn.execute(
            """
            CREATE INDEX IF NOT EXISTS idx_sync_nonce_guard_seen
            ON sync_nonce_guard(first_seen_unix DESC);
            """
        )

    @staticmethod
    def _cleanup_guard_tables(conn: sqlite3.Connection, cutoff_unix: int) -> tuple[int, int]:
        req_deleted = conn.execute(
            "DELETE FROM sync_request_guard WHERE first_seen_unix < ?;",
            (cutoff_unix,),
        ).rowcount
        nonce_deleted = conn.execute(
            "DELETE FROM sync_nonce_guard WHERE first_seen_unix < ?;",
            (cutoff_unix,),
        ).rowcount
        return req_deleted, nonce_deleted

    def _ensure_schema(self) -> None:
        self.db_path.parent.mkdir(parents=True, exist_ok=True)
        with self._lock, self._connect() as conn:
            conn.execute("PRAGMA journal_mode = WAL;")
            conn.execute("PRAGMA synchronous = NORMAL;")
            conn.execute(
                """
                CREATE TABLE IF NOT EXISTS sync_schema_meta (
                    key TEXT PRIMARY KEY,
                    value TEXT NOT NULL
                );
                """
            )
            conn.execute(
                """
                CREATE TABLE IF NOT EXISTS sync_events (
                    event_id TEXT PRIMARY KEY,
                    child_id TEXT NOT NULL,
                    event_type TEXT NOT NULL,
                    event_timestamp TEXT NOT NULL,
                    note TEXT NOT NULL,
                    payload_json TEXT NOT NULL,
                    visibility TEXT NOT NULL,
                    country_code TEXT NOT NULL,
                    app_version TEXT NOT NULL,
                    source_device_id TEXT NOT NULL,
                    received_at TEXT NOT NULL,
                    raw_event_json TEXT NOT NULL
                );
                """
            )
            conn.execute(
                """
                CREATE INDEX IF NOT EXISTS idx_sync_events_child_ts
                ON sync_events(child_id, event_timestamp DESC);
                """
            )
            conn.execute(
                """
                CREATE INDEX IF NOT EXISTS idx_sync_events_received_at
                ON sync_events(received_at DESC);
                """
            )
            conn.execute(
                """
                CREATE TABLE IF NOT EXISTS sync_request_guard (
                    request_digest TEXT PRIMARY KEY,
                    first_seen_unix INTEGER NOT NULL
                );
                """
            )
            conn.execute(
                """
                CREATE INDEX IF NOT EXISTS idx_sync_request_guard_seen
                ON sync_request_guard(first_seen_unix DESC);
                """
            )

            schema_version = self._get_schema_version(conn)
            if schema_version < 1:
                if "source_device_id" not in self._table_columns(conn, "sync_events"):
                    conn.execute(
                        """
                        ALTER TABLE sync_events
                        ADD COLUMN source_device_id TEXT NOT NULL DEFAULT '';
                        """
                    )
                schema_version = 1

            if schema_version < 2:
                self._ensure_nonce_guard_table(conn)
                schema_version = 2
            else:
                self._ensure_nonce_guard_table(conn)

            if schema_version < self.CURRENT_SCHEMA_VERSION:
                schema_version = self.CURRENT_SCHEMA_VERSION
            self._set_schema_version(conn, schema_version)

    @staticmethod
    def _parse_timestamp(value: Any) -> datetime:
        if isinstance(value, (int, float)):
            n = float(value)
            if n > 1_000_000_000_000:
                return datetime.fromtimestamp(n / 1000, tz=timezone.utc)
            if n > 1_000_000_000:
                return datetime.fromtimestamp(n, tz=timezone.utc)
            return APPLE_REFERENCE + timedelta(seconds=n)

        if isinstance(value, str):
            text = value.strip()
            if not text:
                raise ValueError("timestamp is empty")
            if text.endswith("Z"):
                text = text[:-1] + "+00:00"
            ts = datetime.fromisoformat(text)
            if ts.tzinfo is None:
                ts = ts.replace(tzinfo=timezone.utc)
            return ts.astimezone(timezone.utc)

        raise ValueError("timestamp must be numeric or ISO-8601 string")

    @classmethod
    def _normalize_event(cls, raw_event: dict[str, Any]) -> dict[str, str]:
        event_id = str(raw_event.get("id", "")).strip()
        event_type = str(raw_event.get("type", "")).strip()
        if not event_id or not event_type:
            raise ValueError("id and type are required")

        child_id = str(raw_event.get("childId", "")).strip() or "default-child"
        timestamp = cls._parse_timestamp(raw_event.get("timestamp"))
        note = str(raw_event.get("note", "")).strip()
        visibility = str(raw_event.get("visibility", "family")).strip() or "family"

        payload_value = raw_event.get("payload", {})
        if payload_value is None:
            payload_value = {}
        if not isinstance(payload_value, dict):
            raise ValueError("payload must be an object")

        return {
            "event_id": event_id,
            "child_id": child_id,
            "event_type": event_type,
            "event_timestamp": timestamp.isoformat(),
            "note": note,
            "payload_json": json.dumps(payload_value, ensure_ascii=False, sort_keys=True),
            "visibility": visibility,
            "raw_event_json": json.dumps(raw_event, ensure_ascii=False, sort_keys=True),
        }

    def upsert_event(
        self,
        raw_event: dict[str, Any],
        *,
        country_code: str,
        app_version: str,
        source_device_id: str = "",
    ) -> bool:
        accepted, _ = self.upsert_event_with_status(
            raw_event,
            country_code=country_code,
            app_version=app_version,
            source_device_id=source_device_id,
        )
        return accepted

    def upsert_event_with_status(
        self,
        raw_event: dict[str, Any],
        *,
        country_code: str,
        app_version: str,
        source_device_id: str = "",
        force: bool = False,
    ) -> tuple[bool, str]:
        try:
            row = self._normalize_event(raw_event)
        except ValueError:
            return False, "invalid_event"

        now = datetime.now(timezone.utc).isoformat()
        with self._lock, self._connect() as conn:
            existing = conn.execute(
                """
                SELECT source_device_id, raw_event_json
                FROM sync_events
                WHERE event_id = ?;
                """,
                (row["event_id"],),
            ).fetchone()
            if existing:
                existing_device = str(existing["source_device_id"] or "").strip()
                incoming_device = source_device_id.strip()
                existing_raw = str(existing["raw_event_json"] or "")
                incoming_raw = row["raw_event_json"]

                # Conflict policy:
                # If two different devices modify the same event id with different payloads,
                # do not overwrite silently. Let the client resolve.
                if (
                    not force
                    and
                    existing_device
                    and incoming_device
                    and existing_device != incoming_device
                    and existing_raw != incoming_raw
                ):
                    return False, "conflict_remote_update"

            conn.execute(
                """
                INSERT INTO sync_events (
                    event_id,
                    child_id,
                    event_type,
                    event_timestamp,
                    note,
                    payload_json,
                    visibility,
                    country_code,
                    app_version,
                    source_device_id,
                    received_at,
                    raw_event_json
                )
                VALUES (
                    :event_id,
                    :child_id,
                    :event_type,
                    :event_timestamp,
                    :note,
                    :payload_json,
                    :visibility,
                    :country_code,
                    :app_version,
                    :source_device_id,
                    :received_at,
                    :raw_event_json
                )
                ON CONFLICT(event_id) DO UPDATE SET
                    child_id = excluded.child_id,
                    event_type = excluded.event_type,
                    event_timestamp = excluded.event_timestamp,
                    note = excluded.note,
                    payload_json = excluded.payload_json,
                    visibility = excluded.visibility,
                    country_code = excluded.country_code,
                    app_version = excluded.app_version,
                    source_device_id = excluded.source_device_id,
                    received_at = excluded.received_at,
                    raw_event_json = excluded.raw_event_json;
                """,
                {
                    **row,
                    "country_code": country_code.upper(),
                    "app_version": app_version.strip() or "0",
                    "source_device_id": source_device_id.strip(),
                    "received_at": now,
                },
            )
        return True, "accepted"

    def get_event_raw(self, event_id: str) -> dict[str, Any] | None:
        key = str(event_id).strip()
        if not key:
            return None

        with self._lock, self._connect() as conn:
            row = conn.execute(
                """
                SELECT raw_event_json
                FROM sync_events
                WHERE event_id = ?;
                """,
                (key,),
            ).fetchone()
            if not row:
                return None
            try:
                payload = json.loads(str(row["raw_event_json"]))
            except (TypeError, ValueError, json.JSONDecodeError):
                return None
            return payload if isinstance(payload, dict) else None

    def register_request_digest(self, digest: str, window_sec: int) -> bool:
        if window_sec <= 0:
            return True

        now = int(time.time())
        cutoff = now - max(window_sec, 60)
        with self._lock, self._connect() as conn:
            self._cleanup_guard_tables(conn, cutoff)
            row = conn.execute(
                "SELECT first_seen_unix FROM sync_request_guard WHERE request_digest = ?;",
                (digest,),
            ).fetchone()
            if row and (now - int(row[0])) <= window_sec:
                return False

            conn.execute(
                """
                INSERT INTO sync_request_guard (request_digest, first_seen_unix)
                VALUES (?, ?)
                ON CONFLICT(request_digest) DO UPDATE SET
                    first_seen_unix = excluded.first_seen_unix;
                """,
                (digest, now),
            )

        return True

    def register_device_nonce(self, device_id: str, nonce: str, window_sec: int) -> bool:
        if window_sec <= 0:
            return True

        normalized_device = device_id.strip()
        normalized_nonce = nonce.strip()
        if not normalized_device or not normalized_nonce:
            return False

        nonce_hash = hashlib.sha256(normalized_nonce.encode("utf-8")).hexdigest()
        now = int(time.time())
        cutoff = now - max(window_sec, 60)
        with self._lock, self._connect() as conn:
            self._cleanup_guard_tables(conn, cutoff)
            row = conn.execute(
                """
                SELECT first_seen_unix
                FROM sync_nonce_guard
                WHERE device_id = ? AND nonce_hash = ?;
                """,
                (normalized_device, nonce_hash),
            ).fetchone()
            if row and (now - int(row[0])) <= window_sec:
                return False

            conn.execute(
                """
                INSERT INTO sync_nonce_guard (device_id, nonce_hash, first_seen_unix)
                VALUES (?, ?, ?)
                ON CONFLICT(device_id, nonce_hash) DO UPDATE SET
                    first_seen_unix = excluded.first_seen_unix;
                """,
                (normalized_device, nonce_hash, now),
            )
        return True

    def apply_retention_policy(
        self,
        *,
        event_retention_days: int | None = None,
        guard_retention_sec: int = 86400,
        force: bool = False,
    ) -> dict[str, Any]:
        now_unix = int(time.time())
        if not force and (now_unix - self._last_retention_sweep_unix) < self.retention_sweep_interval_sec:
            return {"ran": False}

        keep_days = max(int(event_retention_days or self.default_event_retention_days), 1)
        keep_guard_sec = max(int(guard_retention_sec), 60)
        event_cutoff = (datetime.now(timezone.utc) - timedelta(days=keep_days)).isoformat()
        guard_cutoff_unix = now_unix - keep_guard_sec

        with self._lock, self._connect() as conn:
            deleted_events = conn.execute(
                "DELETE FROM sync_events WHERE received_at < ?;",
                (event_cutoff,),
            ).rowcount
            deleted_request, deleted_nonce = self._cleanup_guard_tables(conn, guard_cutoff_unix)

        self._last_retention_sweep_unix = now_unix
        return {
            "ran": True,
            "deletedEvents": int(deleted_events),
            "deletedRequestGuards": int(deleted_request),
            "deletedNonceGuards": int(deleted_nonce),
            "eventRetentionDays": keep_days,
            "guardRetentionSec": keep_guard_sec,
        }

    def stats(self) -> dict[str, Any]:
        with self._connect() as conn:
            event_count = int(conn.execute("SELECT COUNT(*) FROM sync_events;").fetchone()[0])
            oldest_event = conn.execute("SELECT MIN(received_at) FROM sync_events;").fetchone()[0]
            last_event = conn.execute("SELECT MAX(received_at) FROM sync_events;").fetchone()[0]
            guard_count = int(conn.execute("SELECT COUNT(*) FROM sync_request_guard;").fetchone()[0])
            nonce_guard_count = int(conn.execute("SELECT COUNT(*) FROM sync_nonce_guard;").fetchone()[0])
            guard_last = conn.execute(
                "SELECT MAX(first_seen_unix) FROM sync_request_guard;"
            ).fetchone()[0]
            nonce_guard_last = conn.execute(
                "SELECT MAX(first_seen_unix) FROM sync_nonce_guard;"
            ).fetchone()[0]
            schema_version = self._get_schema_version(conn)

        return {
            "storedEvents": event_count,
            "oldestReceivedAt": oldest_event,
            "lastReceivedAt": last_event,
            "replayGuardEntries": guard_count,
            "lastGuardSeenUnix": guard_last,
            "deviceNonceGuardEntries": nonce_guard_count,
            "lastDeviceNonceSeenUnix": nonce_guard_last,
            "schemaVersion": schema_version,
        }
