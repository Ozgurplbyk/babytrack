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


def apply_rights_template(
    payload: dict,
    owner: str,
    target_date: str,
    evidence_link: str,
    note: str,
    *,
    replace_tbd_owner: bool,
    drop_placeholder_evidence: bool,
) -> dict:
    tracks = payload.get("tracks", [])
    for t in tracks:
        current_owner = str(t.get("rightsHolderContact", "")).strip()
        owner_is_tbd = "tbd" in current_owner.casefold()
        if owner and (not current_owner or (replace_tbd_owner and owner_is_tbd)):
            t["rightsHolderContact"] = owner
        t["targetClearanceDate"] = target_date
        links = t.get("evidenceLinks", [])
        if not isinstance(links, list):
            links = []
        normalized_links = [str(x) for x in links]
        if drop_placeholder_evidence:
            normalized_links = remove_placeholder_links(normalized_links)
        t["evidenceLinks"] = append_unique(normalized_links, evidence_link)
        if note and not str(t.get("legalNote", "")).strip():
            t["legalNote"] = note
    payload["tracks"] = tracks
    return payload


def apply_medical_template(
    payload: dict,
    clinical_owner: str,
    legal_owner: str,
    target_date: str,
    evidence_link: str,
    *,
    replace_tbd_owner: bool,
    drop_placeholder_evidence: bool,
) -> dict:
    entries = payload.get("entries", [])
    for e in entries:
        current_clinical_owner = str(e.get("clinicalOwner", "")).strip()
        clinical_owner_is_tbd = "tbd" in current_clinical_owner.casefold()
        if clinical_owner and (not current_clinical_owner or (replace_tbd_owner and clinical_owner_is_tbd)):
            e["clinicalOwner"] = clinical_owner
        current_legal_owner = str(e.get("legalOwner", "")).strip()
        legal_owner_is_tbd = "tbd" in current_legal_owner.casefold()
        if legal_owner and (not current_legal_owner or (replace_tbd_owner and legal_owner_is_tbd)):
            e["legalOwner"] = legal_owner
        e["targetApprovalDate"] = target_date
        sources = e.get("evidenceSources", [])
        if not isinstance(sources, list):
            sources = []
        normalized_sources = [str(x) for x in sources]
        if drop_placeholder_evidence:
            normalized_sources = remove_placeholder_links(normalized_sources)
        e["evidenceSources"] = append_unique(normalized_sources, evidence_link)
    payload["entries"] = entries
    return payload


def main() -> int:
    parser = argparse.ArgumentParser(description="Apply bulk owner/date/evidence template to rights and medical registries")
    parser.add_argument("--rights", default="content/lullabies/lullaby_rights_registry_v1.json")
    parser.add_argument("--medical", default="content/medical/medical_content_registry_v1.json")
    parser.add_argument("--rights-owner", default="LEGAL_OWNER_TBD")
    parser.add_argument("--rights-target-date", default="2026-03-31")
    parser.add_argument("--rights-evidence-link", default="https://replace-me.example.com/rights-proof")
    parser.add_argument("--rights-note", default="Rights clearance pack pending legal review.")
    parser.add_argument("--medical-clinical-owner", default="CLINICAL_OWNER_TBD")
    parser.add_argument("--medical-legal-owner", default="LEGAL_OWNER_TBD")
    parser.add_argument("--medical-target-date", default="2026-03-31")
    parser.add_argument("--medical-evidence-link", default="https://replace-me.example.com/medical-proof")
    parser.add_argument(
        "--replace-tbd-owner",
        action="store_true",
        help="Replace owner values that contain TBD markers",
    )
    parser.add_argument(
        "--drop-placeholder-evidence",
        action="store_true",
        help="Remove placeholder evidence links that use replace-me.example.com",
    )
    args = parser.parse_args()

    rights_path = Path(args.rights)
    medical_path = Path(args.medical)

    rights_payload = apply_rights_template(
        load_json(rights_path),
        owner=args.rights_owner,
        target_date=args.rights_target_date,
        evidence_link=args.rights_evidence_link,
        note=args.rights_note,
        replace_tbd_owner=args.replace_tbd_owner,
        drop_placeholder_evidence=args.drop_placeholder_evidence,
    )
    medical_payload = apply_medical_template(
        load_json(medical_path),
        clinical_owner=args.medical_clinical_owner,
        legal_owner=args.medical_legal_owner,
        target_date=args.medical_target_date,
        evidence_link=args.medical_evidence_link,
        replace_tbd_owner=args.replace_tbd_owner,
        drop_placeholder_evidence=args.drop_placeholder_evidence,
    )

    save_json(rights_path, rights_payload)
    save_json(medical_path, medical_payload)

    print(f"updated_rights={rights_path}")
    print(f"updated_medical={medical_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
