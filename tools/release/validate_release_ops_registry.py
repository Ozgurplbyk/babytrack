#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import re
from pathlib import Path

DATE_RE = re.compile(r"^\d{4}-\d{2}-\d{2}$")
VALID_STATUS = {"pending", "in_progress", "blocked", "completed"}


def load_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def has_real_evidence(links: list[str]) -> bool:
    for item in links:
        text = str(item).strip()
        if text and "replace-me.example.com" not in text:
            return True
    return False


def validate(payload: dict, *, require_complete: bool) -> list[str]:
    failures: list[str] = []
    version = str(payload.get("version", "")).strip()
    if not version:
        failures.append("version is required")

    items = payload.get("items", [])
    if not isinstance(items, list) or not items:
        failures.append("items must be a non-empty array")
        return failures

    seen_ids: set[str] = set()
    for idx, item in enumerate(items):
        prefix = f"items[{idx}]"
        if not isinstance(item, dict):
            failures.append(f"{prefix} must be an object")
            continue

        item_id = str(item.get("id", "")).strip()
        if not item_id:
            failures.append(f"{prefix}.id is required")
        elif item_id in seen_ids:
            failures.append(f"{prefix}.id duplicate: {item_id}")
        else:
            seen_ids.add(item_id)

        title = str(item.get("title", "")).strip()
        if not title:
            failures.append(f"{prefix}.title is required")

        area = str(item.get("area", "")).strip()
        if not area:
            failures.append(f"{prefix}.area is required")

        status = str(item.get("status", "")).strip()
        if status not in VALID_STATUS:
            failures.append(f"{prefix}.status invalid: {status}")

        owner = str(item.get("owner", "")).strip()
        if not owner:
            failures.append(f"{prefix}.owner is required")
        elif "tbd" in owner.casefold():
            failures.append(f"{prefix}.owner must not be TBD placeholder")

        target_date = str(item.get("targetDate", "")).strip()
        if not DATE_RE.match(target_date):
            failures.append(f"{prefix}.targetDate must be YYYY-MM-DD")

        raw_links = item.get("evidenceLinks", [])
        if not isinstance(raw_links, list):
            failures.append(f"{prefix}.evidenceLinks must be array")
            links: list[str] = []
        else:
            links = [str(v).strip() for v in raw_links if str(v).strip()]
            if not links:
                failures.append(f"{prefix}.evidenceLinks must include at least one link")
            if any("replace-me.example.com" in x for x in links):
                failures.append(f"{prefix}.evidenceLinks must not include placeholder links")

        required = bool(item.get("requiredForRelease", False))
        if require_complete and required:
            if status != "completed":
                failures.append(f"{prefix} required item must be completed")
            if not has_real_evidence(links):
                failures.append(f"{prefix} required item must include non-placeholder evidence link")

    return failures


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate release ops registry")
    parser.add_argument("--registry", default="config/release/release_ops_registry_v1.json")
    parser.add_argument("--require-complete", action="store_true", help="Fail if required release ops are not completed")
    args = parser.parse_args()

    payload = load_json(Path(args.registry))
    failures = validate(payload, require_complete=args.require_complete)

    if failures:
        print("release_ops_registry_validation=failed")
        for item in failures:
            print(f"- {item}")
        return 1

    print("release_ops_registry_validation=ok")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
