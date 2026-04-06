#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from datetime import datetime, timezone
from pathlib import Path


def load_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def md_escape(value: str) -> str:
    return value.replace("|", "\\|").replace("\n", " ").strip()


def keyword_csv(item: dict) -> str:
    raw = item.get("keywords", [])
    if not isinstance(raw, list):
        return ""
    values = [str(v).strip() for v in raw if str(v).strip()]
    return ",".join(values)


def row(item: dict) -> str:
    locale = md_escape(str(item.get("locale", "")))
    language = md_escape(str(item.get("languageCode", "")))
    country = md_escape(str(item.get("countryCode", "")))
    app_name = md_escape(str(item.get("appName", "")))
    subtitle = md_escape(str(item.get("subtitle", "")))
    keywords = md_escape(keyword_csv(item))
    return f"| `{locale}` | `{language}` | `{country}` | {app_name} | {subtitle} | {keywords} | ☐ |"


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate App Store localization upload sheet from metadata registry")
    parser.add_argument("--metadata", default="config/app_store/app_store_metadata_localized_v1.json")
    parser.add_argument("--out", default="docs/APP_STORE_LOCALIZATION_UPLOAD_SHEET_TR.md")
    args = parser.parse_args()

    payload = load_json(Path(args.metadata))
    entries = payload.get("entries", [])
    if not isinstance(entries, list):
        raise SystemExit("metadata entries must be an array")

    generated = datetime.now(timezone.utc).isoformat()
    default_locale = str(payload.get("defaultLocale", "")).strip()

    lines = [
        "# App Store Localization Upload Sheet (TR)",
        "",
        f"- generatedAtUtc: `{generated}`",
        f"- defaultLocale: `{default_locale}`",
        f"- localeCount: `{len(entries)}`",
        "",
        "## Kullanim",
        "",
        "1. Her locale satirindaki `appName`, `subtitle` ve `keywords` degerlerini App Store Connect'e gir.",
        "2. Locale girisi bittiginde son sutundaki checkbox'i isaretle.",
        "3. Tamamlanan bolgeler icin release ops kaydina kanit linki ekle.",
        "",
        "| Locale | Dil | Ulke | App Name | Subtitle | Keywords CSV | ASC Girildi |",
        "|---|---|---|---|---|---|---|",
    ]

    for item in entries:
        if isinstance(item, dict):
            lines.append(row(item))

    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text("\n".join(lines) + "\n", encoding="utf-8")

    print(f"app_store_localization_sheet={out}")
    print(f"locale_count={len(entries)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

