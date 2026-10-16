#!/usr/bin/env python3
"""Compare two playtest_runner reports, for example before and after a balance change.

usage: compare_playtest_reports.py base.json new.json [--suite=run|power]

Per chef: win rate, average day reached, final gold, and average score / goal for each day.
In --power reports every day plays out in full, so score / goal is the cleanest power measure.
Then the cards whose take rate moved most.
"""

import sys
from collections import Counter, defaultdict

from playtest_report import bot_cases, load_report, picked_card_ids

RUN_LENGTH = 9


def summarize(cases: list[dict]) -> dict[str, dict]:
    chefs: dict[str, dict] = {}
    for case in cases:
        chef = case.get("chef", "?")
        details = case.get("details", {})
        row = chefs.setdefault(chef, {
            "runs": 0, "wins": 0, "reached": 0, "gold": 0,
            "ratio_sum": defaultdict(float), "ratio_count": Counter(),
            "takes": Counter(),
        })
        row["runs"] += 1
        row["wins"] += bool(details.get("won"))
        row["reached"] += int(details.get("reached_round", 0))
        row["gold"] += int(details.get("gold", 0))
        for day in details.get("days", []):
            goal = max(1, int(day.get("goal", 1)))
            row["ratio_sum"][int(day["round"])] += float(day.get("score", 0)) / goal
            row["ratio_count"][int(day["round"])] += 1
        row["takes"].update(set(picked_card_ids(details)))
    return chefs


def ratio(row: dict, day: int) -> float | None:
    count = row["ratio_count"][day]
    return row["ratio_sum"][day] / count if count else None


def fmt(value: float | None) -> str:
    return "-" if value is None else f"{value:.2f}"


def main() -> None:
    args = [arg for arg in sys.argv[1:] if not arg.startswith("--")]
    suite = next((arg.split("=", 1)[1] for arg in sys.argv[1:] if arg.startswith("--suite=")), None)
    if len(args) != 2:
        print(__doc__)
        sys.exit(2)
    base = summarize(bot_cases(load_report(args[0]), suite))
    new = summarize(bot_cases(load_report(args[1]), suite))

    for chef in sorted(set(base) | set(new)):
        old_row, new_row = base.get(chef), new.get(chef)
        print(f"\n== {chef}")
        if old_row is None or new_row is None:
            print("  only in one report")
            continue
        for label, key in (("win %", "wins"), ("avg day", "reached"), ("gold", "gold")):
            old_value = old_row[key] / old_row["runs"] * (100 if key == "wins" else 1)
            new_value = new_row[key] / new_row["runs"] * (100 if key == "wins" else 1)
            print(f"  {label:8} {old_value:8.1f} -> {new_value:8.1f}  ({new_value - old_value:+.1f})")
        print("  score/goal by day")
        for day in range(1, RUN_LENGTH + 1):
            old_ratio, new_ratio = ratio(old_row, day), ratio(new_row, day)
            if old_ratio is None and new_ratio is None:
                continue
            line = f"    day {day}: {fmt(old_ratio):>6} -> {fmt(new_ratio):>6}"
            if old_ratio is not None and new_ratio is not None:
                line += f"  ({new_ratio - old_ratio:+.2f})"
            print(line)
        moves = []
        for card_id in set(old_row["takes"]) | set(new_row["takes"]):
            old_rate = old_row["takes"][card_id] / old_row["runs"]
            new_rate = new_row["takes"][card_id] / new_row["runs"]
            moves.append((new_rate - old_rate, card_id, old_rate, new_rate))
        moves.sort(key=lambda move: abs(move[0]), reverse=True)
        print("  biggest take-rate changes (share of runs)")
        for delta, card_id, old_rate, new_rate in moves[:8]:
            print(f"    {card_id:24} {100 * old_rate:4.0f}% -> {100 * new_rate:4.0f}%  ({100 * delta:+.0f})")


if __name__ == "__main__":
    main()
