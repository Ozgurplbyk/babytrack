#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from datetime import datetime, timezone
from pathlib import Path


def load_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def rights_actions(registry: dict) -> list[str]:
    rows: list[str] = []
    for t in registry.get("tracks", []):
        status = str(t.get("clearanceStatus", "")).strip()
        if status == "cleared":
            continue
        cc = str(t.get("countryCode", "")).upper()
        tid = str(t.get("trackId", ""))
        title = str(t.get("title", ""))
        strategy = str(t.get("clearanceStrategy", ""))
        rows.append(f"- [ ] Rights `{cc}/{tid}`: {title} ({strategy})")
    return rows


def medical_actions(registry: dict) -> list[str]:
    rows: list[str] = []
    for e in registry.get("entries", []):
        module = str(e.get("module", ""))
        editorial = str(e.get("editorialStatus", ""))
        legal = str(e.get("legalStatus", ""))
        if editorial == "approved" and legal == "approved":
            continue
        rows.append(f"- [ ] Medical `{module}`: editorial={editorial}, legal={legal}")
    return rows


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate compliance action board from rights and medical registries")
    parser.add_argument("--rights", default="content/lullabies/lullaby_rights_registry_v1.json")
    parser.add_argument("--medical", default="content/medical/medical_content_registry_v1.json")
    parser.add_argument("--out", default="docs/COMPLIANCE_ACTION_BOARD_TR.md")
    args = parser.parse_args()

    rights = load_json(Path(args.rights))
    medical = load_json(Path(args.medical))

    rights_rows = rights_actions(rights)
    med_rows = medical_actions(medical)

    generated = datetime.now(timezone.utc).isoformat()
    lines = [
        "# Compliance Action Board (TR)",
        "",
        f"- generatedAtUtc: `{generated}`",
        f"- pendingRightsItems: `{len(rights_rows)}`",
        f"- pendingMedicalItems: `{len(med_rows)}`",
        "",
        "## Rights (Lullaby)",
        "",
    ]
    lines.extend(rights_rows or ["- [x] Tum rights maddeleri tamamlandi"])
    lines.extend(["", "## Medical", ""])
    lines.extend(med_rows or ["- [x] Tum medical maddeleri tamamlandi"])
    lines.append("")

    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text("\n".join(lines), encoding="utf-8")

    print(f"action_board={out}")
    print(f"pending_rights={len(rights_rows)}")
    print(f"pending_medical={len(med_rows)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
