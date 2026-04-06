#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from pathlib import Path


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


def remove_placeholder_links(items: list[str]) -> list[str]:
    return [x for x in items if "replace-me.example.com" not in x]


def main() -> int:
    parser = argparse.ArgumentParser(description="Apply bulk owner/date/evidence template to release ops registry")
    parser.add_argument("--registry", default="config/release/release_ops_registry_v1.json")
    parser.add_argument("--owner", default="OPS_OWNER_TBD")
    parser.add_argument("--target-date", default="2026-03-31")
    parser.add_argument("--evidence-link", default="https://replace-me.example.com/release-ops-proof")
    parser.add_argument("--status", default="", help="Optional status override (pending/in_progress/blocked/completed)")
    parser.add_argument("--area", default="", help="Optional area filter (app_store/ios_release/backend_release/operations)")
    parser.add_argument(
        "--replace-tbd-owner",
        action="store_true",
        help="Replace owner values that contain TBD markers",
    )
    parser.add_argument(
        "--force-owner",
        action="store_true",
        help="Always overwrite owner with --owner",
    )
    parser.add_argument(
        "--drop-placeholder-evidence",
        action="store_true",
        help="Remove placeholder evidence links that use replace-me.example.com",
    )
    args = parser.parse_args()

    payload = load_json(Path(args.registry))
    items = payload.get("items", [])
    filtered_area = args.area.strip()
    status_override = args.status.strip()

    for item in items:
        area = str(item.get("area", "")).strip()
        if filtered_area and area != filtered_area:
            continue

        current_owner = str(item.get("owner", "")).strip()
        owner_is_tbd = "tbd" in current_owner.casefold()
        if args.owner and (
            args.force_owner
            or not current_owner
            or (args.replace_tbd_owner and owner_is_tbd)
        ):
            item["owner"] = args.owner
        item["targetDate"] = args.target_date

        links = item.get("evidenceLinks", [])
        if not isinstance(links, list):
            links = []
        normalized_links = [str(x) for x in links]
        if args.drop_placeholder_evidence:
            normalized_links = remove_placeholder_links(normalized_links)
        item["evidenceLinks"] = append_unique(normalized_links, args.evidence_link)

        if status_override:
            item["status"] = status_override

    payload["items"] = items
    save_json(Path(args.registry), payload)
    print(f"updated_release_ops_registry={args.registry}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
