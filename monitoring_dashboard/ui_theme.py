# Concept: Mukesh Kesharwani
# Contact: mukesh.kesharwani@adobe.com

"""Streamlit CSS — green accent aligned with stocks/OSCAL settings UI."""

from __future__ import annotations

import streamlit as st

PLOTLY_LAYOUT = dict(
    template="plotly_white",
    margin=dict(l=50, r=24, t=48, b=60),
    paper_bgcolor="#fff",
    plot_bgcolor="#fafafa",
    legend=dict(orientation="h", yanchor="bottom", y=1.02, x=0),
)

_MAIN_NAV_KEY = "main_dashboard_nav"

# (background, border, text) per main section
_MAIN_NAV_PALETTE = (
    ("#e0e7ff", "#4f46e5", "#312e81"),
    ("#d1fae5", "#059669", "#064e3b"),
    ("#ffedd5", "#ea580c", "#7c2d12"),
    ("#ede9fe", "#7c3aed", "#4c1d95"),
)

_SUB_TAB_PALETTE = (
    ("#f1f5f9", "#64748b", "#1e293b"),
    ("#ecfdf5", "#34d399", "#065f46"),
    ("#fffbeb", "#fbbf24", "#92400e"),
    ("#f5f3ff", "#a78bfa", "#5b21b6"),
    ("#fdf2f8", "#f472b6", "#9d174d"),
)

_SCSS = """
<style>
div[data-testid="stMetricValue"] { font-variant-numeric: tabular-nums; }
.settings-header { color: #047857; font-weight: 600; }
.hero-box {
  border: 1px solid #e2e8f0;
  border-radius: 10px;
  padding: 1rem 1.25rem;
  background: #fff;
  margin-bottom: 1rem;
}
.hero-title { font-size: 1.2rem; font-weight: 700; color: #047857; }
.hero-caption { font-size: 0.85rem; color: #64748b; }
</style>
"""


def _palette_css(selector: str, palette: tuple[tuple[str, str, str], ...], *, selected_border: str) -> str:
    """Build nth-child rules for tab or radio labels."""
    lines: list[str] = []
    for i, (bg, border, text) in enumerate(palette, start=1):
        lines.append(
            f"""
{selector}:nth-child({i}) {{
  background-color: {bg} !important;
  color: {text} !important;
  border: 2px solid {border} !important;
  border-radius: 8px !important;
  padding: 0.55rem 1rem !important;
  font-weight: 600 !important;
  margin: 0 !important;
}}
{selector}:nth-child({i}):has(input:checked),
{selector}:nth-child({i})[aria-selected="true"] {{
  {selected_border}: 4px solid {border} !important;
  box-shadow: 0 2px 8px rgba(15, 23, 42, 0.12) !important;
}}
"""
        )
    return "\n".join(lines)


def _multi_selector_palette(selectors: list[str], palette: tuple[tuple[str, str, str], ...], *, selected_border: str) -> str:
    return "".join(_palette_css(sel, palette, selected_border=selected_border) for sel in selectors)


def inject_main_nav_styles() -> None:
    """Coloured main sections — st.radio with key main_dashboard_nav (st-key-* class)."""
    group = f".st-key-{_MAIN_NAV_KEY}"
    label_selectors = [
        f"{group} [data-baseweb='radio'] label",
        f"{group} [role='radiogroup'] > label",
        f"{group} div[data-testid='stRadio'] label",
    ]
    css = (
        "<style>"
        f"{group} [data-baseweb='radio'] > div, {group} [role='radiogroup'] {{"
        "gap: 0.5rem !important; flex-wrap: wrap !important;"
        "}"
        + _multi_selector_palette(label_selectors, _MAIN_NAV_PALETTE, selected_border="border-bottom")
        + "</style>"
    )
    st.markdown(css, unsafe_allow_html=True)


def inject_subtab_styles() -> None:
    """Coloured inner tabs (Overview / Trends / …) — Streamlit .stTabs + baseweb."""
    tab_selectors = [
        ".stTabs [data-baseweb='tab-list'] [data-baseweb='tab']",
        "div[data-testid='stTabs'] [data-baseweb='tab-list'] [data-baseweb='tab']",
        "div[data-testid='stTabs'] button[role='tab']",
    ]
    css = (
        "<style>"
        ".stTabs [data-baseweb='tab-list'], div[data-testid='stTabs'] [data-baseweb='tab-list'] {"
        "gap: 0.35rem !important; flex-wrap: wrap !important;"
        "}"
        ".stTabs [data-baseweb='tab-highlight'], div[data-testid='stTabs'] [data-baseweb='tab-highlight'] {"
        "background-color: transparent !important; height: 0 !important;"
        "}"
        + _multi_selector_palette(tab_selectors, _SUB_TAB_PALETTE, selected_border="border-top")
        + "</style>"
    )
    st.markdown(css, unsafe_allow_html=True)


def inject_theme() -> None:
    st.markdown(_SCSS, unsafe_allow_html=True)
    inject_subtab_styles()
