#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import os
import re
import urllib.error
import urllib.request
from pathlib import Path
from typing import Dict

API_BASE = "https://generativelanguage.googleapis.com/v1beta/models"
MODEL = "gemini-2.5-flash"

LANG_PROMPTS = {
    "tr": "Turkish (Turkey)",
    "de": "German (Germany)",
    "es": "Spanish (Spain)",
    "fr": "French (France)",
    "it": "Italian (Italy)",
    "pt-BR": "Portuguese (Brazil)",
    "ar": "Arabic (Modern Standard Arabic)"
}


def request_json(url: str, payload: dict) -> dict:
    req = urllib.request.Request(url, data=json.dumps(payload).encode("utf-8"), method="POST")
    req.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(req, timeout=180) as resp:
            return json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        body = exc.read().decode("utf-8", errors="ignore")
        raise RuntimeError(f"HTTP {exc.code}: {body}") from exc


def extract_text(resp: dict) -> str:
    out = []
    for c in resp.get("candidates", []):
        for p in c.get("content", {}).get("parts", []):
            if "text" in p:
                out.append(p["text"])
    return "\n".join(out)


def strip_code_fence(text: str) -> str:
    text = text.strip()
    if text.startswith("```"):
        text = re.sub(r"^```[a-zA-Z0-9_-]*\n", "", text)
        text = re.sub(r"\n```$", "", text)
    return text.strip()


def translate_bundle(api_key: str, source: Dict[str, str], target_desc: str) -> Dict[str, str]:
    prompt = (
        "Translate the JSON string values to the target language. "
        "Keep keys exactly same. Preserve placeholders like %d and %@. "
        "Return only valid JSON object.\n\n"
        f"Target language: {target_desc}\n\n"
        f"Source JSON:\n{json.dumps(source, ensure_ascii=False, indent=2)}"
    )

    payload = {
        "contents": [{"role": "user", "parts": [{"text": prompt}]}],
        "generationConfig": {
            "temperature": 0.1,
            "responseMimeType": "application/json"
        }
    }

    url = f"{API_BASE}/{MODEL}:generateContent?key={api_key}"
    resp = request_json(url, payload)
    txt = strip_code_fence(extract_text(resp))
    parsed = json.loads(txt)

    out: Dict[str, str] = {}
    for key in source.keys():
        out[key] = str(parsed.get(key, source[key]))
    return out


def write_strings_file(path: Path, kv: Dict[str, str]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    lines = []
    for key in sorted(kv.keys()):
        val = kv[key].replace("\\", "\\\\").replace('"', '\\"')
        lines.append(f'"{key}" = "{val}";')
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate Localizable.strings using Gemini")
    parser.add_argument("--base", required=True)
    parser.add_argument("--out", required=True)
    parser.add_argument("--locales", nargs="+", default=["en", "tr", "de", "es", "fr", "it", "pt-BR", "ar"])
    parser.add_argument("--strings-file", default="Localizable.strings")
    args = parser.parse_args()

    api_key = os.environ.get("GEMINI_API_KEY", "").strip()
    if not api_key:
        raise SystemExit("GEMINI_API_KEY is required")

    base = json.loads(Path(args.base).read_text(encoding="utf-8"))
    out_root = Path(args.out)

    for locale in args.locales:
        if locale == "en":
            translated = base
        else:
            target_desc = LANG_PROMPTS.get(locale, locale)
            translated = translate_bundle(api_key, base, target_desc)

        strings_path = out_root / f"{locale}.lproj" / args.strings_file
        write_strings_file(strings_path, translated)
        print(f"Wrote {strings_path}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
