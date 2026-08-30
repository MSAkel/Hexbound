# Tile Cards Catalog

Living list of every tile card in `resources/tile_cards/`. Effect text is copied from each `.tres`. When a card changes, update this file and [archetype_map.md](archetype_map.md).

Bot pick rates: [playtest_findings.md](playtest_findings.md).

**Pool:** 63 cards (31 Producers, 25 Supports, 7 Utilities).

**Rarity weights** (`RuneLoot`): Common 55 / Uncommon 35 / Rare 10.

**Starting hand.** Locked: Power Cell, Basic Multiplier. Plus 1 common Energy with `starting_hand_eligible`, plus 2 common Supports (difficulty may trim Supports).

**Sigils.** Producers derive Energy / Mult / Gold from product. Supports set Empower, Retrigger, Segment Relay, or Growth.

Archetype tags point at [archetype_map.md](archetype_map.md). A card can wear more than one.

## Rules

- Producers occupy a hex and add Energy, Mult, Gold, or a hybrid roll.
- Supports occupy a hex and Empower, retrigger, relay, or stamp.
- Utilities resolve on placement and never occupy (Transposition targets two occupied hexes).
- Placement restrictions drop the card from packs when the layout cannot host them (`is_legal_for_layout`).
- Empower doubles the next activation, then clears. Retrigger queues another activation.

## Producers (31)

| Name | Id | R | Product | Restriction | Effect | Archetypes |
|------|----|---|---------|-------------|--------|------------|
| Power Cell | `power_cell` | C | Energy | — | +20 Energy. Locked starter. Starter-eligible. | Generic |
| Basic Multiplier | `basic_mult` | C | Mult | — | +2 Mult. Locked starter. | Generic |
| Basic Allowance | `basic_allowance` | C | Gold | — | +1 Gold. | Gold |
| Incremental | `incremental` | C | Energy | — | +5 Energy. Every 2nd trigger: permanently +5 Energy. Starter-eligible. | Growth, Retrigger |
| Rising Tempo | `rising_tempo` | C | Energy | — | +5 Energy for every trigger on this segment so far this turn. Starter-eligible. | Retrigger, Tempo |
| Spark Plug | `spark_plug` | C | Energy | — | +18 Energy. +4 if an adjacent Downstream hex is empty. Starter-eligible. | Sparse |
| Prosperity | `prosperity` | C | Energy | — | +8 Energy, plus +4 Energy per Gold produced earlier in this segment. | Gold |
| Edge Card | `edge_card` | C | Energy | Edge tile | +28 Energy. Must be placed on an edge tile. | Generic |
| Turn Up | `turn_up` | C | Mult | — | +2 Mult per current turn. | Generic |
| Aftershock | `aftershock` | U | Energy | — | +10 Energy each time this card triggers this turn. | Retrigger, Tempo |
| Backed Current | `backed_current` | U | Energy | — | +20 Energy. If the previous card in trigger order is a Support, retrigger this card once. | Retrigger, Empower |
| Compact Power | `compact_power` | U | Mult | — | +6 Mult if this segment has 7 tiles or fewer. | Sparse |
| Advanced Pointer | `advanced_pointer` | U | Energy | — | +14 Energy per adjacent Downstream Energy card. +20 if 2 or more. | Cluster |
| Advanced Mult | `advanced_mult` | U | Mult | — | +4 Mult, increased by 1 for each Mult card on the same segment. | Cluster |
| Overcharge | `overcharge` | U | Energy | — | +60 Energy. +10% break chance after every completed trigger this turn. | Break, Tempo |
| Treasury | `treasury` | U | Energy | — | +6 Energy, plus +1 Energy for every Gold you have. | Gold |
| Golden Ratio | `golden_ratio` | U | Mult | — | +3 Mult. Gain +1 Mult for each Gold spent this round. | Gold |
| Opening Volt | `opening_volt` | U | Energy | — | +24 Energy if this is the first Producer in the segment, otherwise +8 Energy. | Bookend |
| Last Surge | `last_surge` | U | Energy | — | +24 Energy if this is the last Producer in the segment, otherwise +8 Energy. | Bookend |
| Open Circuit | `open_circuit` | U | Energy | — | +3 Energy per empty tile in this segment, up to 30. | Sparse |
| Census Cell | `census_cell` | U | Energy | — | +12 Energy for every segment on the map. | Generic |
| Relay Sink | `relay_sink` | U | Energy | — | +12 Energy per segment that has already received a relay this turn. | Relay |
| Wide Ratio | `wide_ratio` | U | Mult | — | +2 Mult per other segment that contains a Producer. | Generic |
| Salvage Core | `salvage_core` | U | Energy | — | +15 Energy. When another card in this segment breaks, permanently +10 Energy. | Break, Growth |
| Turntake | `turntake` | U | Energy | — | +8 Energy. If this activation is Empowered, also +4 Mult. | Empower |
| Run-On | `run_on` | U | Energy | — | +10 Energy, plus +5 Energy per consecutive Energy Producer immediately before this card. | Cluster |
| Lucky Draw | `lucky_draw` | R | Hybrid | — | 3% stacking chance to gain 400 Energy or 8 Gold. Resets on success. | Gold |
| Unstable Concoction | `unstable_concoction` | R | Hybrid | — | Gives 80 Energy or 12 Mult or 6 Gold. | Gold |
| Lone Cell | `lone_cell` | R | Energy | One-tile segment (layout must have size 1) | +80 Energy. Must be placed on a 1-tile segment. | Solo |
| Tall Cell | `tall_cell` | R | Energy | — | +10 Energy per other segment with no Producer. | Sparse |
| Gluttonous Rune | `gluttonous_rune` | R | Energy | — | +30 Energy. Consume the next card to permanently double this card's Energy. | Break, Growth |

## Supports (25)

| Name | Id | R | Sigil | Restriction | Effect | Archetypes |
|------|----|---|-------|-------------|--------|------------|
| Catalyst | `catalyst` | C | Empower | — | After 3 retriggers in this segment, Empower the next Producer. Once per turn. | Retrigger, Empower |
| Chain effect | `chain_effect` | C | Retrigger | — | Triggers the next 3 Producers, generated value reduced by 20% per jump. | Retrigger |
| Wildspark | `wildspark` | C | Retrigger | — | Trigger the earliest adjacent Downstream card. If every adjacent Downstream hex has a unique card, trigger all instead. | Retrigger, Cluster |
| Pair Bond | `pair_bond` | C | Retrigger | — | Retrigger one adjacent Downstream card in this segment. Twice if that card is the same rarity. | Retrigger, Cluster |
| Lead-In | `lead_in` | C | Retrigger | — | Retrigger the first Producer in the next segment. | Relay, Bookend |
| Helping Hand | `helping_hand` | C | Growth | — | Gives the lowest Downstream Energy producer +5 permanently. | Growth, Cluster |
| Radiant Link | `radiant_link` | C | Growth | — | Up to 3 adjacent Downstream Energy cards permanently gain +3 Energy. | Growth, Cluster |
| Segment Bond | `segment_bond` | C | Growth | — | Adjacent Downstream Energy cards in this segment permanently gain +10 Energy. | Growth, Cluster |
| Forward Energy | `forward_score` | C | Relay | — | Gives the next segment +40 Energy. | Relay |
| Forward Mult | `forward_mult` | C | Relay | — | Gives the next segment +5 Mult. | Relay |
| Load Splitter | `load_splitter` | C | Relay | — | This segment +15 Energy. Next segment +2 Mult. | Relay |
| Mirror Copy | `mirror_copy` | C | — | — | Copy the card on the opposite side of the map. | Copy |
| Imprint | `imprint` | C | — | — | Copies the effects of the two tiles directly before this one. | Copy |
| Replication | `replication` | C | — | — | Adds a random common card to your hand. Breaks after 3 triggers. | Break, Copy |
| Endless Power | `endless_power` | U | Empower | — | Empowers a Producer for every active empowerment. | Empower |
| Final Call | `final_call` | U | Empower | — | On the final turn, Empower every Downstream Producer in this segment. | Empower, Bookend |
| Great Value | `great_value` | U | Empower | — | Spend 1 Gold to Empower a random Downstream Producer in this segment. | Gold, Empower |
| Overdrive | `overdrive` | U | Retrigger | — | Triggers the next card in trigger order twice. Can only be activated once per turn from trigger order. | Retrigger |
| Random Selection | `random_selection` | U | Retrigger | — | Triggers two random cards on Downstream segments. | Retrigger |
| Break Glass | `break_glass` | U | Retrigger | — | Triggers every card on its segment. Breaks immediately. | Break, Retrigger |
| Breaker Coil | `breaker_coil` | U | Retrigger | — | If a card has broken on this segment this turn, retrigger the next Producer. | Break, Retrigger |
| Share Load | `share_load` | U | Relay | — | Relay 45% of this segment's Energy pile and 20% of its bonus Mult to the next segment. | Relay |
| Initial Encore | `initial_encore` | R | Retrigger | First tile of a segment | Triggers the first card of each Downstream segment. Must be placed on a first segment tile. | Retrigger, Bookend |
| Final Encore | `final_encore` | R | Retrigger | Last tile of a segment | Triggers the last card of each Downstream segment. Must be placed on a last segment tile. | Retrigger, Bookend |
| Unstable Rune | `unstable_rune` | R | Retrigger | — | Trigger adjacent Downstream Producers. 10% chance this card breaks per adjacent Downstream Producer. | Retrigger, Cluster, Break |

## Utilities (7)

| Name | Id | R | Effect | Archetypes |
|------|----|---|---------|------------|
| Returnus Cardus | `returnus_cardus` | C | Returns the card of the selected tile to your hand. | Copy |
| Transformus Cardus | `transformus_cardus` | C | Transforms a played card into a random same-rarity card. | Copy |
| Card Extraction | `card_extraction` | U | Breaks target card then gain a random card. | Break, Copy |
| Gold Extraction | `gold_extraction` | U | Breaks target card then gain 6 Gold. | Break, Gold |
| Clonus Cardus | `clonus_cardus` | U | Clones the card of the selected tile. | Copy |
| Transposition | `transposition` | U | Swap two placed cards. | Copy |
| Transformus Upgradus | `transformus_upgradus` | R | Transforms a played card into a random higher-rarity card. | Copy |

## Counts by archetype

Primary tags only (a card can sit in more than one row).

| Archetype | Producers | Supports | Utilities | Read |
|-----------|-----------|----------|-----------|------|
| Empower Burst | 2 (Turntake, Backed Current) | 4 | 0 | Thin payoff |
| Retrigger Engine | 3 | 10 | 0 | Dense |
| Segment Relay | 1 (Relay Sink) | 5 | 0 | Thin payoff |
| Downstream Cluster | 3 | 5 | 0 | Energy-only |
| Bookend | 2 | 5 | 0 | No Mult bookend |
| Break Cycle | 3 | 4 | 2 | Thin payoff |
| Gold Ledger | 5 | 1 | 1 | One real Gold Producer |
| Solo Cell | 1 | 0 | 0 | Nascent |
| Sparse | 4 | 0 | 0 | Producer-only |
| Growth stamps | 3 | 3 | 0 | No Mult stamp card |
| Copy / mutate | 0 | 3 | 7 | Do not add more |

## Starter-eligible Energy commons

`power_cell`, `incremental`, `rising_tempo`, `spark_plug`.

Locked regardless of eligibility: `power_cell`, `basic_mult`.

## Layout gates

| Card | Gate | Missing on |
|------|------|------------|
| Lone Cell | Segment of size 1 | Surveyor |
| Initial Encore | First tile of a segment | None (every layout has one) |
| Final Encore | Last tile of a segment | None |
| Edge Card | Map edge | None |

Compact Power has no layout gate. It simply fails on segments larger than 7 (Encircler outer ring, Spiralist outer ring).
