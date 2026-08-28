extends Node

## Run-scoped RNG for deterministic gameplay rolls. Cosmetic effects keep using the global RNG.

const SEED_CHARS := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
const SEED_DISPLAY_LENGTH := 8
const STREAM_GAMEPLAY := "gameplay"

var _streams: Dictionary = {}
var _active_stream: String = STREAM_GAMEPLAY
var _display_seed := ""
var _is_seeded_run := false


## Start a run from an optional custom seed string. Empty text generates a random display seed.
func begin_new_run(seed_text: String = "") -> void:
	_streams.clear()
	_active_stream = STREAM_GAMEPLAY
	var cleaned := _normalize_seed_text(seed_text)
	_is_seeded_run = not cleaned.is_empty()
	if _is_seeded_run:
		_display_seed = cleaned
	else:
		_display_seed = _generate_random_seed()


## Re-seed every stream after an in-run restart.
func restart_same_seed() -> void:
	if _display_seed.is_empty():
		push_warning("RunRng: restart requested before a run seed was set.")
		return
	_streams.clear()
	_active_stream = STREAM_GAMEPLAY


func get_display_seed() -> String:
	return _display_seed


func is_seeded_run() -> bool:
	return _is_seeded_run


## Seeded runs skip unlock progress and lifetime stat updates tied to unlocks.
func is_unlock_progress_disabled() -> bool:
	return _is_seeded_run


## Keep only A-Z and 0-9 so pasted labels or punctuation cannot break seed entry.
func normalize_seed_text(seed_text: String) -> String:
	return _normalize_seed_text(seed_text)


func read_seed_from_clipboard() -> String:
	return _normalize_seed_text(DisplayServer.clipboard_get())


func copy_display_seed_to_clipboard() -> bool:
	var display_seed := get_display_seed()
	if display_seed.is_empty():
		return false
	DisplayServer.clipboard_set(display_seed)
	return true


## Route all rolls in callback through a named stream derived from the run seed.
func using_stream(stream_name: String, callback: Callable) -> Variant:
	var previous_stream := _active_stream
	_active_stream = stream_name
	var result: Variant = callback.call()
	_active_stream = previous_stream
	return result


## Same as using_stream, but always starts this named stream from the beginning of the seed.
func using_fresh_stream(stream_name: String, callback: Callable) -> Variant:
	_streams.erase(stream_name)
	return using_stream(stream_name, callback)


## Independent RNG for a loot key. Same seed plus key always replays from the start.
## Does not share state with gameplay or with cached named streams.
func create_rng(stream_name: String) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed_from_display_text("%s#%s" % [_display_seed, stream_name])
	return rng


## Isolated RNG for one card effect. Same seed, tile, card, and trigger count replay.
## Combat rolls no longer share a single advancing tape that other effects can desync.
func create_card_effect_rng(tile: Hex, card: TileCard = null, tag: String = "effect") -> RandomNumberGenerator:
	var resolved_card := card
	if resolved_card == null and tile != null:
		resolved_card = tile.active_tile_card

	var card_id := resolved_card.id if resolved_card != null else "none"
	var activation_index := 0
	if resolved_card != null:
		activation_index = GameManager.get_tile_card_activation_count_this_turn(resolved_card)

	var coords := tile.coordinates if tile != null else Vector2i.ZERO
	return create_rng("card_fx:r%d:s%d:%d,%d:%s:n%d:%s" % [
		GameManager.current_round,
		GameManager.turn_stamp,
		coords.x,
		coords.y,
		card_id,
		activation_index,
		tag,
	])


## Fisher-Yates shuffle using a caller-owned generator instead of the active stream.
func shuffle_with(rng: RandomNumberGenerator, array: Array) -> void:
	for index in range(array.size() - 1, 0, -1):
		var swap_index := rng.randi_range(0, index)
		var temp: Variant = array[index]
		array[index] = array[swap_index]
		array[swap_index] = temp


func pick_random_with(rng: RandomNumberGenerator, array: Array) -> Variant:
	if array.is_empty():
		return null
	return array[rng.randi_range(0, array.size() - 1)]


## Sort placed runes by map coordinates so pool order cannot change a pick.
func sort_placed_tile_cards(candidates: Array[TileCard], tile_map: HexTileMap) -> Array[TileCard]:
	var sorted := candidates.duplicate()
	sorted.sort_custom(func(a: TileCard, b: TileCard) -> bool:
		var a_hex := tile_map.get_hex_for_tile_card(a) if tile_map != null else null
		var b_hex := tile_map.get_hex_for_tile_card(b) if tile_map != null else null
		var a_coords := a_hex.coordinates if a_hex != null else Vector2i(2147483647, 2147483647)
		var b_coords := b_hex.coordinates if b_hex != null else Vector2i(2147483647, 2147483647)
		if a_coords.x != b_coords.x:
			return a_coords.x < b_coords.x
		if a_coords.y != b_coords.y:
			return a_coords.y < b_coords.y
		return a.id < b.id
	)
	return sorted


func pick_random_placed_tile_card(
	candidates: Array[TileCard],
	rng: RandomNumberGenerator,
	tile_map: HexTileMap
) -> TileCard:
	return pick_random_with(rng, sort_placed_tile_cards(candidates, tile_map)) as TileCard


## Build a stable stream key from run position so the same moment always rolls the same pack.
## Fail offers include remaining_turns so they do not depend on challenge turn-cap math.
func build_rune_offer_stream_name(
	round_number: int,
	remaining_turns: int,
	is_round_reward: bool,
	reroll_index: int
) -> String:
	if is_round_reward:
		return "rune_offer:r%d:reward:e%d" % [round_number, reroll_index]
	return "rune_offer:r%d:fail:t%d:e%d" % [round_number, remaining_turns, reroll_index]


func build_merchant_stream_name(round_number: int, reroll_index: int) -> String:
	return "merchant:r%d:e%d" % [round_number, reroll_index]


func randf() -> float:
	return _current_rng().randf()


func randf_range(from: float, to: float) -> float:
	return _current_rng().randf_range(from, to)


func randi() -> int:
	return _current_rng().randi()


func randi_range(from: int, to: int) -> int:
	return _current_rng().randi_range(from, to)


## Fisher-Yates shuffle backed by the active run stream.
func shuffle(array: Array) -> void:
	var rng := _current_rng()
	for index in range(array.size() - 1, 0, -1):
		var swap_index := rng.randi_range(0, index)
		var temp: Variant = array[index]
		array[index] = array[swap_index]
		array[swap_index] = temp


func pick_random(array: Array) -> Variant:
	if array.is_empty():
		return null
	return array[randi_range(0, array.size() - 1)]


func pick_random_tile_card(candidates: Array[TileCard]) -> TileCard:
	var sorted := candidates.duplicate()
	sorted.sort_custom(func(a: TileCard, b: TileCard) -> bool:
		return a.id < b.id
	)
	return pick_random(sorted) as TileCard


func capture_run_state() -> Dictionary:
	var state := {
		"display_seed": _display_seed,
		"is_seeded_run": _is_seeded_run,
	}
	# Only persist a stream that has actually been used. Writing 0 over a fresh
	# seeded generator on load is not the same as "never rolled".
	if _streams.has(STREAM_GAMEPLAY):
		state["gameplay_state"] = int(_stream(STREAM_GAMEPLAY).state)
	return state


func apply_run_state(state: Dictionary) -> void:
	_display_seed = _normalize_seed_text(String(state.get("display_seed", "")))
	_is_seeded_run = bool(state.get("is_seeded_run", false))
	_streams.clear()
	_active_stream = STREAM_GAMEPLAY
	if state.has("gameplay_state") or state.has("rng_state"):
		_stream(STREAM_GAMEPLAY).state = int(state.get("gameplay_state", state.get("rng_state", 0)))


func _current_rng() -> RandomNumberGenerator:
	return _stream(_active_stream)


func _stream(stream_name: String) -> RandomNumberGenerator:
	if not _streams.has(stream_name):
		var rng := RandomNumberGenerator.new()
		rng.seed = _seed_from_display_text("%s#%s" % [_display_seed, stream_name])
		_streams[stream_name] = rng
	return _streams[stream_name]


## Stable FNV-1a hash so the same display seed always maps to the same RNG stream.
func _seed_from_display_text(text: String) -> int:
	var hash_value := 1469598103934665603
	for index in text.length():
		hash_value ^= text.unicode_at(index)
		hash_value *= 1099511628211
	return hash_value


func _normalize_seed_text(seed_text: String) -> String:
	var cleaned := seed_text.strip_edges().to_upper()
	var normalized := ""
	for index in cleaned.length():
		var character := cleaned[index]
		if (character >= "0" and character <= "9") or (character >= "A" and character <= "Z"):
			normalized += character
	return normalized


func _generate_random_seed() -> String:
	var builder := ""
	var temp_rng := RandomNumberGenerator.new()
	temp_rng.randomize()
	for _i in SEED_DISPLAY_LENGTH:
		builder += SEED_CHARS[temp_rng.randi_range(0, SEED_CHARS.length() - 1)]
	return builder
