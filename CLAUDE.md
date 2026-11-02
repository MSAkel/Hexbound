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

- `--runs=N` seeds per chef (default 8); `--chef=<id>` one chef (ids in `resources/chefs/*.tres`)
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
import, boot, 1 bot playtest per chef and 8 fuzz runs per chef (8 chefs, ~8 min). It fails on any
`SCRIPT ERROR` / `Parse Error` / `ERROR:` line, since Godot often exits 0 when scripts fail to
compile. Run the same checks locally (Git Bash on Windows) with:

```
GODOT="/path/to/godot_console" .github/scripts/godot_checks.sh
```

Logs and playtest reports are uploaded as the `godot-check-logs` artifact on each run.
Bigger runs: Actions → Godot checks → Run workflow, and set the seed counts.

## Content catalog

`scenes/debug/export_catalog.tscn` writes every card, Technique, condiment, station and chef to
JSON using the game's own loaders. `scripts/debug/catalog/build_catalog_page.py` (needs Pillow)
turns that JSON into a single self-contained HTML page with search, filters and the game's icons:

```
godot --headless --path . res://scenes/debug/export_catalog.tscn -- --out=catalog.json
python scripts/debug/catalog/build_catalog_page.py catalog.json catalog.html --commit=<sha>
python scripts/debug/catalog/build_map_pages.py catalog.json <out_dir> --commit=<sha>
python scripts/debug/catalog/build_meal_collection.py catalog.json meal_collection.html --commit=<sha>
```

`build_map_pages.py` writes the Meal, Station, Dependency and Technique maps. The first three share
`map_template.html` (meals, stations, or both). The Technique Map's hand mapping of each Technique
to the mechanics it relies on and affects is the `MAP` table in `technique_map_template.html`;
a new Technique shows as unmapped until it gets an entry there.
`build_meal_collection.py catalog.json meal_collection.html` builds the Meal Collection page:
draft real-world history per Meal from `meal_collection/meal_lore.json` (keyed by meal id, not
used by the game) plus effect, category and recipe from the export. A new Meal shows as
"still to write" until it gets a lore entry; the builder lists those. Stations export a `setup` list
(kinds, named cards, "different" rules) that the maps read; keep it in step with `StationType`.

## Design notes

- Difficulty 0 is intentionally easy. Don't treat a 100% win rate there as a balance problem;
  judge balance at higher difficulties.
- Baseline (Oct 2026, difficulty 0, 2 runs/chef): all chefs win; Sommelier's late-game
  score/goal ratio (3–4x on days 6–9) is much higher than the other chefs (1.1–2x) — worth watching.

## Chefs

Each chef is a `ChefDefinition` in `resources/chefs/<id>.tres`, listed in `ChefRegistry.CHEF_PATHS`:
name, selection portrait (`icon`), in-game portrait (shown above the gold panel), ability text,
`starting_hand` and a `perk`. The perk is a script in `resources/chefs/perks/` extending `ChefPerk`;
its tunable numbers are `@export` fields set in the chef's `.tres`. Game systems call the bound chef
through `GameManager.chef` (`ChefRuntime`), which forwards to the perk's hooks: starting gold, card
pool filter (`GameManager.get_draw_pool()`), output scale, after-trigger, Meal +Mult, Meal served,
Hour/Day start, station level thresholds, taking every station pick, merchant slots and free rerolls.
Add a hook to `ChefPerk` + `ChefRuntime` when a new chef needs one.

`starting_hand` lists card ids or random entries (`random:kitchenware`, `random:ingredient`,
`random:<ingredient tag>`), dealt in order. With `last_card_is_flex`, a difficulty starting-hand
reduction removes the last card first so the station setup stays whole. An empty list deals the
default random 3 Ingredients + 2 Kitchenware.

## Conventions

- Autoloads live in `scripts/autoload/` (registered in `project.godot`).
- Card definitions: `resources/cards/**` (`.tres` + optional `.gd` behaviour); staff in `resources/staff/`,
  condiments in `resources/condiments/`, stations in `resources/stations/`.
- GDScript warnings are treated as errors in this project — keep types explicit
  (e.g. avoid constants inferred from Variant).
- Don't commit `.godot/`, `.cursor_video_frames/`, `tools/` or `docs/` (see `.gitignore`).
