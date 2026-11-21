class_name StationKit
extends Resource

## Starting-deck cards for one Station type (design: claude/deck-and-draw-design.md, section 8).
## One ordered list of 9 entries used at three sizes:
## mini (first 5): the Station's setup (1 Kitchenware + 3 Ingredients) and 1 Meal those cards complete,
## small (first 6): one more card, full (all 9): a second Meal, a second Kitchenware and a spare.
## Entries are card ids or random entries ("random:fruit", "random:kitchenware", "random:ingredient").
## Every Meal can be completed from cards earlier in the same kit. All picks are untuned.

enum Size { MINI, SMALL, FULL }

const SIZE_COUNTS := {Size.MINI: 5, Size.SMALL: 6, Size.FULL: 9}
const SIZE_IDS := {"mini": Size.MINI, "small": Size.SMALL, "full": Size.FULL}

## StationType id this kit builds toward, such as "fry_station".
@export var station_id: String = ""
@export var cards: Array[String] = []


## The entries for one size. Slots count from 1 in kit_swaps, like the design doc.
func entries_for(size: Size) -> Array[String]:
	var count: int = SIZE_COUNTS[size]
	return cards.slice(0, mini(count, cards.size()))


static func size_from_id(size_id: String) -> Size:
	return SIZE_IDS.get(size_id, Size.FULL)
