#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from datetime import datetime, timezone
from pathlib import Path


def load_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def rights_summary(registry_path: Path) -> tuple[dict, list[str]]:
    payload = load_json(registry_path)
    tracks = payload.get("tracks", [])
    total = len(tracks)
    cleared = sum(1 for t in tracks if str(t.get("clearanceStatus", "")).strip() == "cleared")
    pending = total - cleared
    blockers = []
    if pending > 0:
        blockers.append(f"Lullaby rights clearance pending: {pending}/{total}")
    return {"total": total, "cleared": cleared, "pending": pending}, blockers


def medical_summary(registry_path: Path) -> tuple[dict, list[str]]:
    payload = load_json(registry_path)
    entries = payload.get("entries", [])
    total = len(entries)
    approved = 0
    for item in entries:
        editorial = str(item.get("editorialStatus", "")).strip()
        legal = str(item.get("legalStatus", "")).strip()
        if editorial == "approved" and legal == "approved":
            approved += 1
    pending = total - approved
    blockers = []
    if pending > 0:
        blockers.append(f"Medical editorial/legal approvals pending: {pending}/{total}")
    return {"total": total, "approved": approved, "pending": pending}, blockers


def paywall_summary(config_path: Path, ios_path: Path) -> tuple[dict, list[str]]:
    src = load_json(config_path)
    ios = load_json(ios_path)

    blockers: list[str] = []
    same_payload = src == ios
    if not same_payload:
        blockers.append("Paywall config mismatch between backend and iOS resource")

    plans = src.get("plans", [])
    missing_product_id = sum(
        1 for p in plans if not str(p.get("appStoreProductId", "")).strip()
    )
    if missing_product_id > 0:
        blockers.append(f"Paywall plans missing appStoreProductId: {missing_product_id}")

    return {
        "plans": len(plans),
        "sameBackendAndIOS": same_payload,
        "missingProductIds": missing_product_id,
    }, blockers


def localization_summary(root: Path, locales: list[str]) -> tuple[dict, list[str]]:
    missing: list[str] = []
    empty: list[str] = []
    for loc in locales:
        path = root / f"{loc}.lproj" / "Localizable.strings"
        if not path.exists():
            missing.append(loc)
            continue
        line_count = sum(1 for line in path.read_text(encoding="utf-8").splitlines() if line.strip())
        if line_count == 0:
            empty.append(loc)

    blockers: list[str] = []
    if missing:
        blockers.append(f"Missing localization files: {', '.join(missing)}")
    if empty:
        blockers.append(f"Empty localization files: {', '.join(empty)}")

    return {
        "expectedLocales": locales,
        "missingLocales": missing,
        "emptyLocales": empty,
    }, blockers


def app_store_metadata_summary(metadata_path: Path, required_langs: list[str]) -> tuple[dict, list[str]]:
    blockers: list[str] = []
    if not metadata_path.exists():
        blockers.append(f"App Store metadata file missing: {metadata_path}")
        return {
            "exists": False,
            "locales": 0,
            "requiredLanguages": required_langs,
            "missingLanguages": required_langs,
        }, blockers

    payload = load_json(metadata_path)
    entries = payload.get("entries", [])
    if not isinstance(entries, list) or not entries:
        blockers.append("App Store metadata entries missing")
        return {
            "exists": True,
            "locales": 0,
            "requiredLanguages": required_langs,
            "missingLanguages": required_langs,
        }, blockers

    languages_present: set[str] = set()
    for item in entries:
        if not isinstance(item, dict):
            continue
        language = str(item.get("languageCode", "")).strip().lower()
        if language:
            languages_present.add(language)

    missing_langs = [lang for lang in required_langs if lang not in languages_present]
    if missing_langs:
        blockers.append(f"App Store metadata missing languages: {', '.join(missing_langs)}")

    return {
        "exists": True,
        "locales": len(entries),
        "requiredLanguages": required_langs,
        "missingLanguages": missing_langs,
    }, blockers


def release_ops_summary(registry_path: Path) -> tuple[dict, list[str]]:
    payload = load_json(registry_path)
    items = payload.get("items", [])
    total = len(items)
    required = [i for i in items if bool(i.get("requiredForRelease", False))]
    required_total = len(required)
    required_completed = sum(1 for i in required if str(i.get("status", "")).strip() == "completed")
    required_pending = required_total - required_completed

    blockers: list[str] = []
    if required_pending > 0:
        blockers.append(f"Release ops required items pending: {required_pending}/{required_total}")

    return {
        "total": total,
        "required": required_total,
        "requiredCompleted": required_completed,
        "requiredPending": required_pending,
    }, blockers


def build_markdown(report: dict, blockers: list[str]) -> str:
    ts = datetime.now(timezone.utc).isoformat()
    status = "NOT READY" if blockers else "READY"
    lines = [
        "# Release Readiness Report",
        "",
        f"- generatedAtUtc: `{ts}`",
        f"- status: **{status}**",
        "",
        "## Summary",
        "",
        f"- rights: `{report['rights']['cleared']}/{report['rights']['total']}` cleared",
        f"- medical: `{report['medical']['approved']}/{report['medical']['total']}` fully approved",
        f"- paywall plans: `{report['paywall']['plans']}`",
        f"- missing localizations: `{len(report['localization']['missingLocales'])}`",
        f"- app store metadata locales: `{report['appStoreMetadata']['locales']}`",
        f"- release ops (required completed): `{report['releaseOps']['requiredCompleted']}/{report['releaseOps']['required']}`",
        "",
        "## Blockers",
        "",
    ]
    if blockers:
        for b in blockers:
            lines.append(f"- {b}")
    else:
        lines.append("- None")

    lines.append("")
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate BabyTrack release readiness report")
    parser.add_argument("--rights-registry", default="content/lullabies/lullaby_rights_registry_v1.json")
    parser.add_argument("--medical-registry", default="content/medical/medical_content_registry_v1.json")
    parser.add_argument("--paywall-config", default="config/paywall/paywall_offers.json")
    parser.add_argument("--ios-paywall-config", default="app/ios/BabyTrack/Resources/Config/paywall_offers.json")
    parser.add_argument("--localization-root", default="app/ios/BabyTrack/Resources/Localization")
    parser.add_argument("--app-store-metadata", default="config/app_store/app_store_metadata_localized_v1.json")
    parser.add_argument(
        "--required-language-codes",
        nargs="+",
        default=["en", "tr", "de", "es", "fr", "it", "pt", "ar"],
    )
    parser.add_argument("--release-ops-registry", default="config/release/release_ops_registry_v1.json")
    parser.add_argument("--locales", nargs="+", default=["en", "tr", "de", "es", "fr", "it", "pt-BR", "ar"])
    parser.add_argument("--out", default="docs/RELEASE_READINESS_REPORT.md")
    parser.add_argument("--strict", action="store_true", help="Exit non-zero if blockers exist")
    args = parser.parse_args()

    rights, rights_blockers = rights_summary(Path(args.rights_registry))
    medical, med_blockers = medical_summary(Path(args.medical_registry))
    paywall, paywall_blockers = paywall_summary(Path(args.paywall_config), Path(args.ios_paywall_config))
    localization, loc_blockers = localization_summary(Path(args.localization_root), args.locales)
    app_store_metadata, app_store_metadata_blockers = app_store_metadata_summary(
        Path(args.app_store_metadata),
        [x.strip().lower() for x in args.required_language_codes if x.strip()],
    )
    release_ops, release_ops_blockers = release_ops_summary(Path(args.release_ops_registry))

    blockers = (
        rights_blockers
        + med_blockers
        + paywall_blockers
        + loc_blockers
        + app_store_metadata_blockers
        + release_ops_blockers
    )
    report = {
        "rights": rights,
        "medical": medical,
        "paywall": paywall,
        "localization": localization,
        "appStoreMetadata": app_store_metadata,
        "releaseOps": release_ops,
    }

    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(build_markdown(report, blockers), encoding="utf-8")

    print(f"release_readiness_report={out}")
    print(f"blockers={len(blockers)}")
    if blockers:
        for b in blockers:
            print(f"- {b}")

    if args.strict and blockers:
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
