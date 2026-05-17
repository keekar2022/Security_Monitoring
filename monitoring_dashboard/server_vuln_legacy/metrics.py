# Concept: Mukesh Kesharwani
# Contact: mukesh.kesharwani@adobe.com

"""Aggregations and filters for legacy AEM Gov AU weekly scanning dashboard."""

from __future__ import annotations

from typing import Any

import pandas as pd

from monitoring_dashboard.server_vuln_legacy.store import is_weekly_schema

TAB_META = {
    "title": "AEM Gov AU Vulnerability Scanning (2022–2026)",
    "entityLabel": "weekly snapshots",
    "vulnWord": "Total Vulnerabilities (TTV)",
}

SOURCE_LABELS = {
    "m2_prod": "M2-Prod",
    "cust_sa_acct": "Cust SA Acct",
    "aem_weekly": "AEM weekly report",
}

WEEKLY_METRICS = (
    ("m2_ttv", "M2 TTV"),
    ("sa_ttv", "SA TTV"),
    ("container_vul_count", "Container vul count"),
    ("m2_servers", "M2 servers"),
    ("sa_servers", "SA servers"),
    ("m2_per_server", "M2 per server"),
    ("sa_per_server", "SA per server"),
    ("image_repo_count", "Image repos"),
    ("m2_containers_per_repo", "Containers per repo"),
)

LEGACY_METRICS = ("total", "critical", "high", "medium", "low")


def is_weekly_dataframe(df: pd.DataFrame) -> bool:
    if df.empty:
        return is_weekly_schema()
    if "record_type" in df.columns:
        return bool((df["record_type"] == "weekly_snapshot").any())
    return is_weekly_schema() or "m2_ttv" in df.columns


def filter_dataframe(df: pd.DataFrame, search: str) -> pd.DataFrame:
    if df.empty or not search.strip():
        return df
    q = search.strip().lower()
    mask = df.astype(str).apply(lambda row: row.str.lower().str.contains(q, regex=False).any(), axis=1)
    return df[mask]


def hero_stats(df: pd.DataFrame) -> dict[str, Any]:
    if df.empty:
        return {}
    if is_weekly_dataframe(df):
        return _hero_stats_weekly(df)
    return _hero_stats_legacy(df)


def _hero_stats_weekly(df: pd.DataFrame) -> dict[str, Any]:
    sub = df.sort_values("scan_date").iloc[-1] if "scan_date" in df.columns else df.iloc[-1]
    latest_scan = sub.get("scan_date")
    latest_year = int(sub["year"]) if pd.notna(sub.get("year")) else None
    return {
        "weekly": True,
        "latest": latest_scan,
        "latest_year": latest_year,
        "m2_ttv": sub.get("m2_ttv"),
        "sa_ttv": sub.get("sa_ttv"),
        "container_vul_count": sub.get("container_vul_count"),
        "m2_servers": sub.get("m2_servers"),
        "sa_servers": sub.get("sa_servers"),
        "snapshots": len(df),
    }


def _hero_stats_legacy(df: pd.DataFrame) -> dict[str, Any]:
    latest_year = int(df["year"].max()) if "year" in df.columns and df["year"].notna().any() else None
    subset = df[df["year"] == latest_year] if latest_year is not None else df
    latest_scan = None
    if "scan_date" in df.columns and df["scan_date"].notna().any():
        latest_scan = df["scan_date"].max()
    return {
        "weekly": False,
        "latest": latest_scan,
        "latest_year": latest_year,
        "systems": subset["system_name"].nunique() if "system_name" in subset.columns else 0,
        "critical": int(subset["critical"].sum()) if "critical" in subset.columns else 0,
        "high": int(subset["high"].sum()) if "high" in subset.columns else 0,
        "medium": int(subset["medium"].sum()) if "medium" in subset.columns else 0,
        "low": int(subset["low"].sum()) if "low" in subset.columns else 0,
        "total": int(subset["total"].sum()) if "total" in subset.columns else 0,
        "avg_risk": 0.0,
    }


def latest_year_df(df: pd.DataFrame) -> pd.DataFrame:
    if df.empty or "year" not in df.columns:
        return df
    y = df["year"].max()
    return df[df["year"] == y] if pd.notna(y) else df


def sum_severity(df: pd.DataFrame) -> dict[str, int]:
    out = {k: 0 for k in ("critical", "high", "medium", "low", "total")}
    for key in out:
        if key in df.columns:
            out[key] = int(pd.to_numeric(df[key], errors="coerce").fillna(0).sum())
    return out


def filter_years(df: pd.DataFrame, years: list[int]) -> pd.DataFrame:
    if df.empty or not years or "year" not in df.columns:
        return df
    return df[df["year"].isin(years)]


def weekly_display_columns() -> list[tuple[str, str]]:
    return [
        ("scan_date", "Week"),
        ("year", "Year"),
        ("m2_servers", "M2 servers"),
        ("m2_ttv", "M2 TTV"),
        ("image_repo_count", "Image repos"),
        ("container_vul_count", "Container vul count"),
        ("m2_containers_per_repo", "Containers / repo"),
        ("sa_servers", "SA servers"),
        ("sa_ttv", "SA TTV"),
        ("m2_per_server", "M2 / server"),
        ("sa_per_server", "SA / server"),
        ("container_cluster", "Container cluster"),
        ("source_file", "Source file"),
    ]
