# Concept: Mukesh Kesharwani
# Contact: mukesh.kesharwani@adobe.com

"""Page footer — build version and attribution (aligned with Stocks dashboard)."""

from __future__ import annotations

import streamlit as st

from monitoring_dashboard.app_meta import ATTRIBUTION_LINE
from monitoring_dashboard.version_info import footer_markdown, get_version_info

_FOOTER_CSS = """
<style>
.md-page-footer {
  text-align: center;
  margin: 0.25rem 0 0.5rem 0;
}
.md-page-footer [data-testid="stMarkdownContainer"] p {
  font-size: 0.8rem;
  line-height: 1.35;
  color: #64748b;
  margin: 0;
}
.md-page-footer a { color: #059669; }
</style>
"""


def render_page_footer(*, build_line: str | None = None) -> None:
    """Page footer: build version, GitHub commit link, and attribution."""
    st.markdown(_FOOTER_CSS, unsafe_allow_html=True)
    st.markdown("---")
    line = build_line or footer_markdown(get_version_info())
    st.markdown('<div class="md-page-footer">', unsafe_allow_html=True)
    st.markdown(f"**Build:** {line}")
    st.caption(ATTRIBUTION_LINE)
    st.markdown(" ", unsafe_allow_html=True)
