# Concept: Mukesh Kesharwani
# Contact: mukesh.kesharwani@adobe.com

"""Collection schedule policy, due checks, and run metadata for Trend Micro collectors."""

from __future__ import annotations

import argparse
import json
import os
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parent.parent
DEFAULT_POLICY_PATH = ROOT / "config" / "collection_schedule.json"
EXAMPLE_POLICY_PATH = ROOT / "config" / "collection_schedule.json.example"
META_PATH = Path(os.environ.get("DATA_DIR", str(ROOT / "data"))) / "collection_meta.json"
DEPLOYMENT_CONFIG_PATH = ROOT / "config" / "deployment_config.json"

FREQUENCIES = frozenset({"daily", "weekly", "monthly"})
INTERVALS = {"daily": timedelta(days=1), "weekly": timedelta(days=7), "monthly": timedelta(days=30)}


def _utc_now() -> datetime:
    return datetime.now(timezone.utc)


def _parse_iso(value: str) -> datetime | None:
    if not value:
        return None
    try:
        text = value.strip().replace("Z", "+00:00")
        parsed = datetime.fromisoformat(text)
        if parsed.tzinfo is None:
            parsed = parsed.replace(tzinfo=timezone.utc)
        return parsed.astimezone(timezone.utc)
    except ValueError:
        return None


def load_policy() -> dict[str, Any]:
    """Load schedule policy from env override, config file, or example."""
    env_freq = (os.environ.get("COLLECTION_FREQUENCY") or "").strip().lower()
    if env_freq in FREQUENCIES:
        return {
            "enabled": os.environ.get("COLLECTION_ENABLED", "true").lower() not in ("0", "false", "no"),
            "frequency": env_freq,
            "environments": "all_with_credentials",
        }

    for path in (DEFAULT_POLICY_PATH, EXAMPLE_POLICY_PATH):
        if path.is_file():
            try:
                with path.open(encoding="utf-8") as f:
                    data = json.load(f)
                if isinstance(data, dict):
                    return data
            except (json.JSONDecodeError, OSError):
                continue

    return {"enabled": True, "frequency": "daily", "environments": "all_with_credentials"}


def list_credentialed_environments() -> list[str]:
    """Environments defined in deployment_config (collectors resolve tokens via pass/env)."""
    if not DEPLOYMENT_CONFIG_PATH.is_file():
        return []
    try:
        with DEPLOYMENT_CONFIG_PATH.open(encoding="utf-8") as f:
            data = json.load(f)
        envs = data.get("environments")
        if isinstance(envs, dict):
            return sorted(envs.keys())
    except (json.JSONDecodeError, OSError):
        pass
    return []


def get_last_run() -> datetime | None:
    if not META_PATH.is_file():
        return None
    try:
        with META_PATH.open(encoding="utf-8") as f:
            meta = json.load(f)
        if isinstance(meta, dict):
            return _parse_iso(str(meta.get("last_success_at") or ""))
    except (json.JSONDecodeError, OSError):
        return None
    return None


def load_meta() -> dict[str, Any]:
    if not META_PATH.is_file():
        return {}
    try:
        with META_PATH.open(encoding="utf-8") as f:
            data = json.load(f)
        return data if isinstance(data, dict) else {}
    except (json.JSONDecodeError, OSError):
        return {}


def next_due_at(last_run: datetime | None, frequency: str) -> datetime:
    interval = INTERVALS.get(frequency, INTERVALS["daily"])
    base = last_run or datetime.min.replace(tzinfo=timezone.utc)
    return base + interval


def is_collection_due(*, force: bool = False) -> tuple[bool, str]:
    if force:
        return True, "forced run"
    policy = load_policy()
    if not policy.get("enabled", True):
        return False, "collection disabled in policy"
    frequency = str(policy.get("frequency") or "daily").lower()
    if frequency not in FREQUENCIES:
        return False, f"invalid frequency: {frequency}"
    last = get_last_run()
    if last is None:
        return True, "no previous successful collection"
    due_at = next_due_at(last, frequency)
    now = _utc_now()
    if now >= due_at:
        return True, f"due ({frequency}); last run {last.isoformat()}"
    remaining = due_at - now
    return False, f"not due until {due_at.isoformat()} ({remaining} remaining)"


def write_meta_after_success(
    *,
    environments: list[str],
    duration_seconds: float,
    trigger: str,
    frequency: str | None = None,
    failed_environments: list[str] | None = None,
) -> None:
    policy = load_policy()
    meta = {
        "last_success_at": _utc_now().strftime("%Y-%m-%dT%H:%M:%SZ"),
        "frequency": frequency or str(policy.get("frequency") or "daily"),
        "environments": environments,
        "duration_seconds": round(duration_seconds, 2),
        "trigger": trigger,
    }
    if failed_environments:
        meta["failed_environments"] = failed_environments
        meta["partial"] = True
    META_PATH.parent.mkdir(parents=True, exist_ok=True)
    with META_PATH.open("w", encoding="utf-8") as f:
        json.dump(meta, f, indent=2)
        f.write("\n")


def format_status() -> str:
    policy = load_policy()
    last = get_last_run()
    due, reason = is_collection_due()
    freq = policy.get("frequency", "daily")
    lines = [
        f"enabled={policy.get('enabled', True)}",
        f"frequency={freq}",
        f"last_success_at={last.isoformat() if last else 'never'}",
        f"due={due} ({reason})",
        f"environments={', '.join(list_credentialed_environments()) or 'none'}",
    ]
    if last and not due:
        lines.append(f"next_due_at={next_due_at(last, str(freq)).isoformat()}")
    return "\n".join(lines)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Trend Micro collection schedule helper")
    parser.add_argument("--check", action="store_true", help="Exit 0 if due, 2 if skip")
    parser.add_argument("--force", action="store_true", help="Treat collection as due")
    parser.add_argument("--status", action="store_true", help="Print schedule status")
    args = parser.parse_args(argv)

    if args.status:
        print(format_status())
        return 0

    due, reason = is_collection_due(force=args.force)
    if args.check:
        print(reason)
        return 0 if due else 2

    print(format_status())
    return 0 if due else 1


if __name__ == "__main__":
    sys.exit(main())
