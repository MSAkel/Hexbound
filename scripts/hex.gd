class_name Hex
extends Node

const RUNE_UI: PackedScene = preload("res://scenes/ui/runes/rune_ui.tscn")

var _coordinates: Vector2i = Vector2i(0, 0)
var active_rune: Rune = null
var rune_ui: RuneUI = null

# Character segment passive, stamped at run start on fixed tiles. Cannot be changed or overridden.
var segment_passive_modifier: SegmentPassiveModifier = null
# Future player-applied modifier. Only allowed on tiles without a segment passive.
var tile_modifier: TileModifier = null
# Permanently disabled by difficulty level 5; tile cannot be used for the run.
var is_disabled_by_difficulty: bool = false

var segment_passive_icon: TextureRect = null
var map: HexTileMap
var items_grid: Control
# Optional challenge tint layered on top of the normal active/inactive state.
var _challenge_rune_modulate: Color = Color.WHITE
# True while toggle_map_display is held to hide rune icons on the map.
var _runes_hidden: bool = false

# Match the dashed hex art size so runes align with the tile texture
const HEX_TILE_SIZE := Vector2(HexTileMap.HEX_TEXTURE_SIZE, HexTileMap.HEX_TEXTURE_SIZE)
const HEX_TILE_HALF := HEX_TILE_SIZE / 2
# Segment passive icons sit centered on the tile at half the hex size
const SEGMENT_PASSIVE_ICON_SIZE := HEX_TILE_SIZE / 2
const RUNE_INACTIVE_MODULATE := Color(0.35, 0.35, 0.42, 0.78)
const RUNE_FADED_SECTOR_MODULATE := Color(0.58, 0.46, 0.34, 0.9)

var coordinates: Vector2i:
	get:
		return _coordinates

func _init(coords: Vector2i) -> void:
	_coordinates = coords


func setup(map_ref: Node2D) -> void:
	map = map_ref
	# Container sized to one hex; map_to_local returns the tile center
	items_grid = Control.new()
	items_grid.custom_minimum_size = HEX_TILE_SIZE
	items_grid.size = HEX_TILE_SIZE
	items_grid.position = map.base_layer.map_to_local(coordinates) - HEX_TILE_HALF
	map.add_child(items_grid)


func is_reserved_for_segment_passive() -> bool:
	return segment_passive_modifier != null


func can_receive_tile_modifier() -> bool:
	return TileModifier.can_replace_on(self)


func place_rune(rune: Rune) -> void:
	# Prevent placing a rune if one already exists or the tile is disabled by difficulty.
	if active_rune != null or is_disabled_by_difficulty:
		return
	
	# Each tile needs its own rune instance. hand/pool cards often share one .tres reference.
	active_rune = rune.duplicate(true)
	var new_rune_instance: RuneUI = RUNE_UI.instantiate()
	rune_ui = new_rune_instance
	new_rune_instance.map = map
	new_rune_instance.tile = self
	new_rune_instance.center_coordinates = coordinates

	new_rune_instance.setup(rune)
	# Fixed size keeps runes aligned to the hex art
	new_rune_instance.position = Vector2.ZERO
	new_rune_instance.size = HEX_TILE_SIZE
	
	items_grid.add_child(new_rune_instance)
	new_rune_instance.play_placement_animation()
	_apply_display_mode()
	refresh_rune_visual_state()


# Stamp the character's segment passive onto this tile (run start only).
func set_segment_passive_modifier(modifier: SegmentPassiveModifier) -> void:
	segment_passive_modifier = modifier

	if modifier == null:
		if segment_passive_icon != null:
			segment_passive_icon.queue_free()
			segment_passive_icon = null
		return

	if segment_passive_icon == null:
		segment_passive_icon = _create_segment_passive_icon()
		items_grid.add_child(segment_passive_icon)

	segment_passive_icon.texture = modifier.icon
	_refresh_segment_passive_icon_rotation()
	_apply_display_mode()


func _create_segment_passive_icon() -> TextureRect:
	var icon := TextureRect.new()
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	# Anchor to tile center so the icon stays centered at a fixed size
	icon.set_anchors_preset(Control.PRESET_CENTER)
	var half_size := SEGMENT_PASSIVE_ICON_SIZE / 2
	icon.offset_left = -half_size.x
	icon.offset_top = -half_size.y
	icon.offset_right = half_size.x
	icon.offset_bottom = half_size.y
	# Row-direction flips rotate around the icon center, not the top-left corner.
	icon.pivot_offset = half_size
	return icon


func _refresh_segment_passive_icon_rotation() -> void:
	if segment_passive_icon == null or segment_passive_modifier == null:
		return
	if segment_passive_modifier.modifier_type != SegmentPassiveModifier.Type.FIRST_ROW:
		segment_passive_icon.rotation = 0.0
		return

	var row_index := map.get_segment_index(coordinates)
	segment_passive_icon.rotation = PI if row_index % 2 == 1 else 0.0


# Apply a run-time tile modifier. Returns false on segment-passive or occupied tiles.
func try_apply_tile_modifier(modifier: TileModifier) -> bool:
	if is_disabled_by_difficulty:
		return false

	if not TileModifier.can_replace_on(self):
		return false

	tile_modifier = modifier
	# Future: add tile_modifier_icon UI when this mechanic is implemented.
	return true


func clear_tile_modifier() -> void:
	tile_modifier = null
	# Future: remove tile_modifier_icon when that UI exists.


# Attach an enhancement to the placed rune. Returns false when the tile is empty or already enhanced.
func try_apply_enhancement(enhancement: Enhancement) -> bool:
	if is_disabled_by_difficulty:
		return false

	if not Enhancement.can_apply_to(self):
		return false

	# Each placement needs its own instance so map state does not leak between cards.
	active_rune.enhancement = enhancement.duplicate(true)
	Events.enhancement_applied.emit(active_rune, active_rune.enhancement)
	# Future: add enhancement_icon UI when that overlay is implemented.
	return true


# Hide or show rune icons while keeping segment-passive modifiers visible.
func set_runes_hidden(hide_runes: bool) -> void:
	_runes_hidden = hide_runes
	_apply_display_mode()


func _apply_display_mode() -> void:
	var has_rune := rune_ui != null and active_rune != null
	if segment_passive_icon != null:
		# Modifiers are shown by default; a placed rune takes priority on the same tile.
		segment_passive_icon.visible = (
			segment_passive_modifier != null
			and (not has_rune or _runes_hidden)
		)
	if rune_ui != null:
		rune_ui.visible = has_rune and not _runes_hidden


func refresh_rune_visual_state() -> void:
	if rune_ui == null or active_rune == null:
		return

	var target_modulate := Color.WHITE
	if not active_rune.is_active:
		target_modulate = RUNE_INACTIVE_MODULATE
	elif _challenge_rune_modulate != Color.WHITE:
		target_modulate = _challenge_rune_modulate

	rune_ui.apply_resting_modulate(target_modulate)


func set_rune_challenge_modulate(modulate: Color) -> void:
	_challenge_rune_modulate = modulate
	refresh_rune_visual_state()


func clear_rune_challenge_modulate() -> void:
	_challenge_rune_modulate = Color.WHITE
	refresh_rune_visual_state()


# Clear the placed rune from this tile and remove its map UI.
func remove_rune() -> void:
	if active_rune == null:
		return
	
	active_rune = null
	_challenge_rune_modulate = Color.WHITE
	if rune_ui != null:
		rune_ui.queue_free()
		rune_ui = null
	_apply_display_mode()


# Play the rune trigger animation without applying the effect.
func play_rune_activation_animation() -> void:
	if active_rune == null or rune_ui == null:
		return
	
	# Only animate active runes so inactive runes do not look triggered.
	if active_rune.is_active:
		rune_ui.play_activation_animation()


# Lift-and-slam animation used during the post-turn segment result reveal.
func play_segment_result_animation() -> void:
	if rune_ui == null:
		return
	rune_ui.play_segment_result_animation()


func apply_rune_activation(activation_scale: float = 1.0) -> void:
	if active_rune == null:
		return
	
	active_rune.activate_rune(self, activation_scale)


func start_empower_flash() -> void:
	if rune_ui == null:
		return
	rune_ui.start_empower_flash()


func stop_empower_flash() -> void:
	if rune_ui == null:
		return
	rune_ui.stop_empower_flash()
