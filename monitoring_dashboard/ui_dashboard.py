# Concept: Mukesh Kesharwani
# Contact: mukesh.kesharwani@adobe.com

"""Native Streamlit vulnerability dashboard (jsonl_viewer port)."""

from __future__ import annotations

from datetime import datetime

import pandas as pd
import plotly.graph_objects as go
import streamlit as st

from monitoring_dashboard.collection_schedule import get_last_run, load_meta
from monitoring_dashboard.data_loader import load_jsonl
from monitoring_dashboard.metrics import (
    SEVERITY_COLORS,
    TAB_META,
    entity_metric_averages_last_snapshots,
    entity_name,
    environment_name,
    filter_dataframe,
    get_timestamp_col,
    hero_stats,
    row_metric,
    recent_snapshot_times,
)
from monitoring_dashboard.app_meta import APP_TITLE
from monitoring_dashboard.ui_server_vuln_legacy import render_server_vuln_legacy_tab
from monitoring_dashboard.ui_theme import PLOTLY_LAYOUT, inject_main_nav_styles

TAB_ORDER = ["container", "endpointVuln", "endpoint"]
MAIN_NAV_LABELS = (
    "Server Vulnerabilities-Legacy Tool",
    "Container Vulnerabilities",
    "Endpoint Vulnerabilities",
    "Endpoint Inventory",
)


def render_dashboard() -> None:
    st.title(APP_TITLE)
    last = get_last_run()
    meta = load_meta()
    if last:
        st.caption(
            f"Trend Micro Vision One — OpenTelemetry metrics · Data as of "
            f"{last.strftime('%Y-%m-%d %H:%M UTC')}"
            + (f" ({meta.get('trigger', '')})" if meta.get("trigger") else "")
        )
    else:
        st.caption("Trend Micro Vision One — OpenTelemetry metrics · No collection metadata yet")

    inject_main_nav_styles()
    section = st.radio(
        "Dashboard section",
        list(MAIN_NAV_LABELS),
        horizontal=True,
        label_visibility="collapsed",
        key="main_dashboard_nav",
    )

    if section == MAIN_NAV_LABELS[0]:
        render_server_vuln_legacy_tab()
    elif section == MAIN_NAV_LABELS[1]:
        _render_dataset_tab("container")
    elif section == MAIN_NAV_LABELS[2]:
        _render_dataset_tab("endpointVuln")
    else:
        _render_dataset_tab("endpoint")


def _render_dataset_tab(data_type: str) -> None:
    meta = TAB_META[data_type]
    cache_key = f"df_{data_type}"
    if cache_key not in st.session_state:
        st.session_state[cache_key] = load_jsonl(data_type)
        st.session_state[f"loaded_at_{data_type}"] = datetime.now()

    col_r, col_s = st.columns([3, 1])
    with col_r:
        if st.button("Reload data", key=f"reload_{data_type}"):
            st.session_state[cache_key] = load_jsonl(data_type)
            st.session_state[f"loaded_at_{data_type}"] = datetime.now()
            st.rerun()
    with col_s:
        loaded = st.session_state.get(f"loaded_at_{data_type}")
        if loaded:
            st.caption(f"Loaded {loaded.strftime('%Y-%m-%d %H:%M')}")

    search = st.text_input("Filter", key=f"search_{data_type}", placeholder="Search records…")
    df = st.session_state[cache_key]
    if search:
        df = filter_dataframe(df, search)

    stats = hero_stats(df, data_type)
    _render_hero(meta, stats)

    st.caption(f"Showing {len(df)} record(s)")
    view_mode = st.radio("View charts as", ["Chart", "Table", "Both"], horizontal=True, key=f"view_{data_type}")

    from monitoring_dashboard.ui_theme import inject_subtab_styles

    inject_subtab_styles()
    sub_over, sub_trend, sub_env, sub_data = st.tabs(["Overview", "Trends", "By environment", "Data"])

    with sub_over:
        if view_mode in ("Chart", "Both"):
            _chart_severity(df, data_type)
            _chart_top_entities(df, data_type)
            _chart_risk_hist(df, data_type)
        if view_mode in ("Table", "Both") and not df.empty:
            st.markdown("**Severity totals**")
            st.dataframe(_severity_table(df, data_type), use_container_width=True)

    with sub_trend:
        if view_mode == "Table":
            st.info("Select Chart or Both to view trend lines.")
        else:
            metric = st.selectbox(
                "Metric",
                ["total", "critical", "high", "medium", "low", "risk_score"],
                format_func=lambda x: x.replace("_", " ").title(),
                key=f"metric_{data_type}",
            )
            show_all = st.checkbox("Show all series (top 12 if unchecked)", value=True, key=f"all_{data_type}")
            _chart_trends(df, data_type, metric, show_all)

    with sub_env:
        if view_mode == "Table":
            st.info("Select Chart or Both for environment charts.")
        else:
            _chart_by_environment(df, data_type)

    with sub_data:
        if view_mode == "Chart":
            st.info("Select Table or Both to view raw data.")
        else:
            _render_data_table(df, data_type)


def _render_hero(meta: dict, stats: dict) -> None:
    st.markdown(f'<div class="hero-title">{meta["title"]}</div>', unsafe_allow_html=True)
    if not stats:
        st.caption("No data loaded.")
        return
    latest = stats.get("latest")
    latest_lbl = latest.strftime("%d %b %Y") if latest is not None and pd.notna(latest) else "—"
    c1, c2, c3, c4, c5 = st.columns(5)
    c1.metric("Latest scan", latest_lbl)
    c2.metric(f"Total {meta['vulnWord']}", f"{int(stats.get('total', 0)):,}")
    c3.metric("Critical", f"{int(stats.get('critical', 0)):,}")
    c4.metric("High", f"{int(stats.get('high', 0)):,}")
    c5.metric("Avg risk", f"{stats.get('avg_risk', 0):.1f}")


def _severity_table(df: pd.DataFrame, data_type: str) -> pd.DataFrame:
    return pd.DataFrame(
        {
            "Severity": ["Critical", "High", "Medium", "Low", "Total"],
            "Count": [
                int(sum(row_metric(row, data_type, s) for _, row in df.iterrows()))
                for s in ("critical", "high", "medium", "low", "total")
            ],
        }
    )


def _chart_severity(df: pd.DataFrame, data_type: str) -> None:
    if df.empty:
        st.caption("No data.")
        return
    labels = ["Critical", "High", "Medium", "Low"]
    keys = ["critical", "high", "medium", "low"]
    values = [sum(row_metric(row, data_type, k) for _, row in df.iterrows()) for k in keys]
    fig = go.Figure(
        go.Bar(
            x=labels,
            y=values,
            marker_color=[SEVERITY_COLORS[k] for k in keys],
            text=[f"{v:,}" for v in values],
            textposition="outside",
        )
    )
    fig.update_layout(title="Severity breakdown (aggregated)", height=320, **PLOTLY_LAYOUT)
    fig.update_yaxes(rangemode="tozero")
    st.plotly_chart(fig, use_container_width=True)


def _chart_top_entities(df: pd.DataFrame, data_type: str, limit: int = 15, last_n_snapshots: int = 4) -> None:
    if df.empty:
        return
    averages = entity_metric_averages_last_snapshots(
        df, data_type, "total", last_n_snapshots=last_n_snapshots
    )
    sorted_items = sorted(averages.items(), key=lambda x: x[1], reverse=True)[:limit]
    if not sorted_items:
        st.caption("No entities to chart.")
        return
    names = [x[0] for x in reversed(sorted_items)]
    vals = [x[1] for x in reversed(sorted_items)]
    snap_count = len(recent_snapshot_times(df, last_n_snapshots))
    snap_note = f"last {snap_count} collection{'s' if snap_count != 1 else ''}"
    fig = go.Figure(go.Bar(x=vals, y=names, orientation="h", marker_color="#059669"))
    fig.update_layout(
        title=f"Top {limit} {TAB_META[data_type]['entityLabel']} (avg, {snap_note})",
        height=420,
        **PLOTLY_LAYOUT,
    )
    fig.update_xaxes(rangemode="tozero")
    st.plotly_chart(fig, use_container_width=True)
    st.caption(
        f"Bars show the **average** vulnerability total across the {snap_note} "
        f"(~one month if collected weekly), not cumulative history."
    )


def _chart_risk_hist(df: pd.DataFrame, data_type: str) -> None:
    scores = [row_metric(row, data_type, "risk") for _, row in df.iterrows() if row_metric(row, data_type, "risk") > 0]
    if not scores:
        st.caption("No non-zero risk scores.")
        return
    fig = go.Figure(go.Histogram(x=scores, marker_color="#059669"))
    fig.update_layout(title="Risk score distribution", height=320, **PLOTLY_LAYOUT)
    st.plotly_chart(fig, use_container_width=True)


def _chart_by_environment(df: pd.DataFrame, data_type: str) -> None:
    if df.empty:
        st.caption("No data.")
        return
    by_env: dict[str, dict[str, float]] = {}
    for _, row in df.iterrows():
        env = environment_name(row)
        if env not in by_env:
            by_env[env] = {"critical": 0, "high": 0, "medium": 0, "low": 0}
        for sev in ("critical", "high", "medium", "low"):
            by_env[env][sev] += row_metric(row, data_type, sev)
    envs = sorted(by_env.keys())
    fig = go.Figure()
    for sev in ("critical", "high", "medium", "low"):
        fig.add_trace(
            go.Bar(
                name=sev.capitalize(),
                x=envs,
                y=[by_env[e][sev] for e in envs],
                marker_color=SEVERITY_COLORS[sev],
            )
        )
    fig.update_layout(
        title="Severity by environment",
        barmode="stack",
        height=420,
        **PLOTLY_LAYOUT,
    )
    fig.update_xaxes(tickangle=-25)
    st.plotly_chart(fig, use_container_width=True)


def _chart_trends(df: pd.DataFrame, data_type: str, metric: str, show_all: bool) -> None:
    ts_col = get_timestamp_col(df)
    if df.empty or not ts_col:
        st.caption("No timestamped data.")
        return
    series: dict[str, list] = {}
    for _, row in df.iterrows():
        ts = row.get(ts_col)
        if pd.isna(ts):
            continue
        name = entity_name(row, data_type) or "Unknown"
        if name in ("Unknown", "Ungrouped"):
            continue
        val = row_metric(row, data_type, metric)
        series.setdefault(name, {"x": [], "y": []})
        series[name]["x"].append(pd.to_datetime(ts, utc=True))
        series[name]["y"].append(val)

    if not series:
        st.caption("No series to plot.")
        return

    ranked = sorted(
        series.keys(),
        key=lambda n: sum(series[n]["y"]),
        reverse=True,
    )
    if not show_all:
        ranked = ranked[:12]

    palette = ["#059669", "#2563eb", "#d97706", "#7c3aed", "#db2777", "#0891b2"]
    fig = go.Figure()
    for i, name in enumerate(ranked):
        s = series[name]
        order = sorted(range(len(s["x"])), key=lambda j: s["x"][j])
        xs = [s["x"][j] for j in order]
        ys = [s["y"][j] for j in order]
        fig.add_trace(
            go.Scatter(
                x=xs,
                y=ys,
                mode="lines+markers",
                name=name,
                line=dict(color=palette[i % len(palette)], width=2),
            )
        )
    fig.update_layout(
        title=f"{metric.replace('_', ' ').title()} over time",
        height=420,
        xaxis_title="Time",
        yaxis_title=metric,
        **PLOTLY_LAYOUT,
    )
    st.plotly_chart(fig, use_container_width=True)


def _render_data_table(df: pd.DataFrame, data_type: str) -> None:
    if df.empty:
        st.caption("No data.")
        return
    display = df.copy()
    ts_col = get_timestamp_col(display)
    if ts_col:
        display[ts_col] = pd.to_datetime(display[ts_col], errors="coerce")
    st.dataframe(display, use_container_width=True, height=400)
