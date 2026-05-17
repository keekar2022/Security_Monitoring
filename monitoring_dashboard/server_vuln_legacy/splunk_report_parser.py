# Concept: Mukesh Kesharwani
# Contact: mukesh.kesharwani@adobe.com

"""Parse Splunk Nexpose vulnerability export CSVs (M2-Prod / Cust SA Acct)."""

from __future__ import annotations

import json
import re
from datetime import date, timedelta
from io import BytesIO
from pathlib import Path
from typing import Any

import pandas as pd

from monitoring_dashboard.server_vuln_legacy.aem_report_parser import CONTAINER_CLUSTER

SITE_M2 = "AMSGovCloud M2-Prod"
SITE_SA = "AMSGovCloud Cust SA Acct"

_FILENAME_DATE_RE = re.compile(r"(\d{4}-\d{2}-\d{2})")
_FILENAME_M2_RE = re.compile(r"m2[-_]?prod", re.I)
_FILENAME_SA_RE = re.compile(r"cust[-_\s]?sa", re.I)

_SEVERITY_ORDER = ("Critical", "Severe", "Moderate", "Low", "Info")


def _read_csv_bytes(data: bytes) -> pd.DataFrame | None:
    for encoding in ("utf-8-sig", "utf-8", "latin-1"):
        try:
            return pd.read_csv(BytesIO(data), encoding=encoding)
        except UnicodeDecodeError:
            continue
    return None


def is_splunk_nexpose_bytes(data: bytes) -> bool:
    """True when CSV looks like a Splunk nexpose:vuln export (_time + JSON _raw)."""
    try:
        raw = pd.read_csv(BytesIO(data), nrows=3, encoding="utf-8-sig")
    except Exception:
        return False
    if raw.empty:
        return False
    cols = {str(c).strip().lower() for c in raw.columns}
    if "_time" not in cols or "_raw" not in cols:
        return False
    raw_col = raw.columns[[str(c).strip().lower() == "_raw" for c in raw.columns]][0]
    for val in raw[raw_col].head(3):
        text = str(val).strip()
        if text.startswith("{"):
            return True
    return False


def parse_filename_date(filename: str) -> date | None:
    match = _FILENAME_DATE_RE.search(filename or "")
    if not match:
        return None
    try:
        return pd.to_datetime(match.group(1)).date()
    except (TypeError, ValueError):
        return None


def splunk_export_to_scan_date(export_date: date) -> str:
    """
    Map Splunk export file date to AEM weekly snapshot scan_date.

    Exports are typically pulled on Thursday; spreadsheet rows use the following Friday.
    """
    if export_date.weekday() == 3:  # Thursday
        return (export_date + timedelta(days=1)).isoformat()
    if export_date.weekday() == 4:  # Friday
        return export_date.isoformat()
    days_ahead = (4 - export_date.weekday()) % 7
    if days_ahead == 0:
        days_ahead = 7
    return (export_date + timedelta(days=days_ahead)).isoformat()


def detect_environment(filename: str, sample_site: str | None) -> str | None:
    """Return 'm2' or 'sa' from filename or nexpose_scan_site."""
    name = filename or ""
    if _FILENAME_M2_RE.search(name):
        return "m2"
    if _FILENAME_SA_RE.search(name):
        return "sa"
    site = (sample_site or "").strip()
    if site == SITE_M2:
        return "m2"
    if site == SITE_SA:
        return "sa"
    return None


def _parse_raw_json(raw: str) -> dict[str, Any] | None:
    text = raw.strip()
    if not text.startswith("{"):
        return None
    try:
        payload = json.loads(text)
    except json.JSONDecodeError:
        return None
    return payload if isinstance(payload, dict) else None


def aggregate_splunk_findings(df: pd.DataFrame) -> dict[str, Any]:
    """
    Aggregate Splunk rows into servers (unique assets), TTV (finding rows), and severity breakdown.
    """
    if df.empty:
        return {
            "finding_rows": 0,
            "unique_assets": 0,
            "unique_findings": 0,
            "severity_counts": {},
            "sites": [],
            "nexpose_scan_id": None,
        }

    raw_col = next((c for c in df.columns if str(c).strip().lower() == "_raw"), None)
    sites_col = next((c for c in df.columns if str(c).strip().lower() == "sites"), None)
    if raw_col is None:
        return {
            "finding_rows": 0,
            "unique_assets": 0,
            "unique_findings": 0,
            "severity_counts": {},
            "sites": [],
            "nexpose_scan_id": None,
        }

    assets: set[Any] = set()
    finding_keys: set[tuple[Any, ...]] = set()
    severity_counts: dict[str, int] = {}
    sites: set[str] = set()
    scan_ids: set[str] = set()
    parsed_rows = 0

    for _, row in df.iterrows():
        payload = _parse_raw_json(str(row[raw_col]))
        if not payload:
            continue
        parsed_rows += 1
        asset_id = payload.get("nexpose_asset_id")
        if asset_id is not None:
            assets.add(asset_id)
        site = payload.get("nexpose_scan_site")
        if site:
            sites.add(str(site))
        elif sites_col is not None and pd.notna(row.get(sites_col)):
            sites.add(str(row[sites_col]).strip())

        scan_id = payload.get("nexpose_scan_id")
        if scan_id is not None:
            scan_ids.add(str(scan_id))

        sev = str(payload.get("nexpose_severity") or "unknown").strip() or "unknown"
        severity_counts[sev] = severity_counts.get(sev, 0) + 1

        finding_keys.add(
            (
                asset_id,
                payload.get("signature_id"),
                payload.get("nexpose_vuln_id"),
                payload.get("dest_port"),
            )
        )

    return {
        "finding_rows": parsed_rows,
        "unique_assets": len(assets),
        "unique_findings": len(finding_keys),
        "severity_counts": severity_counts,
        "sites": sorted(sites),
        "nexpose_scan_id": next(iter(scan_ids)) if len(scan_ids) == 1 else None,
    }


def parse_splunk_nexpose_bytes(
    data: bytes,
    *,
    filename: str = "",
) -> tuple[dict[str, Any] | None, list[str]]:
    """
    Parse one Splunk Nexpose CSV export.

    Returns (result, errors). result includes environment, scan_date, servers, ttv, etc.
    """
    errors: list[str] = []
    if not is_splunk_nexpose_bytes(data):
        return None, ["Not a Splunk Nexpose export (_time / _raw JSON columns)."]

    df = _read_csv_bytes(data)
    if df is None:
        return None, ["Could not decode CSV (tried UTF-8 and Latin-1)."]
    if df.empty:
        return None, ["CSV file is empty."]

    agg = aggregate_splunk_findings(df)
    if agg["finding_rows"] == 0:
        return None, ["No parseable Nexpose JSON rows in _raw column."]

    export_date = parse_filename_date(filename)
    if export_date is None:
        time_col = next((c for c in df.columns if str(c).strip().lower() == "_time"), None)
        if time_col:
            times = pd.to_datetime(df[time_col], errors="coerce").dropna()
            if len(times):
                export_date = times.max().date()
    if export_date is None:
        errors.append("Could not determine export date from filename or _time column.")

    sample_site = agg["sites"][0] if agg["sites"] else None
    env = detect_environment(filename, sample_site)
    if env is None:
        errors.append(
            f"Could not map file to M2 or SA (site={sample_site!r}, filename={filename!r})."
        )
        return None, errors

    scan_date = splunk_export_to_scan_date(export_date) if export_date else None

    # TTV in AEM reports matches total finding rows in Splunk exports (validated May 2026).
    ttv = float(agg["finding_rows"])
    servers = int(agg["unique_assets"])

    result: dict[str, Any] = {
        "record_type": "weekly_snapshot",
        "environment": env,
        "scan_date": scan_date,
        "year": int(scan_date[:4]) if scan_date else None,
        "servers": servers,
        "ttv": ttv,
        "finding_rows": agg["finding_rows"],
        "unique_findings": agg["unique_findings"],
        "severity_counts": agg["severity_counts"],
        "sites": agg["sites"],
        "nexpose_scan_id": agg["nexpose_scan_id"],
        "source_file": filename or None,
        "export_date": export_date.isoformat() if export_date else None,
    }
    return result, errors


def _apply_per_server(record: dict[str, Any]) -> None:
    m2s, m2t = record.get("m2_servers"), record.get("m2_ttv")
    if m2s and m2t is not None:
        try:
            record["m2_per_server"] = round(float(m2t) / int(m2s), 2)
        except (TypeError, ValueError, ZeroDivisionError):
            pass
    sas, sat = record.get("sa_servers"), record.get("sa_ttv")
    if sas and sat is not None:
        try:
            record["sa_per_server"] = round(float(sat) / int(sas), 2)
        except (TypeError, ValueError, ZeroDivisionError):
            pass


def splunk_partial_to_weekly_fields(partial: dict[str, Any]) -> dict[str, Any]:
    """Map parse_splunk_nexpose_bytes result onto weekly_snapshot field names."""
    env = partial.get("environment")
    fields: dict[str, Any] = {}
    if env == "m2":
        fields["m2_servers"] = partial.get("servers")
        fields["m2_ttv"] = partial.get("ttv")
    elif env == "sa":
        fields["sa_servers"] = partial.get("servers")
        fields["sa_ttv"] = partial.get("ttv")
    return fields


def build_weekly_snapshot_from_splunk_partials(
    partials: list[dict[str, Any]],
    *,
    upload_id: str,
    source_files: list[str],
) -> dict[str, Any] | None:
    """Combine one or two Splunk parse results (m2 and/or sa) into one weekly_snapshot row."""
    if not partials:
        return None
    scan_dates = {p.get("scan_date") for p in partials if p.get("scan_date")}
    if len(scan_dates) != 1:
        return None
    scan_date = next(iter(scan_dates))
    record: dict[str, Any] = {
        "record_type": "weekly_snapshot",
        "scan_date": scan_date,
        "year": int(str(scan_date)[:4]),
        "container_cluster": CONTAINER_CLUSTER,
        "upload_id": upload_id,
        "source_file": ", ".join(source_files) if source_files else None,
        "splunk_sources": source_files,
    }
    for partial in partials:
        record.update(splunk_partial_to_weekly_fields(partial))
        if partial.get("severity_counts"):
            key = f"splunk_{partial.get('environment')}_severity"
            record[key] = partial["severity_counts"]
    _apply_per_server(record)
    return record


def merge_splunk_partial_into_weekly_row(
    existing: dict[str, Any] | None,
    partial: dict[str, Any],
    *,
    upload_id: str,
    filename: str,
) -> dict[str, Any]:
    """Patch m2 or sa columns on an existing weekly row (preserves container/EKS fields)."""
    scan_date = partial.get("scan_date")
    if existing:
        row = dict(existing)
    else:
        row = {
            "record_type": "weekly_snapshot",
            "scan_date": scan_date,
            "year": int(str(scan_date)[:4]) if scan_date else None,
            "container_cluster": CONTAINER_CLUSTER,
            "image_repo_count": None,
            "container_vul_count": None,
            "m2_containers_per_repo": None,
        }
    row.update(splunk_partial_to_weekly_fields(partial))
    row["upload_id"] = upload_id
    sources = list(row.get("splunk_sources") or [])
    if filename and filename not in sources:
        sources.append(filename)
    row["splunk_sources"] = sources
    if filename:
        prior = row.get("source_file") or ""
        if filename not in prior:
            row["source_file"] = f"{prior}, {filename}".strip(", ") if prior else filename
    env = partial.get("environment")
    if partial.get("severity_counts") and env:
        row[f"splunk_{env}_severity"] = partial["severity_counts"]
    _apply_per_server(row)
    return row


def parse_splunk_to_weekly_rows(
    data: bytes,
    *,
    filename: str = "",
    upload_id: str = "",
) -> tuple[list[dict[str, Any]], list[str]]:
    """Parse Splunk CSV into weekly_snapshot row(s) for ingest (0 or 1 row)."""
    partial, errors = parse_splunk_nexpose_bytes(data, filename=filename)
    if partial is None:
        return [], errors
    row = merge_splunk_partial_into_weekly_row(
        None,
        partial,
        upload_id=upload_id or "splunk-upload",
        filename=filename,
    )
    return [row], errors
