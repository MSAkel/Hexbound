extends Node

## Persists in-progress runs to user:// so players can resume from the main menu.
## Checkpoints, pause, and window-close all write through the same guarded path.

const SAVE_FILE := preload("res://scripts/helpers/atomic_save_file.gd")
const SAVE_PATH := "user://run_save.json"
const SAVE_VERSION := 3
const HAND_GROUP := "run_hand"
const MERCHANT_GROUP := "run_merchant"
const RUNE_SELECTION_GROUP := "run_rune_selection"
const GAME_OVER_GROUP := "run_game_over"

# Set before loading main.tscn from the main menu Continue button.
var continue_run_pending := false
## One-shot request set before entering a scene that supports the rune reveal transition.
var scene_enter_transition_pending := false
var _pending_run_seed: String = ""
var _has_pending_run_seed := false
## Coalesces multiple committed actions in one frame into a single write.
var _autosave_queued := false
## Bumped when a save is discarded so an in-flight autosave cannot rewrite it.
var _autosave_generation := 0
## Blocks checkpoints while restore_run is still applying panel state.
var _is_restoring := false
## Prevents close_requested and WM_CLOSE_REQUEST from quitting twice.
var _is_quitting := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().set_auto_accept_quit(false)
	var window := get_window()
	if window != null and not window.close_requested.is_connected(_on_window_close_requested):
		window.close_requested.connect(_on_window_close_requested)
	EventBus.card_played.connect(_on_committed_card_played)
	EventBus.tile_card_selected.connect(_on_committed_tile_card_selected)
	EventBus.merchant_closed.connect(_on_committed_merchant_closed)
	EventBus.game_ended.connect(_on_game_ended)


func _on_window_close_requested() -> void:
	if _is_quitting:
		return
	_is_quitting = true
	# Immediate write so the file is on disk before the process exits.
	save_current_run()
	get_tree().quit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_on_window_close_requested()


func has_save() -> bool:
	return SAVE_FILE.has_readable(SAVE_PATH)


func request_continue_run() -> void:
	var payload := _load_save_payload()
	if payload.is_empty():
		push_warning("Continue requested but no run save exists.")
		return

	var character := PlayerCharacter.get_character_by_id(payload.get("character_id", ""))
	if character == null:
		push_error("RunSaveManager: cannot continue — unknown character in save.")
		delete_save()
		return

	# Map generation reads character layout rules during _ready, before main.gd restores state.
	GameManager.selected_character = character
	GameManager.selected_difficulty = int(payload.get("difficulty", Difficulty.Level.LEVEL_0)) as Difficulty.Level
	continue_run_pending = true
	request_scene_enter_transition()


func request_scene_enter_transition() -> void:
	scene_enter_transition_pending = true


func request_main_scene_transition() -> void:
	request_scene_enter_transition()


func consume_scene_enter_transition_request() -> bool:
	var was_requested := scene_enter_transition_pending
	scene_enter_transition_pending = false
	return was_requested


func consume_main_scene_transition_request() -> bool:
	return consume_scene_enter_transition_request()


func set_pending_run_seed(seed_text: String) -> void:
	_pending_run_seed = RunRng.normalize_seed_text(seed_text)
	_has_pending_run_seed = true


func consume_pending_run_seed() -> Dictionary:
	if not _has_pending_run_seed:
		return {"requested": false, "seed_text": ""}
	_has_pending_run_seed = false
	return {"requested": true, "seed_text": _pending_run_seed}


func should_restore_run() -> bool:
	# A dangling Continue click must not restore after Play has already deleted the file.
	return continue_run_pending and has_save()


func clear_continue_run_pending() -> void:
	continue_run_pending = false


func delete_save() -> void:
	clear_continue_run_pending()
	_autosave_queued = false
	_autosave_generation += 1
	SAVE_FILE.delete_all(SAVE_PATH)


## Queue a checkpoint after Hand and other listeners have finished this frame.
func request_autosave() -> void:
	if not _can_save_now():
		return
	if _autosave_queued:
		return
	_autosave_queued = true
	_flush_autosave_next_frame()


func save_current_run() -> void:
	if not _can_save_now():
		return

	var tile_map := _find_tile_map()
	var hand := _find_hand()
	if tile_map == null or hand == null:
		return

	var payload := {
		"version": SAVE_VERSION,
		"saved_at_unix": Time.get_unix_time_from_system(),
		"character_id": GameManager.selected_character.id if GameManager.selected_character else "",
		"difficulty": GameManager.selected_difficulty,
		"game_manager": GameManager.capture_run_state(),
		"gold": GoldManager.capture_run_state(),
		"rerolls": RerollManager.capture_run_state(),
		"potions": PotionManager.capture_run_state(),
		"events": EventManager.capture_run_state(),
		"round_flow": RoundFlow.capture_run_state(),
		"run_rng": RunRng.capture_run_state(),
		"map": tile_map.capture_map_state(),
		"hand": hand.capture_hand_state(),
	}

	var merchant = _find_merchant()
	if merchant != null:
		payload["merchant"] = merchant.capture_shop_state()

	var rune_selection = _find_rune_selection()
	if rune_selection != null:
		payload["rune_offer"] = rune_selection.capture_offer_state()

	var json_text := JSON.stringify(payload, "\t")
	if not SAVE_FILE.write_text(SAVE_PATH, json_text):
		push_error("RunSaveManager: failed to write run save.")


func restore_run(hand: Hand, tile_map: HexTileMap) -> bool:
	var payload := _load_save_payload()
	if payload.is_empty():
		push_error("RunSaveManager: no save data to restore.")
		clear_continue_run_pending()
		return false

	if int(payload.get("version", 0)) != SAVE_VERSION:
		push_error("RunSaveManager: unsupported save version.")
		delete_save()
		return false

	var character_id: String = payload.get("character_id", "")
	var character := PlayerCharacter.get_character_by_id(character_id)
	if character == null:
		push_error("RunSaveManager: unknown character id '%s'." % character_id)
		delete_save()
		return false

	_is_restoring = true
	GameManager.selected_character = character
	GameManager.selected_difficulty = int(payload.get("difficulty", Difficulty.Level.LEVEL_0)) as Difficulty.Level
	GameManager.apply_run_state(payload.get("game_manager", {}))
	GoldManager.apply_run_state(payload.get("gold", {}))
	RerollManager.apply_run_state(payload.get("rerolls", {}))
	EventManager.apply_run_state(payload.get("events", {}))
	RoundFlow.apply_run_state(payload.get("round_flow", {}))
	RunRng.apply_run_state(payload.get("run_rng", {}))
	tile_map.restore_map_state(payload.get("map", {}))
	PotionManager.apply_run_state(payload.get("potions", {}))
	hand.restore_hand_state(payload.get("hand", {}))
	_apply_offer_ui_state(payload)
	EventManager.refresh_event_visuals()
	EventManager.restore_banner_after_load()
	# Segment rows are built deferred, refresh them once the layout data is restored.
	tile_map.call_deferred("refresh_segment_turn_results_ui")
	_notify_ui_restored()
	# Re-show the panel the run was sitting on, after the HUD has caught up.
	RoundFlow.restore_after_load()
	_restore_idle_rune_pick()
	_is_restoring = false
	return true


func _can_save_now() -> bool:
	if GameManager.skip_presentation:
		return false
	if _is_restoring:
		return false
	if GameManager.is_processing_turn:
		return false
	if _is_game_over_visible():
		return false
	if _find_tile_map() == null or _find_hand() == null:
		return false
	return true


func _flush_autosave_next_frame() -> void:
	var generation := _autosave_generation
	await get_tree().process_frame
	if generation != _autosave_generation:
		return
	_autosave_queued = false
	save_current_run()


func _on_committed_card_played(_card_ui: CardUI) -> void:
	request_autosave()


func _on_committed_tile_card_selected(_tile_card: TileCard) -> void:
	request_autosave()


func _on_committed_merchant_closed() -> void:
	request_autosave()


func _on_game_ended() -> void:
	_autosave_queued = false
	delete_save()


func _load_save_payload() -> Dictionary:
	return SAVE_FILE.read_json_dictionary(SAVE_PATH)


func _apply_offer_ui_state(payload: Dictionary) -> void:
	var merchant = _find_merchant()
	if merchant != null:
		merchant.apply_shop_state(payload.get("merchant", {}))

	var rune_selection = _find_rune_selection()
	if rune_selection != null:
		rune_selection.apply_offer_state(payload.get("rune_offer", {}))


func _restore_idle_rune_pick() -> void:
	var rune_selection = _find_rune_selection()
	if rune_selection != null:
		rune_selection.restore_open_if_needed()

	var merchant = _find_merchant()
	if merchant != null:
		merchant.restore_open_if_needed()


func _find_tile_map() -> HexTileMap:
	# hex_map_group is also on a child TileMapLayer. Skip anything that is not the map.
	for node in get_tree().get_nodes_in_group("hex_map_group"):
		var tile_map := node as HexTileMap
		if tile_map != null:
			return tile_map
	return null


func _find_hand() -> Hand:
	return get_tree().get_first_node_in_group(HAND_GROUP) as Hand


func _find_merchant():
	return get_tree().get_first_node_in_group(MERCHANT_GROUP)


func _find_rune_selection():
	return get_tree().get_first_node_in_group(RUNE_SELECTION_GROUP)


func _is_game_over_visible() -> bool:
	for node in get_tree().get_nodes_in_group(GAME_OVER_GROUP):
		var overlay := node as Control
		if overlay != null and overlay.is_visible_in_tree():
			return true
	return false


func _notify_ui_restored() -> void:
	EventBus.gold_changed.emit(GoldManager.amount)
	EventBus.rerolls_changed.emit(RerollManager.remaining)
	EventBus.total_round_score_changed.emit()
	EventBus.turn_changed.emit()
	EventBus.round_changed.emit(GameManager.current_round)
	EventBus.required_score_changed.emit()
	EventBus.event_schedule_changed.emit()
	EventBus.event_changed.emit()
