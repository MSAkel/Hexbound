extends Node

## Persists in-progress runs to user:// so players can resume from the main menu.

const SAVE_PATH := "user://run_save.json"
const SAVE_VERSION := 2

# Set before loading main.tscn from the main menu Continue button.
var continue_run_pending := false


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


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
	GameManager.selected_difficulty = int(payload.get("difficulty", Difficulty.Level.LEVEL_0))
	continue_run_pending = true


func should_restore_run() -> bool:
	return continue_run_pending


func clear_continue_run_pending() -> void:
	continue_run_pending = false


func delete_save() -> void:
	clear_continue_run_pending()
	if has_save():
		DirAccess.remove_absolute(SAVE_PATH)


func save_current_run() -> void:
	var tile_map := _find_tile_map()
	var hand := _find_hand()
	if tile_map == null or hand == null:
		push_error("RunSaveManager: cannot save — main scene nodes are missing.")
		return

	var payload := {
		"version": SAVE_VERSION,
		"saved_at_unix": Time.get_unix_time_from_system(),
		"character_id": GameManager.selected_character.id if GameManager.selected_character else "",
		"difficulty": GameManager.selected_difficulty,
		"game_manager": GameManager.capture_run_state(),
		"gold": GoldManager.capture_run_state(),
		"challenges": ChallengeManager.capture_run_state(),
		"round_flow": RoundFlow.capture_run_state(),
		"map": tile_map.capture_map_state(),
		"hand": hand.capture_hand_state(),
	}

	var json_text := JSON.stringify(payload, "\t")
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("RunSaveManager: failed to open save file for writing.")
		return
	file.store_string(json_text)


func restore_run(hand: Hand, tile_map: HexTileMap) -> void:
	var payload := _load_save_payload()
	if payload.is_empty():
		push_error("RunSaveManager: no save data to restore.")
		return

	if int(payload.get("version", 0)) != SAVE_VERSION:
		push_error("RunSaveManager: unsupported save version.")
		delete_save()
		return

	var character_id: String = payload.get("character_id", "")
	var character := PlayerCharacter.get_character_by_id(character_id)
	if character == null:
		push_error("RunSaveManager: unknown character id '%s'." % character_id)
		delete_save()
		return

	GameManager.selected_character = character
	GameManager.selected_difficulty = int(payload.get("difficulty", Difficulty.Level.LEVEL_0))
	GameManager.apply_run_state(payload.get("game_manager", {}))
	GoldManager.apply_run_state(payload.get("gold", {}))
	ChallengeManager.apply_run_state(payload.get("challenges", {}))
	RoundFlow.apply_run_state(payload.get("round_flow", {}))
	tile_map.restore_map_state(payload.get("map", {}))
	hand.restore_hand_state(payload.get("hand", {}))
	ChallengeManager.refresh_challenge_visuals()
	ChallengeManager.restore_banner_after_load()
	# Segment rows are built deferred, refresh them once the layout data is restored.
	tile_map.call_deferred("refresh_segment_turn_results_ui")
	_notify_ui_restored()
	# Re-show the panel the run was sitting on, after the HUD has caught up.
	RoundFlow.restore_after_load()


func _load_save_payload() -> Dictionary:
	if not has_save():
		return {}

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return {}

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		return parsed
	return {}


func _find_tile_map() -> HexTileMap:
	for node in get_tree().get_nodes_in_group("hex_map_group"):
		var tile_map := node as HexTileMap
		if tile_map != null:
			return tile_map
	return null


func _find_hand() -> Hand:
	var root := get_tree().current_scene
	if root == null:
		return null
	var hand_node := root.get_node_or_null("MainUI/CardsHand/Hand")
	return hand_node as Hand


func _notify_ui_restored() -> void:
	EventBus.gold_changed.emit(GoldManager.amount)
	EventBus.total_round_score_changed.emit()
	EventBus.turn_score_changed.emit()
	EventBus.turn_changed.emit()
	EventBus.round_changed.emit(GameManager.current_round)
	EventBus.required_score_changed.emit()
	EventBus.challenge_schedule_changed.emit()
	EventBus.challenge_changed.emit()
