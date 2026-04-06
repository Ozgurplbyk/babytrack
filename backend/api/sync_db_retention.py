#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from pathlib import Path

try:
    from backend.api.event_sync_store import EventSyncStore
except ModuleNotFoundError:
    from event_sync_store import EventSyncStore


def main() -> int:
    parser = argparse.ArgumentParser(description="Apply retention policy to BabyTrack sync sqlite database")
    parser.add_argument(
        "--db",
        default="backend/api/data/sync_events.db",
        help="Path to sync sqlite database",
    )
    parser.add_argument(
        "--event-retention-days",
        type=int,
        default=365,
        help="How many days of sync_events rows to keep",
    )
    parser.add_argument(
        "--guard-retention-sec",
        type=int,
        default=86400,
        help="How many seconds of replay guard rows to keep",
    )
    args = parser.parse_args()

    store = EventSyncStore(
        Path(args.db),
        default_event_retention_days=max(args.event_retention_days, 1),
        retention_sweep_interval_sec=60,
    )
    report = store.apply_retention_policy(
        event_retention_days=max(args.event_retention_days, 1),
        guard_retention_sec=max(args.guard_retention_sec, 60),
        force=True,
    )
    print(json.dumps(report, ensure_ascii=False, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
