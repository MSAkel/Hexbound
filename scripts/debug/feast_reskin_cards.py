#!/usr/bin/env python3
"""Apply Feast copy and condiment labels to spot card and condiment .tres files."""

from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SPOT_CARDS = ROOT / "resources" / "spot_cards"
CONDIMENTS_DIR = ROOT / "resources" / "condiments"
PLACEHOLDER = "res://assets/icons/placeholder.png"

DESCRIPTION_REPLACEMENTS: list[tuple[str, str]] = [
    ("Empowered", "Doubled"),
    ("Empowers", "Doubles"),
    ("Empower", "Double"),
    ("empowered", "doubled"),
    ("empowers", "doubles"),
    ("empower", "double"),
    ("Retriggered", "Fired again"),
    ("Retriggers", "Fire again"),
    ("Retrigger", "Fire again"),
    ("retriggered", "fired again"),
    ("retriggers", "fire again"),
    ("retrigger", "fire again"),
    ("Relayed", "Passed"),
    ("Relays", "Pass"),
    ("Relay", "Pass"),
    ("relayed", "passed"),
    ("relays", "pass"),
    ("relay", "pass"),
    ("Broken", "Spoiled"),
    ("Breaks", "Spoils"),
    ("Break", "Spoil"),
    ("broken", "spoiled"),
    ("breaks", "spoils"),
    ("break", "spoil"),
    ("Producers", "Ingredients"),
    ("Producer", "Ingredient"),
    ("producers", "ingredients"),
    ("producer", "ingredient"),
    ("Supports", "Kitchenware"),
    ("Support", "Kitchenware"),
    ("supports", "kitchenware"),
    ("support", "kitchenware"),
    ("Energy", "Flavour"),
    ("energy", "flavour"),
    ("Score", "Rating"),
    ("score", "rating"),
    ("this turn", "this hour"),
    ("This turn", "This hour"),
    ("per turn", "per hour"),
    ("Per turn", "Per hour"),
    ("final turn", "final hour"),
    ("Final turn", "Final hour"),
    ("this round", "this day"),
    ("This round", "This day"),
    ("the round", "the day"),
    ("segment", "course"),
    ("Segment", "Course"),
    ("trigger", "fire"),
    ("Trigger", "Fire"),
    ("trigger order", "fire order"),
    ("Trigger order", "Fire order"),
    ("Triggered ", "Fired "),
    ("triggered ", "fired "),
    ("tile", "spot"),
    ("Tile", "Spot"),
    ("station", "spot"),
    ("Station", "Spot"),
]

# Undo an old Following -> Next pass. Keep "next course" and "next fire" relay timing copy.
FOLLOWING_RESTORE: list[tuple[str, str]] = [
    ("each later course", "each following course"),
    ("on later courses", "on following courses"),
    ("Adjacent Next", "Adjacent Following"),
    ("adjacent Next", "adjacent Following"),
    ("every Next Ingredient", "every Following Ingredient"),
    ("every Next", "every Following"),
    ("Lowest Next", "Lowest Following"),
    ("random Next", "random Following"),
    ("the next Ingredient", "the Following Ingredient"),
    ("the next 3", "the Following 3"),
    ("the next card", "the Following card"),
    ("Next Ingredients", "Following Ingredients"),
    ("Next Ingredient", "Following Ingredient"),
    ("Next Flavour", "Following Flavour"),
    ("Next Poultry", "Following Poultry"),
    ("next 3 Ingredients", "Following 3 Ingredients"),
    ("adjacent next card", "adjacent Following card"),
    ("Next card", "Following card"),
    ("next card", "Following card"),
    ("next Ingredient", "Following Ingredient"),
    ("adjacent Next spot", "adjacent Following spot"),
    ("per adjacent Next", "per adjacent Following"),
    ("following adjacent", "Following adjacent"),
    ("Fire adjacent following", "Fire adjacent Following"),
]

POTIONS: dict[str, dict[str, str]] = {
    "energy_spike": {
        "display_name": "Gravy",
        "description": "+50 Flavour on next fire",
        "icon": "res://assets/icons/condiments/bbg_sauce.png",
    },
    "mult_spike": {
        "display_name": "Hot Sauce",
        "description": "+6 Mult on next fire",
        "icon": "res://assets/icons/condiments/hot_sauce.png",
    },
    "empower": {
        "display_name": "Reduction",
        "description": "Double",
        "icon": "res://assets/icons/condiments/caramel.png",
    },
    "ward": {
        "display_name": "Cloche Dome",
        "description": "Ignore next spoil",
        "icon": "res://assets/icons/condiments/mayonnaise.png",
    },
    "echo": {
        "display_name": "Second Pass",
        "description": "Fire again after next fire",
        "icon": "res://assets/icons/condiments/relish.png",
    },
    "forward_gift": {
        "display_name": "Runner's Ramekin",
        "description": "For 2 hours, Pass this card's product to the next course",
        "icon": "res://assets/icons/condiments/ranch.png",
    },
    "mint_sip": {
        "display_name": "Mint Drizzle",
        "description": "For 2 hours, also +1 Gold when fired",
        "icon": "res://assets/icons/condiments/chipotle_mayo.png",
    },
    "opening_round": {
        "display_name": "Opening Splash",
        "description": "First Ingredient in every course is Doubled this hour",
        "icon": "res://assets/icons/condiments/secret_sauce_11.png",
    },
    "closing_round": {
        "display_name": "Closing Glaze",
        "description": "Last Ingredient in every course is Doubled this hour",
        "icon": "res://assets/icons/condiments/secret_sauce_13.png",
    },
    "gold_drop": {
        "display_name": "Petty Cash",
        "description": "+15 Gold",
        "icon": "res://assets/icons/condiments/olive_oil.png",
    },
    "borrowed_time": {
        "display_name": "Extra Covers",
        "description": "+1 hour this day",
        "icon": "res://assets/icons/condiments/honey.png",
    },
    "condiment_pack": {
        "display_name": "Condiment Flight",
        "description": "Gain 3 random condiments",
        "icon": "res://assets/icons/condiments/secret_sauce_12.png",
    },
    "rewrite_event": {
        "display_name": "Rewrite Event",
        "description": "Change the upcoming event",
        "icon": "res://assets/icons/condiments/soy_sauce.png",
    },
    "free_reroll": {
        "display_name": "Fresh Menu",
        "description": "+1 free reroll",
        "icon": "res://assets/icons/condiments/ketchup.png",
    },
}


def feastify_description(text: str) -> str:
    for old, new in DESCRIPTION_REPLACEMENTS:
        text = text.replace(old, new)
    return text


def restore_following_copy(text: str) -> str:
    for old, new in FOLLOWING_RESTORE:
        text = text.replace(old, new)
    return text


def set_field(text: str, field: str, value: str) -> str:
    pattern = rf"^{re.escape(field)} = .*$"
    replacement = f'{field} = "{value}"'
    if re.search(pattern, text, flags=re.MULTILINE):
        return re.sub(pattern, replacement, text, count=1, flags=re.MULTILINE)
    return text


def set_icon_path(text: str, icon_path: str) -> str:
    return re.sub(
        r'(\[ext_resource type="Texture2D"[^\]]*path=")[^"]+(" id="[^"]+"\])',
        rf"\1{icon_path}\2",
        text,
        count=1,
    )


def feastify_quoted_strings(line: str) -> str:
    def repl(match: re.Match[str]) -> str:
        return '"' + feastify_description(match.group(1)) + '"'

    return re.sub(r'"([^"\\]*(?:\\.[^"\\]*)*)"', repl, line)


def should_feastify_code_line(line: str) -> bool:
    stripped = line.lstrip()
    if stripped.startswith("## "):
        return True
    if stripped.startswith("# ") and any(
        token in stripped
        for token in (
            "Energy",
            "Segment",
            "Producer",
            "Empower",
            "Relay",
            "Retrigger",
            "Support",
            "break",
            "turn",
            "round",
            "tile",
            "trigger",
        )
    ):
        return True
    if "_create_floating_text(" in line:
        return True
    if "return \"" in line or stripped.startswith("\""):
        return True
    return False


def process_spot_card_script(path: Path) -> bool:
    content = path.read_text(encoding="utf-8")
    original = content
    lines: list[str] = []
    for line in content.splitlines():
        if should_feastify_code_line(line):
            if line.lstrip().startswith("## "):
                prefix = line[: len(line) - len(line.lstrip())]
                lines.append(prefix + restore_following_copy(feastify_description(line.lstrip())))
            else:
                lines.append(restore_following_copy(feastify_quoted_strings(line)))
        else:
            lines.append(line)
    content = "\n".join(lines)
    if content != original:
        path.write_text(content + ("\n" if original.endswith("\n") else ""), encoding="utf-8")
        return True
    return False


def process_spot_card(path: Path) -> bool:
    content = path.read_text(encoding="utf-8")
    original = content
    desc_match = re.search(r'^description = "(.*)"$', content, flags=re.MULTILINE)
    if desc_match:
        new_desc = restore_following_copy(feastify_description(desc_match.group(1)))
        content = set_field(content, "description", new_desc)
    if 'path="res://assets/icons/runes/' in content:
        content = set_icon_path(content, PLACEHOLDER)
    if content != original:
        path.write_text(content, encoding="utf-8")
        return True
    return False


def process_condiment(path: Path) -> bool:
    content = path.read_text(encoding="utf-8")
    original = content
    match = re.search(r'^id = "([^"]+)"', content, flags=re.MULTILINE)
    if not match:
        return False
    condiment_id = match.group(1)
    if condiment_id not in POTIONS:
        return False
    data = POTIONS[condiment_id]
    content = set_field(content, "display_name", data["display_name"])
    content = set_field(content, "description", data["description"])
    content = set_icon_path(content, data["icon"])
    if content != original:
        path.write_text(content, encoding="utf-8")
        return True
    return False


def restore_following_in_tree(root: Path) -> int:
    changed = 0
    for path in sorted(root.rglob("*")):
        if path.suffix not in {".gd", ".tres"}:
            continue
        text = path.read_text(encoding="utf-8")
        updated = restore_following_copy(text)
        if updated != text:
            path.write_text(updated, encoding="utf-8")
            print(f"following: {path.relative_to(ROOT)}")
            changed += 1
    return changed


def main() -> None:
    restore_following_in_tree(SPOT_CARDS)
    changed_cards = 0
    for path in sorted(SPOT_CARDS.rglob("*.tres")):
        if process_spot_card(path):
            changed_cards += 1
            print(f"card: {path.relative_to(ROOT)}")

    changed_scripts = 0
    for path in sorted(SPOT_CARDS.rglob("*.gd")):
        if process_spot_card_script(path):
            changed_scripts += 1
            print(f"script: {path.relative_to(ROOT)}")

    changed_condiments = 0
    for path in sorted(CONDIMENTS_DIR.glob("*.tres")):
        if process_condiment(path):
            changed_condiments += 1
            print(f"condiment: {path.relative_to(ROOT)}")

    print(
        f"Updated {changed_cards} spot cards, {changed_scripts} scripts, "
        f"and {changed_condiments} condiments."
    )


if __name__ == "__main__":
    main()
