#!/usr/bin/env python3
# Concept: Mukesh Kesharwani
# Contact: mukesh.kesharwani@adobe.com
"""
Import Splunk Nexpose CSV exports (M2-Prod / Cust SA Acct) into weekly_metrics.jsonl.

Merges M2 and SA counts into the matching weekly snapshot (by export filename date).
Preserves existing container/EKS fields on that week when present.

Usage:
  python3 scripts/import_splunk_scan_reports.py \\
    ~/Downloads/AMSGovCloud_M2-Prod-2026-05-07.csv \\
    ~/Downloads/AMSGovCloud_Cust_SA_Acct-2026-05-07.csv

See docs/AEM_GOVAU_LEGACY_DASHBOARD.md (release 1.0.11).
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))

from monitoring_dashboard.server_vuln_legacy.splunk_report_parser import (  # noqa: E402
    build_weekly_snapshot_from_splunk_partials,
    parse_splunk_nexpose_bytes,
)
from monitoring_dashboard.server_vuln_legacy.store import (  # noqa: E402
    LEGACY_DIR,
    WEEKLY_METRICS_FILE,
    _read_jsonl,
    _utc_now_iso,
    ensure_dir,
    file_sha256,
    load_ledger,
    merge_weekly_into_store,
    refresh_meta_from_metrics,
    save_ledger,
    save_store_meta,
)


def main() -> int:
    parser = argparse.ArgumentParser(description="Import Splunk Nexpose scan CSVs")
    parser.add_argument("csv_files", nargs="+", type=Path, help="Splunk export CSV paths")
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Parse and print summary only; do not write weekly_metrics.jsonl",
    )
    args = parser.parse_args()

    partials: list[dict] = []
    source_names: list[str] = []
    errors: list[str] = []

    for path in sorted(args.csv_files, key=lambda p: p.name):
        if not path.is_file():
            print(f"ERROR: not found: {path}", file=sys.stderr)
            return 1
        data = path.read_bytes()
        partial, parse_errors = parse_splunk_nexpose_bytes(data, filename=path.name)
        errors.extend(parse_errors)
        if partial is None:
            print(f"  {path.name}: FAILED", file=sys.stderr)
            continue
        partials.append(partial)
        source_names.append(path.name)
        print(
            f"  {path.name}: {partial['environment'].upper()} week {partial['scan_date']} — "
            f"{partial['servers']} servers, {int(partial['ttv'])} TTV"
        )

    if not partials:
        print("ERROR: no Splunk files parsed", file=sys.stderr)
        for err in errors[:10]:
            print(f"  {err}", file=sys.stderr)
        return 1

    upload_id = file_sha256("|".join(source_names).encode("utf-8"))
    row = build_weekly_snapshot_from_splunk_partials(
        partials,
        upload_id=upload_id,
        source_files=source_names,
    )
    if row is None:
        print("ERROR: could not build weekly row (mixed scan weeks?)", file=sys.stderr)
        return 1

    print(f"\nMerged weekly snapshot for {row['scan_date']}:")
    for key in ("m2_servers", "m2_ttv", "m2_per_server", "sa_servers", "sa_ttv", "sa_per_server"):
        if row.get(key) is not None:
            print(f"  {key}: {row[key]}")

    if args.dry_run:
        for err in errors:
            print(f"NOTE: {err}")
        return 0

    ensure_dir()
    existing = _read_jsonl(WEEKLY_METRICS_FILE)
    scan_key = str(row["scan_date"])[:10]
    prior = next((r for r in existing if str(r.get("scan_date", ""))[:10] == scan_key), None)
    if prior:
        from monitoring_dashboard.server_vuln_legacy.splunk_report_parser import (
            merge_splunk_partial_into_weekly_row,
        )

        merged = prior
        for partial in partials:
            merged = merge_splunk_partial_into_weekly_row(
                merged, partial, upload_id=upload_id, filename=partial.get("source_file") or ""
            )
        row = merged

    added = merge_weekly_into_store([row])
    ledger = load_ledger()
    ledger.setdefault("uploads", []).append(
        {
            "file_sha256": upload_id,
            "original_filename": ", ".join(source_names),
            "processed_at": _utc_now_iso(),
            "report_source": "splunk_cli",
            "rows_added": 1,
            "scan_date_max": scan_key,
        }
    )
    save_ledger(ledger)
    meta = refresh_meta_from_metrics()
    meta["last_upload_at"] = _utc_now_iso()
    save_store_meta(meta)

    print(f"\nWrote {WEEKLY_METRICS_FILE.relative_to(ROOT)} (net weekly rows changed: {added})")
    for err in errors:
        print(f"NOTE: {err}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
