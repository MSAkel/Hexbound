class_name CardIconUI
extends Control

## Visual representation of a [TileCard] on the hex map.
##
## This scene wraps [CardIcon] with board-only presentation: the output chip,
## condiment fuse badges, a hex outline, particle effects, and placement/resolution
## animations. Both placed cards and card-placement ghosts instantiate this class;
## call [method prepare_placement_ghost] to make a copy display-only.
##
## [Hex] supplies [member tile], [member map], and [member center_coordinates] before
## calling [method setup] for a placed card. Use [CardIcon] directly when only the
## card artwork is needed outside the board.

#region Scene references

@onready var rune_button: TextureButton = $Container/RuneButton
@onready var card_icon: CardIcon = $Container/RuneButton/CardIcon
@onready var _anim_target: Control = $Container
@onready var placement_smoke: GPUParticles2D = $PlacementSmoke
@onready var placement_dust: GPUParticles2D = $PlacementDust
@onready var placement_slash: GPUParticles2D = $PlacementSlash
@onready var empower_sparks: GPUParticles2D = $EmpowerSparks
@onready var hex_stroke: HexStroke = $HexStroke
@onready var output_chip: PanelContainer = $Container/OutputChip
@onready var output_chip_icon: TextureRect = $Container/OutputChip/OutputChipRow/OutputChipIcon
@onready var output_chip_label: Label = $Container/OutputChip/OutputChipRow/OutputChipLabel
@onready var output_chip_extra_icon: TextureRect = $Container/OutputChip/OutputChipRow/OutputChipExtraIcon
@onready var output_chip_extra_label: Label = $Container/OutputChip/OutputChipRow/OutputChipExtraLabel

## Map that owns this icon. Assigned by [Hex] for placed cards and landing previews.
var map: HexTileMap
## Hex whose card this icon represents. May be [code]null[/code] for a cursor ghost.
var tile: Hex
## Board coordinates used to look up location-specific condiment fuses.
var center_coordinates: Vector2i

#endregion

#region Presentation state

# Long-lived tween references serve as state as well as allowing overlapping effects
# to be cancelled. A transient tween owns the animated properties until it finishes.
var _activation_tween: Tween
var _trigger_link_flash_tween: Tween
var _seal_tween: Tween
var _inspect_hover_tween: Tween
var _inspect_hover_active := false
# Color is composed in layers: Hex state -> sealed tint -> recipe-preview dim.
# Transient animation colors temporarily override that composed resting color.
var _base_resting_modulate := Color.WHITE
var _resting_modulate := Color.WHITE
var _is_segment_sealed := false
# A seal may arrive during an activation. Delay its persistent rim so the two effects
# remain legible instead of fighting over the icon at the same time.
var _pending_sealed_rim := false
var _seal_shine: SealHexShine
var _recipe_preview_dimmed := false
# Condiment UI is created lazily because placement ghosts and most cards never use it.
var _fuse_bar: HBoxContainer
var _condiment_splash: GPUParticles2D

#endregion

#region Presentation constants

# Pop, squash, then settle. Durations must stay in sync with HexTileMap._wait_for_activation_animation.
const ACTIVATION_PEAK_SCALE := Vector2(1.12, 1.12)
const ACTIVATION_SQUASH_SCALE := Vector2(0.88, 0.88)
const ACTIVATION_HIGHLIGHT := Color(1.3, 1.15, 0.75, 1.0)
const ACTIVATION_POP_DURATION := 0.07
const ACTIVATION_SQUASH_DURATION := 0.08
const ACTIVATION_SETTLE_DURATION := 0.08
const ACTIVATION_SHAKE_STRENGTH := 4.5
const ACTIVATION_SHAKE_DURATION := 0.14
# Gold flash timing; kept in sync with HexTileMap.SEGMENT_REVEAL_ANIMATION_DURATION.
const SEGMENT_REVEAL_HIGHLIGHT_DURATION := 0.2
const SEGMENT_REVEAL_FADE_DURATION := 0.16
# Hover preview sits slightly larger than the hex. Slam overshoots, then seats at rest.
const PLACEMENT_HOVER_SCALE := 1.16
const PLACEMENT_SLAM_SCALE := Vector2(1.08, 0.78)
const PLACEMENT_DROP_OFFSET := -40.0
const PLACEMENT_SLAM_DURATION := 0.11
const PLACEMENT_RECOVER_DURATION := 0.13
const PLACEMENT_SHAKE_STRENGTH := 8.0
const PLACEMENT_SHAKE_DURATION := 0.18
# Drag-drop lands from the hover pose. Softer than the click-to-place slam.
const DRAG_SEAT_SQUASH_SCALE := Vector2(1.03, 0.96)
const DRAG_SEAT_SQUASH_DURATION := 0.08
const DRAG_SEAT_SETTLE_DURATION := 0.12
const DRAG_PLACEMENT_SHAKE_STRENGTH := 4.0
const TRIGGER_LINK_FLASH_HIGHLIGHT := Color(1.35, 0.72, 0.22, 1.0)
const TRIGGER_LINK_FLASH_DURATION := 0.42
const CHAINED_ACTIVATION_PEAK_SCALE := Vector2(1.06, 1.06)
const CHAINED_ACTIVATION_HIGHLIGHT := Color(1.28, 0.78, 0.28, 1.0)
# Mid-turn segment close. Smaller than placement slam, big enough to read over activations.
const SEAL_LIFT_OFFSET := -26.0
const SEAL_PEAK_SCALE := Vector2(1.1, 1.1)
const SEAL_SQUASH_SCALE := Vector2(1.08, 0.8)
const SEAL_LIFT_DURATION := 0.07
const SEAL_SLAM_DURATION := 0.09
const SEAL_SETTLE_DURATION := 0.12
const SEAL_HIGHLIGHT := Color(1.55, 1.28, 0.55, 1.0)
const SEALED_REST_TINT := Color(1.08, 0.96, 0.7, 1.0)
# Map inspect hover. Subtler than placement ghost and activation pop.
const INSPECT_HOVER_SCALE := Vector2(1.08, 1.08)
const INSPECT_HOVER_MODULATE := Color(1.15, 1.1, 1.0, 1.0)
const INSPECT_HOVER_DURATION := 0.12
# Keep the chip seated above the hex bottom while its width follows the numbers.
const OUTPUT_CHIP_BOTTOM_INSET := 28.0
# Dim placed cards whose tags cannot fill the hovered dish recipe.
const RECIPE_INVALID_DIM := Color(0.42, 0.42, 0.48, 1.0)

#endregion

#region Setup and board chip

## Returns the unscaled duration of the complete segment-seal slam.
## Keep this in sync with [method HexTileMap.wait_for_segment_seal].
static func get_segment_seal_duration() -> float:
	return SEAL_LIFT_DURATION + SEAL_SLAM_DURATION + SEAL_SETTLE_DURATION


## Binds [param rune] to the embedded icon and builds its board-specific overlays.
##
## If the node has not entered the scene tree yet, setup is deferred until its
## [code]@onready[/code] references exist. Assign [member tile] and
## [member center_coordinates] first when this represents a placed card.
func setup(rune: TileCard) -> void:
	if not is_node_ready():
		call_deferred("setup", rune)
		return
	
	card_icon.setup(rune)
	refresh_output_chip(rune)
	refresh_condiment_badges(rune, center_coordinates)


## Configures this instance as the display-only ghost used while aiming a hand card.
## The ghost retains the same card face and output chip as a placed card, but cannot
## consume mouse input and does not draw the board's persistent hex stroke.
func prepare_placement_ghost() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	if rune_button != null:
		rune_button.mouse_filter = MOUSE_FILTER_IGNORE
		rune_button.disabled = true
	if hex_stroke != null:
		hex_stroke.visible = false
	if output_chip != null:
		output_chip.mouse_filter = MOUSE_FILTER_IGNORE
	reset_ghost_visuals()


## Applies the floating placement-preview scale, multiplied by [param pulse].
##
## The scale lives on the inner container so the root can move between screen and
## board coordinates while the snap/seat animation independently changes its pose.
func set_ghost_float_scale(pulse: float = 1.0) -> void:
	scale = Vector2.ONE
	if _anim_target == null:
		return
	# Scale from the icon center. A top-left pivot drifts the preview off the tile.
	_anim_target.pivot_offset = _anim_target.size / 2
	_anim_target.position = Vector2.ZERO
	_anim_target.scale = Vector2.ONE * PLACEMENT_HOVER_SCALE * pulse


## Restores a reusable placement ghost to its visible, non-emitting hover pose.
func reset_ghost_visuals() -> void:
	_silence_particle_emitters()
	modulate = Color.WHITE
	scale = Vector2.ONE
	if _anim_target != null:
		_anim_target.pivot_offset = _anim_target.size / 2
		_anim_target.position = Vector2.ZERO
		_anim_target.scale = Vector2(PLACEMENT_HOVER_SCALE, PLACEMENT_HOVER_SCALE)


# Hide emitters without restart(). restart() starts a new burst in Godot.
func _silence_particle_emitters() -> void:
	_silence_emitter(placement_smoke)
	_silence_emitter(placement_dust)
	_silence_emitter(placement_slash)
	_silence_emitter(empower_sparks)


func _silence_emitter(emitter: GPUParticles2D) -> void:
	if emitter == null:
		return
	emitter.emitting = false
	emitter.visible = false


## Hides both rows of the output chip without changing their cached content.
func hide_output_chip() -> void:
	if output_chip != null:
		output_chip.hide()
	_hide_extra_chip_row()


## Rebuilds the output chip after the card's bonuses, chance, or progress changes.
## [member tile] is passed through to [method TileCard.get_board_chip] so a card may
## derive its display from neighboring board state. A hidden chip mode hides the panel.
func refresh_output_chip(rune: TileCard) -> void:
	if not is_node_ready() or rune == null:
		return
	_show_output_chip(rune)


func _show_output_chip(rune: TileCard) -> void:
	if output_chip == null:
		return
	var chip: Dictionary = rune.get_board_chip(tile)
	# TileCard owns the chip data contract; this class only turns that data into UI.
	var mode: Variant = chip.get("mode", TileCard.BoardChipMode.HIDDEN)
	if mode == TileCard.BoardChipMode.HIDDEN:
		output_chip.hide()
		return

	output_chip.show()
	# Dark fill only. White numbers stay readable on top.
	output_chip.self_modulate = chip.get("panel_color", rune.get_chip_panel_color())
	var chip_text := str(chip.get("text", ""))
	if chip_text.is_empty():
		output_chip_label.hide()
	else:
		output_chip_label.text = chip_text
		output_chip_label.show()
	var icon := chip.get("icon") as Texture2D
	if icon == null:
		output_chip_icon.hide()
	else:
		output_chip_icon.texture = icon
		output_chip_icon.show()
	_show_extra_chip_row(chip)
	_fit_output_chip()


func _show_extra_chip_row(chip: Dictionary) -> void:
	if output_chip_extra_icon == null or output_chip_extra_label == null:
		return
	var extra_text := str(chip.get("extra_text", ""))
	var extra_icon := chip.get("extra_icon") as Texture2D
	if extra_text.is_empty() and extra_icon == null:
		_hide_extra_chip_row()
		return
	if extra_icon == null:
		output_chip_extra_icon.hide()
	else:
		output_chip_extra_icon.texture = extra_icon
		output_chip_extra_icon.show()
	if extra_text.is_empty():
		output_chip_extra_label.hide()
	else:
		output_chip_extra_label.text = extra_text
		output_chip_extra_label.show()


func _hide_extra_chip_row() -> void:
	if output_chip_extra_icon != null:
		output_chip_extra_icon.hide()
	if output_chip_extra_label != null:
		output_chip_extra_label.hide()


# Shrink the chip to the visible icons and numbers, then keep it centered.
func _fit_output_chip() -> void:
	if output_chip == null:
		return
	output_chip.reset_size()
	var chip_size := output_chip.get_combined_minimum_size()
	output_chip.size = chip_size
	output_chip.offset_left = -chip_size.x * 0.5
	output_chip.offset_right = chip_size.x * 0.5
	output_chip.offset_bottom = -OUTPUT_CHIP_BOTTOM_INSET
	output_chip.offset_top = -OUTPUT_CHIP_BOTTOM_INSET - chip_size.y


#endregion

#region Placement presentation

## Drops a newly placed click-to-place card into its hex with a hard slam.
## This path owns the impact shake, dust burst, and outline draw; drag placement uses
## [method animate_ghost_snap_to] followed by [method play_drag_seat_animation].
func play_placement_animation() -> void:
	_anim_target.pivot_offset = _anim_target.size / 2
	if _anim_target.pivot_offset == Vector2.ZERO:
		_anim_target.pivot_offset = size / 2
	_anim_target.scale = Vector2(PLACEMENT_HOVER_SCALE, PLACEMENT_HOVER_SCALE)
	_anim_target.position.y = PLACEMENT_DROP_OFFSET
	_anim_target.modulate = Color(1.0, 1.0, 1.0, 0.9)
	z_index = 10

	var slam_duration := PLACEMENT_SLAM_DURATION / GameManager.game_speed
	var recover_duration := PLACEMENT_RECOVER_DURATION / GameManager.game_speed

	var placement_tween := create_tween()
	placement_tween.set_parallel(true)
	# Accelerate into the tile so the hit reads as a drop, not a float.
	placement_tween.tween_property(
		_anim_target,
		"position",
		Vector2.ZERO,
		slam_duration
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	placement_tween.tween_property(
		_anim_target,
		"scale",
		PLACEMENT_SLAM_SCALE,
		slam_duration
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	placement_tween.tween_property(
		_anim_target,
		"modulate",
		_resting_modulate,
		slam_duration
	)

	placement_tween.chain()
	placement_tween.tween_callback(_on_placement_impact)
	placement_tween.tween_property(
		_anim_target,
		"scale",
		Vector2.ONE,
		recover_duration
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	placement_tween.chain().tween_callback(func() -> void:
		z_index = 0
		_anim_target.scale = Vector2.ONE
		_anim_target.position = Vector2.ZERO
	)


## Moves a dragged ghost to [param target_pos] and returns after the snap tween finishes.
## [param target_pos] is a global canvas position. Ease-out makes the ghost decelerate
## as it reaches the hex; a non-positive [param duration] snaps immediately.
func animate_ghost_snap_to(target_pos: Vector2, duration: float) -> void:
	modulate = Color.WHITE
	_anim_target.pivot_offset = _anim_target.size / 2
	if _anim_target.pivot_offset == Vector2.ZERO:
		_anim_target.pivot_offset = size / 2
	if duration <= 0.0:
		global_position = target_pos
		_anim_target.scale = Vector2.ONE
		return
	var snap_tween := create_tween().set_parallel(true)
	snap_tween.tween_property(
		self,
		"global_position",
		target_pos,
		duration
	).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	snap_tween.tween_property(
		_anim_target,
		"scale",
		Vector2.ONE,
		duration
	).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	await snap_tween.finished


## Seats a dragged ghost that is already centered over its target hex.
## Returns after a gentler squash-and-settle than the click-to-place slam.
func play_drag_seat_animation() -> void:
	_anim_target.pivot_offset = _anim_target.size / 2
	if _anim_target.pivot_offset == Vector2.ZERO:
		_anim_target.pivot_offset = size / 2
	modulate = Color.WHITE

	var squash_duration := DRAG_SEAT_SQUASH_DURATION / GameManager.game_speed
	var settle_duration := DRAG_SEAT_SETTLE_DURATION / GameManager.game_speed
	var seat_tween := create_tween()
	seat_tween.tween_property(
		_anim_target,
		"scale",
		DRAG_SEAT_SQUASH_SCALE,
		squash_duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	seat_tween.tween_callback(_on_drag_placement_impact)
	seat_tween.tween_property(
		_anim_target,
		"scale",
		Vector2.ONE,
		settle_duration
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	seat_tween.tween_callback(func() -> void:
		_anim_target.scale = Vector2.ONE
		_anim_target.position = Vector2.ZERO
	)
	await seat_tween.finished


func _on_drag_placement_impact() -> void:
	_shake_screen(DRAG_PLACEMENT_SHAKE_STRENGTH, PLACEMENT_SHAKE_DURATION * 0.7)


func _on_placement_impact() -> void:
	_shake_screen(PLACEMENT_SHAKE_STRENGTH, PLACEMENT_SHAKE_DURATION)
	_play_placement_dust()
	if hex_stroke != null:
		hex_stroke.play_clockwise_draw()


## Plays the impact burst on the real card after a drag ghost has landed.
##
## The drag workflow hides its ghost before committing the card, so particles are
## emitted by the newly placed instance instead. Smoke is reserved for segment seals;
## placement uses dust and radial slashes plus the clockwise outline draw.
func play_placement_land_particles() -> void:
	_play_placement_dust()
	if hex_stroke != null:
		hex_stroke.play_clockwise_draw()


func _play_placement_dust() -> void:
	_burst_emitter(placement_dust)
	_burst_emitter(placement_slash)


func _play_placement_smoke() -> void:
	_burst_emitter(placement_smoke)


func _burst_emitter(emitter: GPUParticles2D) -> void:
	if emitter == null:
		return
	# Stay hidden until impact so showing a drag ghost cannot flash a leftover burst.
	emitter.visible = true
	emitter.restart()
	emitter.emitting = true


#endregion

#region Resting color and inspect hover

## Sets the base tint supplied by the owning [Hex].
##
## The sealed-state tint is recomputed from this color, then recipe-preview dimming is
## applied when displayed. If a transient animation currently owns [member modulate],
## the new resting color is stored and applied when that animation ends.
func apply_resting_modulate(color: Color) -> void:
	_base_resting_modulate = color
	_resting_modulate = _compute_resting_modulate()
	if _can_apply_resting_modulate():
		_anim_target.modulate = _visible_resting_modulate()


## Dims cards that cannot contribute to the recipe currently being previewed.
## Transient activation, trigger-link, and seal effects keep visual priority and restore
## the requested dim state when they finish.
func set_recipe_preview_dimmed(dimmed: bool) -> void:
	_recipe_preview_dimmed = dimmed
	if _anim_target == null:
		return
	if not _can_apply_resting_modulate():
		return
	_anim_target.modulate = _visible_resting_modulate()


func _visible_resting_modulate() -> Color:
	if _recipe_preview_dimmed:
		return _resting_modulate * RECIPE_INVALID_DIM
	return _resting_modulate


func _compute_resting_modulate() -> Color:
	if not _is_segment_sealed:
		return _base_resting_modulate
	return _base_resting_modulate.lerp(SEALED_REST_TINT, 0.55)


func _can_apply_resting_modulate() -> bool:
	# Writing modulate during one of these states would interrupt its visual feedback.
	if _activation_tween != null and _activation_tween.is_valid():
		return false
	if _trigger_link_flash_tween != null and _trigger_link_flash_tween.is_valid():
		return false
	if _seal_tween != null and _seal_tween.is_valid():
		return false
	if _inspect_hover_active:
		return false
	return true


func _apply_resting_modulate() -> void:
	if _can_apply_resting_modulate():
		_anim_target.modulate = _visible_resting_modulate()


## Lifts and brightens this placed card while the player inspects it on the map.
## Hover is suppressed when a recipe preview has dimmed the card or a higher-priority
## resolution animation is active.
func play_inspect_hover_in() -> void:
	# Recipe-invalid dim is the preview. Do not brighten over it.
	if _recipe_preview_dimmed:
		return
	if not _can_start_inspect_hover():
		return
	_stop_inspect_hover_tween()
	_inspect_hover_active = true
	_anim_target.pivot_offset = _anim_target.size / 2
	if _anim_target.pivot_offset == Vector2.ZERO:
		_anim_target.pivot_offset = size / 2
	var duration := INSPECT_HOVER_DURATION / GameManager.game_speed
	_inspect_hover_tween = create_tween()
	_inspect_hover_tween.set_ease(Tween.EASE_OUT)
	_inspect_hover_tween.set_trans(Tween.TRANS_QUAD)
	_inspect_hover_tween.set_parallel(true)
	_inspect_hover_tween.tween_property(_anim_target, "scale", INSPECT_HOVER_SCALE, duration)
	_inspect_hover_tween.tween_property(_anim_target, "modulate", INSPECT_HOVER_MODULATE, duration)


## Returns the card to its resting pose when map inspection ends.
## Any sealed tint or recipe-preview dimming is restored as part of the tween.
func play_inspect_hover_out() -> void:
	if not _inspect_hover_active and (_inspect_hover_tween == null or not _inspect_hover_tween.is_valid()):
		return
	_stop_inspect_hover_tween()
	_inspect_hover_active = false
	if _anim_target == null:
		return
	_anim_target.pivot_offset = _anim_target.size / 2
	if _anim_target.pivot_offset == Vector2.ZERO:
		_anim_target.pivot_offset = size / 2
	var duration := INSPECT_HOVER_DURATION / GameManager.game_speed
	_inspect_hover_tween = create_tween()
	_inspect_hover_tween.set_ease(Tween.EASE_OUT)
	_inspect_hover_tween.set_trans(Tween.TRANS_QUAD)
	_inspect_hover_tween.set_parallel(true)
	_inspect_hover_tween.tween_property(_anim_target, "scale", Vector2.ONE, duration)
	# Restore recipe-invalid dim if that preview is still active.
	_inspect_hover_tween.tween_property(_anim_target, "modulate", _visible_resting_modulate(), duration)


func _can_start_inspect_hover() -> bool:
	if _activation_tween != null and _activation_tween.is_valid():
		return false
	if _trigger_link_flash_tween != null and _trigger_link_flash_tween.is_valid():
		return false
	if _seal_tween != null and _seal_tween.is_valid():
		return false
	return true


func _stop_inspect_hover_tween() -> void:
	if _inspect_hover_tween != null and _inspect_hover_tween.is_valid():
		_inspect_hover_tween.kill()
	_inspect_hover_tween = null


func _clear_inspect_hover_state() -> void:
	_stop_inspect_hover_tween()
	_inspect_hover_active = false


#endregion

#region Activation presentation

## Plays the primary activation pop used when this card fires during turn resolution.
## Existing activation feedback is replaced, empower sparks stop, and map-inspection
## hover yields to the animation. The card restores its latest resting tint afterward.
func play_activation_animation() -> void:
	stop_empower_sparks()
	_clear_inspect_hover_state()
	
	if _activation_tween != null and _activation_tween.is_valid():
		_activation_tween.kill()
	
	_anim_target.pivot_offset = _anim_target.size / 2
	_anim_target.scale = Vector2.ONE
	_anim_target.modulate = Color.WHITE
	
	var original_z_index := z_index
	z_index = 10
	_shake_on_activation()
	if hex_stroke != null:
		# Linger past the pop so the firing tile stays marked while its float appears.
		hex_stroke.play_activation_glow(activation_animation_duration() + 0.28)

	var pop_duration := ACTIVATION_POP_DURATION / GameManager.game_speed
	var squash_duration := ACTIVATION_SQUASH_DURATION / GameManager.game_speed
	var settle_duration := ACTIVATION_SETTLE_DURATION / GameManager.game_speed
	
	_activation_tween = create_tween()
	
	# Step 1: pop outward with a gold-tinted highlight.
	_activation_tween.set_parallel(true)
	_activation_tween.tween_property(
		_anim_target,
		"scale",
		ACTIVATION_PEAK_SCALE,
		pop_duration
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_activation_tween.tween_property(
		_anim_target,
		"modulate",
		ACTIVATION_HIGHLIGHT,
		pop_duration
	)
	
	# Step 2: compress smaller than rest.
	_activation_tween.set_parallel(false)
	_activation_tween.tween_property(
		_anim_target,
		"scale",
		ACTIVATION_SQUASH_SCALE,
		squash_duration
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	
	# Step 3: return to the resting pose.
	_activation_tween.tween_property(
		_anim_target,
		"scale",
		Vector2.ONE,
		settle_duration
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_activation_tween.parallel().tween_property(
		_anim_target,
		"modulate",
		_resting_modulate,
		settle_duration
	)
	_activation_tween.tween_callback(func() -> void:
		z_index = original_z_index
		_activation_tween = null
		_apply_resting_modulate()
		_try_apply_pending_sealed_rim()
	)


## Plays the smaller orange pop used when this card is fired by another card's trigger.
## If the source-card trigger-link flash is also active, that looping flash retains
## ownership of the card color while this animation changes only the scale.
func play_chained_activation_animation() -> void:
	stop_empower_sparks()

	if _activation_tween != null and _activation_tween.is_valid():
		_activation_tween.kill()

	_anim_target.pivot_offset = _anim_target.size / 2
	_anim_target.scale = Vector2.ONE
	if _trigger_link_flash_tween == null or not _trigger_link_flash_tween.is_valid():
		_anim_target.modulate = Color.WHITE

	var original_z_index := z_index
	z_index = 10
	_shake_on_activation()
	if hex_stroke != null:
		hex_stroke.play_chained_activation_glow(activation_animation_duration() + 0.28)

	var pop_duration := ACTIVATION_POP_DURATION / GameManager.game_speed
	var squash_duration := ACTIVATION_SQUASH_DURATION / GameManager.game_speed
	var settle_duration := ACTIVATION_SETTLE_DURATION / GameManager.game_speed

	_activation_tween = create_tween()
	_activation_tween.set_parallel(true)
	_activation_tween.tween_property(
		_anim_target,
		"scale",
		CHAINED_ACTIVATION_PEAK_SCALE,
		pop_duration
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if _trigger_link_flash_tween == null or not _trigger_link_flash_tween.is_valid():
		_activation_tween.tween_property(
			_anim_target,
			"modulate",
			CHAINED_ACTIVATION_HIGHLIGHT,
			pop_duration
		)

	_activation_tween.set_parallel(false)
	_activation_tween.tween_property(
		_anim_target,
		"scale",
		ACTIVATION_SQUASH_SCALE,
		squash_duration
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	_activation_tween.tween_property(
		_anim_target,
		"scale",
		Vector2.ONE,
		settle_duration
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if _trigger_link_flash_tween == null or not _trigger_link_flash_tween.is_valid():
		_activation_tween.parallel().tween_property(
			_anim_target,
			"modulate",
			_resting_modulate,
			settle_duration
		)
	_activation_tween.tween_callback(func() -> void:
		z_index = original_z_index
		_activation_tween = null
		_apply_resting_modulate()
		_try_apply_pending_sealed_rim()
	)


func _shake_on_activation() -> void:
	_shake_screen(ACTIVATION_SHAKE_STRENGTH, ACTIVATION_SHAKE_DURATION)


func _shake_screen(strength: float, duration: float) -> void:
	var camera := get_viewport().get_camera_2d()
	if camera == null or not camera.has_method("shake"):
		return
	camera.shake(strength, duration)


## Returns the unscaled duration of either activation pop sequence.
## Callers that wait for presentation should divide this by [member GameManager.game_speed].
static func activation_animation_duration() -> float:
	return ACTIVATION_POP_DURATION + ACTIVATION_SQUASH_DURATION + ACTIVATION_SETTLE_DURATION


func _is_activation_animating() -> bool:
	return _activation_tween != null and _activation_tween.is_valid()


func _is_trigger_link_flashing() -> bool:
	return _trigger_link_flash_tween != null and _trigger_link_flash_tween.is_valid()


#endregion

#region Segment presentation

## Marks the card's segment sealed with a lift, gold flash, slam, smoke, and gold rim.
##
## If the card is still activating, the scale motion is skipped to preserve the firing
## animation. The seal still flashes immediately and queues its persistent rim until
## activation/trigger feedback no longer needs the same visual space.
func play_segment_seal_animation() -> void:
	_clear_inspect_hover_state()
	_is_segment_sealed = true
	_resting_modulate = _compute_resting_modulate()

	var skip_motion := _is_activation_animating()
	if skip_motion:
		_pending_sealed_rim = true
	else:
		_pending_sealed_rim = false
		_start_seal_shine()

	# Seal keeps the original short flame puff. Dirt burst is placement-only.
	_play_placement_smoke()

	if skip_motion:
		# Keep the pop intact. Still flash gold so the close reads on the last card.
		var flash := create_tween()
		flash.tween_property(
			_anim_target,
			"modulate",
			SEAL_HIGHLIGHT,
			0.06 / GameManager.game_speed
		)
		flash.tween_property(
			_anim_target,
			"modulate",
			_resting_modulate,
			0.14 / GameManager.game_speed
		)
		flash.tween_callback(func() -> void:
			_pending_sealed_rim = false
			_start_seal_shine()
		)
		return

	if _seal_tween != null and _seal_tween.is_valid():
		_seal_tween.kill()

	_anim_target.pivot_offset = _anim_target.size / 2
	if _anim_target.pivot_offset == Vector2.ZERO:
		_anim_target.pivot_offset = size / 2

	var lift_duration := SEAL_LIFT_DURATION / GameManager.game_speed
	var slam_duration := SEAL_SLAM_DURATION / GameManager.game_speed
	var settle_duration := SEAL_SETTLE_DURATION / GameManager.game_speed
	z_index = 12

	_seal_tween = create_tween()
	_seal_tween.set_parallel(true)
	_seal_tween.tween_property(
		_anim_target,
		"position:y",
		SEAL_LIFT_OFFSET,
		lift_duration
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_seal_tween.tween_property(
		_anim_target,
		"scale",
		SEAL_PEAK_SCALE,
		lift_duration
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_seal_tween.tween_property(
		_anim_target,
		"modulate",
		SEAL_HIGHLIGHT,
		lift_duration
	)

	_seal_tween.chain()
	_seal_tween.set_parallel(true)
	_seal_tween.tween_property(
		_anim_target,
		"position:y",
		0.0,
		slam_duration
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_seal_tween.tween_property(
		_anim_target,
		"scale",
		SEAL_SQUASH_SCALE,
		slam_duration
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)

	_seal_tween.chain()
	_seal_tween.set_parallel(true)
	_seal_tween.tween_property(
		_anim_target,
		"scale",
		Vector2.ONE,
		settle_duration
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_seal_tween.tween_property(
		_anim_target,
		"modulate",
		_resting_modulate,
		settle_duration
	)
	_seal_tween.chain().tween_callback(func() -> void:
		z_index = 0
		_anim_target.scale = Vector2.ONE
		_anim_target.position = Vector2.ZERO
		_seal_tween = null
		_apply_resting_modulate()
	)


## Removes the persistent sealed presentation and restores the normal resting state.
## Called when the map clears its segment results for the next resolution cycle.
func clear_segment_sealed() -> void:
	_is_segment_sealed = false
	_pending_sealed_rim = false
	if _seal_tween != null and _seal_tween.is_valid():
		_seal_tween.kill()
	_seal_tween = null
	_anim_target.scale = Vector2.ONE
	_anim_target.position = Vector2.ZERO
	if not _is_activation_animating():
		z_index = 0
	_stop_seal_shine()
	_resting_modulate = _compute_resting_modulate()
	_apply_resting_modulate()


func _ensure_seal_shine() -> void:
	if _seal_shine != null and is_instance_valid(_seal_shine):
		return
	_seal_shine = SealHexShine.new()
	_seal_shine.name = "SealHexShine"
	add_child(_seal_shine)


func _start_seal_shine() -> void:
	_ensure_seal_shine()
	_seal_shine.start_shine()


func _stop_seal_shine() -> void:
	if _seal_shine != null and is_instance_valid(_seal_shine):
		_seal_shine.stop_shine()


func _try_apply_pending_sealed_rim() -> void:
	if not _pending_sealed_rim or not _is_segment_sealed:
		return
	if _is_trigger_link_flashing():
		return
	_pending_sealed_rim = false
	_start_seal_shine()


## Flashes gold when this card's segment totals are revealed after turn resolution.
## This reuses the activation tween slot so activation and result feedback cannot
## compete for the icon's color.
func play_segment_result_animation() -> void:
	if _activation_tween != null and _activation_tween.is_valid():
		_activation_tween.kill()

	_anim_target.pivot_offset = _anim_target.size / 2
	_anim_target.scale = Vector2.ONE

	var original_z_index := z_index
	z_index = 10

	_activation_tween = create_tween()
	_activation_tween.tween_property(
		_anim_target,
		"modulate",
		ACTIVATION_HIGHLIGHT,
		SEGMENT_REVEAL_HIGHLIGHT_DURATION
	)
	_activation_tween.tween_property(
		_anim_target,
		"modulate",
		_resting_modulate,
		SEGMENT_REVEAL_FADE_DURATION
	)
	_activation_tween.tween_callback(func() -> void:
		z_index = original_z_index
		_activation_tween = null
		_apply_resting_modulate()
		_try_apply_pending_sealed_rim()
	)


#endregion

#region Ongoing resolution effects

## Starts the persistent sparks that show this card is empowered.
## Repeated calls are idempotent. Sparks sit under the chip so the board output remains readable.
func start_empower_sparks() -> void:
	if empower_sparks == null:
		return
	if empower_sparks.emitting:
		return

	empower_sparks.visible = true
	empower_sparks.restart()
	empower_sparks.emitting = true


## Stops and hides the empowered-state sparks.
func stop_empower_sparks() -> void:
	if empower_sparks != null:
		empower_sparks.emitting = false
		empower_sparks.visible = false


## Starts a looping orange pulse and outline on a source card while its triggers resolve.
## Call [method stop_trigger_link_flash] after all queued linked activations complete.
func start_trigger_link_flash() -> void:
	_clear_inspect_hover_state()
	if _trigger_link_flash_tween != null and _trigger_link_flash_tween.is_valid():
		_trigger_link_flash_tween.kill()

	if hex_stroke != null:
		hex_stroke.start_trigger_link_ring()

	_trigger_link_flash_tween = create_tween()
	_trigger_link_flash_tween.set_loops()
	_trigger_link_flash_tween.tween_property(
		_anim_target,
		"modulate",
		TRIGGER_LINK_FLASH_HIGHLIGHT,
		TRIGGER_LINK_FLASH_DURATION
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_trigger_link_flash_tween.tween_property(
		_anim_target,
		"modulate",
		_resting_modulate,
		TRIGGER_LINK_FLASH_DURATION
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## Stops source-card trigger feedback and restores the latest resting presentation.
## A segment-seal rim that was deferred during the flash is applied here.
func stop_trigger_link_flash() -> void:
	if _trigger_link_flash_tween != null and _trigger_link_flash_tween.is_valid():
		_trigger_link_flash_tween.kill()
	_trigger_link_flash_tween = null

	if hex_stroke != null:
		hex_stroke.stop_trigger_link_ring()

	_apply_resting_modulate()
	_try_apply_pending_sealed_rim()


#endregion

#region Condiment presentation

## Rebuilds the fuse badges for [param card] at [param coords].
##
## [CondimentManager] determines which fuses are active and their remaining turns;
## this class only creates their board presentation. Invalid catalog IDs are ignored.
func refresh_condiment_badges(card: TileCard, coords: Vector2i) -> void:
	_ensure_fuse_ui()
	for child in _fuse_bar.get_children():
		child.queue_free()
	var badges := CondimentManager.get_badge_fuses(card, coords)
	_fuse_bar.visible = not badges.is_empty()
	for fuse in badges:
		var condiment := CondimentCatalog.get_by_id(str(fuse.get("condiment_id", "")))
		if condiment == null:
			continue
		_fuse_bar.add_child(_make_fuse_badge(condiment, int(fuse.get("remaining_turns", 0))))


func _make_fuse_badge(condiment: Condiment, turns: int) -> PanelContainer:
	# Olive well on the hex face so the flask reads against grass and chip art.
	var well := PanelContainer.new()
	well.custom_minimum_size = Vector2(50, 50)
	well.mouse_filter = Control.MOUSE_FILTER_IGNORE
	well.add_theme_stylebox_override("panel", _fuse_badge_style())

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(26, 26)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.texture = condiment.icon
	icon.self_modulate = Color.WHITE
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	well.add_child(icon)

	if turns > 0:
		var count := Label.new()
		count.text = str(turns)
		count.add_theme_font_size_override("font_size", 12)
		count.add_theme_color_override("font_color", Color(1, 0.95, 0.7, 1))
		count.add_theme_color_override("font_outline_color", Color(0.05, 0.06, 0.04, 1))
		count.add_theme_constant_override("outline_size", 4)
		count.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		count.offset_left = -16.0
		count.offset_top = -16.0
		count.mouse_filter = Control.MOUSE_FILTER_IGNORE
		well.add_child(count)
	return well


func _fuse_badge_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("536044")
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color("F7E9C4")
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	style.content_margin_left = 4
	style.content_margin_top = 4
	style.content_margin_right = 4
	style.content_margin_bottom = 4
	return style


## Bursts particles in [param color] when a condiment is applied or consumed.
func play_condiment_splash(color: Color) -> void:
	_ensure_fuse_ui()
	if _condiment_splash == null:
		return
	_condiment_splash.modulate = color
	_condiment_splash.restart()
	_condiment_splash.emitting = true


func _ensure_fuse_ui() -> void:
	# Badges and splash particles are runtime-built so the base scene stays lightweight.
	if _fuse_bar != null:
		return
	_fuse_bar = HBoxContainer.new()
	_fuse_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fuse_bar.z_index = 3
	_fuse_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	_fuse_bar.add_theme_constant_override("separation", 4)
	# Sit on the hex face, below the top vertex and above the center art.
	_fuse_bar.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_fuse_bar.offset_left = -72.0
	_fuse_bar.offset_top = 44.0
	_fuse_bar.offset_right = 72.0
	_fuse_bar.offset_bottom = 86.0
	if _anim_target != null:
		_anim_target.add_child(_fuse_bar)
	else:
		add_child(_fuse_bar)

	_condiment_splash = GPUParticles2D.new()
	_condiment_splash.one_shot = true
	_condiment_splash.amount = 18
	_condiment_splash.lifetime = 0.45
	_condiment_splash.explosiveness = 0.85
	_condiment_splash.position = size * 0.5
	_condiment_splash.z_index = 12
	_condiment_splash.emitting = false
	var splash_material := ParticleProcessMaterial.new()
	splash_material.particle_flag_disable_z = true
	splash_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	splash_material.emission_sphere_radius = 18.0
	splash_material.direction = Vector3(0, -1, 0)
	splash_material.spread = 80.0
	splash_material.initial_velocity_min = 40.0
	splash_material.initial_velocity_max = 90.0
	splash_material.gravity = Vector3(0, 80, 0)
	splash_material.scale_min = 0.08
	splash_material.scale_max = 0.18
	_condiment_splash.process_material = splash_material
	_condiment_splash.texture = preload("res://assets/particles/spark/spark_03.png")
	add_child(_condiment_splash)

#endregion
