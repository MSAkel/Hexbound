class_name RuneUI
extends Control

@onready var rune_button: TextureButton = $Container/RuneButton
@onready var _anim_target: Control = $Container
@onready var enhancement_value_container: PanelContainer = $Container/Identifiers/EnhancementValueContainer
@onready var enhancement_value: Label = $Container/Identifiers/EnhancementValueContainer/EnhancementValue
@onready var placement_smoke: GPUParticles2D = $PlacementSmoke
@onready var empower_sparks: GPUParticles2D = $EmpowerSparks
@onready var hex_stroke: HexStroke = $HexStroke
@onready var sigil: TextureRect = $Container/Identifiers/Sigil
@onready var output_chip: PanelContainer = $Container/OutputChip
@onready var output_chip_icon: TextureRect = $Container/OutputChip/OutputChipRow/OutputChipIcon
@onready var output_chip_label: Label = $Container/OutputChip/OutputChipRow/OutputChipLabel

var map: HexTileMap
var tile: Hex
var center_coordinates: Vector2i

# Keeps activation tweens from stacking if triggers overlap.
var _activation_tween: Tween
var _trigger_link_flash_tween: Tween
# Resting color when no activation or trigger-link tween is running.
var _resting_modulate := Color.WHITE

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
const TRIGGER_LINK_FLASH_HIGHLIGHT := Color(1.35, 0.72, 0.22, 1.0)
const TRIGGER_LINK_FLASH_DURATION := 0.42
const CHAINED_ACTIVATION_PEAK_SCALE := Vector2(1.06, 1.06)
const CHAINED_ACTIVATION_HIGHLIGHT := Color(1.28, 0.78, 0.28, 1.0)

func setup(rune: TileCard) -> void:
	if not is_node_ready():
		await ready
	
	rune_button.texture_normal = rune.icon
	# Role lives on the bottom chip. The corner sigil would duplicate producer icons.
	if sigil != null:
		sigil.hide()
	refresh_output_chip(rune)
	# Show enhancement if it exists on loading a game
	if rune.enhancement != null:
		show_enhancement(rune.enhancement)


# Refresh the output chip after bonuses, chance, or progress change.
func refresh_output_chip(rune: TileCard) -> void:
	if not is_node_ready() or rune == null:
		return
	_show_output_chip(rune)


func _show_output_chip(rune: TileCard) -> void:
	if output_chip == null:
		return
	var chip: Dictionary = rune.get_board_chip(tile)
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


## Called by Hex when an enhancement is attached to this tile.
func show_enhancement(enhancement: Enhancement) -> void:
	if enhancement == null:
		enhancement_value_container.hide()
		return

	enhancement_value_container.show()
	enhancement_value.text = enhancement.short_description

	# Dark tints on the panel only; the label stays white with a thin outline.
	match enhancement.type:
		Enhancement.Type.SCORE:
			enhancement_value.text = "+ %s" % str(enhancement.score_bonus)
			enhancement_value_container.self_modulate = Color(0.08, 0.38, 0.40)
		Enhancement.Type.MULTIPLIER:
			enhancement_value.text = "+ %s" % str(enhancement.mult_bonus)
			enhancement_value_container.self_modulate = Color(0.52, 0.10, 0.12)
		Enhancement.Type.GOLD:
			enhancement_value.text = "+ %s" % str(enhancement.gold_bonus)
			enhancement_value_container.self_modulate = Color(0.715, 0.509, 0.05)
		Enhancement.Type.TRIGGER:
			enhancement_value.text = "+ %s" % str(enhancement.trigger_count)
			enhancement_value_container.self_modulate = Color(0.58, 0.28, 0.06)


#region Animations and colors
# Drops the oversized hover pose into the hex with a hard slam, then seats at rest.
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


func _on_placement_impact() -> void:
	_shake_screen(PLACEMENT_SHAKE_STRENGTH, PLACEMENT_SHAKE_DURATION)
	_play_placement_smoke()
	if hex_stroke != null:
		hex_stroke.play_clockwise_draw()


func _play_placement_smoke() -> void:
	if placement_smoke == null:
		return
	# One-shot emitters stay off until this restart. Emitting must be set true after.
	placement_smoke.restart()
	placement_smoke.emitting = true


func apply_resting_modulate(color: Color) -> void:
	_resting_modulate = color
	if _can_apply_resting_modulate():
		_anim_target.modulate = color


func _can_apply_resting_modulate() -> bool:
	if _activation_tween != null and _activation_tween.is_valid():
		return false
	if _trigger_link_flash_tween != null and _trigger_link_flash_tween.is_valid():
		return false
	return true


func _apply_resting_modulate() -> void:
	if _can_apply_resting_modulate():
		_anim_target.modulate = _resting_modulate


# Brief scale pulse + warm flash so the active rune reads clearly during turn resolution.
func play_activation_animation() -> void:
	stop_empower_sparks()
	
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
	)


# Chained fire from another rune. Orange palette and a smaller pop than a primary activation.
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
	)


func _shake_on_activation() -> void:
	_shake_screen(ACTIVATION_SHAKE_STRENGTH, ACTIVATION_SHAKE_DURATION)


func _shake_screen(strength: float, duration: float) -> void:
	var camera := get_viewport().get_camera_2d()
	if camera == null or not camera.has_method("shake"):
		return
	camera.shake(strength, duration)


static func activation_animation_duration() -> float:
	return ACTIVATION_POP_DURATION + ACTIVATION_SQUASH_DURATION + ACTIVATION_SETTLE_DURATION


# Gold highlight flash when a segment's turn totals are revealed.
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
	_activation_tween.tween_callback(func() -> void:
		AudioManager.play_sfx(UISounds.SEGMENT_RESULT)
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
	)


# Sparks over the rune while it is waiting to spend an empower charge.
func start_empower_sparks() -> void:
	if empower_sparks == null:
		return
	if empower_sparks.emitting:
		return

	empower_sparks.restart()
	empower_sparks.emitting = true


func stop_empower_sparks() -> void:
	if empower_sparks != null:
		empower_sparks.emitting = false


# Looping orange pulse on the source rune while its queued triggers resolve.
func start_trigger_link_flash() -> void:
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


func stop_trigger_link_flash() -> void:
	if _trigger_link_flash_tween != null and _trigger_link_flash_tween.is_valid():
		_trigger_link_flash_tween.kill()
	_trigger_link_flash_tween = null

	if hex_stroke != null:
		hex_stroke.stop_trigger_link_ring()

	_apply_resting_modulate()
#endregion Animations and colors
