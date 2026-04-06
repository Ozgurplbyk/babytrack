from __future__ import annotations

from typing import Any


def make_index(pkg: dict[str, Any]) -> dict[str, dict[str, Any]]:
    idx: dict[str, dict[str, Any]] = {}
    for rec in pkg.get("records", []):
        key = f"{rec.get('vaccine_code')}|{rec.get('dose_no')}|{rec.get('country')}"
        idx[key] = rec
    return idx


def diff_packages(old_pkg: dict[str, Any] | None, new_pkg: dict[str, Any]) -> dict[str, list[dict[str, Any]]]:
    if not old_pkg:
        return {"added": new_pkg.get("records", []), "removed": [], "changed": []}

    old_i = make_index(old_pkg)
    new_i = make_index(new_pkg)

    added = [new_i[k] for k in new_i.keys() - old_i.keys()]
    removed = [old_i[k] for k in old_i.keys() - new_i.keys()]

    changed = []
    for key in old_i.keys() & new_i.keys():
        if old_i[key] != new_i[key]:
            changed.append({"before": old_i[key], "after": new_i[key]})

    return {"added": added, "removed": removed, "changed": changed}
