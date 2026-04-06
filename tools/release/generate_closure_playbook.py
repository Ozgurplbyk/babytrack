#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from datetime import datetime, timezone
from pathlib import Path


def load_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def pending_release_ops(items: list[dict]) -> list[dict]:
    out: list[dict] = []
    for item in items:
        if not bool(item.get("requiredForRelease", False)):
            continue
        status = str(item.get("status", "")).strip()
        if status != "completed":
            out.append(item)
    return out


def pending_rights(tracks: list[dict]) -> dict[str, list[dict]]:
    by_country: dict[str, list[dict]] = {}
    for track in tracks:
        status = str(track.get("clearanceStatus", "")).strip()
        if status == "cleared":
            continue
        country = str(track.get("countryCode", "")).strip().upper() or "UNSPECIFIED"
        by_country.setdefault(country, []).append(track)
    return dict(sorted(by_country.items(), key=lambda kv: kv[0]))


def pending_medical(entries: list[dict]) -> list[dict]:
    out: list[dict] = []
    for entry in entries:
        editorial = str(entry.get("editorialStatus", "")).strip()
        legal = str(entry.get("legalStatus", "")).strip()
        if editorial == "approved" and legal == "approved":
            continue
        out.append(entry)
    return out


def render_release_ops_section(items: list[dict]) -> list[str]:
    lines: list[str] = ["## 1) Release Ops (Required)", ""]
    if not items:
        lines.extend(["- [x] Bekleyen required release ops maddesi yok.", ""])
        return lines

    for item in items:
        item_id = str(item.get("id", "")).strip()
        title = str(item.get("title", "")).strip()
        area = str(item.get("area", "")).strip()
        lines.append(f"- [ ] `{item_id}` ({area}) - {title}")
        lines.append("```bash")
        lines.append("python3 tools/release/set_release_ops_status.py \\")
        lines.append(f"  --id {item_id} \\")
        lines.append("  --status completed \\")
        lines.append('  --evidence-link "https://proof.example.com/release-ops"')
        lines.append("```")
        lines.append("")
    return lines


def render_rights_section(by_country: dict[str, list[dict]]) -> list[str]:
    lines: list[str] = ["## 2) Lullaby Rights", ""]
    if not by_country:
        lines.extend(["- [x] Bekleyen rights kaydi yok.", ""])
        return lines

    for country, tracks in by_country.items():
        lines.append(f"- [ ] `{country}` pending track: `{len(tracks)}`")
        lines.append("```bash")
        lines.append("python3 tools/audio/set_rights_clearance.py \\")
        lines.append(f"  --country {country} \\")
        lines.append("  --status in_review \\")
        lines.append('  --evidence-link "https://proof.example.com/rights-review"')
        lines.append("```")
        lines.append("")
        lines.append("Kapanis (clear):")
        lines.append("```bash")
        lines.append("python3 tools/audio/set_rights_clearance.py \\")
        lines.append(f"  --country {country} \\")
        lines.append("  --status cleared \\")
        lines.append('  --evidence-link "https://proof.example.com/rights-cleared"')
        lines.append("```")
        lines.append("")
    return lines


def render_medical_section(entries: list[dict]) -> list[str]:
    lines: list[str] = ["## 3) Medical Editorial + Legal", ""]
    if not entries:
        lines.extend(["- [x] Bekleyen medical onay maddesi yok.", ""])
        return lines

    for entry in entries:
        module = str(entry.get("module", "")).strip()
        editorial = str(entry.get("editorialStatus", "")).strip()
        legal = str(entry.get("legalStatus", "")).strip()
        lines.append(f"- [ ] `{module}` editorial={editorial}, legal={legal}")
        lines.append("```bash")
        lines.append("python3 tools/content/set_medical_review_status.py \\")
        lines.append(f"  --module {module} \\")
        lines.append("  --editorial-status approved \\")
        lines.append("  --legal-status approved \\")
        lines.append("  --set-reviewed-now \\")
        lines.append('  --evidence-source "https://proof.example.com/medical-review"')
        lines.append("```")
        lines.append("")
    return lines


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate closure playbook for pending release/compliance tasks")
    parser.add_argument("--release-ops", default="config/release/release_ops_registry_v1.json")
    parser.add_argument("--rights", default="content/lullabies/lullaby_rights_registry_v1.json")
    parser.add_argument("--medical", default="content/medical/medical_content_registry_v1.json")
    parser.add_argument("--out", default="docs/CLOSURE_PLAYBOOK_TR.md")
    args = parser.parse_args()

    release_ops_payload = load_json(Path(args.release_ops))
    rights_payload = load_json(Path(args.rights))
    medical_payload = load_json(Path(args.medical))

    pending_ops = pending_release_ops(release_ops_payload.get("items", []))
    pending_rights_by_country = pending_rights(rights_payload.get("tracks", []))
    pending_med = pending_medical(medical_payload.get("entries", []))

    generated = datetime.now(timezone.utc).isoformat()
    lines: list[str] = [
        "# Closure Playbook (TR)",
        "",
        f"- generatedAtUtc: `{generated}`",
        f"- pendingReleaseOpsRequired: `{len(pending_ops)}`",
        f"- pendingRightsTracks: `{sum(len(v) for v in pending_rights_by_country.values())}`",
        f"- pendingMedicalModules: `{len(pending_med)}`",
        "",
        "Bu dokuman pending maddeleri kapatmak icin komut sablonlari uretir.",
        "",
    ]

    lines.extend(render_release_ops_section(pending_ops))
    lines.extend(render_rights_section(pending_rights_by_country))
    lines.extend(render_medical_section(pending_med))

    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text("\n".join(lines) + "\n", encoding="utf-8")

    print(f"closure_playbook={out}")
    print(f"pending_release_ops_required={len(pending_ops)}")
    print(f"pending_rights_tracks={sum(len(v) for v in pending_rights_by_country.values())}")
    print(f"pending_medical_modules={len(pending_med)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

