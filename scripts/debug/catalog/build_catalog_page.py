"""Build the content catalog page from the JSON written by export_catalog.tscn.

    godot --headless --path . res://scenes/debug/export_catalog.tscn -- --out=catalog.json
    python scripts/debug/catalog/build_catalog_page.py catalog.json catalog.html [--commit=<sha>]

Icons and the Gimbot display font are embedded, so the page is one self-contained file.
Needs Pillow (pip install pillow).
"""

import base64
import io
import json
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[3]
TEMPLATE = Path(__file__).with_name("catalog_template.html")
STAT_ICONS = {
    "flavour": "res://assets/icons/stats/flavour.png",
    "mult": "res://assets/icons/stats/mult.png",
    "gold": "res://assets/icons/stats/gold.png",
    "garnish": "res://assets/icons/stats/garnish.png",
    "trigger": "res://assets/icons/stats/fire.png",
}


def res_to_path(res_path: str) -> Path:
    return ROOT / res_path.removeprefix("res://")


def icon_data_uri(res_path: str, size: int) -> str:
    image = Image.open(res_to_path(res_path)).convert("RGBA")
    image.thumbnail((size, size), Image.LANCZOS)
    buffer = io.BytesIO()
    image.save(buffer, "PNG", optimize=True)
    return "data:image/png;base64," + base64.b64encode(buffer.getvalue()).decode()


def main() -> None:
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    commit = next((a.split("=", 1)[1] for a in sys.argv[1:] if a.startswith("--commit=")), "")
    data = json.loads(Path(args[0]).read_text(encoding="utf-8"))
    data["commit"] = commit

    icons: dict[str, str] = {}
    for group, size in (("cards", 96), ("condiments", 96), ("stations", 96), ("chefs", 160)):
        for entry in data[group]:
            path = entry.get("icon")
            if path and path not in icons:
                icons[path] = icon_data_uri(path, size)
    stat_icons = {key: icon_data_uri(path, 40) for key, path in STAT_ICONS.items()}

    font = base64.b64encode((ROOT / "assets/fonts/Gimbot-Regular.otf").read_bytes()).decode()
    html = (
        TEMPLATE.read_text(encoding="utf-8")
        .replace("/*__FONT__*/", font)
        .replace("/*__DATA__*/null", json.dumps(data, ensure_ascii=False))
        .replace("/*__ICONS__*/null", json.dumps(icons))
        .replace("/*__STAT_ICONS__*/null", json.dumps(stat_icons))
    )
    Path(args[1]).write_text(html, encoding="utf-8")
    print(f"wrote {args[1]} ({len(html) // 1024} KB, {len(icons)} icons)")


if __name__ == "__main__":
    main()
