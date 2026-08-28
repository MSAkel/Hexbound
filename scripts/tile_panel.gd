class_name TilePanel
extends Control

@onready var rune_icon: TextureRect = $PanelContainer/VBoxContainer/RunePanelContainer/RuneIconPanel/RuneIcon
@onready var rune_name: Label = $PanelContainer/VBoxContainer/RunePanelContainer/RuneVBox/RuneName
@onready var rune_subtitle: Label = $PanelContainer/VBoxContainer/RunePanelContainer/RuneVBox/RuneSubtitle
@onready var rune_chip_line: Label = $PanelContainer/VBoxContainer/RunePanelContainer/RuneVBox/RuneChipLine
@onready var rune_description: RichTextLabel = $PanelContainer/VBoxContainer/RunePanelContainer/RuneVBox/RuneDescription

# Gap between the hovered tile and the panel edge.
const OFFSET := Vector2(12, 12)
const EMPTY_TILE_ICON := preload("res://assets/tilesets/tile_dashed.png")

var hex: Hex = null
var selected_rune: TileCard = null
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
	_set_rune_information()
	show()
	# Size may change with content; position after the layout pass.
	call_deferred("_update_position")


# Re-anchor while still hovering (e.g. camera zoom / pan mid-hover).
func update_anchor(tile_rect: Rect2) -> void:
	target_rect = tile_rect
	_update_position()


func _set_rune_information() -> void:
	if hex.active_tile_card != null:
		var card := hex.active_tile_card
		rune_icon.texture = card.icon
		rune_name.text = card.name
		rune_subtitle.text = card.get_inspect_subtitle()
		rune_subtitle.visible = not rune_subtitle.text.is_empty()
		_set_chip_line(card)
		var description_bbcode := CardKeywordGlossary.to_bbcode(card.description)
		rune_description.text = description_bbcode
	else:
		rune_icon.texture = EMPTY_TILE_ICON
		rune_name.text = "No Rune"
		rune_subtitle.text = ""
		rune_subtitle.hide()
		rune_chip_line.hide()
		rune_description.text = ""


func _set_chip_line(card: TileCard) -> void:
	var chip: Dictionary = card.get_board_chip(hex)
	var mode: TileCard.BoardChipMode = chip.get("mode", TileCard.BoardChipMode.HIDDEN)
	if mode == TileCard.BoardChipMode.HIDDEN:
		rune_chip_line.hide()
		return
	var detail: String = str(chip.get("detail", ""))
	var chip_text := str(chip.get("text", ""))
	if chip_text.is_empty() and detail.is_empty():
		rune_chip_line.hide()
		return
	if detail.is_empty():
		rune_chip_line.text = chip_text
	else:
		rune_chip_line.text = "%s  ·  %s" % [chip_text, detail]
	rune_chip_line.show()

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
	if hex.active_tile_card.is_active:
		hex.active_tile_card.is_active = false
	else:
		hex.active_tile_card.is_active = true
	hex.refresh_tile_card_visual_state()


func _on_turn_ended() -> void:
	hide()
