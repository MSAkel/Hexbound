class_name RuneUI
extends Control

@onready var rune_button: TextureButton = $Container/RuneButton
@onready var _anim_target: Control = $Container
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
var _fuse_bar: HBoxContainer
var _potion_splash: GPUParticles2D

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

func setup(rune: TileCard) -> void:
	if not is_node_ready():
		call_deferred("setup", rune)
		return
	
	rune_button.texture_normal = rune.icon
	# Role lives on the bottom chip. The corner sigil would duplicate producer icons.
	if sigil != null:
		sigil.hide()
	refresh_output_chip(rune)
	refresh_potion_badges(rune, center_coordinates)


## Ghost copy used while aiming a hand card. Same chip as a placed rune, no input.
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


## Hover scale lives on the inner container so seat tweens read correctly.
func set_ghost_float_scale(pulse: float = 1.0) -> void:
	scale = Vector2.ONE
	if _anim_target == null:
		return
	# Scale from the icon center. A top-left pivot drifts the preview off the tile.
	_anim_target.pivot_offset = _anim_target.size / 2
	_anim_target.position = Vector2.ZERO
	_anim_target.scale = Vector2.ONE * PLACEMENT_HOVER_SCALE * pulse


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
	if placement_smoke != null:
		placement_smoke.emitting = false
		placement_smoke.visible = false
	if empower_sparks != null:
		empower_sparks.emitting = false
		empower_sparks.visible = false


func hide_output_chip() -> void:
	if output_chip != null:
		output_chip.hide()


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


## Glide the dragged ghost into the hex center. Ease-out so it decelerates on arrival.
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


## Seat a dragged ghost that is already over the hex. Gentle squash, then settle.
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
	_play_placement_smoke()
	if hex_stroke != null:
		hex_stroke.play_clockwise_draw()


func _on_placement_impact() -> void:
	_shake_screen(PLACEMENT_SHAKE_STRENGTH, PLACEMENT_SHAKE_DURATION)
	_play_placement_smoke()
	if hex_stroke != null:
		hex_stroke.play_clockwise_draw()


func _play_placement_smoke() -> void:
	if placement_smoke == null:
		return
	# Stay hidden until impact so showing a drag ghost cannot flash a leftover burst.
	placement_smoke.visible = true
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


# Sparks sit under the chip so the icon and output stay readable.
func start_empower_sparks() -> void:
	if empower_sparks == null:
		return
	if empower_sparks.emitting:
		return

	empower_sparks.visible = true
	empower_sparks.restart()
	empower_sparks.emitting = true


func stop_empower_sparks() -> void:
	if empower_sparks != null:
		empower_sparks.emitting = false
		empower_sparks.visible = false


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


func refresh_potion_badges(card: TileCard, coords: Vector2i) -> void:
	_ensure_fuse_ui()
	for child in _fuse_bar.get_children():
		child.queue_free()
	var badges := PotionManager.get_badge_fuses(card, coords)
	_fuse_bar.visible = not badges.is_empty()
	for fuse in badges:
		var potion := PotionCatalog.get_by_id(str(fuse.get("potion_id", "")))
		if potion == null:
			continue
		_fuse_bar.add_child(_make_fuse_badge(potion, int(fuse.get("remaining_turns", 0))))


func _make_fuse_badge(potion: Potion, turns: int) -> PanelContainer:
	# Olive well on the hex face so the flask reads against grass and chip art.
	var well := PanelContainer.new()
	well.custom_minimum_size = Vector2(36, 36)
	well.mouse_filter = Control.MOUSE_FILTER_IGNORE
	well.add_theme_stylebox_override("panel", _fuse_badge_style())

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(26, 26)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.texture = potion.icon
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


func play_potion_splash(color: Color) -> void:
	_ensure_fuse_ui()
	if _potion_splash == null:
		return
	_potion_splash.modulate = color
	_potion_splash.restart()
	_potion_splash.emitting = true


func _ensure_fuse_ui() -> void:
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

	_potion_splash = GPUParticles2D.new()
	_potion_splash.one_shot = true
	_potion_splash.amount = 18
	_potion_splash.lifetime = 0.45
	_potion_splash.explosiveness = 0.85
	_potion_splash.position = size * 0.5
	_potion_splash.z_index = 12
	_potion_splash.emitting = false
	var material := ParticleProcessMaterial.new()
	material.particle_flag_disable_z = true
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	material.emission_sphere_radius = 18.0
	material.direction = Vector3(0, -1, 0)
	material.spread = 80.0
	material.initial_velocity_min = 40.0
	material.initial_velocity_max = 90.0
	material.gravity = Vector3(0, 80, 0)
	material.scale_min = 0.08
	material.scale_max = 0.18
	_potion_splash.process_material = material
	_potion_splash.texture = preload("res://assets/particles/spark/spark_03.png")
	add_child(_potion_splash)
#endregion Animations and colors
