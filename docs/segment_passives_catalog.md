# Segment Passives Catalog

Living list of every segment passive in `resources/segment_passives/`. Effect text is copied from each `.tres`. When a passive changes, update this file and [archetype_map.md](archetype_map.md).

**Active:** 40 (30 global, 10 layout-exclusive). **Retired:** 3 (`spark_surge`, `steady_growth`, `power_boost`). Retired ids are stripped from saves and replaced by the migrations in `MetaProgressionManager`.

Passives are the meta loadout. Three sets (A/B/C) per layout, placed on segments before the run. Copies, tile cost, and layout level gate what can sit on the map.

Archetype tags point at [archetype_map.md](archetype_map.md).

## Rules

- Empty `character_id` means global. Non-empty means that layout only.
- `starts_unlocked` grants the first copy with no reveal toast. Spark is the starter.
- Extra copies use `copy_thresholds` against the same unlock stat.
- Layout exclusives gate on layout level 3 / 6 (two copies) or level 9 (one copy).
- Seeded runs do not advance unlocks or layout XP.

## Global (30)

| Name | Id | Cost | Copies | Effect | Archetypes |
|------|----|------|--------|--------|------------|
| Spark | `spark` | 1 | 3 | Each Producer activation has an independent 2% retrigger chance. Starts unlocked. | Retrigger |
| Spark Surge | `spark_storm` | 2 | 1 | Each Producer activation has an independent 7% retrigger chance. | Retrigger |
| Second Wind | `second_wind` | 1 | 3 | Each Support activation has an independent 2% retrigger chance. | Retrigger |
| Encore Engine | `encore_engine` | 2 | 1 | Each Support activation has an independent 7% retrigger chance. | Retrigger |
| Energy Boost | `energy_boost` | 1 | 3 | Energy cards on this segment produce +5% Energy. | Generic |
| Energy Amplifier | `energy_amplifier` | 2 | 1 | Energy cards on this segment produce +10% Energy. | Generic |
| Head Start | `head_start` | 1 | 2 | The first Producer activated on this segment each turn gains +15% output. | Bookend |
| Last Word | `last_word` | 1 | 2 | The last Producer activated on this segment each turn gains +15% output. | Bookend |
| Empowered Output | `empowered_output` | 3 | 1 | The first Producer activated on this segment each turn is Empowered. | Empower, Bookend |
| Final Flourish | `final_flourish` | 3 | 1 | The last Producer activated on this segment each turn is Empowered. | Empower, Bookend |
| Focused Growth | `focused_growth` | 1 | 2 | Every 5th activation, an Energy card on this segment permanently gains +1 Energy for the run. | Growth |
| Accelerated Growth | `accelerated_growth` | 3 | 1 | Every 5th activation, an Energy card permanently gains +3 Energy for the run. | Growth |
| Ratio Step | `ratio_step` | 1 | 2 | Every 5th activation, a Mult card on this segment permanently gains +0.1 Mult for the run. | Growth |
| Ratio Cascade | `ratio_cascade` | 3 | 1 | Every 5th activation, a Mult card permanently gains +0.3 Mult for the run. | Growth |
| Conductor Core | `conductor_core` | 3 | 1 | The first Support activated on this segment each turn Empowers the next Producer. | Empower, Relay |
| Relay Capacitor | `relay_capacitor` | 1 | 2 | After a Support activates, the next Producer gains +15% output. Each copy holds one charge. | Relay, Empower |
| Alternating Current | `alternating_current` | 1 | 2 | An Energy, Mult, or Gold card gains +10% output when the preceding numeric card produced a different resource. | Generic |
| Spectrum Engine | `spectrum_engine` | 2 | 1 | Same alternating-resource condition grants +25% output. | Generic |
| Resonant Pair | `resonant_pair` | 1 | 2 | A Producer adjacent to another Producer of the same product gains +10% output. | Cluster |
| Resonant Array | `resonant_array` | 2 | 1 | A Producer with at least two adjacent Producers of the same product gains +25% output. | Cluster |
| Packed Line | `packed_line` | 1 | 2 | If every tile in this segment is occupied, Producers gain +8% output. | Cluster |
| Saturated Field | `saturated_field` | 2 | 1 | If every tile in this segment is occupied, Producers gain +20% output. | Cluster |
| Safety Fuse | `safety_fuse` | 1 | 2 | A card that would break has an independent 20% chance to ignore the break. | Break |
| Aegis Matrix | `aegis_matrix` | 3 | 1 | A card that would break has a 50% chance to ignore the break. | Break |
| Solo Dynamo | `solo_dynamo` | 1 | 1 | On a one-tile segment, that card's Energy, Mult, or Gold output +30%. | Solo |
| Echo Chamber | `echo_chamber` | 1 | 1 | On a one-tile segment, every activation has an independent 10% chance to retrigger. | Solo, Retrigger |
| Anchor Ward | `anchor_ward` | 1 | 1 | On a one-tile segment, the first time each turn that card would break, the break is prevented. | Solo, Break |
| Growth Capsule | `growth_capsule` | 1 | 1 | Every third activation grants +5% personal output for this run, capped at +30%. Intended for one-tile segments. | Solo, Growth |
| Gilded Contact | `gilded_contact` | 1 | 2 | Gold cards have an independent 25% chance to produce +1 Gold. | Gold |
| Minting Press | `minting_press` | 3 | 1 | Gold cards in this segment always produce +1 Gold. | Gold |

**Growth Capsule note.** Description and unlock (15 triggers of the same card on a one-tile segment) are Solo Cell. The resource currently sets `effect_type` to adjacency (`15`) instead of `ONE_TILE_PERSONAL_GROWTH` (`19`), so the runtime path in `segment_passive_runtime.gd` does not apply it. Fix the enum on the `.tres` when touching this passive.

## Layout-exclusive (10)

Gates are layout XP levels 3 / 6 (two copies) or 9 (one copy).

### The Surveyor

| Name | Id | Lv | Cost | Copies | Effect | Archetypes |
|------|----|----|------|--------|--------|------------|
| Sightline Calibration | `sightline_calibration` | 3 / 6 | 1 | 2 | A Producer gains +5% output for each occupied card activated earlier in its row, capped at +25% per copy. | Cluster |
| End of the Line | `end_of_the_line` | 9 | 3 | 1 | The row's final Producer retriggers after every earlier occupied card resolves successfully. Once per turn. | Bookend, Retrigger |

### The Encircler

| Name | Id | Lv | Cost | Copies | Effect | Archetypes |
|------|----|----|------|--------|--------|------------|
| Inward Momentum | `inward_momentum` | 3 / 6 | 1 | 2 | The first Producer in a ring gains +5% output per occupied card in the immediately outer ring, capped at +30% per copy. | Bookend, Relay |
| Closed Orbit | `closed_orbit` | 9 | 3 | 1 | After every active card in a ring of at least 6 resolves, Energy cards in that ring permanently gain +1 Energy. Once per qualifying ring per turn. | Growth, Cluster |

### The Spiralist

| Name | Id | Lv | Cost | Copies | Effect | Archetypes |
|------|----|----|------|--------|--------|------------|
| Coil Charge | `coil_charge` | 3 / 6 | 1 | 2 | A Producer gains +3% output per card activated earlier this turn, capped at +30% per copy. | Retrigger, Tempo |
| Outward Pulse | `outward_pulse` | 9 | 3 | 1 | After the immediately inner ring resolves, the first Producer in this ring is Empowered. Once per turn. | Empower, Bookend |

### The Columnist

| Name | Id | Lv | Cost | Copies | Effect | Archetypes |
|------|----|----|------|--------|--------|------------|
| Downstroke | `downstroke` | 3 / 6 | 1 | 2 | A Producer gains +5% output per consecutive occupied card immediately before it in its column, capped at +25% per copy. | Cluster |
| Turnaround | `turnaround` | 9 | 3 | 1 | When the final active card in the column resolves, it Empowers the first active Producer in the next column. Once per turn. | Empower, Bookend, Relay |

### The Converger

| Name | Id | Lv | Cost | Copies | Effect | Archetypes |
|------|----|----|------|--------|--------|------------|
| Compression Gain | `compression_gain` | 3 / 6 | 1 | 2 | A Producer gains +5% output for each outer segment fully resolved earlier this turn, capped at +30% per copy. | Relay, Tempo |
| Singularity | `singularity` | 9 | 1 | 1 | Center-only: that card is Empowered, ignores break during that activation, and retriggers once per turn. | Solo, Empower, Bookend |

## Retired (3)

Do not place. `MetaProgressionManager` migrates old saves.

| Old id | Old name | Replaced by |
|--------|----------|-------------|
| `spark_surge` | Spark (old 2% production retrigger, cost 2, 3 copies) | `spark` |
| `steady_growth` | Steady Growth | `energy_boost` |
| `power_boost` | Power Boost | `energy_boost` |

## Coverage vs card builds

| Archetype | Passive support | Gap |
|-----------|-----------------|-----|
| Empower Burst | Empowered Output, Final Flourish, Conductor Core, Outward Pulse, Turnaround, Singularity | Strong |
| Retrigger Engine | Spark, Spark Surge, Second Wind, Encore Engine, Echo Chamber, End of the Line, Coil Charge | Strong |
| Segment Relay | Relay Capacitor, Inward Momentum, Compression Gain, Turnaround | No "relayed segments score more" passive (Relay Sink has no meta twin) |
| Downstream Cluster | Resonant Pair/Array, Packed Line, Saturated Field, Sightline, Downstroke, Closed Orbit | Strong, and it fights Sparse |
| Bookend | Head Start, Last Word, Empowered Output, Final Flourish, plus every level-9 exclusive | Strong |
| Break Cycle | Safety Fuse, Aegis Matrix, Anchor Ward | All *saves*. No "on break, grow" meta. Salvage Core has no twin |
| Gold Ledger | Gilded Contact, Minting Press | Fine for the thin card layer |
| Solo Cell | Solo Dynamo, Echo Chamber, Anchor Ward, Growth Capsule, Singularity | Stronger than the card layer. Passives are waiting on a second one-tile card |
| Sparse | None | Occupancy passives punish it |
| Growth stamps | Focused / Accelerated / Ratio Step / Cascade, Closed Orbit | Strong. Cards still cannot stamp Mult |

## Prefer layout exclusives over new globals

Forty actives is already dense. New passives should be layout-exclusive identities (the way End of the Line is Surveyor-only) rather than another global +% Energy. Global holes worth a single passive: a Relay Sink twin, a break-payoff twin, nothing that further rewards filling every hex until Sparse has a card Support.
