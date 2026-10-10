class_name ChefSlot
extends Control

## One hex in the chef column. Shows the seated chef, or a dashed well when empty.
## ChefRail owns layout, drag and drop, and decides which animation plays.
## Layout lives in chef_slot.tscn.

signal drag_started(slot_index: int)
signal hover_changed(slot_index: int, hovered: bool)

const DRAG_START_THRESHOLD_PX := 8.0
const RARITY_RIM_COLORS := {
	Card.Rarity.COMMON: Color(1.0, 0.95, 0.8, 1.0),
	Card.Rarity.UNCOMMON: Color(0.55, 0.85, 1.25, 1.0),
	Card.Rarity.RARE: Color(1.0, 0.65, 1.3, 1.0),
}

const HOVER_SCALE := Vector2(1.08, 1.08)
const HOVER_DURATION := 0.12
const CONTROLLER_FOCUS_SCALE := Vector2(1.12, 1.12)
# Fly in from the merchant shelf, then slam into the well.
const ARRIVAL_FLIGHT_DURATION := 0.38
const ARRIVAL_ARC_HEIGHT := 90.0
const ARRIVAL_START_SCALE := Vector2(1.5, 1.5)
# Swap and snap travel between slots.
const TRAVEL_DURATION := 0.24
const TRAVEL_BULGE := 46.0
const SEAT_SQUASH_SCALE := Vector2(1.1, 0.8)
const SEAT_SQUASH_DURATION := 0.08
const SEAT_SETTLE_DURATION := 0.14
const SEAT_SHAKE_STRENGTH := 5.0
const SEAT_SHAKE_DURATION := 0.16
const RIM_FADE_DURATION := 0.32
const COPY_GHOST_DURATION := 0.5
const REJECT_SHAKE_PX := 7.0
const REJECT_DURATION := 0.22
const EMPTY_WELL_MODULATE := Color(1, 1, 1, 0.6)
const FILLED_WELL_MODULATE := Color(1, 1, 1, 0.0)
const DUST_COLOR := Color(0.93, 0.88, 0.78, 0.9)

@export var slot_index: int = 0

@onready var _well: TextureRect = %Well
@onready var _drop_glow: TextureRect = %DropGlow
@onready var _token: Control = %Token
@onready var _icon: TextureRect = %Icon
@onready var _copy_ghost: TextureRect = %CopyGhost
@onready var _rim: TextureRect = %Rim
@onready var _name_tag: Label = %NameTag

var chef: ChefCard = null

# Hidden while the chef is on the cursor.
var _lifted := false
# False while the column is faded out under an overlay.
var _interactive := true
# Display-only copy that follows the cursor. Never takes input.
var _is_ghost := false
var _hovered := false
var _controller_focused := false
var _press_held := false
var _press_screen_pos := Vector2.ZERO
# Owns the token's position and scale until it finishes.
var _motion_tween: Tween
var _rim_tween: Tween
var _ghost_tween: Tween
var _dust: CPUParticles2D


func _ready() -> void:
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	gui_input.connect(_on_gui_input)
	resized.connect(_update_pivot)
	_update_pivot()
	_refresh()


func set_chef(new_chef: ChefCard) -> void:
	chef = new_chef
	if is_node_ready():
		_refresh()


## Turns this instance into the cursor ghost used while dragging.
func configure_as_ghost() -> void:
	_is_ghost = true
	_well.hide()
	_drop_glow.hide()
	_refresh()


func set_interactive(enabled: bool) -> void:
	_interactive = enabled
	_refresh()


## Hide the seated chef while it rides the cursor.
func set_lifted(lifted: bool) -> void:
	_lifted = lifted
	_refresh()


## Lit while a dragged chef would land here.
func set_drop_target(active: bool) -> void:
	_drop_glow.visible = active


func set_controller_focused(focused: bool) -> void:
	if _controller_focused == focused:
		return
	_controller_focused = focused
	_apply_rest_scale(true)


func clear_press() -> void:
	_press_held = false


## Screen-space center, used as the start or end of a travel arc.
func get_global_center() -> Vector2:
	return global_position + size * 0.5


#region --- Animations ---

## Bought from the merchant. Flies from the shelf card, then slams into the well.
func play_arrival(from_global_center: Vector2) -> void:
	if GameManager.skip_presentation:
		return
	_kill_motion()
	var start := from_global_center - get_global_center()
	_token.position = start
	_token.scale = ARRIVAL_START_SCALE
	_token.modulate.a = 0.0
	_token.z_index = 20
	_motion_tween = create_tween()
	_motion_tween.tween_method(
		func(t: float) -> void:
			# Rise first, then drop into the well.
			var lift := -sin(t * PI) * ARRIVAL_ARC_HEIGHT
			_token.position = start.lerp(Vector2.ZERO, t) + Vector2(0.0, lift)
			_token.scale = ARRIVAL_START_SCALE.lerp(Vector2.ONE, t),
		0.0, 1.0, ARRIVAL_FLIGHT_DURATION
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_motion_tween.parallel().tween_property(_token, "modulate:a", 1.0, ARRIVAL_FLIGHT_DURATION * 0.4)
	_append_seat(_motion_tween, true)


## Slides in from another point on screen. bulge bows the path sideways so two
## swapping chefs pass each other instead of overlapping. on_top draws above the other.
func play_travel_from(from_global_center: Vector2, bulge: float = 0.0, on_top: bool = false) -> void:
	if GameManager.skip_presentation:
		return
	_kill_motion()
	var start := from_global_center - get_global_center()
	if start.length() < 1.0:
		_append_seat(_begin_motion(), false)
		return
	var control := start * 0.5 + start.orthogonal().normalized() * bulge
	_token.position = start
	_token.z_index = 20 if on_top else 10
	_motion_tween = create_tween()
	_motion_tween.tween_method(
		func(t: float) -> void:
			# Quadratic bezier from start, through the bowed midpoint, to rest.
			var a := start.lerp(control, t)
			var b := control.lerp(Vector2.ZERO, t)
			_token.position = a.lerp(b, t),
		0.0, 1.0, TRAVEL_DURATION
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_append_seat(_motion_tween, false)


## Effect fired. Same pop, squash, and settle as a spot card so the board pacing matches.
## copied is the chef whose effect ran when this slot holds a copy chef.
func play_effect_pulse(copied: ChefCard = null) -> void:
	if GameManager.skip_presentation or chef == null:
		return
	_kill_motion()
	var speed := GameManager.game_speed
	_token.z_index = 10
	_motion_tween = create_tween()
	_motion_tween.tween_property(
		_token, "scale", CardIconUI.ACTIVATION_PEAK_SCALE, CardIconUI.ACTIVATION_POP_DURATION / speed
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_motion_tween.tween_property(
		_token, "scale", CardIconUI.ACTIVATION_SQUASH_SCALE, CardIconUI.ACTIVATION_SQUASH_DURATION / speed
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_motion_tween.tween_property(
		_token, "scale", _rest_scale(), CardIconUI.ACTIVATION_SETTLE_DURATION / speed
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_motion_tween.tween_callback(_finish_motion)
	_flash_rim(RIM_FADE_DURATION / speed)
	if copied != null and copied != chef:
		_flash_copy_ghost(copied, COPY_GHOST_DURATION / speed)


## Dragged somewhere it cannot go. Short sideways shake.
func play_reject() -> void:
	if GameManager.skip_presentation:
		return
	_kill_motion()
	_motion_tween = create_tween()
	var step := REJECT_DURATION / 4.0
	for offset_x: float in [REJECT_SHAKE_PX, -REJECT_SHAKE_PX, REJECT_SHAKE_PX * 0.5, 0.0]:
		_motion_tween.tween_property(_token, "position:x", offset_x, step)
	_motion_tween.tween_callback(_finish_motion)


## Ghost only. Shrinks into the sell panel, then calls done.
func play_sell_into(target_global_center: Vector2, done: Callable) -> void:
	if GameManager.skip_presentation:
		done.call()
		return
	_kill_motion()
	_motion_tween = create_tween()
	_motion_tween.set_parallel(true)
	_motion_tween.tween_property(
		self, "global_position", target_global_center - size * 0.5, 0.2
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_motion_tween.tween_property(_token, "scale", Vector2(0.2, 0.2), 0.2).set_trans(
		Tween.TRANS_BACK
	).set_ease(Tween.EASE_IN)
	_motion_tween.tween_property(_token, "modulate:a", 0.0, 0.2)
	_motion_tween.chain().tween_callback(func() -> void:
		_finish_motion()
		done.call()
	)


func _begin_motion() -> Tween:
	_motion_tween = create_tween()
	return _motion_tween


## Landing beat appended to a travel tween. heavy adds dust and a screen shake.
func _append_seat(tween: Tween, heavy: bool) -> void:
	tween.tween_callback(func() -> void:
		_token.position = Vector2.ZERO
		_flash_rim(RIM_FADE_DURATION)
		if heavy:
			_burst_dust()
			_shake_screen(SEAT_SHAKE_STRENGTH, SEAT_SHAKE_DURATION)
			AudioManager.play_sfx(UISounds.GROUND_IMPACT)
		else:
			AudioManager.play_ui_hover()
	)
	tween.tween_property(_token, "scale", SEAT_SQUASH_SCALE, SEAT_SQUASH_DURATION).set_trans(
		Tween.TRANS_QUAD
	).set_ease(Tween.EASE_OUT)
	tween.tween_property(_token, "scale", _rest_scale(), SEAT_SETTLE_DURATION).set_trans(
		Tween.TRANS_BACK
	).set_ease(Tween.EASE_OUT)
	tween.tween_callback(_finish_motion)


func _kill_motion() -> void:
	if _motion_tween != null and _motion_tween.is_valid():
		_motion_tween.kill()
	_motion_tween = null
	_token.position = Vector2.ZERO
	_token.scale = _rest_scale()
	_token.modulate.a = 1.0
	_token.z_index = 0


func _finish_motion() -> void:
	_motion_tween = null
	_token.position = Vector2.ZERO
	_token.scale = _rest_scale()
	_token.modulate.a = 1.0
	_token.z_index = 0


func _flash_rim(duration: float) -> void:
	if _rim_tween != null and _rim_tween.is_valid():
		_rim_tween.kill()
	var color: Color = RARITY_RIM_COLORS.get(
		chef.rarity if chef != null else Card.Rarity.COMMON,
		RARITY_RIM_COLORS[Card.Rarity.COMMON]
	)
	_rim.modulate = color
	_rim_tween = create_tween()
	_rim_tween.tween_property(_rim, "modulate:a", 0.0, duration).set_trans(
		Tween.TRANS_QUAD
	).set_ease(Tween.EASE_IN)


## Briefly shows whose effect a copy chef just ran.
func _flash_copy_ghost(copied: ChefCard, duration: float) -> void:
	if _ghost_tween != null and _ghost_tween.is_valid():
		_ghost_tween.kill()
	_copy_ghost.texture = _icon_for(copied)
	_copy_ghost.modulate = Color(1.2, 1.2, 1.4, 0.9)
	_copy_ghost.scale = Vector2(1.25, 1.25)
	_copy_ghost.pivot_offset = _copy_ghost.size * 0.5
	_ghost_tween = create_tween()
	_ghost_tween.set_parallel(true)
	_ghost_tween.tween_property(_copy_ghost, "modulate:a", 0.0, duration)
	_ghost_tween.tween_property(_copy_ghost, "scale", Vector2.ONE, duration).set_trans(
		Tween.TRANS_QUAD
	).set_ease(Tween.EASE_OUT)


func _burst_dust() -> void:
	if _dust == null:
		_dust = CPUParticles2D.new()
		_dust.one_shot = true
		_dust.emitting = false
		_dust.explosiveness = 0.95
		_dust.amount = 14
		_dust.lifetime = 0.45
		_dust.direction = Vector2.UP
		_dust.spread = 80.0
		_dust.gravity = Vector2(0.0, 260.0)
		_dust.initial_velocity_min = 60.0
		_dust.initial_velocity_max = 150.0
		_dust.scale_amount_min = 3.0
		_dust.scale_amount_max = 6.0
		_dust.color = DUST_COLOR
		var fade := Gradient.new()
		fade.set_color(0, Color(1, 1, 1, 1))
		fade.set_color(1, Color(1, 1, 1, 0))
		_dust.color_ramp = fade
		add_child(_dust)
	_dust.position = Vector2(size.x * 0.5, size.y * 0.72)
	_dust.restart()
	_dust.emitting = true


func _shake_screen(strength: float, duration: float) -> void:
	var camera := get_viewport().get_camera_2d()
	if camera == null or not camera.has_method("shake"):
		return
	camera.shake(strength, duration)

#endregion --- Animations ---


func _refresh() -> void:
	var shown := chef != null and not _lifted
	_token.visible = shown
	_well.modulate = FILLED_WELL_MODULATE if shown else EMPTY_WELL_MODULATE
	if _is_ghost:
		_well.hide()
	# Empty hexes pass the pointer through. Drops are resolved by rect, not by hover.
	var takes_input := _interactive and chef != null and not _is_ghost
	mouse_filter = Control.MOUSE_FILTER_STOP if takes_input else Control.MOUSE_FILTER_IGNORE
	if chef == null:
		return
	_icon.texture = _icon_for(chef)
	_name_tag.text = chef.name
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func _icon_for(card: ChefCard) -> Texture2D:
	return card.icon if card.icon != null else FeastStatIcons.PLACEHOLDER


func _update_pivot() -> void:
	_token.pivot_offset = size * 0.5


func _rest_scale() -> Vector2:
	if _controller_focused:
		return CONTROLLER_FOCUS_SCALE
	if _hovered and chef != null and not _is_ghost:
		return HOVER_SCALE
	return Vector2.ONE


func _apply_rest_scale(animate: bool) -> void:
	# A running travel or pulse owns the scale and settles to the rest scale itself.
	if _motion_tween != null and _motion_tween.is_valid():
		return
	if not animate or GameManager.skip_presentation:
		_token.scale = _rest_scale()
		return
	var tween := create_tween()
	tween.tween_property(_token, "scale", _rest_scale(), HOVER_DURATION).set_trans(
		Tween.TRANS_QUAD
	).set_ease(Tween.EASE_OUT)


func _on_mouse_entered() -> void:
	_hovered = true
	_apply_rest_scale(true)
	hover_changed.emit(slot_index, true)


func _on_mouse_exited() -> void:
	_hovered = false
	_apply_rest_scale(true)
	hover_changed.emit(slot_index, false)


func _on_gui_input(event: InputEvent) -> void:
	if _is_ghost or chef == null:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_press_held = event.pressed
		if event.pressed:
			_press_screen_pos = event.global_position
		return
	# A small pointer move is still a click. Past the threshold it becomes a drag.
	if event is InputEventMouseMotion and _press_held:
		if event.global_position.distance_to(_press_screen_pos) >= DRAG_START_THRESHOLD_PX:
			_press_held = false
			drag_started.emit(slot_index)
