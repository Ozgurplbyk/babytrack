#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from pathlib import Path


def load_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate paywall plans and App Store product mapping")
    parser.add_argument("--paywall", default="config/paywall/paywall_offers.json")
    parser.add_argument("--ios-paywall", default="app/ios/BabyTrack/Resources/Config/paywall_offers.json")
    args = parser.parse_args()

    source = load_json(Path(args.paywall))
    ios = load_json(Path(args.ios_paywall))

    failures: list[str] = []

    for name, payload in [("config", source), ("ios", ios)]:
        plans = payload.get("plans", [])
        default_plan = payload.get("defaultPlan")
        plan_ids = [str(p.get("id", "")).strip() for p in plans]

        if default_plan not in plan_ids:
            failures.append(f"[{name}] defaultPlan '{default_plan}' not found in plans")

        seen_plan: set[str] = set()
        seen_product: set[str] = set()

        for p in plans:
            plan_id = str(p.get("id", "")).strip()
            product_id = str(p.get("appStoreProductId", "")).strip()
            if not plan_id:
                failures.append(f"[{name}] plan id is empty")
                continue
            if plan_id in seen_plan:
                failures.append(f"[{name}] duplicate plan id: {plan_id}")
            seen_plan.add(plan_id)

            if not product_id:
                failures.append(f"[{name}] {plan_id} missing appStoreProductId")
            elif product_id in seen_product:
                failures.append(f"[{name}] duplicate appStoreProductId: {product_id}")
            seen_product.add(product_id)

    if source != ios:
        failures.append("config/paywall/paywall_offers.json and iOS paywall_offers.json differ")

    if failures:
        print("Paywall mapping validation failed:")
        for item in failures:
            print(f"- {item}")
        return 1

    print("Paywall mapping validation passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
