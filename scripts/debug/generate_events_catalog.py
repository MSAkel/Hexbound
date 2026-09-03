#!/usr/bin/env python3
"""Export day-event catalog from event_manager.gd to docs/events_catalog.csv."""

from __future__ import annotations

import csv
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
EVENT_MANAGER = ROOT / "scripts" / "autoload" / "event_manager.gd"
OUT_CSV = ROOT / "docs" / "events_catalog.csv"

HEADERS = [
    "Enum",
    "Name",
    "Description",
    "Event_Days",
    "Code_Notes",
]

# Feast-facing notes for enum names that still use legacy identifiers in code.
CODE_NOTES = {
    "FADING_SECTOR": "Enum name is legacy. Player name is Fading Course.",
    "SEALED_HEXES": "Enum name is legacy. Player name is Sealed Spots.",
}


def _read_event_manager_text() -> str:
    return EVENT_MANAGER.read_text(encoding="utf-8")


def _parse_enum_order(text: str) -> list[str]:
    block = re.search(r"enum Type \{([^}]+)\}", text, flags=re.DOTALL)
    if not block:
        return []
    names: list[str] = []
    for line in block.group(1).splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        names.append(line.rstrip(",").strip())
    return names


def _parse_event_info(text: str) -> dict[str, dict[str, str]]:
    block = re.search(r"const EVENT_INFO := \{([^;]+)\}", text, flags=re.DOTALL)
    if not block:
        return {}
    entries: dict[str, dict[str, str]] = {}
    for match in re.finditer(
        r"Type\.([A-Z_]+):\s*\{\s*"
        r'"name":\s*"([^"]*)",\s*'
        r'"description":\s*"([^"]*)",\s*'
        r'"rounds":\s*([A-Z_]+)',
        block.group(1),
        flags=re.DOTALL,
    ):
        enum_name, name, description, rounds_const = match.groups()
        entries[enum_name] = {
            "name": name,
            "description": description,
            "rounds": rounds_const,
        }
    return entries


def _rounds_label(rounds_const: str) -> str:
    mapping = {
        "ANY_EVENT_ROUND": "3, 6, 9",
        "LATE_EVENT_ROUNDS": "6, 9",
        "FINAL_EVENT_ROUND": "9",
    }
    return mapping.get(rounds_const, rounds_const)


def build_rows() -> list[list[str]]:
    text = _read_event_manager_text()
    enum_order = _parse_enum_order(text)
    event_info = _parse_event_info(text)
    rows: list[list[str]] = []
    for enum_name in enum_order:
        info = event_info.get(enum_name)
        if info is None:
            continue
        rows.append(
            [
                enum_name,
                info["name"],
                info["description"],
                _rounds_label(info["rounds"]),
                CODE_NOTES.get(enum_name, ""),
            ]
        )
    return rows


def write_csv(rows: list[list[str]], path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.writer(handle)
        writer.writerow(HEADERS)
        writer.writerows(rows)
        writer.writerow([])
        writer.writerow(["Glossary", "docs/feast_glossary.md"])
        writer.writerow(["Source", "scripts/autoload/event_manager.gd"])


def main() -> None:
    rows = build_rows()
    write_csv(rows, OUT_CSV)
    print(f"Wrote {len(rows)} events to {OUT_CSV}")


if __name__ == "__main__":
    main()
