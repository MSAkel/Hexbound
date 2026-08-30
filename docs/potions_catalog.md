# Potions Catalog

Merchant drinks stored on a 3-slot belt. They are not hand cards. Utilities stay in the hand.

## Rules

- Shop offers **3 potions** and **3 tile cards** each visit.
- Belt holds **3** potions. A full belt cannot buy more.
- Right-click a filled belt slot, then **Remove**. No refund. Fuses already on tiles keep running.
- Tile drinks leave a visible fuse, then clear. No run-long hex stamps.
- Segment-wide drinks hit **one Producer per segment** (first or last). They do not retrigger a whole row.
- Challenge drinks rewrite the **next unstarted** challenge. They never mute the active law.
- **Potion Pack** cannot roll itself. After drinking it, only empty belt slots fill. Extra rolls are lost.

## Fairness

If two layouts drink the same potion, affected activations must not grow with segment length.

## Locked list (13)

Working names. Gold amounts and prices can be tuned later.

### Instant

| Potion | Effect |
|--------|--------|
| Gold Drop | Gain 8 Gold. |
| Borrowed Time | Extra turn this round. Rush Hour still stole its turn. |
| Rewrite Omen | Replace the upcoming challenge with a type not already on the calendar. |
| Free Reroll | +1 shared draft and merchant reroll. |
| Potion Pack | Gain 3 random potions from the other 12. Fill empty slots only. |

### Tile, next activation

| Potion | Effect |
|--------|--------|
| Empower | Empowers that card. |
| Echo | That card retriggers once after its next activation. |
| Ward | Ignore the next break on that card. |
| Baton | That card’s next activation Empowers the next Producer in trigger order. |

### Tile, 2 turns

| Potion | Effect |
|--------|--------|
| Forward Gift | For 2 turns, each product from that card is also relayed to the next segment. |
| Mint Sip | For 2 turns, each activation also produces +1 Gold. |

The drink’s turn counts if you drink before Resolve. A leftover turn carries into the next round.

### Map, this turn

| Potion | Effect |
|--------|--------|
| Opening Round | First Producer in every segment is Empowered. |
| Closing Round | Last Producer in every segment is Empowered. |

## Rejected

First Pour, whole-segment encore or double Score, unbreak, and any drink that weakens the current challenge.
