class_name RuneUI
extends Control

@onready var rune_button: TextureButton = $Container/RuneButton
@onready var _anim_target: Control = $Container
@onready var enhancement_value_container: PanelContainer = $Container/EnhancementValueContainer
@onready var enhancement_value: Label = $Container/EnhancementValueContainer/EnhancementValue
@onready var placement_smoke: GPUParticles2D = $PlacementSmoke
@onready var hex_stroke: HexStroke = $HexStroke

var map: HexTileMap
var tile: Hex
var center_coordinates: Vector2i

# Keeps activation tweens from stacking if triggers overlap.
var _activation_tween: Tween
var _empower_flash_tween: Tween
# Resting color when no activation or empower tween is running.
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
# Hover preview and the start of the place animation sit slightly larger than the hex.
const PLACEMENT_HOVER_SCALE := 1.16
const PLACEMENT_INSERT_DURATION := 0.28
const EMPOWER_FLASH_HIGHLIGHT := Color(1.45, 1.35, 0.15, 1.0)
const EMPOWER_FLASH_DURATION := 0.45

func setup(rune: TileCard) -> void:
	if not is_node_ready():
		await ready
	
	rune_button.texture_normal = rune.icon
	# Show enhancement if it exists on loading a game
	if rune.enhancement != null:
		show_enhancement(rune.enhancement)


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
# Scales the rune from the oversized hover preview down into the hex.
func play_placement_animation() -> void:
	_anim_target.pivot_offset = _anim_target.size / 2
	if _anim_target.pivot_offset == Vector2.ZERO:
		_anim_target.pivot_offset = size / 2
	_anim_target.scale = Vector2(PLACEMENT_HOVER_SCALE, PLACEMENT_HOVER_SCALE)
	_anim_target.modulate = Color(1.0, 1.0, 1.0, 0.9)
	z_index = 10

	var placement_tween := create_tween()
	placement_tween.set_parallel(true)
	# Back ease overshoots slightly under 1, then seats at rest like a press-in.
	placement_tween.tween_property(
		_anim_target,
		"scale",
		Vector2.ONE,
		PLACEMENT_INSERT_DURATION
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	placement_tween.tween_property(
		_anim_target,
		"modulate",
		_resting_modulate,
		PLACEMENT_INSERT_DURATION * 0.8
	)
	placement_tween.chain().tween_callback(func() -> void:
		z_index = 0
		_anim_target.scale = Vector2.ONE
	)
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
	if _empower_flash_tween != null and _empower_flash_tween.is_valid():
		return false
	return true


func _apply_resting_modulate() -> void:
	if _can_apply_resting_modulate():
		_anim_target.modulate = _resting_modulate


# Brief scale pulse + warm flash so the active rune reads clearly during turn resolution.
func play_activation_animation() -> void:
	stop_empower_flash()
	
	if _activation_tween != null and _activation_tween.is_valid():
		_activation_tween.kill()
	
	_anim_target.pivot_offset = _anim_target.size / 2
	_anim_target.scale = Vector2.ONE
	_anim_target.modulate = Color.WHITE
	
	var original_z_index := z_index
	z_index = 10
	_shake_on_activation()

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


func _shake_on_activation() -> void:
	var camera := get_viewport().get_camera_2d()
	if camera == null or not camera.has_method("shake"):
		return
	camera.shake(ACTIVATION_SHAKE_STRENGTH, ACTIVATION_SHAKE_DURATION)


static func activation_animation_duration() -> float:
	return ACTIVATION_POP_DURATION + ACTIVATION_SQUASH_DURATION + ACTIVATION_SETTLE_DURATION


# Gold highlight flash when a segment's turn totals are revealed.
func play_segment_result_animation() -> void:
	stop_empower_flash()

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


# Looping yellow pulse while a rune waits to trigger its empowered production.
func start_empower_flash() -> void:
	stop_empower_flash()
	
	_empower_flash_tween = create_tween()
	_empower_flash_tween.set_loops()
	_empower_flash_tween.tween_property(
		_anim_target,
		"modulate",
		EMPOWER_FLASH_HIGHLIGHT,
		EMPOWER_FLASH_DURATION
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_empower_flash_tween.tween_property(
		_anim_target,
		"modulate",
		_resting_modulate,
		EMPOWER_FLASH_DURATION
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func stop_empower_flash() -> void:
	if _empower_flash_tween != null and _empower_flash_tween.is_valid():
		_empower_flash_tween.kill()
	_empower_flash_tween = null
	
	_apply_resting_modulate()
#endregion Animations and colors
