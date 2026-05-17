# Concept: Mukesh Kesharwani
# Contact: mukesh.kesharwani@adobe.com

"""Load JSONL metric files into pandas DataFrames."""

from __future__ import annotations

import json
import os
from pathlib import Path

import pandas as pd

ROOT = Path(__file__).resolve().parent.parent

TAB_FILES = {
    "container": "container_vulnerability_metrics.jsonl",
    "endpointVuln": "endpoint_vulnerability_metrics.jsonl",
    "endpoint": "endpoint_inventory_metrics.jsonl",
}


def data_dir() -> Path:
    return Path(os.environ.get("DATA_DIR", str(ROOT / "data")))


def load_jsonl(data_type: str) -> pd.DataFrame:
    filename = TAB_FILES.get(data_type)
    if not filename:
        return pd.DataFrame()
    path = data_dir() / filename
    if not path.is_file():
        return pd.DataFrame()
    rows: list[dict] = []
    with path.open(encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                rows.append(json.loads(line))
            except json.JSONDecodeError:
                continue
    if not rows:
        return pd.DataFrame()
    return pd.json_normalize(rows) if rows else pd.DataFrame()
