#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from pathlib import Path


def load_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def catalog_keys(catalog: dict) -> set[tuple[str, str]]:
    out: set[tuple[str, str]] = set()
    for country in catalog.get("countries", []):
        cc = str(country.get("countryCode", "")).upper()
        for track in country.get("topLullabies", []):
            out.add((cc, str(track.get("id", ""))))
    return out


def registry_keys(registry: dict) -> set[tuple[str, str]]:
    out: set[tuple[str, str]] = set()
    for track in registry.get("tracks", []):
        out.add((str(track.get("countryCode", "")).upper(), str(track.get("trackId", ""))))
    return out


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate lullaby rights registry coverage and schema")
    parser.add_argument("--catalog", default="content/lullabies/lullaby_catalog.json")
    parser.add_argument("--registry", default="content/lullabies/lullaby_rights_registry_v1.json")
    parser.add_argument("--require-cleared", action="store_true")
    args = parser.parse_args()

    catalog = load_json(Path(args.catalog))
    registry = load_json(Path(args.registry))

    required_fields = {
        "trackId",
        "countryCode",
        "title",
        "audioAssetPath",
        "sourceType",
        "clearanceStatus",
        "clearanceStrategy",
        "compositionEvidence",
        "masterEvidence",
        "evidenceLinks",
        "targetClearanceDate",
        "rightsHolderContact",
        "legalNote",
    }

    failures: list[str] = []
    c_keys = catalog_keys(catalog)
    r_keys = registry_keys(registry)

    missing = sorted(c_keys - r_keys)
    extra = sorted(r_keys - c_keys)
    if missing:
        failures.append(f"Missing registry entries for {len(missing)} tracks")
    if extra:
        failures.append(f"Unexpected registry entries for {len(extra)} tracks")

    for t in registry.get("tracks", []):
        miss = sorted(required_fields - set(t.keys()))
        if miss:
            failures.append(f"{t.get('countryCode','?')}/{t.get('trackId','?')} missing fields: {', '.join(miss)}")
            continue

        if not isinstance(t["compositionEvidence"], list):
            failures.append(f"{t['countryCode']}/{t['trackId']} compositionEvidence must be list")
        if not isinstance(t["masterEvidence"], list):
            failures.append(f"{t['countryCode']}/{t['trackId']} masterEvidence must be list")
        if not isinstance(t["evidenceLinks"], list):
            failures.append(f"{t['countryCode']}/{t['trackId']} evidenceLinks must be list")
        if not str(t.get("targetClearanceDate", "")).strip():
            failures.append(f"{t['countryCode']}/{t['trackId']} targetClearanceDate is empty")

        if args.require_cleared and t["clearanceStatus"] != "cleared":
            failures.append(f"{t['countryCode']}/{t['trackId']} is not cleared")

    if failures:
        print("Rights registry validation failed:")
        for item in failures:
            print(f"- {item}")
        return 1

    print(f"Rights registry validation passed. Tracks: {len(registry.get('tracks', []))}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
