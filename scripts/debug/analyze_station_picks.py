#!/usr/bin/env python3
"""Which stations get built and which perks get picked, from a playtest report.

    python scripts/debug/analyze_station_picks.py report.json [--vs=other.json] [--chef=<id>]

With --vs the pick rates of the two reports sit side by side, labelled by the bot that played
(details.bot), so "human" and "novice" can be compared on the same seeds.

Sections:
  1. Stations    -- which station types are on the board at the end of each Day, how far they level
  2. Perk picks  -- for each station and level, every option and how often it was taken.
                    "tag matches" is how many cards on the station the perk's own tags select when it
                    was offered. Perks with special behaviour (most Level 6 picks) have no tags, so they
                    always show 0 there. It says nothing about how good they are.
Needs reports made with the station_picks field (this tool's runner). Chefs that take every
station pick themselves (no popup) have none.

The careful bot ("human") values a perk only by its flat Flavour and output scale, so behavioural
perks tie at zero and it takes option #0 every time. Its pick rates show that, not what players
prefer. The novice profiles add slips (random perk picks), which spread the picks.
"""
import json
import sys
from collections import Counter, defaultdict


def load(path, chef_filter):
    report = json.load(open(path))
    runs = [c for c in report["cases"] if c.get("suite") == "run"]
    if chef_filter:
        runs = [c for c in runs if c["chef"] == chef_filter]
    return runs


def bot_name(runs):
    return "/".join(sorted({r["details"].get("bot", "?") for r in runs})) or "?"


def pct(a, b):
    return 100.0 * a / b if b else 0.0


def section_stations(runs):
    print("== 1. Stations at the end of each Day (share of station-days, average level)")
    seen, levels = Counter(), defaultdict(list)
    reached3, reached6, run_with = Counter(), Counter(), Counter()
    total = 0
    for run in runs:
        best = {}
        for day in run["details"].get("days", []):
            for segment, s in enumerate(day.get("stations", [])):
                name = s["type"] or "(base)"
                seen[name] += 1
                levels[name].append(s["level"])
                total += 1
                best[(name, segment)] = max(s["level"], best.get((name, segment), 0))
        types_in_run = {name for (name, _seg) in best}
        for name in types_in_run:
            run_with[name] += 1
        for (name, _seg), level in best.items():
            reached3[name] += level >= 3
            reached6[name] += level >= 6
    for name, count in seen.most_common():
        lv = levels[name]
        print("   %-22s %4.0f%% of station-days  avg level %.1f  in %d of %d runs  (reached L3 x%d, L6 x%d)" % (
            name, pct(count, total), sum(lv) / len(lv), run_with[name], len(runs), reached3[name], reached6[name]))


def collect_picks(runs):
    table = defaultdict(lambda: {"options": [], "events": 0, "taken": Counter(), "offered_match": defaultdict(list),
                                  "dead": Counter(), "won": Counter()})
    for run in runs:
        won = bool(run["details"].get("won"))
        for pick in run["details"].get("station_picks", []):
            row = table[(pick["station"], pick["level"])]
            if not row["options"]:
                row["options"] = pick["options"]
            row["events"] += 1
            chosen = pick["chosen"]
            row["taken"][chosen] += 1
            row["won"][chosen] += won
            for i, n in enumerate(pick["matching"]):
                row["offered_match"][i].append(n)
            if pick["matching"] and pick["matching"][chosen] == 0:
                row["dead"][chosen] += 1
    return table


def section_picks(runs, other_runs):
    print("\n== 2. Perk picks per station and level (picked / offered, cards it applied to)")
    mine = collect_picks(runs)
    theirs = collect_picks(other_runs) if other_runs is not None else None
    if not mine:
        print("   no station_picks in this report (made before this tool, or the chef takes every pick)")
        return
    label_a = bot_name(runs)
    label_b = bot_name(other_runs) if other_runs is not None else ""
    for key in sorted(mine, key=lambda k: (k[0], k[1])):
        row = mine[key]
        print("   %s, Level %d  (%d picks)" % (key[0], key[1], row["events"]))
        other = theirs.get(key) if theirs else None
        if row["events"] >= 3 and max(row["taken"].values()) == row["events"]:
            print("     (one option took every pick: the bot may not be able to tell these apart)")
        for i, text in enumerate(row["options"]):
            matches = row["offered_match"][i]
            avg = sum(matches) / len(matches) if matches else 0
            line = "     %-4s %3.0f%% (%d)  tag matches %.1f" % (
                "#%d" % i, pct(row["taken"][i], row["events"]), row["taken"][i], avg)
            if other is not None and other["events"]:
                line += "   | %s %3.0f%% (%d)" % (label_b, pct(other["taken"][i], other["events"]), other["taken"][i])
            print(line + "   " + text[:90].replace("\n", " "))
    if theirs is not None:
        print("\n   columns: %s | %s" % (label_a, label_b))


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    opts = dict(a[2:].split("=", 1) for a in sys.argv[1:] if a.startswith("--") and "=" in a)
    if not args:
        print(__doc__)
        sys.exit(1)
    runs = load(args[0], opts.get("chef", ""))
    other = load(opts["vs"], opts.get("chef", "")) if "vs" in opts else None
    section_stations(runs)
    section_picks(runs, other)


if __name__ == "__main__":
    main()
