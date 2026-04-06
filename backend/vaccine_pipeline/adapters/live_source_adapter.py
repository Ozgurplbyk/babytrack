from __future__ import annotations

import email.utils
import json
import re
from datetime import datetime, timezone
from html import unescape
from pathlib import Path
from typing import Any
from urllib.request import Request, urlopen

from .base import BaseAdapter, SourceSnapshot


class LiveSourceAdapter(BaseAdapter):
    """
    Live ingest adapter with safe fallback.

    Strategy:
    1) Try optional machine-readable schedule feed.
    2) If feed is HTML, attempt lightweight table parsing.
    3) Always fetch official source page metadata (Last-Modified/date hints).
    4) Fall back to local fixture if live parsing fails.
    """

    _DATE_PATTERN = re.compile(r"(20\d{2})[-./](0[1-9]|1[0-2])[-./](0[1-9]|[12]\d|3[01])")
    _TR_RE = re.compile(r"<tr[^>]*>(.*?)</tr>", re.IGNORECASE | re.DOTALL)
    _CELL_RE = re.compile(r"<t[dh][^>]*>(.*?)</t[dh]>", re.IGNORECASE | re.DOTALL)
    _TAG_RE = re.compile(r"<[^>]+>")
    _AGE_RANGE_RE = re.compile(
        r"(?P<start>\d{1,3})\s*(?:-|to|–|—|a|hasta)\s*(?P<end>\d{1,3})\s*(?P<unit>day|days|week|weeks|month|months|year|years)",
        re.IGNORECASE,
    )
    _AGE_SINGLE_RE = re.compile(r"(?P<value>\d{1,3})\s*(?P<unit>day|days|week|weeks|month|months|year|years)", re.IGNORECASE)
    _DOSE_RE = re.compile(
        r"(?:dose|doses|doz|dosis|dosi|doza|#)\s*(\d{1,2})|\b(\d{1,2})(?:st|nd|rd|th)?\s*(?:dose|doses)\b",
        re.IGNORECASE,
    )

    _FIELD_CANDIDATES: dict[str, list[str]] = {
        "vaccine_code": ["vaccine_code", "vaccine", "code", "antigen", "name"],
        "dose_no": ["dose_no", "dose", "dose_number", "doseNo"],
        "min_age_days": ["min_age_days", "minAgeDays", "minimum_age_days"],
        "max_age_days": ["max_age_days", "maxAgeDays", "maximum_age_days"],
        "min_interval_days": ["min_interval_days", "minIntervalDays", "interval_days"],
        "effective_from": ["effective_from", "effectiveFrom", "from"],
        "effective_to": ["effective_to", "effectiveTo", "to"],
        "catch_up_rule": ["catch_up_rule", "catchUpRule", "catchup", "rule"],
        "age_text": ["age", "age_group", "window", "due", "timing"],
    }

    _UNIT_TO_DAYS = {
        "day": 1,
        "days": 1,
        "week": 7,
        "weeks": 7,
        "month": 30,
        "months": 30,
        "year": 365,
        "years": 365,
    }

    _AGE_TERM_REPLACEMENTS: list[tuple[str, str]] = [
        (r"\bgun\b|\bgün\b", "days"),
        (r"\bhafta\b", "weeks"),
        (r"\bay\b", "months"),
        (r"\byas\b|\byaş\b|\byil\b|\byıl\b", "years"),
        (r"\btag\b", "day"),
        (r"\btage\b", "days"),
        (r"\bwoche\b", "week"),
        (r"\bwochen\b", "weeks"),
        (r"\bmonat\b", "month"),
        (r"\bmonate\b", "months"),
        (r"\bjahr\b", "year"),
        (r"\bjahre\b", "years"),
        (r"\bjour\b", "day"),
        (r"\bjours\b", "days"),
        (r"\bsemaine\b", "week"),
        (r"\bsemaines\b", "weeks"),
        (r"\bmois\b", "month"),
        (r"\bannee\b|\bannée\b|\ban\b", "year"),
        (r"\bannees\b|\bannées\b|\bans\b", "years"),
        (r"\bdia\b|\bdía\b", "day"),
        (r"\bdias\b|\bdías\b", "days"),
        (r"\bsemana\b", "week"),
        (r"\bsemanas\b", "weeks"),
        (r"\bmes\b", "month"),
        (r"\bmeses\b", "months"),
        (r"\bano\b|\baño\b", "year"),
        (r"\banos\b|\baños\b", "years"),
        (r"\bgiorno\b", "day"),
        (r"\bgiorni\b", "days"),
        (r"\bsettimana\b", "week"),
        (r"\bsettimane\b", "weeks"),
        (r"\bmese\b", "month"),
        (r"\bmesi\b", "months"),
        (r"\banno\b", "year"),
        (r"\banni\b", "years"),
        (r"\bm[eê]s\b", "month"),
        (r"\bmeses\b", "months"),
        (r"\bano\b", "year"),
        (r"\banos\b", "years"),
        (r"\bbirth\b|\bdogum\b|\bdoğum\b|\bnaissance\b|\bnacimiento\b|\bnascita\b", "birth"),
    ]

    def __init__(
        self,
        country_code: str,
        authority: str,
        fixture_path: Path,
        *,
        source_name: str,
        source_url: str,
        source_updated_at: str,
        schedule_feed_url: str = "",
        schedule_feed_format: str = "auto",
        schedule_feed_path: str = "",
        schedule_field_map: dict[str, str] | None = None,
        timeout_sec: int = 12,
    ):
        self.country_code = country_code
        self.authority = authority
        self.fixture_path = fixture_path
        self.source_name = source_name
        self.source_url = source_url
        self.source_updated_at = source_updated_at
        self.schedule_feed_url = schedule_feed_url
        self.schedule_feed_format = (schedule_feed_format or "auto").strip().lower()
        self.schedule_feed_path = schedule_feed_path.strip()
        self.schedule_field_map = {
            str(k).strip(): str(v).strip()
            for k, v in (schedule_field_map or {}).items()
            if str(k).strip() and str(v).strip()
        }
        self.timeout_sec = max(int(timeout_sec), 3)

    def fetch_snapshot(self) -> SourceSnapshot:
        retrieved_at = datetime.now(timezone.utc).isoformat()
        fixture = self._load_fixture()

        live_schedule, live_version, live_source_updated = self._try_fetch_live_schedule()
        _, page_source_updated = self._fetch_page_metadata(self.source_url)

        selected_schedule = live_schedule if live_schedule else fixture.get("schedule", [])
        selected_version = self._resolve_version(
            live_version=live_version,
            fixture_version=str(fixture.get("version", "unknown")),
            source_updated=live_source_updated or page_source_updated or self.source_updated_at,
        )

        return SourceSnapshot(
            country_code=self.country_code,
            authority=self.authority,
            version=selected_version,
            payload={
                "version": selected_version,
                "schedule": selected_schedule,
            },
            source_name=self.source_name,
            source_url=self.source_url,
            source_updated_at=live_source_updated or page_source_updated or self.source_updated_at,
            retrieved_at=retrieved_at,
        )

    def _load_fixture(self) -> dict[str, Any]:
        return json.loads(self.fixture_path.read_text(encoding="utf-8"))

    def _try_fetch_live_schedule(self) -> tuple[list[dict[str, Any]], str, str]:
        target_url = self.schedule_feed_url.strip() or self.source_url.strip()
        if not target_url:
            return [], "", ""

        body, headers = self._fetch_url(target_url)
        if not body:
            return [], "", ""

        schedule: list[dict[str, Any]] = []
        version = ""
        source_updated = ""

        parsed = self._load_json(body)
        if parsed is not None and self.schedule_feed_format not in {"html", "table", "html_table"}:
            schedule, version, source_updated = self._parse_schedule_from_json(parsed)

        if not schedule:
            schedule = self._parse_schedule_from_html(body)

        if not self._looks_like_schedule(schedule):
            schedule = []

        if not source_updated:
            source_updated = self._source_updated_from_headers(headers)

        return schedule, version, source_updated

    def _parse_schedule_from_json(self, payload: Any) -> tuple[list[dict[str, Any]], str, str]:
        rows = self._extract_rows(payload)
        schedule = [row for row in (self._normalize_row(row) for row in rows) if row]

        version = self._lookup_scalar(payload, ["version", "releaseVersion", "release", "scheduleVersion"])
        source_updated = self._lookup_scalar(payload, ["sourceUpdatedAt", "updatedAt", "lastUpdated", "last_modified"])
        return schedule, version, source_updated

    def _extract_rows(self, payload: Any) -> list[dict[str, Any]]:
        if isinstance(payload, list):
            return [row for row in payload if isinstance(row, dict)]

        if not isinstance(payload, dict):
            return []

        if self.schedule_feed_path:
            from_path = self._dig(payload, self.schedule_feed_path)
            if isinstance(from_path, list):
                return [row for row in from_path if isinstance(row, dict)]

        for key in ("schedule", "records", "items", "vaccines"):
            candidate = payload.get(key)
            if isinstance(candidate, list):
                return [row for row in candidate if isinstance(row, dict)]

        data_node = payload.get("data")
        if isinstance(data_node, list):
            return [row for row in data_node if isinstance(row, dict)]
        if isinstance(data_node, dict):
            for key in ("schedule", "records", "items", "vaccines"):
                candidate = data_node.get(key)
                if isinstance(candidate, list):
                    return [row for row in candidate if isinstance(row, dict)]

        return []

    def _normalize_row(self, row: dict[str, Any]) -> dict[str, Any] | None:
        vaccine_code = self._extract_text_field(row, "vaccine_code")
        dose_no = self._extract_int_field(row, "dose_no")
        min_age_days = self._extract_int_field(row, "min_age_days")
        max_age_days = self._extract_int_field(row, "max_age_days")
        min_interval_days = self._extract_int_field(row, "min_interval_days")

        if min_age_days is None and max_age_days is None:
            age_text = self._extract_text_field(row, "age_text")
            parsed_min, parsed_max = self._parse_age_window(age_text)
            min_age_days = parsed_min
            max_age_days = parsed_max

        if dose_no is None:
            dose_no = self._extract_dose_number(self._extract_text_field(row, "dose_no"))

        if not vaccine_code or dose_no is None:
            return None

        effective_from = self._extract_text_field(row, "effective_from")
        effective_to = self._extract_text_field(row, "effective_to")
        catch_up_rule = self._extract_text_field(row, "catch_up_rule")

        return {
            "vaccine_code": vaccine_code,
            "dose_no": dose_no,
            "min_age_days": min_age_days,
            "max_age_days": max_age_days,
            "min_interval_days": min_interval_days or 0,
            "effective_from": effective_from or None,
            "effective_to": effective_to or None,
            "catch_up_rule": catch_up_rule,
        }

    def _extract_text_field(self, row: dict[str, Any], canonical_key: str) -> str:
        preferred = self.schedule_field_map.get(canonical_key, "")
        if preferred:
            value = row.get(preferred)
            if value is not None:
                return str(value).strip()

        for candidate in self._FIELD_CANDIDATES.get(canonical_key, []):
            value = row.get(candidate)
            if value is not None and str(value).strip():
                return str(value).strip()
        return ""

    def _extract_int_field(self, row: dict[str, Any], canonical_key: str) -> int | None:
        raw = self._extract_text_field(row, canonical_key)
        if not raw:
            value = row.get(self.schedule_field_map.get(canonical_key, ""))
            if isinstance(value, (int, float)):
                return int(value)
            return None
        return self._parse_int(raw)

    def _parse_schedule_from_html(self, body: str) -> list[dict[str, Any]]:
        rows: list[dict[str, Any]] = []

        for tr_html in self._TR_RE.findall(body):
            cells = [self._clean_html(cell) for cell in self._CELL_RE.findall(tr_html)]
            cells = [cell for cell in cells if cell]
            if len(cells) < 2:
                continue

            joined_lower = " ".join(cells).lower()
            if "vaccine" in joined_lower and "dose" in joined_lower:
                continue

            vaccine_text = cells[0]
            dose_no = self._extract_dose_number(" ".join(cells[1:3]))
            age_text = " ".join(cells)
            min_age_days, max_age_days = self._parse_age_window(age_text)

            if not vaccine_text or dose_no is None or min_age_days is None:
                continue

            rows.append(
                {
                    "vaccine_code": self._normalize_vaccine_code(vaccine_text),
                    "dose_no": dose_no,
                    "min_age_days": min_age_days,
                    "max_age_days": max_age_days,
                    "min_interval_days": 0,
                    "effective_from": None,
                    "effective_to": None,
                    "catch_up_rule": "",
                }
            )

        return rows

    def _fetch_page_metadata(self, url: str) -> tuple[str, str]:
        body, headers = self._fetch_url(url)
        source_updated = self._source_updated_from_headers(headers)
        if not source_updated and body:
            source_updated = self._source_updated_from_body(body)
        return body, source_updated

    def _fetch_url(self, url: str) -> tuple[str, dict[str, str]]:
        normalized = url.strip()
        if not normalized:
            return "", {}

        req = Request(
            normalized,
            headers={
                "User-Agent": "BabyTrackVaccineBot/1.0 (+https://babytrack.app)",
                "Accept": "text/html,application/json;q=0.9,*/*;q=0.8",
            },
        )

        try:
            with urlopen(req, timeout=self.timeout_sec) as response:
                raw = response.read()
                encoding = response.headers.get_content_charset() or "utf-8"
                body = raw.decode(encoding, errors="replace")
                headers = {k: str(v) for k, v in response.headers.items()}
                return body, headers
        except Exception:
            return "", {}

    def _source_updated_from_headers(self, headers: dict[str, str]) -> str:
        value = headers.get("Last-Modified") or headers.get("last-modified")
        if not value:
            return ""
        try:
            dt = email.utils.parsedate_to_datetime(value)
            if dt.tzinfo is None:
                dt = dt.replace(tzinfo=timezone.utc)
            return dt.astimezone(timezone.utc).date().isoformat()
        except (TypeError, ValueError):
            return ""

    def _source_updated_from_body(self, body: str) -> str:
        candidates = self._DATE_PATTERN.findall(body)
        if not candidates:
            return ""

        normalized: list[str] = []
        for year, month, day in candidates:
            normalized.append(f"{year}-{month}-{day}")

        return sorted(normalized)[-1]

    def _parse_age_window(self, raw: str) -> tuple[int | None, int | None]:
        text = self._normalize_age_text(raw)
        if not text:
            return None, None

        if "birth" in text:
            return 0, 30

        range_match = self._AGE_RANGE_RE.search(text)
        if range_match:
            start = int(range_match.group("start"))
            end = int(range_match.group("end"))
            unit = range_match.group("unit")
            factor = self._UNIT_TO_DAYS.get(unit, 1)
            return start * factor, end * factor

        singles = list(self._AGE_SINGLE_RE.finditer(text))
        if singles:
            values: list[int] = []
            for match in singles:
                value = int(match.group("value"))
                unit = match.group("unit")
                factor = self._UNIT_TO_DAYS.get(unit, 1)
                values.append(value * factor)
            if values:
                return min(values), max(values) if len(values) > 1 else None

        return None, None

    def _looks_like_schedule(self, schedule: list[dict[str, Any]]) -> bool:
        if not schedule:
            return False
        valid_rows = 0
        for row in schedule:
            vaccine_code = str(row.get("vaccine_code", "")).strip()
            dose_no = row.get("dose_no")
            min_age_days = row.get("min_age_days")
            if not vaccine_code:
                continue
            if not isinstance(dose_no, int):
                continue
            if not isinstance(min_age_days, int):
                continue
            valid_rows += 1
        return valid_rows > 0

    def _normalize_age_text(self, raw: str) -> str:
        text = raw.strip().lower()
        if not text:
            return ""
        for pattern, replacement in self._AGE_TERM_REPLACEMENTS:
            text = re.sub(pattern, replacement, text, flags=re.IGNORECASE)
        return re.sub(r"\s+", " ", text).strip()

    def _extract_dose_number(self, raw: str) -> int | None:
        text = raw.strip().lower()
        if not text:
            return None
        match = self._DOSE_RE.search(text)
        if match:
            first = match.group(1)
            second = match.group(2)
            token = first or second
            if token and token.isdigit():
                return int(token)

        tokens = re.findall(r"\d{1,2}", text)
        if tokens:
            return int(tokens[0])
        return None

    def _normalize_vaccine_code(self, raw: str) -> str:
        text = raw.strip()
        text = re.sub(r"\s+", "", text)
        text = re.sub(r"[^A-Za-z0-9+_-]", "", text)
        return text.upper()

    def _clean_html(self, value: str) -> str:
        no_tags = self._TAG_RE.sub(" ", value)
        decoded = unescape(no_tags)
        return re.sub(r"\s+", " ", decoded).strip()

    def _load_json(self, body: str) -> Any | None:
        try:
            return json.loads(body)
        except (TypeError, ValueError, json.JSONDecodeError):
            return None

    def _lookup_scalar(self, payload: Any, keys: list[str]) -> str:
        if not isinstance(payload, dict):
            return ""
        for key in keys:
            value = payload.get(key)
            if value is not None and str(value).strip():
                return str(value).strip()

        data_node = payload.get("data")
        if isinstance(data_node, dict):
            for key in keys:
                value = data_node.get(key)
                if value is not None and str(value).strip():
                    return str(value).strip()
        return ""

    def _parse_int(self, value: str) -> int | None:
        text = str(value).strip()
        if not text:
            return None
        match = re.search(r"\d+", text)
        if not match:
            return None
        try:
            return int(match.group(0))
        except (TypeError, ValueError):
            return None

    def _dig(self, payload: dict[str, Any], path: str) -> Any:
        current: Any = payload
        for token in (part.strip() for part in path.split(".")):
            if not token:
                continue
            if isinstance(current, dict):
                current = current.get(token)
            else:
                return None
        return current

    @staticmethod
    def _resolve_version(live_version: str, fixture_version: str, source_updated: str) -> str:
        if live_version:
            return live_version

        date_token = source_updated.strip()
        if date_token:
            parts = date_token.split("-")
            if len(parts) == 3 and all(p.isdigit() for p in parts):
                year, month, day = parts
                candidate = f"{year}.{month}{day}"
                if LiveSourceAdapter._version_rank(candidate) >= LiveSourceAdapter._version_rank(fixture_version):
                    return candidate

        return fixture_version or "unknown"

    @staticmethod
    def _version_rank(value: str) -> tuple[int, ...]:
        tokens = re.findall(r"\d+", value)
        if not tokens:
            return (0,)
        return tuple(int(token) for token in tokens[:4])
