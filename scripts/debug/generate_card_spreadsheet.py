#!/usr/bin/env python3
"""Generate tile card master spreadsheet (existing + suggested from card pass plan)."""

import csv
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT_CSV = ROOT / "docs" / "tile_cards_master_spreadsheet.csv"
OUT_XLSX = ROOT / "docs" / "tile_cards_master_spreadsheet.xlsx"

HEADERS = [
    "Status",
    "Type",
    "Rarity",
    "Name",
    "Id",
    "Product_Or_Sigil",
    "Restriction",
    "Effect",
    "Primary_Identity",
    "Secondary_Identities",
    "Starter_Eligible",
    "Layout_Gate",
    "In_First_Cut",
    "Notes",
]

# Existing cards: 62 in resources (Golden Ratio removed from repo).
EXISTING = [
    # Producers Common
    ("Existing", "Producer", "Common", "Power Cell", "power_cell", "Energy", "", "+20 Energy. Locked starter.", "Generic", "", "Yes", "", "No", "Locked starter"),
    ("Existing", "Producer", "Common", "Basic Multiplier", "basic_mult", "Mult", "", "+2 Mult. Locked starter.", "Generic", "", "No", "", "No", "Locked starter"),
    ("Existing", "Producer", "Common", "Basic Allowance", "basic_allowance", "Gold", "", "+1 Gold.", "Gold Ledger", "", "No", "", "No", "Common trickle, not main Gold Producer"),
    ("Existing", "Producer", "Common", "Incremental", "incremental", "Energy", "", "+5 Energy. Every 2nd trigger: permanently +5 Energy.", "Growth", "Retrigger Engine", "Yes", "", "No", ""),
    ("Existing", "Producer", "Common", "Rising Tempo", "rising_tempo", "Energy", "", "+5 Energy for every trigger on this segment so far this turn.", "Retrigger Engine", "Tempo", "Yes", "", "No", ""),
    ("Existing", "Producer", "Common", "Spark Plug", "spark_plug", "Energy", "", "+18 Energy. +4 if an adjacent Downstream hex is empty.", "Sparse", "", "Yes", "", "No", ""),
    ("Existing", "Producer", "Common", "Prosperity", "prosperity", "Energy", "", "+8 Energy, plus +4 Energy per Gold produced earlier in this segment.", "Gold Ledger", "", "No", "", "No", ""),
    ("Existing", "Producer", "Common", "Edge Card", "edge_card", "Energy", "Edge tile", "+28 Energy. Must be placed on an edge tile.", "Generic", "", "No", "Map edge", "No", ""),
    ("Existing", "Producer", "Common", "Turn Up", "turn_up", "Mult", "", "+2 Mult per current turn.", "Generic", "", "No", "", "No", ""),
    # Producers Uncommon
    ("Existing", "Producer", "Uncommon", "Aftershock", "aftershock", "Energy", "", "+10 Energy each time this card triggers this turn.", "Retrigger Engine", "Tempo", "No", "", "No", ""),
    ("Existing", "Producer", "Uncommon", "Backed Current", "backed_current", "Energy", "", "+20 Energy. If the previous card in trigger order is a Support, retrigger this card once.", "Retrigger Engine", "Empower Burst", "No", "", "No", ""),
    ("Existing", "Producer", "Uncommon", "Compact Power", "compact_power", "Mult", "", "+6 Mult if this segment has 7 tiles or fewer.", "Sparse", "", "No", "", "No", "Fails on segments larger than 7"),
    ("Existing", "Producer", "Uncommon", "Advanced Pointer", "advanced_pointer", "Energy", "", "+14 Energy per adjacent Downstream Energy card. +20 if 2 or more.", "Downstream Cluster", "", "No", "", "No", ""),
    ("Existing", "Producer", "Uncommon", "Advanced Mult", "advanced_mult", "Mult", "", "+4 Mult, increased by 1 for each Mult card on the same segment.", "Downstream Cluster", "", "No", "", "No", "Segment Mult cluster, not hex adjacency"),
    ("Existing", "Producer", "Uncommon", "Overcharge", "overcharge", "Energy", "", "+60 Energy. +10% break chance after every completed trigger this turn.", "Break (tool)", "Tempo", "No", "", "No", "Removal/sacrifice risk, not a build"),
    ("Existing", "Producer", "Uncommon", "Treasury", "treasury", "Energy", "", "+6 Energy, plus +1 Energy for every Gold you have.", "Gold Ledger", "", "No", "", "No", "Hoard payoff"),
    ("Existing", "Producer", "Uncommon", "Opening Volt", "opening_volt", "Energy", "", "+24 Energy if first Producer in segment, otherwise +8 Energy.", "Bookend", "", "No", "", "No", ""),
    ("Existing", "Producer", "Uncommon", "Last Surge", "last_surge", "Energy", "", "+24 Energy if last Producer in segment, otherwise +8 Energy.", "Bookend", "", "No", "", "No", ""),
    ("Existing", "Producer", "Uncommon", "Open Circuit", "open_circuit", "Energy", "", "+3 Energy per empty tile in this segment, up to 30.", "Sparse", "", "No", "", "No", ""),
    ("Existing", "Producer", "Uncommon", "Census Cell", "census_cell", "Energy", "", "+12 Energy for every segment on the map.", "Generic", "", "No", "", "No", ""),
    ("Existing", "Producer", "Uncommon", "Relay Sink", "relay_sink", "Energy", "", "+12 Energy per segment that has already received a relay this turn.", "Segment Relay", "", "No", "", "No", ""),
    ("Existing", "Producer", "Uncommon", "Wide Ratio", "wide_ratio", "Mult", "", "+2 Mult per other segment that contains a Producer.", "Generic", "", "No", "", "No", ""),
    ("Existing", "Producer", "Uncommon", "Salvage Core", "salvage_core", "Energy", "", "+15 Energy. When another card in this segment breaks, permanently +10 Energy.", "Break (tool)", "Growth", "No", "", "No", ""),
    ("Existing", "Producer", "Uncommon", "Turntake", "turntake", "Energy", "", "+8 Energy. If this activation is Empowered, also +4 Mult.", "Empower Burst", "", "No", "", "No", "Only Producer with Empowered-conditional payoff"),
    ("Existing", "Producer", "Uncommon", "Run-On", "run_on", "Energy", "", "+10 Energy, plus +5 Energy per consecutive Energy Producer immediately before this card.", "Downstream Cluster", "", "No", "", "No", ""),
    # Producers Rare
    ("Existing", "Producer", "Rare", "Lucky Draw", "lucky_draw", "Hybrid", "", "3% stacking chance to gain 400 Energy or 8 Gold. Resets on success.", "Gold Ledger", "", "No", "", "No", ""),
    ("Existing", "Producer", "Rare", "Unstable Concoction", "unstable_concoction", "Hybrid", "", "Gives 80 Energy or 12 Mult or 6 Gold.", "Gold Ledger", "", "No", "", "No", ""),
    ("Existing", "Producer", "Rare", "Lone Cell", "lone_cell", "Energy", "One-tile segment", "+80 Energy. Must be placed on a 1-tile segment.", "Solo Cell", "", "No", "Size-1 segment", "No", ""),
    ("Existing", "Producer", "Rare", "Tall Cell", "tall_cell", "Energy", "", "+10 Energy per other segment with no Producer.", "Sparse", "", "No", "", "No", ""),
    ("Existing", "Producer", "Rare", "Gluttonous Rune", "gluttonous_rune", "Energy", "", "+30 Energy. Consume the next card to permanently double this card's Energy.", "Break (tool)", "Growth", "No", "", "No", ""),
    # Supports Common
    ("Existing", "Support", "Common", "Catalyst", "catalyst", "Empower", "", "After 3 retriggers in this segment, Empower the next Producer. Once per turn.", "Retrigger Engine", "Empower Burst", "No", "", "No", "Bridge Retrigger to Empower"),
    ("Existing", "Support", "Common", "Chain effect", "chain_effect", "Retrigger", "", "Triggers the next 3 Producers, generated value reduced by 20% per jump.", "Retrigger Engine", "", "No", "", "No", ""),
    ("Existing", "Support", "Common", "Wildspark", "wildspark", "Retrigger", "", "Trigger the earliest adjacent Downstream card. If every adjacent Downstream hex has a unique card, trigger all instead.", "Retrigger Engine", "Downstream Cluster", "No", "", "No", ""),
    ("Existing", "Support", "Common", "Pair Bond", "pair_bond", "Retrigger", "", "Retrigger one adjacent Downstream card in this segment. Twice if that card is the same rarity.", "Retrigger Engine", "Downstream Cluster", "No", "", "No", ""),
    ("Existing", "Support", "Common", "Lead-In", "lead_in", "Retrigger", "", "Retrigger the first Producer in the next segment.", "Segment Relay", "Bookend", "No", "", "No", ""),
    ("Existing", "Support", "Common", "Helping Hand", "helping_hand", "Growth", "", "Gives the lowest Downstream Energy producer +5 permanently.", "Growth", "Downstream Cluster", "No", "", "No", ""),
    ("Existing", "Support", "Common", "Radiant Link", "radiant_link", "Growth", "", "Up to 3 adjacent Downstream Energy cards permanently gain +3 Energy.", "Growth", "Downstream Cluster", "No", "", "No", ""),
    ("Existing", "Support", "Common", "Segment Bond", "segment_bond", "Growth", "", "Adjacent Downstream Energy cards in this segment permanently gain +10 Energy.", "Growth", "Downstream Cluster", "No", "", "No", ""),
    ("Existing", "Support", "Common", "Forward Energy", "forward_score", "Relay", "", "Gives the next segment +40 Energy.", "Segment Relay", "", "No", "", "No", ""),
    ("Existing", "Support", "Common", "Forward Mult", "forward_mult", "Relay", "", "Gives the next segment +5 Mult.", "Segment Relay", "", "No", "", "No", ""),
    ("Existing", "Support", "Common", "Load Splitter", "load_splitter", "Relay", "", "This segment +15 Energy. Next segment +2 Mult.", "Segment Relay", "", "No", "", "No", ""),
    ("Existing", "Support", "Common", "Mirror Copy", "mirror_copy", "", "", "Copy the card on the opposite side of the map.", "Copy / mutate", "", "No", "", "No", ""),
    ("Existing", "Support", "Common", "Replication", "replication", "", "", "Adds a random common card to your hand. Breaks after 3 triggers.", "Break (tool)", "Copy / mutate", "No", "", "No", ""),
    # Supports Uncommon
    ("Existing", "Support", "Uncommon", "Imprint", "imprint", "", "", "Copies the effects of the two tiles directly before this one.", "Copy / mutate", "", "No", "", "No", "Uncommon in .tres, catalog still says Common"),
    ("Existing", "Support", "Uncommon", "Endless Power", "endless_power", "Empower", "", "Empowers a Producer for every active empowerment.", "Empower Burst", "", "No", "", "No", ""),
    ("Existing", "Support", "Uncommon", "Final Call", "final_call", "Empower", "", "On the final turn, Empower every Downstream Producer in this segment.", "Empower Burst", "Bookend", "No", "", "No", ""),
    ("Existing", "Support", "Uncommon", "Great Value", "great_value", "Empower", "", "Spend 1 Gold to Empower a random Downstream Producer in this segment.", "Gold Ledger", "Empower Burst", "No", "", "No", "PLANNED CUT: spends gold on board"),
    ("Existing", "Support", "Uncommon", "Overdrive", "overdrive", "Retrigger", "", "Triggers the next card in trigger order twice. Once per turn from trigger order.", "Retrigger Engine", "", "No", "", "No", ""),
    ("Existing", "Support", "Uncommon", "Random Selection", "random_selection", "Retrigger", "", "Triggers two random cards on Downstream segments.", "Retrigger Engine", "", "No", "", "No", ""),
    ("Existing", "Support", "Uncommon", "Break Glass", "break_glass", "Retrigger", "", "Triggers every card on its segment. Breaks immediately.", "Break (tool)", "Retrigger Engine", "No", "", "No", ""),
    ("Existing", "Support", "Uncommon", "Breaker Coil", "breaker_coil", "Retrigger", "", "If a card has broken on this segment this turn, retrigger the next Producer.", "Break (tool)", "Retrigger Engine", "No", "", "No", ""),
    ("Existing", "Support", "Uncommon", "Share Load", "share_load", "Relay", "", "Relay 45% of this segment's Energy pile and 20% of its bonus Mult to the next segment.", "Segment Relay", "", "No", "", "No", "Bot rarely picks, may tune"),
    # Supports Rare
    ("Existing", "Support", "Rare", "Initial Encore", "initial_encore", "Retrigger", "First tile of segment", "Triggers the first card of each Downstream segment.", "Retrigger Engine", "Bookend", "No", "First segment tile", "No", ""),
    ("Existing", "Support", "Rare", "Final Encore", "final_encore", "Retrigger", "Last tile of segment", "Triggers the last card of each Downstream segment.", "Retrigger Engine", "Bookend", "No", "Last segment tile", "No", ""),
    ("Existing", "Support", "Rare", "Unstable Rune", "unstable_rune", "Retrigger", "", "Trigger adjacent Downstream Producers. 10% break chance per adjacent Downstream Producer.", "Retrigger Engine", "Downstream Cluster; Break (tool)", "No", "", "No", ""),
    # Utilities
    ("Existing", "Utility", "Common", "Returnus Cardus", "returnus_cardus", "", "", "Returns the card of the selected tile to your hand.", "Copy / mutate", "", "No", "", "No", ""),
    ("Existing", "Utility", "Common", "Transformus Cardus", "transformus_cardus", "", "", "Transforms a played card into a random same-rarity card.", "Copy / mutate", "", "No", "", "No", ""),
    ("Existing", "Utility", "Uncommon", "Card Extraction", "card_extraction", "", "", "Breaks target card then gain a random card.", "Break (tool)", "Copy / mutate", "No", "", "No", ""),
    ("Existing", "Utility", "Uncommon", "Gold Extraction", "gold_extraction", "", "", "Breaks target card then gain 6 Gold.", "Break (tool)", "Gold Ledger", "No", "", "No", ""),
    ("Existing", "Utility", "Uncommon", "Clonus Cardus", "clonus_cardus", "", "", "Clones the card of the selected tile.", "Copy / mutate", "", "No", "", "No", ""),
    ("Existing", "Utility", "Uncommon", "Transposition", "transposition", "", "", "Swap two placed cards.", "Copy / mutate", "", "No", "", "No", ""),
    ("Existing", "Utility", "Rare", "Transformus Upgradus", "transformus_upgradus", "", "", "Transforms a played card into a random higher-rarity card.", "Copy / mutate", "", "No", "", "No", ""),
    # Removed from repo but listed in catalog
    ("Removed", "Producer", "Uncommon", "Golden Ratio", "golden_ratio", "Mult", "", "+3 Mult. Gain +1 Mult for each Gold spent this round.", "Gold Ledger", "", "No", "", "No", "Removed from resources, do not restore"),
]

# Locked 15. Every card fills a hole or is Charge core. Do not add filler.
# Notes compare to an existing staple so the card is never strictly worse.
SUGGESTED = [
    # Charge core (store, feed, dump, rare spike)
    ("Suggested", "Producer", "Common", "Capacitor", "capacitor", "Energy", "", "+16 Energy. Store 10 charge on this card.", "Charge", "", "No", "", "Yes", "Power Cell is +20 now. Capacitor pays 4 Energy to bank 10 for Release / Overfill. Do not pick it as a generic cell."),
    ("Suggested", "Support", "Common", "Trickle Charge", "trickle_charge", "Charge", "", "Add 12 charge to the next Producer on this segment.", "Charge", "", "No", "", "Yes", "The feeder. Without this, Charge never outruns Power Cell. Support slot, not a weak Producer."),
    ("Suggested", "Producer", "Uncommon", "Release", "release", "Energy", "", "Gain Energy equal to this card's charge, then clear charge. If you dumped 20 or more, also +2 Mult.", "Charge", "", "No", "", "Yes", "Empty it is a brick. Charged it beats Power Cell (20 charge = 20 Energy and +2 Mult)."),
    ("Suggested", "Producer", "Rare", "Overfill", "overfill", "Energy", "", "When this card's charge reaches 30, dump all charge as Energy and Empower this card.", "Charge", "Empower Burst", "No", "", "Yes", "Rare spike. 30 Energy plus Empower is not a Power Cell sidegrade."),
    # Gold hoard (Allowance is a trickle, Great Value spends)
    ("Suggested", "Producer", "Common", "Mint Cell", "mint_cell", "Gold", "", "+2 Gold.", "Gold Ledger", "", "No", "", "Yes", "Allowance is +1. This is the common Gold Producer the build is missing."),
    ("Suggested", "Producer", "Uncommon", "Vault Mult", "vault_mult", "Mult", "", "+2 Mult, plus +1 Mult per 8 gold you hold.", "Gold Ledger", "", "No", "", "Yes", "Floor matches Basic Mult. 16 gold = +4, 24 gold = +5. Treasury already converts gold to Energy."),
    ("Suggested", "Support", "Uncommon", "Reserve Empower", "reserve_empower", "Empower", "", "If you hold at least 8 gold, Empower the next Producer. Does not spend gold.", "Gold Ledger", "Empower Burst", "No", "", "Yes", "Replaces Great Value. Targeted next Producer, wallet stays for Treasury / Vault Mult."),
    # Empower payoff (Turntake is the only existing Empowered-conditional Producer)
    ("Suggested", "Producer", "Rare", "Peak Hit", "peak_hit", "Energy", "", "+24 Energy. If this activation is Empowered, also +6 Mult.", "Empower Burst", "", "No", "", "Yes", "Floor beats Power Cell (24 vs 20). Empowered: doubled Energy plus +6 Mult. Turntake is the small version (+8 / +4 Mult)."),
    # Break: one payoff, not a package
    ("Suggested", "Producer", "Rare", "Last Claim", "last_claim", "Energy", "", "+55 Energy if a card has already broken on this segment this turn, else +16.", "Break (tool)", "", "No", "", "Yes", "Miss is below Power Cell on purpose. Hit is almost 3x Power Cell. Breaks are scarce so the hit must be huge."),
    # Bookend Mult (Opening Volt / Last Surge are Energy only)
    ("Suggested", "Producer", "Uncommon", "Opening Ratio", "opening_ratio", "Mult", "", "+6 Mult if this is the first Producer in the segment, else +2.", "Bookend", "", "No", "", "Yes", "Out of seat ties Basic Mult. In seat is 3x Basic Mult. Never strictly worse."),
    ("Suggested", "Producer", "Uncommon", "Last Ratio", "last_ratio", "Mult", "", "+6 Mult if this is the last Producer in the segment, else +2.", "Bookend", "", "No", "", "Yes", "Same floor as Opening Ratio for the last seat."),
    # Solo Mult (Lone Cell is Energy-only, size-1 Support cannot share the tile)
    ("Suggested", "Producer", "Rare", "Lone Ratio", "lone_ratio", "Mult", "One-tile segment", "+8 Mult. Size-1 segment only.", "Solo Cell", "", "No", "Size-1 segment", "Yes", "Lone Cell is +80 Energy on the same seat. This is the Mult seat. Compact Power is +6 on segments of 7 or fewer, this is +8 on size-1."),
    # Relay Mult payoff (Relay Sink is Energy-only)
    ("Suggested", "Producer", "Uncommon", "Mult Sink", "mult_sink", "Mult", "", "+3 Mult per segment that has already received a relay this turn.", "Segment Relay", "", "No", "", "Yes", "Forward Mult is a flat +5 to the next segment. This scores after relays already happened. Two relays = +6, three = +9."),
    # Cluster Mult adjacency (Advanced Pointer is Energy-only)
    ("Suggested", "Producer", "Uncommon", "Pair Mult", "pair_mult", "Mult", "", "+3 Mult per adjacent Downstream Mult card.", "Downstream Cluster", "", "No", "", "Yes", "One Mult neighbor = +3 (beats Basic Mult). Two = +6. Advanced Pointer is the Energy adjacency card. Advanced Mult counts Mult on the whole segment, not hex neighbors."),
    # Sparse Support (Spark Plug / Open Circuit exist, no Support wants empty hexes)
    ("Suggested", "Support", "Common", "Gap Stamp", "gap_stamp", "Growth", "", "If an adjacent Downstream hex is empty, the next Producer permanently +10 Energy.", "Sparse", "Growth", "No", "", "Yes", "Helping Hand is +5 to the lowest Energy with no gap. This is double the stamp if you keep a hole."),
]

TYPE_ORDER = {"Producer": 0, "Support": 1, "Utility": 2}
RARITY_ORDER = {"Common": 0, "Uncommon": 1, "Rare": 2}
STATUS_ORDER = {"Existing": 0, "Suggested": 1, "Removed": 2}


def sort_key(row):
    return (
        TYPE_ORDER.get(row[1], 9),
        RARITY_ORDER.get(row[2], 9),
        STATUS_ORDER.get(row[0], 9),
        row[3].lower(),
    )


def build_summary_rows(rows):
    """Return summary statistics as rows for CSV tail and Summary sheet."""
    summary = []

    existing = [r for r in rows if r[0] == "Existing"]
    suggested = [r for r in rows if r[0] == "Suggested"]
    removed = [r for r in rows if r[0] == "Removed"]
    first_cut = [r for r in rows if r[12] == "Yes"]

    summary.append(["=== SUMMARY ==="])
    summary.append([])
    summary.append(["Metric", "Count"])
    summary.append(["Total cards in spreadsheet", len(rows)])
    summary.append(["Existing (in resources)", len(existing)])
    summary.append(["Suggested (plan menu)", len(suggested)])
    summary.append(["Removed from repo (catalog only)", len(removed)])
    summary.append(["Suggested first-cut bundle", len(first_cut)])
    summary.append(["Pool if first-cut shipped (+ cut Great Value)", len(existing) - 1 + len(first_cut)])
    summary.append(["Pool if all suggested shipped (+ cut Great Value)", len(existing) - 1 + len(suggested)])
    summary.append(["This pass suggested adds", len(suggested)])
    summary.append(["Target pool size (later)", "~100"])
    summary.append([])

    summary.append(["By status and type"])
    for status in ("Existing", "Suggested", "Removed"):
        for typ in ("Producer", "Support", "Utility"):
            n = sum(1 for r in rows if r[0] == status and r[1] == typ)
            if n:
                summary.append([f"{status} {typ}", n])
    summary.append([])

    summary.append(["By type (Existing + Suggested only)"])
    for typ in ("Producer", "Support", "Utility"):
        n = sum(1 for r in rows if r[0] in ("Existing", "Suggested") and r[1] == typ)
        summary.append([typ, n])
    summary.append([])

    summary.append(["By rarity (Existing + Suggested only)"])
    for rarity in ("Common", "Uncommon", "Rare"):
        n = sum(1 for r in rows if r[0] in ("Existing", "Suggested") and r[2] == rarity)
        summary.append([rarity, n])
    summary.append([])

    summary.append(["By rarity within type (Existing + Suggested)"])
    for typ in ("Producer", "Support", "Utility"):
        for rarity in ("Common", "Uncommon", "Rare"):
            n = sum(
                1
                for r in rows
                if r[0] in ("Existing", "Suggested") and r[1] == typ and r[2] == rarity
            )
            if n:
                summary.append([f"{typ} {rarity}", n])
    summary.append([])

    summary.append(["By primary identity (Existing + Suggested)"])
    identity_counts = Counter(r[8] for r in rows if r[0] in ("Existing", "Suggested"))
    for identity, n in sorted(identity_counts.items(), key=lambda x: (-x[1], x[0])):
        summary.append([identity, n])
    summary.append([])

    summary.append(["By primary identity — Existing only"])
    ex_counts = Counter(r[8] for r in rows if r[0] == "Existing")
    for identity, n in sorted(ex_counts.items(), key=lambda x: (-x[1], x[0])):
        summary.append([identity, n])
    summary.append([])

    summary.append(["By primary identity — Suggested only"])
    sug_counts = Counter(r[8] for r in rows if r[0] == "Suggested")
    for identity, n in sorted(sug_counts.items(), key=lambda x: (-x[1], x[0])):
        summary.append([identity, n])
    summary.append([])

    summary.append(["First-cut picks by identity"])
    fc_counts = Counter(r[8] for r in rows if r[12] == "Yes")
    for identity, n in sorted(fc_counts.items(), key=lambda x: (-x[1], x[0])):
        summary.append([identity, n])
    summary.append([])

    summary.append(["Loot weights (pool design target)", "Common 55% / Uncommon 35% / Rare 10%"])
    summary.append(["Rarity pool target (~100 cards)", "~42-44 Common / ~42-44 Uncommon / ~13-15 Rare"])

    return summary


def write_summary(rows, writer):
    writer.writerow([])
    for row in build_summary_rows(rows):
        writer.writerow(row)


def write_csv(rows, path):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(HEADERS)
        writer.writerows(rows)
        write_summary(rows, writer)


def _xlsx_styles():
    from openpyxl.styles import Font, PatternFill

    return {
        "header_font": Font(bold=True),
        "header_fill": PatternFill(fill_type="solid", fgColor="D9E1F2"),
        "section_font": Font(bold=True, italic=True),
        "section_fill": PatternFill(fill_type="solid", fgColor="F2F2F2"),
        "suggested_fill": PatternFill(fill_type="solid", fgColor="FFF9C4"),
        "removed_fill": PatternFill(fill_type="solid", fgColor="E0E0E0"),
        "first_cut_fill": PatternFill(fill_type="solid", fgColor="C6EFCE"),
        "bold_font": Font(bold=True),
    }


def _apply_column_widths(ws, max_width=50):
    for col_idx, header in enumerate(HEADERS, start=1):
        cap = max_width if header in ("Effect", "Notes") else 28
        max_len = len(header)
        for row in ws.iter_rows(min_row=2, min_col=col_idx, max_col=col_idx):
            cell = row[0]
            if cell.value:
                max_len = max(max_len, len(str(cell.value)))
        ws.column_dimensions[ws.cell(row=1, column=col_idx).column_letter].width = min(max_len + 2, cap)


def _write_header_row(ws, styles):
    for col_idx, header in enumerate(HEADERS, start=1):
        cell = ws.cell(row=1, column=col_idx, value=header)
        cell.font = styles["header_font"]
        cell.fill = styles["header_fill"]
    ws.freeze_panes = "A2"


def _write_data_row(ws, row_idx, row_data, styles):
    for col_idx, value in enumerate(row_data, start=1):
        ws.cell(row=row_idx, column=col_idx, value=value)

    status = row_data[0]
    row_fill = None
    if status == "Suggested":
        row_fill = styles["suggested_fill"]
    elif status == "Removed":
        row_fill = styles["removed_fill"]

    if row_fill:
        for col_idx in range(1, len(HEADERS) + 1):
            ws.cell(row=row_idx, column=col_idx).fill = row_fill

    # In_First_Cut column highlight
    if row_data[12] == "Yes":
        first_cut_col = 13
        ws.cell(row=row_idx, column=first_cut_col).fill = styles["first_cut_fill"]
        ws.cell(row=row_idx, column=4).font = styles["bold_font"]


def _write_data_sheet(ws, rows, with_rarity_sections=False, styles=None):
    styles = styles or _xlsx_styles()
    _write_header_row(ws, styles)

    row_idx = 2
    if with_rarity_sections:
        for rarity in ("Common", "Uncommon", "Rare"):
            rarity_rows = [r for r in rows if r[2] == rarity]
            if not rarity_rows:
                continue
            for col_idx in range(1, len(HEADERS) + 1):
                cell = ws.cell(row=row_idx, column=col_idx)
                if col_idx == 1:
                    cell.value = f"— {rarity} —"
                cell.font = styles["section_font"]
                cell.fill = styles["section_fill"]
            row_idx += 1
            for row_data in rarity_rows:
                _write_data_row(ws, row_idx, row_data, styles)
                row_idx += 1
    else:
        for row_data in rows:
            _write_data_row(ws, row_idx, row_data, styles)
            row_idx += 1

    _apply_column_widths(ws)


def write_xlsx(rows, path):
    from openpyxl import Workbook
    from openpyxl.styles import Font

    styles = _xlsx_styles()
    wb = Workbook()
    wb.remove(wb.active)

    all_sheet = wb.create_sheet("All Cards")
    _write_data_sheet(all_sheet, rows, with_rarity_sections=False, styles=styles)

    for sheet_name, card_type in (
        ("Producers", "Producer"),
        ("Supports", "Support"),
        ("Utilities", "Utility"),
    ):
        type_rows = [r for r in rows if r[1] == card_type]
        sheet = wb.create_sheet(sheet_name)
        _write_data_sheet(sheet, type_rows, with_rarity_sections=True, styles=styles)

    first_cut_rows = [r for r in rows if r[12] == "Yes"]
    first_cut_sheet = wb.create_sheet("First Cut")
    _write_data_sheet(first_cut_sheet, first_cut_rows, with_rarity_sections=False, styles=styles)

    summary_sheet = wb.create_sheet("Summary")
    summary_rows = build_summary_rows(rows)
    for row_idx, row_data in enumerate(summary_rows, start=1):
        for col_idx, value in enumerate(row_data, start=1):
            summary_sheet.cell(row=row_idx, column=col_idx, value=value)
        if row_data and str(row_data[0]).startswith("==="):
            for col_idx in range(1, 3):
                summary_sheet.cell(row=row_idx, column=col_idx).font = Font(bold=True)
        elif row_data and row_data[0] in (
            "By status and type",
            "By type (Existing + Suggested only)",
            "By rarity (Existing + Suggested only)",
            "By rarity within type (Existing + Suggested)",
            "By primary identity (Existing + Suggested)",
            "By primary identity — Existing only",
            "By primary identity — Suggested only",
            "First-cut picks by identity",
        ):
            summary_sheet.cell(row=row_idx, column=1).font = Font(bold=True)

    summary_sheet.column_dimensions["A"].width = 48
    summary_sheet.column_dimensions["B"].width = 24

    path.parent.mkdir(parents=True, exist_ok=True)
    wb.save(path)


def main():
    rows = sorted(EXISTING + SUGGESTED, key=sort_key)

    write_csv(rows, OUT_CSV)
    print(f"Wrote {len(rows)} card rows to {OUT_CSV}")

    try:
        write_xlsx(rows, OUT_XLSX)
        print(f"Wrote workbook to {OUT_XLSX}")
    except ImportError:
        print("openpyxl not installed. CSV written only.")
        print("Install with: pip install -r scripts/debug/requirements.txt")


if __name__ == "__main__":
    main()
