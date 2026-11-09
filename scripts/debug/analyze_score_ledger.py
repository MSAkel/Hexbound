#!/usr/bin/env python3
"""Reads a playtest report and explains where the score came from.

    python scripts/debug/analyze_score_ledger.py report.json [--top=5] [--chef=<id>] [--min-offers=6]

Sections:
  1. Score by source   -- which cards carry the score (needs a report made with --ledger)
  2. xMult uplift      -- how much of the score xMult adds, per chef
  3. Scale what-ifs    -- the same boards re-scored with one output scale taken back out
  4. Top Hours         -- the biggest Hours with their top contributors
  5. Replacements      -- what the bot replaces and when (works on any report)
  6. Offers            -- how often each card was offered versus taken (reports made after this tool)

Replaying an Hour: Flavour adds up, "+Mult" adds to a multiplier that starts at 1, xMult multiplies it,
score = round(Flavour x multiplier). Events are [kind, source, value, segment, scales]; scales is
[garnish, star, chef, station, queued] of the activation that paid them, or [] when none was running.
The scale what-ifs divide one scale back out of every event, so they are exact for Flavour and +Mult
(the Station flat bonus is scaled the same way) and use 1 + (factor - 1) / scale for xMult. They keep
the same board and the same plays, so they show what a scale adds, not what a different bot would do.
"""
import json
import sys
from collections import Counter, defaultdict

SCALE_NAMES = ["garnish", "star", "chef", "station", "queued"]


def replay(events):
    flavour, mult = 0.0, 1.0
    for kind, _src, value, _seg, _scales in events:
        if kind == "f":
            flavour += value
        elif kind == "a":
            mult += value
        elif kind == "x":
            mult *= value
    return int(round(flavour * mult))


def without(events, drop):
    return [e for e in events if not drop(e)]


def rescale(events, index):
    """Events with scale component `index` taken back out."""
    result = []
    for kind, src, value, seg, scales in events:
        if scales and kind in "fax":
            s = scales[index]
            if s and s != 1.0:
                value = 1.0 + (value - 1.0) / s if kind == "x" else value / s
        result.append([kind, src, value, seg, scales])
    return result


def pct(a, b):
    return 100.0 * a / b if b else 0.0


def load(path, chef_filter):
    report = json.load(open(path))
    runs = [c for c in report["cases"] if c.get("suite") == "run"]
    if chef_filter:
        runs = [c for c in runs if c["chef"] == chef_filter]
    return runs


def day_goals(details):
    return {int(d["round"]): d.get("goal", 0) for d in details.get("days", [])}


def section_score(runs, top):
    by_chef_source = defaultdict(lambda: defaultdict(float))
    chef_total = Counter()
    mismatches = hours = 0
    for run in runs:
        for h in run["details"].get("hour_ledger", []):
            ev = h["events"]
            score = replay(ev)
            hours += 1
            if abs(score - h["score"]) > max(2, 0.001 * abs(h["score"])):
                mismatches += 1
            chef_total[run["chef"]] += score
            for src in {e[1] for e in ev if e[1]}:
                by_chef_source[run["chef"]][src] += score - replay(without(ev, lambda e: e[1] == src))
    print("== 1. Score by source (score lost when that card's events are removed; shares can pass 100%)")
    if not hours:
        print("   no hour_ledger in this report (run the playtest with --ledger)")
        return False
    print("   replay vs game score: %d of %d Hours differ" % (mismatches, hours))
    for chef in sorted(by_chef_source):
        ranked = sorted(by_chef_source[chef].items(), key=lambda kv: -kv[1])[:top]
        print("   %-16s %s" % (chef, ", ".join("%s %.0f%%" % (s, pct(v, chef_total[chef])) for s, v in ranked)))
    return True


def section_xmult(runs):
    print("\n== 2. xMult uplift (score / score with every xMult removed)")
    for chef in sorted({r["chef"] for r in runs}):
        total = total_no_x = 0
        ratios = []
        for run in (r for r in runs if r["chef"] == chef):
            for h in run["details"].get("hour_ledger", []):
                ev = h["events"]
                s, sx = replay(ev), replay(without(ev, lambda e: e[0] == "x"))
                total += s
                total_no_x += sx
                if sx > 0:
                    ratios.append(s / sx)
        if not ratios:
            continue
        ratios.sort()
        print("   %-16s xMult is %2.0f%% of score   median x%.2f  p90 x%.2f  max x%.2f" % (
            chef, pct(total - total_no_x, total), ratios[len(ratios) // 2],
            ratios[int(len(ratios) * 0.9)], ratios[-1]))


def section_scales(runs):
    print("\n== 3. Scale what-ifs (score kept with that scale taken out, Gold not counted)")
    print("   %-16s %s" % ("", "  ".join("%8s" % n for n in SCALE_NAMES)))
    for chef in sorted({r["chef"] for r in runs}):
        total = 0
        cf = [0] * len(SCALE_NAMES)
        for run in (r for r in runs if r["chef"] == chef):
            for h in run["details"].get("hour_ledger", []):
                ev = h["events"]
                total += replay(ev)
                for i in range(len(SCALE_NAMES)):
                    cf[i] += replay(rescale(ev, i))
        if total:
            print("   %-16s %s" % (chef, "  ".join("%7.0f%%" % pct(c, total) for c in cf)))


def section_top_hours(runs, top):
    print("\n== 4. Top Hours (score / that day's goal)")
    rows = []
    for run in runs:
        goals = day_goals(run["details"])
        for h in run["details"].get("hour_ledger", []):
            ev = h["events"]
            rows.append((replay(ev), run, h, goals.get(h["day"], 0), ev))
    rows.sort(key=lambda r: -r[0])
    for score, run, h, goal, ev in rows[:top]:
        contrib = Counter()
        for src in {e[1] for e in ev if e[1]}:
            contrib[src] = score - replay(without(ev, lambda e: e[1] == src))
        xs = [e for e in ev if e[0] == "x"]
        biggest_x = max(xs, key=lambda e: e[2]) if xs else None
        garnish = max((e[4][0] for e in ev if e[4]), default=1.0)
        stars = max((e[4][1] for e in ev if e[4]), default=1.0)
        print("   %s seed %s day %d hour %d: %d (%.1fx goal)  top: %s" % (
            run["chef"], run["seed"], h["day"], h["hour"], score, score / goal if goal else 0,
            ", ".join("%s %.0f%%" % (s, pct(v, score)) for s, v in contrib.most_common(3))))
        print("      %d events, biggest xMult %s, max Garnish scale x%.2f, max star scale x%.2f" % (
            len(ev), ("x%.2f from %s" % (biggest_x[2], biggest_x[1] or "?")) if biggest_x else "none", garnish, stars))


def section_replaces(runs):
    print("\n== 5. Replacements")
    meal_ids = set()
    for run in runs:
        meal_ids.update(run["details"].get("meal_fires", {}).keys())
    transitions, by_day, by_chef = Counter(), Counter(), Counter()
    replaced, replacing, lost_stars = Counter(), Counter(), 0
    total = 0
    for run in runs:
        d = run["details"]
        detail = d.get("replace_detail")
        if detail is None:  # older report: ids only, so a Meal is any id that fired as one
            detail = []
            for text in d.get("replaces", []):
                day, pair = text.split(":", 1)
                old, new = pair.split(">", 1)
                detail.append({"day": int(day), "old": old, "new": new,
                               "old_kind": "Meal" if old in meal_ids else "other",
                               "new_kind": "Meal" if new in meal_ids else "other", "old_stars": 1})
        for r in detail:
            total += 1
            transitions["%s -> %s" % (r["old_kind"] or "?", r["new_kind"] or "?")] += 1
            by_day[r["day"]] += 1
            by_chef[run["chef"]] += 1
            replaced[r["old"]] += 1
            replacing[r["new"]] += 1
            lost_stars += max(0, r.get("old_stars", 1) - 1)
    if not total:
        print("   none")
        return
    print("   %d replacements over %d runs (%.1f per run), %d star levels thrown away" % (
        total, len(runs), total / len(runs), lost_stars))
    print("   by kind: " + ", ".join("%s %d" % kv for kv in transitions.most_common()))
    print("   by day:  " + ", ".join("D%d %d" % kv for kv in sorted(by_day.items())))
    print("   by chef: " + ", ".join("%s %d" % kv for kv in by_chef.most_common()))
    print("   most replaced:   " + ", ".join("%s %d" % kv for kv in replaced.most_common(6)))
    print("   most put in:     " + ", ".join("%s %d" % kv for kv in replacing.most_common(6)))


def section_offers(runs, min_offers):
    offered, taken = Counter(), Counter()
    for run in runs:
        for text in run["details"].get("offers", []):
            head, chosen = text.rsplit(">", 1)
            ids = head.split(":", 1)[1].split("|")
            for card_id in ids:
                offered[card_id] += 1
            if chosen != "rerolled":
                taken[chosen] += 1
    print("\n== 6. Offers (take rate when offered)")
    if not offered:
        print("   no offers in this report")
        return
    rows = sorted(((taken[c] / n, c, n) for c, n in offered.items() if n >= min_offers))
    print("   rarely taken:  " + ", ".join("%s %.0f%% of %d" % (c, 100 * r, n) for r, c, n in rows[:8]))
    print("   often taken:   " + ", ".join("%s %.0f%% of %d" % (c, 100 * r, n) for r, c, n in rows[::-1][:8]))


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    opts = dict(a[2:].split("=", 1) for a in sys.argv[1:] if a.startswith("--") and "=" in a)
    if not args:
        print(__doc__)
        sys.exit(1)
    runs = load(args[0], opts.get("chef", ""))
    top = int(opts.get("top", 5))
    if section_score(runs, top):
        section_xmult(runs)
        section_scales(runs)
        section_top_hours(runs, top)
    section_replaces(runs)
    section_offers(runs, int(opts.get("min-offers", 6)))


if __name__ == "__main__":
    main()
