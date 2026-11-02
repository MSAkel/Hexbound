"""Build the Meal Collection page: every Meal with its real-world history and its game data.

    godot --headless --path . res://scenes/debug/export_catalog.tscn -- --out=catalog.json
    python scripts/debug/catalog/build_meal_collection.py catalog.json meal_collection.html [--commit=<sha>]

History, fun facts and traditional ingredients come from meal_collection/meal_lore.json (draft
lore, keyed by meal id; not used by the game). Effect text, category, icon and recipe come from
the export, so they always match the build. A Meal with no lore entry still appears, marked as
"still to write", and is listed when the page is built.
Headings use meal_collection/Gimbot-Accented.otf, a copy of the game font with its blank
accented letters filled in (see compose_accents.py). Needs Pillow (pip install pillow).
"""

import base64
import json
import sys
from pathlib import Path

from build_catalog_page import ROOT, icon_data_uri

HERE = Path(__file__).parent / "meal_collection"
STAT_ICONS = {
    "mult": "res://assets/icons/stats/mult.png",
    "flavour": "res://assets/icons/stats/flavour.png",
    "garnish": "res://assets/icons/stats/garnish.png",
}


def main() -> None:
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    commit = next((a.split("=", 1)[1] for a in sys.argv[1:] if a.startswith("--commit=")), "")
    data = json.loads(Path(args[0]).read_text(encoding="utf-8"))
    lore = json.loads((HERE / "meal_lore.json").read_text(encoding="utf-8"))["meals"]
    names = {card["id"]: card["name"] for card in data["cards"]}

    icons = {key: icon_data_uri(path, 40) for key, path in STAT_ICONS.items()}
    meals = []
    for card in sorted((c for c in data["cards"] if c["type"] == "Meal"), key=lambda c: c["name"]):
        if card["icon"] and card["icon"] not in icons:
            icons[card["icon"]] = icon_data_uri(card["icon"], 160)
        recipe = [[names.get(card_id, card_id), False] for card_id in card.get("recipe_cards", [])]
        for kind, count in (card.get("recipe") or {}).items():
            recipe += [[kind, True]] * int(count)
        meals.append({
            "id": card["id"],
            "name": card["name"],
            "category": card.get("category") or (card.get("tags") or ["Dish"])[0],
            "icon": card["icon"],
            "effect": card["description"]["raw"],
            "recipe": recipe,
            "lore": lore.get(card["id"]),
        })

    font = base64.b64encode((HERE / "Gimbot-Accented.otf").read_bytes()).decode()
    html = (
        (HERE / "template.html").read_text(encoding="utf-8")
        .replace("/*__FONT__*/", font)
        .replace("/*__ICONS__*/null", json.dumps(icons))
        .replace("/*__MEALS__*/null", json.dumps({"commit": commit, "meals": meals}, ensure_ascii=False))
    )
    Path(args[1]).write_text(html, encoding="utf-8")
    missing = [m["name"] for m in meals if not m["lore"]]
    unused = sorted(set(lore) - {m["id"] for m in meals})
    print(f"wrote {args[1]} ({len(html) // 1024} KB, {len(meals)} meals)")
    if missing:
        print("no lore yet: " + ", ".join(missing))
    if unused:
        print("lore for meals no longer in the game: " + ", ".join(unused))


if __name__ == "__main__":
    main()
