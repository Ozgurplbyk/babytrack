from __future__ import annotations

import argparse
import json
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from tools.content.validate_vaccine_pipeline_health import (
    _load_json,
    _load_registry_countries,
    validate_health,
)


def _format_datetime(raw: str) -> str:
    value = str(raw or "").strip()
    if not value:
        return "-"
    return value.replace("T", " ").replace("+00:00", " UTC")


def _alert_level(errors: list[str], warnings: list[str]) -> str:
    if errors:
        return "error"
    if warnings:
        return "warn"
    return "ok"


def _country_rows(registry: list[dict[str, Any]], state: dict[str, Any]) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for country in registry:
        country_code = str(country.get("countryCode", "")).upper().strip()
        if not country_code or str(country.get("adapter", "")).strip().lower() != "live_source":
            continue

        state_row = state.get(country_code) if isinstance(state, dict) else {}
        if not isinstance(state_row, dict):
            state_row = {}

        rows.append(
            {
                "country": country_code,
                "source_name": str(state_row.get("sourceName", "") or country.get("sourceName", "")).strip() or "-",
                "source_url": str(state_row.get("sourceUrl", "") or country.get("sourceUrl", "")).strip(),
                "fetch_mode": str(state_row.get("fetchMode", "")).strip() or "-",
                "fallback_reason": str(state_row.get("fallbackReason", "")).strip() or "-",
                "source_updated_at": _format_datetime(str(state_row.get("sourceUpdatedAt", ""))),
                "retrieved_at": _format_datetime(str(state_row.get("retrievedAt", ""))),
                "live_record_count": int(state_row.get("liveRecordCount", 0) or 0),
                "record_count": int(state_row.get("recordCount", 0) or 0),
                "changed": bool(state_row.get("changed", False)),
                "published_file": str(state_row.get("publishedFile", "")).strip() or "-",
            }
        )
    return rows


def _render_markdown(*, generated_at: datetime, errors: list[str], warnings: list[str], rows: list[dict[str, Any]]) -> str:
    level = _alert_level(errors, warnings)
    status_label = {
        "ok": "Healthy",
        "warn": "Warning",
        "error": "Error",
    }[level]

    changed_rows = [row for row in rows if row["changed"]]
    lines = [
        "# Vaccine Pipeline Health",
        "",
        f"- Status: **{status_label}**",
        f"- Generated at: `{generated_at.strftime('%Y-%m-%d %H:%M:%S UTC')}`",
        f"- Warnings: `{len(warnings)}`",
        f"- Errors: `{len(errors)}`",
        "",
    ]

    if changed_rows:
        lines.extend(
            [
                "## Changed Packages In This Run",
                "",
                *[
                    f"- `{row['country']}` -> `{row['published_file']}` via `{row['fetch_mode']}`"
                    for row in changed_rows
                ],
                "",
            ]
        )

    if warnings or errors:
        lines.append("## Active Alerts")
        lines.append("")
        for item in warnings:
            lines.append(f"- WARN {item}")
        for item in errors:
            lines.append(f"- ERROR {item}")
        lines.append("")

    lines.extend(
        [
            "## Country Source State",
            "",
            "| Country | Fetch Mode | Source Updated | Retrieved | Live Rows | Records | Fallback | Source |",
            "| --- | --- | --- | --- | ---: | ---: | --- | --- |",
        ]
    )

    for row in rows:
        source = row["source_name"]
        if row["source_url"]:
            source = f"[{source}]({row['source_url']})"
        lines.append(
            "| {country} | {fetch_mode} | {source_updated_at} | {retrieved_at} | {live_record_count} | {record_count} | {fallback_reason} | {source} |".format(
                **row,
                source=source,
            )
        )

    lines.append("")
    if level == "ok":
        lines.append("No active vaccine source alerts.")
    else:
        lines.append("Review the active alerts above before trusting a stale or degraded vaccine package.")
    lines.append("")

    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--registry", default="backend/vaccine_pipeline/source_registry.json")
    parser.add_argument("--state", default="backend/vaccine_pipeline/output/source_state.json")
    parser.add_argument("--out-dir", default="backend/vaccine_pipeline/output")
    parser.add_argument("--report-out", required=True)
    parser.add_argument("--metadata-out", required=True)
    parser.add_argument("--max-retrieved-age-hours", type=int, default=24)
    parser.add_argument("--warn-source-age-days", type=int, default=180)
    args = parser.parse_args()

    registry_path = Path(args.registry)
    state_path = Path(args.state)
    out_dir = Path(args.out_dir)
    report_out = Path(args.report_out)
    metadata_out = Path(args.metadata_out)

    errors, warnings = validate_health(
        registry_path=registry_path,
        state_path=state_path,
        out_dir=out_dir,
        max_retrieved_age_hours=max(int(args.max_retrieved_age_hours), 1),
        warn_source_age_days=max(int(args.warn_source_age_days), 1),
    )
    registry = _load_registry_countries(registry_path)
    state = _load_json(state_path) if state_path.exists() else {}
    generated_at = datetime.now(timezone.utc)
    rows = _country_rows(registry, state if isinstance(state, dict) else {})
    level = _alert_level(errors, warnings)

    report_out.write_text(
        _render_markdown(generated_at=generated_at, errors=errors, warnings=warnings, rows=rows),
        encoding="utf-8",
    )
    metadata_out.write_text(
        json.dumps(
            {
                "generatedAt": generated_at.isoformat(),
                "level": level,
                "hasAlerts": bool(errors or warnings),
                "warnings": len(warnings),
                "errors": len(errors),
                "issueTitle": "Vaccine Pipeline Alert",
                "label": "vaccine-pipeline-alert",
            },
            indent=2,
        ),
        encoding="utf-8",
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
