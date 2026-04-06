from __future__ import annotations

import json
import sqlite3
import uuid
from datetime import datetime, timedelta, timezone
from pathlib import Path
from threading import Lock
from typing import Any


class ForumStore:
    def __init__(
        self,
        db_path: Path,
        *,
        blocked_terms: list[str] | None = None,
        post_rate_limit: int = 5,
        post_rate_window_sec: int = 300,
    ):
        self.db_path = db_path
        self._lock = Lock()
        self.blocked_terms = {
            term.strip().lower()
            for term in (blocked_terms or ["hate", "violence", "kill", "abuse", "scam", "spam"])
            if term.strip()
        }
        self.post_rate_limit = max(int(post_rate_limit), 1)
        self.post_rate_window_sec = max(int(post_rate_window_sec), 60)
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
                CREATE TABLE IF NOT EXISTS forum_posts (
                    id TEXT PRIMARY KEY,
                    author_user_id TEXT NOT NULL,
                    author_name TEXT NOT NULL,
                    title TEXT NOT NULL,
                    body TEXT NOT NULL,
                    tags_json TEXT NOT NULL,
                    country_code TEXT NOT NULL,
                    child_id TEXT NOT NULL,
                    created_at TEXT NOT NULL,
                    updated_at TEXT NOT NULL
                );
                """
            )
            conn.execute(
                """
                CREATE TABLE IF NOT EXISTS forum_comments (
                    id TEXT PRIMARY KEY,
                    post_id TEXT NOT NULL,
                    author_user_id TEXT NOT NULL,
                    author_name TEXT NOT NULL,
                    body TEXT NOT NULL,
                    created_at TEXT NOT NULL,
                    FOREIGN KEY(post_id) REFERENCES forum_posts(id)
                );
                """
            )
            conn.execute(
                """
                CREATE TABLE IF NOT EXISTS forum_reactions (
                    post_id TEXT NOT NULL,
                    user_id TEXT NOT NULL,
                    reaction TEXT NOT NULL,
                    created_at TEXT NOT NULL,
                    PRIMARY KEY (post_id, user_id, reaction),
                    FOREIGN KEY(post_id) REFERENCES forum_posts(id)
                );
                """
            )
            conn.execute(
                """
                CREATE TABLE IF NOT EXISTS forum_reports (
                    id TEXT PRIMARY KEY,
                    post_id TEXT NOT NULL,
                    reporter_user_id TEXT NOT NULL,
                    reason TEXT NOT NULL,
                    note TEXT NOT NULL,
                    status TEXT NOT NULL,
                    created_at TEXT NOT NULL,
                    resolved_at TEXT,
                    resolved_by_user_id TEXT
                );
                """
            )
            conn.execute(
                """
                CREATE TABLE IF NOT EXISTS forum_user_blocks (
                    user_id TEXT NOT NULL,
                    target_user_id TEXT NOT NULL,
                    created_at TEXT NOT NULL,
                    PRIMARY KEY (user_id, target_user_id)
                );
                """
            )
            conn.execute(
                """
                CREATE TABLE IF NOT EXISTS forum_post_mutes (
                    user_id TEXT NOT NULL,
                    post_id TEXT NOT NULL,
                    created_at TEXT NOT NULL,
                    PRIMARY KEY (user_id, post_id)
                );
                """
            )
            conn.execute(
                """
                CREATE TABLE IF NOT EXISTS forum_post_bookmarks (
                    user_id TEXT NOT NULL,
                    post_id TEXT NOT NULL,
                    created_at TEXT NOT NULL,
                    PRIMARY KEY (user_id, post_id)
                );
                """
            )

            conn.execute("CREATE INDEX IF NOT EXISTS idx_forum_posts_created ON forum_posts(created_at DESC);")
            conn.execute("CREATE INDEX IF NOT EXISTS idx_forum_posts_country ON forum_posts(country_code, created_at DESC);")
            conn.execute("CREATE INDEX IF NOT EXISTS idx_forum_comments_post ON forum_comments(post_id, created_at ASC);")
            conn.execute("CREATE INDEX IF NOT EXISTS idx_forum_reactions_post ON forum_reactions(post_id);")
            conn.execute("CREATE INDEX IF NOT EXISTS idx_forum_reports_status ON forum_reports(status, created_at DESC);")

    @staticmethod
    def _now_iso() -> str:
        return datetime.now(timezone.utc).isoformat()

    @staticmethod
    def _normalize_tags(tags: list[str] | None) -> list[str]:
        if not tags:
            return []
        normalized: list[str] = []
        seen: set[str] = set()
        for value in tags:
            text = str(value).strip().lower()
            if not text or text in seen:
                continue
            normalized.append(text)
            seen.add(text)
            if len(normalized) >= 6:
                break
        return normalized

    @staticmethod
    def _post_payload(row: sqlite3.Row) -> dict[str, Any]:
        try:
            tags = json.loads(str(row["tags_json"]))
            if not isinstance(tags, list):
                tags = []
        except (TypeError, ValueError, json.JSONDecodeError):
            tags = []

        return {
            "id": row["id"],
            "authorUserId": row["author_user_id"],
            "authorName": row["author_name"],
            "title": row["title"],
            "body": row["body"],
            "tags": tags,
            "countryCode": row["country_code"],
            "childId": row["child_id"],
            "createdAt": row["created_at"],
            "updatedAt": row["updated_at"],
            "commentCount": int(row["comment_count"] or 0),
            "reactionCount": int(row["reaction_count"] or 0),
            "viewerReaction": row["viewer_reaction"] or "",
            "viewerBookmarked": bool(row["viewer_bookmarked"] or 0),
        }

    @staticmethod
    def _comment_payload(row: sqlite3.Row) -> dict[str, Any]:
        return {
            "id": row["id"],
            "postId": row["post_id"],
            "authorUserId": row["author_user_id"],
            "authorName": row["author_name"],
            "body": row["body"],
            "createdAt": row["created_at"],
        }

    @staticmethod
    def _report_payload(row: sqlite3.Row) -> dict[str, Any]:
        return {
            "id": row["id"],
            "postId": row["post_id"],
            "reporterUserId": row["reporter_user_id"],
            "reason": row["reason"],
            "note": row["note"],
            "status": row["status"],
            "createdAt": row["created_at"],
            "resolvedAt": row["resolved_at"],
            "resolvedByUserId": row["resolved_by_user_id"],
        }

    def _contains_blocked_terms(self, text: str) -> bool:
        normalized = text.lower()
        return any(term in normalized for term in self.blocked_terms)

    def _enforce_post_rate_limit(self, conn: sqlite3.Connection, user_id: str) -> None:
        cutoff = (datetime.now(timezone.utc) - timedelta(seconds=self.post_rate_window_sec)).isoformat()
        row = conn.execute(
            """
            SELECT COUNT(*)
            FROM forum_posts
            WHERE author_user_id = ? AND created_at >= ?;
            """,
            (user_id, cutoff),
        ).fetchone()
        count = int(row[0]) if row else 0
        if count >= self.post_rate_limit:
            raise ValueError("rate_limited")

    def list_posts(
        self,
        viewer_user_id: str,
        country_code: str,
        limit: int = 30,
        query: str = "",
        tag: str = "",
        author_scope: str = "all",
    ) -> list[dict[str, Any]]:
        scoped_country = country_code.strip().upper()
        scoped_limit = min(max(int(limit), 1), 100)
        normalized_query = " ".join(query.strip().lower().split())
        normalized_tag = tag.strip().lower()
        normalized_scope = author_scope.strip().lower() or "all"

        with self._lock, self._connect() as conn:
            base_sql = """
                SELECT
                    p.*,
                    (SELECT COUNT(*) FROM forum_comments c WHERE c.post_id = p.id) AS comment_count,
                    (SELECT COUNT(*) FROM forum_reactions r WHERE r.post_id = p.id) AS reaction_count,
                    (SELECT reaction FROM forum_reactions vr WHERE vr.post_id = p.id AND vr.user_id = ? LIMIT 1) AS viewer_reaction,
                    EXISTS(
                        SELECT 1 FROM forum_post_bookmarks fb
                        WHERE fb.post_id = p.id AND fb.user_id = ?
                    ) AS viewer_bookmarked
                FROM forum_posts p
                WHERE NOT EXISTS (
                    SELECT 1 FROM forum_post_mutes m
                    WHERE m.user_id = ? AND m.post_id = p.id
                )
                AND NOT EXISTS (
                    SELECT 1 FROM forum_user_blocks b
                    WHERE b.user_id = ? AND b.target_user_id = p.author_user_id
                )
                AND NOT EXISTS (
                    SELECT 1 FROM forum_user_blocks b2
                    WHERE b2.user_id = p.author_user_id AND b2.target_user_id = ?
                )
            """
            params: list[Any] = [viewer_user_id, viewer_user_id, viewer_user_id, viewer_user_id, viewer_user_id]
            if scoped_country:
                base_sql += " AND p.country_code = ?"
                params.append(scoped_country)
            if normalized_scope == "mine":
                base_sql += " AND p.author_user_id = ?"
                params.append(viewer_user_id)
            if normalized_scope == "saved":
                base_sql += """
                    AND EXISTS (
                        SELECT 1 FROM forum_post_bookmarks fb
                        WHERE fb.user_id = ? AND fb.post_id = p.id
                    )
                """
                params.append(viewer_user_id)
            if normalized_query:
                base_sql += " AND (LOWER(p.title) LIKE ? OR LOWER(p.body) LIKE ?)"
                wildcard = f"%{normalized_query}%"
                params.extend([wildcard, wildcard])
            if normalized_tag:
                base_sql += " AND LOWER(p.tags_json) LIKE ?"
                params.append(f'%"{normalized_tag}"%')
            base_sql += " ORDER BY p.created_at DESC LIMIT ?"
            params.append(scoped_limit)

            rows = conn.execute(base_sql, params).fetchall()
            return [self._post_payload(row) for row in rows]

    def create_post(
        self,
        *,
        user_id: str,
        author_name: str,
        title: str,
        body: str,
        country_code: str,
        child_id: str,
        tags: list[str] | None,
    ) -> dict[str, Any]:
        normalized_body = body.strip()
        if len(normalized_body) < 3:
            raise ValueError("body_too_short")
        if len(normalized_body) > 1200:
            raise ValueError("body_too_long")

        normalized_title = title.strip()
        if not normalized_title:
            normalized_title = (normalized_body[:56] + "…") if len(normalized_body) > 56 else normalized_body

        if self._contains_blocked_terms(f"{normalized_title} {normalized_body}"):
            raise ValueError("blocked_terms")

        post_id = str(uuid.uuid4())
        now = self._now_iso()
        tag_values = self._normalize_tags(tags)

        with self._lock, self._connect() as conn:
            self._enforce_post_rate_limit(conn, user_id)

            conn.execute(
                """
                INSERT INTO forum_posts (
                    id,
                    author_user_id,
                    author_name,
                    title,
                    body,
                    tags_json,
                    country_code,
                    child_id,
                    created_at,
                    updated_at
                )
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
                """,
                (
                    post_id,
                    user_id,
                    author_name.strip() or "Parent",
                    normalized_title,
                    normalized_body,
                    json.dumps(tag_values, ensure_ascii=False),
                    country_code.strip().upper(),
                    child_id.strip(),
                    now,
                    now,
                ),
            )
            row = conn.execute(
                """
                SELECT
                    p.*,
                    0 AS comment_count,
                    0 AS reaction_count,
                    '' AS viewer_reaction,
                    0 AS viewer_bookmarked
                FROM forum_posts p
                WHERE p.id = ?;
                """,
                (post_id,),
            ).fetchone()
            assert row is not None
            return self._post_payload(row)

    def update_post(
        self,
        *,
        post_id: str,
        user_id: str,
        title: str,
        body: str,
        tags: list[str] | None,
    ) -> dict[str, Any]:
        scoped_post_id = post_id.strip()
        normalized_body = body.strip()
        if len(normalized_body) < 3:
            raise ValueError("body_too_short")
        if len(normalized_body) > 1200:
            raise ValueError("body_too_long")

        normalized_title = title.strip()
        if not normalized_title:
            normalized_title = (normalized_body[:56] + "…") if len(normalized_body) > 56 else normalized_body

        if self._contains_blocked_terms(f"{normalized_title} {normalized_body}"):
            raise ValueError("blocked_terms")

        now = self._now_iso()
        tag_values = self._normalize_tags(tags)

        with self._lock, self._connect() as conn:
            row = conn.execute(
                "SELECT author_user_id FROM forum_posts WHERE id = ?;",
                (scoped_post_id,),
            ).fetchone()
            if not row:
                raise ValueError("post_not_found")
            if row["author_user_id"] != user_id:
                raise ValueError("forbidden")

            conn.execute(
                """
                UPDATE forum_posts
                SET title = ?, body = ?, tags_json = ?, updated_at = ?
                WHERE id = ?;
                """,
                (
                    normalized_title,
                    normalized_body,
                    json.dumps(tag_values, ensure_ascii=False),
                    now,
                    scoped_post_id,
                ),
            )
            payload = conn.execute(
                """
                SELECT
                    p.*,
                    (SELECT COUNT(*) FROM forum_comments c WHERE c.post_id = p.id) AS comment_count,
                    (SELECT COUNT(*) FROM forum_reactions r WHERE r.post_id = p.id) AS reaction_count,
                    (SELECT reaction FROM forum_reactions vr WHERE vr.post_id = p.id AND vr.user_id = ? LIMIT 1) AS viewer_reaction,
                    EXISTS(
                        SELECT 1 FROM forum_post_bookmarks fb
                        WHERE fb.post_id = p.id AND fb.user_id = ?
                    ) AS viewer_bookmarked
                FROM forum_posts p
                WHERE p.id = ?;
                """,
                (user_id, user_id, scoped_post_id),
            ).fetchone()
            assert payload is not None
            return self._post_payload(payload)

    def delete_post(self, *, post_id: str, user_id: str) -> bool:
        scoped_post_id = post_id.strip()
        with self._lock, self._connect() as conn:
            row = conn.execute(
                "SELECT author_user_id FROM forum_posts WHERE id = ?;",
                (scoped_post_id,),
            ).fetchone()
            if not row:
                return False
            if row["author_user_id"] != user_id:
                raise ValueError("forbidden")

            conn.execute("DELETE FROM forum_reactions WHERE post_id = ?;", (scoped_post_id,))
            conn.execute("DELETE FROM forum_comments WHERE post_id = ?;", (scoped_post_id,))
            conn.execute("DELETE FROM forum_reports WHERE post_id = ?;", (scoped_post_id,))
            conn.execute("DELETE FROM forum_post_mutes WHERE post_id = ?;", (scoped_post_id,))
            conn.execute("DELETE FROM forum_post_bookmarks WHERE post_id = ?;", (scoped_post_id,))
            conn.execute("DELETE FROM forum_posts WHERE id = ?;", (scoped_post_id,))
            return True

    def list_comments(self, post_id: str, limit: int = 80) -> list[dict[str, Any]]:
        scoped_limit = min(max(int(limit), 1), 300)

        with self._lock, self._connect() as conn:
            rows = conn.execute(
                """
                SELECT *
                FROM forum_comments
                WHERE post_id = ?
                ORDER BY created_at ASC
                LIMIT ?;
                """,
                (post_id.strip(), scoped_limit),
            ).fetchall()
            return [self._comment_payload(row) for row in rows]

    def create_comment(self, *, post_id: str, user_id: str, author_name: str, body: str) -> dict[str, Any]:
        scoped_post_id = post_id.strip()
        normalized_body = body.strip()
        if len(normalized_body) < 1:
            raise ValueError("comment_empty")
        if len(normalized_body) > 600:
            raise ValueError("comment_too_long")
        if self._contains_blocked_terms(normalized_body):
            raise ValueError("blocked_terms")

        comment_id = str(uuid.uuid4())
        now = self._now_iso()

        with self._lock, self._connect() as conn:
            post_exists = conn.execute(
                "SELECT id FROM forum_posts WHERE id = ?;",
                (scoped_post_id,),
            ).fetchone()
            if not post_exists:
                raise ValueError("post_not_found")

            conn.execute(
                """
                INSERT INTO forum_comments (
                    id,
                    post_id,
                    author_user_id,
                    author_name,
                    body,
                    created_at
                )
                VALUES (?, ?, ?, ?, ?, ?);
                """,
                (
                    comment_id,
                    scoped_post_id,
                    user_id,
                    author_name.strip() or "Parent",
                    normalized_body,
                    now,
                ),
            )
            row = conn.execute(
                "SELECT * FROM forum_comments WHERE id = ?;",
                (comment_id,),
            ).fetchone()
            assert row is not None
            return self._comment_payload(row)

    def set_reaction(self, *, post_id: str, user_id: str, reaction: str, active: bool) -> dict[str, Any]:
        scoped_post_id = post_id.strip()
        normalized_reaction = reaction.strip().lower()
        if normalized_reaction not in {"support", "hug"}:
            raise ValueError("unsupported_reaction")

        now = self._now_iso()
        with self._lock, self._connect() as conn:
            post_exists = conn.execute("SELECT id FROM forum_posts WHERE id = ?;", (scoped_post_id,)).fetchone()
            if not post_exists:
                raise ValueError("post_not_found")

            if active:
                conn.execute(
                    """
                    INSERT OR IGNORE INTO forum_reactions (post_id, user_id, reaction, created_at)
                    VALUES (?, ?, ?, ?);
                    """,
                    (scoped_post_id, user_id, normalized_reaction, now),
                )
            else:
                conn.execute(
                    """
                    DELETE FROM forum_reactions
                    WHERE post_id = ? AND user_id = ? AND reaction = ?;
                    """,
                    (scoped_post_id, user_id, normalized_reaction),
                )

            row = conn.execute(
                """
                SELECT
                    (SELECT COUNT(*) FROM forum_reactions r WHERE r.post_id = ?) AS reaction_count,
                    (SELECT reaction FROM forum_reactions vr WHERE vr.post_id = ? AND vr.user_id = ? LIMIT 1) AS viewer_reaction;
                """,
                (scoped_post_id, scoped_post_id, user_id),
            ).fetchone()
            return {
                "postId": scoped_post_id,
                "reactionCount": int(row["reaction_count"] or 0),
                "viewerReaction": row["viewer_reaction"] or "",
            }

    def report_post(self, *, post_id: str, reporter_user_id: str, reason: str, note: str = "") -> dict[str, Any]:
        scoped_post_id = post_id.strip()
        normalized_reason = reason.strip().lower() or "other"
        normalized_note = note.strip()

        report_id = str(uuid.uuid4())
        now = self._now_iso()
        with self._lock, self._connect() as conn:
            post_exists = conn.execute("SELECT id FROM forum_posts WHERE id = ?;", (scoped_post_id,)).fetchone()
            if not post_exists:
                raise ValueError("post_not_found")

            conn.execute(
                """
                INSERT INTO forum_reports (
                    id,
                    post_id,
                    reporter_user_id,
                    reason,
                    note,
                    status,
                    created_at,
                    resolved_at,
                    resolved_by_user_id
                )
                VALUES (?, ?, ?, ?, ?, 'pending', ?, NULL, NULL);
                """,
                (report_id, scoped_post_id, reporter_user_id, normalized_reason, normalized_note, now),
            )
            row = conn.execute("SELECT * FROM forum_reports WHERE id = ?;", (report_id,)).fetchone()
            assert row is not None
            return self._report_payload(row)

    def list_reports(self, *, status: str = "", limit: int = 100) -> list[dict[str, Any]]:
        normalized_status = status.strip().lower()
        scoped_limit = min(max(int(limit), 1), 500)

        with self._lock, self._connect() as conn:
            if normalized_status:
                rows = conn.execute(
                    """
                    SELECT * FROM forum_reports
                    WHERE status = ?
                    ORDER BY created_at DESC
                    LIMIT ?;
                    """,
                    (normalized_status, scoped_limit),
                ).fetchall()
            else:
                rows = conn.execute(
                    """
                    SELECT * FROM forum_reports
                    ORDER BY created_at DESC
                    LIMIT ?;
                    """,
                    (scoped_limit,),
                ).fetchall()
            return [self._report_payload(row) for row in rows]

    def resolve_report(self, *, report_id: str, reviewer_user_id: str, status: str) -> dict[str, Any] | None:
        normalized_status = status.strip().lower()
        if normalized_status not in {"resolved", "rejected"}:
            return None

        now = self._now_iso()
        with self._lock, self._connect() as conn:
            row = conn.execute("SELECT * FROM forum_reports WHERE id = ?;", (report_id.strip(),)).fetchone()
            if not row:
                return None
            conn.execute(
                """
                UPDATE forum_reports
                SET status = ?, resolved_at = ?, resolved_by_user_id = ?
                WHERE id = ?;
                """,
                (normalized_status, now, reviewer_user_id, report_id.strip()),
            )
            updated = conn.execute("SELECT * FROM forum_reports WHERE id = ?;", (report_id.strip(),)).fetchone()
            assert updated is not None
            return self._report_payload(updated)

    def block_user(self, *, user_id: str, target_user_id: str) -> bool:
        if not user_id.strip() or not target_user_id.strip() or user_id.strip() == target_user_id.strip():
            return False
        with self._lock, self._connect() as conn:
            conn.execute(
                """
                INSERT OR IGNORE INTO forum_user_blocks (user_id, target_user_id, created_at)
                VALUES (?, ?, ?);
                """,
                (user_id.strip(), target_user_id.strip(), self._now_iso()),
            )
        return True

    def mute_post(self, *, user_id: str, post_id: str) -> bool:
        if not user_id.strip() or not post_id.strip():
            return False
        with self._lock, self._connect() as conn:
            post_exists = conn.execute("SELECT id FROM forum_posts WHERE id = ?;", (post_id.strip(),)).fetchone()
            if not post_exists:
                return False
            conn.execute(
                """
                INSERT OR IGNORE INTO forum_post_mutes (user_id, post_id, created_at)
                VALUES (?, ?, ?);
                """,
                (user_id.strip(), post_id.strip(), self._now_iso()),
            )
        return True

    def set_bookmark(self, *, user_id: str, post_id: str, active: bool) -> dict[str, Any]:
        scoped_post_id = post_id.strip()
        if not user_id.strip() or not scoped_post_id:
            raise ValueError("post_not_found")

        with self._lock, self._connect() as conn:
            post_exists = conn.execute("SELECT id FROM forum_posts WHERE id = ?;", (scoped_post_id,)).fetchone()
            if not post_exists:
                raise ValueError("post_not_found")

            if active:
                conn.execute(
                    """
                    INSERT OR IGNORE INTO forum_post_bookmarks (user_id, post_id, created_at)
                    VALUES (?, ?, ?);
                    """,
                    (user_id.strip(), scoped_post_id, self._now_iso()),
                )
            else:
                conn.execute(
                    """
                    DELETE FROM forum_post_bookmarks
                    WHERE user_id = ? AND post_id = ?;
                    """,
                    (user_id.strip(), scoped_post_id),
                )

            row = conn.execute(
                """
                SELECT
                    p.*,
                    (SELECT COUNT(*) FROM forum_comments c WHERE c.post_id = p.id) AS comment_count,
                    (SELECT COUNT(*) FROM forum_reactions r WHERE r.post_id = p.id) AS reaction_count,
                    (SELECT reaction FROM forum_reactions vr WHERE vr.post_id = p.id AND vr.user_id = ? LIMIT 1) AS viewer_reaction,
                    EXISTS(
                        SELECT 1 FROM forum_post_bookmarks fb
                        WHERE fb.post_id = p.id AND fb.user_id = ?
                    ) AS viewer_bookmarked
                FROM forum_posts p
                WHERE p.id = ?;
                """,
                (user_id.strip(), user_id.strip(), scoped_post_id),
            ).fetchone()
            assert row is not None
            return self._post_payload(row)
