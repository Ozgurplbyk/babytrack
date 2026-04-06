#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from datetime import datetime, timezone
from pathlib import Path

VALID_STATUS = {"pending", "approved", "rework_required"}


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


def now_utc_iso() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat()


def main() -> int:
    parser = argparse.ArgumentParser(description="Bulk update medical editorial/legal registry entries")
    parser.add_argument("--registry", default="content/medical/medical_content_registry_v1.json")
    parser.add_argument("--module", dest="modules", action="append", default=[], help="Module id to update (repeatable)")
    parser.add_argument("--all", action="store_true", help="Update all modules")
    parser.add_argument("--editorial-status", choices=sorted(VALID_STATUS), default="")
    parser.add_argument("--legal-status", choices=sorted(VALID_STATUS), default="")
    parser.add_argument("--target-date", default="")
    parser.add_argument("--last-reviewed-at", default="")
    parser.add_argument("--set-reviewed-now", action="store_true")
    parser.add_argument("--clinical-owner", default="")
    parser.add_argument("--legal-owner", default="")
    parser.add_argument("--evidence-source", action="append", default=[])
    args = parser.parse_args()

    modules = {x.strip() for x in args.modules if x.strip()}
    if not args.all and not modules:
        parser.error("use --all or at least one --module selector")
    if args.last_reviewed_at.strip() and args.set_reviewed_now:
        parser.error("use only one of --last-reviewed-at or --set-reviewed-now")

    review_value = args.last_reviewed_at.strip()
    if args.set_reviewed_now:
        review_value = now_utc_iso()

    has_update = any(
        [
            args.editorial_status.strip(),
            args.legal_status.strip(),
            args.target_date.strip(),
            review_value,
            args.clinical_owner.strip(),
            args.legal_owner.strip(),
            any(x.strip() for x in args.evidence_source),
        ]
    )
    if not has_update:
        parser.error("at least one update field is required")

    path = Path(args.registry)
    payload = load_json(path)
    entries = payload.get("entries", [])

    updated_modules: list[str] = []
    for item in entries:
        module = str(item.get("module", "")).strip()
        selected = args.all or module in modules
        if not selected:
            continue

        if args.editorial_status.strip():
            item["editorialStatus"] = args.editorial_status.strip()
        if args.legal_status.strip():
            item["legalStatus"] = args.legal_status.strip()
        if args.target_date.strip():
            item["targetApprovalDate"] = args.target_date.strip()
        if review_value:
            item["lastReviewedAt"] = review_value
        if args.clinical_owner.strip():
            item["clinicalOwner"] = args.clinical_owner.strip()
        if args.legal_owner.strip():
            item["legalOwner"] = args.legal_owner.strip()

        sources = item.get("evidenceSources", [])
        if not isinstance(sources, list):
            sources = []
        for value in args.evidence_source:
            sources = append_unique([str(x).strip() for x in sources if str(x).strip()], value)
        item["evidenceSources"] = sources

        updated_modules.append(module)

    payload["entries"] = entries
    save_json(path, payload)

    print(f"updated_modules={len(updated_modules)}")
    if updated_modules:
        print("updated_module_ids=" + ",".join(updated_modules))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

