extends Node

## Decides which tutorial hint shows next and remembers what the player has already seen.
##
## Progress lives in its own profile file, never in the run save, so losing or abandoning a run
## keeps it. A hint only counts as seen once the player dismisses it: quitting while one is on
## screen brings it back. Hints key off game state ("owns a condiment"), not off a moment in the
## run, so a missed hint returns the next time its state is true, in this run or a later one.

signal hint_shown(id: StringName)
signal hint_dismissed(id: StringName)
## Seen set or enabled flag changed. The tips archive and settings redraw from it.
signal progress_changed

const SAVE_PATH := "user://tutorial_progress.save"
const STATE_POLL_INTERVAL := 0.5
const _StationManagerScript := preload("res://scripts/autoload/station_manager.gd")

## Tests point this at a scratch file so they never touch the player's progress.
var save_path := SAVE_PATH
var hints_enabled := true
## Headless runs and the playtest bot never show hints. Tests set this to run the queue anyway.
var force_active_for_tests := false

var _seen: Dictionary = {}
var _queue: Array[StringName] = []
var _active_id: StringName = &""
## Save key of the active hint. Differs from _active_id for per-chef hints.
var _active_seen_key: StringName = &""
var _active_action: Callable = Callable()
var _active_action_signal: StringName = &""
## The run's TutorialOverlay. Null outside a run scene.
var _overlay: Node = null
var _dragging := false
var _resolving := false
var _loaded := false
var _state_poll_timer := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	ensure_loaded()
	EventBus.card_drag_started.connect(func(_card: CardUI) -> void: _dragging = true)
	EventBus.card_drag_ended.connect(func(_card: CardUI, _outcome: int) -> void: _dragging = false)
	EventBus.staff_drag_started.connect(func(_slot: int) -> void: _dragging = true)
	EventBus.staff_drag_ended.connect(func() -> void: _dragging = false)
	EventBus.condiment_drag_started.connect(func(_slot: int) -> void: _dragging = true)
	EventBus.condiment_drag_ended.connect(func() -> void: _dragging = false)
	EventBus.turn_ended.connect(_on_turn_ended)
	EventBus.turn_started.connect(_on_turn_started)
	EventBus.card_played.connect(_on_card_played)
	EventBus.tile_card_selected.connect(func(_card: TileCard) -> void: _check_state_hints())
	EventBus.staff_added.connect(func(_slot: int) -> void: request(&"staff"))
	EventBus.condiment_belt_changed.connect(_on_condiment_belt_changed)
	EventBus.station_type_changed.connect(func(_segment: int, _type: String) -> void: request(&"station_type"))
	EventBus.station_leveled_up.connect(func(_segment: int, _level: int) -> void: request(&"station_level"))
	EventBus.event_reveal_finished.connect(func() -> void: request(&"event_active"))
	EventBus.game_ended.connect(_clear_queue)
	UiManager.active_panel_changed.connect(_on_active_panel_changed)


func _process(delta: float) -> void:
	# Cards also turn up in the card pick and the Merchant, which have no signal per offer.
	_state_poll_timer -= delta
	if _state_poll_timer <= 0.0:
		_state_poll_timer = STATE_POLL_INTERVAL
		_check_state_hints()
	if _active_id != &"" or _queue.is_empty() or not _can_run():
		return
	if _dragging or _resolving or get_tree().paused:
		return
	var next := _pick_next()
	if next != &"":
		_show(next)


#region Public API

func ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var data := AtomicSaveFile.read_var_dictionary(save_path)
	hints_enabled = bool(data.get("hints_enabled", true))
	_seen.clear()
	var seen_ids: Variant = data.get("seen", [])
	if seen_ids is Array:
		for seen_id: Variant in seen_ids:
			_seen[StringName(String(seen_id))] = true


## Re-read progress from save_path. Tests use this to check what reached disk.
func reload() -> void:
	_loaded = false
	ensure_loaded()


func is_seen(id: StringName) -> bool:
	return _seen.has(id)


## True for per-chef hints once any chef's version was seen. The tips archive uses this.
func has_seen_any(id: StringName) -> bool:
	if _seen.has(id):
		return true
	var prefix := String(id) + ":"
	for seen_id: StringName in _seen:
		if String(seen_id).begins_with(prefix):
			return true
	return false


## Hints are on and this is a real, presented game (not headless, not the playtest bot).
func is_live() -> bool:
	if not hints_enabled:
		return false
	if force_active_for_tests:
		return true
	return DisplayServer.get_name() != "headless" and not GameManager.skip_presentation


func is_showing() -> bool:
	return _active_id != &""


func get_active_id() -> StringName:
	return _active_id


func get_queue() -> Array[StringName]:
	return _queue.duplicate()


## Queue a hint, or a chain's first unseen step. No-op when seen, disabled, or already queued.
func request(id: StringName) -> void:
	if not hints_enabled:
		return
	if TutorialHints.CHAINS.has(id):
		id = _first_unseen_step(id)
		if id == &"":
			return
	if not TutorialHints.has(id) or _seen.has(_seen_key(id)):
		return
	if id == _active_id or id in _queue:
		return
	_queue.append(id)


func mark_seen(id: StringName) -> void:
	if _seen.has(id):
		return
	_seen[id] = true
	_save()
	progress_changed.emit()


func set_enabled(value: bool) -> void:
	ensure_loaded()
	if hints_enabled == value:
		return
	hints_enabled = value
	if not value:
		_clear_queue()
		if _overlay != null and _active_id != &"":
			_overlay.close_hint()
		_finish_active()
	_save()
	progress_changed.emit()
	if value:
		_check_run_start_hints()


## Every hint becomes unseen and hints turn back on.
func reset_all() -> void:
	ensure_loaded()
	_seen.clear()
	hints_enabled = true
	_save()
	progress_changed.emit()
	if _overlay != null:
		_check_run_start_hints()


## Welcome screen "Skip tutorial": the basics chain is done, contextual hints stay on.
func skip_basics() -> void:
	for step: StringName in TutorialHints.chain_steps(&"basics"):
		_seen[step] = true
	_queue = _queue.filter(func(queued: StringName) -> bool: return TutorialHints.chain_of(queued) != &"basics")
	_save()
	progress_changed.emit()


## The overlay calls this when the player dismisses the active hint.
func dismiss_active() -> void:
	if _active_id == &"":
		return
	var finished_id := _active_id
	mark_seen(_active_seen_key)
	_finish_active()
	hint_dismissed.emit(finished_id)
	# Chains run back to back. Their next step jumps ahead of anything else queued.
	var chain_id := TutorialHints.chain_of(finished_id)
	if chain_id != &"" and hints_enabled:
		var next_step := _first_unseen_step(chain_id)
		if next_step != &"" and not next_step in _queue:
			_queue.push_front(next_step)


## The active hint's screen went away before it finished. It returns, unseen, when the screen is back.
func suspend_active() -> void:
	if _active_id == &"":
		return
	var suspended_id := _active_id
	_finish_active()
	_queue.push_front(suspended_id)


## Body text for a hint, with run-specific details filled in.
func get_body(id: StringName) -> String:
	var body := String(TutorialHints.get_def(id).get("body", ""))
	if id == TutorialHints.CHEF_HINT:
		var chef := GameManager.selected_chef
		if chef != null and not chef.speciality_description.is_empty():
			return "**%s**: %s" % [chef.display_name, chef.speciality_description]
	return body


## Step number (1-based) and step count for chain dots. (0, 0) outside a chain.
func get_chain_progress(id: StringName) -> Vector2i:
	var chain_id := TutorialHints.chain_of(id)
	if chain_id == &"":
		return Vector2i.ZERO
	var steps := TutorialHints.chain_steps(chain_id)
	return Vector2i(steps.find(id) + 1, steps.size())

#endregion


#region Overlay binding

func register_overlay(overlay: Node) -> void:
	_overlay = overlay
	_clear_queue()
	_finish_active()
	_dragging = false
	_resolving = false
	_check_run_start_hints()


func unregister_overlay(overlay: Node) -> void:
	if _overlay != overlay:
		return
	_overlay = null
	_clear_queue()
	_finish_active()

#endregion


#region Triggers

func _on_turn_ended() -> void:
	_resolving = true


func _on_turn_started() -> void:
	_resolving = false
	_check_state_hints()


func _on_card_played(_card_ui: CardUI) -> void:
	_check_state_hints()


func _on_condiment_belt_changed() -> void:
	if _belt_has_condiment():
		request(&"condiments")


func _on_active_panel_changed(panel: Control) -> void:
	if panel == null:
		return
	match String(panel.name):
		"CardSelectionUI":
			request(&"card_pick")
		"Merchant":
			request(&"merchant")
		"StationUpgradeChoice":
			request(&"station_perk")


## Hints for a run that just opened, fresh or continued.
func _check_run_start_hints() -> void:
	if _overlay == null:
		return
	request(&"basics")
	request(TutorialHints.CHEF_HINT)
	_check_state_hints()


## Catch-up: queue every unseen hint whose game state is already true.
## Covers continued runs and moments the player quit through.
func _check_state_hints() -> void:
	if _overlay == null or not hints_enabled:
		return
	var board := _board()
	if _hand_matches_board(board):
		request(&"overplay")
	if _hand_has_keyword():
		request(&"keywords")
	if _meal_card_visible():
		request(&"meal_cards")
	if GameManager.current_round >= 2:
		request(&"sell")
		request(&"event_preview")
	if _has_staff():
		request(&"staff")
	if _belt_has_condiment():
		request(&"condiments")
	if board != null:
		for segment in board.get_segment_count():
			if StationManager.get_station_type(segment) != null:
				request(&"station_type")
			if StationManager.get_level(segment) > _StationManagerScript.START_LEVEL:
				request(&"station_level")
	if EventManager.active_event != -1:
		request(&"event_active")

#endregion


#region State checks

func _board() -> HexTileMap:
	# hex_map_group is also on a child TileMapLayer. Skip anything that is not the map.
	for node in get_tree().get_nodes_in_group(CondimentManager.HEX_MAP_GROUP):
		if node is HexTileMap and node.is_node_ready():
			return node as HexTileMap
	return null


func _hand_cards() -> Array[TileCard]:
	var cards: Array[TileCard] = []
	var hand := get_tree().get_first_node_in_group("run_hand")
	if hand == null:
		return cards
	for child in hand.get_children():
		if child is CardUI and (child as CardUI).card is TileCard:
			cards.append((child as CardUI).card as TileCard)
	return cards


func _hand_matches_board(board: HexTileMap) -> bool:
	if board == null:
		return false
	var seated_ids := {}
	for seated: TileCard in board.get_all_placed_tile_cards():
		seated_ids[seated.id] = true
	for card: TileCard in _hand_cards():
		if seated_ids.has(card.id):
			return true
	return false


func _hand_has_keyword() -> bool:
	for card: TileCard in _hand_cards():
		var text := card.get_description_text()
		for token: String in ["{garnish", "{trigger", "{retrigger", "{destroy", "{following"]:
			if text.contains(token):
				return true
	return false


## A Meal in the hand, the card pick or the Merchant shelf.
func _meal_card_visible() -> bool:
	return _overlay != null and _overlay.find_visible_meal_card() != null


func _has_staff() -> bool:
	for staff in StaffManager.slots:
		if staff != null:
			return true
	return false


func _belt_has_condiment() -> bool:
	for condiment in CondimentManager.belt:
		if condiment != null:
			return true
	return false

#endregion


#region Queue

func _can_run() -> bool:
	return _overlay != null and is_live()


## Highest priority hint whose screen is up. Ties keep request order.
func _pick_next() -> StringName:
	var best: StringName = &""
	var best_priority := -1
	for id: StringName in _queue:
		var def := TutorialHints.get_def(id)
		var priority := int(def.get("priority", 0))
		if priority <= best_priority:
			continue
		if not _overlay.is_context_ready(int(def.get("context", 0))):
			continue
		best = id
		best_priority = priority
	return best


func _show(id: StringName) -> void:
	_queue.erase(id)
	if _seen.has(_seen_key(id)) or not _is_still_relevant(id):
		return
	_active_id = id
	_active_seen_key = _seen_key(id)
	var def := TutorialHints.get_def(id)
	var action_signal: StringName = def.get("action_signal", &"")
	if action_signal != &"" and EventBus.has_signal(action_signal):
		_active_action_signal = action_signal
		_active_action = _on_active_action_done.unbind(_signal_arg_count(EventBus, action_signal))
		EventBus.connect(action_signal, _active_action)
	_overlay.show_hint(id)
	hint_shown.emit(id)


## A hint can wait a whole Day for its screen, and its state may be gone by then
## (Staff sold, Condiment used, Station lost its type). Stale hints are dropped unseen;
## _check_state_hints queues them again once their state is back.
func _is_still_relevant(id: StringName) -> bool:
	match id:
		&"event_active":
			return EventManager.active_event != -1
		&"station_type":
			return _any_segment(func(segment: int) -> bool: return StationManager.get_station_type(segment) != null)
		&"station_level":
			return _any_segment(func(segment: int) -> bool: return StationManager.get_level(segment) > _StationManagerScript.START_LEVEL)
		&"staff":
			return _has_staff()
		&"condiments":
			return _belt_has_condiment()
		&"meal_cards":
			return _meal_card_visible()
		&"overplay":
			return _hand_matches_board(_board())
		&"keywords":
			return _hand_has_keyword()
	return true


func _any_segment(qualifies: Callable) -> bool:
	var board := _board()
	if board == null:
		return false
	for segment in board.get_segment_count():
		if qualifies.call(segment):
			return true
	return false


func _on_active_action_done() -> void:
	if _active_id == &"":
		return
	if _overlay != null:
		_overlay.close_hint()
	dismiss_active()


func _finish_active() -> void:
	if _active_action_signal != &"" and EventBus.is_connected(_active_action_signal, _active_action):
		EventBus.disconnect(_active_action_signal, _active_action)
	_active_action = Callable()
	_active_action_signal = &""
	_active_id = &""
	_active_seen_key = &""


func _clear_queue() -> void:
	_queue.clear()


func _first_unseen_step(chain_id: StringName) -> StringName:
	for step: StringName in TutorialHints.chain_steps(chain_id):
		if not _seen.has(step):
			return step
	return &""


## Per-chef hints save under their own key so each chef's speciality is explained once.
func _seen_key(id: StringName) -> StringName:
	if id == TutorialHints.CHEF_HINT and GameManager.selected_chef != null:
		return StringName("%s:%s" % [id, GameManager.selected_chef.id])
	return id


static func _signal_arg_count(target: Object, signal_name: StringName) -> int:
	for info: Dictionary in target.get_signal_list():
		if info["name"] == signal_name:
			return (info["args"] as Array).size()
	return 0


func _save() -> void:
	var seen_ids: Array[String] = []
	for id: StringName in _seen:
		seen_ids.append(String(id))
	seen_ids.sort()
	AtomicSaveFile.write_var(save_path, {
		"hints_enabled": hints_enabled,
		"seen": seen_ids,
	})

#endregion
