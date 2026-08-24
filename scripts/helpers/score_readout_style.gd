class_name ScoreReadoutStyle
extends RefCounted

## Shared size curve for turn-score, floating text, and segment totals.

const MIN_FONT_SIZE := 72
const MAX_FONT_SIZE := 168
## Scores at or above this use max font size.
const INTENSITY_SCORE_CAP := 1_000_000.0

const SEGMENT_SCORE_COLOR := Color(1.0, 0.85, 0.2, 1.0)

const COLOR_WHITE := Color(1.0, 1.0, 1.0, 1.0)
const COLOR_TEAL := Color(0.18, 0.84, 0.78, 1.0)
const COLOR_ORANGE := Color(1.0, 0.58, 0.22, 1.0)
## Coral red. Saturated but not a warning or damage red.
const COLOR_WARM_RED := Color(0.94, 0.38, 0.36, 1.0)


static func intensity_for_score(score: int) -> float:
	return clampf(
		log(float(maxi(score, 0)) + 1.0) / log(INTENSITY_SCORE_CAP + 1.0),
		0.0,
		1.0
	)


static func font_size_for_score(score: int) -> int:
	return int(lerpf(MIN_FONT_SIZE, MAX_FONT_SIZE, intensity_for_score(score)))


## White to teal to orange to warm red. Tint of each stop strengthens through that band.
static func color_for_score(score: int) -> Color:
	var stops: Array[Color] = [COLOR_WHITE, COLOR_TEAL, COLOR_ORANGE, COLOR_WARM_RED]
	var scaled := intensity_for_score(score) * float(stops.size() - 1)
	var index := mini(int(scaled), stops.size() - 2)
	var local := scaled - float(index)
	# Ease in so the upcoming color's tint builds as the score climbs through the band.
	local *= local
	return stops[index].lerp(stops[index + 1], local)


## Pulls the first integer out of floating text such as "+120" or "1,250".
static func parse_amount(text: String) -> int:
	var regex := RegEx.new()
	regex.compile("-?[\\d,]+")
	var match := regex.search(text)
	if match == null:
		return 0
	return int(match.get_string().replace(",", ""))
