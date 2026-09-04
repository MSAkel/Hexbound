class_name CondimentBelt
extends Control

## Three square slots on the right. Drag a condiment out to drink it.
## Slot cells come from condiment_slot.tscn. The drag ghost is authored in this scene.

const SLOT_SCENE := preload("res://scenes/ui/condiments/condiment_slot.tscn")
const GHOST_SIZE := Vector2(48, 48)

@onready var _slots_column: VBoxContainer = $SlotsColumn
@onready var _ghost: TextureRect = %DragGhost

var _slots: Array[CondimentSlot] = []
var _drag_index := -1
var _awaiting_consume := false
var _controller_focus_index := -1


func _ready() -> void:
	for i in CondimentManager.BELT_SIZE:
		var slot: CondimentSlot = SLOT_SCENE.instantiate()
		slot.slot_index = i
		slot.drag_started.connect(_on_slot_drag_started)
		slot.remove_requested.connect(_on_slot_remove_requested)
		_slots_column.add_child(slot)
		_slots.append(slot)
	_ghost.size = GHOST_SIZE
	EventBus.condiment_belt_changed.connect(_refresh)
	EventBus.condiment_targeting_changed.connect(_on_targeting_changed)
	EventBus.condiment_consume_started.connect(_on_consume_started)
	EventBus.condiment_use_failed.connect(_on_use_failed)
	EventBus.turn_started.connect(_on_turn_started)
	_refresh()


func _process(_delta: float) -> void:
	if _drag_index < 0 or _awaiting_consume:
		return
	_place_ghost_at_mouse()


func _input(event: InputEvent) -> void:
	if _drag_index < 0:
		return
	if event.is_action_pressed("ui_cancel"):
		_cancel_drag()
		get_viewport().set_input_as_handled()
		return
	if not event is InputEventMouseButton:
		return
	# Right click puts the condiment back in its square.
	if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		_cancel_drag()
		get_viewport().set_input_as_handled()
		return
	if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_finish_drop()
		get_viewport().set_input_as_handled()


func _refresh() -> void:
	for i in _slots.size():
		_slots[i].set_condiment(CondimentManager.belt[i])
		_slots[i].set_targeting(CondimentManager.targeting_slot == i)
		_slots[i].set_lifted(_drag_index == i)
	_apply_controller_focus_visual()


func _on_slot_drag_started(index: int) -> void:
	if _drag_index >= 0 or not CondimentManager.can_drink_now():
		return
	var condiment := CondimentManager.belt[index]
	if condiment == null:
		return
	if not CondimentManager.can_use(condiment):
		EventBus.condiment_use_failed.emit(condiment)
		return
	_drag_index = index
	AudioManager.play_sfx(UISounds.CONDIMENT_GRAB)
	_show_ghost(condiment)
	_refresh()
	if condiment.needs_tile_target():
		CondimentManager.begin_targeting(index)


func _on_slot_remove_requested(index: int) -> void:
	if _drag_index >= 0:
		return
	CondimentManager.remove_slot(index)


func _on_targeting_changed(_slot_index: int) -> void:
	_refresh()


func _on_consume_started(slot_index: int, _condiment: Condiment) -> void:
	_awaiting_consume = true
	if GameManager.skip_presentation:
		_finish_consume_visuals()
		EventBus.condiment_consume_animation_finished.emit()
		return
	if _ghost.visible:
		await _play_ghost_consume()
	elif slot_index >= 0 and slot_index < _slots.size():
		await _slots[slot_index].play_consume_animation()
	_finish_consume_visuals()
	EventBus.condiment_consume_animation_finished.emit()


func _on_use_failed(condiment: Condiment) -> void:
	if condiment == null:
		return
	EventBus.toggle_tooltip.emit(
		true,
		"%s cannot be used right now." % condiment.display_name,
		get_global_rect()
	)


func _on_turn_started() -> void:
	if _drag_index >= 0 and not _awaiting_consume:
		_cancel_drag()


func _show_ghost(condiment: Condiment) -> void:
	_ghost.texture = condiment.icon
	_ghost.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Match the belt well. Leave the flask art untinted.
	_ghost.self_modulate = Color.WHITE
	_ghost.modulate = Color.WHITE
	_ghost.scale = Vector2.ONE
	_ghost.visible = true
	_place_ghost_at_mouse()


func _place_ghost_at_mouse() -> void:
	_ghost.global_position = get_global_mouse_position() - GHOST_SIZE * 0.5


func _play_ghost_consume() -> void:
	_ghost.pivot_offset = GHOST_SIZE * 0.5
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(_ghost, "scale", Vector2(0.25, 0.25), 0.24)
	tween.parallel().tween_property(_ghost, "modulate:a", 0.0, 0.24)
	await tween.finished


func _finish_consume_visuals() -> void:
	_ghost.visible = false
	_ghost.modulate = Color.WHITE
	_ghost.scale = Vector2.ONE
	_drag_index = -1
	_awaiting_consume = false
	_refresh()


func _cancel_drag() -> void:
	if _drag_index < 0:
		return
	CondimentManager.cancel_targeting()
	_ghost.visible = false
	_drag_index = -1
	_awaiting_consume = false
	_refresh()


func _finish_drop() -> void:
	if _drag_index < 0 or _awaiting_consume:
		return
	var index := _drag_index
	var condiment := CondimentManager.belt[index]
	# Releasing over the rack puts the bottle back. Same as a right-click cancel.
	if get_global_rect().has_point(get_global_mouse_position()):
		_cancel_drag()
		return
	if condiment == null:
		_cancel_drag()
		return
	if condiment.needs_tile_target():
		# Tile drinks only apply when the cursor is over a valid occupied hex.
		if CondimentManager.try_apply_to_hex_under_mouse():
			return
		CondimentManager.show_tile_drop_failure_feedback()
		_cancel_drag()
		return
	# Instant drinks apply wherever they are dropped off the rack.
	CondimentManager.request_use_slot(index)


func ensure_controller_focus() -> void:
	_move_controller_focus_to(maxi(_controller_focus_index, 0))


func clear_controller_focus() -> void:
	_controller_focus_index = -1
	_apply_controller_focus_visual()


func move_controller_focus(direction: int) -> void:
	if _slots.is_empty():
		return
	var next := 0 if _controller_focus_index < 0 else _controller_focus_index + direction
	_move_controller_focus_to(next)


func activate_controller_focused_slot() -> void:
	if _controller_focus_index < 0 or _controller_focus_index >= _slots.size():
		return
	CondimentManager.request_use_slot(_controller_focus_index)


func _move_controller_focus_to(index: int) -> void:
	if _slots.is_empty():
		return
	_controller_focus_index = clampi(index, 0, _slots.size() - 1)
	_apply_controller_focus_visual()


func _apply_controller_focus_visual() -> void:
	var previous_focus := -1
	for i in _slots.size():
		if _slots[i].controller_focused:
			previous_focus = i
			break
	for i in _slots.size():
		_slots[i].set_controller_focused(i == _controller_focus_index)
	if _controller_focus_index < 0:
		EventBus.toggle_tooltip.emit(false, "", Rect2())
		return
	if _controller_focus_index == previous_focus:
		return
	_announce_controller_slot(_slots[_controller_focus_index])


func _announce_controller_slot(slot: CondimentSlot) -> void:
	if slot.condiment != null:
		AudioManager.play_condiment_hover()
		EventBus.toggle_tooltip.emit(
			true,
			"%s\n%s" % [slot.condiment.display_name, slot.condiment.description],
			slot.get_global_rect()
		)
		return
	AudioManager.play_ui_hover()
	EventBus.toggle_tooltip.emit(true, "Empty slot", slot.get_global_rect())
