from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from backend.api.event_sync_store import EventSyncStore


class EventSyncStoreConflictTests(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        db = Path(self.tmp.name) / "sync.db"
        self.store = EventSyncStore(db)

    def tearDown(self) -> None:
        self.tmp.cleanup()

    def _base_event(self) -> dict:
        return {
            "id": "11111111-1111-1111-1111-111111111111",
            "childId": "child-a",
            "type": "sleep",
            "timestamp": "2026-03-05T08:00:00Z",
            "note": "initial",
            "payload": {"duration_min": "20"},
            "visibility": "family",
        }

    def test_conflict_detected_for_different_devices(self) -> None:
        event = self._base_event()

        accepted, reason = self.store.upsert_event_with_status(
            event,
            country_code="TR",
            app_version="1.0.0",
            source_device_id="device-a",
        )
        self.assertTrue(accepted)
        self.assertEqual(reason, "accepted")

        modified = dict(event)
        modified["note"] = "changed-on-device-b"

        accepted, reason = self.store.upsert_event_with_status(
            modified,
            country_code="TR",
            app_version="1.0.0",
            source_device_id="device-b",
        )
        self.assertFalse(accepted)
        self.assertEqual(reason, "conflict_remote_update")

    def test_force_override_resolves_conflict(self) -> None:
        event = self._base_event()
        self.store.upsert_event_with_status(
            event,
            country_code="TR",
            app_version="1.0.0",
            source_device_id="device-a",
        )

        modified = dict(event)
        modified["note"] = "resolved-keep-local"

        accepted, reason = self.store.upsert_event_with_status(
            modified,
            country_code="TR",
            app_version="1.0.0",
            source_device_id="device-b",
            force=True,
        )
        self.assertTrue(accepted)
        self.assertEqual(reason, "accepted")

        remote = self.store.get_event_raw(event["id"])
        self.assertIsNotNone(remote)
        self.assertEqual(remote["note"], "resolved-keep-local")


if __name__ == "__main__":
    unittest.main()
