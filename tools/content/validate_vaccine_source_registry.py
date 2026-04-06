#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from pathlib import Path

SUPPORTED_COUNTRIES = {"TR", "US", "GB", "DE", "FR", "ES", "IT", "BR", "SA"}
ALLOWED_DELIVERY = {"pipeline_package", "manual_fallback"}
ALLOWED_STATUS = {"active", "pending_pipeline", "deprecated"}


def load_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def has_non_empty_records(package_path: Path) -> bool:
    payload = load_json(package_path)
    records = payload.get("payload", {}).get("records", [])
    return isinstance(records, list) and len(records) > 0


def validate(registry: dict, output_dir: Path) -> list[str]:
    failures: list[str] = []
    entries = registry.get("countries")
    if not isinstance(entries, list):
        return ["countries must be a list"]

    seen: set[str] = set()
    for item in entries:
        cc = str(item.get("countryCode", "")).upper().strip()
        if not cc:
            failures.append("countryCode is empty")
            continue
        if cc in seen:
            failures.append(f"duplicate countryCode: {cc}")
        seen.add(cc)

        if cc not in SUPPORTED_COUNTRIES:
            failures.append(f"{cc} is not in supported country list")

        authority = str(item.get("authority", "")).strip()
        if not authority:
            failures.append(f"{cc} authority is empty")

        source_url = str(item.get("officialSourceUrl", "")).strip()
        if not source_url.startswith("http://") and not source_url.startswith("https://"):
            failures.append(f"{cc} officialSourceUrl is invalid")

        delivery = str(item.get("deliveryMode", "")).strip()
        if delivery not in ALLOWED_DELIVERY:
            failures.append(f"{cc} invalid deliveryMode: {delivery}")

        status = str(item.get("status", "")).strip()
        if status not in ALLOWED_STATUS:
            failures.append(f"{cc} invalid status: {status}")

        if delivery == "pipeline_package":
            matches = sorted(output_dir.glob(f"{cc}_*.json"))
            if not matches:
                failures.append(f"{cc} marked pipeline_package but no package exists in output dir")
            elif not has_non_empty_records(matches[-1]):
                failures.append(f"{cc} latest package has no records")

    missing = sorted(SUPPORTED_COUNTRIES - seen)
    if missing:
        failures.append("missing countries: " + ", ".join(missing))

    return failures


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate vaccine source registry and pipeline linkage")
    parser.add_argument("--registry", default="content/medical/vaccine_country_source_registry_v1.json")
    parser.add_argument("--output-dir", default="backend/vaccine_pipeline/output")
    args = parser.parse_args()

    registry = load_json(Path(args.registry))
    failures = validate(registry, Path(args.output_dir))
    if failures:
        print("vaccine_source_registry_validation=failed")
        for item in failures:
            print(f"- {item}")
        return 1

    print("vaccine_source_registry_validation=ok")
    print(f"countries={len(registry.get('countries', []))}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
