# Concept: Mukesh Kesharwani
# Contact: mukesh.kesharwani@adobe.com

"""Generate placeholder multi-year server vulnerability data until real Splunk CSVs arrive."""

from __future__ import annotations

import random
from datetime import date
from typing import Any

SYSTEMS = [
    "ams-prod-dispatcher-01",
    "ams-prod-author-02",
    "ams-prod-publish-03",
    "ams-prod-gateway-04",
    "ams-m2-prod-core-05",
    "ams-m2-prod-api-06",
    "ams-cust-sa-web-07",
    "ams-cust-sa-batch-08",
    "ams-govcloud-lb-09",
    "ams-govcloud-db-10",
    "ams-splunk-fwd-11",
    "ams-splunk-idx-12",
    "ams-legacy-mon-13",
    "ams-legacy-app-14",
    "ams-legacy-cache-15",
]

YEARS = [2024, 2025, 2026]
# Latest scan in seed is old enough to show 7-day upload prompt (relative to typical use).
SCAN_DATES = {
    2024: date(2024, 6, 15),
    2025: date(2025, 6, 15),
    2026: date(2026, 4, 1),
}


def generate_mock_rows() -> list[dict[str, Any]]:
    random.seed(42)
    rows: list[dict[str, Any]] = []
    for system in SYSTEMS:
        base = random.randint(8, 40)
        for year in YEARS:
            growth = (year - 2024) * random.randint(-2, 5)
            critical = max(0, random.randint(0, 3) + (1 if year == 2026 else 0))
            high = max(0, int(base * 0.35) + growth)
            medium = max(0, int(base * 0.4) + growth // 2)
            low = max(0, int(base * 0.25))
            total = critical + high + medium + low
            source = "m2_prod" if "m2" in system or "prod" in system else "cust_sa_acct"
            if random.random() > 0.7:
                source = "cust_sa_acct"
            rows.append(
                {
                    "system_name": system,
                    "year": year,
                    "scan_date": SCAN_DATES[year].isoformat(),
                    "report_source": source,
                    "critical": critical,
                    "high": high,
                    "medium": medium,
                    "low": low,
                    "total": total,
                    "upload_id": "mock-seed",
                }
            )
    return rows
