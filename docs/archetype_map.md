# Archetype Map

Named builds for the current tile-card pool. Use this when balancing, adding cards, or writing unlock gates.

Keep this file in sync with [tile_cards_catalog.md](tile_cards_catalog.md) and [segment_passives_catalog.md](segment_passives_catalog.md). Card text lives on the `.tres`. This file records **intent**.

## How to read a build

- **Core** — the build does not exist without these
- **Enabler** — makes the core fire more often or more safely
- **Payoff** — turns the engine into Energy × Mult
- **Trap** — looks on-theme but fights the plan
- **Hole** — a job this build still cannot hire a card for

Roles are design labels, not code tags.

## Primary builds

Seven ways to win a 9-round run with cards that already exist.

### 1. Empower Burst

Double a Producer, then make sure that doubled hit actually happens.

**Plan.** Sequence Supports so Empower lands on a high-value Producer just before it resolves. Stack extra Empowers (Endless Power) or spend Gold (Great Value) so more than one Producer doubles.

| Role | Cards |
|------|--------|
| Core | Endless Power, Catalyst, Great Value, Final Call |
| Payoff | Turntake (the only Producer that pays extra *because* it was Empowered), any fat Energy/Mult Producer |
| Enabler | Opening Volt / Last Surge as bookend targets, Baton / Opening Round / Closing Round potions |
| Trap | Empowering a Gold card or a tiny starter while a 60-Energy Overcharge sits later in order |

**Passives.** Empowered Output, Final Flourish, Conductor Core, Relay Capacitor (Support then Producer).

**Layouts.** Any. Strongest where you can see the first and last Producer in a segment (Surveyor rows, Columnist columns).

**Holes.**

- Almost no Producers care that they were Empowered. Turntake is the only one that adds Mult on an Empowered hit.
- No "Empower stays" or "Empower the whole segment" card. That is intentional (potions already cover first/last-all-segments).

### 2. Retrigger Engine

Score is activations × output. Extra triggers beat bigger base numbers.

**Plan.** Place Overdrive, Chain Effect, Wildspark, Pair Bond, or the Encore pair so key Producers fire twice or more. Aftershock and Rising Tempo then scale with those extra hits. Catalyst converts three retriggers into Empower, which is the bridge into Empower Burst.

| Role | Cards |
|------|--------|
| Core | Overdrive, Chain Effect, Wildspark, Pair Bond, Initial Encore, Final Encore |
| Payoff | Aftershock, Rising Tempo, Incremental (grows on every 2nd trigger) |
| Enabler | Lead-In, Random Selection, Unstable Rune, Break Glass, Backed Current (retriggers itself after a Support) |
| Trap | Overdrive on a Support that then fails. Unstable Rune wiping the cluster it just retriggered. Break Glass emptying the segment you wanted to grow |

**Passives.** Spark, Spark Surge, Second Wind, Encore Engine, Echo Chamber (one-tile).

**Layouts.** Spiralist Coil Charge loves a long trigger chain. Encircler / Spiralist Encore cards hit many segments. Columnist one-tile plus Echo Chamber is a mini version of this.

**Holes.**

- No Support that retriggers *this segment's* Producers without breaking (Break Glass is the all-in version).
- No Mult Producer that scales with retrigger count (Aftershock is Energy-only).

### 3. Segment Relay

This segment is a battery. The next segment is the amplifier.

**Plan.** Dump Energy or Mult forward (Forward Energy, Forward Mult, Load Splitter, Share Load). Relay Sink scores from segments that already received a relay. Lead-In retriggers the next segment's opener so the forwarded pile actually gets used.

| Role | Cards |
|------|--------|
| Core | Forward Energy, Forward Mult, Load Splitter, Share Load |
| Payoff | Relay Sink |
| Enabler | Lead-In, Forward Gift potion |
| Trap | Relaying into an empty next segment. Surveyor last row and Encircler center have nowhere to send |

**Passives.** Relay Capacitor, Conductor Core.

**Layouts.** Surveyor (row to row) and Columnist (column to column) are the clean pipelines. Encircler relays inward. Spiralist relays outward. Converger compresses into the center.

**Holes.**

- Relay Sink is the only Producer that *cares* a relay happened.
- No Gold relay. No "relay retriggers" Support.
- Share Load copies a fraction of the pile. There is no "send the whole pile and zero this segment" nuke.

### 4. Downstream Cluster

Hex neighbors in trigger order. Same-product clumps. Growth stamps that hop to adjacent Energy.

**Plan.** Sit Energy Producers on adjacent Downstream hexes. Advanced Pointer scores the cluster. Radiant Link and Segment Bond stamp +Energy onto those neighbors. Pair Bond and Wildspark retrigger inside the clump. Run-On wants a consecutive Energy chain immediately before it.

| Role | Cards |
|------|--------|
| Core | Advanced Pointer, Radiant Link, Segment Bond, Run-On, Pair Bond |
| Payoff | Advanced Pointer, Run-On, Advanced Mult (Mult cards sharing a *segment*, not a hex) |
| Enabler | Wildspark, Unstable Rune, Helping Hand, Spark Plug (wants one empty Downstream hex, fights a full cluster) |
| Trap | Spark Plug and Open Circuit, which want empty tiles. Unstable Rune's break chance per neighbor |

**Passives.** Resonant Pair, Resonant Array, Packed Line, Saturated Field.

**Layouts.** Surveyor rows and Columnist columns make adjacency line up with trigger order. Encircler's outer ring is a huge cluster. Converger arcs are mixed.

**Holes.**

- Cluster tools are Energy-only. No "adjacent Downstream *Mult*" Producer or stamp.
- Resonant Pair/Array passives buff any same-product adjacency, but almost no Mult cards are written to sit together on purpose.
- No "count occupied neighbors, any product" Producer besides the Energy path.

### 5. Bookend

First Producer and last Producer in a segment are special seats.

**Plan.** Put Opening Volt or a stamped Energy card in seat one. Put Last Surge or a Mult card in seat last. Initial Encore / Final Encore / Final Call / Lead-In exist to fire or Empower those seats across segments. Potions Opening Round and Closing Round are the map-wide version.

| Role | Cards |
|------|--------|
| Core | Opening Volt, Last Surge, Initial Encore, Final Encore, Final Call, Lead-In |
| Payoff | Opening Volt, Last Surge (both still give a small amount when not in the seat) |
| Enabler | Opening Round, Closing Round, Baton potions |
| Trap | Filling a segment so the "first Producer" is a cheap Basic Allowance. Initial Encore on a layout with tiny first tiles you cannot spare |

**Passives.** Head Start, Last Word, Empowered Output, Final Flourish. Layout: End of the Line, Outward Pulse, Turnaround, Singularity.

**Layouts.** Every layout has first/last seats. Surveyor End of the Line and Columnist Turnaround are the dedicated finishers. Converger Singularity is a one-tile bookend at the center.

**Holes.**

- No first/last *Mult* Producer (Opening Volt and Last Surge are Energy).
- No "middle of segment" identity. Compact Power is size-based, not position-based.

### 6. Break Cycle

Breaking is a resource. Grow, retrigger, or cash out when something dies.

**Plan.** Overcharge and Unstable Rune threaten to break. Break Glass and Gluttonous Rune break on purpose. Salvage Core permanently grows when a neighbor dies. Breaker Coil retriggers the next Producer after a break. Ward potion and Safety Fuse keep the cards you still need.

| Role | Cards |
|------|--------|
| Core | Overcharge, Break Glass, Gluttonous Rune, Salvage Core, Breaker Coil |
| Payoff | Salvage Core, Gluttonous Rune (consumed cards double its Energy), Gold Extraction |
| Enabler | Replication (breaks itself after 3), Unstable Rune, Card Extraction, Ward potion |
| Trap | Breaking Salvage Core itself. Gluttonous eating the payoff you needed. Break Glass on a segment you still need next turn |

**Passives.** Safety Fuse, Aegis Matrix, Anchor Ward (one-tile).

**Layouts.** Any. One-tile breaks are harsher (Anchor Ward exists because of that). Dense Surveyor rows make Salvage Core easy to feed.

**Holes.**

- Salvage Core and Breaker Coil are the only on-board *payoffs* for a break. Thin layer.
- No Mult or Gold Producer that grows on breaks.
- No "break this to Empower the rest" Support besides Break Glass's full-segment retrigger.

### 7. Gold Ledger

Gold is shop fuel and a scoring stat. A few cards treat the wallet as Energy or Mult.

**Plan.** Produce Gold (Basic Allowance, Lucky Draw, Unstable Concoction, Gold Extraction, Mint Sip). Spend it (Great Value, merchant, Golden Ratio). Convert the pile into Energy (Treasury) or convert Gold produced earlier in the segment (Prosperity).

| Role | Cards |
|------|--------|
| Core | Basic Allowance, Treasury, Prosperity, Golden Ratio, Great Value |
| Payoff | Treasury, Prosperity, Golden Ratio |
| Enabler | Lucky Draw, Unstable Concoction, Gold Extraction, Mint Sip, Gilded Contact / Minting Press |
| Trap | Spending the wallet Treasury wanted to count. Taxation challenge vs Support-heavy Gold plans |

**Passives.** Gilded Contact, Minting Press.

**Layouts.** Neutral. Merchant-heavy difficulties (4+) fight this. Difficulty 3 starts at 0 Gold.

**Holes.**

- Basic Allowance is the only dedicated Gold Producer (`+1` per trigger). That is not a build, it is a trickle.
- No "Gold per adjacent Gold" or "Gold retrigger" card.
- Great Value is the only Support that *spends* Gold for a board effect.

This is the weakest of the seven. Treat new Gold cards as filling this hole, not as flavor.

## Engines and tools (not win conditions)

These feed several primary builds. Do not count them as a eighth "build" until they have a dedicated payoff.

### Growth stamps

Permanent `+Energy` or `+Mult` on a placed card.

**Cards.** Incremental, Helping Hand, Radiant Link, Segment Bond, Salvage Core, Gluttonous Rune.

**Passives.** Focused Growth, Accelerated Growth, Ratio Step, Ratio Cascade, Closed Orbit (Encircler).

Growth is how commons stay relevant into round 9. Every primary build wants at least one stamp.

**Hole.** No Support that stamps Mult onto a Mult Producer (passives do this, cards do not).

### Sparse board

Leave tiles empty on purpose.

**Cards.** Open Circuit, Spark Plug, Tall Cell, Compact Power (segment of 7 or fewer).

**Fights.** Packed Line, Saturated Field, Resonant Array, Census Cell / Wide Ratio (those two want the map *populated*, not empty).

**Hole.** No Support that rewards empty hexes. Sparse is Producer-only.

### Tempo (triggers this turn)

**Cards.** Rising Tempo, Aftershock, Overcharge (break chance per completed trigger), Catalyst (3 retriggers).

**Passives.** Coil Charge (Spiralist).

This is Retrigger Engine's scoring layer. Aftershock is Uncommon, Rising Tempo is a starter-eligible common. Healthy.

### Copy and mutate

Board tools. They enable other builds.

**Cards.** Mirror Copy, Imprint, Clonus Cardus, Transformus Cardus, Transformus Upgradus, Transposition, Returnus Cardus, Card Extraction.

Do not add more of these until Producers need them. Seven utilities is already a lot of hand clutter.

## Nascent: Solo Cell

One-tile segments exist on Columnist (size 1), Encircler (center), Spiralist (center), and Converger (center).

**Cards.** Lone Cell is the only card that *must* sit on a 1-tile segment.

**Passives.** Solo Dynamo, Echo Chamber, Anchor Ward, Growth Capsule (intended), Singularity (Converger center).

**Hole.** No one-tile Mult. No one-tile Support. No "this card is better on size 1 but legal elsewhere" middle ground besides Lone Cell's hard gate.

Do not call this a primary build until it has a second payoff.

## Layout fit (quick)

| Layout | What it wants | What it starves |
|--------|---------------|-----------------|
| Surveyor | Relay row-to-row, clusters along a row, bookends, Packed Line | Lone Cell (no size-1 segment) |
| Encircler | Outer-ring cluster, relay inward, Closed Orbit growth, Initial Encore on the rim | Forwarding off the center. Huge size-18 ring fights Compact Power |
| Spiralist | Retrigger chains (Coil Charge), relay outward, Outward Pulse Empower | Same as Encircler, reversed |
| Columnist | Solo Cell on the size-1 column, Downstroke occupied streaks, Turnaround Empower | Wide rings. Compact Power is easy (all columns ≤ 7) |
| Converger | Compression Gain, Singularity center, relay into the middle | Sparse Tall Cell (center wants a Producer) |

## Cross-build bridges (keep these)

These cards exist to glue two primaries together. Do not nerf them into one silo.

- **Catalyst** — Retrigger → Empower
- **Turntake** — Empower → Mult
- **Backed Current** — Support sitting immediately before a Producer → self-retrigger
- **Great Value** — Gold → Empower
- **Breaker Coil** — Break → Retrigger
- **Lead-In** — Relay → Retrigger the next segment's opener
- **Share Load / Load Splitter** — this segment's pile → next segment

## What not to add yet

Until pick-rate data exists (next todo), prefer filling **Holes** above over:

- Another flat Energy common
- Another generic retrigger Support
- Another utility
- A sixth layout

Highest-value card jobs, in order:

1. A real Gold Producer (Gold Ledger is not playable)
2. A break payoff that is not Salvage Core (Break Cycle is too thin)
3. An Empowered-conditional Producer besides Turntake
4. A Mult-cluster card (adjacency is Energy-only)
5. A second Solo Cell payoff
6. A Relay Sink sibling (Gold or Mult that cares about relays)
