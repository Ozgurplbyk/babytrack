#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from pathlib import Path

ALLOWED_STATUS = {"pending", "approved", "rework_required"}


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate medical content registry structure")
    parser.add_argument("--registry", default="content/medical/medical_content_registry_v1.json")
    parser.add_argument("--require-approved", action="store_true")
    args = parser.parse_args()

    payload = json.loads(Path(args.registry).read_text(encoding="utf-8"))
    entries = payload.get("entries", [])
    failures: list[str] = []

    required = {
        "module",
        "contentScope",
        "clinicalOwner",
        "legalOwner",
        "evidenceSources",
        "editorialStatus",
        "legalStatus",
        "targetApprovalDate",
        "lastReviewedAt",
    }

    seen_modules: set[str] = set()
    for item in entries:
        module = str(item.get("module", "")).strip()
        if not module:
            failures.append("module is empty")
            continue
        if module in seen_modules:
            failures.append(f"duplicate module: {module}")
        seen_modules.add(module)

        missing = sorted(required - set(item.keys()))
        if missing:
            failures.append(f"{module} missing fields: {', '.join(missing)}")
            continue

        if not isinstance(item.get("evidenceSources"), list):
            failures.append(f"{module} evidenceSources must be list")
        if not str(item.get("targetApprovalDate", "")).strip():
            failures.append(f"{module} targetApprovalDate is empty")

        editorial = str(item.get("editorialStatus", "")).strip()
        legal = str(item.get("legalStatus", "")).strip()
        if editorial not in ALLOWED_STATUS:
            failures.append(f"{module} invalid editorialStatus: {editorial}")
        if legal not in ALLOWED_STATUS:
            failures.append(f"{module} invalid legalStatus: {legal}")
        if args.require_approved and (editorial != "approved" or legal != "approved"):
            failures.append(f"{module} is not fully approved (editorial={editorial}, legal={legal})")

    if failures:
        print("Medical registry validation failed:")
        for f in failures:
            print(f"- {f}")
        return 1

    print(f"Medical registry validation passed. Entries: {len(entries)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
