# Concept: Mukesh Kesharwani
# Contact: mukesh.kesharwani@adobe.com

"""ServerVulnerabilities-LegacyTool tab — AEM Gov AU weekly scanning trends (2022–2026)."""

from __future__ import annotations

from datetime import datetime

import pandas as pd
import plotly.graph_objects as go
import streamlit as st

from monitoring_dashboard.metrics import SEVERITY_COLORS
from monitoring_dashboard.server_vuln_legacy import (
    ensure_seeded,
    ingest_upload,
    is_data_stale,
    load_dataframe,
    load_ledger,
    load_store_meta,
)
from monitoring_dashboard.server_vuln_legacy.aem_report_parser import (
    is_aem_report_bytes,
    parse_aem_report_bytes,
)
from monitoring_dashboard.server_vuln_legacy.metrics import (
    LEGACY_METRICS,
    SOURCE_LABELS,
    TAB_META,
    WEEKLY_METRICS,
    filter_dataframe,
    hero_stats,
    is_weekly_dataframe,
    latest_year_df,
    sum_severity,
    weekly_display_columns,
)
from monitoring_dashboard.server_vuln_legacy.parser import parse_csv_bytes
from monitoring_dashboard.ui_theme import PLOTLY_LAYOUT


def render_server_vuln_legacy_tab() -> None:
    ensure_seeded()

    stale, last_date = is_data_stale()
    if stale:
        prev = last_date or "unknown"
        st.warning(
            f"Latest data feed is not provided. Previous data was from **{prev}**. "
            "Please upload the latest AEM Gov AU vulnerability scanning report CSV."
        )
    else:
        st.caption(
            f"Data is current (last snapshot: **{last_date}**). "
            "Upload a newer weekly report CSV when available."
        )

    cache_key = "df_server_vuln_legacy"
    if cache_key not in st.session_state:
        st.session_state[cache_key] = load_dataframe()
        st.session_state["loaded_at_server_vuln_legacy"] = datetime.now()

    col_r, col_s = st.columns([3, 1])
    with col_r:
        if st.button("Reload data", key="reload_server_vuln_legacy"):
            st.session_state[cache_key] = load_dataframe()
            st.session_state["loaded_at_server_vuln_legacy"] = datetime.now()
            st.rerun()
    with col_s:
        loaded = st.session_state.get("loaded_at_server_vuln_legacy")
        if loaded:
            st.caption(f"Loaded {loaded.strftime('%Y-%m-%d %H:%M')}")

    df = st.session_state[cache_key]
    weekly = is_weekly_dataframe(df)
    meta = TAB_META

    c_f1, c_f2 = st.columns([2, 1])
    with c_f1:
        placeholder = "Search dates, metrics…" if weekly else "Search systems…"
        search = st.text_input("Filter", key="search_legacy", placeholder=placeholder)
    with c_f2:
        years = sorted(df["year"].dropna().unique().tolist()) if not df.empty and "year" in df.columns else []
        year_filter = st.multiselect("Years", years, default=years, key="years_legacy")

    if search:
        df = filter_dataframe(df, search)
    if year_filter and "year" in df.columns:
        df = df[df["year"].isin(year_filter)]

    if not weekly and "report_source" in df.columns:
        sources = sorted(df["report_source"].dropna().unique().tolist())
        source_labels = {s: SOURCE_LABELS.get(s, s) for s in sources}
        source_filter = st.multiselect(
            "Report source",
            sources,
            default=sources,
            format_func=lambda s: source_labels.get(s, s),
            key="sources_legacy",
        )
        if source_filter:
            df = df[df["report_source"].isin(source_filter)]

    stats = hero_stats(df)
    _render_hero(meta, stats, weekly=weekly)

    st.caption(f"Showing {len(df)} record(s)")
    view_mode = st.radio(
        "View charts as",
        ["Chart", "Table", "Both"],
        horizontal=True,
        key="view_legacy",
    )

    sub_over, sub_trend, sub_env, sub_data, sub_upload = st.tabs(
        ["Overview", "Trends", "By environment", "Data", "Upload"]
    )

    with sub_over:
        if weekly:
            _render_weekly_overview(df, view_mode)
        else:
            _render_legacy_overview(df, view_mode)

    with sub_trend:
        if view_mode == "Table":
            st.info("Select Chart or Both to view trends.")
        elif weekly:
            metric_keys = [k for k, _ in WEEKLY_METRICS]
            metric = st.selectbox(
                "Metric",
                metric_keys,
                format_func=lambda k: dict(WEEKLY_METRICS).get(k, k),
                key="metric_legacy_weekly",
            )
            _chart_weekly_metric(df, metric)
        else:
            metric = st.selectbox(
                "Metric",
                list(LEGACY_METRICS),
                format_func=lambda x: x.replace("_", " ").title(),
                key="metric_legacy",
            )
            show_all = st.checkbox(
                "Show all systems (top 12 if unchecked)",
                value=True,
                key="all_legacy",
            )
            _chart_multi_year_lines(df, metric, show_all)

    with sub_env:
        if view_mode == "Table":
            st.info("Select Chart or Both for environment charts.")
        elif weekly:
            _chart_m2_vs_sa(df)
        else:
            _chart_by_report_source(df)

    with sub_data:
        if view_mode == "Chart":
            st.info("Select Table or Both to view raw data.")
        elif weekly:
            _render_weekly_data_table(df)
        else:
            _render_data_table(df)

    with sub_upload:
        _render_upload_section(expanded=stale, weekly=weekly)


def _render_upload_section(*, expanded: bool, weekly: bool) -> None:
    label = "Upload latest AEM scan report (CSV)" if expanded else "Upload new AEM scan report (CSV)"
    with st.expander(label, expanded=expanded):
        st.caption(
            "Upload **AEM Gov AU Vulnerability Scanning Report** CSV files "
            "(weekly M2-Prod / Cust SA / container metrics)."
        )
        st.caption(
            "Container vul count maps to **EKS_AEMGovAU_PROD_Cluster** in Container Vulnerabilities."
        )
        uploaded = st.file_uploader("CSV file", type=["csv"], key="legacy_csv_upload")
        if not weekly:
            st.radio(
                "Report source (per-system Splunk CSV only)",
                options=["m2_prod", "cust_sa_acct"],
                format_func=lambda k: SOURCE_LABELS.get(k, k),
                horizontal=True,
                key="legacy_report_source",
            )
        if st.button("Process upload", type="primary", key="legacy_process_upload"):
            if uploaded is None:
                st.error("Select a CSV file first.")
                return
            raw = uploaded.getvalue()
            if is_aem_report_bytes(raw) or weekly:
                rows, errors = parse_aem_report_bytes(raw, source_file=uploaded.name)
                report_source = "aem_weekly"
            else:
                report_source = st.session_state.get("legacy_report_source", "m2_prod")
                rows, errors = parse_csv_bytes(raw)
            if errors:
                for err in errors[:10]:
                    st.error(err)
                if len(errors) > 10:
                    st.caption(f"… and {len(errors) - 10} more errors")
                return
            ok, msg = ingest_upload(raw, uploaded.name, report_source, rows)
            if ok:
                st.success(msg)
                st.session_state.pop("df_server_vuln_legacy", None)
                st.rerun()
            else:
                st.warning(msg)

        st.markdown("**Processed files**")
        ledger = load_ledger().get("uploads", [])
        if ledger:
            st.dataframe(pd.DataFrame(ledger), use_container_width=True, hide_index=True)
        else:
            st.caption("No uploads processed yet.")

        store_meta = load_store_meta()
        if store_meta:
            st.caption(
                f"Store: {store_meta.get('record_count', 0)} records · "
                f"schema v{store_meta.get('schema_version', 1)} · "
                f"last data date: {store_meta.get('last_data_date', '—')}"
            )


def _render_hero(meta: dict, stats: dict, *, weekly: bool) -> None:
    st.markdown(f'<div class="hero-title">{meta["title"]}</div>', unsafe_allow_html=True)
    if not stats:
        st.caption("No data loaded.")
        return
    latest = stats.get("latest")
    latest_lbl = latest.strftime("%d %b %Y") if latest is not None and pd.notna(latest) else "—"
    if weekly:
        c1, c2, c3, c4, c5 = st.columns(5)
        c1.metric("Latest week", latest_lbl)
        c2.metric("M2 TTV", _fmt_num(stats.get("m2_ttv")))
        c3.metric("SA TTV", _fmt_num(stats.get("sa_ttv")))
        cv = stats.get("container_vul_count")
        c4.metric("Container vul count", _fmt_num(cv) if pd.notna(cv) else "—")
        c5.metric("Snapshots", f"{int(stats.get('snapshots', 0)):,}")
        st.caption(
            f"M2 servers: {_fmt_num(stats.get('m2_servers'))} · "
            f"SA servers: {_fmt_num(stats.get('sa_servers'))} · "
            f"Year: {stats.get('latest_year', '—')}"
        )
        return

    yr = stats.get("latest_year", "—")
    c1, c2, c3, c4, c5 = st.columns(5)
    c1.metric("Latest snapshot", latest_lbl)
    c2.metric("Latest year", str(yr))
    c3.metric(f"Total {meta['vulnWord']}", f"{int(stats.get('total', 0)):,}")
    c4.metric("Critical", f"{int(stats.get('critical', 0)):,}")
    c5.metric("Systems", f"{int(stats.get('systems', 0)):,}")


def _fmt_num(val) -> str:
    if val is None or (isinstance(val, float) and pd.isna(val)):
        return "—"
    try:
        f = float(val)
        if f == int(f):
            return f"{int(f):,}"
        return f"{f:,.2f}"
    except (TypeError, ValueError):
        return str(val)


def _render_weekly_overview(df: pd.DataFrame, view_mode: str) -> None:
    if view_mode in ("Chart", "Both"):
        _chart_weekly_ttv_trend(df)
        if "container_vul_count" in df.columns and df["container_vul_count"].notna().any():
            _chart_weekly_metric(df, "container_vul_count")
        _chart_weekly_servers(df)
    if view_mode in ("Table", "Both") and not df.empty:
        st.markdown("**Latest year summary (avg TTV)**")
        sub = latest_year_df(df)
        if not sub.empty:
            summary = pd.DataFrame(
                {
                    "Metric": ["M2 TTV (avg)", "SA TTV (avg)", "Container vul (avg)"],
                    "Value": [
                        sub["m2_ttv"].mean() if "m2_ttv" in sub.columns else None,
                        sub["sa_ttv"].mean() if "sa_ttv" in sub.columns else None,
                        sub["container_vul_count"].mean()
                        if "container_vul_count" in sub.columns
                        else None,
                    ],
                }
            )
            st.dataframe(summary, use_container_width=True, hide_index=True)


def _render_legacy_overview(df: pd.DataFrame, view_mode: str) -> None:
    if view_mode in ("Chart", "Both"):
        _chart_severity_latest_year(df)
        _chart_top_systems(df)
        _chart_total_by_year(df)
    if view_mode in ("Table", "Both") and not df.empty:
        st.markdown("**Severity totals (latest year)**")
        st.dataframe(_severity_table(df), use_container_width=True)


def _chart_weekly_ttv_trend(df: pd.DataFrame) -> None:
    if df.empty or "scan_date" not in df.columns:
        st.caption("No data.")
        return
    sub = df.sort_values("scan_date")
    fig = go.Figure()
    if "m2_ttv" in sub.columns:
        fig.add_trace(
            go.Scatter(
                x=sub["scan_date"],
                y=sub["m2_ttv"],
                mode="lines+markers",
                name="M2 TTV",
                line=dict(color="#059669", width=2),
            )
        )
    if "sa_ttv" in sub.columns:
        fig.add_trace(
            go.Scatter(
                x=sub["scan_date"],
                y=sub["sa_ttv"],
                mode="lines+markers",
                name="SA TTV",
                line=dict(color="#2563eb", width=2),
            )
        )
    fig.update_layout(
        title="M2 vs SA total vulnerabilities (weekly)",
        height=380,
        xaxis_title="Week",
        yaxis_title="TTV",
        **PLOTLY_LAYOUT,
    )
    st.plotly_chart(fig, use_container_width=True)


def _chart_weekly_metric(df: pd.DataFrame, metric: str) -> None:
    if df.empty or metric not in df.columns:
        st.caption("No data.")
        return
    sub = df.sort_values("scan_date")
    if not sub[metric].notna().any():
        st.caption(f"No values for {metric}.")
        return
    label = dict(WEEKLY_METRICS).get(metric, metric.replace("_", " ").title())
    fig = go.Figure(
        go.Scatter(
            x=sub["scan_date"],
            y=sub[metric],
            mode="lines+markers",
            line=dict(color="#059669", width=2),
            name=label,
        )
    )
    title = label
    if metric == "container_vul_count":
        title += " (EKS_AEMGovAU_PROD_Cluster)"
    fig.update_layout(title=title, height=360, xaxis_title="Week", **PLOTLY_LAYOUT)
    st.plotly_chart(fig, use_container_width=True)


def _chart_weekly_servers(df: pd.DataFrame) -> None:
    if df.empty:
        return
    sub = df.sort_values("scan_date")
    fig = go.Figure()
    if "m2_servers" in sub.columns:
        fig.add_trace(
            go.Scatter(
                x=sub["scan_date"],
                y=sub["m2_servers"],
                mode="lines+markers",
                name="M2 servers",
                line=dict(color="#047857", width=2),
            )
        )
    if "sa_servers" in sub.columns:
        fig.add_trace(
            go.Scatter(
                x=sub["scan_date"],
                y=sub["sa_servers"],
                mode="lines+markers",
                name="SA servers",
                line=dict(color="#7c3aed", width=2),
            )
        )
    fig.update_layout(title="Server counts (weekly)", height=320, **PLOTLY_LAYOUT)
    st.plotly_chart(fig, use_container_width=True)


def _chart_m2_vs_sa(df: pd.DataFrame) -> None:
    if df.empty:
        st.caption("No data.")
        return
    sub = latest_year_df(df).sort_values("scan_date")
    if sub.empty:
        sub = df.sort_values("scan_date")
    fig = go.Figure()
    for col, name, color in (
        ("m2_per_server", "M2 per server", "#059669"),
        ("sa_per_server", "SA per server", "#2563eb"),
    ):
        if col in sub.columns and sub[col].notna().any():
            fig.add_trace(
                go.Scatter(
                    x=sub["scan_date"],
                    y=sub[col],
                    mode="lines+markers",
                    name=name,
                    line=dict(color=color, width=2),
                )
            )
    fig.update_layout(
        title="Per-server vulnerability ratio (latest year)",
        height=360,
        xaxis_title="Week",
        **PLOTLY_LAYOUT,
    )
    st.plotly_chart(fig, use_container_width=True)


def _render_weekly_data_table(df: pd.DataFrame) -> None:
    if df.empty:
        st.caption("No data.")
        return
    display = df.sort_values("scan_date", ascending=False).copy()
    cols = [c for c, _ in weekly_display_columns() if c in display.columns]
    out = display[cols].rename(columns=dict(weekly_display_columns()))
    if "Week" in out.columns:
        out["Week"] = pd.to_datetime(out["Week"], errors="coerce").dt.strftime("%Y-%m-%d")
    st.dataframe(out, use_container_width=True, height=400)


def _severity_table(df: pd.DataFrame) -> pd.DataFrame:
    sub = latest_year_df(df)
    sev = sum_severity(sub)
    return pd.DataFrame(
        {
            "Severity": ["Critical", "High", "Medium", "Low", "Total"],
            "Count": [sev["critical"], sev["high"], sev["medium"], sev["low"], sev["total"]],
        }
    )


def _chart_severity_latest_year(df: pd.DataFrame) -> None:
    sub = latest_year_df(df)
    if sub.empty:
        st.caption("No data.")
        return
    sev = sum_severity(sub)
    labels = ["Critical", "High", "Medium", "Low"]
    keys = ["critical", "high", "medium", "low"]
    values = [sev[k] for k in keys]
    fig = go.Figure(
        go.Bar(
            x=labels,
            y=values,
            marker_color=[SEVERITY_COLORS[k] for k in keys],
            text=[f"{v:,}" for v in values],
            textposition="outside",
        )
    )
    title_year = int(sub["year"].max()) if sub["year"].notna().any() else ""
    fig.update_layout(title=f"Severity breakdown ({title_year})", height=320, **PLOTLY_LAYOUT)
    fig.update_yaxes(rangemode="tozero")
    st.plotly_chart(fig, use_container_width=True)


def _chart_top_systems(df: pd.DataFrame, limit: int = 15) -> None:
    sub = latest_year_df(df)
    if sub.empty:
        return
    totals = (
        sub.groupby("system_name", as_index=False)["total"]
        .sum()
        .sort_values("total", ascending=False)
        .head(limit)
    )
    if totals.empty:
        st.caption("No systems to chart.")
        return
    fig = go.Figure(
        go.Bar(
            x=totals["total"],
            y=totals["system_name"],
            orientation="h",
            marker_color="#059669",
        )
    )
    fig.update_layout(title=f"Top {limit} systems (latest year)", height=420, **PLOTLY_LAYOUT)
    st.plotly_chart(fig, use_container_width=True)


def _chart_total_by_year(df: pd.DataFrame) -> None:
    if df.empty:
        return
    by_year = df.groupby("year", as_index=False)["total"].sum().sort_values("year")
    fig = go.Figure(go.Bar(x=by_year["year"], y=by_year["total"], marker_color="#059669"))
    fig.update_layout(title="Total vulnerabilities by year", height=320, **PLOTLY_LAYOUT)
    st.plotly_chart(fig, use_container_width=True)


def _chart_multi_year_lines(df: pd.DataFrame, metric: str, show_all: bool) -> None:
    if df.empty:
        st.caption("No data.")
        return
    pivot = df.groupby(["system_name", "year"], as_index=False)[metric].sum()
    if pivot.empty:
        st.caption("No series to plot.")
        return

    ranked = pivot.groupby("system_name")[metric].sum().sort_values(ascending=False).index.tolist()
    if not show_all:
        ranked = ranked[:12]

    palette = ["#059669", "#2563eb", "#d97706", "#7c3aed", "#db2777", "#0891b2"]
    fig = go.Figure()
    years_sorted = sorted(pivot["year"].dropna().unique())
    for i, name in enumerate(ranked):
        sub = pivot[pivot["system_name"] == name].sort_values("year")
        fig.add_trace(
            go.Scatter(
                x=sub["year"],
                y=sub[metric],
                mode="lines+markers",
                name=name,
                line=dict(color=palette[i % len(palette)], width=2),
            )
        )
    fig.update_layout(
        title=f"{metric.replace('_', ' ').title()} by year (per system)",
        height=420,
        xaxis_title="Year",
        yaxis_title=metric.replace("_", " ").title(),
        xaxis=dict(tickmode="linear", dtick=1),
        **PLOTLY_LAYOUT,
    )
    fig.update_xaxes(type="category", categoryorder="array", categoryarray=[str(int(y)) for y in years_sorted])
    st.plotly_chart(fig, use_container_width=True)


def _chart_by_report_source(df: pd.DataFrame) -> None:
    if df.empty or "report_source" not in df.columns:
        st.caption("No data.")
        return
    sub = latest_year_df(df)
    by_src: dict[str, dict[str, int]] = {}
    for _, row in sub.iterrows():
        src = SOURCE_LABELS.get(str(row["report_source"]), str(row["report_source"]))
        if src not in by_src:
            by_src[src] = {"critical": 0, "high": 0, "medium": 0, "low": 0}
        for sev in ("critical", "high", "medium", "low"):
            by_src[src][sev] += int(row.get(sev, 0))
    sources = sorted(by_src.keys())
    fig = go.Figure()
    for sev in ("critical", "high", "medium", "low"):
        fig.add_trace(
            go.Bar(
                name=sev.capitalize(),
                x=sources,
                y=[by_src[s][sev] for s in sources],
                marker_color=SEVERITY_COLORS[sev],
            )
        )
    fig.update_layout(
        title="Severity by report source (latest year)",
        barmode="stack",
        height=420,
        **PLOTLY_LAYOUT,
    )
    st.plotly_chart(fig, use_container_width=True)


def _render_data_table(df: pd.DataFrame) -> None:
    if df.empty:
        st.caption("No data.")
        return
    display = df.copy()
    if "scan_date" in display.columns:
        display["scan_date"] = pd.to_datetime(display["scan_date"], errors="coerce")
    if "report_source" in display.columns:
        display["report_source"] = display["report_source"].map(lambda s: SOURCE_LABELS.get(s, s))
    st.dataframe(display, use_container_width=True, height=400)
