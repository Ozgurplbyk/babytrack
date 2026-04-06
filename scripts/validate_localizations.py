#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

PLACEHOLDER_RE = re.compile(r"%(?:\d+\$)?[@df]")
STRINGS_LINE_RE = re.compile(r'^\s*"(?P<key>[^"]+)"\s*=\s*"(?P<value>(?:\\.|[^"])*)";\s*$')


def decode_value(raw: str) -> str:
    return bytes(raw, "utf-8").decode("unicode_escape")


def parse_strings(path: Path) -> dict[str, str]:
    out: dict[str, str] = {}
    for i, line in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
        line = line.strip()
        if not line or line.startswith("//") or line.startswith("/*"):
            continue
        m = STRINGS_LINE_RE.match(line)
        if not m:
            raise ValueError(f"{path}:{i}: invalid .strings line")
        out[m.group("key")] = decode_value(m.group("value"))
    return out


def extract_placeholders(text: str) -> list[str]:
    return PLACEHOLDER_RE.findall(text)


def validate_bundle(
    *,
    base_entries: dict[str, str],
    root: Path,
    file_name: str,
    locales: list[str],
    check_placeholders: bool,
    failures: list[str],
    label: str,
) -> None:
    base = base_entries
    base_keys = set(base_entries.keys())

    for locale in locales:
        strings_path = root / f"{locale}.lproj" / file_name
        if not strings_path.exists():
            failures.append(f"[{label}:{locale}] missing file: {strings_path}")
            continue

        try:
            bundle = parse_strings(strings_path)
        except Exception as exc:  # noqa: BLE001
            failures.append(f"[{label}:{locale}] parse error: {exc}")
            continue

        bundle_keys = set(bundle.keys())
        missing = sorted(base_keys - bundle_keys)
        extra = sorted(bundle_keys - base_keys)
        if missing:
            failures.append(
                f"[{label}:{locale}] missing keys: {', '.join(missing[:5])}{'...' if len(missing) > 5 else ''}"
            )
        if extra:
            failures.append(
                f"[{label}:{locale}] extra keys: {', '.join(extra[:5])}{'...' if len(extra) > 5 else ''}"
            )

        if check_placeholders:
            for key, base_text in base.items():
                if key not in bundle:
                    continue
                base_tokens = extract_placeholders(base_text)
                loc_tokens = extract_placeholders(bundle[key])
                if base_tokens != loc_tokens:
                    failures.append(
                        f"[{label}:{locale}] placeholder mismatch for '{key}': expected {base_tokens}, found {loc_tokens}"
                    )


def load_base_entries(base_arg: str, root: Path, file_name: str, label: str) -> dict[str, str]:
    candidate = Path(base_arg).expanduser() if base_arg else Path()
    if base_arg:
        if not candidate.exists():
            raise FileNotFoundError(f"{label} base file not found: {candidate}")
        if candidate.suffix.lower() == ".json":
            payload = json.loads(candidate.read_text(encoding="utf-8"))
            if not isinstance(payload, dict):
                raise ValueError(f"{label} base json must be an object")
            return {str(k): str(v) for k, v in payload.items()}
        return parse_strings(candidate)

    fallback = root / "en.lproj" / file_name
    if not fallback.exists():
        raise FileNotFoundError(f"{label} fallback base file not found: {fallback}")
    return parse_strings(fallback)


def load_locales_from_registry(path: Path) -> list[str]:
    payload = json.loads(path.read_text(encoding="utf-8"))
    entries = payload.get("entries")
    if not isinstance(entries, list):
        raise ValueError("locale registry entries must be a list")

    locales: list[str] = []
    seen: set[str] = set()
    for entry in entries:
        locale = str(entry.get("locale", "")).strip()
        if not locale or locale in seen:
            continue
        locales.append(locale)
        seen.add(locale)

    if not locales:
        raise ValueError("locale registry does not contain any locales")
    return locales


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate localization bundles for key and placeholder parity")
    parser.add_argument(
        "--localizable-app-base",
        default="",
        help="Optional base file for app Localizable.strings (json or .strings). Defaults to app en.lproj file.",
    )
    parser.add_argument(
        "--localizable-widget-base",
        default="",
        help="Optional base file for widget Localizable.strings (json or .strings). Defaults to widget en.lproj file.",
    )
    parser.add_argument(
        "--localizable-watch-base",
        default="",
        help="Optional base file for watch Localizable.strings (json or .strings). Defaults to watch en.lproj file.",
    )
    parser.add_argument(
        "--root",
        default="app/ios/BabyTrack/Resources/Localization",
        help="Localization directory containing *.lproj/Localizable.strings",
    )
    parser.add_argument(
        "--localizable-widget-root",
        default="app/ios/BabyTrackWidget",
    )
    parser.add_argument(
        "--localizable-watch-root",
        default="app/ios/BabyTrackWatch",
    )
    parser.add_argument(
        "--locales",
        nargs="+",
        default=None,
        help="Locale folders to validate",
    )
    parser.add_argument(
        "--locale-registry",
        default="config/localization/app_display_name_registry_v1.json",
        help="Locale registry used when --locales is omitted",
    )
    parser.add_argument(
        "--infoplist-app-base",
        default="config/localization/base_infoplist_app_en.json",
    )
    parser.add_argument(
        "--infoplist-app-root",
        default="app/ios/BabyTrack/Resources/Localization",
    )
    parser.add_argument(
        "--infoplist-widget-base",
        default="config/localization/base_infoplist_widget_en.json",
    )
    parser.add_argument(
        "--infoplist-widget-root",
        default="app/ios/BabyTrackWidget",
    )
    parser.add_argument(
        "--infoplist-watch-base",
        default="config/localization/base_infoplist_watch_en.json",
    )
    parser.add_argument(
        "--infoplist-watch-root",
        default="app/ios/BabyTrackWatch",
    )
    args = parser.parse_args()

    try:
        locales = args.locales or load_locales_from_registry(Path(args.locale_registry))
    except Exception as exc:  # noqa: BLE001
        print(f"Localization validation setup failed: {exc}")
        return 1

    failures: list[str] = []
    app_root = Path(args.root)
    widget_root = Path(args.localizable_widget_root)
    watch_root = Path(args.localizable_watch_root)

    try:
        app_localizable_base = load_base_entries(args.localizable_app_base, app_root, "Localizable.strings", "localizable")
        widget_localizable_base = load_base_entries(
            args.localizable_widget_base,
            widget_root,
            "Localizable.strings",
            "localizable_widget",
        )
        watch_localizable_base = load_base_entries(
            args.localizable_watch_base,
            watch_root,
            "Localizable.strings",
            "localizable_watch",
        )
        app_infoplist_base = load_base_entries(args.infoplist_app_base, Path(args.infoplist_app_root), "InfoPlist.strings", "infoplist_app")
        widget_infoplist_base = load_base_entries(
            args.infoplist_widget_base,
            Path(args.infoplist_widget_root),
            "InfoPlist.strings",
            "infoplist_widget",
        )
        watch_infoplist_base = load_base_entries(
            args.infoplist_watch_base,
            Path(args.infoplist_watch_root),
            "InfoPlist.strings",
            "infoplist_watch",
        )
    except Exception as exc:  # noqa: BLE001
        print(f"Localization validation setup failed: {exc}")
        return 1

    validate_bundle(
        base_entries=app_localizable_base,
        root=app_root,
        file_name="Localizable.strings",
        locales=locales,
        check_placeholders=True,
        failures=failures,
        label="localizable",
    )
    validate_bundle(
        base_entries=widget_localizable_base,
        root=widget_root,
        file_name="Localizable.strings",
        locales=locales,
        check_placeholders=True,
        failures=failures,
        label="localizable_widget",
    )
    validate_bundle(
        base_entries=watch_localizable_base,
        root=watch_root,
        file_name="Localizable.strings",
        locales=locales,
        check_placeholders=True,
        failures=failures,
        label="localizable_watch",
    )
    validate_bundle(
        base_entries=app_infoplist_base,
        root=Path(args.infoplist_app_root),
        file_name="InfoPlist.strings",
        locales=locales,
        check_placeholders=False,
        failures=failures,
        label="infoplist_app",
    )
    validate_bundle(
        base_entries=widget_infoplist_base,
        root=Path(args.infoplist_widget_root),
        file_name="InfoPlist.strings",
        locales=locales,
        check_placeholders=False,
        failures=failures,
        label="infoplist_widget",
    )
    validate_bundle(
        base_entries=watch_infoplist_base,
        root=Path(args.infoplist_watch_root),
        file_name="InfoPlist.strings",
        locales=locales,
        check_placeholders=False,
        failures=failures,
        label="infoplist_watch",
    )

    root = Path(args.root)
    tr_path = root / "tr.lproj" / "Localizable.strings"
    if tr_path.exists():
        tr_text = tr_path.read_text(encoding="utf-8")
        tr_chars = ["\u015f", "\u011f", "\u0131", "\u0130", "\u00f6", "\u00fc", "\u00e7"]
        for ch in tr_chars:
            if ch not in tr_text:
                failures.append(f"[tr] expected character not found: {ch}")
    else:
        failures.append("[tr] missing file: tr.lproj/Localizable.strings")

    if failures:
        print("Localization validation failed:")
        for item in failures:
            print(f"- {item}")
        return 1

    print(f"Localization validation passed for locales: {', '.join(locales)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
