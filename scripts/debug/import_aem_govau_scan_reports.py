#!/usr/bin/env python3
# Concept: Mukesh Kesharwani
# Contact: mukesh.kesharwani@adobe.com
"""
Import AEM Gov AU vulnerability scanning CSVs into weekly_metrics.jsonl.

Usage:
  python3 scripts/debug/import_aem_govau_scan_reports.py \\
    ~/Downloads/2022-AEMGovAu-Vulnerability-Scanning-Report.csv \\
    ... \\
    ~/Downloads/2026-AEMGovAu-Vulnerability-Scanning-Report.csv

See docs/USER_GUIDE.md (AEM legacy tab).
"""

from __future__ import annotations

import argparse
import json
import sys
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(ROOT))

from monitoring_dashboard.server_vuln_legacy.aem_report_parser import (  # noqa: E402
    merge_weekly_records,
    parse_aem_report_file,
    predicted_data_cutoff,
    validate_container_counts,
)
from monitoring_dashboard.server_vuln_legacy.store import (  # noqa: E402
    LEGACY_DIR,
    WEEKLY_METRICS_FILE,
    _max_scan_date,
    _utc_now_iso,
    ensure_dir,
    save_ledger,
    save_store_meta,
)

UPLOAD_ID = "import-aem-2022-2026"
CONTAINER_JSONL = ROOT / "data" / "container_vulnerability_metrics.jsonl"


def write_weekly_metrics(rows: list[dict]) -> None:
    ensure_dir()
    with WEEKLY_METRICS_FILE.open("w", encoding="utf-8") as f:
        for row in rows:
            f.write(json.dumps(row, separators=(",", ":")) + "\n")


def main() -> int:
    parser = argparse.ArgumentParser(description="Import AEM Gov AU scan report CSVs")
    parser.add_argument("csv_files", nargs="+", type=Path, help="CSV files (2022–2026)")
    parser.add_argument("--no-validate", action="store_true", help="Skip container JSONL validation")
    args = parser.parse_args()

    paths = sorted(args.csv_files, key=lambda p: p.name)
    file_rows: list[tuple[str, list[dict]]] = []
    all_errors: list[str] = []

    for path in paths:
        if not path.is_file():
            print(f"ERROR: not found: {path}", file=sys.stderr)
            return 1
        rows, errors = parse_aem_report_file(path, upload_id=UPLOAD_ID)
        all_errors.extend(errors)
        file_rows.append((path.name, rows))
        print(f"  {path.name}: {len(rows)} rows")

    merged = merge_weekly_records(file_rows)
    if not merged:
        print("ERROR: no records after merge", file=sys.stderr)
        for e in all_errors[:10]:
            print(f"  {e}", file=sys.stderr)
        return 1

    write_weekly_metrics(merged)

    max_date = _max_scan_date(merged)
    min_date = merged[0]["scan_date"]
    years = Counter(r["year"] for r in merged)
    with_container = sum(1 for r in merged if r.get("container_vul_count") is not None)

    meta = {
        "schema_version": 2,
        "record_type": "weekly_snapshot",
        "mock": False,
        "seeded": False,
        "last_data_date": max_date.isoformat() if max_date else None,
        "first_data_date": min_date,
        "record_count": len(merged),
        "last_upload_at": _utc_now_iso(),
        "import_upload_id": UPLOAD_ID,
        "source_files": [name for name, _ in file_rows],
        "rows_with_container_metrics": with_container,
        "predicted_data_cutoff": predicted_data_cutoff().isoformat(),
    }
    save_store_meta(meta)

    ledger = {
        "uploads": [
            {
                "file_sha256": UPLOAD_ID,
                "original_filename": "bulk-import-2022-2026",
                "processed_at": _utc_now_iso(),
                "report_source": "aem_weekly",
                "rows_added": len(merged),
                "scan_date_max": max_date.isoformat() if max_date else None,
                "source_files": meta["source_files"],
            }
        ]
    }
    save_ledger(ledger)

    if not args.no_validate:
        warnings = validate_container_counts(merged, CONTAINER_JSONL)
        for w in warnings:
            print(f"  WARN: {w}")

    print(f"\nWrote {len(merged)} records -> {WEEKLY_METRICS_FILE}")
    print(f"Date range: {min_date} .. {meta['last_data_date']}")
    print("Rows per year:", dict(sorted(years.items())))
    print(f"Rows with container_vul_count: {with_container}")
    if all_errors:
        print(f"Parser notes ({len(all_errors)}):", all_errors[:5])
    return 0


if __name__ == "__main__":
    sys.exit(main())
