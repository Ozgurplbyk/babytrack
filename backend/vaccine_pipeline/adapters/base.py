from __future__ import annotations

from dataclasses import dataclass
from typing import Any


@dataclass
class SourceSnapshot:
    country_code: str
    authority: str
    version: str
    payload: dict[str, Any]
    source_name: str = ""
    source_url: str = ""
    source_updated_at: str = ""
    retrieved_at: str = ""


class BaseAdapter:
    country_code: str = ""
    authority: str = ""

    def fetch_snapshot(self) -> SourceSnapshot:
        raise NotImplementedError
