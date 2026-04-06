from __future__ import annotations

import hashlib
import json
import time
from collections import deque
from threading import Lock
from typing import Any, Deque


def request_digest(payload: dict[str, Any]) -> str:
    canonical = json.dumps(payload, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
    return hashlib.sha256(canonical.encode("utf-8")).hexdigest()


class SlidingWindowRateLimiter:
    def __init__(self, limit: int, window_sec: int):
        self.limit = max(int(limit), 0)
        self.window_sec = max(int(window_sec), 1)
        self._lock = Lock()
        self._events: dict[str, Deque[float]] = {}

    def _trim(self, now: float, points: Deque[float]) -> None:
        while points and now - points[0] > self.window_sec:
            points.popleft()

    def allow(self, key: str) -> bool:
        if self.limit <= 0:
            return True

        now = time.monotonic()
        with self._lock:
            points = self._events.setdefault(key, deque())
            self._trim(now, points)
            if len(points) >= self.limit:
                return False
            points.append(now)

            # Best-effort memory cleanup for idle keys.
            if len(self._events) > 10000:
                stale = [k for k, v in self._events.items() if not v or now - v[-1] > self.window_sec * 2]
                for k in stale[:2000]:
                    self._events.pop(k, None)

        return True
