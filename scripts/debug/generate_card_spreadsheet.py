#!/usr/bin/env python3
"""Generate the spot card master spreadsheet from resources/cards."""

from __future__ import annotations

import csv
import re
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CARDS = ROOT / "resources" / "cards"
OUT_CSV = ROOT / "docs" / "cards_master_spreadsheet.csv"
OUT_XLSX = ROOT / "docs" / "cards_master_spreadsheet.xlsx"

HEADERS = [
    "Shelf",
    "Kind",
    "Name",
    "Id",
    "Product",
    "Base",
    "Requirements",
    "Effect",
    "Starter_Eligible",
    "Path",
]

# Mirrors TileCard.TileCardType and TileCard.Product. A missing field is the enum's first value
# for type (Ingredient) and NONE for product.
SHELVES = {0: "Ingredients", 1: "Kitchenware", 2: "Meals"}
SHELF_ORDER = {"Ingredients": 0, "Kitchenware": 1, "Meals": 2}
PRODUCTS = {0: "Gold", 1: "Flavour", 2: "Mult", 3: "Hybrid", 4: ""}
# Player-facing kind names. Mirrors GameTerms.get_ingredient_kind_label.
KIND_LABELS = {
    "vegetable": "Vegetable",
    "fruit": "Fruit",
    "protein": "Meat",
    "seafood": "Seafood",
    "dairy": "Dairy",
    "sweet": "Sweet",
    "seasoning": "Seasoning",
    "kitchenware": "Kitchenware",
    "dish": "Dish",
    "beverage": "Beverage",
}
RECIPE_FIELDS = [
    ("recipe_vegetable_count", "vegetable"),
    ("recipe_fruit_count", "fruit"),
    ("recipe_protein_count", "protein"),
    ("recipe_seafood_count", "seafood"),
    ("recipe_dairy_count", "dairy"),
    ("recipe_sweet_count", "sweet"),
    ("recipe_seasoning_count", "seasoning"),
    ("recipe_kitchenware_count", "kitchenware"),
]


def _read_field(text: str, field: str) -> str:
    match = re.search(rf'^{field} = "?(.*?)"?$', text, re.MULTILINE)
    return match.group(1) if match else ""


def _read_int(text: str, field: str, default: int = 0) -> int:
    raw = _read_field(text, field)
    return int(raw) if raw.lstrip("-").isdigit() else default


def _tags(text: str) -> list[str]:
    return re.findall(r'&"([a-z_]+)"', _read_field(text, "ingredient_tags"))


def _requirements(text: str) -> str:
    parts = []
    for card_id in re.findall(r'"([a-z_]+)"', _read_field(text, "recipe_required_card_ids")):
        parts.append(card_id.replace("_", " ").title())
    for field, kind in RECIPE_FIELDS:
        count = _read_int(text, field)
        if count > 0:
            parts.append(f"{count} {KIND_LABELS[kind]}")
    return ", ".join(parts)


def scan_cards() -> list[list]:
    rows: list[list] = []
    for path in sorted(CARDS.rglob("*.tres")):
        text = path.read_text(encoding="utf-8")
        card_id = _read_field(text, "id")
        if not card_id:
            continue
        shelf = SHELVES.get(_read_int(text, "type"), "Ingredients")
        kinds = " · ".join(KIND_LABELS.get(tag, tag) for tag in _tags(text))
        rows.append([
            shelf,
            kinds,
            _read_field(text, "name"),
            card_id,
            PRODUCTS.get(_read_int(text, "product", 4), ""),
            _read_int(text, "base_production_amount"),
            _requirements(text),
            _read_field(text, "description"),
            "Yes" if _read_field(text, "starting_hand_eligible") == "true" else "No",
            path.relative_to(ROOT).as_posix(),
        ])
    rows.sort(key=lambda row: (SHELF_ORDER.get(row[0], 9), row[1], row[2].lower()))
    return rows


def build_summary_rows(rows: list[list]) -> list[list]:
    summary: list[list] = [["=== SUMMARY ==="], [], ["Metric", "Count"], ["Total cards", len(rows)], []]
    summary.append(["By shelf"])
    for shelf, count in sorted(Counter(r[0] for r in rows).items(), key=lambda item: SHELF_ORDER.get(item[0], 9)):
        summary.append([shelf, count])
    summary.append([])
    summary.append(["By kind"])
    for kind, count in sorted(Counter(r[1] for r in rows if r[1]).items()):
        summary.append([kind, count])
    summary.append([])
    summary.append(["Terminology"])
    summary.append(["Player formula", "Flavour x Mult = Rating"])
    summary.append(["Day / Hour", "round / turn in code"])
    summary.append(["Station / Spot", "segment / tile in code"])
    summary.append(["Glossary", "docs/feast_glossary.md"])
    return summary


def write_csv(rows: list[list], path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.writer(handle)
        writer.writerow(HEADERS)
        writer.writerows(rows)
        writer.writerow([])
        writer.writerows(build_summary_rows(rows))


def write_xlsx(rows: list[list], path: Path) -> None:
    from openpyxl import Workbook
    from openpyxl.styles import Font, PatternFill

    header_font = Font(bold=True)
    header_fill = PatternFill(fill_type="solid", fgColor="D9E1F2")

    wb = Workbook()
    wb.remove(wb.active)

    def write_sheet(title: str, sheet_rows: list[list]) -> None:
        ws = wb.create_sheet(title)
        for col_idx, header in enumerate(HEADERS, start=1):
            cell = ws.cell(row=1, column=col_idx, value=header)
            cell.font = header_font
            cell.fill = header_fill
        ws.freeze_panes = "A2"
        for row_idx, row_data in enumerate(sheet_rows, start=2):
            for col_idx, value in enumerate(row_data, start=1):
                ws.cell(row=row_idx, column=col_idx, value=value)

    write_sheet("All Cards", rows)
    for shelf in SHELF_ORDER:
        write_sheet(shelf, [r for r in rows if r[0] == shelf])

    summary_sheet = wb.create_sheet("Summary")
    for row_idx, row_data in enumerate(build_summary_rows(rows), start=1):
        for col_idx, value in enumerate(row_data, start=1):
            cell = summary_sheet.cell(row=row_idx, column=col_idx, value=value)
            if row_data and str(row_data[0]).startswith("==="):
                cell.font = Font(bold=True)

    path.parent.mkdir(parents=True, exist_ok=True)
    wb.save(path)


def main() -> None:
    rows = scan_cards()
    write_csv(rows, OUT_CSV)
    print(f"Wrote {len(rows)} rows to {OUT_CSV}")
    try:
        write_xlsx(rows, OUT_XLSX)
        print(f"Wrote workbook to {OUT_XLSX}")
    except ImportError:
        print("openpyxl not installed. CSV written only.")
        print("Install with: pip install -r scripts/debug/requirements.txt")


if __name__ == "__main__":
    main()
