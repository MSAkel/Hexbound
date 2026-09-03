# Events Catalog

Round modifiers on **rounds 3, 6, and 9**. The run picks three unique events at start.

Sister docs: [archetype_map.md](archetype_map.md), [tile_cards_catalog.md](tile_cards_catalog.md), [potions_catalog.md](potions_catalog.md).

## Rules

- One event is active while you play that round. It clears when the next round begins.
- **Rewrite Omen** replaces the next unstarted event with an unused type that is **legal for that round**.
- Round gates exist so early boards are not crushed by late-only laws (Blackout on round 3 is the example).

## Round gates

| Gate | Rounds | Why |
|------|--------|-----|
| Any event round | 3, 6, 9 | Fair on a thin board |
| Late | 6, 9 | Needs a developed map or engine |
| Final | 9 | Boss pressure only |

Round 3 always has five legal types, so the scheduler can always fill the first slot.

## Pool (11)

### Any event round

| Event | Effect |
|-------|--------|
| Rush Hour | −1 turn |
| Dealt Hand | One random card is dealt straight to your hand. The draft screen does not open |
| Fading Sector | Each turn, a random segment's Producer output ×0.5 |
| Austerity | `GoldManager.add` is blocked, including round-clear gold paid while this event is still active. Tokens still award |
| Jammed Belt | Condiments cannot be drunk |

### Late (rounds 6 and 9)

| Event | Effect |
|-------|--------|
| Blackout | 5 random placed cards are disabled each turn |
| Dry Wire | Extra activations and queued retriggers do not fire. Trigger-order slots still resolve |
| Null Charge | Empower still consumes, but it does not double output |
| Local Current | Segment relays and Forward Gift do not credit another segment |
| Sealed Hexes | 3 empty tiles cannot be played on for the rest of the round |

### Final (round 9)

| Event | Effect |
|-------|--------|
| Raised Stakes | Score target ×1.25 |

## Scheduling

Each slot shuffles the unused types that list that round. Unique across the three slots.

Rewrite Omen uses the same filter for the upcoming slot. If nothing unused is legal, the drink cannot be used.
