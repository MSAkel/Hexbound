# Segment Passives Catalog

Design only. This is the locked list of passives: names, card-facing effects, tile costs, copy counts, unlocks, and icon descriptions. It does not add resources, runtime effects, Mult conversion, or unlock tracking.

Flavor names stay (**The Surveyor**, **The Encircler**, and so on). System copy uses **layout**, not character. Example UI: “Select a layout” / “The Surveyor — Top-left → bottom-right layout.” Wildcard is removed. No layout-specific passives for it.

---

## Design rules

- **Card-facing only.** No passive adds score, Energy, or Mult to the segment after cards resolve. Bonuses apply to the card’s own output so the hex chip and floating number can show them.
- **Energy Boost / Energy Amplifier** scale **Energy cards only**. Mult and Gold are unchanged by those two.
- **Mult is assumed to become a float** in a later systems pass. Energy and Gold stay integers. Score = `round(Energy × Mult)` at the segment contribution step. Empty-segment Mult stays 1.0. UI shows one decimal on Mult.
- **Families, not clones.** A 1-tile version and a stronger 2–3 tile version share a fantasy. They are separate passives with separate unlocks.
- **Copies** are extra placements of the same passive id. Weaker passives have 2–3 copies. Stronger ones have 1. Extra copies unlock from the same stat at higher thresholds. UI shows `2/3 copies unlocked`. Copies may sit on different segments, or stack on one segment if tiles remain.
- **Stacking.** `%` output adds. Retrigger chances roll independently per copy. Permanent growth adds per copy on that segment. First/last Producer effects add if stacked.
- **Tile cost** is loadout capacity. Cards still occupy every map tile during a run. A 1-tile segment can only hold a 1-tile passive.
- **Starter.** Spark Copy 1 starts unlocked. Nothing else does.

---

## Unlock rules

- **Multi-copy passives:** one id, tiered thresholds (Copy 1 / 2 / 3).
- **In-run feats:** checked on **any run end**, win or loss.
- **Layout exclusives:** per-layout XP and levels. Proposed XP: +1 per round completed with that layout (losses count), +3 extra on a win. Gates at levels **3 / 6 / 9** for Copy 1 / Copy 2 / signature.
- **Global win passives:** difficulty-gated wins (any layout), not “win N times.” Difficulty uses the existing Level 1–5 scale.
- **Head Start** uses **completed runs**, not wins. Losses count.
- **Breaks:** any destroyed/broken placed card counts.
- **Aegis Matrix:** only counts preventions while **Safety Fuse is placed** on a loadout and that fuse rolls the save.

### Difficulty win mapping

| Passive | Unlock |
|---------|--------|
| Energy Amplifier | Win a run on Difficulty 3 |
| Final Flourish | Win a run on Difficulty 4 |
| Empowered Output | Win a run on Difficulty 5 |
| Minting Press | Win on Difficulty 4 while holding at least 40 Gold |

### Implementation defaults (for a later pass)

- **Spark Surge:** first of 40 lifetime Producer retriggers **or** 50 card triggers in one turn.
- **Fully occupied segment:** every playable tile in the segment has a card. Disabled tiles are not in the segment list.
- **Alternating Current:** only Energy / Mult / Gold producers set the sequence. Supports are skipped and do not reset it.
- **Spectrum Engine:** cumulative across runs. One qualifying turn counts once.
- **Last Word copies:** a Producer activation that was the last Producer in its segment that turn.
- **Resonant Array:** every occupied tile in the segment is a Producer of the same product.
- **Conductor Core:** Support cards that trigger another card’s effect or Empower a Producer.

Existing passives reworked: Energy Boost (was Power Boost, Energy-only %), Spark, Second Wind, Focused Growth (was segment score %), Head Start (was gold/flat placeholder), Empowered Output (was segment Mult %). Steady Growth stays retired.

---

## Global families (28)

### Energy output

| Passive | Effect | Unlock | Max copies | Tiles | Icon |
|---------|--------|--------|------------|-------|------|
| Energy Boost | Energy cards on this segment produce +5% Energy. Mult and Gold unchanged. | 150 / 1,500 / 5,000 lifetime card triggers | 3 | 1 | Small battery behind a card |
| Energy Amplifier | Energy cards on this segment produce +10% Energy. Mult and Gold unchanged. | Win a run on Difficulty 3 (any layout) | 1 | 2 | Card between two bright coils |

Three Energy Boosts is the map-wide Energy `%` budget. Energy Amplifier is extra budget on one segment, not a more efficient Energy Boost.

### Energy growth

| Passive | Effect | Unlock | Max copies | Tiles | Icon |
|---------|--------|--------|------------|-------|------|
| Focused Growth | Every 5th activation, an Energy card on this segment permanently gains +1 Energy for the run. Extra copies on the same segment add another +1. | Trigger one Energy card 8 / 25 times in a single run | 2 | 1 | Energy pip with a sprout |
| Accelerated Growth | Every 5th activation, an Energy card permanently gains +3 Energy for the run. | Get one Energy card to +30 bonus Energy in one run | 1 | 3 | Crystalline sprout |

### Mult growth

Same cadence as Energy growth, but fractional. On a 2.0 Mult card, +0.1 per tick is about +5% of that card.

| Passive | Effect | Unlock | Max copies | Tiles | Icon |
|---------|--------|--------|------------|-------|------|
| Ratio Step | Every 5th activation, a Mult card on this segment permanently gains +0.1 Mult for the run. Extra copies add another +0.1. | Trigger one Mult card 8 / 25 times in a single run | 2 | 1 | Mult diamond with a sprout |
| Ratio Cascade | Every 5th activation, a Mult card permanently gains +0.3 Mult for the run. | Get one Mult card to +1.5 bonus Mult in one run | 1 | 3 | Stacked Mult diamonds |

### Support echo

| Passive | Effect | Unlock | Max copies | Tiles | Icon |
|---------|--------|--------|------------|-------|------|
| Second Wind | Each Support activation has an independent 2% retrigger chance. | 80 / 500 / 1,800 lifetime Support triggers | 3 | 1 | Blue looping arrow |
| Encore Engine | Each Support activation has an independent 7% retrigger chance. | Cause 20 Support retriggers in one run | 1 | 2 | Support sigil with echo rings |

### Producer echo

| Passive | Effect | Unlock | Max copies | Tiles | Icon |
|---------|--------|--------|------------|-------|------|
| Spark | Each Producer activation has an independent 2% retrigger chance. | Copy 1 starts unlocked. Copies 2 / 3: 1,000 / 3,500 lifetime Producer triggers | 3 | 1 | Small orange spark |
| Spark Surge | Each Producer activation has an independent 7% retrigger chance. | 40 Producer retriggers across runs, or 50 card triggers in a single turn | 1 | 2 | Forked bolt over a card |

### Opening

+15% (not +25%) so these do not beat 1-tile specialists on a 1-tile segment. Head Start / Empowered Output still apply to whichever product the first Producer is (Energy, Mult, or Gold).

| Passive | Effect | Unlock | Max copies | Tiles | Icon |
|---------|--------|--------|------------|-------|------|
| Head Start | The first Producer activated on this segment each turn gains +15% output. | Complete 2 / 10 runs (wins not required) | 2 | 1 | Card beside a starting flag |
| Empowered Output | The first Producer activated on this segment each turn is Empowered. | Win a run on Difficulty 5 (any layout) | 1 | 3 | Radiant opening card |

### Closing

Symmetric to opening. Strong on long rows/columns and on the last ring of a spiral.

| Passive | Effect | Unlock | Max copies | Tiles | Icon |
|---------|--------|--------|------------|-------|------|
| Last Word | The last Producer activated on this segment each turn gains +15% output. | 200 / 1,200 lifetime Producer triggers that were the last Producer in their segment | 2 | 1 | Card at a finish line |
| Final Flourish | The last Producer activated on this segment each turn is Empowered. | Win a run on Difficulty 4 (any layout) | 1 | 3 | Curtain-call spotlight on a card |

### Gold

| Passive | Effect | Unlock | Max copies | Tiles | Icon |
|---------|--------|--------|------------|-------|------|
| Gilded Contact | Gold cards have an independent 25% chance to produce +1 Gold. | Earn 20 gold in one run / hold 25 gold at once | 2 | 1 | Coin-tipped card |
| Minting Press | Gold cards always produce +1 Gold. | Win on Difficulty 4 while holding at least 40 Gold | 1 | 3 | Card pressed into a coin |

### Protection

For Overcharge, Unstable, Break Glass, Replication, Gluttonous.

| Passive | Effect | Unlock | Max copies | Tiles | Icon |
|---------|--------|--------|------------|-------|------|
| Safety Fuse | A card that would break has an independent 20% chance to ignore the break. | Lose 5 / 20 cards to break effects | 2 | 1 | Intact glowing fuse |
| Aegis Matrix | A card that would break has a 50% chance to ignore the break. | Prevent 20 breaks while Safety Fuse is placed on a loadout | 1 | 3 | Shielded hex card |

### Sequencing

Supports do not interrupt the product sequence.

| Passive | Effect | Unlock | Max copies | Tiles | Icon |
|---------|--------|--------|------------|-------|------|
| Alternating Current | An Energy, Mult, or Gold card gains +10% output when the preceding Energy/Mult/Gold card produced a different resource. | 40 / 200 alternating-resource activations | 2 | 1 | Two alternating coloured arrows |
| Spectrum Engine | Same condition, +25% output. | On one segment, activate Energy, Mult, and Gold during the same turn, 8 times across runs | 1 | 2 | Three-colour card prism |

### Support relay

| Passive | Effect | Unlock | Max copies | Tiles | Icon |
|---------|--------|--------|------------|-------|------|
| Relay Capacitor | After a Support activates, the next Producer gains +15% output. Each copy holds one charge. A later Support refreshes it. | Complete 40 / 200 Support-then-Producer sequences | 2 | 1 | Support linked to a battery |
| Conductor Core | The first Support activated on this segment each turn Empowers the next Producer. | Have Support effects trigger or Empower 200 Producers | 1 | 3 | Baton directing a card |

### Adjacency

Hex neighbors, same product.

| Passive | Effect | Unlock | Max copies | Tiles | Icon |
|---------|--------|--------|------------|-------|------|
| Resonant Pair | A Producer adjacent to another Producer of the same product gains +10% output. | Trigger qualifying adjacent Producers 80 / 400 times | 2 | 1 | Two matching linked cards |
| Resonant Array | A Producer with at least two adjacent Producers of the same product gains +25% output. | Fill a segment of at least six tiles with one Producer product and complete a turn | 1 | 2 | Three matching linked cards |

### Occupancy

Rewards filling a whole segment. Distinct from adjacency (full occupancy vs clusters).

| Passive | Effect | Unlock | Max copies | Tiles | Icon |
|---------|--------|--------|------------|-------|------|
| Packed Line | If every tile in this segment is occupied, Producers gain +8% output. | Complete 8 / 25 turns with at least one fully occupied segment | 2 | 1 | Hex row with no gaps |
| Saturated Field | If every tile in this segment is occupied, Producers gain +20% output. | Fill the entire map with cards and complete a turn | 1 | 2 | Fully lit hex cluster |

---

## One-tile specialists (4)

Placeable on any segment, but the effect only applies if this segment has **exactly one map tile**. Unlock tracking also only counts 1-tile segments. The Surveyor has no 1-tile segment. The others do (center, or the Columnist’s first column).

| Passive | Effect | Unlock | Max copies | Tiles | Icon |
|---------|--------|--------|------------|-------|------|
| Solo Dynamo | That card’s Energy, Mult, or Gold output +30%. | 80 activations on one-tile segments | 1 | 1 | Single card with a halo |
| Echo Chamber | Every activation has an independent 10% chance to retrigger. | 400 activations on one-tile segments | 1 | 1 | Card inside echo rings |
| Growth Capsule | Every 3rd activation, that card gains +5% personal output for the rest of the run, capped at +30%. | Trigger the same card 15 times in one run while it occupies a one-tile segment | 1 | 1 | Card inside a glass capsule |
| Anchor Ward | The first time each turn that card would break, the break is prevented. | Lose 8 cards to break effects while they occupy one-tile segments | 1 | 1 | Anchored shielded card |

---

## Layout exclusives (10)

All gated on **that layout’s level**. Copy 1 at 3, Copy 2 at 6, signature at 9. XP is per layout.

### The Surveyor (zigzag rows, 4–7 tiles)

| Passive | Effect | Unlock | Max copies | Tiles | Icon |
|---------|--------|--------|------------|-------|------|
| Sightline Calibration | A Producer gains +5% output for each occupied card activated earlier in its row, capped at +25% per copy. | Surveyor levels 3 / 6 | 2 | 1 | Telescope over a row |
| End of the Line | If every earlier occupied card in the row activated, the row’s final Producer retriggers once. Once per turn. | Surveyor level 9 | 1 | 3 | Card at the end of a ruled line |

### The Encircler (outer ring first: 18 / 12 / 6 / 1)

Useless on the outermost ring. Built for feeding inward.

| Passive | Effect | Unlock | Max copies | Tiles | Icon |
|---------|--------|--------|------------|-------|------|
| Inward Momentum | The first Producer in a ring gains +5% output per occupied card in the immediately outer ring, capped at +30% per copy. | Encircler levels 3 / 6 | 2 | 1 | Arrow entering a ring |
| Closed Orbit | After every active card in a ring of at least 6 resolves, Energy cards in that ring permanently gain +1 Energy for the run. Each qualifying ring can fire once per turn. | Encircler level 9 | 1 | 3 | Completed glowing circle |

### The Spiralist (center first, then out: 1 / 6 / 12 / 18)

Charge builds toward the outer rings.

| Passive | Effect | Unlock | Max copies | Tiles | Icon |
|---------|--------|--------|------------|-------|------|
| Coil Charge | A Producer gains +3% output per card activated earlier this turn, capped at +30% per copy. | Spiralist levels 3 / 6 | 2 | 1 | Charging spiral coil |
| Outward Pulse | After the immediately inner ring resolves, the first Producer in this ring is Empowered. Once per turn. | Spiralist level 9 | 1 | 3 | Expanding ring pulse |

### The Columnist (serpentine columns, including a 1-tile first column)

| Passive | Effect | Unlock | Max copies | Tiles | Icon |
|---------|--------|--------|------------|-------|------|
| Downstroke | A Producer gains +5% output per consecutive occupied card immediately before it in its column, capped at +25% per copy. | Columnist levels 3 / 6 | 2 | 1 | Vertical ink stroke |
| Turnaround | When the final active card in the column resolves, it Empowers the first active Producer in the next column. Once per turn. | Columnist level 9 | 1 | 3 | U-turn between two columns |

### The Converger (inward spiral, shrinking segments, 1-tile center)

| Passive | Effect | Unlock | Max copies | Tiles | Icon |
|---------|--------|--------|------------|-------|------|
| Compression Gain | A Producer gains +5% output for each outer segment fully resolved earlier this turn, capped at +30% per copy. | Converger levels 3 / 6 | 2 | 1 | Arrows compressing inward |
| Singularity | Center-only (1-tile segment): that card is Empowered, ignores break during that activation, and retriggers once per turn. | Converger level 9 | 1 | 1 | Brilliant dark-star core |

---

## Totals

42 passives: 28 global + 4 one-tile + 10 layout.

Added vs the original spreadsheet: Mult growth, Closing, Occupancy. Energy Boost / Energy Amplifier are Energy-only (renamed from Power Boost / Power Amplifier).

---

## Later implementation (not this pass)

A future implementation would need to add tracking for:

- Lifetime triggers split by Producer vs Support
- Retrigger counts
- Extra copies unlocked per passive (Copy 1 / 2 / 3)
- Per-layout XP / level
- Breaks, and breaks prevented by a placed Safety Fuse
- Gold earned this run (not only peak held)
- Alternating-product activations, Support-then-Producer sequences, adjacent same-product triggers
- Activations on 1-tile segments
- Fully occupied segment turns
- Difficulty at time of win in the run snapshot
- Float Mult on cards, segments, save data, and UI (1 decimal). Score rounded from Energy × Mult

Then wire the 42 passives as resources with real runtime effects. No `.tres` files, icons, or code in this catalog pass.
