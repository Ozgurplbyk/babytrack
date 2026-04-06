#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from datetime import datetime, timezone
from pathlib import Path
from typing import Dict, List


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Sync localized app icon names (CFBundleDisplayName) and generate policy report."
    )
    parser.add_argument("--registry", required=True, help="Path to app display name registry JSON")
    parser.add_argument("--localization-root", required=True, help="Path to app localization root")
    parser.add_argument("--doc-out", required=True, help="Path to generated markdown policy report")
    parser.add_argument(
        "--strings-file",
        default="InfoPlist.strings",
        help="Localized plist strings filename (default: InfoPlist.strings)",
    )
    return parser.parse_args()


def read_json(path: Path) -> Dict:
    return json.loads(path.read_text(encoding="utf-8"))


def discover_locales(localization_root: Path) -> List[str]:
    locales: List[str] = []
    if not localization_root.exists():
        return locales
    for item in sorted(localization_root.iterdir(), key=lambda p: p.name.lower()):
        if item.is_dir() and item.name.endswith(".lproj"):
            locales.append(item.name.replace(".lproj", ""))
    return locales


def write_infoplist_strings(path: Path, display_name: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    safe = display_name.replace("\\", "\\\\").replace('"', '\\"')
    path.write_text(f"\"CFBundleDisplayName\" = \"{safe}\";\n", encoding="utf-8")


def pretty_path(path: Path) -> str:
    resolved = path.resolve()
    try:
        return resolved.relative_to(Path.cwd().resolve()).as_posix()
    except ValueError:
        return resolved.as_posix()


def generate_doc(
    doc_out: Path,
    rows: List[Dict[str, str]],
    registry_path: Path,
    localization_root: Path,
) -> None:
    generated_at = datetime.now(timezone.utc).replace(microsecond=0).isoformat()
    lines: List[str] = []
    lines.append("# App Icon Name Localization Policy (Auto)")
    lines.append("")
    lines.append(f"- generatedAtUtc: `{generated_at}`")
    lines.append(f"- sourceRegistry: `{pretty_path(registry_path)}`")
    lines.append(f"- localizationRoot: `{pretty_path(localization_root)}`")
    lines.append("")
    lines.append("## Kural")
    lines.append("")
    lines.append("1. Home Screen icon altindaki isim `CFBundleDisplayName` alanindan gelir.")
    lines.append("2. Her locale icin isim `app_display_name_registry_v1.json` uzerinden yonetilir.")
    lines.append("3. Yeni dil/bolge eklendiginde bu script yeniden calistirilir; hem `InfoPlist.strings` hem bu rapor guncellenir.")
    lines.append("4. `status=missing_registry` ise locale var ama ad registry'de tanimli degildir; yayin oncesi tamamlanmalidir.")
    lines.append("")
    lines.append("## Locale Tablosu")
    lines.append("")
    lines.append("| Locale | Region | Language | Icon Name | Chars | Status |")
    lines.append("|---|---|---|---|---:|---|")
    for row in rows:
        lines.append(
            f"| `{row['locale']}` | {row['region']} | {row['language_native']} | "
            f"`{row['app_display_name']}` | {row['chars']} | {row['status']} |"
        )
    lines.append("")
    lines.append("## Calistirma")
    lines.append("")
    lines.append("```bash")
    lines.append("python3 tools/localization/sync_app_display_names.py \\")
    lines.append("  --registry config/localization/app_display_name_registry_v1.json \\")
    lines.append("  --localization-root app/ios/BabyTrack/Resources/Localization \\")
    lines.append("  --doc-out docs/APP_NAME_LOCALIZATION_POLICY_AUTO_TR.md")
    lines.append("```")
    lines.append("")
    doc_out.parent.mkdir(parents=True, exist_ok=True)
    doc_out.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> int:
    args = parse_args()
    registry_path = Path(args.registry)
    localization_root = Path(args.localization_root)
    doc_out = Path(args.doc_out)

    registry = read_json(registry_path)
    default_display_name = str(registry.get("default_display_name", "BabyTrack"))
    entries = registry.get("entries", [])

    entry_map: Dict[str, Dict[str, str]] = {}
    for entry in entries:
        locale = str(entry.get("locale", "")).strip()
        if not locale:
            continue
        entry_map[locale] = {
            "region": str(entry.get("region", "-")),
            "language_native": str(entry.get("language_native", "-")),
            "app_display_name": str(entry.get("app_display_name", default_display_name)),
        }

    locales_in_fs = set(discover_locales(localization_root))
    locales_in_registry = set(entry_map.keys())
    all_locales = sorted(locales_in_fs | locales_in_registry, key=lambda s: s.lower())

    rows: List[Dict[str, str]] = []

    for locale in all_locales:
        entry = entry_map.get(locale)
        if entry:
            display_name = entry["app_display_name"]
            region = entry["region"]
            language_native = entry["language_native"]
            status = "configured"
        else:
            display_name = default_display_name
            region = "-"
            language_native = "-"
            status = "missing_registry"

        out_strings_path = localization_root / f"{locale}.lproj" / args.strings_file
        write_infoplist_strings(out_strings_path, display_name)

        rows.append(
            {
                "locale": locale,
                "region": region,
                "language_native": language_native,
                "app_display_name": display_name,
                "chars": str(len(display_name)),
                "status": status,
            }
        )

    generate_doc(
        doc_out=doc_out,
        rows=rows,
        registry_path=registry_path,
        localization_root=localization_root,
    )

    print(f"Synced {len(rows)} locales.")
    print(f"Updated: {doc_out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
