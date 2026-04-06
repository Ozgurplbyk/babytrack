from __future__ import annotations

import argparse
import json
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


def _load_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def _parse_datetime(value: str) -> datetime | None:
    raw = str(value or "").strip()
    if not raw:
        return None

    try:
        if len(raw) == 10:
            return datetime.fromisoformat(f"{raw}T00:00:00+00:00")
        normalized = raw.replace("Z", "+00:00")
        parsed = datetime.fromisoformat(normalized)
        if parsed.tzinfo is None:
            return parsed.replace(tzinfo=timezone.utc)
        return parsed.astimezone(timezone.utc)
    except ValueError:
        return None


def _load_registry_countries(registry_path: Path) -> list[dict[str, Any]]:
    payload = _load_json(registry_path)
    countries = payload.get("countries", [])
    if not isinstance(countries, list):
        raise ValueError("source registry countries must be a list")
    return [row for row in countries if isinstance(row, dict)]


def _find_package_file(out_dir: Path, country_code: str, state_row: dict[str, Any]) -> Path | None:
    published = str(state_row.get("publishedFile", "")).strip()
    if published:
        candidate = out_dir / published
        if candidate.exists():
            return candidate

    matches = sorted(out_dir.glob(f"{country_code}_*.json"))
    return matches[-1] if matches else None


def validate_health(
    *,
    registry_path: Path,
    state_path: Path,
    out_dir: Path,
    max_retrieved_age_hours: int,
    warn_source_age_days: int,
) -> tuple[list[str], list[str]]:
    registry = _load_registry_countries(registry_path)
    state = _load_json(state_path) if state_path.exists() else {}
    if not isinstance(state, dict):
        raise ValueError("source state must be a dictionary")

    now = datetime.now(timezone.utc)
    errors: list[str] = []
    warnings: list[str] = []

    for row in registry:
        country_code = str(row.get("countryCode", "")).upper().strip()
        adapter = str(row.get("adapter", "")).strip().lower()
        strict_live_required = bool(row.get("strictLiveRequired", True))
        if not country_code or adapter != "live_source":
            continue

        state_row = state.get(country_code)
        if not isinstance(state_row, dict):
            errors.append(f"[{country_code}] missing state row")
            continue

        fetch_mode = str(state_row.get("fetchMode", "")).strip().lower()
        fallback_reason = str(state_row.get("fallbackReason", "")).strip()
        if fetch_mode not in {"live", "live_metadata"}:
            reason = fallback_reason or "unknown_fallback"
            issue = f"[{country_code}] live ingest unhealthy: fetchMode={fetch_mode or 'missing'} fallbackReason={reason}"
            if strict_live_required:
                errors.append(issue)
            else:
                warnings.append(f"{issue} (warn-only override)")

        live_record_count = int(state_row.get("liveRecordCount", 0) or 0)
        if fetch_mode == "live" and live_record_count <= 0:
            errors.append(f"[{country_code}] live ingest returned no schedule rows")
        elif fetch_mode == "live_metadata" and live_record_count <= 0:
            warnings.append(f"[{country_code}] official source metadata was refreshed but schedule rows still use cached records")

        retrieved_at = _parse_datetime(str(state_row.get("retrievedAt", "")))
        if retrieved_at is None:
            errors.append(f"[{country_code}] missing retrievedAt")
        else:
            age_hours = (now - retrieved_at).total_seconds() / 3600
            if age_hours > max_retrieved_age_hours:
                errors.append(
                    f"[{country_code}] source state is stale: retrieved {age_hours:.1f}h ago (limit {max_retrieved_age_hours}h)"
                )

        source_updated_at = _parse_datetime(str(state_row.get("sourceUpdatedAt", "")))
        if source_updated_at is None:
            warnings.append(f"[{country_code}] sourceUpdatedAt missing or unparseable")
        else:
            age_days = (now - source_updated_at).total_seconds() / 86400
            if age_days > warn_source_age_days:
                warnings.append(
                    f"[{country_code}] official source metadata is {age_days:.0f} days old (warn threshold {warn_source_age_days})"
                )

        record_count = int(state_row.get("recordCount", 0) or 0)
        if record_count <= 0:
            package_file = _find_package_file(out_dir, country_code, state_row)
            if package_file is None:
                errors.append(f"[{country_code}] missing published package file")
            else:
                package_payload = _load_json(package_file)
                payload = package_payload.get("payload", {}) if isinstance(package_payload, dict) else {}
                records = payload.get("records", []) if isinstance(payload, dict) else []
                record_count = len(records) if isinstance(records, list) else 0
                if record_count <= 0:
                    errors.append(f"[{country_code}] published package has no records")

    return errors, warnings


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--registry", default="backend/vaccine_pipeline/source_registry.json")
    parser.add_argument("--state", default="backend/vaccine_pipeline/output/source_state.json")
    parser.add_argument("--out-dir", default="backend/vaccine_pipeline/output")
    parser.add_argument("--max-retrieved-age-hours", type=int, default=24)
    parser.add_argument("--warn-source-age-days", type=int, default=180)
    parser.add_argument("--strict-live", action="store_true")
    args = parser.parse_args()

    errors, warnings = validate_health(
        registry_path=Path(args.registry),
        state_path=Path(args.state),
        out_dir=Path(args.out_dir),
        max_retrieved_age_hours=max(int(args.max_retrieved_age_hours), 1),
        warn_source_age_days=max(int(args.warn_source_age_days), 1),
    )

    if warnings or errors:
        print("vaccine_pipeline_health=warn")
        for item in warnings:
            print(f"WARN {item}")
        for item in errors:
            print(f"ERROR {item}")
        if args.strict_live:
            print("strict_live=failed")
            return 1
        print(f"warnings={len(warnings)}")
        print(f"errors={len(errors)}")
        return 0

    print("vaccine_pipeline_health=ok")
    print(f"warnings={len(warnings)}")
    print(f"errors={len(errors)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
