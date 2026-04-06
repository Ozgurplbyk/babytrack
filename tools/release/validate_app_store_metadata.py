#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import re
from pathlib import Path

DATELESS_PLACEHOLDER = "replace-me.example.com"
MAX_APP_NAME_LEN = 30
MAX_SUBTITLE_LEN = 30
MAX_KEYWORDS_LEN = 100
TURKISH_NATIVE_CHARS = set("çğıöşüÇĞİÖŞÜ")

DEFAULT_REQUIRED_LANGS = ["en", "tr", "de", "es", "fr", "it", "pt", "ar"]


def load_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def normalize_whitespace(value: str) -> str:
    return re.sub(r"\s+", " ", value.strip())


def has_turkish_native_chars(value: str) -> bool:
    return any(ch in TURKISH_NATIVE_CHARS for ch in value)


def validate_entry(entry: dict, idx: int, failures: list[str]) -> tuple[str, str] | None:
    prefix = f"entries[{idx}]"
    locale = normalize_whitespace(str(entry.get("locale", "")))
    language = normalize_whitespace(str(entry.get("languageCode", ""))).lower()
    app_name = normalize_whitespace(str(entry.get("appName", "")))
    subtitle = normalize_whitespace(str(entry.get("subtitle", "")))

    if not locale:
        failures.append(f"{prefix}.locale is required")
    if not language:
        failures.append(f"{prefix}.languageCode is required")
    if not app_name:
        failures.append(f"{prefix}.appName is required")
    if not subtitle:
        failures.append(f"{prefix}.subtitle is required")

    if app_name and len(app_name) > MAX_APP_NAME_LEN:
        failures.append(f"{prefix}.appName exceeds {MAX_APP_NAME_LEN} chars")
    if subtitle and len(subtitle) > MAX_SUBTITLE_LEN:
        failures.append(f"{prefix}.subtitle exceeds {MAX_SUBTITLE_LEN} chars")

    if app_name and "babytrack" not in app_name.casefold():
        failures.append(f"{prefix}.appName must include BabyTrack brand root")

    raw_keywords = entry.get("keywords", [])
    keywords: list[str] = []
    if not isinstance(raw_keywords, list):
        failures.append(f"{prefix}.keywords must be an array")
    else:
        seen: set[str] = set()
        for k_idx, raw in enumerate(raw_keywords):
            keyword = normalize_whitespace(str(raw))
            if not keyword:
                failures.append(f"{prefix}.keywords[{k_idx}] cannot be empty")
                continue
            if "," in keyword:
                failures.append(f"{prefix}.keywords[{k_idx}] must not contain comma")
                continue
            lowered = keyword.casefold()
            if lowered in seen:
                failures.append(f"{prefix}.keywords has duplicate value: {keyword}")
                continue
            seen.add(lowered)
            keywords.append(keyword)

    if not keywords:
        failures.append(f"{prefix}.keywords must include at least one keyword")
    else:
        keyword_csv = ",".join(keywords)
        if len(keyword_csv) > MAX_KEYWORDS_LEN:
            failures.append(f"{prefix}.keywords csv exceeds {MAX_KEYWORDS_LEN} chars")

        name_subtitle = f"{app_name} {subtitle}".casefold()
        for keyword in keywords:
            if keyword.casefold() in name_subtitle:
                failures.append(f"{prefix}.keyword repeats appName/subtitle: {keyword}")

    if language == "tr":
        turkish_text = " ".join([app_name, subtitle, *keywords])
        if not has_turkish_native_chars(turkish_text):
            failures.append(
                f"{prefix} Turkish metadata should include native characters (ç, ğ, ı, ö, ş, ü)"
            )

    if failures and (not locale or not language):
        return None
    return locale, language


def validate(payload: dict, *, required_languages: list[str]) -> list[str]:
    failures: list[str] = []
    version = normalize_whitespace(str(payload.get("version", "")))
    if not version:
        failures.append("version is required")

    default_locale = normalize_whitespace(str(payload.get("defaultLocale", "")))
    if not default_locale:
        failures.append("defaultLocale is required")

    entries = payload.get("entries", [])
    if not isinstance(entries, list) or not entries:
        failures.append("entries must be a non-empty array")
        return failures

    seen_locale: set[str] = set()
    languages_present: set[str] = set()
    for idx, item in enumerate(entries):
        if not isinstance(item, dict):
            failures.append(f"entries[{idx}] must be an object")
            continue

        result = validate_entry(item, idx, failures)
        if result is None:
            continue
        locale, language = result
        if locale in seen_locale:
            failures.append(f"duplicate locale entry: {locale}")
        else:
            seen_locale.add(locale)
        languages_present.add(language)

    if default_locale and default_locale not in seen_locale:
        failures.append(f"defaultLocale not found in entries: {default_locale}")

    for language in required_languages:
        if language not in languages_present:
            failures.append(f"missing required language coverage: {language}")

    return failures


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate localized App Store metadata registry")
    parser.add_argument("--metadata", default="config/app_store/app_store_metadata_localized_v1.json")
    parser.add_argument("--required-languages", nargs="+", default=DEFAULT_REQUIRED_LANGS)
    args = parser.parse_args()

    payload = load_json(Path(args.metadata))
    failures = validate(payload, required_languages=[x.strip().lower() for x in args.required_languages if x.strip()])

    if failures:
        print("app_store_metadata_validation=failed")
        for item in failures:
            print(f"- {item}")
        return 1

    print("app_store_metadata_validation=ok")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
