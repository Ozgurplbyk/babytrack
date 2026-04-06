#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from pathlib import Path

VALID_STATUS = {"pending", "in_review", "rework_required", "cleared"}


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
    parser = argparse.ArgumentParser(description="Bulk update lullaby rights registry entries")
    parser.add_argument("--registry", default="content/lullabies/lullaby_rights_registry_v1.json")
    parser.add_argument("--track-id", dest="track_ids", action="append", default=[], help="Track id to update (repeatable)")
    parser.add_argument("--country", dest="countries", action="append", default=[], help="Country code to update (repeatable)")
    parser.add_argument("--all", action="store_true", help="Update all tracks")
    parser.add_argument("--status", choices=sorted(VALID_STATUS), default="")
    parser.add_argument("--target-date", default="")
    parser.add_argument("--rights-holder-contact", default="")
    parser.add_argument("--legal-note", default="")
    parser.add_argument("--evidence-link", action="append", default=[])
    parser.add_argument("--composition-evidence", action="append", default=[])
    parser.add_argument("--master-evidence", action="append", default=[])
    args = parser.parse_args()

    track_ids = {x.strip() for x in args.track_ids if x.strip()}
    countries = {x.strip().upper() for x in args.countries if x.strip()}
    if not args.all and not track_ids and not countries:
        parser.error("use --all or at least one --track-id/--country selector")

    has_update = any(
        [
            args.status.strip(),
            args.target_date.strip(),
            args.rights_holder_contact.strip(),
            args.legal_note.strip(),
            any(x.strip() for x in args.evidence_link),
            any(x.strip() for x in args.composition_evidence),
            any(x.strip() for x in args.master_evidence),
        ]
    )
    if not has_update:
        parser.error("at least one update field is required")

    path = Path(args.registry)
    payload = load_json(path)
    tracks = payload.get("tracks", [])

    updated_ids: list[str] = []
    for track in tracks:
        track_id = str(track.get("trackId", "")).strip()
        country = str(track.get("countryCode", "")).strip().upper()
        selected = args.all or track_id in track_ids or country in countries
        if not selected:
            continue

        if args.status.strip():
            track["clearanceStatus"] = args.status.strip()
        if args.target_date.strip():
            track["targetClearanceDate"] = args.target_date.strip()
        if args.rights_holder_contact.strip():
            track["rightsHolderContact"] = args.rights_holder_contact.strip()
        if args.legal_note.strip():
            track["legalNote"] = args.legal_note.strip()

        evidence_links = track.get("evidenceLinks", [])
        if not isinstance(evidence_links, list):
            evidence_links = []
        for value in args.evidence_link:
            evidence_links = append_unique([str(x).strip() for x in evidence_links if str(x).strip()], value)
        track["evidenceLinks"] = evidence_links

        composition_evidence = track.get("compositionEvidence", [])
        if not isinstance(composition_evidence, list):
            composition_evidence = []
        for value in args.composition_evidence:
            composition_evidence = append_unique(
                [str(x).strip() for x in composition_evidence if str(x).strip()],
                value,
            )
        track["compositionEvidence"] = composition_evidence

        master_evidence = track.get("masterEvidence", [])
        if not isinstance(master_evidence, list):
            master_evidence = []
        for value in args.master_evidence:
            master_evidence = append_unique([str(x).strip() for x in master_evidence if str(x).strip()], value)
        track["masterEvidence"] = master_evidence

        updated_ids.append(track_id)

    payload["tracks"] = tracks
    save_json(path, payload)

    print(f"updated_tracks={len(updated_ids)}")
    if updated_ids:
        print("updated_track_ids=" + ",".join(updated_ids))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

