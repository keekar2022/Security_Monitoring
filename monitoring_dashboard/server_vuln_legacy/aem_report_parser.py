# Concept: Mukesh Kesharwani
# Contact: mukesh.kesharwani@adobe.com

"""Parse AEM Gov AU weekly vulnerability scanning report CSVs (2022–2026)."""

from __future__ import annotations

import os
from datetime import date
from io import BytesIO
from pathlib import Path
from typing import Any

import pandas as pd

CONTAINER_CLUSTER = "EKS_AEMGovAU_PROD_Cluster"
SKIP_ROW_PREFIXES = ("average of year", "median of year", "note:")

# Spreadsheet forward-fill / projected weeks (see CSV note row). Override: AEM_PREDICTED_CUTOFF=YYYY-MM-DD
_DEFAULT_PREDICTED_CUTOFF = date(2026, 5, 13)


def predicted_data_cutoff() -> date:
    raw = (os.environ.get("AEM_PREDICTED_CUTOFF") or "").strip()
    if raw:
        return pd.to_datetime(raw).date()
    return _DEFAULT_PREDICTED_CUTOFF


def is_predicted_snapshot(scan_date: str | None) -> bool:
    """True when scan_date is on/after the configured projected-data cutoff."""
    if not scan_date:
        return False
    try:
        d = pd.to_datetime(scan_date).date()
    except (TypeError, ValueError):
        return False
    return d >= predicted_data_cutoff()


def filter_predicted_rows(rows: list[dict[str, Any]]) -> tuple[list[dict[str, Any]], int]:
    """Drop projected/forward-filled snapshots; returns (kept, removed_count)."""
    kept: list[dict[str, Any]] = []
    removed = 0
    for row in rows:
        if is_predicted_snapshot(row.get("scan_date")):
            removed += 1
            continue
        kept.append(row)
    return kept, removed

_LEGACY_COLS = 7
_EXTENDED_MIN_COLS = 10


def _is_skip_label(val: Any) -> bool:
    if val is None or (isinstance(val, float) and pd.isna(val)):
        return True
    text = str(val).strip().lower()
    if not text:
        return True
    return any(text.startswith(p) for p in SKIP_ROW_PREFIXES)


def _parse_float(val: Any) -> float | None:
    if val is None or (isinstance(val, float) and pd.isna(val)):
        return None
    text = str(val).strip().replace(",", "")
    if not text:
        return None
    try:
        return float(text)
    except ValueError:
        return None


def _parse_int(val: Any) -> int | None:
    f = _parse_float(val)
    if f is None:
        return None
    return int(round(f))


def _parse_scan_date(val: Any) -> str | None:
    if _is_skip_label(val):
        return None
    try:
        dt = pd.to_datetime(val, dayfirst=True, errors="coerce")
        if pd.isna(dt):
            return None
        return dt.date().isoformat()
    except (TypeError, ValueError):
        return None


def detect_extended_layout(header_row: pd.Series) -> bool:
    """True when CSV row 0 includes container columns (2025+ layout)."""
    cells = [str(c).strip() for c in header_row if not (isinstance(c, float) and pd.isna(c))]
    joined = " ".join(cells).lower()
    return "m2-containers vul count" in joined or "image repo" in joined


def parse_aem_report_bytes(
    data: bytes,
    *,
    source_file: str = "",
    upload_id: str = "import-aem-2022-2026",
    apply_predicted_filter: bool = True,
) -> tuple[list[dict[str, Any]], list[str]]:
    """
    Parse one AEM Gov AU scanning report CSV.
    Returns (rows, errors).
    """
    errors: list[str] = []
    for encoding in ("utf-8-sig", "utf-8", "latin-1"):
        try:
            raw = pd.read_csv(BytesIO(data), header=None, encoding=encoding)
            break
        except UnicodeDecodeError:
            raw = None
    else:
        return [], ["Could not decode CSV (tried UTF-8 and Latin-1)."]

    if raw is None or len(raw) < 3:
        return [], ["CSV file is empty or missing data rows."]

    extended = detect_extended_layout(raw.iloc[0])
    data_rows = raw.iloc[2:]
    rows: list[dict[str, Any]] = []

    for idx, row in data_rows.iterrows():
        date_val = row.iloc[0] if len(row) > 0 else None
        if _is_skip_label(date_val):
            continue
        scan_date = _parse_scan_date(date_val)
        if not scan_date:
            continue

        year = int(scan_date[:4])
        record: dict[str, Any] = {
            "record_type": "weekly_snapshot",
            "scan_date": scan_date,
            "year": year,
            "container_cluster": CONTAINER_CLUSTER,
            "source_file": source_file or None,
            "upload_id": upload_id,
        }

        if extended:
            if len(row) < _EXTENDED_MIN_COLS:
                errors.append(f"Row {idx + 1}: expected extended layout columns")
                continue
            record.update(
                {
                    "m2_servers": _parse_int(row.iloc[1]),
                    "m2_ttv": _parse_float(row.iloc[2]),
                    "image_repo_count": _parse_int(row.iloc[3]),
                    "container_vul_count": _parse_int(row.iloc[4]),
                    "sa_servers": _parse_int(row.iloc[5]),
                    "sa_ttv": _parse_float(row.iloc[6]),
                    "m2_per_server": _parse_float(row.iloc[7]),
                    "sa_per_server": _parse_float(row.iloc[8]),
                    "m2_containers_per_repo": _parse_float(row.iloc[9]),
                }
            )
        else:
            if len(row) < _LEGACY_COLS:
                errors.append(f"Row {idx + 1}: expected legacy layout columns")
                continue
            record.update(
                {
                    "m2_servers": _parse_int(row.iloc[1]),
                    "m2_ttv": _parse_float(row.iloc[2]),
                    "image_repo_count": None,
                    "container_vul_count": None,
                    "sa_servers": _parse_int(row.iloc[3]),
                    "sa_ttv": _parse_float(row.iloc[4]),
                    "m2_per_server": _parse_float(row.iloc[5]),
                    "sa_per_server": _parse_float(row.iloc[6]),
                    "m2_containers_per_repo": None,
                }
            )

        rows.append(record)

    if not rows and not errors:
        errors.append("No weekly data rows parsed from CSV.")

    if apply_predicted_filter:
        rows, dropped = filter_predicted_rows(rows)
        if dropped:
            cutoff = predicted_data_cutoff().isoformat()
            errors.append(
                f"Excluded {dropped} projected row(s) with scan_date on/after {cutoff} "
                f"(set AEM_PREDICTED_CUTOFF to change)."
            )

    return rows, errors


def parse_aem_report_file(path: Path, **kwargs: Any) -> tuple[list[dict[str, Any]], list[str]]:
    data = path.read_bytes()
    return parse_aem_report_bytes(data, source_file=path.name, **kwargs)


def is_aem_report_bytes(data: bytes) -> bool:
    """Detect AEM Gov AU aggregate report format (row 0 group headers)."""
    try:
        raw = pd.read_csv(BytesIO(data), header=None, nrows=1, encoding="utf-8-sig")
    except Exception:
        return False
    if raw.empty:
        return False
    joined = " ".join(str(c) for c in raw.iloc[0] if not (isinstance(c, float) and pd.isna(c)))
    return "amsgovcloud m2-prod" in joined.lower()


def merge_weekly_records(
    file_rows: list[tuple[str, list[dict[str, Any]]]],
) -> list[dict[str, Any]]:
    """
    Merge rows from multiple files; later files win on duplicate scan_date.
    file_rows: list of (source_file, rows) in processing order.
    """
    by_date: dict[str, dict[str, Any]] = {}
    for source_file, rows in file_rows:
        for row in rows:
            key = row["scan_date"]
            row = dict(row)
            row["source_file"] = source_file
            by_date[key] = row
    merged = sorted(by_date.values(), key=lambda r: r["scan_date"])
    filtered, _ = filter_predicted_rows(merged)
    return filtered


def validate_container_counts(
    rows: list[dict[str, Any]],
    container_jsonl: Path,
    *,
    cluster_name: str = CONTAINER_CLUSTER,
) -> list[str]:
    """Optional: compare CSV container_vul_count to nearest container metrics snapshot."""
    import json

    warnings: list[str] = []
    if not container_jsonl.is_file():
        return warnings

    snapshots: list[tuple[str, int]] = []
    with container_jsonl.open(encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                rec = json.loads(line)
            except json.JSONDecodeError:
                continue
            cluster = rec.get("cluster.name") or rec.get("cluster_name") or ""
            if cluster_name not in str(cluster):
                continue
            ts = rec.get("@timestamp") or rec.get("timestamp") or rec.get("scan_date")
            total = rec.get("vulnerability.total") or rec.get("total_vulnerabilities")
            if ts and total is not None:
                try:
                    d = pd.to_datetime(ts).date().isoformat()
                    snapshots.append((d, int(total)))
                except (TypeError, ValueError):
                    continue

    if not snapshots:
        return warnings

    snapshots.sort(key=lambda x: x[0])
    for row in rows:
        cv = row.get("container_vul_count")
        if cv is None:
            continue
        sd = row["scan_date"]
        nearest = min(snapshots, key=lambda s: abs((pd.to_datetime(s[0]) - pd.to_datetime(sd)).days))
        diff = abs(int(cv) - nearest[1])
        if diff > 500:
            warnings.append(
                f"{sd}: CSV container_vul_count={cv} vs nearest EKS snapshot "
                f"({nearest[0]})={nearest[1]} (diff={diff})"
            )
    return warnings[:20]
