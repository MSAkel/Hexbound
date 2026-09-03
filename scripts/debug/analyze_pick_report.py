#!/usr/bin/env python3
"""Summarize player-bot picks and buys from playtest_report.json (spot_cards pool)."""

import json
import re
import os
import sys
from collections import Counter, defaultdict

REPORT = os.path.expandvars(
    r"C:\Users\16138\AppData\Roaming\Godot\app_userdata\6 Aklatros\playtest_report.json"
)
POOL_DIR = os.path.join(os.path.dirname(__file__), "..", "..", "resources", "spot_cards")


def load_pool() -> set[str]:
    pool: set[str] = set()
    for root, _, files in os.walk(POOL_DIR):
        for name in files:
            if not name.endswith(".tres"):
                continue
            path = os.path.join(root, name)
            with open(path, encoding="utf-8", errors="ignore") as handle:
                text = handle.read()
            match = re.search(r'^id\s*=\s*"([^"]+)"', text, re.M)
            if match:
                pool.add(match.group(1))
    return pool


def main() -> None:
    report_path = sys.argv[1] if len(sys.argv) > 1 else REPORT
    pool = load_pool()
    with open(report_path, encoding="utf-8") as handle:
        data = json.load(handle)

    pick_counts: Counter[str] = Counter()
    buy_counts: Counter[str] = Counter()
    runs_with: Counter[str] = Counter()
    layout_pick: dict[str, Counter[str]] = defaultdict(Counter)
    layout_runs: Counter[str] = Counter()
    total_runs = 0

    for case in data.get("cases", []):
        if case.get("suite") != "full_nine":
            continue
        details = case.get("details", {})
        if details.get("bot") != "player":
            continue
        layout = case.get("character", "?")
        total_runs += 1
        layout_runs[layout] += 1
        seen: set[str] = set()
        for entry in details.get("picks", []):
            card_id = entry.split(":", 1)[-1]
            pick_counts[card_id] += 1
            layout_pick[layout][card_id] += 1
            seen.add(card_id)
        for entry in details.get("buys", []):
            parts = entry.split(":")
            if len(parts) >= 2 and parts[1] == "potion":
                continue
            if len(parts) >= 2 and parts[0].isdigit():
                card_id = parts[1].split("@")[0]
                buy_counts[card_id] += 1
                layout_pick[layout][card_id] += 1
                seen.add(card_id)
        for card_id in seen:
            runs_with[card_id] += 1

    all_picked = set(pick_counts) | set(buy_counts)
    never = sorted(pool - all_picked)
    combined = Counter()
    combined.update(pick_counts)
    combined.update(buy_counts)
    every_run = sorted(card for card in all_picked if runs_with[card] == total_runs)

    print(f"runs={total_runs} pool={len(pool)} picked_unique={len(all_picked)}")
    print("\nNEVER_PICKED")
    print(", ".join(never) if never else "(none)")
    print("\nIN_EVERY_RUN")
    for card_id in every_run:
        print(f"  {card_id}: {combined[card_id]} total, {runs_with[card_id]}/{total_runs} runs")
    print("\nTOP_PICKS")
    for card_id, count in combined.most_common(35):
        pct = 100.0 * runs_with[card_id] / total_runs
        print(f"  {card_id}: {count} total, {runs_with[card_id]}/{total_runs} runs ({pct:.0f}%)")
    print("\nNEVER_BY_LAYOUT")
    for layout in sorted(layout_runs):
        never_layout = sorted(pool - set(layout_pick[layout]))
        print(f"  {layout} ({layout_runs[layout]} runs): {len(never_layout)} never")
        print(f"    {', '.join(never_layout)}")


if __name__ == "__main__":
    main()
