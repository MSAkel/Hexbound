class_name GeneratedCardReveal
extends Node

## Queues and plays the fly-in showcase when a tile effect creates a hand card.

const START_SCALE := 0.12
const SHOWCASE_SCALE := 1.4
const ENTER_DURATION := 0.5
const SHOWCASE_HOLD := 0.75
const FLOAT_AMPLITUDE := 5.0
const FLOAT_PERIOD := 0.7
const TO_HAND_DURATION := 0.45
const CARD_Z_INDEX := 30
const SHOWCASE_VIEWPORT_RATIO := Vector2(0.80, 0.28)

@onready var _hand: Hand = $"../Hand"

var _queue: Array[Card] = []
var _is_playing := false
var _generation := 0
var _animating_card: CardUI = null
var _anim_tween: Tween = null
var _float_tween: Tween = null


func _ready() -> void:
	EventBus.generated_hand_card.connect(_on_generated_hand_card)


func is_animating_card(card_ui: CardUI) -> bool:
	return _animating_card == card_ui


func capture_pending() -> Array:
	var pending: Array = []
	for card: Card in _queue:
		if card == null:
			continue
		pending.append({"kind": card.get_save_kind(), "id": card.id})
	return pending


func restore_pending(entries: Array) -> void:
	_queue.clear()
	for entry: Variant in entries:
		if entry is not Dictionary:
			continue
		var pending := _card_from_save_entry(entry)
		if pending != null:
			_queue.append(pending)


func try_play_next() -> void:
	if _is_playing:
		return
	if _queue.is_empty() or not _can_play():
		return
	_play_queue()


func interrupt() -> void:
	_generation += 1
	if _anim_tween != null and _anim_tween.is_valid():
		_anim_tween.kill()
	_anim_tween = null
	if _float_tween != null and _float_tween.is_valid():
		_float_tween.kill()
	_float_tween = null
	if _animating_card != null:
		_settle_in_hand(_animating_card)
		_animating_card = null
	# The running queue coroutine still owns _is_playing.


func _on_generated_hand_card(card: Card) -> void:
	if card == null:
		return
	_queue.append(card)
	try_play_next()


func _can_play() -> bool:
	# Only the run intro should block this. Reveals play during tile resolution too.
	return not _hand.is_awaiting_intro()


func _anim_duration(base_duration: float) -> float:
	return base_duration / GameManager.game_speed


func _play_queue() -> void:
	_is_playing = true
	while not _queue.is_empty() and _can_play():
		var next_card: Card = _queue.pop_front()
		await _play_animation(next_card)
	_is_playing = false
	_animating_card = null


func _play_animation(data: Card) -> void:
	var generation := _generation
	var card_ui := _hand.create_hand_card(data)
	_animating_card = card_ui
	card_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_ui.hover_enabled = false
	card_ui.z_index = CARD_Z_INDEX
	card_ui.offset_transform_enabled = true
	card_ui.offset_transform_pivot_ratio = Vector2(0.5, 0.5)
	# Stay in the HBox layout. Hide with alpha until the fly-in offset is applied.
	card_ui.modulate.a = 0.0

	if not card_ui.is_node_ready():
		await card_ui.ready
	if generation != _generation:
		return

	# Wait for HBox layout so offsets are relative to the final hand slot.
	await _await_process_frame(generation)
	if generation != _generation:
		return

	var viewport_size := get_viewport().get_visible_rect().size
	var showcase_global := Vector2(
		viewport_size.x * SHOWCASE_VIEWPORT_RATIO.x,
		viewport_size.y * SHOWCASE_VIEWPORT_RATIO.y
	)
	# Enter from just off the right edge, then settle at the same showcase pose.
	var start_global := Vector2(viewport_size.x, showcase_global.y)
	var start_offset := _offset_to_reach_global(card_ui, start_global)
	var showcase_offset := _offset_to_reach_global(card_ui, showcase_global)

	card_ui.offset_transform_position = start_offset
	card_ui.offset_transform_scale = Vector2.ONE * START_SCALE
	card_ui.modulate.a = 1.0
	AudioManager.play_sfx(UISounds.CARD_REVEAL)

	var enter_duration := _anim_duration(ENTER_DURATION)
	_anim_tween = create_tween()
	_anim_tween.set_parallel(true)
	_anim_tween.tween_property(
		card_ui,
		"offset_transform_position",
		showcase_offset,
		enter_duration
	).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_anim_tween.tween_property(
		card_ui,
		"offset_transform_scale",
		Vector2.ONE * SHOWCASE_SCALE,
		enter_duration
	).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	await _await_tween(_anim_tween, generation)
	if generation != _generation:
		return

	var float_half := _anim_duration(FLOAT_PERIOD) * 0.5
	_float_tween = create_tween()
	_float_tween.set_loops()
	_float_tween.tween_property(
		card_ui,
		"offset_transform_position",
		showcase_offset + Vector2(0.0, -FLOAT_AMPLITUDE),
		float_half
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_float_tween.tween_property(
		card_ui,
		"offset_transform_position",
		showcase_offset + Vector2(0.0, FLOAT_AMPLITUDE),
		float_half
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	await _await_delay(_anim_duration(SHOWCASE_HOLD), generation)
	if generation != _generation:
		return

	if _float_tween != null and _float_tween.is_valid():
		_float_tween.kill()
	_float_tween = null

	var to_hand_offset := _hand.get_card_rest_offset()
	var to_hand_duration := _anim_duration(TO_HAND_DURATION)
	_anim_tween = create_tween()
	_anim_tween.set_parallel(true)
	_anim_tween.tween_property(
		card_ui,
		"offset_transform_position",
		to_hand_offset,
		to_hand_duration
	).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	_anim_tween.tween_property(
		card_ui,
		"offset_transform_scale",
		Vector2.ONE,
		to_hand_duration
	).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	await _await_tween(_anim_tween, generation)
	if generation != _generation:
		return

	_settle_in_hand(card_ui)
	_animating_card = null
	_anim_tween = null


func _settle_in_hand(card_ui: CardUI) -> void:
	card_ui.modulate.a = 1.0
	card_ui.hover_enabled = true
	card_ui.offset_transform_enabled = true
	card_ui.offset_transform_pivot_ratio = Vector2(0.5, 1.0)
	card_ui.offset_transform_scale = Vector2.ONE
	card_ui.offset_transform_position = _hand.get_card_rest_offset()
	card_ui.z_index = 0
	if _hand.is_hand_hidden():
		card_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	else:
		card_ui.mouse_filter = Control.MOUSE_FILTER_STOP


# Maps a viewport point onto this card's offset_transform, independent of its hand slot.
func _offset_to_reach_global(card_ui: CardUI, target_global: Vector2) -> Vector2:
	return target_global - card_ui.global_position


func _card_from_save_entry(entry: Dictionary) -> Card:
	var kind: String = entry.get("kind", "")
	var card_id: String = entry.get("id", "")
	if kind == "tile_card" or kind == "rune":
		var template := GameManager.get_tile_card_by_id(card_id)
		if template != null:
			return template.duplicate(true)
	elif kind == "enhancement":
		var template := GameManager.get_enhancement_by_id(card_id)
		if template != null:
			return template.duplicate(true)
	return null


func _await_process_frame(generation: int) -> void:
	await get_tree().process_frame
	if generation != _generation:
		return


func _await_tween(tween: Tween, generation: int) -> void:
	if tween == null:
		return
	while tween.is_valid() and tween.is_running():
		if generation != _generation:
			return
		await get_tree().process_frame


func _await_delay(duration: float, generation: int) -> void:
	var elapsed := 0.0
	while elapsed < duration:
		if generation != _generation:
			return
		await get_tree().process_frame
		elapsed += get_process_delta_time()
