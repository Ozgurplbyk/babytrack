from __future__ import annotations

import json
from datetime import datetime, timezone
from pathlib import Path

from .base import BaseAdapter, SourceSnapshot


class LocalFixtureAdapter(BaseAdapter):
    def __init__(
        self,
        country_code: str,
        authority: str,
        fixture_path: Path,
        source_name: str = "",
        source_url: str = "",
        source_updated_at: str = "",
    ):
        self.country_code = country_code
        self.authority = authority
        self.fixture_path = fixture_path
        self.source_name = source_name
        self.source_url = source_url
        self.source_updated_at = source_updated_at

    def fetch_snapshot(self) -> SourceSnapshot:
        data = json.loads(self.fixture_path.read_text(encoding="utf-8"))
        version = data.get("version", "unknown")
        return SourceSnapshot(
            country_code=self.country_code,
            authority=self.authority,
            version=version,
            payload=data,
            source_name=self.source_name,
            source_url=self.source_url,
            source_updated_at=self.source_updated_at,
            retrieved_at=datetime.now(timezone.utc).isoformat(),
            fetch_mode="fixture_local",
            fallback_reason="local_fixture_adapter",
            live_record_count=0,
        )
