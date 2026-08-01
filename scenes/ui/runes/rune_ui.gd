class_name RuneUI
extends Control

@onready var rune_button: TextureButton = $Container/RuneButton
@onready var _anim_target: Control = $Container

var map: HexTileMap
var tile: Hex
var center_coordinates: Vector2i

# Keeps activation tweens from stacking if triggers overlap.
var _activation_tween: Tween

# Pop scale and warm highlight tuned to fit within the turn-end delay interval.
const ACTIVATION_PEAK_SCALE := Vector2(1.22, 1.22)
const ACTIVATION_HIGHLIGHT := Color(1.3, 1.15, 0.75, 1.0)
const ACTIVATION_POP_DURATION := 0.14
const ACTIVATION_SETTLE_DURATION := 0.22
const PLACEMENT_DROP_OFFSET := -72.0
const PLACEMENT_DROP_DURATION := 0.28

func setup(rune: Rune) -> void:
	if not is_node_ready():
		await ready
	
	rune_button.texture_normal = rune.icon


# Drop-in animation when a rune is first placed on a tile.
func play_placement_animation() -> void:
	_anim_target.position.y = PLACEMENT_DROP_OFFSET
	_anim_target.modulate = Color(1.0, 1.0, 1.0, 0.85)
	
	var placement_tween := create_tween()
	placement_tween.set_ease(Tween.EASE_OUT)
	placement_tween.set_trans(Tween.TRANS_BACK)
	placement_tween.tween_property(
		_anim_target,
		"position",
		Vector2.ZERO,
		PLACEMENT_DROP_DURATION
	)
	placement_tween.parallel().tween_property(
		_anim_target,
		"modulate",
		Color.WHITE,
		PLACEMENT_DROP_DURATION * 0.8
	)


# Brief scale pulse + warm flash so the active rune reads clearly during turn resolution.
func play_activation_animation() -> void:
	if _activation_tween != null and _activation_tween.is_valid():
		_activation_tween.kill()
	
	# Scale from the center of the hex-sized rune icon.
	_anim_target.pivot_offset = _anim_target.size / 2
	_anim_target.scale = Vector2.ONE
	_anim_target.modulate = Color.WHITE
	
	var original_z_index := z_index
	z_index = 10
	
	_activation_tween = create_tween()
	
	# Phase 1: pop outward with a gold-tinted highlight.
	_activation_tween.set_parallel(true)
	_activation_tween.tween_property(
		_anim_target,
		"scale",
		ACTIVATION_PEAK_SCALE,
		ACTIVATION_POP_DURATION
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_activation_tween.tween_property(
		_anim_target,
		"modulate",
		ACTIVATION_HIGHLIGHT,
		ACTIVATION_POP_DURATION
	)
	
	# Phase 2: settle back to the resting pose.
	_activation_tween.set_parallel(false)
	_activation_tween.tween_property(
		_anim_target,
		"scale",
		Vector2.ONE,
		ACTIVATION_SETTLE_DURATION
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_activation_tween.parallel().tween_property(
		_anim_target,
		"modulate",
		Color.WHITE,
		ACTIVATION_SETTLE_DURATION
	)
	_activation_tween.tween_callback(func() -> void:
		z_index = original_z_index
		_activation_tween = null
	)
