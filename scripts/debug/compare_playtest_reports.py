#!/usr/bin/env python3
"""Compare two playtest_runner reports, for example before and after a balance change.

usage: compare_playtest_reports.py base.json new.json [--suite=run|power]

Per chef: win rate, average day reached, final gold, and average score / goal for each day.
In --power reports every day plays out in full, so score / goal is the cleanest power measure.
Then the cards whose take rate moved most.

Run reports made with --extra-hours also show, per day: Hours used to meet the goal, gold paid for
the unused Hours, and full-day score / goal (the score if the bot had played the unused Hours too).
Full-day uses the same deck and gold as the real run, so it shows what finishing early gives up.
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
            "hours_sum": defaultdict(float), "early_gold_sum": defaultdict(float),
            "cleared_count": Counter(), "gold_count": Counter(),
            "full_sum": defaultdict(float), "full_count": Counter(),
        })
        row["runs"] += 1
        row["wins"] += bool(details.get("won"))
        row["reached"] += int(details.get("reached_round", 0))
        row["gold"] += int(details.get("gold", 0))
        for day in details.get("days", []):
            goal = max(1, int(day.get("goal", 1)))
            row["ratio_sum"][int(day["round"])] += float(day.get("score", 0)) / goal
            row["ratio_count"][int(day["round"])] += 1
            if day.get("cleared") and not details.get("power"):
                row["hours_sum"][int(day["round"])] += int(day.get("hours", 0))
                row["cleared_count"][int(day["round"])] += 1
            if "early_gold" in day:
                row["early_gold_sum"][int(day["round"])] += int(day["early_gold"])
                row["gold_count"][int(day["round"])] += 1
            if "full_day_score" in day:
                # A day that used every Hour has nothing left to play, so its full day is its score.
                row["full_sum"][int(day["round"])] += float(day["full_day_score"]) / goal
                row["full_count"][int(day["round"])] += 1
            elif day.get("cleared") and details.get("extra_hours") and not day.get("extra_hours_skipped"):
                row["full_sum"][int(day["round"])] += float(day.get("score", 0)) / goal
                row["full_count"][int(day["round"])] += 1
        row["takes"].update(set(picked_card_ids(details)))
    return chefs


def ratio(row: dict, day: int) -> float | None:
    count = row["ratio_count"][day]
    return row["ratio_sum"][day] / count if count else None


def mean(row: dict, sum_key: str, count_key: str, day: int) -> float | None:
    count = row[count_key][day]
    return row[sum_key][day] / count if count else None


def fmt(value: float | None) -> str:
    return "-" if value is None else f"{value:.2f}"


def print_by_day(title: str, old_row: dict, new_row: dict, sum_key: str, count_key: str) -> None:
    lines = []
    for day in range(1, RUN_LENGTH + 1):
        old_value = mean(old_row, sum_key, count_key, day)
        new_value = mean(new_row, sum_key, count_key, day)
        if old_value is None and new_value is None:
            continue
        line = f"    day {day}: {fmt(old_value):>6} -> {fmt(new_value):>6}"
        if old_value is not None and new_value is not None:
            line += f"  ({new_value - old_value:+.2f})"
        lines.append(line)
    if lines:
        print(f"  {title}")
        print("\n".join(lines))


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
        print_by_day("Hours used to meet the goal", old_row, new_row, "hours_sum", "cleared_count")
        print_by_day("early-finish gold", old_row, new_row, "early_gold_sum", "gold_count")
        print_by_day("full-day score/goal (--extra-hours)", old_row, new_row, "full_sum", "full_count")
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
