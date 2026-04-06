#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from datetime import datetime, timezone
from pathlib import Path


def load_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def row_for_item(item: dict) -> str:
    status = str(item.get("status", "pending")).strip()
    mark = "x" if status == "completed" else " "
    item_id = str(item.get("id", "")).strip()
    title = str(item.get("title", "")).strip()
    owner = str(item.get("owner", "")).strip()
    target = str(item.get("targetDate", "")).strip()
    evidence = ", ".join(str(v).strip() for v in item.get("evidenceLinks", []) if str(v).strip())
    required = "required" if bool(item.get("requiredForRelease", False)) else "optional"
    return (
        f"- [{mark}] `{item_id}` ({required}/{status}) - {title} "
        f"| owner={owner} | target={target} | evidence={evidence}"
    )


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate release operations action board from registry")
    parser.add_argument("--registry", default="config/release/release_ops_registry_v1.json")
    parser.add_argument("--out", default="docs/RELEASE_OPS_ACTION_BOARD_TR.md")
    args = parser.parse_args()

    payload = load_json(Path(args.registry))
    items = payload.get("items", [])

    pending_required = [
        i for i in items if bool(i.get("requiredForRelease", False)) and str(i.get("status", "")).strip() != "completed"
    ]

    by_area: dict[str, list[dict]] = {}
    for item in items:
        area = str(item.get("area", "other")).strip() or "other"
        by_area.setdefault(area, []).append(item)

    generated = datetime.now(timezone.utc).isoformat()
    lines = [
        "# Release Ops Action Board (TR)",
        "",
        f"- generatedAtUtc: `{generated}`",
        f"- totalItems: `{len(items)}`",
        f"- pendingRequiredItems: `{len(pending_required)}`",
        "",
    ]

    for area in sorted(by_area.keys()):
        lines.append(f"## {area}")
        lines.append("")
        area_rows = [row_for_item(i) for i in by_area[area]]
        lines.extend(area_rows or ["- [x] Bu alanda bekleyen madde yok"])
        lines.append("")

    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text("\n".join(lines), encoding="utf-8")

    print(f"release_ops_action_board={out}")
    print(f"pending_required_items={len(pending_required)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
