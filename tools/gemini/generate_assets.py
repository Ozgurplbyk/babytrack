#!/usr/bin/env python3
"""
Generate app assets from a JSON manifest using Gemini API.

Supports:
1) image generation (saves PNG/JPEG based on MIME)
2) storyboard text generation
3) lottie spec text generation

Usage:
  export GEMINI_API_KEY="..."
  python3 tools/gemini/generate_assets.py \
    --manifest assets/manifest/asset_manifest_v1.json \
    --style tools/gemini/style_system.json \
    --out generated/assets
"""

from __future__ import annotations

import argparse
import base64
import json
import os
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple


API_BASE = "https://generativelanguage.googleapis.com/v1beta/models"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Gemini asset generation pipeline")
    parser.add_argument("--manifest", required=True, help="Path to manifest JSON")
    parser.add_argument("--style", required=True, help="Path to style JSON")
    parser.add_argument("--out", required=True, help="Output directory")
    parser.add_argument(
        "--kinds",
        nargs="+",
        default=["image", "storyboard", "lottie_spec"],
        help="Asset kinds to generate",
    )
    parser.add_argument(
        "--delay-sec",
        type=float,
        default=0.5,
        help="Delay between requests to avoid rate spikes",
    )
    return parser.parse_args()


def read_json(path: Path) -> Dict[str, Any]:
    with path.open("r", encoding="utf-8") as f:
        return json.load(f)


def build_style_text(style: Dict[str, Any]) -> str:
    rules = style.get("visual_rules", {})
    palette = style.get("palette", {})
    disallow = rules.get("do_not_use", [])
    rule_lines: List[str] = []
    for key in sorted(rules.keys()):
        if key == "do_not_use":
            continue
        value = rules[key]
        if isinstance(value, (dict, list)):
            rendered = json.dumps(value, ensure_ascii=False)
        else:
            rendered = str(value)
        rule_lines.append(f"- {key}: {rendered}")

    style_rule_text = "\n".join(rule_lines)
    if style_rule_text:
        style_rule_text += "\n"

    return (
        "STYLE SYSTEM\n"
        f"- name: {style.get('style_name', 'default')}\n"
        f"{style_rule_text}"
        f"- palette: {json.dumps(palette, ensure_ascii=False)}\n"
        f"- do_not_use: {json.dumps(disallow, ensure_ascii=False)}\n"
    )


def request_json(url: str, payload: Dict[str, Any]) -> Dict[str, Any]:
    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(url, data=data, method="POST")
    req.add_header("Content-Type", "application/json")

    try:
        with urllib.request.urlopen(req, timeout=120) as resp:
            raw = resp.read().decode("utf-8")
            return json.loads(raw)
    except urllib.error.HTTPError as exc:
        body = exc.read().decode("utf-8", errors="ignore")
        raise RuntimeError(f"HTTP {exc.code}: {body}") from exc
    except urllib.error.URLError as exc:
        raise RuntimeError(f"Network error: {exc}") from exc


def mime_to_ext(mime_type: str) -> str:
    if "png" in mime_type:
        return ".png"
    if "jpeg" in mime_type or "jpg" in mime_type:
        return ".jpg"
    if "webp" in mime_type:
        return ".webp"
    return ".bin"


def extract_text(response: Dict[str, Any]) -> str:
    candidates = response.get("candidates", [])
    texts: List[str] = []
    for cand in candidates:
        content = cand.get("content", {})
        for part in content.get("parts", []):
            if "text" in part:
                texts.append(part["text"])
    return "\n\n".join(texts).strip()


def extract_first_inline_image(response: Dict[str, Any]) -> Optional[Tuple[bytes, str]]:
    candidates = response.get("candidates", [])
    for cand in candidates:
        content = cand.get("content", {})
        for part in content.get("parts", []):
            inline = part.get("inlineData") or part.get("inline_data")
            if inline and "data" in inline:
                mime_type = inline.get("mimeType") or inline.get("mime_type") or "image/png"
                try:
                    data = base64.b64decode(inline["data"])
                except Exception as exc:
                    raise RuntimeError(f"Failed to decode inline image: {exc}") from exc
                return data, mime_type
    return None


def build_prompt(asset_prompt: str, style_text: str, kind: str, aspect_ratio: str) -> str:
    base = (
        f"{style_text}\n"
        f"TASK TYPE: {kind}\n"
        f"ASPECT RATIO: {aspect_ratio}\n"
        "OUTPUT RULES:\n"
        "- Keep visual style strictly consistent with style system.\n"
        "- No text labels inside the image unless explicitly asked.\n"
        "- No logos or brand names.\n"
        "- Child-safe, culturally neutral, globally usable.\n"
        "\n"
        f"USER PROMPT:\n{asset_prompt}\n"
    )
    return base


def generate_image(
    api_key: str, model: str, prompt: str
) -> Tuple[Optional[bytes], Optional[str], str]:
    url = f"{API_BASE}/{model}:generateContent?key={api_key}"
    payload = {
        "contents": [{"role": "user", "parts": [{"text": prompt}]}],
        "generationConfig": {
            "responseModalities": ["TEXT", "IMAGE"]
        }
    }
    response = request_json(url, payload)
    img = extract_first_inline_image(response)
    text = extract_text(response)
    if img:
        return img[0], img[1], text
    return None, None, text


def generate_text(api_key: str, model: str, prompt: str) -> str:
    url = f"{API_BASE}/{model}:generateContent?key={api_key}"
    payload = {
        "contents": [{"role": "user", "parts": [{"text": prompt}]}]
    }
    response = request_json(url, payload)
    return extract_text(response)


def ensure_parent(path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)


def write_text(path: Path, text: str) -> None:
    ensure_parent(path)
    path.write_text(text.strip() + "\n", encoding="utf-8")


def main() -> int:
    args = parse_args()
    api_key = os.environ.get("GEMINI_API_KEY", "").strip()
    if not api_key:
        print("ERROR: GEMINI_API_KEY is not set.", file=sys.stderr)
        return 2

    manifest = read_json(Path(args.manifest))
    style = read_json(Path(args.style))
    out_dir = Path(args.out)
    out_dir.mkdir(parents=True, exist_ok=True)

    defaults = manifest.get("defaults", {})
    image_model_default = defaults.get("image_model", "gemini-2.5-flash-image")
    text_model_default = defaults.get("text_model", "gemini-2.5-flash")
    default_aspect = defaults.get("aspect_ratio", "1:1")

    style_text = build_style_text(style)
    allowed_kinds = set(args.kinds)
    assets = manifest.get("assets", [])

    total = 0
    success = 0
    failures: List[str] = []

    for asset in assets:
        asset_id = asset.get("id", "unknown_id")
        kind = asset.get("kind", "image")
        if kind not in allowed_kinds:
            continue

        total += 1
        print(f"[{total}] Generating {asset_id} ({kind}) ...")

        prompt_text = build_prompt(
            asset_prompt=asset.get("prompt", ""),
            style_text=style_text,
            kind=kind,
            aspect_ratio=asset.get("aspect_ratio", default_aspect),
        )

        output_rel = asset.get("output_path", asset_id)
        model = asset.get(
            "model",
            image_model_default if kind == "image" else text_model_default,
        )

        try:
            if kind == "image":
                img_bytes, mime_type, generated_text = generate_image(api_key, model, prompt_text)
                if img_bytes is None or mime_type is None:
                    # Save fallback text if image not returned by model.
                    fallback_path = out_dir / f"{output_rel}.txt"
                    write_text(
                        fallback_path,
                        "Model returned no image. Text response:\n\n" + (generated_text or "<empty>"),
                    )
                    raise RuntimeError("Model returned no inline image data.")

                ext = mime_to_ext(mime_type)
                image_path = out_dir / f"{output_rel}{ext}"
                ensure_parent(image_path)
                image_path.write_bytes(img_bytes)
            else:
                text = generate_text(api_key, model, prompt_text)
                suffix = ".md" if kind == "storyboard" else ".txt"
                text_path = out_dir / f"{output_rel}{suffix}"
                write_text(text_path, text or f"{kind} generation returned empty response.")

            success += 1
        except Exception as exc:
            failures.append(f"{asset_id}: {exc}")
            print(f"  -> FAILED: {exc}", file=sys.stderr)

        time.sleep(max(args.delay_sec, 0.0))

    print("\nGeneration summary")
    print(f"- total attempted: {total}")
    print(f"- success: {success}")
    print(f"- failed: {len(failures)}")

    if failures:
        fail_log = out_dir / "generation_failures.log"
        write_text(fail_log, "\n".join(failures))
        print(f"- failure log: {fail_log}")
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
