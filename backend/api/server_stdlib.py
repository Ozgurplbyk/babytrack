from __future__ import annotations

import json
import os
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path
from urllib.parse import parse_qs, urlparse

try:
    from backend.api.event_sync_store import EventSyncStore
    from backend.api.family_account_store import FamilyAccountStore
    from backend.api.forum_store import ForumStore
    from backend.api.security_controls import SlidingWindowRateLimiter, request_digest
except ModuleNotFoundError:
    from event_sync_store import EventSyncStore
    from family_account_store import FamilyAccountStore
    from forum_store import ForumStore
    from security_controls import SlidingWindowRateLimiter, request_digest

ROOT = Path(__file__).resolve().parents[2]
PAYWALL_FILE = ROOT / "config" / "paywall" / "paywall_offers.json"
LULLABY_FILE = ROOT / "content" / "lullabies" / "lullaby_catalog.json"
VACCINE_OUT = ROOT / "backend" / "vaccine_pipeline" / "output"


def _env_bool(name: str, default: bool = False) -> bool:
    raw = os.environ.get(name)
    if raw is None:
        return default
    return raw.strip().lower() in {"1", "true", "yes", "on"}


API_TOKEN = os.environ.get("BABYTRACK_API_TOKEN", "").strip()
API_TOKENS = {API_TOKEN} if API_TOKEN else set()
_multi_tokens = os.environ.get("BABYTRACK_API_TOKENS", "").strip()
if _multi_tokens:
    API_TOKENS.update(t.strip() for t in _multi_tokens.split(",") if t.strip())
SYNC_DB = Path(os.environ.get("BABYTRACK_SYNC_DB", str(ROOT / "backend" / "api" / "data" / "sync_events.db")))
RATE_LIMIT_PER_MIN = int(os.environ.get("BABYTRACK_RATE_LIMIT_PER_MIN", "120"))
SYNC_REPLAY_WINDOW_SEC = int(os.environ.get("BABYTRACK_SYNC_REPLAY_WINDOW_SEC", "300"))
SYNC_REQUIRE_DEVICE_BINDING = _env_bool("BABYTRACK_SYNC_REQUIRE_DEVICE_BINDING", default=True)
SYNC_RETENTION_DAYS = int(os.environ.get("BABYTRACK_SYNC_RETENTION_DAYS", "365"))
SYNC_RETENTION_SWEEP_SEC = int(os.environ.get("BABYTRACK_SYNC_RETENTION_SWEEP_SEC", "3600"))
EVENT_STORE = EventSyncStore(
    SYNC_DB,
    default_event_retention_days=SYNC_RETENTION_DAYS,
    retention_sweep_interval_sec=SYNC_RETENTION_SWEEP_SEC,
)
FAMILY_STORE = FamilyAccountStore(SYNC_DB)
FORUM_STORE = ForumStore(SYNC_DB)
RATE_LIMITER = SlidingWindowRateLimiter(RATE_LIMIT_PER_MIN, 60) if RATE_LIMIT_PER_MIN > 0 else None
FORUM_ADMIN_USER_IDS = {
    user_id.strip()
    for user_id in os.environ.get("BABYTRACK_FORUM_ADMIN_USER_IDS", "").split(",")
    if user_id.strip()
}


def load_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


class Handler(BaseHTTPRequestHandler):
    def _is_authorized(self) -> bool:
        if not API_TOKENS:
            return True
        auth = self.headers.get("Authorization", "")
        if not auth.startswith("Bearer "):
            return False
        token = auth.removeprefix("Bearer ").strip()
        return token in API_TOKENS

    def _send(self, code: int, payload: dict):
        body = json.dumps(payload).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _json_body(self) -> dict:
        content_length = int(self.headers.get("Content-Length", "0"))
        raw = self.rfile.read(content_length)
        try:
            return json.loads(raw.decode("utf-8"))
        except Exception:
            return {}

    def _rate_limit_key(self) -> str:
        auth = self.headers.get("Authorization", "").strip()
        if auth:
            return f"token:{auth}"
        return f"ip:{self.client_address[0]}"

    def _within_rate_limit(self) -> bool:
        if RATE_LIMITER is None:
            return True
        return RATE_LIMITER.allow(self._rate_limit_key())

    def _user_from_token(self) -> dict | None:
        token = self.headers.get("X-BabyTrack-User-Token", "").strip()
        if not token:
            return None
        return FAMILY_STORE.get_user_for_session_token(token)

    def _is_forum_admin(self, user: dict) -> bool:
        if not FORUM_ADMIN_USER_IDS:
            return True
        return str(user.get("id", "")).strip() in FORUM_ADMIN_USER_IDS

    def do_GET(self):
        parsed = urlparse(self.path)
        path = parsed.path
        query = parse_qs(parsed.query)

        if path == "/health":
            return self._send(200, {"status": "ok", "timestamp": datetime.now(timezone.utc).isoformat()})

        if path.startswith("/v1/") and not self._within_rate_limit():
            return self._send(429, {"error": "rate_limit_exceeded"})

        if path.startswith("/v1/") and not self._is_authorized():
            return self._send(401, {"error": "unauthorized"})

        if path == "/v1/config/paywall":
            return self._send(200, load_json(PAYWALL_FILE))

        if path == "/v1/events/stats":
            return self._send(200, EVENT_STORE.stats())

        if path.startswith("/v1/config/lullabies/"):
            cc = path.split("/")[-1].upper()
            payload = load_json(LULLABY_FILE)
            for country in payload.get("countries", []):
                if country.get("countryCode", "").upper() == cc:
                    return self._send(200, country)
            if payload.get("countries"):
                return self._send(200, payload["countries"][0])
            return self._send(404, {"error": "no lullabies"})

        if path.startswith("/v1/vaccines/packages/") and path.endswith("/latest"):
            parts = path.strip("/").split("/")
            cc = parts[3].upper() if len(parts) >= 5 else "TR"
            matches = sorted(VACCINE_OUT.glob(f"{cc}_*.json"))
            if not matches:
                return self._send(404, {"error": f"no package for {cc}"})
            return self._send(200, load_json(matches[-1]))

        if path == "/v1/vaccines/packages/index":
            latest_by_country: dict[str, Path] = {}
            for package in sorted(VACCINE_OUT.glob("*_*.json")):
                cc = package.stem.split("_", maxsplit=1)[0].upper()
                if cc not in latest_by_country or package.name > latest_by_country[cc].name:
                    latest_by_country[cc] = package
            packages = []
            for cc in sorted(latest_by_country.keys()):
                package = latest_by_country[cc]
                package_doc = load_json(package)
                payload = package_doc.get("payload", {})
                meta = package_doc.get("meta", {})
                source = payload.get("source", {}) if isinstance(payload.get("source"), dict) else {}
                packages.append(
                    {
                        "country": cc,
                        "authority": payload.get("authority", ""),
                        "version": payload.get("version", ""),
                        "updatedAt": datetime.fromtimestamp(package.stat().st_mtime, timezone.utc).isoformat(),
                        "publishedAt": str(meta.get("published_at", "")),
                        "sourceName": str(source.get("name", "")),
                        "sourceUrl": str(source.get("url", "")),
                        "sourceUpdatedAt": str(source.get("source_updated_at", "")),
                    }
                )
            return self._send(200, {"packages": packages})

        if path == "/v1/auth/me":
            user = self._user_from_token()
            if not user:
                return self._send(401, {"error": "user_session_required"})
            return self._send(200, {"user": user})

        if path.startswith("/v1/family/") and path.endswith("/invites"):
            user = self._user_from_token()
            if not user:
                return self._send(401, {"error": "user_session_required"})
            parts = path.strip("/").split("/")
            if len(parts) < 4:
                return self._send(404, {"error": "not_found"})
            child_id = parts[2]
            invites = FAMILY_STORE.list_invites(child_id=child_id, user_id=user["id"])
            return self._send(200, {"invites": invites})

        if path == "/v1/forum/posts":
            user = self._user_from_token()
            if not user:
                return self._send(401, {"error": "user_session_required"})
            country = str((query.get("countryCode") or [""])[0]).strip().upper()
            try:
                limit = int((query.get("limit") or ["30"])[0])
            except ValueError:
                limit = 30
            posts = FORUM_STORE.list_posts(viewer_user_id=user["id"], country_code=country, limit=limit)
            return self._send(200, {"posts": posts})

        if path.startswith("/v1/forum/posts/") and path.endswith("/comments"):
            user = self._user_from_token()
            if not user:
                return self._send(401, {"error": "user_session_required"})
            parts = path.strip("/").split("/")
            if len(parts) < 5:
                return self._send(404, {"error": "not_found"})
            post_id = parts[3]
            try:
                limit = int((query.get("limit") or ["80"])[0])
            except ValueError:
                limit = 80
            comments = FORUM_STORE.list_comments(post_id=post_id, limit=limit)
            return self._send(200, {"comments": comments})

        if path == "/v1/forum/admin/reports":
            user = self._user_from_token()
            if not user:
                return self._send(401, {"error": "user_session_required"})
            if not self._is_forum_admin(user):
                return self._send(403, {"error": "forum_admin_required"})
            status = str((query.get("status") or [""])[0]).strip()
            try:
                limit = int((query.get("limit") or ["100"])[0])
            except ValueError:
                limit = 100
            reports = FORUM_STORE.list_reports(status=status, limit=limit)
            return self._send(200, {"reports": reports})

        return self._send(404, {"error": "not found"})

    def do_POST(self):
        parsed = urlparse(self.path)
        path = parsed.path

        if path.startswith("/v1/") and not self._within_rate_limit():
            return self._send(429, {"error": "rate_limit_exceeded"})

        if path.startswith("/v1/") and not self._is_authorized():
            return self._send(401, {"error": "unauthorized"})

        if path == "/v1/auth/register":
            payload = self._json_body()
            try:
                user = FAMILY_STORE.create_user(
                    email=str(payload.get("email", "")),
                    password=str(payload.get("password", "")),
                    display_name=str(payload.get("displayName", "")),
                )
            except ValueError as exc:
                reason = str(exc)
                if reason == "email_exists":
                    return self._send(409, {"error": "email_exists"})
                if reason == "invalid_email":
                    return self._send(400, {"error": "invalid_email"})
                if reason == "weak_password":
                    return self._send(400, {"error": "weak_password"})
                return self._send(400, {"error": "invalid_payload"})

            token = FAMILY_STORE.create_session(user["id"])
            return self._send(200, {"token": token, "user": user})

        if path == "/v1/auth/login":
            payload = self._json_body()
            user = FAMILY_STORE.authenticate(
                email=str(payload.get("email", "")),
                password=str(payload.get("password", "")),
            )
            if not user:
                return self._send(401, {"error": "invalid_credentials"})
            token = FAMILY_STORE.create_session(user["id"])
            return self._send(200, {"token": token, "user": user})

        if path == "/v1/auth/logout":
            token = self.headers.get("X-BabyTrack-User-Token", "").strip()
            if token:
                FAMILY_STORE.delete_session(token)
            return self._send(200, {"ok": True})

        if path == "/v1/events/sync":
            payload = self._json_body()
            if not payload:
                return self._send(400, {"error": "invalid json"})

            device_id = self.headers.get("X-BabyTrack-Device-Id", "").strip()
            nonce = self.headers.get("X-BabyTrack-Nonce", "").strip()
            has_device_binding = bool(device_id or nonce)
            if SYNC_REQUIRE_DEVICE_BINDING and not has_device_binding:
                return self._send(400, {"error": "device_binding_required"})
            if has_device_binding and (not device_id or not nonce):
                return self._send(400, {"error": "invalid_device_binding_headers"})
            if len(device_id) > 128 or len(nonce) > 128:
                return self._send(400, {"error": "device_binding_headers_too_long"})

            if has_device_binding and SYNC_REPLAY_WINDOW_SEC > 0:
                if not EVENT_STORE.register_device_nonce(device_id, nonce, SYNC_REPLAY_WINDOW_SEC):
                    return self._send(409, {"error": "replay_detected"})

            if SYNC_REPLAY_WINDOW_SEC > 0:
                digest_payload: dict[str, object] = payload
                if has_device_binding:
                    digest_payload = {
                        "deviceId": device_id,
                        "nonce": nonce,
                        "payload": payload,
                    }
                digest = request_digest(digest_payload)
                if not EVENT_STORE.register_request_digest(digest, SYNC_REPLAY_WINDOW_SEC):
                    return self._send(409, {"error": "replay_detected"})

            events = payload.get("events", [])
            accepted = 0
            rejected = 0
            conflicts = []
            for event in events:
                accepted_event, reason = EVENT_STORE.upsert_event_with_status(
                    event,
                    country_code=str(payload.get("countryCode", "TR")),
                    app_version=str(payload.get("appVersion", "0")),
                    source_device_id=device_id,
                )
                if accepted_event:
                    accepted += 1
                else:
                    rejected += 1
                    event_id = str(event.get("id", "")).strip()
                    if event_id and reason == "conflict_remote_update":
                        remote_event = EVENT_STORE.get_event_raw(event_id)
                        conflicts.append({"eventId": event_id, "reason": reason, "remoteEvent": remote_event})

            EVENT_STORE.apply_retention_policy(
                guard_retention_sec=max(SYNC_REPLAY_WINDOW_SEC * 4, 86400)
            )

            return self._send(200, {"acceptedCount": accepted, "rejectedCount": rejected, "conflicts": conflicts})

        if path == "/v1/events/conflicts/resolve":
            payload = self._json_body()
            event_id = str(payload.get("eventId", "")).strip()
            strategy = str(payload.get("strategy", "")).strip().lower()
            country_code = str(payload.get("countryCode", "TR"))
            app_version = str(payload.get("appVersion", "0"))
            device_id = self.headers.get("X-BabyTrack-Device-Id", "").strip()

            if not event_id:
                return self._send(400, {"error": "event_id_required"})
            if strategy not in {"keep_local", "keep_remote", "merge"}:
                return self._send(400, {"error": "unsupported_strategy"})

            remote = EVENT_STORE.get_event_raw(event_id)
            if not remote:
                return self._send(404, {"error": "remote_event_not_found"})

            if strategy == "keep_remote":
                return self._send(200, {"ok": True, "strategy": strategy, "event": remote})

            if strategy == "keep_local":
                local = payload.get("localEvent")
                if not isinstance(local, dict):
                    return self._send(400, {"error": "local_event_required"})
                local["id"] = event_id
                accepted_event, reason = EVENT_STORE.upsert_event_with_status(
                    local,
                    country_code=country_code,
                    app_version=app_version,
                    source_device_id=device_id,
                    force=True,
                )
                if not accepted_event:
                    return self._send(400, {"error": reason})
                resolved = EVENT_STORE.get_event_raw(event_id)
                return self._send(200, {"ok": True, "strategy": strategy, "event": resolved})

            merged = payload.get("mergedEvent")
            if not isinstance(merged, dict):
                return self._send(400, {"error": "merged_event_required"})
            merged["id"] = event_id
            accepted_event, reason = EVENT_STORE.upsert_event_with_status(
                merged,
                country_code=country_code,
                app_version=app_version,
                source_device_id=device_id,
                force=True,
            )
            if not accepted_event:
                return self._send(400, {"error": reason})
            resolved = EVENT_STORE.get_event_raw(event_id)
            return self._send(200, {"ok": True, "strategy": strategy, "event": resolved})

        if path == "/v1/forum/posts":
            user = self._user_from_token()
            if not user:
                return self._send(401, {"error": "user_session_required"})
            payload = self._json_body()
            try:
                post = FORUM_STORE.create_post(
                    user_id=user["id"],
                    author_name=str(user.get("displayName", "")),
                    title=str(payload.get("title", "")),
                    body=str(payload.get("body", "")),
                    country_code=str(payload.get("countryCode", "")),
                    child_id=str(payload.get("childId", "")),
                    tags=payload.get("tags") if isinstance(payload.get("tags"), list) else [],
                )
            except ValueError as exc:
                return self._send(400, {"error": str(exc)})
            return self._send(200, {"post": post})

        if path.startswith("/v1/forum/posts/") and path.endswith("/comments"):
            user = self._user_from_token()
            if not user:
                return self._send(401, {"error": "user_session_required"})
            parts = path.strip("/").split("/")
            if len(parts) < 5:
                return self._send(404, {"error": "not_found"})
            post_id = parts[3]
            payload = self._json_body()
            try:
                comment = FORUM_STORE.create_comment(
                    post_id=post_id,
                    user_id=user["id"],
                    author_name=str(user.get("displayName", "")),
                    body=str(payload.get("body", "")),
                )
            except ValueError as exc:
                reason = str(exc)
                if reason == "post_not_found":
                    return self._send(404, {"error": reason})
                return self._send(400, {"error": reason})
            return self._send(200, {"comment": comment})

        if path.startswith("/v1/forum/posts/") and path.endswith("/reactions"):
            user = self._user_from_token()
            if not user:
                return self._send(401, {"error": "user_session_required"})
            parts = path.strip("/").split("/")
            if len(parts) < 5:
                return self._send(404, {"error": "not_found"})
            post_id = parts[3]
            payload = self._json_body()
            try:
                summary = FORUM_STORE.set_reaction(
                    post_id=post_id,
                    user_id=user["id"],
                    reaction=str(payload.get("reaction", "support")),
                    active=bool(payload.get("active", True)),
                )
            except ValueError as exc:
                reason = str(exc)
                if reason == "post_not_found":
                    return self._send(404, {"error": reason})
                return self._send(400, {"error": reason})
            return self._send(200, {"summary": summary})

        if path.startswith("/v1/forum/posts/") and path.endswith("/report"):
            user = self._user_from_token()
            if not user:
                return self._send(401, {"error": "user_session_required"})
            parts = path.strip("/").split("/")
            if len(parts) < 5:
                return self._send(404, {"error": "not_found"})
            post_id = parts[3]
            payload = self._json_body()
            try:
                report = FORUM_STORE.report_post(
                    post_id=post_id,
                    reporter_user_id=user["id"],
                    reason=str(payload.get("reason", "other")),
                    note=str(payload.get("note", "")),
                )
            except ValueError as exc:
                reason = str(exc)
                if reason == "post_not_found":
                    return self._send(404, {"error": reason})
                return self._send(400, {"error": reason})
            return self._send(200, {"report": report})

        if path.startswith("/v1/forum/posts/") and path.endswith("/mute"):
            user = self._user_from_token()
            if not user:
                return self._send(401, {"error": "user_session_required"})
            parts = path.strip("/").split("/")
            if len(parts) < 5:
                return self._send(404, {"error": "not_found"})
            post_id = parts[3]
            muted = FORUM_STORE.mute_post(user_id=user["id"], post_id=post_id)
            if not muted:
                return self._send(404, {"error": "post_not_found"})
            return self._send(200, {"ok": True})

        if path.startswith("/v1/forum/users/") and path.endswith("/block"):
            user = self._user_from_token()
            if not user:
                return self._send(401, {"error": "user_session_required"})
            parts = path.strip("/").split("/")
            if len(parts) < 5:
                return self._send(404, {"error": "not_found"})
            target_user_id = parts[3]
            blocked = FORUM_STORE.block_user(user_id=user["id"], target_user_id=target_user_id)
            if not blocked:
                return self._send(400, {"error": "invalid_block_target"})
            return self._send(200, {"ok": True})

        if path.startswith("/v1/forum/admin/reports/") and path.endswith("/resolve"):
            user = self._user_from_token()
            if not user:
                return self._send(401, {"error": "user_session_required"})
            if not self._is_forum_admin(user):
                return self._send(403, {"error": "forum_admin_required"})
            parts = path.strip("/").split("/")
            if len(parts) < 6:
                return self._send(404, {"error": "not_found"})
            report_id = parts[4]
            payload = self._json_body()
            report = FORUM_STORE.resolve_report(
                report_id=report_id,
                reviewer_user_id=user["id"],
                status=str(payload.get("status", "")),
            )
            if not report:
                return self._send(404, {"error": "report_not_found_or_invalid_status"})
            return self._send(200, {"report": report})

        if path.startswith("/v1/family/") and path.endswith("/invites"):
            user = self._user_from_token()
            if not user:
                return self._send(401, {"error": "user_session_required"})
            parts = path.strip("/").split("/")
            if len(parts) < 4:
                return self._send(404, {"error": "not_found"})
            child_id = parts[2]
            payload = self._json_body()
            try:
                invite = FAMILY_STORE.create_invite(
                    child_id=child_id,
                    user_id=user["id"],
                    role=str(payload.get("role", "")),
                    display_name=str(payload.get("displayName", "")),
                )
            except ValueError:
                return self._send(400, {"error": "invalid_payload"})
            return self._send(200, {"invite": invite})

        if path == "/v1/family/invites/join":
            user = self._user_from_token()
            if not user:
                return self._send(401, {"error": "user_session_required"})
            payload = self._json_body()
            invite = FAMILY_STORE.join_invite(code=str(payload.get("code", "")), user_id=user["id"])
            if not invite:
                return self._send(404, {"error": "invite_not_found_or_used"})
            return self._send(200, {"invite": invite})

        if path.startswith("/v1/family/invites/") and path.endswith("/status"):
            user = self._user_from_token()
            if not user:
                return self._send(401, {"error": "user_session_required"})
            invite_id = path.strip("/").split("/")[3]
            payload = self._json_body()
            invite = FAMILY_STORE.set_invite_status(
                invite_id=invite_id,
                user_id=user["id"],
                status=str(payload.get("status", "")),
            )
            if not invite:
                return self._send(404, {"error": "invite_not_found_or_forbidden"})
            return self._send(200, {"invite": invite})

        return self._send(404, {"error": "not found"})

    def do_DELETE(self):
        parsed = urlparse(self.path)
        path = parsed.path

        if path.startswith("/v1/") and not self._within_rate_limit():
            return self._send(429, {"error": "rate_limit_exceeded"})

        if path.startswith("/v1/") and not self._is_authorized():
            return self._send(401, {"error": "unauthorized"})

        if path.startswith("/v1/family/invites/"):
            user = self._user_from_token()
            if not user:
                return self._send(401, {"error": "user_session_required"})
            invite_id = path.strip("/").split("/")[3]
            deleted = FAMILY_STORE.delete_invite(invite_id=invite_id, user_id=user["id"])
            if not deleted:
                return self._send(404, {"error": "invite_not_found_or_forbidden"})
            return self._send(200, {"ok": True})

        return self._send(404, {"error": "not found"})


def main() -> int:
    host = "127.0.0.1"
    port = 8787
    server = HTTPServer((host, port), Handler)
    print(f"stdlib api listening on http://{host}:{port}")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
