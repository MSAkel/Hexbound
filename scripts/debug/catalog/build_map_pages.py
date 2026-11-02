"""Build the four map pages from the JSON written by export_catalog.tscn.

    godot --headless --path . res://scenes/debug/export_catalog.tscn -- --out=catalog.json
    python scripts/debug/catalog/build_map_pages.py catalog.json <out_dir> [--commit=<sha>]

Writes meal_map.html, station_map.html, dependency_map.html and technique_map.html to out_dir.
The Meal, Station and Dependency maps share map_template.html (meals, stations, or both);
the Technique Map uses technique_map_template.html, whose hand mapping of each Technique to
the mechanics it relies on and affects lives in the template's MAP table.
Icons and the Gimbot display font are embedded, so each page is one self-contained file.
Needs Pillow (pip install pillow).
"""

import base64
import json
import sys
from pathlib import Path

from build_catalog_page import ROOT, STAT_ICONS, icon_data_uri

HERE = Path(__file__).parent
SIZES = {"cards": 96, "condiments": 96, "stations": 96, "chefs": 160}
PAGES = {
    "meal_map": ("map_template.html", {"__TITLE__": "Meal Map", "__MODE__": "meals"}, ["cards"]),
    "station_map": ("map_template.html", {"__TITLE__": "Station Map", "__MODE__": "stations"}, ["cards", "stations"]),
    "dependency_map": ("map_template.html", {"__TITLE__": "Dependency Map", "__MODE__": "all"}, ["cards", "stations", "chefs"]),
    "technique_map": ("technique_map_template.html", {}, ["cards", "condiments", "stations", "chefs"]),
}


def build_icons(data: dict, groups: list[str]) -> dict[str, str]:
    icons: dict[str, str] = {}
    for group in groups:
        for entry in data[group]:
            path = entry.get("icon")
            if path and path not in icons:
                icons[path] = icon_data_uri(path, SIZES[group])
    return icons


def main() -> None:
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    commit = next((a.split("=", 1)[1] for a in sys.argv[1:] if a.startswith("--commit=")), "")
    data = json.loads(Path(args[0]).read_text(encoding="utf-8"))
    data["commit"] = commit
    out_dir = Path(args[1])
    out_dir.mkdir(parents=True, exist_ok=True)

    font = base64.b64encode((ROOT / "assets/fonts/Gimbot-Regular.otf").read_bytes()).decode()
    stat_icons = {key: icon_data_uri(path, 40) for key, path in STAT_ICONS.items()}
    for page, (template, fills, groups) in PAGES.items():
        html = (HERE / template).read_text(encoding="utf-8")
        for key, value in fills.items():
            html = html.replace(key, value)
        html = (
            html.replace("/*__FONT__*/", font)
            .replace("/*__DATA__*/null", json.dumps(data, ensure_ascii=False))
            .replace("/*__ICONS__*/null", json.dumps(build_icons(data, groups)))
            .replace("/*__STAT_ICONS__*/null", json.dumps(stat_icons))
        )
        if "/*__" in html or "__TITLE__" in html or "__MODE__" in html:
            raise SystemExit(f"{page}: a placeholder was left unfilled")
        path = out_dir / f"{page}.html"
        path.write_text(html, encoding="utf-8")
        print(f"wrote {path} ({len(html) // 1024} KB)")


if __name__ == "__main__":
    main()
