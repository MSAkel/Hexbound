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
- `--difficulty=N` difficulty level as shown in game, 1 to 8 (default 1)
- `--power` no day goals, reports raw score per day
- `--extra-hours` real day flow, but when an Hour is about to meet the goal with Hours to spare, the
  bot also plays those Hours out as a what-if (picks, plays, condiments) and rolls everything back.
  Each day gets `extra_hour_scores`, `full_day_score` and `early_gold`, so you can see what finishing
  early gives up with the deck and gold of a real run. Skipped on Blackout, Fading Station and
  Short Staffed days (those reroll part of the board every Hour). Costs roughly +35% run time.
- `--after-goal=stop|continue|continue:<N>` what the bot does once a Day's goal is met with Hours to
  spare: `stop` (default) ends the Day for the early-finish gold, `continue` plays every Hour of every
  Day, `continue:N` plays on through Day N. Each Day records `continued`, and `leftover_hours` counts
  the Hours played after the goal. Use it to compare ending early with playing on over whole runs.
- `--fuzz` random legal actions (plays, End Hour, skipped picks, the removal service); fails on
  invariants and script errors
- `--bot=<name>` who plays: `human` (default, the careful bot) or a player still learning the game:
  `novice` (skill 0.25), `casual` (0.55) or `slip` (0.85), from `novice_policy.gd`. Same what-if eyes as
  `human`, but it misjudges values (noise), does not use merging, replacing, rerolls, the condiment belt
  or staff moves until a random discovery day, and slips now and then (grabs a card, plays one without
  comparing the hand on one of its 3 best-looking spots and never by selling it, walks out of the
  merchant, picks a station perk blind). Skill grows by `--learning` per Day. `--skill=0..1` and `--learning=<per Day>` override the profile. Seeded, so a seed replays the
  same. `details.bot_profile` has the discovery days and the slips taken. All numbers are untuned.
- `--ledger` also log every Flavour, +Mult, xMult and Gold event of each real Hour in
  `details.hour_ledger` (`HourLedger`, `scripts/helpers/hour_ledger.gd`): the card that paid it and its
  scales `[garnish, star, chef, station, queued]`. Replaying the events rebuilds the Hour score exactly.
  Off by default, since it makes reports much larger. It does not change gameplay.
- `--no-condiments`, `--no-overplay`, `--check-sim`, `--verbose`
- `--out=<path>` report path (default `user://playtest_report.json`)

Each run's `details.meal_fires` maps a Meal id to `[times served, times Failed]` from real Hours
(what-if Hours are not counted), so you can see which Meals the bot completes, not just picks.
`details.station_picks` has every Level 3 and 6 station perk pick (station, level, all options, what was
taken) and each Day's `stations` now carry the perk index held. `scripts/debug/analyze_station_picks.py
report.json [--vs=other.json]` reads them, with a second report beside it to compare bots. The `human`
bot values a perk only by flat Flavour or output scale, so behavioural perks tie at zero and it takes
option #0 every time; read its pick rates with that in mind.
Deck fields: `details.starting_deck` (card ids) and `kitchen` (Station kits it was built from),
`passes` (Hours ended with plays left), `skips` (card picks skipped) and `removals` (removal service,
`round:id@price`), `paid_rerolls` (`round@price`). The bot values a pick by playing it on the next
Day (picks go on top of the draw pile),
discounts Merchant cards by how often a shuffled-in card is drawn, skips weak picks once the deck is
18+ cards and removes its weakest cards above that size. All of those numbers are untuned.
`details.station_summary` lists every Station type the run formed (`best_level`, `first_day`, `days`
it stood at a Day's end, most `rows` at once) and `details.meals_served` the Meals served at least once
(id -> serves). Each run's log line prints both (`stations=pastry L5 (day 2, 2 rows) meals=2`), and
`compare_playtest_reports.py` shows Stations per run, different Meals served per run and each Station's
share of runs, average best level and first Day.
`details.replace_detail` lists every replacement (day, Hour, old and new card with kinds, stars lost) and
`details.offers` every card offer as `round:id|id|id>chosen`.

`scripts/debug/analyze_score_ledger.py report.json` reads these: score by source card, how much of the
score xMult adds, the same boards re-scored with Garnish, stars, chef or Station scales taken out, the top
Hours, what the bot replaces and when, and take rate per card when offered. The first four need `--ledger`.

A run takes ~50s per seed per chef. Compare reports with `scripts/debug/compare_playtest_reports.py`
and list picks with `scripts/debug/analyze_pick_report.py`.

After gameplay or balance changes, run at least `--runs=2` and a `--fuzz` pass before calling it done.

## Push checks (CI)

`.github/workflows/checks.yml` runs on every push to `main` and every pull request:
import, boot, a content check (`scenes/debug/content_check.tscn`: fails when the Technique or condiment catalog or a card category loads empty, which raises no error), a deck flow check on the real run screen (`scenes/debug/deck_flow_check.tscn`: draw, plays, picks, End Hour, Skip, the Day reshuffle, the removal service, save and Continue), 1 bot playtest per chef and 8 fuzz runs per chef (8 chefs, ~8 min). It fails on any
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

- Difficulty Level 1 is intentionally easy. Don't treat a 100% win rate there as a balance problem;
  judge balance at higher levels.
- Difficulty levels stack, each adding one rule (`scripts/resources/difficulty.gd`). Level 1 is the
  practice and learning level: the lowest Day targets (`ScoreProgression.AUTHORED_ROUND_SCORES`), every
  second Meal slot open and Merchant rerolls at a flat 5 Gold. There are 8 levels (the old −5 starting
  Gold level was removed): 2 Day targets grow +2% per Day after Day 1, 3 one fewer hand discard a Day
  (3 instead of 4), 4 two random Stations lock their second Meal slot until Station level 3, 5 Day
  targets grow another +3% per Day after Day 1, 6 Merchant reroll cost climbs +1 per reroll, 7 all
  four Stations lock it, 8 each Station level needs 1 more Meal. Levels 4, 7 and 8 only act while
  Station levelling is on (`StationManager.LEVELING_ENABLED`).
  Day 1's target is the same at every level: no one should lose Day 1. Ramp values are untuned.
  `Difficulty.Level` is 0-based (`LEVEL_1` = 0); saves store that index.
- Baseline (Oct 2026, Level 1, 2 runs/chef): all chefs win; Sommelier's late-game
  score/goal ratio (3–4x on days 6–9) is much higher than the other chefs (1.1–2x) — worth watching.

## Deck and draw

Player-facing text calls an Hour a **Turn** (`GameTerms.HOUR` is "Turn"; card, Technique, Station,
event and UI text say Turn). Code, save keys and these notes still say Hour. The event name Rush Hour
is kept.

`DeckManager` (`scripts/autoload/deck_manager.gd`) owns the run's deck: draw pile, hand, discard pile
and played pile. Design: the project doc `claude/deck-and-draw-design.md`. All numbers untuned.

- Every Hour draws `HOUR_DRAW` (5). An Hour ends after `PLAYS_PER_HOUR` (3) plays or the End Hour
  button. Cards left in the hand are discarded. The Discard button (`discard_button.gd`, under End Hour)
  calls `DeckManager.discard_hand`: the whole hand goes to the discard pile and as many cards are drawn,
  using no play, `HAND_DISCARDS_PER_DAY` (4) times a Day. The bots send `{"discard": true}`. When the draw pile runs out mid-draw the discard pile
  is shuffled in. Each new Day (`RoundFlow._finish_transition` → `DeckManager.start_day`) shuffles
  every pile, including the played pile, back into the draw pile.
- One Station cooks per Hour, top to bottom (`HexTileMap.get_cooking_segment`, Hour N cooks
  Station N; a Day has 4 Hours and the board 4 Stations). While an Hour resolves,
  `HexTileMap.cooking_segment` makes every other Station's cards inactive: they don't fire, can't be
  retriggered and don't score, and their Meals aren't served. Ending the Day early leaves the later
  Stations uncooked. Rush Hour (3 Hours) never cooks the bottom Station.
- A played card is placed on the board and its deck card goes to the played pile. The board copies
  the card (`Hex.place_tile_card`), so board card and deck card are separate once played. A redraw on a
  later Day can merge onto its own board copy or go on an empty spot. Playing a different card onto a
  placed one (replacing it) is off (`TileCard.REPLACE_ENABLED` false), so the bots never replace.
- Every card joining the deck goes through `DeckManager.gain_card(card, source)`, which copies the
  card and picks the pile: card picks (off for now) go on top of the draw pile, Merchant buys, packs and Duplicate Order are shuffled in, Send Back goes to the discard
  pile. It then emits `EventBus.tile_card_selected` (save and tutorial listeners).
- There is no end-of-Day card pick: the Day summary leads straight to the Merchant
  (`RoundFlow.CARD_PICK_ENABLED` false; the CARD_PICK step and its reroll code are kept, unused). New
  cards come only from the Merchant and packs.
- Day-end Gold (`EconomyManager.apply_round_speed_rewards`): `ROUND_COMPLETION_GOLD` (3), plus
  `GOLD_PER_UNUSED_TURN` (3) per Hour left, plus `GOLD_PER_UNIQUE_MEAL` (1) for each different Meal on
  the board. The Day Complete screen shows each part. Untuned.
- Techniques cost 4/6/8 by rarity (`StaffCard.BASE_PRICE_BY_RARITY`); a Technique's `price_override`
  above 0 replaces that (Leftovers, a Common at 2).
- Discard (move to the discard pile) and destroy (remove completely) are different words: Throw Out
  destroys the board card only, Send Back discards it with its stars, the Merchant removal service
  (3 Gold, +1 per use in a visit) destroys a deck card. The service is paid up front
  (`DeckManager.pay_for_removal`); skipping the pick keeps the Gold spent. The deck can't go below
  `MIN_DECK_SIZE` (10).
- Hand cards can't be sold. `Hand` (scenes/components/hand.gd) only shows DeckManager's hand. It deals
  drawn cards from the deck pile and flings discarded ones into the chef portrait (`DEAL_*` and
  `DISCARD_*` constants). `DeckHud` (`scenes/ui/deck/deck_hud.tscn`, the draw pile bottom-right) opens
  `DeckViewer` (`deck_viewer.tscn`: the draw pile, or the whole deck for the removal service). End Hour
  and Discard sit under the chef portrait in `card_sell_panel.tscn`.
- Merchant shelf: `Merchant.MERCHANT_SHELF_CARD_COUNT` (3) cards, each slot rolling its kind by
  `MerchantPacks.SHELF_KIND_WEIGHTS` (Technique 50%, Meal 40%, Ingredient 5%, Kitchenware 5%); there is
  no guaranteed Technique slot. Ingredients and Kitchenware cost 1 Gold, Meals 3 (`TileCard.SHOP_PRICE`,
  `MEAL_SHOP_PRICE`); packs 3/3/4/4 (`MerchantPacks.PRICES`), pack kinds by `KIND_WEIGHTS`.
- Stars have no cap and add `TileCard.STAR_SCALE_STEP` (+20%) each.
- Saves (version 7) store every pile in order. Version 6 runs can't be continued.

## Chefs

Each chef is a `ChefDefinition` in `resources/chefs/<id>.tres`, listed in `ChefRegistry.CHEF_PATHS`:
name, selection portrait (`icon`), in-game portrait (shown above the gold panel), ability text,
a starting deck (`deck_stations`, `kit_swaps`) and a `perk`. The perk is a script in `resources/chefs/perks/` extending `ChefPerk`;
its tunable numbers are `@export` fields set in the chef's `.tres`. Game systems call the bound chef
through `GameManager.chef` (`ChefRuntime`), which forwards to the perk's hooks: starting gold, card
pool filter (`GameManager.get_draw_pool()`), output scale, after-trigger, Meal +Mult, Meal served,
Hour/Day start, station level thresholds, taking every station pick, merchant slots and free rerolls.
Add a hook to `ChefPerk` + `ChefRuntime` when a new chef needs one.

Starting decks hold one copy of every Ingredient and Kitchenware the chef can see
(`GameManager.get_draw_pool`) plus `ChefRegistry.STARTING_MEAL_COUNT` (4) different Meals:
`SPECIALITY_MEAL_COUNT` (2) from the home Station's kit (kit order, swaps applied) and the rest random
from the chef's pool. Chefs whose home Station is rolled (Restaurateur, Chef de Cuisine) get all 4
random. The kits' Ingredient, Kitchenware and random entries are no longer dealt. Station kits (`resources/station_kits/*.tres`, `StationKit`): one ordered
list of 9 card ids or random entries (`random:kitchenware`, `random:ingredient`, `random:<ingredient tag>`)
per Station type, used as a mini (first 5), small (first 6) or full (all 9) kit. `deck_stations` lists
`"<choice>:<size>"` entries, home Station first: a Station id, ids split by `|` to roll one, or `any`.
`kit_swaps` (`"<station id>:<slot>=<card id>"`) replace kit slots with a chef's signature cards.
`ChefRegistry.build_starting_deck` builds it in the `starting_deck:<chef id>` RNG stream, so a seed
deals the same deck. An empty `deck_stations` deals the full set with no Meals.

## Conventions

- Autoloads live in `scripts/autoload/` (registered in `project.godot`).
- Card definitions: `resources/cards/**` (`.tres` + optional `.gd` behaviour); Techniques in `resources/techniques/`,
  condiments in `resources/condiments/`, stations in `resources/stations/`.
- GDScript warnings are treated as errors in this project — keep types explicit
  (e.g. avoid constants inferred from Variant).
- Don't commit `.godot/`, `.cursor_video_frames/`, `tools/` or `docs/` (see `.gitignore`).
