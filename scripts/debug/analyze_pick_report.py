#!/usr/bin/env python3
"""Summarize what the playtest bot drafted, bought, sold and drank.

usage: analyze_pick_report.py [report.json] [--suite=run|power|fuzz]
Defaults to the runner's report in this project's Godot user-data folder.
"""

import sys
from collections import Counter, defaultdict

from playtest_report import bot_cases, card_pool, load_report, parse_buy, picked_card_ids


def main() -> None:
    args = [arg for arg in sys.argv[1:] if not arg.startswith("--")]
    suite = next((arg.split("=", 1)[1] for arg in sys.argv[1:] if arg.startswith("--suite=")), None)
    cases = bot_cases(load_report(args[0] if args else None), suite)
    if not cases:
        print("no bot runs in report")
        return
    pool = card_pool()

    card_counts: Counter[str] = Counter()
    runs_with: Counter[str] = Counter()
    wins_with: Counter[str] = Counter()
    by_chef: dict[str, Counter[str]] = defaultdict(Counter)
    chef_runs: Counter[str] = Counter()
    other_buys: dict[str, Counter[str]] = defaultdict(Counter)
    sells: Counter[str] = Counter()
    drinks: Counter[str] = Counter()
    total_wins = 0

    for case in cases:
        details = case.get("details", {})
        chef = case.get("chef", "?")
        won = bool(details.get("won"))
        total_wins += won
        chef_runs[chef] += 1
        ids = picked_card_ids(details)
        card_counts.update(ids)
        by_chef[chef].update(ids)
        for card_id in set(ids):
            runs_with[card_id] += 1
            wins_with[card_id] += won
        for entry in details.get("buys", []):
            kind, item_id = parse_buy(entry)
            if kind != "card":
                other_buys[kind][item_id] += 1
        sells.update(entry.split(":", 1)[-1] for entry in details.get("sells", []))
        drinks.update(entry.split(":", 1)[-1] for entry in details.get("drinks", []))

    total = len(cases)
    base_rate = total_wins / total
    print(f"runs={total} wins={total_wins} ({100 * base_rate:.0f}%) pool={len(pool)} taken_unique={len(card_counts)}")

    print("\nNEVER_TAKEN")
    never = sorted(pool - set(card_counts))
    print("  " + (", ".join(never) if never else "(none)"))

    print("\nCARDS  (taken, runs with it, win rate when taken vs overall)")
    for card_id, count in card_counts.most_common():
        runs = runs_with[card_id]
        win_rate = wins_with[card_id] / runs
        print(f"  {card_id:24} {count:4}  {runs:3}/{total} runs  win {100 * win_rate:4.0f}% ({100 * (win_rate - base_rate):+.0f})")

    for kind in sorted(other_buys):
        print(f"\nBOUGHT_{kind.upper()}")
        for item_id, count in other_buys[kind].most_common():
            print(f"  {item_id:24} {count}")
    print("\nSOLD")
    for item_id, count in sells.most_common():
        print(f"  {item_id:24} {count}")
    print("\nDRUNK")
    for item_id, count in drinks.most_common():
        print(f"  {item_id:24} {count}")

    print("\nNEVER_TAKEN_BY_CHEF")
    for chef in sorted(chef_runs):
        missing = sorted(pool - set(by_chef[chef]))
        print(f"  {chef} ({chef_runs[chef]} runs): {len(missing)} never")
        print(f"    {', '.join(missing)}")


if __name__ == "__main__":
    main()
