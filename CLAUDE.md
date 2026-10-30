# Flavour Pass

Godot 4.7 (Forward Plus) roguelike deckbuilder on a hex board. GitHub: MSAkel/Hexbound.

## Running Godot from the command line

`godot` below means the Godot 4.7 executable. If it isn't on PATH, use its full path
(e.g. `"C:\path\to\Godot_v4.7-stable_win64_console.exe"` — use the `_console` build so
output prints to the terminal).

- Re-import assets (after adding/changing assets): `godot --headless --path . --import`
- Boot the game headless for ~10s to catch load/script errors: `godot --headless --path . --quit-after 600`

## Playtest bot

`scripts/debug/playtest_runner.gd` plays seeded runs through the real day flow and writes a JSON report.

```
godot --headless --path . res://scenes/debug/playtest_runner.tscn -- [flags]
```

- `--runs=N` seeds per chef (default 8); `--chef=sous_chef|sommelier|gourmet_restaurant`
- `--seed=<text>` one seed; `--repeat=N` replays it to check determinism
- `--difficulty=N` difficulty index (default 0)
- `--power` no day goals, reports raw score per day
- `--fuzz` random legal actions; fails on invariants and script errors
- `--no-condiments`, `--no-overplay`, `--check-sim`, `--verbose`
- `--out=<path>` report path (default `user://playtest_report.json`)

A run takes ~50s per seed per chef. Compare reports with `scripts/debug/compare_playtest_reports.py`
and list picks with `scripts/debug/analyze_pick_report.py`.

After gameplay or balance changes, run at least `--runs=2` and a `--fuzz` pass before calling it done.

## Push checks (CI)

`.github/workflows/checks.yml` runs on every push to `main` and every pull request:
import, boot, 1 bot playtest per chef and 20 fuzz runs per chef (~4 min). It fails on any
`SCRIPT ERROR` / `Parse Error` / `ERROR:` line, since Godot often exits 0 when scripts fail to
compile. Run the same checks locally (Git Bash on Windows) with:

```
GODOT="/path/to/godot_console" .github/scripts/godot_checks.sh
```

Logs and playtest reports are uploaded as the `godot-check-logs` artifact on each run.
Bigger runs: Actions → Godot checks → Run workflow, and set the seed counts.

## Design notes

- Difficulty 0 is intentionally easy. Don't treat a 100% win rate there as a balance problem;
  judge balance at higher difficulties.
- Baseline (Oct 2026, difficulty 0, 2 runs/chef): all chefs win; Sommelier's late-game
  score/goal ratio (3–4x on days 6–9) is much higher than the other chefs (1.1–2x) — worth watching.

## Conventions

- Autoloads live in `scripts/autoload/` (registered in `project.godot`).
- Card definitions: `resources/cards/**` (`.tres` + optional `.gd` behaviour); staff in `resources/staff/`,
  condiments in `resources/condiments/`, stations in `resources/stations/`.
- GDScript warnings are treated as errors in this project — keep types explicit
  (e.g. avoid constants inferred from Variant).
- Don't commit `.godot/`, `.cursor_video_frames/`, `tools/` or `docs/` (see `.gitignore`).
