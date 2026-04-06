from __future__ import annotations

import hashlib
import secrets
import sqlite3
import uuid
from datetime import datetime, timedelta, timezone
from pathlib import Path
from threading import Lock
from typing import Any


class FamilyAccountStore:
    def __init__(self, db_path: Path, *, session_ttl_days: int = 45):
        self.db_path = db_path
        self.session_ttl_days = max(int(session_ttl_days), 1)
        self._lock = Lock()
        self._ensure_schema()

    def _connect(self) -> sqlite3.Connection:
        conn = sqlite3.connect(str(self.db_path))
        conn.row_factory = sqlite3.Row
        return conn

    def _ensure_schema(self) -> None:
        self.db_path.parent.mkdir(parents=True, exist_ok=True)
        with self._lock, self._connect() as conn:
            conn.execute(
                """
                CREATE TABLE IF NOT EXISTS family_users (
                    id TEXT PRIMARY KEY,
                    email TEXT NOT NULL UNIQUE,
                    password_hash TEXT NOT NULL,
                    password_salt TEXT NOT NULL,
                    display_name TEXT NOT NULL,
                    created_at TEXT NOT NULL
                );
                """
            )
            conn.execute(
                """
                CREATE TABLE IF NOT EXISTS family_sessions (
                    token TEXT PRIMARY KEY,
                    user_id TEXT NOT NULL,
                    created_at TEXT NOT NULL,
                    expires_at TEXT NOT NULL,
                    last_seen_at TEXT NOT NULL,
                    FOREIGN KEY(user_id) REFERENCES family_users(id)
                );
                """
            )
            conn.execute(
                """
                CREATE INDEX IF NOT EXISTS idx_family_sessions_user
                ON family_sessions(user_id);
                """
            )
            conn.execute(
                """
                CREATE TABLE IF NOT EXISTS family_invites (
                    id TEXT PRIMARY KEY,
                    child_id TEXT NOT NULL,
                    role TEXT NOT NULL,
                    display_name TEXT NOT NULL,
                    invite_code TEXT NOT NULL UNIQUE,
                    status TEXT NOT NULL,
                    created_by_user_id TEXT NOT NULL,
                    joined_by_user_id TEXT,
                    created_at TEXT NOT NULL,
                    joined_at TEXT,
                    FOREIGN KEY(created_by_user_id) REFERENCES family_users(id),
                    FOREIGN KEY(joined_by_user_id) REFERENCES family_users(id)
                );
                """
            )
            conn.execute(
                """
                CREATE INDEX IF NOT EXISTS idx_family_invites_child
                ON family_invites(child_id, created_at DESC);
                """
            )
            conn.execute(
                """
                CREATE INDEX IF NOT EXISTS idx_family_invites_code
                ON family_invites(invite_code);
                """
            )

    @staticmethod
    def _now_iso() -> str:
        return datetime.now(timezone.utc).isoformat()

    @staticmethod
    def _normalize_email(email: str) -> str:
        return email.strip().lower()

    @staticmethod
    def _password_hash(password: str, salt_hex: str) -> str:
        digest = hashlib.pbkdf2_hmac(
            "sha256",
            password.encode("utf-8"),
            bytes.fromhex(salt_hex),
            120_000,
        )
        return digest.hex()

    @staticmethod
    def _user_payload(row: sqlite3.Row) -> dict[str, Any]:
        return {
            "id": row["id"],
            "email": row["email"],
            "displayName": row["display_name"],
            "createdAt": row["created_at"],
        }

    @staticmethod
    def _invite_payload(row: sqlite3.Row) -> dict[str, Any]:
        return {
            "id": row["id"],
            "childId": row["child_id"],
            "role": row["role"],
            "displayName": row["display_name"],
            "status": row["status"],
            "inviteCode": row["invite_code"],
            "createdByUserId": row["created_by_user_id"],
            "joinedByUserId": row["joined_by_user_id"],
            "createdAt": row["created_at"],
            "joinedAt": row["joined_at"],
        }

    def create_user(self, email: str, password: str, display_name: str) -> dict[str, Any]:
        normalized_email = self._normalize_email(email)
        trimmed_password = password.strip()
        trimmed_name = display_name.strip() or normalized_email.split("@")[0]
        if "@" not in normalized_email or "." not in normalized_email:
            raise ValueError("invalid_email")
        if len(trimmed_password) < 6:
            raise ValueError("weak_password")

        user_id = str(uuid.uuid4())
        created_at = self._now_iso()
        salt_hex = secrets.token_hex(16)
        password_hash = self._password_hash(trimmed_password, salt_hex)

        with self._lock, self._connect() as conn:
            existing = conn.execute(
                "SELECT id FROM family_users WHERE email = ?;",
                (normalized_email,),
            ).fetchone()
            if existing:
                raise ValueError("email_exists")

            conn.execute(
                """
                INSERT INTO family_users (id, email, password_hash, password_salt, display_name, created_at)
                VALUES (?, ?, ?, ?, ?, ?);
                """,
                (user_id, normalized_email, password_hash, salt_hex, trimmed_name, created_at),
            )
            row = conn.execute(
                "SELECT id, email, display_name, created_at FROM family_users WHERE id = ?;",
                (user_id,),
            ).fetchone()
            assert row is not None
            return self._user_payload(row)

    def authenticate(self, email: str, password: str) -> dict[str, Any] | None:
        normalized_email = self._normalize_email(email)
        candidate_password = password.strip()
        if not normalized_email or not candidate_password:
            return None

        with self._lock, self._connect() as conn:
            row = conn.execute(
                """
                SELECT id, email, password_hash, password_salt, display_name, created_at
                FROM family_users
                WHERE email = ?;
                """,
                (normalized_email,),
            ).fetchone()
            if not row:
                return None

            candidate_hash = self._password_hash(candidate_password, row["password_salt"])
            if candidate_hash != row["password_hash"]:
                return None

            return self._user_payload(row)

    def create_session(self, user_id: str) -> str:
        token = secrets.token_urlsafe(32)
        now = datetime.now(timezone.utc)
        created_at = now.isoformat()
        expires_at = (now + timedelta(days=self.session_ttl_days)).isoformat()

        with self._lock, self._connect() as conn:
            conn.execute(
                """
                INSERT INTO family_sessions (token, user_id, created_at, expires_at, last_seen_at)
                VALUES (?, ?, ?, ?, ?);
                """,
                (token, user_id, created_at, expires_at, created_at),
            )
        return token

    def get_user_for_session_token(self, token: str) -> dict[str, Any] | None:
        trimmed = token.strip()
        if not trimmed:
            return None

        now = datetime.now(timezone.utc)
        with self._lock, self._connect() as conn:
            row = conn.execute(
                """
                SELECT
                    s.token AS token,
                    s.user_id AS user_id,
                    s.expires_at AS expires_at,
                    u.id AS id,
                    u.email AS email,
                    u.display_name AS display_name,
                    u.created_at AS created_at
                FROM family_sessions s
                JOIN family_users u ON u.id = s.user_id
                WHERE s.token = ?;
                """,
                (trimmed,),
            ).fetchone()
            if not row:
                return None

            try:
                expires_at = datetime.fromisoformat(str(row["expires_at"]))
                if expires_at.tzinfo is None:
                    expires_at = expires_at.replace(tzinfo=timezone.utc)
            except ValueError:
                expires_at = now - timedelta(seconds=1)

            if expires_at < now:
                conn.execute("DELETE FROM family_sessions WHERE token = ?;", (trimmed,))
                return None

            conn.execute(
                "UPDATE family_sessions SET last_seen_at = ? WHERE token = ?;",
                (now.isoformat(), trimmed),
            )
            return self._user_payload(row)

    def delete_session(self, token: str) -> None:
        trimmed = token.strip()
        if not trimmed:
            return
        with self._lock, self._connect() as conn:
            conn.execute("DELETE FROM family_sessions WHERE token = ?;", (trimmed,))

    def list_invites(self, child_id: str, user_id: str) -> list[dict[str, Any]]:
        scoped_child = child_id.strip()
        if not scoped_child:
            return []

        with self._lock, self._connect() as conn:
            rows = conn.execute(
                """
                SELECT *
                FROM family_invites
                WHERE child_id = ?
                  AND (created_by_user_id = ? OR joined_by_user_id = ?)
                ORDER BY created_at DESC;
                """,
                (scoped_child, user_id, user_id),
            ).fetchall()
            return [self._invite_payload(row) for row in rows]

    def create_invite(self, child_id: str, user_id: str, role: str, display_name: str) -> dict[str, Any]:
        scoped_child = child_id.strip()
        normalized_role = role.strip() or "caregiver"
        normalized_display = display_name.strip()
        if not scoped_child:
            raise ValueError("invalid_child")

        invite_id = str(uuid.uuid4())
        invite_code = secrets.token_hex(4).upper()
        created_at = self._now_iso()

        with self._lock, self._connect() as conn:
            conn.execute(
                """
                INSERT INTO family_invites (
                    id, child_id, role, display_name, invite_code, status,
                    created_by_user_id, joined_by_user_id, created_at, joined_at
                )
                VALUES (?, ?, ?, ?, ?, ?, ?, NULL, ?, NULL);
                """,
                (
                    invite_id,
                    scoped_child,
                    normalized_role,
                    normalized_display,
                    invite_code,
                    "pending",
                    user_id,
                    created_at,
                ),
            )
            row = conn.execute("SELECT * FROM family_invites WHERE id = ?;", (invite_id,)).fetchone()
            assert row is not None
            return self._invite_payload(row)

    def join_invite(self, code: str, user_id: str) -> dict[str, Any] | None:
        normalized_code = code.strip().upper()
        if not normalized_code:
            return None

        joined_at = self._now_iso()
        with self._lock, self._connect() as conn:
            row = conn.execute(
                "SELECT * FROM family_invites WHERE invite_code = ?;",
                (normalized_code,),
            ).fetchone()
            if not row:
                return None

            if row["status"] == "joined":
                # Already consumed; only return if same user joined before.
                if row["joined_by_user_id"] != user_id:
                    return None
                return self._invite_payload(row)

            conn.execute(
                """
                UPDATE family_invites
                SET status = 'joined',
                    joined_by_user_id = ?,
                    joined_at = ?
                WHERE id = ?;
                """,
                (user_id, joined_at, row["id"]),
            )
            updated = conn.execute("SELECT * FROM family_invites WHERE id = ?;", (row["id"],)).fetchone()
            assert updated is not None
            return self._invite_payload(updated)

    def set_invite_status(self, invite_id: str, user_id: str, status: str) -> dict[str, Any] | None:
        normalized_status = status.strip().lower()
        if normalized_status not in {"pending", "joined"}:
            return None

        with self._lock, self._connect() as conn:
            row = conn.execute(
                "SELECT * FROM family_invites WHERE id = ?;",
                (invite_id,),
            ).fetchone()
            if not row:
                return None
            if row["created_by_user_id"] != user_id:
                return None

            joined_by = row["joined_by_user_id"]
            joined_at = row["joined_at"]
            if normalized_status == "pending":
                joined_by = None
                joined_at = None
            elif not joined_by:
                joined_by = user_id
                joined_at = self._now_iso()

            conn.execute(
                """
                UPDATE family_invites
                SET status = ?, joined_by_user_id = ?, joined_at = ?
                WHERE id = ?;
                """,
                (normalized_status, joined_by, joined_at, invite_id),
            )
            updated = conn.execute("SELECT * FROM family_invites WHERE id = ?;", (invite_id,)).fetchone()
            assert updated is not None
            return self._invite_payload(updated)

    def delete_invite(self, invite_id: str, user_id: str) -> bool:
        with self._lock, self._connect() as conn:
            row = conn.execute(
                "SELECT created_by_user_id FROM family_invites WHERE id = ?;",
                (invite_id,),
            ).fetchone()
            if not row or row["created_by_user_id"] != user_id:
                return False
            conn.execute("DELETE FROM family_invites WHERE id = ?;", (invite_id,))
            return True
