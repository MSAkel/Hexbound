extends Node

## Scripted Sommelier Hour for a short social clip. Stages a mid-run board, then a fake
## cursor picks Wine from the offer, places Grape and Wine, and the Hour resolves for real.
##
## godot --path . --write-movie <out.avi> --fixed-fps 60 res://scenes/debug/showcase.tscn
## Add `-- --probe` to skip the movie and print the Hour score quickly while tuning the board.
## Back up the user-data folder first. The run autosaves and the game speed setting is saved.

const CURSOR_TEXTURE := preload("res://assets/icons/cursor_icon.png")
const CURSOR_SCALE := 1.6
const SEED := "SHOWCASE"
const ROUND := 8
## Day Rating already banked before the clip's Hour.
const BANKED_RATING := 14500
const GAME_SPEED := 1.0
## Engine time scale while the Hour fires, so the clip stays short.
const RESOLVE_TIME_SCALE := 2.2
const PROBE_TIME_SCALE := 6.0

## Regular spots per station, in fire order. Empty strings stay open for the clip.
const BOARD := [
	["steak", "salt", "black_pepper", "skillet", "chicken", ""],
	["lobster", "butter", "whisk", "milk", "salmon", ""],
	["chocolate", "cream", "sugar", "kitchen_torch", "lettuce", ""],
	["olive", "apple", "chef_knife", "", "blender", "lemon"],
]
const MEALS := ["grilled_steak", "lobster_roll", "creme_brulee", ""]
const STAFF := ["", "brine", "", ""]
const HAND := ["grape", "lemon", "chili_pepper"]
const OFFER := ["coffee", "wine", "cheese_fondue"]
## Where the board's grape and wine go in the last station.
const CLIP_STATION := 3
const GRAPE_SPOT := 3

var _cursor: Sprite2D
var _cursor_pos := Vector2(1500, 900)
var _held := false
var _main: Node
var _probe := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_probe = "--probe" in OS.get_cmdline_user_args()
	if _probe:
		Engine.time_scale = PROBE_TIME_SCALE
	TutorialManager.set_enabled(false)
	GameManager.set_game_speed(GAME_SPEED)
	GameManager.selected_chef = ChefRegistry.get_chef_by_id("sommelier")
	RunSaveManager.set_pending_run_seed(SEED)
	get_tree().change_scene_to_file.call_deferred(ScenePaths.MAIN)
	_make_cursor()
	await _wait(3.0)
	_main = get_tree().current_scene
	for child in _main.get_children():
		if child.scene_file_path.ends_with("run_sandbox_overlay.tscn"):
			child.queue_free()
	await _stage()
	await _wait(1.0)
	await _play()
	get_tree().quit()


func _make_cursor() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	var layer := CanvasLayer.new()
	layer.layer = 128
	add_child(layer)
	_cursor = Sprite2D.new()
	_cursor.texture = CURSOR_TEXTURE
	_cursor.centered = false
	_cursor.scale = Vector2.ONE * CURSOR_SCALE
	_cursor.position = _cursor_pos
	layer.add_child(_cursor)


#region Staging

func _stage() -> void:
	var map: HexTileMap = _main.get_node("HexTileMap")
	GameManager.debug_jump_to_round(ROUND)
	for segment in BOARD.size():
		var spots := _segment_spots(map, segment)
		for i in BOARD[segment].size():
			if BOARD[segment][i] != "":
				GameManager.get_tile_card_by_id(BOARD[segment][i]).play_on(spots["regular"][i], false)
		if MEALS[segment] != "":
			GameManager.get_tile_card_by_id(MEALS[segment]).play_on(spots["meal"], false)
	for slot in STAFF.size():
		if STAFF[slot] != "":
			StaffManager.add_staff_to_slot(StaffCatalog.get_by_id(STAFF[slot]), slot)
	var hand: Hand = _main.get_node("MainUI/CardsHand/Hand")
	for card_ui in hand._get_hand_cards():
		card_ui.queue_free()
	await get_tree().process_frame
	for id: String in HAND:
		EventBus.tile_card_selected.emit(GameManager.get_tile_card_by_id(id))
	GameManager.remaining_turns = 2
	GameManager.total_round_score = BANKED_RATING
	EventBus.turn_changed.emit()


## {"regular": [Hex...] in fire order, "meal": first Meal slot}.
func _segment_spots(map: HexTileMap, segment: int) -> Dictionary:
	var regular: Array[Hex] = []
	var meal: Hex = null
	for hex: Hex in map.get_hexes_in_segment(segment):
		if map.is_meal_slot(hex.coordinates):
			if meal == null:
				meal = hex
		else:
			regular.append(hex)
	return {"regular": regular, "meal": meal}

#endregion


#region Clip

func _play() -> void:
	var map: HexTileMap = _main.get_node("HexTileMap")
	print("SHOWCASE_START frame=%d" % Engine.get_frames_drawn())
	var panel := get_tree().get_first_node_in_group("run_card_selection") as CardSelectionUI
	UiManager.show_cards_choice_panel.emit()
	panel.cards_pack.clear()
	for id: String in OFFER:
		panel.cards_pack.append(GameManager.get_tile_card_by_id(id))
	await panel.instantiate_card_choices()
	await _wait(0.45)

	var choices := _choice_cards(panel)
	await _move_to(_center(choices[0]), 0.3)
	await _wait(0.15)
	await _move_to(_center(choices[1]), 0.25)
	await _wait(0.3)
	await _click()
	await _wait(0.6)

	var spots := _segment_spots(map, CLIP_STATION)
	await _drag_hand_card("grape", _hex_screen(spots["regular"][GRAPE_SPOT]))
	await _wait(0.25)
	var score_before := GameManager.total_round_score
	await _drag_hand_card("wine", _hex_screen(spots["meal"]))
	if not _probe:
		Engine.time_scale = RESOLVE_TIME_SCALE

	await EventBus.round_score_count_finished
	if not _probe:
		Engine.time_scale = 1.0
	print("SHOWCASE_COUNTED frame=%d" % Engine.get_frames_drawn())
	print("SHOWCASE_HOUR score=%d total=%d target=%d" % [
		GameManager.total_round_score - score_before,
		GameManager.total_round_score,
		GameManager.required_score,
	])
	await _move_to(Vector2(1500, 950), 0.6)
	await _wait(2.5)
	print("SHOWCASE_END frame=%d" % Engine.get_frames_drawn())


func _choice_cards(panel: CardSelectionUI) -> Array[CardUI]:
	var cards: Array[CardUI] = []
	for slot in panel.choices_container.get_children():
		for wrapper in slot.get_children():
			for node in wrapper.get_children():
				if node is CardUI:
					cards.append(node)
	return cards


func _drag_hand_card(card_id: String, target: Vector2) -> void:
	var hand: Hand = _main.get_node("MainUI/CardsHand/Hand")
	var card_ui: CardUI = null
	for candidate in hand._get_hand_cards():
		if candidate.card.id == card_id:
			card_ui = candidate
	await _move_to(_center(card_ui) + Vector2(0, 40), 0.35)
	await _wait(0.2)
	_button(true)
	await _wait(0.1)
	await _move_to(target, 0.45)
	await _wait(0.2)
	_button(false)
	await _wait(0.1)

#endregion


#region Cursor

func _center(control: Control) -> Vector2:
	return control.get_global_rect().get_center()


func _hex_screen(hex: Hex) -> Vector2:
	var map: HexTileMap = _main.get_node("HexTileMap")
	return map.get_viewport().get_canvas_transform() * map.floating_text_position_for_hex(hex.coordinates)


func _move_to(target: Vector2, duration: float) -> void:
	var start := _cursor_pos
	var elapsed := 0.0
	while elapsed < duration:
		await get_tree().process_frame
		elapsed += get_process_delta_time()
		_set_cursor(start.lerp(target, ease(clampf(elapsed / duration, 0.0, 1.0), -2.2)))
	_set_cursor(target)


## Moves the drawn cursor and the real OS cursor, then feeds the game the same motion.
## Hand hover and drag previews read the OS cursor, so a parsed event alone is not enough.
func _set_cursor(pos: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.relative = pos - _cursor_pos
	_cursor_pos = pos
	_cursor.position = pos
	motion.position = get_viewport().get_final_transform() * pos
	Input.warp_mouse(motion.position)
	motion.global_position = motion.position
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT if _held else 0
	Input.parse_input_event(motion)


func _button(pressed: bool) -> void:
	_held = pressed
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	event.position = get_viewport().get_final_transform() * _cursor_pos
	event.global_position = event.position
	Input.parse_input_event(event)
	create_tween().tween_property(_cursor, "scale", Vector2.ONE * CURSOR_SCALE * (0.85 if pressed else 1.0), 0.08)


func _click() -> void:
	_button(true)
	await _wait(0.09)
	_button(false)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout

#endregion
