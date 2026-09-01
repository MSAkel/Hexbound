class_name CardKeywordGlossary
extends RefCounted

## Shared keyword highlighting and hover-tooltip copy for card descriptions.
## Register new entries in _static_init so CardUI picks them up automatically.

class Keyword:
	var id: StringName
	var tokens: PackedStringArray
	var display_name: String
	var color: Color
	## Empty tooltip means the word is colored but does not spawn a hover panel.
	var tooltip: String

	func _init(
		p_id: StringName,
		p_tokens: PackedStringArray,
		p_display_name: String,
		p_color: Color,
		p_tooltip: String = ""
	) -> void:
		id = p_id
		tokens = p_tokens
		display_name = p_display_name
		color = p_color
		tooltip = p_tooltip


	func matches_token(token: String) -> bool:
		var needle := token.to_lower()
		for candidate: String in tokens:
			if candidate.to_lower() == needle:
				return true
		return false


static var _keywords: Array[Keyword] = []
static var _match_regex: RegEx = null

const COLOR_ENERGY := Color(0.0, 0.52, 0.66)
const COLOR_SCORE := Color(0.0, 0.42, 0.55)
const COLOR_MULT := Color(0.52, 0.16, 0.48)
const COLOR_EMPOWER := Color(0.78, 0.34, 0.0)
const COLOR_FOLLOWING := Color(0.18, 0.52, 0.36)
const COLOR_RETRIGGER := Color(0.45, 0.35, 0.72)
const COLOR_BREAK := Color(0.72, 0.22, 0.22)
const COLOR_RELAY := Color(0.28, 0.48, 0.62)
const COLOR_PRODUCER := Color(0.42, 0.52, 0.28)


static func _static_init() -> void:
	# Longer tokens are matched before shorter ones.
	# Leave tooltip empty to color the word without spawning a hover panel.
	register(
		"energy",
		["energy"],
		"Energy",
		COLOR_ENERGY,
		"A segment’s base points before Mult is applied to produce Score"
	)
	register(
		"score",
		["score"],
		"Score",
		COLOR_SCORE,
		"The resource needed to win a round"
	)
	register("mult", ["mult"], "Mult", COLOR_MULT, "Multiplies Energy in the same segment. Starts at 1.")
	register(
		"empower",
		["empower", "empowers", "empowered", "empowerment"],
		"Empower",
		COLOR_EMPOWER,
		"Doubles the output of a production card."
	)
	register(
		"following",
		["following"],
		"Following",
		COLOR_FOLLOWING,
		"Later in trigger order"
	)
	register(
		"following",
		["following"],
		"Following",
		COLOR_FOLLOWING,
		"Later in trigger order on the map"
	)
	register(
		"retrigger",
		["retrigger", "retriggers", "retriggered"],
		"Retrigger",
		COLOR_RETRIGGER,
		"Triggers the card again this turn."
	)
	register(
		"break",
		["break", "breaks", "broken"],
		"Break",
		COLOR_BREAK,
		"Destroys the card"
	)
	register(
		"relay",
		["relay", "relays", "relayed"],
		"Relay",
		COLOR_RELAY,
		"Sends Energy, Mult, or Gold to another segment."
	)
	register(
		"producer",
		["producer", "producers"],
		"Producer",
		COLOR_PRODUCER,
		"Generates Energy, Mult, or Gold when triggered."
	)


static func register(
	id: StringName,
	tokens: Array,
	display_name: String,
	color: Color,
	tooltip: String = ""
) -> void:
	var packed_tokens := PackedStringArray()
	for token: Variant in tokens:
		packed_tokens.append(String(token))

	for existing: Keyword in _keywords:
		if existing.id == id:
			existing.tokens = packed_tokens
			existing.display_name = display_name
			existing.color = color
			existing.tooltip = tooltip
			_match_regex = null
			return

	_keywords.append(Keyword.new(id, packed_tokens, display_name, color, tooltip))
	_match_regex = null


static func to_bbcode(source: String) -> String:
	if source.is_empty() or _keywords.is_empty():
		return _escape_bbcode(source)

	var regex := _get_match_regex()
	if regex == null:
		return _escape_bbcode(source)

	var matches := regex.search_all(source)
	if matches.is_empty():
		return _escape_bbcode(source)

	var result := ""
	var cursor := 0
	for regex_match: RegExMatch in matches:
		var start := regex_match.get_start()
		var matched := regex_match.get_string()
		result += _escape_bbcode(source.substr(cursor, start - cursor))
		var keyword := find_keyword(matched)
		var display := _capitalize_first(matched)
		if keyword == null:
			result += _escape_bbcode(display)
		else:
			result += "[color=#%s]%s[/color]" % [keyword.color.to_html(false), _escape_bbcode(display)]
		cursor = regex_match.get_end()

	result += _escape_bbcode(source.substr(cursor))
	return result


## Unique keywords that have tooltip copy, in first-appearance order.
static func tooltip_entries(source: String) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if source.is_empty() or _keywords.is_empty():
		return entries

	var regex := _get_match_regex()
	if regex == null:
		return entries

	var seen := {}
	for regex_match: RegExMatch in regex.search_all(source):
		var keyword := find_keyword(regex_match.get_string())
		if keyword == null:
			continue
		if keyword.tooltip.is_empty():
			continue
		if seen.has(keyword.id):
			continue
		seen[keyword.id] = true
		entries.append({
			"id": keyword.id,
			"title": keyword.display_name,
			"text": "%s\n%s" % [keyword.display_name, keyword.tooltip],
			"color": keyword.color,
		})

	return entries


static func find_keyword(token: String) -> Keyword:
	for keyword: Keyword in _keywords:
		if keyword.matches_token(token):
			return keyword
	return null


static func _get_match_regex() -> RegEx:
	if _match_regex != null:
		return _match_regex

	var tokens: Array[String] = []
	for keyword: Keyword in _keywords:
		for token: String in keyword.tokens:
			if not tokens.has(token):
				tokens.append(token)

	if tokens.is_empty():
		return null

	# PackedStringArray has no sort_custom. Longer tokens must win in the regex.
	tokens.sort_custom(func(a: String, b: String) -> bool:
		return a.length() > b.length()
	)

	var escaped: PackedStringArray = []
	for token: String in tokens:
		escaped.append(_escape_regex(token))

	_match_regex = RegEx.new()
	var compile_error := _match_regex.compile("(?i)\\b(?:%s)\\b" % "|".join(escaped))
	if compile_error != OK:
		push_error("CardKeywordGlossary failed to compile keyword regex.")
		_match_regex = null
	return _match_regex


static func _capitalize_first(text: String) -> String:
	if text.is_empty():
		return text
	return text.substr(0, 1).to_upper() + text.substr(1)


static func _escape_bbcode(text: String) -> String:
	return text.replace("[", "[lb]")


static func _escape_regex(text: String) -> String:
	const SPECIALS := "\\.^$|*+?()[]{}"
	var escaped := ""
	for i: int in text.length():
		var character := text.substr(i, 1)
		if SPECIALS.contains(character):
			escaped += "\\"
		escaped += character
	return escaped
