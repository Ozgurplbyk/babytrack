#!/usr/bin/env python3
from __future__ import annotations

import argparse
import sqlite3
from datetime import datetime, timezone
from pathlib import Path


def backup_db(source: Path, out_dir: Path) -> Path:
    out_dir.mkdir(parents=True, exist_ok=True)
    stamp = datetime.now(timezone.utc).strftime("%Y%m%d_%H%M%S")
    target = out_dir / f"sync_events_{stamp}.db"

    with sqlite3.connect(str(source)) as src:
        src.execute("PRAGMA wal_checkpoint(FULL);")
        with sqlite3.connect(str(target)) as dst:
            src.backup(dst)

    return target


def main() -> int:
    parser = argparse.ArgumentParser(description="Backup BabyTrack sync sqlite database")
    parser.add_argument(
        "--db",
        default="backend/api/data/sync_events.db",
        help="Path to source sqlite database",
    )
    parser.add_argument(
        "--out",
        default="backend/api/backups",
        help="Directory to write backup files",
    )
    args = parser.parse_args()

    src = Path(args.db)
    if not src.exists():
        raise SystemExit(f"source db not found: {src}")

    target = backup_db(src, Path(args.out))
    print(f"backup_created={target}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
