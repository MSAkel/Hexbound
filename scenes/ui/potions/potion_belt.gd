class_name PotionBelt
extends Control

## Three square slots on the right. Drag a potion out to drink it.
## Slot cells come from potion_slot.tscn. The drag ghost is authored in this scene.

const SLOT_SCENE := preload("res://scenes/ui/potions/potion_slot.tscn")
const GHOST_SIZE := Vector2(64, 64)

@onready var _slots_column: VBoxContainer = $SlotsColumn
@onready var _ghost: TextureRect = %DragGhost

var _slots: Array[PotionSlot] = []
var _drag_index := -1
var _awaiting_consume := false


func _ready() -> void:
	for i in PotionManager.BELT_SIZE:
		var slot: PotionSlot = SLOT_SCENE.instantiate()
		slot.slot_index = i
		slot.drag_started.connect(_on_slot_drag_started)
		slot.remove_requested.connect(_on_slot_remove_requested)
		_slots_column.add_child(slot)
		_slots.append(slot)
	_ghost.size = GHOST_SIZE
	EventBus.potion_belt_changed.connect(_refresh)
	EventBus.potion_targeting_changed.connect(_on_targeting_changed)
	EventBus.potion_consume_started.connect(_on_consume_started)
	EventBus.potion_use_failed.connect(_on_use_failed)
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
	# Right click puts the potion back in its square.
	if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		_cancel_drag()
		get_viewport().set_input_as_handled()
		return
	if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_finish_drop()
		get_viewport().set_input_as_handled()


func _refresh() -> void:
	for i in _slots.size():
		_slots[i].set_potion(PotionManager.belt[i])
		_slots[i].set_targeting(PotionManager.targeting_slot == i)
		_slots[i].set_lifted(_drag_index == i)


func _on_slot_drag_started(index: int) -> void:
	if _drag_index >= 0 or not PotionManager.can_drink_now():
		return
	var potion := PotionManager.belt[index]
	if potion == null:
		return
	if not PotionManager.can_use(potion):
		EventBus.potion_use_failed.emit(potion)
		return
	_drag_index = index
	_show_ghost(potion)
	_refresh()
	if potion.needs_tile_target():
		PotionManager.begin_targeting(index)


func _on_slot_remove_requested(index: int) -> void:
	if _drag_index >= 0:
		return
	PotionManager.remove_slot(index)


func _on_targeting_changed(_slot_index: int) -> void:
	_refresh()


func _on_consume_started(slot_index: int, _potion: Potion) -> void:
	_awaiting_consume = true
	if GameManager.skip_presentation:
		_finish_consume_visuals()
		EventBus.potion_consume_animation_finished.emit()
		return
	if _ghost.visible:
		await _play_ghost_consume()
	elif slot_index >= 0 and slot_index < _slots.size():
		await _slots[slot_index].play_consume_animation()
	_finish_consume_visuals()
	EventBus.potion_consume_animation_finished.emit()


func _on_use_failed(potion: Potion) -> void:
	if potion == null:
		return
	EventBus.toggle_tooltip.emit(
		true,
		"%s cannot be used right now." % potion.display_name,
		get_global_rect()
	)


func _on_turn_started() -> void:
	if _drag_index >= 0 and not _awaiting_consume:
		_cancel_drag()


func _show_ghost(potion: Potion) -> void:
	_ghost.texture = potion.icon
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
	PotionManager.cancel_targeting()
	_ghost.visible = false
	_drag_index = -1
	_awaiting_consume = false
	_refresh()


func _finish_drop() -> void:
	if _drag_index < 0 or _awaiting_consume:
		return
	var index := _drag_index
	var potion := PotionManager.belt[index]
	# Releasing over the rack puts the bottle back. Same as a right-click cancel.
	if get_global_rect().has_point(get_global_mouse_position()):
		_cancel_drag()
		return
	if potion == null:
		_cancel_drag()
		return
	if potion.needs_tile_target():
		# Tile drinks only apply when the cursor is over a valid occupied hex.
		if PotionManager.try_apply_to_hex_under_mouse():
			return
		PotionManager.show_tile_drop_failure_feedback()
		_cancel_drag()
		return
	# Instant drinks apply wherever they are dropped off the rack.
	PotionManager.request_use_slot(index)
