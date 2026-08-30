# Playtest findings

Headless player-bot data from [Testing](96e51dbd-4f2a-48ed-94cc-eb2a6063779a). Re-run with `scripts/debug/analyze_pick_report.py` against `user://playtest_report.json`.

This is a **bot floor**, not a human sample. The bot skips six utilities, never rerolls for a named synergy, and commits to one engine line. Layout specialists (`wide_ratio`, `share_load`, `compact_power`, `lone_cell`) are understated.

## Batches

| Batch | Bot | Passives | Result |
|-------|-----|----------|--------|
| Fixtures | — | — | Starter fairness 100/100. Lone Cell illegal on Surveyor. R1 two-segment 10/10 at 435. |
| Greedy fill, 10 seeds × 5 layouts | fill | none | Surveyor 40%, Converger 40%, Spiralist 30%, Encircler 20%, Columnist 20%. |
| fill / stack / spread, 4 seeds × 5 | 3 bots | none | **17/60 (28%)**. Stack on Encircler is the only cell that regularly dies on R9 instead of early. Spread dies on 435 by splitting Energy and Mult. |
| Player, 8 seeds × 5 | player | none | **20/40 (50%)**. Surveyor 63%, others ~38–50%. Log: `playtest_player_8x5.log`. |
| Player, 8 seeds × 5 | player | Spark | **18/40 (45%)**. Encircler 75%, Surveyor and Columnist 25%. Log: `playtest_player_smart_8x5.log`. |
| Player, 10 seeds × 5 | player | Spark | **25/50 (50%)**. Pick-rate source. Log: `playtest_player_10x5.log`. |

## 1–9 win rate (player bot, 10×5, Spark)

| Layout | Wins | Avg round reached | Typical deaths |
|--------|------|-------------------|----------------|
| Encircler | 7/10 (70%) | 7.8 | R3 ×2, R9 ×1 |
| Spiralist | 6/10 (60%) | 7.9 | R3, R6, R7, R9 |
| Converger | 5/10 (50%) | 7.7 | R4, R6, R7 ×2, R8 |
| Columnist | 4/10 (40%) | 6.0 | R3 ×3, R4 ×2, R7 |
| Surveyor | 3/10 (30%) | 7.9 | mixed 4–9 |

Overall **25/50**. R1 is not the split (two-segment opener clears 435). Walls are **R3 events**, **R6–R7**, and **R9 60000**.

Columnist was patched after this batch (force a first Energy/Mult producer on the locked column in R1–R3). Treat Columnist 40% as pre-patch.

## Pick rates (same 50 runs)

Pack picks + shop buys. Not offer rate. 62-card pool at the time (current pool is 63). **No card appeared in every run.**

### Staples (72%+ of runs)

| Card | Runs | Total picks/buys | Archetype |
|------|------|------------------|-----------|
| Forward Mult | 39/50 (78%) | 104 | Relay |
| Basic Multiplier | 38/50 (76%) | 86 | Generic Mult |
| Forward Energy | 38/50 (76%) | 69 | Relay |
| Turn Up | 36/50 (72%) | 79 | Generic Mult |
| Segment Bond | 36/50 (72%) | 62 | Cluster / Growth |
| Edge Card | 36/50 (72%) | 57 | Generic Energy |

Next tier: Helping Hand 64%, Load Splitter 62%, Overcharge 56%, Census Cell 54%, Power Cell 52%, Gluttonous Rune 52%, Lead-In 52%.

The bot's actual plan is **relay Mult and Energy onto one engine line, stamp adjacent Energy, buy fat Energy**. That is Relay + Cluster stamps, not Empower Burst.

### Never picked (0/50)

Bot-ignored utilities: Card Extraction, Clonus Cardus, Gold Extraction, Returnus Cardus, Transformus Cardus, Transformus Upgradus.

`transposition` is the only utility the bot buys (5/50).

**Golden Ratio** does not appear in this report at all (0 picks). Treat it as dead for the bot.

### Almost never (1/50)

Basic Allowance, Lucky Draw, Unstable Concoction, Share Load.

### Weak but legal (under 16% of runs)

| Card | Runs | Notes |
|------|------|-------|
| Open Circuit | 3/50 | Sparse |
| Lone Cell | 4/50 | Solo. Legal on four layouts, still rare |
| Opening Volt | 6/50 | Bookend |
| Initial Encore | 6/50 | Bookend |
| Treasury | 6/50 | Gold |
| Last Surge | 7/50 | Bookend |
| Compact Power | 7/50 | Sparse / small segments |
| Wide Ratio | 7/50 | Layout specialist |
| Turntake | 7/50 | Empower payoff |

Relay Sink 15/50. Endless Power 16/50. Aftershock 10/50.

## Versus the archetype map

| Build | Bot evidence | Read |
|-------|--------------|------|
| Segment Relay | Forward Mult / Forward Energy are the closest thing to mandatory | Dominant. Share Load and Relay Sink do not come along |
| Downstream Cluster | Segment Bond and Helping Hand are staples | Stamps yes. Advanced Pointer only 36% |
| Break Cycle | Overcharge 56%, Gluttonous 52%, Salvage Core 42% | Thicker in picks than the map guessed |
| Retrigger Engine | Wildspark 40%, Overdrive 34%, Aftershock 20% | Present, not the engine |
| Empower Burst | Turntake 14%, Endless Power 32% | Thin payoff, confirms the hole |
| Bookend | Opening Volt / Last Surge / Initial Encore all ≤14% | Cards exist, bot never sits them |
| Gold Ledger | Allowance / Lucky Draw / Concoction 2%, Golden Ratio 0% | Dead. Confirms the hole |
| Solo Cell | Lone Cell 8% | Nascent, confirms the hole |
| Sparse | Open Circuit 6%, Compact Power 14%, Tall Cell 40% | Tall Cell is the only sparse card the bot likes |
| Copy / mutate | Six utilities 0%. Imprint 28%. Mirror Copy 48% | Tools, not a build |

## What this does *not* say

- Humans will pick Lone Cell, Bookends, or Share Load more than the bot.
- Difficulty 2–5 was not in these batches (difficulty 1 / Spark only).
- Pick rate is not power. Forward Mult is common because the bot's scorer loves forwarding onto the engine line.
- Dead utilities are a harness gap, not a design verdict.

## Next measurement (not this todo)

Offer rate vs take rate (so "never picked" can mean "never offered" vs "offered and refused"). Human playtest of Gold Ledger, Bookend, and Solo Cell. Post-Columnist-patch 10×5.
