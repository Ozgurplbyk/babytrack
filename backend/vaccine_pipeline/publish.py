from __future__ import annotations

import hashlib
import json
from datetime import datetime, timezone
from pathlib import Path


def sign_payload(payload: dict) -> str:
    blob = json.dumps(payload, sort_keys=True, ensure_ascii=False).encode("utf-8")
    return hashlib.sha256(blob).hexdigest()


def publish_package(out_dir: Path, country_code: str, package: dict, diff: dict, approved_by: str) -> Path:
    out_dir.mkdir(parents=True, exist_ok=True)
    version = package.get("version", "unknown")

    published = {
        "meta": {
            "country": country_code,
            "version": version,
            "approved_by": approved_by,
            "published_at": datetime.now(timezone.utc).isoformat(),
        },
        "diff": diff,
        "payload": package,
    }
    published["meta"]["signature"] = sign_payload(published)

    out_file = out_dir / f"{country_code}_{version}.json"
    out_file.write_text(json.dumps(published, ensure_ascii=False, indent=2), encoding="utf-8")
    return out_file
