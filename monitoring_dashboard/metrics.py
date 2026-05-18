# Concept: Mukesh Kesharwani
# Contact: mukesh.kesharwani@adobe.com

"""Metric helpers ported from jsonl_viewer.html."""

from __future__ import annotations

from typing import Any

import pandas as pd

TAB_META = {
    "container": {
        "title": "Container Security",
        "filename": "container_vulnerability_metrics.jsonl",
        "entityLabel": "clusters",
        "vulnWord": "Vulnerabilities",
    },
    "endpointVuln": {
        "title": "Endpoint Vulnerabilities (ASRM)",
        "filename": "endpoint_vulnerability_metrics.jsonl",
        "entityLabel": "devices",
        "vulnWord": "Vulnerabilities",
    },
    "endpoint": {
        "title": "Endpoint Inventory",
        "filename": "endpoint_inventory_metrics.jsonl",
        "entityLabel": "endpoints",
        "vulnWord": "Detections",
    },
}

SEVERITY_COLORS = {
    "critical": "#dc3545",
    "high": "#fd7e14",
    "medium": "#ffc107",
    "low": "#28a745",
}


def get_timestamp_col(df: pd.DataFrame) -> str | None:
    for col in ("Timestamp", "ObservedTimestamp"):
        if col in df.columns:
            return col
    return None


def _num(row: pd.Series, *keys: str) -> float:
    for k in keys:
        if k in row.index and pd.notna(row[k]):
            return float(row[k])
    return 0.0


def severity_columns(data_type: str) -> dict[str, list[str]]:
    if data_type == "container":
        return {
            "critical": ["Attributes.vulnerability.severity.critical", "vulnerability.severity.critical"],
            "high": ["Attributes.vulnerability.severity.high", "vulnerability.severity.high"],
            "medium": ["Attributes.vulnerability.severity.medium", "vulnerability.severity.medium"],
            "low": ["Attributes.vulnerability.severity.low", "vulnerability.severity.low"],
            "total": ["Attributes.vulnerability.total", "vulnerability.total"],
            "risk": ["Attributes.vulnerability.risk_score", "vulnerability.risk_score"],
        }
    if data_type == "endpointVuln":
        return {
            "critical": ["vulnerability.critical"],
            "high": ["vulnerability.high"],
            "medium": ["vulnerability.medium"],
            "low": ["vulnerability.low"],
            "total": ["vulnerability.total"],
            "risk": ["vulnerability.risk_score"],
        }
    return {
        "critical": ["detections.critical"],
        "high": ["detections.high"],
        "medium": ["detections.medium"],
        "low": ["detections.low"],
        "total": ["detections.total"],
        "risk": ["detections.risk_score"],
    }


def row_metric(row: pd.Series, data_type: str, metric: str) -> float:
    cols = severity_columns(data_type).get(metric, [])
    return _num(row, *cols)


def entity_name(row: pd.Series, data_type: str) -> str | None:
    if data_type == "container":
        for k in ("Attributes.cluster.name", "cluster.name", "Attributes.group.name"):
            v = row.get(k)
            if isinstance(v, str) and v.strip() and v.strip() not in ("Ungrouped", "Unknown"):
                return v.strip()
        return None
    if data_type == "endpointVuln":
        return row.get("device.name") or row.get("device.id")
    return row.get("endpoint.name")


# Canonical labels for dashboard charts (merge legacy/alternate collector names).
_ENVIRONMENT_CANONICAL = {
    "quality & test": "AMS QTE",
    "quality and test": "AMS QTE",
}


def normalize_environment_name(name: str) -> str:
    """Map alternate Trend Micro environment labels to one dashboard bar."""
    text = (name or "").strip()
    if not text:
        return "Unknown"
    return _ENVIRONMENT_CANONICAL.get(text.lower(), text)


def environment_name(row: pd.Series) -> str:
    for k in ("Resource.deployment.environment", "deployment.environment"):
        v = row.get(k)
        if isinstance(v, str) and v.strip():
            return normalize_environment_name(v)
    return "Unknown"


def filter_dataframe(df: pd.DataFrame, term: str) -> pd.DataFrame:
    if df.empty or not term.strip():
        return df
    mask = df.astype(str).apply(lambda col: col.str.contains(term, case=False, na=False)).any(axis=1)
    return df[mask]


def recent_snapshot_times(df: pd.DataFrame, last_n: int = 4) -> list[pd.Timestamp]:
    """Most recent collection timestamps in the dataset (newest first)."""
    ts_col = get_timestamp_col(df)
    if df.empty or not ts_col:
        return []
    times = pd.to_datetime(df[ts_col], errors="coerce", utc=True).dropna()
    if times.empty:
        return []
    unique = sorted(times.unique(), reverse=True)
    return list(unique[:last_n])


def entity_metric_averages_last_snapshots(
    df: pd.DataFrame,
    data_type: str,
    metric: str = "total",
    *,
    last_n_snapshots: int = 4,
) -> dict[str, float]:
    """
    Per-entity mean metric across the last N collection runs (not cumulative).

    Each snapshot contributes one value per entity; duplicates at the same timestamp
    use the maximum value for that entity.
    """
    ts_col = get_timestamp_col(df)
    if df.empty or not ts_col or last_n_snapshots < 1:
        return {}

    snapshots = recent_snapshot_times(df, last_n_snapshots)
    if not snapshots:
        return {}

    ts_series = pd.to_datetime(df[ts_col], errors="coerce", utc=True)
    recent = df.loc[ts_series.isin(snapshots)]
    if recent.empty:
        return {}

    by_entity_ts: dict[str, dict[pd.Timestamp, float]] = {}
    for _, row in recent.iterrows():
        name = entity_name(row, data_type)
        if not name:
            continue
        ts = pd.to_datetime(row[ts_col], errors="coerce", utc=True)
        if pd.isna(ts):
            continue
        val = row_metric(row, data_type, metric)
        bucket = by_entity_ts.setdefault(name, {})
        bucket[ts] = max(bucket.get(ts, 0.0), val)

    return {name: sum(vals.values()) / len(vals) for name, vals in by_entity_ts.items() if vals}


def hero_stats(df: pd.DataFrame, data_type: str) -> dict[str, Any]:
    if df.empty:
        return {}
    ts_col = get_timestamp_col(df)
    latest = None
    if ts_col:
        times = pd.to_datetime(df[ts_col], errors="coerce", utc=True)
        if times.notna().any():
            latest = times.max()
    entities = set()
    for _, row in df.iterrows():
        en = entity_name(row, data_type)
        if en:
            entities.add(en)
    return {
        "records": len(df),
        "entities": len(entities),
        "total": sum(row_metric(row, data_type, "total") for _, row in df.iterrows()),
        "critical": sum(row_metric(row, data_type, "critical") for _, row in df.iterrows()),
        "high": sum(row_metric(row, data_type, "high") for _, row in df.iterrows()),
        "medium": sum(row_metric(row, data_type, "medium") for _, row in df.iterrows()),
        "low": sum(row_metric(row, data_type, "low") for _, row in df.iterrows()),
        "avg_risk": (
            sum(row_metric(row, data_type, "risk") for _, row in df.iterrows()) / len(df) if len(df) else 0
        ),
        "latest": latest,
    }
