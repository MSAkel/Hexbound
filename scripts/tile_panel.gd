class_name TilePanel
extends Control

@onready var active_tile_modifier: Label = $PanelContainer/VBoxContainer/TileDetailsContainer/ActiveTileModifier

@onready var rune_icon: TextureRect = $PanelContainer/VBoxContainer/RunePanelContainer/RuneIconPanel/RuneIcon
@onready var rune_name: Label = $PanelContainer/VBoxContainer/RunePanelContainer/RuneVBox/RuneName
@onready var rune_description: Label = $PanelContainer/VBoxContainer/RunePanelContainer/RuneVBox/RuneDescription

# Gap between the hovered tile and the panel edge.
const OFFSET := Vector2(12, 12)

var hex: Hex = null
var selected_rune: Rune = null
# Screen-space rect of the hovered tile (viewport / CanvasLayer coords).
var target_rect: Rect2 = Rect2()


func _ready() -> void:
	EventBus.turn_ended.connect(_on_turn_ended)
	hide()
	# Keep above map UI chrome while ignoring mouse so hover can leave the tile.
	z_index = 100
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_hex(h: Hex, tile_rect: Rect2 = Rect2()) -> void:
	hex = h
	target_rect = tile_rect
	_set_tile_information()
	_set_rune_information()
	show()
	# Size may change with content; position after the layout pass.
	call_deferred("_update_position")


# Re-anchor while still hovering (e.g. camera zoom / pan mid-hover).
func update_anchor(tile_rect: Rect2) -> void:
	target_rect = tile_rect
	_update_position()


func _set_tile_information() -> void:
	var lines: PackedStringArray = []

	if hex.segment_passive_modifier != null:
		lines.append(
			"%s\n%s" % [
				hex.segment_passive_modifier.name,
				hex.segment_passive_modifier.description,
			]
		)

	if hex.tile_modifier != null:
		lines.append(
			"%s\n%s" % [
				hex.tile_modifier.name,
				hex.tile_modifier.description,
			]
		)

	if lines.is_empty():
		active_tile_modifier.text = "None"
	else:
		active_tile_modifier.text = "\n\n".join(lines)


func _set_rune_information() -> void:
	if hex.active_rune != null:
		rune_icon.texture = hex.active_rune.icon
		rune_name.text = hex.active_rune.name
		var description_lines: PackedStringArray = [hex.active_rune.description]
		if hex.active_rune.enhancement != null:
			description_lines.append(
				"Enhancement: %s" % [hex.active_rune.enhancement.short_description]
			)
		rune_description.text = "\n\n".join(description_lines)
	else:
		rune_icon.texture = load("res://assets/tilesets/tile_dashed.png")
		rune_name.text = "No Rune"
		rune_description.text = ""

# Position next to the tile, flipping sides when near viewport edges (same idea as Tooltip).
func _update_position() -> void:
	if target_rect == Rect2():
		return

	var viewport_size := get_viewport().get_visible_rect().size
	var panel_pos := Vector2(target_rect.end.x + OFFSET.x, target_rect.position.y)

	# Prefer right of the tile; flip to the left if it would clip.
	if panel_pos.x + size.x > viewport_size.x:
		panel_pos.x = target_rect.position.x - size.x - OFFSET.x

	# Prefer top-aligned with the tile; shift up if it would clip at the bottom.
	if panel_pos.y + size.y > viewport_size.y:
		panel_pos.y = target_rect.end.y - size.y

	position = panel_pos
	_clamp_to_viewport()


func _clamp_to_viewport() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	position.x = clampf(position.x, 0.0, maxf(viewport_size.x - size.x, 0.0))
	position.y = clampf(position.y, 0.0, maxf(viewport_size.y - size.y, 0.0))


func _on_close_button_pressed() -> void:
	hide()


func _on_toggle_rune_button_pressed() -> void:
	if hex.active_rune.is_active:
		hex.active_rune.is_active = false
	else:
		hex.active_rune.is_active = true
	hex.refresh_rune_visual_state()


func _on_turn_ended() -> void:
	hide()
