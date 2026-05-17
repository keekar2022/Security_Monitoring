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


def inject_theme() -> None:
    st.markdown(_SCSS, unsafe_allow_html=True)
