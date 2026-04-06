#!/usr/bin/env python3
from __future__ import annotations

import argparse
import base64
import json
import mimetypes
import os
import re
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request
from pathlib import Path
from typing import Any


API_BASE = "https://generativelanguage.googleapis.com/v1beta/models"
DEFAULT_AUDIT_MODEL = "gemini-2.5-flash"
HEX_RE = re.compile(r"#(?:[0-9a-fA-F]{3}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})")
CODE_FENCE_RE = re.compile(r"^```(?:json)?\s*|\s*```$", re.IGNORECASE)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Audit generated images for visible text and regenerate non-compliant assets."
    )
    parser.add_argument("--manifest", required=True, help="Asset manifest JSON path")
    parser.add_argument("--style", required=True, help="Gemini style JSON path")
    parser.add_argument("--assets-dir", required=True, help="Generated assets directory")
    parser.add_argument("--report-out", required=True, help="Audit report JSON output path")
    parser.add_argument("--post-report-out", default="", help="Optional post-regeneration audit report path")
    parser.add_argument("--audit-model", default=DEFAULT_AUDIT_MODEL)
    parser.add_argument("--delay-sec", type=float, default=0.35, help="Delay between audit requests")
    parser.add_argument("--regen-delay-sec", type=float, default=0.5, help="Delay for regeneration requests")
    parser.add_argument("--regenerate", action="store_true", help="Regenerate non-compliant assets")
    parser.add_argument("--sync-ios-dir", default="", help="Optional iOS generated assets directory for rsync")
    parser.add_argument(
        "--max-regen",
        type=int,
        default=0,
        help="Optional cap for regenerated asset count (0 means no cap)",
    )
    return parser.parse_args()


def read_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def request_json(url: str, payload: dict[str, Any], max_attempts: int = 5) -> dict[str, Any]:
    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(url, data=data, method="POST")
    req.add_header("Content-Type", "application/json")
    last_err: Exception | None = None
    for attempt in range(1, max_attempts + 1):
        try:
            with urllib.request.urlopen(req, timeout=120) as resp:
                return json.loads(resp.read().decode("utf-8"))
        except urllib.error.HTTPError as exc:
            body = exc.read().decode("utf-8", errors="ignore")
            recoverable = exc.code in {408, 429, 500, 502, 503, 504}
            if recoverable and attempt < max_attempts:
                time.sleep(min(2**attempt, 12))
                last_err = exc
                continue
            raise RuntimeError(f"HTTP {exc.code}: {body}") from exc
        except urllib.error.URLError as exc:
            if attempt < max_attempts:
                time.sleep(min(2**attempt, 12))
                last_err = exc
                continue
            raise RuntimeError(f"Network error: {exc}") from exc
    raise RuntimeError(f"Network error: {last_err}")


def extract_text_response(payload: dict[str, Any]) -> str:
    lines: list[str] = []
    for cand in payload.get("candidates", []):
        content = cand.get("content", {})
        for part in content.get("parts", []):
            text = part.get("text")
            if isinstance(text, str) and text.strip():
                lines.append(text.strip())
    return "\n".join(lines).strip()


def sanitize_json_text(text: str) -> str:
    trimmed = text.strip()
    trimmed = CODE_FENCE_RE.sub("", trimmed).strip()
    if trimmed.startswith("{") and trimmed.endswith("}"):
        return trimmed
    first = trimmed.find("{")
    last = trimmed.rfind("}")
    if first >= 0 and last > first:
        return trimmed[first : last + 1]
    return trimmed


def parse_audit_response(raw_text: str) -> dict[str, Any]:
    candidate = sanitize_json_text(raw_text)
    try:
        parsed = json.loads(candidate)
    except Exception:
        return {
            "contains_text": True,
            "contains_hex_code": False,
            "detected_strings": [raw_text[:120] if raw_text else "parse_failed"],
            "reason": "parse_failed",
        }

    detected_strings = parsed.get("detected_strings", [])
    if not isinstance(detected_strings, list):
        detected_strings = [str(detected_strings)]
    detected_strings = [str(s).strip() for s in detected_strings if str(s).strip()]

    contains_text = bool(parsed.get("contains_text", False))
    contains_hex = bool(parsed.get("contains_hex_code", False))
    reason = str(parsed.get("reason", "")).strip()
    return {
        "contains_text": contains_text,
        "contains_hex_code": contains_hex,
        "detected_strings": detected_strings,
        "reason": reason,
    }


def mime_for_path(path: Path) -> str:
    guessed, _ = mimetypes.guess_type(path.name)
    if guessed and guessed.startswith("image/"):
        return guessed
    return "image/png"


def audit_image(api_key: str, model: str, image_path: Path) -> dict[str, Any]:
    prompt = (
        "You are an OCR compliance checker.\n"
        "Task: Detect visible letters, words, numbers, hexadecimal color codes, "
        "UI labels, watermarks, or pseudo-text in this image.\n"
        "Return STRICT JSON only with this schema:\n"
        "{"
        "\"contains_text\": boolean, "
        "\"contains_hex_code\": boolean, "
        "\"detected_strings\": [string], "
        "\"reason\": string"
        "}\n"
        "If unsure, set contains_text=true."
    )
    raw = image_path.read_bytes()
    payload = {
        "contents": [
            {
                "role": "user",
                "parts": [
                    {"text": prompt},
                    {
                        "inlineData": {
                            "mimeType": mime_for_path(image_path),
                            "data": base64.b64encode(raw).decode("utf-8"),
                        }
                    },
                ],
            }
        ]
    }
    url = f"{API_BASE}/{model}:generateContent?key={api_key}"
    response = request_json(url, payload)
    raw_text = extract_text_response(response)
    result = parse_audit_response(raw_text)

    detected = result.get("detected_strings", [])
    has_hex_in_strings = any(HEX_RE.search(s) for s in detected)
    result["contains_hex_code"] = bool(result.get("contains_hex_code")) or has_hex_in_strings
    return result


def relative_without_suffix(path: Path, root: Path) -> str:
    rel = path.relative_to(root)
    return rel.with_suffix("").as_posix()


def image_files(root: Path) -> list[Path]:
    allowed = {".png", ".jpg", ".jpeg", ".webp"}
    files = [p for p in root.rglob("*") if p.is_file() and p.suffix.lower() in allowed]
    return sorted(files)


def write_report(path: Path, report: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def run_regeneration(
    manifest_path: Path,
    style_path: Path,
    assets_dir: Path,
    entries: list[dict[str, Any]],
    delay_sec: float,
) -> tuple[int, str]:
    temp_manifest = {
        "meta": {
            "version": "1.0.0",
            "generatedBy": "audit_and_regenerate_textless_assets.py",
        },
        "defaults": read_json(manifest_path).get("defaults", {}),
        "assets": entries,
    }
    with tempfile.TemporaryDirectory(prefix="babytrack_textless_regen_") as td:
        temp_path = Path(td) / "regen_manifest.json"
        temp_path.write_text(json.dumps(temp_manifest, ensure_ascii=False, indent=2), encoding="utf-8")
        cmd = [
            sys.executable,
            str(manifest_path.parents[2] / "tools" / "gemini" / "generate_assets.py"),
            "--manifest",
            str(temp_path),
            "--style",
            str(style_path),
            "--out",
            str(assets_dir),
            "--kinds",
            "image",
            "--delay-sec",
            str(max(delay_sec, 0.0)),
        ]
        proc = subprocess.run(cmd, capture_output=True, text=True)
        output = (proc.stdout or "") + ("\n" + proc.stderr if proc.stderr else "")
        return proc.returncode, output.strip()


def sync_to_ios(src: Path, dst: Path) -> tuple[int, str]:
    cmd = ["rsync", "-a", f"{src.as_posix()}/", f"{dst.as_posix()}/"]
    proc = subprocess.run(cmd, capture_output=True, text=True)
    output = (proc.stdout or "") + ("\n" + proc.stderr if proc.stderr else "")
    return proc.returncode, output.strip()


def main() -> int:
    args = parse_args()
    api_key = os.environ.get("GEMINI_API_KEY", "").strip()
    if not api_key:
        print("ERROR: GEMINI_API_KEY is not set", file=sys.stderr)
        return 2

    manifest_path = Path(args.manifest).resolve()
    style_path = Path(args.style).resolve()
    assets_dir = Path(args.assets_dir).resolve()
    report_out = Path(args.report_out).resolve()
    post_report_out = Path(args.post_report_out).resolve() if args.post_report_out else None

    manifest = read_json(manifest_path)
    manifest_assets = manifest.get("assets", [])
    by_output: dict[str, dict[str, Any]] = {}
    for item in manifest_assets:
        if item.get("kind") != "image":
            continue
        out = str(item.get("output_path", "")).strip()
        if out:
            by_output[out] = item

    all_images = image_files(assets_dir)
    findings: list[dict[str, Any]] = []

    total = len(all_images)
    for idx, image_path in enumerate(all_images, start=1):
        rel = relative_without_suffix(image_path, assets_dir)
        result = audit_image(api_key, args.audit_model, image_path)
        detected = result.get("detected_strings", [])
        non_compliant = bool(result.get("contains_text")) or bool(result.get("contains_hex_code"))
        findings.append(
            {
                "path": image_path.relative_to(assets_dir).as_posix(),
                "output_path": rel,
                "in_manifest": rel in by_output,
                "contains_text": bool(result.get("contains_text")),
                "contains_hex_code": bool(result.get("contains_hex_code")),
                "detected_strings": detected,
                "reason": result.get("reason", ""),
                "non_compliant": non_compliant,
            }
        )
        print(f"[audit {idx}/{total}] {rel} -> {'FAIL' if non_compliant else 'OK'}")
        time.sleep(max(args.delay_sec, 0.0))

    non_compliant = [f for f in findings if f["non_compliant"]]
    report = {
        "summary": {
            "total_images": total,
            "non_compliant_count": len(non_compliant),
            "compliant_count": total - len(non_compliant),
        },
        "non_compliant_output_paths": [f["output_path"] for f in non_compliant],
        "findings": findings,
    }
    write_report(report_out, report)
    print(f"audit_report={report_out}")

    if not args.regenerate or not non_compliant:
        return 0

    regen_candidates: list[dict[str, Any]] = []
    limit = args.max_regen if args.max_regen > 0 else None
    for item in non_compliant:
        output_path = item["output_path"]
        base = by_output.get(output_path)
        if not base:
            continue
        rewritten = dict(base)
        original_prompt = str(rewritten.get("prompt", "")).strip()
        strict_tail = (
            " STRICT CONSTRAINTS: The image must not contain any readable text, letters, "
            "numbers, pseudo-writing, watermarks, signatures, labels, or hex color codes. "
            "No alphanumeric characters are allowed anywhere in the composition."
        )
        rewritten["prompt"] = (original_prompt + " " + strict_tail).strip()
        regen_candidates.append(rewritten)
        if limit is not None and len(regen_candidates) >= limit:
            break

    if not regen_candidates:
        print("No manifest-mapped non-compliant assets to regenerate.")
        return 0

    code, regen_output = run_regeneration(
        manifest_path=manifest_path,
        style_path=style_path,
        assets_dir=assets_dir,
        entries=regen_candidates,
        delay_sec=args.regen_delay_sec,
    )
    print("regeneration_result=ok" if code == 0 else "regeneration_result=failed")
    if regen_output:
        print(regen_output)
    if code != 0:
        return code

    if args.sync_ios_dir:
        sync_code, sync_output = sync_to_ios(assets_dir, Path(args.sync_ios_dir).resolve())
        print("sync_ios_result=ok" if sync_code == 0 else "sync_ios_result=failed")
        if sync_output:
            print(sync_output)
        if sync_code != 0:
            return sync_code

    if post_report_out:
        refreshed_images = image_files(assets_dir)
        post_findings: list[dict[str, Any]] = []
        for idx, image_path in enumerate(refreshed_images, start=1):
            rel = relative_without_suffix(image_path, assets_dir)
            result = audit_image(api_key, args.audit_model, image_path)
            bad = bool(result.get("contains_text")) or bool(result.get("contains_hex_code"))
            post_findings.append(
                {
                    "path": image_path.relative_to(assets_dir).as_posix(),
                    "output_path": rel,
                    "contains_text": bool(result.get("contains_text")),
                    "contains_hex_code": bool(result.get("contains_hex_code")),
                    "detected_strings": result.get("detected_strings", []),
                    "reason": result.get("reason", ""),
                    "non_compliant": bad,
                }
            )
            print(f"[post-audit {idx}/{len(refreshed_images)}] {rel} -> {'FAIL' if bad else 'OK'}")
            time.sleep(max(args.delay_sec, 0.0))

        post_non_compliant = [f for f in post_findings if f["non_compliant"]]
        post_report = {
            "summary": {
                "total_images": len(refreshed_images),
                "non_compliant_count": len(post_non_compliant),
                "compliant_count": len(refreshed_images) - len(post_non_compliant),
            },
            "non_compliant_output_paths": [f["output_path"] for f in post_non_compliant],
            "findings": post_findings,
        }
        write_report(post_report_out, post_report)
        print(f"post_audit_report={post_report_out}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
