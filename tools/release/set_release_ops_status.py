#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from pathlib import Path

VALID_STATUS = {"pending", "in_progress", "blocked", "completed"}


def load_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def save_json(path: Path, payload: dict) -> None:
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def append_unique(items: list[str], value: str) -> list[str]:
    v = value.strip()
    if not v:
        return items
    if v not in items:
        items.append(v)
    return items


def main() -> int:
    parser = argparse.ArgumentParser(description="Update status/owner/date/evidence for release ops items")
    parser.add_argument("--registry", default="config/release/release_ops_registry_v1.json")
    parser.add_argument("--id", dest="item_ids", action="append", default=[], help="Item id to update (repeatable)")
    parser.add_argument("--all", action="store_true", help="Update all items")
    parser.add_argument("--area", action="append", default=[], help="Filter by area (repeatable)")
    parser.add_argument("--required-only", action="store_true", help="Update only requiredForRelease=true items")
    parser.add_argument("--status", required=True, choices=sorted(VALID_STATUS))
    parser.add_argument("--owner", default="")
    parser.add_argument("--target-date", default="")
    parser.add_argument("--evidence-link", action="append", default=[])
    parser.add_argument("--note", default="")
    args = parser.parse_args()

    ids = {x.strip() for x in args.item_ids if x.strip()}
    areas = {x.strip() for x in args.area if x.strip()}
    if not args.all and not ids and not areas and not args.required_only:
        parser.error("provide at least one selector: --id, --area, --required-only, or --all")

    path = Path(args.registry)
    payload = load_json(path)
    items = payload.get("items", [])

    updated = 0
    updated_ids: list[str] = []
    for item in items:
        item_id = str(item.get("id", "")).strip()
        area = str(item.get("area", "")).strip()
        is_required = bool(item.get("requiredForRelease", False))

        if args.all:
            selected = True
        else:
            selected = True
            if ids:
                selected = selected and (item_id in ids)
            if areas:
                selected = selected and (area in areas)
            if args.required_only:
                selected = selected and is_required

        if not selected:
            continue

        item["status"] = args.status
        if args.owner.strip():
            item["owner"] = args.owner.strip()
        if args.target_date.strip():
            item["targetDate"] = args.target_date.strip()
        if args.note.strip():
            item["note"] = args.note.strip()
        links = item.get("evidenceLinks", [])
        if not isinstance(links, list):
            links = []
        normalized_links = [str(x).strip() for x in links if str(x).strip()]
        for evidence in args.evidence_link:
            if evidence.strip():
                normalized_links = append_unique(normalized_links, evidence)
        item["evidenceLinks"] = normalized_links
        updated += 1
        updated_ids.append(item_id)

    payload["items"] = items
    save_json(path, payload)
    print(f"updated_items={updated}")
    if updated_ids:
        print("updated_item_ids=" + ",".join(updated_ids))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
