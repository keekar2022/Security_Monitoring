# Concept: Mukesh Kesharwani
# Contact: mukesh.kesharwani@adobe.com

"""Persistence for legacy server vulnerability metrics (JSONL + meta + upload ledger)."""

from __future__ import annotations

import hashlib
import json
import os
from datetime import date, datetime, timezone
from pathlib import Path
from typing import Any

import pandas as pd

ROOT = Path(__file__).resolve().parent.parent.parent
LEGACY_DIR = Path(os.environ.get("LEGACY_SERVER_VULN_DIR", str(ROOT / "data" / "server_vulnerabilities_legacy")))
METRICS_FILE = LEGACY_DIR / "metrics.jsonl"
WEEKLY_METRICS_FILE = LEGACY_DIR / "weekly_metrics.jsonl"
META_FILE = LEGACY_DIR / "meta.json"
LEDGER_FILE = LEGACY_DIR / "processed_uploads.json"

STALE_DAYS = 7
SCHEMA_VERSION_WEEKLY = 2

REPORT_SOURCES = {
    "m2_prod": "Splunk Report: AMSGovCloud M2-Prod",
    "cust_sa_acct": "Splunk Report: AMSGovCloud Cust SA Acct",
    "aem_weekly": "AEM Gov AU Vulnerability Scanning Report",
}

WEEKLY_COLUMNS = [
    "record_type",
    "scan_date",
    "year",
    "m2_servers",
    "m2_ttv",
    "image_repo_count",
    "container_vul_count",
    "m2_containers_per_repo",
    "sa_servers",
    "sa_ttv",
    "m2_per_server",
    "sa_per_server",
    "container_cluster",
    "source_file",
    "upload_id",
]

LEGACY_SYSTEM_COLUMNS = [
    "system_name",
    "year",
    "scan_date",
    "report_source",
    "critical",
    "high",
    "medium",
    "low",
    "total",
    "upload_id",
]


def _utc_now_iso() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def ensure_dir() -> None:
    LEGACY_DIR.mkdir(parents=True, exist_ok=True)


def file_sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def is_weekly_schema() -> bool:
    meta = load_store_meta()
    if meta.get("schema_version", 0) >= SCHEMA_VERSION_WEEKLY:
        return True
    return WEEKLY_METRICS_FILE.is_file() and WEEKLY_METRICS_FILE.stat().st_size > 0


def load_ledger() -> dict[str, Any]:
    ensure_dir()
    if not LEDGER_FILE.is_file():
        return {"uploads": []}
    try:
        with LEDGER_FILE.open(encoding="utf-8") as f:
            data = json.load(f)
        if isinstance(data, dict) and isinstance(data.get("uploads"), list):
            return data
    except (json.JSONDecodeError, OSError):
        pass
    return {"uploads": []}


def save_ledger(ledger: dict[str, Any]) -> None:
    ensure_dir()
    with LEDGER_FILE.open("w", encoding="utf-8") as f:
        json.dump(ledger, f, indent=2)
        f.write("\n")


def is_file_processed(file_hash: str) -> dict[str, Any] | None:
    for entry in load_ledger().get("uploads", []):
        if entry.get("file_sha256") == file_hash:
            return entry
    return None


def load_store_meta() -> dict[str, Any]:
    ensure_dir()
    if not META_FILE.is_file():
        return {}
    try:
        with META_FILE.open(encoding="utf-8") as f:
            data = json.load(f)
        return data if isinstance(data, dict) else {}
    except (json.JSONDecodeError, OSError):
        return {}


def save_store_meta(meta: dict[str, Any]) -> None:
    ensure_dir()
    with META_FILE.open("w", encoding="utf-8") as f:
        json.dump(meta, f, indent=2)
        f.write("\n")


def _read_jsonl(path: Path) -> list[dict[str, Any]]:
    if not path.is_file():
        return []
    rows: list[dict[str, Any]] = []
    with path.open(encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                rows.append(json.loads(line))
            except json.JSONDecodeError:
                continue
    return rows


def load_records() -> list[dict[str, Any]]:
    if is_weekly_schema() or (WEEKLY_METRICS_FILE.is_file() and WEEKLY_METRICS_FILE.stat().st_size > 0):
        return _read_jsonl(WEEKLY_METRICS_FILE)
    return _read_jsonl(METRICS_FILE)


def load_dataframe() -> pd.DataFrame:
    rows = load_records()
    weekly = is_weekly_schema() or (
        rows and rows[0].get("record_type") == "weekly_snapshot"
    )
    if not rows:
        cols = WEEKLY_COLUMNS if weekly else LEGACY_SYSTEM_COLUMNS
        return pd.DataFrame(columns=cols)

    df = pd.DataFrame(rows)
    if "scan_date" in df.columns:
        df["scan_date"] = pd.to_datetime(df["scan_date"], errors="coerce")
    if "year" in df.columns:
        df["year"] = pd.to_numeric(df["year"], errors="coerce").astype("Int64")
    return df


def _max_scan_date(rows: list[dict[str, Any]]) -> date | None:
    dates: list[date] = []
    for row in rows:
        raw = row.get("scan_date")
        if not raw:
            continue
        try:
            if isinstance(raw, date) and not isinstance(raw, datetime):
                dates.append(raw)
            else:
                dates.append(pd.to_datetime(raw).date())
        except (TypeError, ValueError):
            continue
    return max(dates) if dates else None


def refresh_meta_from_metrics() -> dict[str, Any]:
    rows = load_records()
    max_date = _max_scan_date(rows)
    weekly = is_weekly_schema() or (rows and rows[0].get("record_type") == "weekly_snapshot")
    meta = load_store_meta()
    meta.update(
        {
            "last_data_date": max_date.isoformat() if max_date else None,
            "record_count": len(rows),
        }
    )
    if weekly:
        meta["schema_version"] = SCHEMA_VERSION_WEEKLY
        meta["record_type"] = "weekly_snapshot"
        meta["mock"] = False
        if rows:
            meta["first_data_date"] = min(
                str(r.get("scan_date", ""))[:10] for r in rows if r.get("scan_date")
            )
    save_store_meta(meta)
    return meta


def write_metrics_file(rows: list[dict[str, Any]], *, append: bool = False) -> None:
    """Write per-system legacy metrics (deprecated when weekly schema active)."""
    ensure_dir()
    mode = "a" if append else "w"
    with METRICS_FILE.open(mode, encoding="utf-8") as f:
        for row in rows:
            f.write(json.dumps(row, separators=(",", ":")) + "\n")


def write_weekly_metrics_file(rows: list[dict[str, Any]]) -> None:
    ensure_dir()
    with WEEKLY_METRICS_FILE.open("w", encoding="utf-8") as f:
        for row in rows:
            f.write(json.dumps(row, separators=(",", ":")) + "\n")


def merge_weekly_into_store(new_rows: list[dict[str, Any]]) -> int:
    """Merge new weekly rows by scan_date; returns count added/updated."""
    existing = _read_jsonl(WEEKLY_METRICS_FILE)
    by_date = {str(r["scan_date"])[:10]: r for r in existing if r.get("scan_date")}
    before = len(by_date)
    for row in new_rows:
        key = str(row["scan_date"])[:10]
        by_date[key] = row
    merged = sorted(by_date.values(), key=lambda r: str(r["scan_date"]))
    write_weekly_metrics_file(merged)
    meta = refresh_meta_from_metrics()
    meta["schema_version"] = SCHEMA_VERSION_WEEKLY
    meta["mock"] = False
    save_store_meta(meta)
    return len(by_date) - before


def is_data_stale() -> tuple[bool, str | None]:
    meta = load_store_meta()
    raw = meta.get("last_data_date")
    if not raw:
        return True, None
    try:
        last = pd.to_datetime(raw).date()
    except (TypeError, ValueError):
        return True, str(raw)
    age = (date.today() - last).days
    return age > STALE_DAYS, last.isoformat()


def ingest_upload(
    file_bytes: bytes,
    filename: str,
    report_source: str,
    parsed_rows: list[dict[str, Any]],
) -> tuple[bool, str]:
    """Append parsed rows if file not yet processed. Returns (success, message)."""
    from monitoring_dashboard.server_vuln_legacy.aem_report_parser import is_aem_report_bytes

    file_hash = file_sha256(file_bytes)
    existing = is_file_processed(file_hash)
    if existing:
        processed = existing.get("processed_at", "unknown")
        return False, f"This file was already processed on {processed}. No duplicate entries were added."

    if not parsed_rows:
        return False, "No valid rows found in the uploaded file."

    if is_aem_report_bytes(file_bytes) or (
        parsed_rows and parsed_rows[0].get("record_type") == "weekly_snapshot"
    ):
        for row in parsed_rows:
            row["upload_id"] = file_hash
        added = merge_weekly_into_store(parsed_rows)
        scan_max = _max_scan_date(parsed_rows)
        ledger = load_ledger()
        ledger.setdefault("uploads", []).append(
            {
                "file_sha256": file_hash,
                "original_filename": filename,
                "processed_at": _utc_now_iso(),
                "report_source": "aem_weekly",
                "rows_added": len(parsed_rows),
                "scan_date_max": scan_max.isoformat() if scan_max else None,
            }
        )
        save_ledger(ledger)
        meta = refresh_meta_from_metrics()
        meta["last_upload_at"] = _utc_now_iso()
        save_store_meta(meta)
        return True, f"Merged {len(parsed_rows)} weekly row(s) from {filename} (net change: {added})."

    for row in parsed_rows:
        row["upload_id"] = file_hash
        row["report_source"] = report_source

    write_metrics_file(parsed_rows, append=True)

    scan_dates = [_max_scan_date([r]) for r in parsed_rows]
    scan_dates = [d for d in scan_dates if d]
    scan_max = max(scan_dates).isoformat() if scan_dates else None

    ledger = load_ledger()
    ledger.setdefault("uploads", []).append(
        {
            "file_sha256": file_hash,
            "original_filename": filename,
            "processed_at": _utc_now_iso(),
            "report_source": report_source,
            "rows_added": len(parsed_rows),
            "scan_date_max": scan_max,
        }
    )
    save_ledger(ledger)

    meta = refresh_meta_from_metrics()
    meta["last_upload_at"] = _utc_now_iso()
    save_store_meta(meta)

    return True, f"Processed {len(parsed_rows)} row(s) from {filename}."


def ensure_seeded() -> None:
    """Create mock metrics only when no weekly or legacy data exists."""
    from monitoring_dashboard.server_vuln_legacy.mock_data import generate_mock_rows

    ensure_dir()
    force = os.environ.get("FORCE_LEGACY_MOCK", "").lower() in ("1", "true", "yes")

    if WEEKLY_METRICS_FILE.is_file() and WEEKLY_METRICS_FILE.stat().st_size > 0 and not force:
        if not META_FILE.is_file():
            refresh_meta_from_metrics()
        return

    meta = load_store_meta()
    if meta.get("mock") is False and not force:
        if WEEKLY_METRICS_FILE.is_file() or METRICS_FILE.is_file():
            if not META_FILE.is_file():
                refresh_meta_from_metrics()
            return

    if METRICS_FILE.is_file() and not force:
        if not META_FILE.is_file():
            refresh_meta_from_metrics()
        return

    rows = generate_mock_rows()
    write_metrics_file(rows, append=False)
    ledger = {
        "uploads": [
            {
                "file_sha256": "mock-seed",
                "original_filename": "mock_seed.csv",
                "processed_at": _utc_now_iso(),
                "report_source": "m2_prod",
                "rows_added": len(rows),
                "scan_date_max": _max_scan_date(rows).isoformat() if _max_scan_date(rows) else None,
            }
        ]
    }
    save_ledger(ledger)
    meta = refresh_meta_from_metrics()
    meta["seeded"] = True
    meta["mock"] = True
    save_store_meta(meta)
