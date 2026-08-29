# Tile Cards Catalog

Design lock for card identities, numbers, rarities, targeting rules, and the first-wave additions. Implement against this file.

Treat **Score** in old copy as **Energy**. Turn score is `round(Energy × Mult)` per segment.

---

## Design rules

- **Downstream.** Later in trigger order. Card copy says **adjacent Downstream** when only touching hexes that fire after this card count. Passives stay omnidirectional adjacent.
- **Resolved segment.** After a segment finishes its natural trigger pass, nothing retriggers cards on it for the rest of the turn. Downstream segments may be pre-fired. Same-segment retrigger is legal while the segment is still open.
- **Forward targeting.** Card-driven retriggers and this-turn buffs hit Downstream cards unless the effect is a persistent status (Endless Power) or a player-chosen utility.
- **Imprint** copies the two tiles directly before this hex. It does not re-fire those hexes.
- **Break Glass** retriggers this open segment, then breaks.
- **Layout loot.** Cards that cannot function on a layout are omitted from that layout’s packs, shop, and starting filler. Requirements are size-based, not layout ids.
- **Starter Energy** sits in one power band. No hidden best common Energy.

---

## Round targets

- R1 450, R2 1600, R3 3600
- R4–9 unchanged: 6937, 11155, 17482, 26973, 41209, 62563
- Endless from R10 unchanged

---

## Starting hand

- Guaranteed: Power Cell, Basic Mult
- Filler: 1 random common Energy producer with `starting_hand_eligible`, excluding the guaranteed ids
- 2 random common supports (Diff 2+ trims a support)

Starter-eligible Energy: Power Cell (guaranteed, not in filler), Incremental, Rising Tempo, Spark Plug.

---

## Keywords

- **Downstream** — later in trigger order. **Adjacent Downstream** — a touching hex that fires after this card.
- **Next** — the next card in global trigger order, not necessarily adjacent

---

## Existing cards (retunes)

Gold identity stays. Golden Ratio is removed.

### Producers

- **Power Cell** Common Energy +20. Guaranteed starter.
- **Basic Mult** Common Mult +2. Guaranteed starter.
- **Basic Allowance** Common Gold +1. Not starter-eligible.
- **Incremental** Common Energy +5, +5 permanent every 2nd trigger. Starter-eligible.
- **Rising Tempo** Common Energy +5 × segment triggers so far this turn. Starter-eligible.
- **Edge Card** Common Energy +28, edge only.
- **Turn Up** Common Mult +2 × current turn number.
- **Prosperity** Common Energy +8, plus +4 per Gold already produced on this segment.
- **Compact Power** Uncommon Mult +6 if segment size is less than 6.
- **Treasury** Uncommon Energy +6, plus +1 per Gold held.
- **Advanced Mult** Uncommon. Unchanged identity.
- **Advanced Pointer** Uncommon Energy. +14 per adjacent Downstream Energy card. +20 extra if 2 or more. Counts Energy product, not Producer type.
- **Golden Ratio** Removed.
- **Overcharge** Uncommon Energy +60. +10% break chance per completed trigger this turn.
- **Gluttonous Rune** Rare. Unchanged identity.
- **Lucky Draw** Rare. 3% stacking. 400 Energy or 8 Gold. Resets on success.
- **Unstable Concoction** Rare. 80 Energy or 12 Mult or 6 Gold.

### Supports

- **Radiant Link** Common. Up to 3 adjacent Downstream Energy cards permanently gain +3 Energy.
- **Segment Bond** Common. Adjacent Downstream same-segment Energy cards permanently gain +10 Energy.
- **Wildspark** Common. Trigger the earliest adjacent Downstream card. If every adjacent Downstream hex is occupied by a unique card id, trigger all instead.
- **Chain Effect** Common. Next 3 Producers, 20% less output per jump.
- **Overdrive** Uncommon. Trigger the next card in trigger order twice. Once per turn from trigger order. Copy must not say adjacent.
- **Helping Hand** Common. Lowest Downstream Energy producer gains +5 Energy permanently.
- **Great Value** Uncommon. Spend 1 Gold to empower a random Downstream Producer on this segment.
- **Final Call** Uncommon. On the final turn, empower every Downstream Producer on this segment.
- **Forward Energy** Common. Next segment +40 Energy. Product is Energy.
- **Forward Mult** Common. Next segment +5 Mult.
- **Catalyst** Common. Unchanged identity.
- **Endless Power** Uncommon. Unchanged. Empower may include earlier Producers.
- **Break Glass** Uncommon. Retrigger every other card on this segment, then break.
- **Random Selection** Uncommon. Trigger two random cards on Downstream segments.
- **Unstable Rune** Rare. Trigger adjacent Downstream Producers. 10% break chance per adjacent Downstream Producer. No wrap to earlier cards.
- **Initial Encore** Rare. First-tile only. Trigger the first card of each Downstream segment.
- **Final Encore** Rare. Last-tile only. Trigger the last card of each Downstream segment.
- **Imprint** Uncommon. Copy the effects of the two tiles directly before this one.
- **Mirror Copy** Common. Unchanged.
- **Replication** Common. Unchanged.

### Utilities

- **Gold Extraction** Uncommon. Break target, gain 6 Gold.
- **Returnus / Clonus / Transformus / Card Extraction / Transformus Upgradus** Unchanged identities.

---

## First-wave new cards

### Producers

- **Spark Plug** `spark_plug` Common Energy, starter-eligible. +18 Energy, +4 if an adjacent Downstream hex is empty.
- **Aftershock** `aftershock` Uncommon Energy. +10 Energy each time this card triggers this turn.
- **Opening Volt** `opening_volt` Uncommon Energy. +24 if this is the first Producer in the segment, else +8.
- **Last Surge** `last_surge` Uncommon Energy. +24 if this is the last Producer in the segment, else +8.
- **Turntake** `turntake` Uncommon Energy. +8 Energy, plus +4 Mult if this activation is Empowered.
- **Census Cell** `census_cell` Uncommon Energy. +5 Energy per segment on the map.
- **Salvage Core** `salvage_core` Uncommon Energy. +15 Energy. When another card in this segment breaks, permanently +10 Energy.
- **Lone Cell** `lone_cell` Rare Energy +80. 1-tile segment only. Requires a 1-tile segment on the layout (Surveyor excluded from loot).
- **Long Line** `long_line` Uncommon Energy. +3 Energy per tile in this segment, cap 30.
- **Open Circuit** `open_circuit` Uncommon Energy. +3 Energy per empty tile in this segment, cap 30.
- **Backed Current** `backed_current` Uncommon Energy. +20 Energy. If the previous card in trigger order is a Support, retrigger this card once.
- **Wide Ratio** `wide_ratio` Uncommon Mult. +1 Mult per other segment that contains a Producer.
- **Run-On** `run_on` Uncommon Energy. +10 Energy, plus +5 per consecutive Energy Producer immediately before this card.
- **Tall Cell** `tall_cell` Rare Energy. +10 Energy per other segment with no Producer.
- **Relay Sink** `relay_sink` Uncommon Energy. +12 Energy per segment that has already received a relay this turn.

### Supports

- **Load Splitter** `load_splitter` Common Segment Relay. This segment +15 Energy, next segment +2 Mult.
- **Breaker Coil** `breaker_coil` Uncommon Retrigger. If a card has broken on this segment this turn, retrigger the next Producer.
- **Pair Bond** `pair_bond` Common Retrigger. Retrigger one adjacent Downstream card in this segment. Twice if that card is the same rarity.
- **Lead In** `lead_in` Common Retrigger. Retrigger the first Producer of the next segment.
- **Cadence** `cadence` Rare Retrigger. If this segment has 7+ tiles, retrigger every fourth Downstream Producer in this segment.
- **Share Load** `share_load` Uncommon Segment Relay. Relay 30% of this segment’s Energy pile so far to the next segment.

### Utility

- **Transposition** `transposition` Uncommon. Swap two placed cards. Two-step target.

No extra 1-tile cards this pass.

---

## Layout sizes (hex radius 3)

- Surveyor: 4, 5, 6, 7, 6, 5, 4
- Columnist: 1, 3, 5, 7, 7, 7, 7
- Converger: 9, 9, 6, 6, 3, 4 (1-tile center if the last start is its own segment — treat as having a 1-tile)
- Spiralist / Encircler: 1, 6, 12, 18
