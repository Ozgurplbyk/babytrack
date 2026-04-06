from __future__ import annotations

import json
import tempfile
import unittest
from datetime import datetime, timedelta, timezone
from pathlib import Path

from tools.content.validate_vaccine_pipeline_health import validate_health


class VaccinePipelineHealthTests(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.registry = self.root / "source_registry.json"
        self.state = self.root / "source_state.json"
        self.out_dir = self.root / "output"
        self.out_dir.mkdir()

        self.registry.write_text(
            json.dumps(
                {
                    "countries": [
                        {
                            "countryCode": "TR",
                            "adapter": "live_source",
                        },
                        {
                            "countryCode": "US",
                            "adapter": "local_fixture",
                        },
                    ]
                }
            ),
            encoding="utf-8",
        )

    def tearDown(self) -> None:
        self.tmp.cleanup()

    def test_accepts_healthy_live_source_state(self) -> None:
        now = datetime.now(timezone.utc)
        self.state.write_text(
            json.dumps(
                {
                    "TR": {
                        "fetchMode": "live",
                        "fallbackReason": "",
                        "liveRecordCount": 4,
                        "recordCount": 4,
                        "retrievedAt": (now - timedelta(hours=1)).isoformat(),
                        "sourceUpdatedAt": (now - timedelta(days=2)).date().isoformat(),
                        "publishedFile": "TR_2026.0404.json",
                    }
                }
            ),
            encoding="utf-8",
        )
        (self.out_dir / "TR_2026.0404.json").write_text(
            json.dumps({"payload": {"records": [{"id": 1}]}}),
            encoding="utf-8",
        )

        errors, warnings = validate_health(
            registry_path=self.registry,
            state_path=self.state,
            out_dir=self.out_dir,
            max_retrieved_age_hours=48,
            warn_source_age_days=180,
        )

        self.assertEqual(errors, [])
        self.assertEqual(warnings, [])

    def test_flags_live_source_fallback_as_error(self) -> None:
        now = datetime.now(timezone.utc)
        self.state.write_text(
            json.dumps(
                {
                    "TR": {
                        "fetchMode": "fixture_fallback",
                        "fallbackReason": "schedule_parse_failed",
                        "liveRecordCount": 0,
                        "recordCount": 3,
                        "retrievedAt": (now - timedelta(hours=1)).isoformat(),
                        "sourceUpdatedAt": (now - timedelta(days=2)).date().isoformat(),
                        "publishedFile": "TR_2026.0404.json",
                    }
                }
            ),
            encoding="utf-8",
        )
        (self.out_dir / "TR_2026.0404.json").write_text(
            json.dumps({"payload": {"records": [{"id": 1}]}}),
            encoding="utf-8",
        )

        errors, warnings = validate_health(
            registry_path=self.registry,
            state_path=self.state,
            out_dir=self.out_dir,
            max_retrieved_age_hours=48,
            warn_source_age_days=180,
        )

        self.assertTrue(any("fetchMode=fixture_fallback" in item for item in errors))
        self.assertEqual(warnings, [])

    def test_warns_when_source_metadata_is_old(self) -> None:
        now = datetime.now(timezone.utc)
        self.state.write_text(
            json.dumps(
                {
                    "TR": {
                        "fetchMode": "live",
                        "fallbackReason": "",
                        "liveRecordCount": 2,
                        "recordCount": 2,
                        "retrievedAt": (now - timedelta(hours=1)).isoformat(),
                        "sourceUpdatedAt": (now - timedelta(days=365)).date().isoformat(),
                        "publishedFile": "TR_2026.0404.json",
                    }
                }
            ),
            encoding="utf-8",
        )
        (self.out_dir / "TR_2026.0404.json").write_text(
            json.dumps({"payload": {"records": [{"id": 1}]}}),
            encoding="utf-8",
        )

        errors, warnings = validate_health(
            registry_path=self.registry,
            state_path=self.state,
            out_dir=self.out_dir,
            max_retrieved_age_hours=48,
            warn_source_age_days=180,
        )

        self.assertEqual(errors, [])
        self.assertTrue(any("official source metadata is" in item for item in warnings))

    def test_accepts_live_metadata_mode_with_warning(self) -> None:
        now = datetime.now(timezone.utc)
        self.state.write_text(
            json.dumps(
                {
                    "TR": {
                        "fetchMode": "live_metadata",
                        "fallbackReason": "schedule_parse_failed",
                        "liveRecordCount": 0,
                        "recordCount": 3,
                        "retrievedAt": (now - timedelta(hours=1)).isoformat(),
                        "sourceUpdatedAt": (now - timedelta(days=2)).date().isoformat(),
                        "publishedFile": "TR_2026.0404.json",
                    }
                }
            ),
            encoding="utf-8",
        )
        (self.out_dir / "TR_2026.0404.json").write_text(
            json.dumps({"payload": {"records": [{"id": 1}]}}),
            encoding="utf-8",
        )

        errors, warnings = validate_health(
            registry_path=self.registry,
            state_path=self.state,
            out_dir=self.out_dir,
            max_retrieved_age_hours=48,
            warn_source_age_days=180,
        )

        self.assertEqual(errors, [])
        self.assertTrue(any("official source metadata was refreshed" in item for item in warnings))

    def test_warn_only_override_downgrades_live_failure(self) -> None:
        now = datetime.now(timezone.utc)
        self.registry.write_text(
            json.dumps(
                {
                    "countries": [
                        {
                            "countryCode": "TR",
                            "adapter": "live_source",
                            "strictLiveRequired": False,
                        }
                    ]
                }
            ),
            encoding="utf-8",
        )
        self.state.write_text(
            json.dumps(
                {
                    "TR": {
                        "fetchMode": "fixture_fallback",
                        "fallbackReason": "source_blocked",
                        "liveRecordCount": 0,
                        "recordCount": 3,
                        "retrievedAt": (now - timedelta(hours=1)).isoformat(),
                        "sourceUpdatedAt": (now - timedelta(days=2)).date().isoformat(),
                        "publishedFile": "TR_2026.0404.json",
                    }
                }
            ),
            encoding="utf-8",
        )
        (self.out_dir / "TR_2026.0404.json").write_text(
            json.dumps({"payload": {"records": [{"id": 1}]}}),
            encoding="utf-8",
        )

        errors, warnings = validate_health(
            registry_path=self.registry,
            state_path=self.state,
            out_dir=self.out_dir,
            max_retrieved_age_hours=48,
            warn_source_age_days=180,
        )

        self.assertEqual(errors, [])
        self.assertTrue(any("warn-only override" in item for item in warnings))


if __name__ == "__main__":
    unittest.main()
