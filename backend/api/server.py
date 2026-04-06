from __future__ import annotations

import json
import os
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from fastapi import Depends, FastAPI, Header, HTTPException, Request
from pydantic import BaseModel

from .event_sync_store import EventSyncStore
from .family_account_store import FamilyAccountStore
from .forum_store import ForumStore
from .security_controls import SlidingWindowRateLimiter, request_digest

ROOT = Path(__file__).resolve().parents[2]
PAYWALL_FILE = ROOT / "config" / "paywall" / "paywall_offers.json"
LULLABY_FILE = ROOT / "content" / "lullabies" / "lullaby_catalog.json"
VACCINE_OUT = ROOT / "backend" / "vaccine_pipeline" / "output"


def _env_bool(name: str, default: bool = False) -> bool:
    raw = os.environ.get(name)
    if raw is None:
        return default
    return raw.strip().lower() in {"1", "true", "yes", "on"}


def _load_api_tokens() -> set[str]:
    tokens: set[str] = set()
    single = os.environ.get("BABYTRACK_API_TOKEN", "").strip()
    if single:
        tokens.add(single)
    multi = os.environ.get("BABYTRACK_API_TOKENS", "").strip()
    if multi:
        for t in multi.split(","):
            v = t.strip()
            if v:
                tokens.add(v)
    return tokens


API_TOKENS = _load_api_tokens()
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

app = FastAPI(title="BabyTrack API", version="1.0.0")


class SyncEnvelope(BaseModel):
    countryCode: str
    appVersion: str
    events: list[dict[str, Any]]


class SyncResult(BaseModel):
    acceptedCount: int
    rejectedCount: int
    conflicts: list[dict[str, Any]] = []


class ConflictResolveRequest(BaseModel):
    eventId: str
    strategy: str
    countryCode: str = "TR"
    appVersion: str = "0"
    localEvent: dict[str, Any] | None = None
    mergedEvent: dict[str, Any] | None = None


class ConflictResolveResult(BaseModel):
    ok: bool
    strategy: str
    event: dict[str, Any] | None = None


class AuthRequest(BaseModel):
    email: str
    password: str
    displayName: str | None = None


class FamilyInviteCreateRequest(BaseModel):
    role: str
    displayName: str = ""


class FamilyInviteJoinRequest(BaseModel):
    code: str


class FamilyInviteStatusRequest(BaseModel):
    status: str


class ForumPostCreateRequest(BaseModel):
    title: str = ""
    body: str
    tags: list[str] = []
    countryCode: str = ""
    childId: str = ""


class ForumCommentCreateRequest(BaseModel):
    body: str


class ForumReactionRequest(BaseModel):
    reaction: str = "support"
    active: bool = True


class ForumReportRequest(BaseModel):
    reason: str = "other"
    note: str = ""


class ForumReportResolveRequest(BaseModel):
    status: str


def _load_json(path: Path) -> dict[str, Any]:
    if not path.exists():
        raise HTTPException(status_code=404, detail=f"Not found: {path.name}")
    return json.loads(path.read_text(encoding="utf-8"))


def _require_auth(authorization: str | None = Header(default=None)) -> None:
    if not API_TOKENS:
        return

    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Unauthorized")
    token = authorization.removeprefix("Bearer ").strip()
    if token not in API_TOKENS:
        raise HTTPException(status_code=401, detail="Unauthorized")


def _rate_limit_key(request: Request, authorization: str | None) -> str:
    if authorization and authorization.strip():
        return f"token:{authorization.strip()}"
    ip = request.client.host if request.client else "unknown"
    return f"ip:{ip}"


def _enforce_rate_limit(request: Request, authorization: str | None = Header(default=None)) -> None:
    if RATE_LIMITER is None:
        return
    if not RATE_LIMITER.allow(_rate_limit_key(request, authorization)):
        raise HTTPException(status_code=429, detail="Rate limit exceeded")


def _require_user(
    x_babytrack_user_token: str | None = Header(default=None, alias="X-BabyTrack-User-Token"),
) -> dict[str, Any]:
    token = (x_babytrack_user_token or "").strip()
    user = FAMILY_STORE.get_user_for_session_token(token)
    if not user:
        raise HTTPException(status_code=401, detail="User session required")
    return user


def _require_forum_admin(user: dict[str, Any]) -> None:
    if not FORUM_ADMIN_USER_IDS:
        return
    user_id = str(user.get("id", "")).strip()
    if user_id not in FORUM_ADMIN_USER_IDS:
        raise HTTPException(status_code=403, detail="Forum admin required")


@app.get("/health")
def health() -> dict[str, Any]:
    return {
        "status": "ok",
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }


@app.get("/v1/config/paywall", dependencies=[Depends(_require_auth), Depends(_enforce_rate_limit)])
def paywall_config() -> dict[str, Any]:
    return _load_json(PAYWALL_FILE)


@app.get("/v1/config/lullabies/{country_code}", dependencies=[Depends(_require_auth), Depends(_enforce_rate_limit)])
def lullabies(country_code: str) -> dict[str, Any]:
    payload = _load_json(LULLABY_FILE)
    cc = country_code.upper()
    for entry in payload.get("countries", []):
        if entry.get("countryCode", "").upper() == cc:
            return entry

    if payload.get("countries"):
        return payload["countries"][0]
    raise HTTPException(status_code=404, detail="No lullaby entries")


@app.get("/v1/vaccines/packages/{country_code}/latest", dependencies=[Depends(_require_auth), Depends(_enforce_rate_limit)])
def latest_vaccine_package(country_code: str) -> dict[str, Any]:
    cc = country_code.upper()
    matches = sorted(VACCINE_OUT.glob(f"{cc}_*.json"))
    if not matches:
        raise HTTPException(status_code=404, detail=f"No package for {cc}")
    return _load_json(matches[-1])


@app.get("/v1/vaccines/packages/index", dependencies=[Depends(_require_auth), Depends(_enforce_rate_limit)])
def vaccine_package_index() -> dict[str, Any]:
    latest_by_country: dict[str, Path] = {}
    for path in sorted(VACCINE_OUT.glob("*_*.json")):
        cc = path.stem.split("_", maxsplit=1)[0].upper()
        if cc not in latest_by_country or path.name > latest_by_country[cc].name:
            latest_by_country[cc] = path

    packages: list[dict[str, Any]] = []
    for cc in sorted(latest_by_country.keys()):
        path = latest_by_country[cc]
        package_doc = _load_json(path)
        payload = package_doc.get("payload", {})
        meta = package_doc.get("meta", {})
        source = payload.get("source", {}) if isinstance(payload.get("source"), dict) else {}
        packages.append(
            {
                "country": cc,
                "authority": payload.get("authority", ""),
                "version": payload.get("version", ""),
                "updatedAt": datetime.fromtimestamp(path.stat().st_mtime, timezone.utc).isoformat(),
                "publishedAt": str(meta.get("published_at", "")),
                "sourceName": str(source.get("name", "")),
                "sourceUrl": str(source.get("url", "")),
                "sourceUpdatedAt": str(source.get("source_updated_at", "")),
            }
        )

    return {"packages": packages}


@app.post("/v1/auth/register", dependencies=[Depends(_enforce_rate_limit)])
def auth_register(payload: AuthRequest) -> dict[str, Any]:
    try:
        user = FAMILY_STORE.create_user(
            email=payload.email,
            password=payload.password,
            display_name=payload.displayName or "",
        )
    except ValueError as exc:
        reason = str(exc)
        if reason == "email_exists":
            raise HTTPException(status_code=409, detail="Email already registered") from exc
        if reason == "invalid_email":
            raise HTTPException(status_code=400, detail="Invalid email") from exc
        if reason == "weak_password":
            raise HTTPException(status_code=400, detail="Password must be at least 6 chars") from exc
        raise HTTPException(status_code=400, detail="Invalid input") from exc

    token = FAMILY_STORE.create_session(user["id"])
    return {"token": token, "user": user}


@app.post("/v1/auth/login", dependencies=[Depends(_enforce_rate_limit)])
def auth_login(payload: AuthRequest) -> dict[str, Any]:
    user = FAMILY_STORE.authenticate(payload.email, payload.password)
    if not user:
        raise HTTPException(status_code=401, detail="Invalid credentials")
    token = FAMILY_STORE.create_session(user["id"])
    return {"token": token, "user": user}


@app.get("/v1/auth/me", dependencies=[Depends(_enforce_rate_limit)])
def auth_me(user: dict[str, Any] = Depends(_require_user)) -> dict[str, Any]:
    return {"user": user}


@app.post("/v1/auth/logout", dependencies=[Depends(_enforce_rate_limit)])
def auth_logout(
    x_babytrack_user_token: str | None = Header(default=None, alias="X-BabyTrack-User-Token"),
) -> dict[str, Any]:
    token = (x_babytrack_user_token or "").strip()
    if token:
        FAMILY_STORE.delete_session(token)
    return {"ok": True}


@app.get("/v1/family/{child_id}/invites", dependencies=[Depends(_enforce_rate_limit)])
def family_invites(child_id: str, user: dict[str, Any] = Depends(_require_user)) -> dict[str, Any]:
    invites = FAMILY_STORE.list_invites(child_id=child_id, user_id=user["id"])
    return {"invites": invites}


@app.post("/v1/family/{child_id}/invites", dependencies=[Depends(_enforce_rate_limit)])
def family_invite_create(
    child_id: str,
    payload: FamilyInviteCreateRequest,
    user: dict[str, Any] = Depends(_require_user),
) -> dict[str, Any]:
    try:
        invite = FAMILY_STORE.create_invite(
            child_id=child_id,
            user_id=user["id"],
            role=payload.role,
            display_name=payload.displayName,
        )
    except ValueError as exc:
        raise HTTPException(status_code=400, detail="Invalid invite payload") from exc
    return {"invite": invite}


@app.post("/v1/family/invites/join", dependencies=[Depends(_enforce_rate_limit)])
def family_invite_join(
    payload: FamilyInviteJoinRequest,
    user: dict[str, Any] = Depends(_require_user),
) -> dict[str, Any]:
    invite = FAMILY_STORE.join_invite(code=payload.code, user_id=user["id"])
    if not invite:
        raise HTTPException(status_code=404, detail="Invite not found or already used")
    return {"invite": invite}


@app.post("/v1/family/invites/{invite_id}/status", dependencies=[Depends(_enforce_rate_limit)])
def family_invite_status(
    invite_id: str,
    payload: FamilyInviteStatusRequest,
    user: dict[str, Any] = Depends(_require_user),
) -> dict[str, Any]:
    invite = FAMILY_STORE.set_invite_status(
        invite_id=invite_id,
        user_id=user["id"],
        status=payload.status,
    )
    if not invite:
        raise HTTPException(status_code=404, detail="Invite not found or forbidden")
    return {"invite": invite}


@app.delete("/v1/family/invites/{invite_id}", dependencies=[Depends(_enforce_rate_limit)])
def family_invite_delete(invite_id: str, user: dict[str, Any] = Depends(_require_user)) -> dict[str, Any]:
    deleted = FAMILY_STORE.delete_invite(invite_id=invite_id, user_id=user["id"])
    if not deleted:
        raise HTTPException(status_code=404, detail="Invite not found or forbidden")
    return {"ok": True}


@app.get("/v1/forum/posts", dependencies=[Depends(_enforce_rate_limit)])
def forum_posts(
    countryCode: str = "",
    limit: int = 30,
    query: str = "",
    tag: str = "",
    scope: str = "all",
    user: dict[str, Any] = Depends(_require_user),
) -> dict[str, Any]:
    posts = FORUM_STORE.list_posts(
        viewer_user_id=user["id"],
        country_code=countryCode,
        limit=limit,
        query=query,
        tag=tag,
        author_scope=scope,
    )
    return {"posts": posts}


@app.post("/v1/forum/posts", dependencies=[Depends(_enforce_rate_limit)])
def forum_post_create(
    payload: ForumPostCreateRequest,
    user: dict[str, Any] = Depends(_require_user),
) -> dict[str, Any]:
    try:
        post = FORUM_STORE.create_post(
            user_id=user["id"],
            author_name=user.get("displayName", ""),
            title=payload.title,
            body=payload.body,
            country_code=payload.countryCode,
            child_id=payload.childId,
            tags=payload.tags,
        )
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    return {"post": post}


@app.get("/v1/forum/posts/{post_id}/comments", dependencies=[Depends(_enforce_rate_limit)])
def forum_comments(post_id: str, limit: int = 80, user: dict[str, Any] = Depends(_require_user)) -> dict[str, Any]:
    _ = user
    comments = FORUM_STORE.list_comments(post_id=post_id, limit=limit)
    return {"comments": comments}


@app.post("/v1/forum/posts/{post_id}/comments", dependencies=[Depends(_enforce_rate_limit)])
def forum_comment_create(
    post_id: str,
    payload: ForumCommentCreateRequest,
    user: dict[str, Any] = Depends(_require_user),
) -> dict[str, Any]:
    try:
        comment = FORUM_STORE.create_comment(
            post_id=post_id,
            user_id=user["id"],
            author_name=user.get("displayName", ""),
            body=payload.body,
        )
    except ValueError as exc:
        reason = str(exc)
        if reason == "post_not_found":
            raise HTTPException(status_code=404, detail=reason) from exc
        raise HTTPException(status_code=400, detail=reason) from exc
    return {"comment": comment}


@app.post("/v1/forum/posts/{post_id}/reactions", dependencies=[Depends(_enforce_rate_limit)])
def forum_reaction_set(
    post_id: str,
    payload: ForumReactionRequest,
    user: dict[str, Any] = Depends(_require_user),
) -> dict[str, Any]:
    try:
        summary = FORUM_STORE.set_reaction(
            post_id=post_id,
            user_id=user["id"],
            reaction=payload.reaction,
            active=payload.active,
        )
    except ValueError as exc:
        reason = str(exc)
        if reason == "post_not_found":
            raise HTTPException(status_code=404, detail=reason) from exc
        raise HTTPException(status_code=400, detail=reason) from exc
    return {"summary": summary}


@app.post("/v1/forum/posts/{post_id}/report", dependencies=[Depends(_enforce_rate_limit)])
def forum_report_post(
    post_id: str,
    payload: ForumReportRequest,
    user: dict[str, Any] = Depends(_require_user),
) -> dict[str, Any]:
    try:
        report = FORUM_STORE.report_post(
            post_id=post_id,
            reporter_user_id=user["id"],
            reason=payload.reason,
            note=payload.note,
        )
    except ValueError as exc:
        reason = str(exc)
        if reason == "post_not_found":
            raise HTTPException(status_code=404, detail=reason) from exc
        raise HTTPException(status_code=400, detail=reason) from exc
    return {"report": report}


@app.post("/v1/forum/posts/{post_id}/mute", dependencies=[Depends(_enforce_rate_limit)])
def forum_mute_post(post_id: str, user: dict[str, Any] = Depends(_require_user)) -> dict[str, Any]:
    muted = FORUM_STORE.mute_post(user_id=user["id"], post_id=post_id)
    if not muted:
        raise HTTPException(status_code=404, detail="post_not_found")
    return {"ok": True}


@app.post("/v1/forum/users/{target_user_id}/block", dependencies=[Depends(_enforce_rate_limit)])
def forum_block_user(target_user_id: str, user: dict[str, Any] = Depends(_require_user)) -> dict[str, Any]:
    blocked = FORUM_STORE.block_user(user_id=user["id"], target_user_id=target_user_id)
    if not blocked:
        raise HTTPException(status_code=400, detail="invalid_block_target")
    return {"ok": True}


@app.get("/v1/forum/admin/reports", dependencies=[Depends(_enforce_rate_limit)])
def forum_admin_reports(
    status: str = "",
    limit: int = 100,
    user: dict[str, Any] = Depends(_require_user),
) -> dict[str, Any]:
    _require_forum_admin(user)
    reports = FORUM_STORE.list_reports(status=status, limit=limit)
    return {"reports": reports}


@app.post("/v1/forum/admin/reports/{report_id}/resolve", dependencies=[Depends(_enforce_rate_limit)])
def forum_admin_resolve_report(
    report_id: str,
    payload: ForumReportResolveRequest,
    user: dict[str, Any] = Depends(_require_user),
) -> dict[str, Any]:
    _require_forum_admin(user)
    report = FORUM_STORE.resolve_report(
        report_id=report_id,
        reviewer_user_id=user["id"],
        status=payload.status,
    )
    if not report:
        raise HTTPException(status_code=404, detail="report_not_found_or_invalid_status")
    return {"report": report}


@app.post(
    "/v1/events/sync",
    response_model=SyncResult,
    dependencies=[Depends(_require_auth), Depends(_enforce_rate_limit)],
)
def sync_events_with_headers(
    payload: SyncEnvelope,
    x_babytrack_device_id: str | None = Header(default=None, alias="X-BabyTrack-Device-Id"),
    x_babytrack_nonce: str | None = Header(default=None, alias="X-BabyTrack-Nonce"),
) -> SyncResult:
    device_id = (x_babytrack_device_id or "").strip()
    nonce = (x_babytrack_nonce or "").strip()
    has_device_binding = bool(device_id or nonce)

    if SYNC_REQUIRE_DEVICE_BINDING and not has_device_binding:
        raise HTTPException(status_code=400, detail="Device binding headers required")
    if has_device_binding and (not device_id or not nonce):
        raise HTTPException(status_code=400, detail="Both device id and nonce headers must be set")
    if len(device_id) > 128 or len(nonce) > 128:
        raise HTTPException(status_code=400, detail="Device binding headers too long")

    if has_device_binding and SYNC_REPLAY_WINDOW_SEC > 0:
        if not EVENT_STORE.register_device_nonce(device_id, nonce, SYNC_REPLAY_WINDOW_SEC):
            raise HTTPException(status_code=409, detail="Replay detected")

    if SYNC_REPLAY_WINDOW_SEC > 0:
        digest_payload: dict[str, Any] = payload.model_dump()
        if has_device_binding:
            digest_payload = {
                "deviceId": device_id,
                "nonce": nonce,
                "payload": digest_payload,
            }
        digest = request_digest(digest_payload)
        if not EVENT_STORE.register_request_digest(digest, SYNC_REPLAY_WINDOW_SEC):
            raise HTTPException(status_code=409, detail="Replay detected")

    accepted = 0
    rejected = 0
    conflicts: list[dict[str, Any]] = []

    for item in payload.events:
        accepted_event, reason = EVENT_STORE.upsert_event_with_status(
            item,
            country_code=payload.countryCode,
            app_version=payload.appVersion,
            source_device_id=device_id,
        )
        if accepted_event:
            accepted += 1
        else:
            rejected += 1
            event_id = str(item.get("id", "")).strip()
            if event_id and reason == "conflict_remote_update":
                remote_event = EVENT_STORE.get_event_raw(event_id)
                conflicts.append({"eventId": event_id, "reason": reason, "remoteEvent": remote_event})

    EVENT_STORE.apply_retention_policy(
        guard_retention_sec=max(SYNC_REPLAY_WINDOW_SEC * 4, 86400),
    )

    return SyncResult(acceptedCount=accepted, rejectedCount=rejected, conflicts=conflicts)


@app.post(
    "/v1/events/conflicts/resolve",
    response_model=ConflictResolveResult,
    dependencies=[Depends(_require_auth), Depends(_enforce_rate_limit)],
)
def resolve_sync_conflict(
    payload: ConflictResolveRequest,
    x_babytrack_device_id: str | None = Header(default=None, alias="X-BabyTrack-Device-Id"),
) -> ConflictResolveResult:
    event_id = payload.eventId.strip()
    strategy = payload.strategy.strip().lower()
    device_id = (x_babytrack_device_id or "").strip()

    if not event_id:
        raise HTTPException(status_code=400, detail="eventId is required")
    if strategy not in {"keep_local", "keep_remote", "merge"}:
        raise HTTPException(status_code=400, detail="Unsupported strategy")

    remote = EVENT_STORE.get_event_raw(event_id)
    if not remote:
        raise HTTPException(status_code=404, detail="Remote event not found")

    if strategy == "keep_remote":
        return ConflictResolveResult(ok=True, strategy=strategy, event=remote)

    if strategy == "keep_local":
        local = payload.localEvent
        if not isinstance(local, dict):
            raise HTTPException(status_code=400, detail="localEvent is required for keep_local")
        local["id"] = event_id
        accepted, reason = EVENT_STORE.upsert_event_with_status(
            local,
            country_code=payload.countryCode,
            app_version=payload.appVersion,
            source_device_id=device_id,
            force=True,
        )
        if not accepted:
            raise HTTPException(status_code=400, detail=reason)
        resolved = EVENT_STORE.get_event_raw(event_id)
        return ConflictResolveResult(ok=True, strategy=strategy, event=resolved)

    merged = payload.mergedEvent
    if not isinstance(merged, dict):
        raise HTTPException(status_code=400, detail="mergedEvent is required for merge")
    merged["id"] = event_id
    accepted, reason = EVENT_STORE.upsert_event_with_status(
        merged,
        country_code=payload.countryCode,
        app_version=payload.appVersion,
        source_device_id=device_id,
        force=True,
    )
    if not accepted:
        raise HTTPException(status_code=400, detail=reason)
    resolved = EVENT_STORE.get_event_raw(event_id)
    return ConflictResolveResult(ok=True, strategy=strategy, event=resolved)


@app.get("/v1/events/stats", dependencies=[Depends(_require_auth), Depends(_enforce_rate_limit)])
def event_stats() -> dict[str, Any]:
    return EVENT_STORE.stats()
