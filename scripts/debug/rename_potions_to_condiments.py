#!/usr/bin/env python3
"""One-shot refactor: potion -> condiment terminology and condiment icons."""

from __future__ import annotations

import os
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

# File renames: old relative path -> new relative path
FILE_RENAMES: list[tuple[str, str]] = [
    ("scripts/resources/potion.gd", "scripts/resources/condiment.gd"),
    ("scripts/resources/potion.gd.uid", "scripts/resources/condiment.gd.uid"),
    ("scripts/helpers/potion_catalog.gd", "scripts/helpers/condiment_catalog.gd"),
    ("scripts/helpers/potion_catalog.gd.uid", "scripts/helpers/condiment_catalog.gd.uid"),
    ("scripts/autoload/potion_manager.gd", "scripts/autoload/condiment_manager.gd"),
    ("scripts/autoload/potion_manager.gd.uid", "scripts/autoload/condiment_manager.gd.uid"),
    ("scenes/ui/potions/potion_belt.gd", "scenes/ui/condiments/condiment_belt.gd"),
    ("scenes/ui/potions/potion_belt.gd.uid", "scenes/ui/condiments/condiment_belt.gd.uid"),
    ("scenes/ui/potions/potion_belt.tscn", "scenes/ui/condiments/condiment_belt.tscn"),
    ("scenes/ui/potions/potion_slot.gd", "scenes/ui/condiments/condiment_slot.gd"),
    ("scenes/ui/potions/potion_slot.gd.uid", "scenes/ui/condiments/condiment_slot.gd.uid"),
    ("scenes/ui/potions/potion_slot.tscn", "scenes/ui/condiments/condiment_slot.tscn"),
    ("scenes/ui/potions/potion_shop_item.gd", "scenes/ui/condiments/condiment_shop_item.gd"),
    ("scenes/ui/potions/potion_shop_item.gd.uid", "scenes/ui/condiments/condiment_shop_item.gd.uid"),
    ("scenes/ui/potions/potion_shop_item.tscn", "scenes/ui/condiments/condiment_shop_item.tscn"),
    ("scenes/ui/potions/potion_edge_glow.gd", "scenes/ui/condiments/condiment_edge_glow.gd"),
    ("scenes/ui/potions/potion_edge_glow.gd.uid", "scenes/ui/condiments/condiment_edge_glow.gd.uid"),
    ("scenes/ui/potions/potion_edge_glow.tscn", "scenes/ui/condiments/condiment_edge_glow.tscn"),
    ("resources/condiments/potion_pack.tres", "resources/condiments/condiment_pack.tres"),
]

# Condiment .tres icon paths (named icons from assets/icons/condiments/).
CONDIMENT_ICONS: dict[str, str] = {
    "gold_drop": "res://assets/icons/condiments/olive_oil.png",
    "borrowed_time": "res://assets/icons/condiments/honey.png",
    "free_reroll": "res://assets/icons/condiments/ketchup.png",
    "rewrite_omen": "res://assets/icons/condiments/soy_sauce.png",
    "condiment_pack": "res://assets/icons/condiments/secret_sauce_12.png",
    "empower": "res://assets/icons/condiments/caramel.png",
    "echo": "res://assets/icons/condiments/relish.png",
    "ward": "res://assets/icons/condiments/mayonnaise.png",
    "energy_spike": "res://assets/icons/condiments/bbg_sauce.png",
    "mult_spike": "res://assets/icons/condiments/hot_sauce.png",
    "forward_gift": "res://assets/icons/condiments/ranch.png",
    "mint_sip": "res://assets/icons/condiments/chipotle_mayo.png",
    "opening_round": "res://assets/icons/condiments/secret_sauce_11.png",
    "closing_round": "res://assets/icons/condiments/secret_sauce_13.png",
}

# Longest-first text replacements across project files.
TEXT_REPLACEMENTS: list[tuple[str, str]] = [
    ("PotionManager", "CondimentManager"),
    ("PotionCatalog", "CondimentCatalog"),
    ("PotionShopItem", "CondimentShopItem"),
    ("PotionEdgeGlow", "CondimentEdgeGlow"),
    ("PotionBelt", "CondimentBelt"),
    ("PotionSlot", "CondimentSlot"),
    ("POTION_ITEM_SCENE", "CONDIMENT_ITEM_SCENE"),
    ("POTION_PACK", "CONDIMENT_PACK"),
    ("POTIONS_DIR", "CONDIMENTS_DIR"),
    ("CONSUME_POTION", "CONSUME_CONDIMENT"),
    ("POTION_HOVER_A", "CONDIMENT_HOVER_A"),
    ("POTION_HOVER_B", "CONDIMENT_HOVER_B"),
    ("POTION_GRAB", "CONDIMENT_GRAB"),
    ("play_potion_hover", "play_condiment_hover"),
    ("play_potion_splash", "play_condiment_splash"),
    ("refresh_potion_badges", "refresh_condiment_badges"),
    ("_potion_splash", "_condiment_splash"),
    ("set_potion_target_highlights", "set_condiment_target_highlights"),
    ("clear_potion_target_highlights", "clear_condiment_target_highlights"),
    ("potion_consume_animation_finished", "condiment_consume_animation_finished"),
    ("potion_consume_started", "condiment_consume_started"),
    ("potion_targeting_changed", "condiment_targeting_changed"),
    ("potion_fuses_changed", "condiment_fuses_changed"),
    ("potion_belt_changed", "condiment_belt_changed"),
    ("potion_use_failed", "condiment_use_failed"),
    ("sold_potion_indices", "sold_condiment_indices"),
    ("_displayed_potions", "_displayed_condiments"),
    ("_selected_potion_ui", "_selected_condiment_ui"),
    ("merchant_potions", "merchant_condiments"),
    ("_refresh_merchant_potions", "_refresh_merchant_condiments"),
    ("_display_merchant_potions", "_display_merchant_condiments"),
    ("_clear_potion_selection", "_clear_condiment_selection"),
    ("_complete_potion_purchase", "_complete_condiment_purchase"),
    ("_apply_sold_potion_indices", "_apply_sold_condiment_indices"),
    ("_on_stock_potion_selected", "_on_stock_condiment_selected"),
    ("_on_stock_potion_gold_purchase_requested", "_on_stock_condiment_gold_purchase_requested"),
    ("_on_stock_potion_token_purchase_requested", "_on_stock_condiment_token_purchase_requested"),
    ("_on_potion_targeting_changed", "_on_condiment_targeting_changed"),
    ("_on_potion_fuses_changed", "_on_condiment_fuses_changed"),
    ("potion_fuse_line", "condiment_fuse_line"),
    ("PotionFuseLine", "CondimentFuseLine"),
    ("_set_potion_fuse_line", "_set_condiment_fuse_line"),
    ("get_targeting_potion", "get_targeting_condiment"),
    ("are_potions_blocked", "are_condiments_blocked"),
    ("add_potion", "add_condiment"),
    ("potion_fuses", "condiment_fuses"),
    ("potion_id", "condiment_id"),
    ("potion_pack", "condiment_pack"),
    ("playtest_potions", "playtest_condiments"),
    ("--no-potions", "--no-condiments"),
    ("_use_potions", "_use_condiments"),
    ("PotionsGrid", "CondimentsGrid"),
    ("PotionShelf", "CondimentShelf"),
    ("potions_grid", "condiments_grid"),
    ('"potions"', '"condiments"'),
    ("class_name Potion", "class_name Condiment"),
    ("script_class=\"Potion\"", "script_class=\"Condiment\""),
    ("as Potion", "as Condiment"),
    ("Array[Potion]", "Array[Condiment]"),
    (": Potion", ": Condiment"),
    ("(potion:", "(condiment:"),
    ("(potion)", "(condiment)"),
    (" potion:", " condiment:"),
    (" potion ", " condiment "),
    (" potion\n", " condiment\n"),
    (" potion.", " condiment."),
    (" potion,", " condiment,"),
    (" potion)", " condiment)"),
    ("for potion", "for condiment"),
    ("var potion", "var condiment"),
    ("new_potion", "new_condiment"),
    ("_potion", "_condiment"),
    ("potion.", "condiment."),
    ("res://scripts/resources/potion.gd", "res://scripts/resources/condiment.gd"),
    ("res://scripts/helpers/potion_catalog.gd", "res://scripts/helpers/condiment_catalog.gd"),
    ("res://scripts/autoload/potion_manager.gd", "res://scripts/autoload/condiment_manager.gd"),
    ("res://scenes/ui/potions/", "res://scenes/ui/condiments/"),
    ("potion_belt.tscn", "condiment_belt.tscn"),
    ("potion_slot.tscn", "condiment_slot.tscn"),
    ("potion_shop_item.tscn", "condiment_shop_item.tscn"),
    ("potion_edge_glow.tscn", "condiment_edge_glow.tscn"),
    ("potion_belt.gd", "condiment_belt.gd"),
    ("potion_slot.gd", "condiment_slot.gd"),
    ("potion_shop_item.gd", "condiment_shop_item.gd"),
    ("potion_edge_glow.gd", "condiment_edge_glow.gd"),
    ("PotionManager=", "CondimentManager="),
    ("id = \"potion_pack\"", "id = \"condiment_pack\""),
    ("potion:rewrite_omen", "condiment:rewrite_omen"),
    ("potion_pack:r", "condiment_pack:r"),
    (":potion:", ":condiment:"),
    ("Potion.", "Condiment."),
    ("Potion", "Condiment"),
]

SCAN_EXTENSIONS = {".gd", ".tscn", ".tres", ".godot", ".py", ".md"}
SKIP_DIRS = {".git", ".godot", "node_modules"}


def apply_replacements(text: str) -> str:
    for old, new in TEXT_REPLACEMENTS:
        text = text.replace(old, new)
    return text


def rename_files() -> None:
    (ROOT / "scenes/ui/condiments").mkdir(parents=True, exist_ok=True)
    for old_rel, new_rel in FILE_RENAMES:
        old_path = ROOT / old_rel
        new_path = ROOT / new_rel
        if not old_path.exists():
            continue
        new_path.parent.mkdir(parents=True, exist_ok=True)
        if new_path.exists():
            new_path.unlink()
        old_path.rename(new_path)
        print(f"renamed {old_rel} -> {new_rel}")
    potions_dir = ROOT / "scenes/ui/potions"
    if potions_dir.exists() and not any(potions_dir.iterdir()):
        potions_dir.rmdir()


def update_condiment_tres() -> None:
    condiments_dir = ROOT / "resources/condiments"
    for tres_path in sorted(condiments_dir.glob("*.tres")):
        text = tres_path.read_text(encoding="utf-8")
        id_match = re.search(r'^id = "([^"]+)"', text, re.MULTILINE)
        if not id_match:
            continue
        condiment_id = id_match.group(1)
        if condiment_id == "potion_pack":
            condiment_id = "condiment_pack"
            text = text.replace('id = "potion_pack"', 'id = "condiment_pack"')
        icon_path = CONDIMENT_ICONS.get(condiment_id)
        if icon_path:
            text = re.sub(
                r'\[ext_resource type="Texture2D"[^\]]*path="[^"]+" id="2_icon"\]',
                f'[ext_resource type="Texture2D" path="{icon_path}" id="2_icon"]',
                text,
                count=1,
            )
        text = apply_replacements(text)
        tres_path.write_text(text, encoding="utf-8")
        print(f"updated {tres_path.relative_to(ROOT)}")


def scan_and_replace_files() -> None:
    for dirpath, dirnames, filenames in os.walk(ROOT):
        dirnames[:] = [d for d in dirnames if d not in SKIP_DIRS]
        for filename in filenames:
            path = Path(dirpath) / filename
            if path.suffix not in SCAN_EXTENSIONS:
                continue
            if path.name == "rename_potions_to_condiments.py":
                continue
            rel = path.relative_to(ROOT)
            if str(rel).startswith("assets/"):
                continue
            original = path.read_text(encoding="utf-8")
            updated = apply_replacements(original)
            if updated != original:
                path.write_text(updated, encoding="utf-8")
                print(f"patched {rel}")


def patch_condiment_resource_script() -> None:
    path = ROOT / "scripts/resources/condiment.gd"
    if not path.exists():
        return
    text = path.read_text(encoding="utf-8")
    text = text.replace(
        "## One merchant drink. Belt slots and shop stock hold these, not hand cards.",
        "## One merchant condiment. Belt slots and shop stock hold these, not hand cards.",
    )
    path.write_text(text, encoding="utf-8")


def patch_condiment_manager_header() -> None:
    path = ROOT / "scripts/autoload/condiment_manager.gd"
    if not path.exists():
        return
    text = path.read_text(encoding="utf-8")
    text = text.replace(
        "## Run-long potion belt, targeting, and fuses applied to placed cards.",
        "## Run-long condiment belt, targeting, and fuses applied to placed cards.",
    )
    path.write_text(text, encoding="utf-8")


def main() -> None:
    rename_files()
    scan_and_replace_files()
    update_condiment_tres()
    patch_condiment_resource_script()
    patch_condiment_manager_header()
    print("done")


if __name__ == "__main__":
    main()
