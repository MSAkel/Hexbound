"""Shared loading and parsing for playtest_runner reports."""

import json
import os
import re

PROJECT_ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", ".."))
REPORT_NAME = "playtest_report.json"
# full_nine is the pre-overhaul bot's suite, kept so old baselines still compare.
BOT_SUITES = ("run", "power", "fuzz", "full_nine")


def project_name() -> str:
    with open(os.path.join(PROJECT_ROOT, "project.godot"), encoding="utf-8") as handle:
        match = re.search(r'^config/name="([^"]+)"', handle.read(), re.M)
    return match.group(1) if match else ""


def default_report_path() -> str:
    """The runner's default user:// report for this project on this machine."""
    appdata = os.environ.get("APPDATA") or os.path.expanduser("~/.local/share")
    return os.path.join(appdata, "Godot", "app_userdata", project_name(), REPORT_NAME)


def load_report(path: str | None = None) -> dict:
    with open(path or default_report_path(), encoding="utf-8") as handle:
        return json.load(handle)


def bot_cases(report: dict, suite: str | None = None) -> list[dict]:
    """Full-run cases, optionally from one suite."""
    return [
        case
        for case in report.get("cases", [])
        if case.get("suite") in BOT_SUITES and (suite is None or case.get("suite") == suite)
    ]


def parse_buy(entry: str) -> tuple[str, str]:
    """'4:apple@4' -> ('card', 'apple'), '4:staff:runner@9' -> ('staff', 'runner')."""
    parts = entry.split("@", 1)[0].split(":")
    if len(parts) == 3:
        return parts[1], parts[2]
    return "card", parts[-1]


def picked_card_ids(details: dict) -> list[str]:
    """Cards drafted from offers and bought from the merchant, in order."""
    ids = [entry.split(":", 1)[-1] for entry in details.get("picks", [])]
    for entry in details.get("buys", []):
        kind, item_id = parse_buy(entry)
        if kind == "card":
            ids.append(item_id)
    return ids


def card_pool() -> set[str]:
    pool: set[str] = set()
    for root, _, files in os.walk(os.path.join(PROJECT_ROOT, "resources", "cards")):
        for name in files:
            if not name.endswith(".tres"):
                continue
            with open(os.path.join(root, name), encoding="utf-8", errors="ignore") as handle:
                match = re.search(r'^id\s*=\s*"([^"]+)"', handle.read(), re.M)
            if match:
                pool.add(match.group(1))
    return pool
