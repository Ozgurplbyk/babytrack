#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import re
from pathlib import Path


def load_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def has_non_empty_records(package_path: Path) -> bool:
    payload = load_json(package_path)
    records = payload.get("payload", {}).get("records", [])
    return isinstance(records, list) and len(records) > 0


def latest_package_for(country_code: str, output_dir: Path) -> Path | None:
    matches = sorted(output_dir.glob(f"{country_code}_*.json"))
    return matches[-1] if matches else None


def load_swift_catalog(path: Path) -> tuple[dict[str, dict[str, object]], set[str]]:
    text = path.read_text(encoding="utf-8")
    language_pattern = re.compile(
        r'\.init\(code: "(?P<locale>[^"]+)", titleKey: "[^"]+", defaultCountryCode: "(?P<default>[^"]+)", '
        r'vaccineCountryCodes: \[(?P<codes>[^\]]*)\]\)'
    )
    country_pattern = re.compile(r'\.init\(code: "(?P<country>[A-Z]{2})", titleKey: "country_[^"]+"\)')

    languages: dict[str, dict[str, object]] = {}
    for match in language_pattern.finditer(text):
        codes = [
            item.strip().strip('"')
            for item in match.group("codes").split(",")
            if item.strip()
        ]
        languages[match.group("locale")] = {
            "default_country_code": match.group("default"),
            "vaccine_country_codes": codes,
        }

    countries = {match.group("country") for match in country_pattern.finditer(text)}
    return languages, countries


def validate(
    locale_registry: dict,
    vaccine_registry: dict,
    output_dir: Path,
    swift_catalog_path: Path | None = None,
) -> list[str]:
    failures: list[str] = []

    locale_entries = locale_registry.get("entries")
    if not isinstance(locale_entries, list):
        return ["locale registry entries must be a list"]

    vaccine_entries = vaccine_registry.get("countries")
    if not isinstance(vaccine_entries, list):
        return ["vaccine registry countries must be a list"]

    known_countries = {
        str(item.get("countryCode", "")).upper().strip()
        for item in vaccine_entries
        if str(item.get("countryCode", "")).strip()
    }

    swift_languages: dict[str, dict[str, object]] = {}
    swift_countries: set[str] = set()
    if swift_catalog_path is not None:
        swift_languages, swift_countries = load_swift_catalog(swift_catalog_path)

    seen_locales: set[str] = set()
    for entry in locale_entries:
        locale = str(entry.get("locale", "")).strip()
        if not locale:
            failures.append("locale is empty")
            continue
        if locale in seen_locales:
            failures.append(f"duplicate locale: {locale}")
        seen_locales.add(locale)

        default_country = str(entry.get("default_country_code", "")).upper().strip()
        if not default_country:
            failures.append(f"{locale} missing default_country_code")

        vaccine_country_codes = entry.get("vaccine_country_codes")
        if not isinstance(vaccine_country_codes, list) or not vaccine_country_codes:
            failures.append(f"{locale} missing vaccine_country_codes")
            continue

        normalized_codes: list[str] = []
        for raw_code in vaccine_country_codes:
            code = str(raw_code).upper().strip()
            if not code:
                failures.append(f"{locale} has empty vaccine country code")
                continue
            if code not in known_countries:
                failures.append(f"{locale} references unsupported vaccine country: {code}")
                continue

            package_path = latest_package_for(code, output_dir)
            if package_path is None:
                failures.append(f"{locale} references {code} but no vaccine package exists")
                continue
            if not has_non_empty_records(package_path):
                failures.append(f"{locale} references {code} but latest vaccine package has no records")
                continue

            normalized_codes.append(code)

        if default_country and normalized_codes and default_country not in normalized_codes:
            failures.append(f"{locale} default_country_code {default_country} is not included in vaccine_country_codes")

        if swift_catalog_path is not None:
            swift_entry = swift_languages.get(locale)
            if swift_entry is None:
                failures.append(f"{locale} missing from Swift locale catalog")
            else:
                if swift_entry.get("default_country_code") != default_country:
                    failures.append(
                        f"{locale} default_country_code mismatch between registry ({default_country}) and Swift catalog ({swift_entry.get('default_country_code')})"
                    )
                if swift_entry.get("vaccine_country_codes") != normalized_codes:
                    failures.append(
                        f"{locale} vaccine_country_codes mismatch between registry ({normalized_codes}) and Swift catalog ({swift_entry.get('vaccine_country_codes')})"
                    )

    if swift_catalog_path is not None:
        missing_in_registry = sorted(set(swift_languages.keys()) - seen_locales)
        if missing_in_registry:
            failures.append("Swift locale catalog has locales missing in registry: " + ", ".join(missing_in_registry))

        configured_countries = {
            str(country).upper().strip()
            for entry in locale_entries
            for country in entry.get("vaccine_country_codes", [])
            if str(country).strip()
        }
        missing_countries = sorted(configured_countries - swift_countries)
        if missing_countries:
            failures.append("Swift locale catalog is missing countries: " + ", ".join(missing_countries))

    return failures


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Validate that every supported app locale maps to at least one vaccine country with a live package."
    )
    parser.add_argument("--locale-registry", default="config/localization/app_display_name_registry_v1.json")
    parser.add_argument("--vaccine-registry", default="content/medical/vaccine_country_source_registry_v1.json")
    parser.add_argument("--output-dir", default="backend/vaccine_pipeline/output")
    parser.add_argument(
        "--swift-catalog",
        default="app/ios/BabyTrack/Core/Localization/LocaleCountryCatalog.swift",
        help="Optional Swift source of truth to cross-check app locale/country coverage",
    )
    args = parser.parse_args()

    locale_registry = load_json(Path(args.locale_registry))
    vaccine_registry = load_json(Path(args.vaccine_registry))
    swift_catalog_path = Path(args.swift_catalog)
    failures = validate(
        locale_registry,
        vaccine_registry,
        Path(args.output_dir),
        swift_catalog_path=swift_catalog_path if swift_catalog_path.exists() else None,
    )

    if failures:
        print("locale_vaccine_coverage_validation=failed")
        for item in failures:
            print(f"- {item}")
        return 1

    entries = locale_registry.get("entries", [])
    countries = sorted(
        {
            str(country).upper().strip()
            for entry in entries
            for country in entry.get("vaccine_country_codes", [])
            if str(country).strip()
        }
    )
    print("locale_vaccine_coverage_validation=ok")
    print(f"locales={len(entries)}")
    print(f"countries={','.join(countries)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
