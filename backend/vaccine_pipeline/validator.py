from __future__ import annotations


def validate_package(pkg: dict) -> list[str]:
    errors: list[str] = []
    records = pkg.get("records", [])

    if not records:
        errors.append("no records in package")
        return errors

    for idx, row in enumerate(records):
        if not row.get("vaccine_code"):
            errors.append(f"row {idx}: missing vaccine_code")
        if row.get("dose_no") is None:
            errors.append(f"row {idx}: missing dose_no")

        min_age = row.get("min_age_days")
        max_age = row.get("max_age_days")
        if min_age is not None and max_age is not None and min_age > max_age:
            errors.append(f"row {idx}: min_age_days > max_age_days")

    return errors
