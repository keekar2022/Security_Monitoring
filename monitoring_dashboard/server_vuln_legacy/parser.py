# Concept: Mukesh Kesharwani
# Contact: mukesh.kesharwani@adobe.com

"""Parse Splunk legacy server vulnerability CSV uploads."""

from __future__ import annotations

import json
from io import BytesIO
from pathlib import Path
from typing import Any

import pandas as pd

ROOT = Path(__file__).resolve().parent.parent.parent
COLUMN_CONFIG = ROOT / "config" / "server_vuln_legacy_columns.json"
COLUMN_CONFIG_EXAMPLE = ROOT / "config" / "server_vuln_legacy_columns.json.example"


def _load_column_map() -> dict[str, list[str]]:
    path = COLUMN_CONFIG if COLUMN_CONFIG.is_file() else COLUMN_CONFIG_EXAMPLE
    if not path.is_file():
        return {
            "system_name": ["System", "Hostname", "server_name"],
            "year": ["Year", "year"],
            "scan_date": ["Scan Date", "Date", "scan_date"],
            "critical": ["Critical"],
            "high": ["High"],
            "medium": ["Medium"],
            "low": ["Low"],
            "total": ["Total", "Vulnerabilities"],
        }
    with path.open(encoding="utf-8") as f:
        data = json.load(f)
    return {k: list(v) for k, v in data.items() if isinstance(v, list)}


def _resolve_column(df: pd.DataFrame, aliases: list[str]) -> str | None:
    cols = {c.strip().lower(): c for c in df.columns}
    for alias in aliases:
        key = alias.strip().lower()
        if key in cols:
            return cols[key]
    return None


def _parse_int(val: Any) -> int:
    if pd.isna(val):
        return 0
    try:
        return int(float(str(val).replace(",", "").strip()))
    except (TypeError, ValueError):
        return 0


def _parse_year(val: Any) -> int | None:
    if pd.isna(val):
        return None
    try:
        y = int(float(str(val).strip()))
        if 1990 <= y <= 2100:
            return y
    except (TypeError, ValueError):
        pass
    return None


def _parse_scan_date(val: Any, year: int | None) -> str | None:
    if pd.isna(val) or str(val).strip() == "":
        if year:
            return f"{year}-06-15"
        return None
    try:
        return pd.to_datetime(val).date().isoformat()
    except (TypeError, ValueError):
        return None


def parse_csv_bytes(data: bytes) -> tuple[list[dict[str, Any]], list[str]]:
    """
    Parse CSV bytes into normalized records.
    Returns (rows, errors). If errors non-empty, rows may be empty.
    """
    errors: list[str] = []
    col_map = _load_column_map()

    for encoding in ("utf-8-sig", "utf-8", "latin-1"):
        try:
            raw = pd.read_csv(BytesIO(data), encoding=encoding)
            break
        except UnicodeDecodeError:
            raw = None
    else:
        return [], ["Could not decode CSV (tried UTF-8 and Latin-1)."]

    if raw is None or raw.empty:
        return [], ["CSV file is empty or unreadable."]

    resolved: dict[str, str] = {}
    for field, aliases in col_map.items():
        col = _resolve_column(raw, aliases)
        if col:
            resolved[field] = col

    required = ("system_name", "year")
    for req in required:
        if req not in resolved:
            errors.append(f"Missing required column for '{req}' (aliases: {col_map.get(req, [])})")

    if errors:
        return [], errors

    rows: list[dict[str, Any]] = []
    for idx, row in raw.iterrows():
        system = str(row[resolved["system_name"]]).strip()
        if not system:
            continue
        year = _parse_year(row[resolved["year"]]) if "year" in resolved else None
        if year is None:
            errors.append(f"Row {idx + 2}: invalid year")
            continue

        scan_col = resolved.get("scan_date")
        scan_date = _parse_scan_date(row[scan_col], year) if scan_col else f"{year}-06-15"

        crit = _parse_int(row[resolved["critical"]]) if "critical" in resolved else 0
        high = _parse_int(row[resolved["high"]]) if "high" in resolved else 0
        med = _parse_int(row[resolved["medium"]]) if "medium" in resolved else 0
        low = _parse_int(row[resolved["low"]]) if "low" in resolved else 0
        total = _parse_int(row[resolved["total"]]) if "total" in resolved else crit + high + med + low

        rows.append(
            {
                "system_name": system,
                "year": year,
                "scan_date": scan_date,
                "critical": crit,
                "high": high,
                "medium": med,
                "low": low,
                "total": total,
            }
        )

    if not rows and not errors:
        errors.append("No data rows parsed from CSV.")
    return rows, errors
