from __future__ import annotations

from typing import Any


def canonicalize(
    snapshot_payload: dict[str, Any],
    country_code: str,
    authority: str,
    version: str,
    source_name: str = "",
    source_url: str = "",
    source_updated_at: str = "",
    retrieved_at: str = "",
) -> dict[str, Any]:
    records = []
    for row in snapshot_payload.get("schedule", []):
        records.append(
            {
                "country": country_code,
                "authority": authority,
                "version": version,
                "effective_from": row.get("effective_from"),
                "effective_to": row.get("effective_to"),
                "vaccine_code": row.get("vaccine_code"),
                "dose_no": row.get("dose_no"),
                "min_age_days": row.get("min_age_days"),
                "max_age_days": row.get("max_age_days"),
                "min_interval_days": row.get("min_interval_days"),
                "catch_up_rule": row.get("catch_up_rule", "")
            }
        )

    return {
        "country": country_code,
        "authority": authority,
        "version": version,
        "source": {
            "name": source_name,
            "url": source_url,
            "source_updated_at": source_updated_at,
            "retrieved_at": retrieved_at,
        },
        "records": records,
    }
