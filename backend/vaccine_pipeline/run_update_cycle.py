from __future__ import annotations

import json
from pathlib import Path
from typing import Any

from adapters.live_source_adapter import LiveSourceAdapter
from adapters.local_fixture_adapter import LocalFixtureAdapter
from canonicalize import canonicalize
from diffing import diff_packages
from publish import publish_package, sign_payload
from validator import validate_package

ROOT = Path(__file__).resolve().parent
FIXTURES = ROOT / "fixtures"
OUT = ROOT / "output"
REGISTRY_FILE = ROOT / "source_registry.json"
STATE_FILE = OUT / "source_state.json"


def load_latest(country: str) -> dict | None:
    matches = sorted(OUT.glob(f"{country}_*.json"))
    if not matches:
        return None
    latest = matches[-1]
    payload = json.loads(latest.read_text(encoding="utf-8"))
    return payload.get("payload")


def load_source_registry() -> list[dict[str, Any]]:
    if not REGISTRY_FILE.exists():
        raise FileNotFoundError(f"Missing registry: {REGISTRY_FILE}")

    payload = json.loads(REGISTRY_FILE.read_text(encoding="utf-8"))
    rows = payload.get("countries", [])
    if not isinstance(rows, list):
        raise ValueError("source_registry.json countries must be a list")

    normalized: list[dict[str, Any]] = []
    for row in rows:
        if not isinstance(row, dict):
            continue

        country_code = str(row.get("countryCode", "")).upper().strip()
        authority = str(row.get("authority", "")).strip()
        fixture_name = str(row.get("fixture", "")).strip()

        if not country_code or not authority or not fixture_name:
            continue

        fixture_path = FIXTURES / fixture_name
        if not fixture_path.exists():
            print(f"[{country_code}] fixture missing: {fixture_path}")
            continue

        normalized.append(
            {
                "countryCode": country_code,
                "authority": authority,
                "adapter": str(row.get("adapter", "local_fixture")).strip().lower(),
                "fixture": fixture_path,
                "sourceName": str(row.get("sourceName", "")).strip(),
                "sourceUrl": str(row.get("sourceUrl", "")).strip(),
                "sourceUpdatedAt": str(row.get("sourceUpdatedAt", "")).strip(),
                "scheduleFeedUrl": str(row.get("scheduleFeedUrl", "")).strip(),
                "scheduleFeedFormat": str(row.get("scheduleFeedFormat", "auto")).strip(),
                "scheduleFeedPath": str(row.get("scheduleFeedPath", "")).strip(),
                "scheduleFieldMap": row.get("scheduleFieldMap", {}) if isinstance(row.get("scheduleFieldMap"), dict) else {},
                "scheduleFeedFallbackUrls": row.get("scheduleFeedFallbackUrls", [])
                if isinstance(row.get("scheduleFeedFallbackUrls"), list)
                else [],
                "sourceFallbackUrls": row.get("sourceFallbackUrls", [])
                if isinstance(row.get("sourceFallbackUrls"), list)
                else [],
                "timeoutSec": int(row.get("timeoutSec", 12) or 12),
                "warnSourceAgeDays": int(row.get("warnSourceAgeDays", 180) or 180),
            }
        )

    return normalized


def load_state() -> dict[str, Any]:
    if not STATE_FILE.exists():
        return {}
    try:
        payload = json.loads(STATE_FILE.read_text(encoding="utf-8"))
        if isinstance(payload, dict):
            return payload
    except (TypeError, ValueError, json.JSONDecodeError):
        pass
    return {}


def save_state(state: dict[str, Any]) -> None:
    STATE_FILE.parent.mkdir(parents=True, exist_ok=True)
    STATE_FILE.write_text(json.dumps(state, ensure_ascii=False, indent=2), encoding="utf-8")


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    state = load_state()

    countries = load_source_registry()
    if not countries:
        print("No valid countries found in source_registry.json")
        return 1

    for row in countries:
        cc = row["countryCode"]
        authority = row["authority"]
        fixture = row["fixture"]

        if row["adapter"] == "live_source":
            adapter = LiveSourceAdapter(
                cc,
                authority,
                fixture,
                source_name=row["sourceName"],
                source_url=row["sourceUrl"],
                source_updated_at=row["sourceUpdatedAt"],
                schedule_feed_url=row["scheduleFeedUrl"],
                schedule_feed_format=row["scheduleFeedFormat"],
                schedule_feed_path=row["scheduleFeedPath"],
                schedule_field_map=row["scheduleFieldMap"],
                schedule_feed_fallback_urls=row.get("scheduleFeedFallbackUrls", []),
                source_fallback_urls=row.get("sourceFallbackUrls", []),
                timeout_sec=int(row.get("timeoutSec", 12) or 12),
            )
        else:
            adapter = LocalFixtureAdapter(
                cc,
                authority,
                fixture,
                source_name=row["sourceName"],
                source_url=row["sourceUrl"],
                source_updated_at=row["sourceUpdatedAt"],
            )
        snap = adapter.fetch_snapshot()

        canonical = canonicalize(
            snap.payload,
            snap.country_code,
            snap.authority,
            snap.version,
            source_name=snap.source_name,
            source_url=snap.source_url,
            source_updated_at=snap.source_updated_at,
            retrieved_at=snap.retrieved_at,
        )
        errors = validate_package(canonical)
        if errors:
            print(f"[{cc}] validation failed:")
            for err in errors:
                print(f" - {err}")
            continue

        signature_records: list[dict[str, Any]] = []
        for record in canonical.get("records", []):
            if isinstance(record, dict):
                normalized = {k: v for k, v in record.items() if k != "version"}
                signature_records.append(normalized)

        payload_signature = sign_payload(
            {
                "country": canonical.get("country"),
                "authority": canonical.get("authority"),
                "records": signature_records,
            }
        )
        previous = state.get(cc, {}) if isinstance(state.get(cc), dict) else {}
        previous_signature = str(previous.get("payloadSignature", "")).strip()

        if payload_signature == previous_signature:
            stable_version = str(previous.get("version", "")).strip() or str(canonical.get("version", "")).strip()
            state[cc] = {
                "version": stable_version,
                "payloadSignature": payload_signature,
                "sourceUpdatedAt": snap.source_updated_at,
                "retrievedAt": snap.retrieved_at,
                "sourceUrl": snap.source_url,
                "sourceName": snap.source_name,
                "publishedFile": previous.get("publishedFile", ""),
                "changed": False,
                "adapter": row["adapter"],
                "fetchMode": snap.fetch_mode,
                "fallbackReason": snap.fallback_reason,
                "liveRecordCount": snap.live_record_count,
                "attemptedUrls": snap.attempted_urls or [],
                "attemptErrors": snap.attempt_errors or {},
                "recordCount": len(canonical.get("records", [])),
            }
            print(f"[{cc}] no schedule change (signature unchanged)")
            continue

        old = load_latest(cc)
        diff = diff_packages(old, canonical)
        out_file = publish_package(OUT, cc, canonical, diff, approved_by="medical_editor_required")
        print(f"[{cc}] published -> {out_file.name} (added={len(diff['added'])}, changed={len(diff['changed'])}, removed={len(diff['removed'])})")
        state[cc] = {
            "version": canonical.get("version", ""),
            "payloadSignature": payload_signature,
            "sourceUpdatedAt": snap.source_updated_at,
            "retrievedAt": snap.retrieved_at,
            "sourceUrl": snap.source_url,
            "sourceName": snap.source_name,
            "publishedFile": out_file.name,
            "changed": True,
            "adapter": row["adapter"],
            "fetchMode": snap.fetch_mode,
            "fallbackReason": snap.fallback_reason,
            "liveRecordCount": snap.live_record_count,
            "attemptedUrls": snap.attempted_urls or [],
            "attemptErrors": snap.attempt_errors or {},
            "recordCount": len(canonical.get("records", [])),
        }

    save_state(state)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
